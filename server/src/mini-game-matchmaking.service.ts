import { BadRequestException, Injectable } from '@nestjs/common';
import { InfrastructureService } from './infrastructure.service';
import { RoomService } from './room.service';
import { RedFlagGameService } from './red-flag-game.service';
import { GameRoomTestService } from './game-room-test.service';

type GameKey = 'red_flag_green_flag' | 'two_truths_one_lie';

@Injectable()
export class MiniGameMatchmakingService {
  constructor(
    private readonly infra: InfrastructureService,
    private readonly rooms: RoomService,
    private readonly redFlag: RedFlagGameService,
    private readonly twoTruths: GameRoomTestService,
  ) {}

  private gameKey(raw: unknown): GameKey {
    const key = String(raw ?? '').trim();
    if (key === 'red_flag_green_flag' || key === 'two_truths_one_lie') return key;
    throw new BadRequestException('Geçerli mini oyun seçmelisin.');
  }

  private async activeGameRoom(userId: string, wanted?: GameKey) {
    const result = await this.infra.db.query<{ room_id: string; body: string }>(
      `select rm.room_id::text,
              coalesce((select m.body from room_messages m where m.room_id=rm.room_id and m.sender_user_id is null order by m.id desc limit 1),'') body
       from room_members rm
       join rooms r on r.id=rm.room_id
       where rm.user_id=$1
         and rm.left_at is null
         and rm.admin_removed_at is null
         and r.room_mode='game'
         and r.status in ('active','selection')
       order by rm.room_id desc
       limit 1`,
      [userId],
    );
    const row = result.rows[0];
    if (!row) return null;
    const body = row.body.toLocaleLowerCase('tr-TR');
    const gameKey: GameKey | null = body.includes('red flag')
      ? 'red_flag_green_flag'
      : body.includes('iki doğru') || body.includes('iki dogru')
        ? 'two_truths_one_lie'
        : null;
    if (!gameKey || (wanted && gameKey !== wanted)) return null;
    return { roomId: row.room_id, gameKey };
  }

  private async initializeRedFlag(roomId: string, memberIds: string[]) {
    const profiles = await this.infra.db.query<{
      user_id: string;
      name: string;
      gender: string;
      looking_for: string;
      photo_url: string;
      age: number;
    }>(
      `select u.id::text user_id,
              coalesce(nullif(trim(p.display_name),''),'Oyuncu') name,
              coalesce(p.gender,'') gender,
              coalesce(mp.looking_for,'Herkes') looking_for,
              coalesce(p.photo_urls[1],'') photo_url,
              extract(year from age(current_date,p.birth_date))::int age
       from users u
       join profiles p on p.user_id=u.id
       left join matching_preferences mp on mp.user_id=u.id
       where u.id=any($1::bigint[])
         and u.status='active'
         and p.profile_completed=true`,
      [memberIds],
    );
    if (profiles.rows.length !== 6) {
      throw new BadRequestException('Red Flag oyuncularından biri artık hazır değil.');
    }
    const byId = new Map(profiles.rows.map((row) => [row.user_id, row]));
    const first = byId.get(memberIds[0]);
    const service = this.redFlag as any;
    const questions = await service.chooseQuestions(memberIds[0], first?.age ?? 18);

    for (const id of memberIds) {
      for (const question of questions) {
        await this.infra.db.query(
          `insert into red_flag_question_history(user_id,question_id,seen_at)
           values($1,$2,now())
           on conflict(user_id,question_id) do update set seen_at=excluded.seen_at`,
          [id, question.id],
        );
      }
    }

    const players = memberIds.map((id) => {
      const row = byId.get(id)!;
      return {
        id,
        name: row.name,
        test: false,
        gender: row.gender,
        lookingFor: row.looking_for,
        photoUrl: row.photo_url,
      };
    });
    const startedAtMs = Date.now();
    const state = {
      roomId,
      players,
      questions,
      questionIndex: 0,
      phase: 'choice',
      phaseEndsAt: new Date(startedAtMs + 15_000),
      startedAtMs,
      choices: {},
      answers: [],
      suggestions: {},
      finalChoices: {},
      matchIds: {},
    };
    service.prepareQuestion(state, 0);
    service.games.set(roomId, state);
  }

  private async initializeTwoTruths(roomId: string, memberIds: string[], startedAtMs: number) {
    const profiles = await this.infra.db.query<{
      user_id: string;
      name: string;
      gender: string;
      looking_for: string;
      photo_url: string;
    }>(
      `select u.id::text user_id,
              coalesce(nullif(trim(p.display_name),''),'Oyuncu') name,
              coalesce(p.gender,'') gender,
              coalesce(mp.looking_for,'Herkes') looking_for,
              coalesce(p.photo_urls[1],'') photo_url
       from users u
       join profiles p on p.user_id=u.id
       left join matching_preferences mp on mp.user_id=u.id
       where u.id=any($1::bigint[])
         and u.status='active'
         and p.profile_completed=true`,
      [memberIds],
    );
    if (profiles.rows.length !== 6) {
      throw new BadRequestException('2 Doğru 1 Yanlış oyuncularından biri artık hazır değil.');
    }
    const byId = new Map(profiles.rows.map((row) => [row.user_id, row]));
    const players = memberIds.map((id) => {
      const row = byId.get(id)!;
      return {
        id,
        name: row.name,
        test: false,
        gender: row.gender,
        lookingFor: row.looking_for,
        photoUrl: row.photo_url,
      };
    });
    const owner = players[0];
    const state = {
      roomId,
      players,
      roundIndex: 0,
      round: {
        ownerUserId: owner.id,
        statements: [],
        lieIndex: -1,
        votes: {},
        resolved: false,
      },
      xpEarned: Object.fromEntries(players.map((player) => [player.id, 0])),
      completedRounds: [],
      finished: false,
      suggestions: {},
      finalChoices: {},
      matchIds: {},
      startedAtMs,
    };
    (this.twoTruths as any).games.set(roomId, state);
  }

  async join(userId: string, rawGameKey: unknown) {
    const gameKey = this.gameKey(rawGameKey);
    const current = await this.activeGameRoom(String(userId), gameKey);
    if (current) {
      return {
        ok: true,
        state: 'room',
        gameKey,
        room: await this.rooms.getRoom(userId, current.roomId),
      };
    }

    const ready = await this.infra.db.query(
      `select 1 from users u join profiles p on p.user_id=u.id
       where u.id=$1 and u.status='active' and p.profile_completed=true`,
      [userId],
    );
    if (!ready.rowCount) throw new BadRequestException('Mini oyun için profilini tamamlamalısın.');

    const client = await this.infra.db.connect();
    let roomId = '';
    let chosenIds: string[] = [];
    let startedAtMs = Date.now();
    try {
      await client.query('begin');
      await client.query('select pg_advisory_xact_lock(606065)');
      const busy = await client.query(
        `select 1 from room_members rm join rooms r on r.id=rm.room_id
         where rm.user_id=$1 and rm.left_at is null and rm.admin_removed_at is null
           and r.status in ('active','selection') limit 1`,
        [userId],
      );
      if (busy.rowCount) throw new BadRequestException('Önce mevcut aktif odandan çıkmalısın.');

      await client.query(
        `insert into mini_game_matchmaking_queue(user_id,game_key,joined_at)
         values($1,$2,now())
         on conflict(user_id) do update set game_key=excluded.game_key, joined_at=case when mini_game_matchmaking_queue.game_key=excluded.game_key then mini_game_matchmaking_queue.joined_at else now() end`,
        [userId, gameKey],
      );

      const candidates = await client.query<{ user_id: string }>(
        `select q.user_id::text
         from mini_game_matchmaking_queue q
         join users u on u.id=q.user_id
         join profiles p on p.user_id=q.user_id
         where q.game_key=$1
           and u.status='active'
           and p.profile_completed=true
           and not exists(
             select 1 from room_members rm join rooms r on r.id=rm.room_id
             where rm.user_id=q.user_id and rm.left_at is null and rm.admin_removed_at is null
               and r.status in ('active','selection')
           )
         order by q.joined_at asc
         limit 6
         for update of q skip locked`,
        [gameKey],
      );
      chosenIds = candidates.rows.map((row) => row.user_id);
      if (chosenIds.length < 6) {
        await client.query('commit');
        return this.status(String(userId), gameKey);
      }

      const created = await client.query<{ id: string; started_at: Date }>(
        `insert into rooms(status,started_at,ends_at,room_duration_minutes,room_mode)
         values('active',now(),now()+interval '15 minutes',15,'game')
         returning id::text,started_at`,
      );
      roomId = created.rows[0]?.id ?? '';
      startedAtMs = created.rows[0]?.started_at?.getTime() ?? Date.now();
      if (!roomId) throw new BadRequestException('Mini oyun odası oluşturulamadı.');

      for (const id of chosenIds) {
        await client.query('insert into room_members(room_id,user_id) values($1,$2)', [roomId, id]);
      }
      await client.query('delete from mini_game_matchmaking_queue where user_id=any($1::bigint[])', [chosenIds]);
      await client.query('delete from matchmaking_queue where user_id=any($1::bigint[])', [chosenIds]);
      await client.query('delete from tabu_matchmaking_queue where user_id=any($1::bigint[])', [chosenIds]);
      await client.query(
        `insert into room_messages(room_id,sender_user_id,body) values($1,null,$2)`,
        [
          roomId,
          gameKey === 'red_flag_green_flag'
            ? 'Red Flag / Green Flag başladı. 6 soru • 15 sn seçim • 2 dk tartışma.'
            : 'Mini oyun başladı: İki Doğru Bir Yalan.',
        ],
      );
      await client.query('commit');
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }

    if (gameKey === 'red_flag_green_flag') {
      await this.initializeRedFlag(roomId, chosenIds);
    } else {
      await this.initializeTwoTruths(roomId, chosenIds, startedAtMs);
    }

    return {
      ok: true,
      state: 'room',
      gameKey,
      participantCount: 6,
      room: await this.rooms.getRoom(userId, roomId),
    };
  }

  async status(userId: string, rawGameKey: unknown) {
    const gameKey = this.gameKey(rawGameKey);
    const current = await this.activeGameRoom(String(userId), gameKey);
    if (current) {
      return {
        ok: true,
        state: 'room',
        gameKey,
        room: await this.rooms.getRoom(userId, current.roomId),
      };
    }
    const result = await this.infra.db.query<{ user_id: string }>(
      `select user_id::text from mini_game_matchmaking_queue
       where game_key=$1 order by joined_at asc`,
      [gameKey],
    );
    const index = result.rows.findIndex((row) => row.user_id === String(userId));
    return {
      ok: true,
      state: 'queued',
      gameKey,
      total: result.rowCount ?? 0,
      position: index < 0 ? 0 : index + 1,
      needed: Math.max(0, 6 - (result.rowCount ?? 0)),
      nextRetrySeconds: 2,
    };
  }

  async cancel(userId: string) {
    await this.infra.db.query('delete from mini_game_matchmaking_queue where user_id=$1', [userId]);
    return { ok: true, state: 'idle' };
  }
}
