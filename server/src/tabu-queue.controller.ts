import { createHash } from 'crypto';
import { BadRequestException, Controller, Delete, ForbiddenException, Get, Headers, Post } from '@nestjs/common';

import { AuthService } from './auth.service';
import { InfrastructureService } from './infrastructure.service';
import { RoomService } from './room.service';
import { TabuGameService } from './tabu-game.service';
import { TabuGateway } from './tabu.gateway';

@Controller('rooms/tabu/queue')
export class TabuQueueController {
  private static readonly TESTER_PHONE_HASH =
    '80340dec2efb640dbb56d3cd0234a589f4fffc6d79384cd2570377e6384d075d';
  private readonly testTimers = new Map<string, NodeJS.Timeout>();

  constructor(
    private readonly auth: AuthService,
    private readonly tabu: TabuGameService,
    private readonly infra: InfrastructureService,
    private readonly rooms: RoomService,
    private readonly gateway: TabuGateway,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  private async isTester(userId: string) {
    const result = await this.infra.db.query<{ phone_e164: string }>(
      `select phone_e164 from users where id=$1 and status='active' limit 1`,
      [userId],
    );
    const phone = result.rows[0]?.phone_e164?.trim() ?? '';
    return createHash('sha256').update(phone).digest('hex') ===
      TabuQueueController.TESTER_PHONE_HASH;
  }

  private testIds(currentUserId: string) {
    if (process.env.GAME_ROOM_TEST_ENABLED !== 'true') {
      throw new ForbiddenException('Mini oyun test modu sunucuda kapalı.');
    }
    const ids = (process.env.GAME_ROOM_TEST_USER_IDS ?? '')
      .split(',')
      .map((value) => value.trim())
      .filter((value) => /^\d+$/.test(value) && value !== String(currentUserId));
    const unique = [...new Set(ids)];
    if (unique.length !== 5) {
      throw new BadRequestException(
        'GAME_ROOM_TEST_USER_IDS içinde mevcut kullanıcı hariç tam 5 test kullanıcı ID olmalı.',
      );
    }
    return unique;
  }

  private startTestBots(roomId: string, humanUserId: string) {
    if (this.testTimers.has(roomId)) return;
    const svc = this.tabu as any;
    const gateway = this.gateway as any;

    const timer = setInterval(async () => {
      try {
        const state = svc.games.get(roomId);
        if (!state || state.phase === 'final') {
          clearInterval(timer);
          this.testTimers.delete(roomId);
          return;
        }
        await svc.sync(state);
        if (state.phase !== 'play') return;

        const narrator = state.players[state.narratorIndex];
        if (!narrator) return;

        if (narrator.test) {
          if (state.testCluedVersion === state.wordVersion) return;
          state.testCluedVersion = state.wordVersion;
          svc.addMessage(
            state,
            narrator,
            'narrator',
            `[TEST] Kategori: ${state.card.category}. Doğru cevap: ${state.card.word}`,
          );
          await gateway.broadcast(roomId, 'tabu:speaker_message', {
            testMode: true,
            hint: 'Test botu ipucu gönderdi.',
          });
          return;
        }

        if (narrator.id !== String(humanUserId)) return;
        if (state.testGuessedVersion === state.wordVersion) return;
        const humanClue = [...state.messages]
          .reverse()
          .find((message: any) =>
            message.role === 'narrator' && message.userId === String(humanUserId),
          );
        if (!humanClue) return;

        state.testGuessedVersion = state.wordVersion;
        const bot = state.players.find((player: any) => player.test);
        if (!bot) return;
        const version = state.wordVersion;

        const wrong = await svc.guess(bot.id, roomId, 'deneme');
        await gateway.broadcast(roomId, wrong.event, wrong.eventData ?? {});

        setTimeout(async () => {
          try {
            const latest = svc.games.get(roomId);
            if (!latest || latest.phase !== 'play' || latest.wordVersion !== version) return;
            const correct = await svc.guess(bot.id, roomId, latest.card.word);
            await gateway.broadcast(roomId, correct.event, correct.eventData ?? {});
          } catch (_) {}
        }, 1200);
      } catch (_) {}
    }, 500);

    this.testTimers.set(roomId, timer);
  }

  private async createTestRoom(userId: string) {
    const svc = this.tabu as any;
    const testIds = this.testIds(userId);
    const memberIds = [String(userId), ...testIds];

    await this.tabu.cancelQueue(userId);
    await this.infra.db.query(
      'delete from tabu_matchmaking_queue where user_id=any($1::bigint[])',
      [testIds],
    );

    const busy = await this.infra.db.query(
      `select 1
       from room_members rm
       join rooms r on r.id=rm.room_id
       where rm.user_id=$1
         and rm.left_at is null
         and rm.admin_removed_at is null
         and r.status in ('active','selection')
       limit 1`,
      [userId],
    );
    if (busy.rowCount) {
      throw new BadRequestException('Önce mevcut aktif odandan çıkmalısın.');
    }

    await this.infra.db.query(
      `update rooms
       set status='closed',closed_at=coalesce(closed_at,now()),closed_reason=coalesce(closed_reason,'test_reset')
       where room_mode='game'
         and status in ('active','selection')
         and id in (
           select distinct room_id from room_members
           where user_id=any($1::bigint[])
         )`,
      [testIds],
    );
    await this.infra.db.query(
      `update room_members
       set left_at=coalesce(left_at,now())
       where user_id=any($1::bigint[]) and left_at is null`,
      [testIds],
    );

    const players = await svc.profiles(memberIds);
    for (const player of players) {
      player.test = player.id !== String(userId);
    }

    const client = await this.infra.db.connect();
    let roomId = '';
    try {
      await client.query('begin');
      const created = await client.query<{ id: string }>(
        `insert into rooms(status,started_at,ends_at,room_duration_minutes,room_mode)
         values('active',now(),now()+interval '8 minutes',8,'game')
         returning id::text`,
      );
      roomId = created.rows[0]?.id ?? '';
      if (!roomId) throw new BadRequestException('Tabu test odası oluşturulamadı.');

      for (const id of memberIds) {
        await client.query(
          'insert into room_members(room_id,user_id) values($1,$2)',
          [roomId, id],
        );
      }
      await client.query(
        `insert into room_messages(room_id,sender_user_id,body)
         values($1,null,'Mini oyun başladı: Tabu. [TEST]')`,
        [roomId],
      );
      await client.query('commit');
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }

    const state = await svc.initialize(roomId, players);
    state.testMode = true;
    this.startTestBots(roomId, String(userId));

    return {
      ok: true,
      state: 'room',
      participantCount: 6,
      gameKey: 'tabu',
      testMode: true,
      room: await this.rooms.getRoom(userId, roomId),
      gameState: svc.view(state, String(userId)),
    };
  }

  @Post()
  async join(@Headers('authorization') authorization?: string) {
    const userId = await this.userId(authorization);
    if (await this.isTester(String(userId))) {
      return this.createTestRoom(String(userId));
    }
    return this.tabu.joinQueue(userId);
  }

  @Get()
  async status(@Headers('authorization') authorization?: string) {
    return this.tabu.queueStatus(await this.userId(authorization));
  }

  @Delete()
  async cancel(@Headers('authorization') authorization?: string) {
    return this.tabu.cancelQueue(await this.userId(authorization));
  }
}
