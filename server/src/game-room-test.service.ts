import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';

import { InfrastructureService } from './infrastructure.service';
import { RoomService } from './room.service';

type Player = { id: string; name: string; test: boolean };
type Round = {
  ownerUserId: string;
  statements: string[];
  lieIndex: number;
  votes: Record<string, number>;
  resolved: boolean;
  result?: { lieIndex: number; correctUserIds: string[]; voteCounts: number[] };
};
type State = {
  roomId: string;
  players: Player[];
  roundIndex: number;
  round: Round;
  scores: Record<string, number>;
  finished: boolean;
};

@Injectable()
export class GameRoomTestService {
  private readonly games = new Map<string, State>();

  constructor(
    private readonly infra: InfrastructureService,
    private readonly rooms: RoomService,
  ) {}

  private testIds(currentUserId: string) {
    if (process.env.GAME_ROOM_TEST_ENABLED !== 'true') {
      throw new ForbiddenException('Mini oyun test odası sunucuda kapalı.');
    }
    const ids = (process.env.GAME_ROOM_TEST_USER_IDS ?? '')
      .split(',')
      .map((v) => v.trim())
      .filter((v) => /^\d+$/.test(v) && v !== String(currentUserId));
    const unique = [...new Set(ids)];
    if (unique.length !== 5) {
      throw new BadRequestException('GAME_ROOM_TEST_USER_IDS içinde mevcut kullanıcı hariç tam 5 test kullanıcı ID olmalı.');
    }
    return unique;
  }

  private botStatements(seed: number) {
    const sets = [
      ['Gece yürüyüşlerini severim.', 'Kahveyi şekersiz içerim.', 'Hiç denize girmedim.'],
      ['Bir enstrüman çalabiliyorum.', 'Acı yemek severim.', 'Hiç film izlemem.'],
      ['Sabah erken kalkarım.', 'Kedileri severim.', 'Uçaktan korkarım.'],
      ['Yemek yapmayı severim.', 'Dağ tatilini seçerim.', 'Hiç müzik dinlemem.'],
      ['Spora düzenli giderim.', 'Tatlıyı çok severim.', 'Telefon kullanmam.'],
    ];
    return sets[seed % sets.length];
  }

  private round(players: Player[], index: number): Round {
    const owner = players[index % players.length];
    return owner.test
      ? { ownerUserId: owner.id, statements: this.botStatements(index), lieIndex: 2, votes: {}, resolved: false }
      : { ownerUserId: owner.id, statements: [], lieIndex: -1, votes: {}, resolved: false };
  }

  private resolve(state: State) {
    const eligible = state.players.filter((p) => p.id !== state.round.ownerUserId);
    if (!eligible.every((p) => state.round.votes[p.id] !== undefined)) return;
    const counts = [0, 0, 0];
    for (const vote of Object.values(state.round.votes)) counts[vote]++;
    const correct = eligible
      .filter((p) => state.round.votes[p.id] === state.round.lieIndex)
      .map((p) => p.id);
    for (const userId of correct) state.scores[userId] = (state.scores[userId] ?? 0) + 20;
    state.round.resolved = true;
    state.round.result = {
      lieIndex: state.round.lieIndex,
      correctUserIds: correct,
      voteCounts: counts,
    };
  }

  private autoVotes(state: State, exceptUserId?: string) {
    for (const player of state.players) {
      if (player.id === state.round.ownerUserId || player.id === exceptUserId) continue;
      state.round.votes[player.id] = (Number(player.id) + state.roundIndex) % 3;
    }
    this.resolve(state);
  }

  private view(state: State, userId: string) {
    const owner = state.players.find((p) => p.id === state.round.ownerUserId);
    const leaderboard = state.players
      .map((p) => ({ ...p, score: state.scores[p.id] ?? 0 }))
      .sort((a, b) => b.score - a.score || Number(a.id) - Number(b.id));
    return {
      roomId: state.roomId,
      game: 'two_truths_one_lie',
      roundIndex: state.roundIndex,
      totalRounds: state.players.length,
      players: state.players,
      ownerUserId: state.round.ownerUserId,
      ownerName: owner?.name ?? 'Oyuncu',
      isMyTurn: state.round.ownerUserId === userId,
      phase: state.finished
        ? 'final'
        : state.round.resolved
          ? 'result'
          : state.round.statements.length === 3
            ? 'vote'
            : 'write',
      statements: state.round.statements,
      myVote: state.round.votes[userId] ?? null,
      result: state.round.result ?? null,
      scores: state.scores,
      leaderboard,
      selectionSeconds: 10,
    };
  }

  private async assertMember(userId: string, roomId: string) {
    const result = await this.infra.db.query(
      `select 1 from room_members rm join rooms r on r.id=rm.room_id
       where rm.room_id=$1 and rm.user_id=$2 and rm.left_at is null
       and rm.admin_removed_at is null and r.room_mode='game'`,
      [roomId, userId],
    );
    if (result.rowCount === 0) throw new ForbiddenException('Bu mini oyun odasına erişimin yok.');
  }

  async create(userId: string) {
    const testUserIds = this.testIds(userId);
    const memberIds = [String(userId), ...testUserIds];
    const client = await this.infra.db.connect();
    try {
      await client.query('begin');
      await client.query('select pg_advisory_xact_lock(606061)');
      const profiles = await client.query<{ user_id: string; name: string }>(
        `select u.id::text user_id, coalesce(nullif(trim(p.display_name),''),'Oyuncu') name
         from users u join profiles p on p.user_id=u.id
         where u.id=any($1::bigint[]) and u.status='active' and p.profile_completed=true`,
        [memberIds],
      );
      const ready = new Set(profiles.rows.map((r) => r.user_id));
      const missing = memberIds.filter((id) => !ready.has(id));
      if (missing.length) throw new BadRequestException(`Mini oyun test kullanıcıları hazır değil: ${missing.join(', ')}`);

      const callerBusy = await client.query(
        `select 1 from room_members rm join rooms r on r.id=rm.room_id
         where rm.user_id=$1 and rm.left_at is null and rm.admin_removed_at is null
         and r.status in ('active','selection') limit 1`,
        [userId],
      );
      if (callerBusy.rowCount) throw new BadRequestException('Önce mevcut aktif odandan çıkmalısın.');

      await client.query(
        `update room_members rm set left_at=now() from rooms r
         where rm.room_id=r.id and rm.user_id=any($1::bigint[])
         and rm.left_at is null and rm.admin_removed_at is null
         and r.status in ('active','selection')`,
        [testUserIds],
      );

      const created = await client.query<{ id: string }>(
        `insert into rooms(status,started_at,ends_at,room_duration_minutes,room_mode)
         values('active',now(),now()+interval '15 minutes',15,'game') returning id::text`,
      );
      const roomId = created.rows[0]?.id;
      if (!roomId) throw new BadRequestException('Mini oyun test odası oluşturulamadı.');
      for (const id of memberIds) await client.query('insert into room_members(room_id,user_id) values($1,$2)', [roomId, id]);
      await client.query('delete from matchmaking_queue where user_id=any($1::bigint[])', [memberIds]);
      await client.query(`insert into room_messages(room_id,sender_user_id,body) values($1,null,'Mini oyun başladı: İki Doğru Bir Yalan.')`, [roomId]);
      await client.query('commit');

      const names = new Map(profiles.rows.map((r) => [r.user_id, r.name]));
      const players = memberIds.map((id) => ({ id, name: names.get(id) ?? 'Oyuncu', test: id !== String(userId) }));
      const scores = Object.fromEntries(players.map((p) => [p.id, 0]));
      const state: State = { roomId, players, roundIndex: 0, round: this.round(players, 0), scores, finished: false };
      this.games.set(roomId, state);
      return { ok: true, state: 'room', testMode: true, participantCount: 6, room: await this.rooms.getRoom(userId, roomId), gameState: this.view(state, String(userId)) };
    } catch (error) {
      await client.query('rollback');
      throw error;
    } finally {
      client.release();
    }
  }

  async state(userId: string, roomId: string) {
    await this.assertMember(userId, roomId);
    const state = this.games.get(roomId);
    if (!state) throw new BadRequestException('Mini oyun durumu bulunamadı. Odayı yeniden oluştur.');
    return this.view(state, String(userId));
  }

  async submitStatements(userId: string, roomId: string, statements: unknown, lieIndex: unknown) {
    await this.assertMember(userId, roomId);
    const state = this.games.get(roomId);
    if (!state) throw new BadRequestException('Mini oyun durumu bulunamadı.');
    if (state.finished) throw new BadRequestException('Oyun tamamlandı.');
    if (state.round.ownerUserId !== String(userId)) throw new BadRequestException('Şu an sıra sende değil.');
    if (!Array.isArray(statements) || statements.length !== 3) throw new BadRequestException('Tam 3 ifade girmelisin.');
    const clean = statements.map((v) => String(v ?? '').trim());
    if (clean.some((v) => v.length < 2 || v.length > 120)) throw new BadRequestException('İfadeler 2-120 karakter arasında olmalı.');
    const lie = Number(lieIndex);
    if (![0, 1, 2].includes(lie)) throw new BadRequestException('Yalan olan ifadeyi seç.');
    state.round.statements = clean;
    state.round.lieIndex = lie;
    this.autoVotes(state);
    return this.view(state, String(userId));
  }

  async vote(userId: string, roomId: string, choice: unknown) {
    await this.assertMember(userId, roomId);
    const state = this.games.get(roomId);
    if (!state) throw new BadRequestException('Mini oyun durumu bulunamadı.');
    if (state.finished) throw new BadRequestException('Oyun tamamlandı.');
    if (state.round.statements.length !== 3) throw new BadRequestException('Oylama henüz başlamadı.');
    if (state.round.ownerUserId === String(userId)) throw new BadRequestException('Kendi turunda oy kullanamazsın.');
    const selected = Number(choice);
    if (![0, 1, 2].includes(selected)) throw new BadRequestException('Geçerli bir ifade seç.');
    state.round.votes[String(userId)] = selected;
    this.autoVotes(state, String(userId));
    return this.view(state, String(userId));
  }

  async nextRound(userId: string, roomId: string) {
    await this.assertMember(userId, roomId);
    const state = this.games.get(roomId);
    if (!state) throw new BadRequestException('Mini oyun durumu bulunamadı.');
    if (state.finished) return this.view(state, String(userId));
    if (!state.round.resolved) throw new BadRequestException('Önce mevcut turu tamamla.');

    if (state.roundIndex >= state.players.length - 1) {
      state.finished = true;
      const human = state.players.find((p) => !p.test);
      await this.infra.db.query(
        `update rooms
         set status='selection', ends_at=now(), selection_started_at=now(), selection_ends_at=now()+interval '10 seconds'
         where id=$1 and status='active'`,
        [roomId],
      );
      if (human) {
        for (const bot of state.players.filter((p) => p.test)) {
          await this.infra.db.query(
            `insert into room_selections(room_id,user_id,selected_user_id)
             values($1,$2,$3)
             on conflict(room_id,user_id) do update set selected_user_id=excluded.selected_user_id, updated_at=now()`,
            [roomId, bot.id, human.id],
          );
        }
      }
      return this.view(state, String(userId));
    }

    state.roundIndex += 1;
    state.round = this.round(state.players, state.roundIndex);
    return this.view(state, String(userId));
  }
}
