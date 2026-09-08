import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { InfrastructureService } from './infrastructure.service';
import { RoomService } from './room.service';
import { TabuCard, TabuWordRepository } from './tabu-word.repository';

type Player = { id: string; name: string; test: boolean; photoUrl: string };
type GameMessage = { id: number; userId: string; name: string; role: 'narrator' | 'guesser'; text: string; at: string };
type TurnStat = { narratorUserId: string; correct: number; tabu: number; pass: number; xp: number };
type WordResult = { kind: 'correct' | 'tabu' | 'pass'; target: string; narratorUserId: string; narratorName: string; guesserUserId?: string; guesserName?: string; forbiddenWord?: string; narratorXpDelta: number; guesserXpDelta: number };
type State = {
  roomId: string; players: Player[]; narratorIndex: number; turnEndsAtMs: number;
  phase: 'play' | 'word_result' | 'turn_result' | 'final'; phaseEndsAtMs: number;
  card: TabuCard; usedCardIds: string[]; wordVersion: number; messages: GameMessage[]; messageSeq: number;
  xp: Record<string, number>; turnStats: TurnStat[]; currentTurn: TurnStat; lastResult: WordResult | null;
  finalLeaderboard: Array<{ id: string; name: string; photoUrl: string; xp: number }>;
};

@Injectable()
export class TabuGameService {
  private readonly games = new Map<string, State>();
  private static readonly TURN_MS = 60_000;
  private static readonly RESULT_MS = 3_000;

  constructor(
    private readonly infra: InfrastructureService,
    private readonly rooms: RoomService,
    private readonly words: TabuWordRepository,
  ) {}

  private normalize(value: string) {
    return value.toLocaleLowerCase('tr-TR').normalize('NFKD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9çğıöşü\s]/gi, ' ').replace(/\s+/g, ' ').trim();
  }

  private containsExact(text: string, needle: string) {
    const target = this.normalize(needle);
    return target.length > 0 && (` ${this.normalize(text)} `).includes(` ${target} `);
  }

  private narrator(s: State) { return s.players[s.narratorIndex]; }
  private player(s: State, userId: string) { return s.players.find((p) => p.id === String(userId)); }
  private assertPlayer(s: State, userId: string) {
    if (!this.player(s, userId)) throw new ForbiddenException('Bu Tabu oyununa erişimin yok.');
  }

  private async profiles(memberIds: string[]): Promise<Player[]> {
    const result = await this.infra.db.query<{user_id:string;name:string;photo_url:string}>(
      `select u.id::text user_id,coalesce(nullif(trim(p.display_name),''),'Oyuncu') name,
              coalesce(p.photo_urls[1],'') photo_url
       from users u join profiles p on p.user_id=u.id
       where u.id=any($1::bigint[]) and u.status='active' and p.profile_completed=true`,
      [memberIds],
    );
    const byId = new Map(result.rows.map((r) => [r.user_id, r]));
    if (memberIds.some((id) => !byId.has(id))) throw new BadRequestException('Tabu oyuncu profillerinden biri hazır değil.');
    return memberIds.map((id) => {
      const p = byId.get(id)!;
      return { id, name: p.name, photoUrl: p.photo_url, test: false };
    });
  }

  private async initialize(roomId: string, players: Player[]) {
    const ids = players.map((p) => p.id);
    const first = await this.words.nextCard(ids);
    const narrator = players[0];
    const turnEnds = Date.now() + TabuGameService.TURN_MS;
    const s: State = {
      roomId, players, narratorIndex: 0, turnEndsAtMs: turnEnds,
      phase: 'play', phaseEndsAtMs: turnEnds, card: first, usedCardIds: [first.id], wordVersion: 1,
      messages: [], messageSeq: 0, xp: Object.fromEntries(players.map((p) => [p.id, 0])), turnStats: [],
      currentTurn: { narratorUserId: narrator.id, correct: 0, tabu: 0, pass: 0, xp: 0 }, lastResult: null, finalLeaderboard: [],
    };
    this.games.set(roomId, s);
    return s;
  }

  private async activeStateForUser(userId: string) {
    const result = await this.infra.db.query<{room_id:string}>(
      `select rm.room_id::text from room_members rm join rooms r on r.id=rm.room_id
       where rm.user_id=$1 and rm.left_at is null and rm.admin_removed_at is null
         and r.room_mode='game' and r.status in ('active','selection')
       order by rm.room_id desc limit 1`, [userId]);
    const roomId = result.rows[0]?.room_id;
    if (!roomId) return null;
    const state = this.games.get(roomId);
    return state ? { roomId, state } : null;
  }

  async joinQueue(userId: string) {
    const existing = await this.activeStateForUser(String(userId));
    if (existing) return { ok: true, state: 'room', gameKey: 'tabu', room: await this.rooms.getRoom(userId, existing.roomId), gameState: this.viewRaw(existing.state, String(userId)) };

    const profile = await this.infra.db.query(`select 1 from users u join profiles p on p.user_id=u.id where u.id=$1 and u.status='active' and p.profile_completed=true`, [userId]);
    if (!profile.rowCount) throw new BadRequestException('Tabu için profilini tamamlamalısın.');

    const client = await this.infra.db.connect();
    let chosen: string[] = [];
    let roomId = '';
    try {
      await client.query('begin');
      await client.query('select pg_advisory_xact_lock(606064)');
      const busy = await client.query(`select 1 from room_members rm join rooms r on r.id=rm.room_id where rm.user_id=$1 and rm.left_at is null and rm.admin_removed_at is null and r.status in ('active','selection') limit 1`, [userId]);
      if (busy.rowCount) throw new BadRequestException('Önce mevcut aktif odandan çıkmalısın.');
      await client.query(`insert into tabu_matchmaking_queue(user_id,joined_at) values($1,now()) on conflict(user_id) do update set joined_at=least(tabu_matchmaking_queue.joined_at,excluded.joined_at)`, [userId]);
      const candidates = await client.query<{user_id:string}>(
        `select q.user_id::text from tabu_matchmaking_queue q
         join users u on u.id=q.user_id join profiles p on p.user_id=q.user_id
         where u.status='active' and p.profile_completed=true
           and not exists(
             select 1 from room_members rm join rooms r on r.id=rm.room_id
             where rm.user_id=q.user_id and rm.left_at is null and rm.admin_removed_at is null
               and r.status in ('active','selection'))
         order by q.joined_at asc limit 6 for update of q skip locked`,
      );
      chosen = candidates.rows.map((r) => r.user_id);
      if (chosen.length < 6) {
        await client.query('commit');
        const pos = await this.queueStatus(String(userId));
        return pos;
      }
      const created = await client.query<{id:string}>(`insert into rooms(status,started_at,ends_at,room_duration_minutes,room_mode) values('active',now(),now()+interval '8 minutes',8,'game') returning id::text`);
      roomId = created.rows[0]?.id ?? '';
      if (!roomId) throw new BadRequestException('Tabu odası oluşturulamadı.');
      for (const id of chosen) await client.query('insert into room_members(room_id,user_id) values($1,$2)', [roomId, id]);
      await client.query('delete from tabu_matchmaking_queue where user_id=any($1::bigint[])', [chosen]);
      await client.query('delete from matchmaking_queue where user_id=any($1::bigint[])', [chosen]);
      await client.query(`insert into room_messages(room_id,sender_user_id,body) values($1,null,'Mini oyun başladı: Tabu.')`, [roomId]);
      await client.query('commit');
    } catch (e) {
      await client.query('rollback').catch(() => undefined);
      throw e;
    } finally { client.release(); }

    const players = await this.profiles(chosen);
    const state = await this.initialize(roomId, players);
    return { ok: true, state: 'room', participantCount: 6, gameKey: 'tabu', room: await this.rooms.getRoom(userId, roomId), gameState: this.viewRaw(state, String(userId)) };
  }

  async queueStatus(userId: string) {
    const existing = await this.activeStateForUser(String(userId));
    if (existing) return { ok: true, state: 'room', gameKey: 'tabu', room: await this.rooms.getRoom(userId, existing.roomId), gameState: this.viewRaw(existing.state, String(userId)) };
    const rows = await this.infra.db.query<{user_id:string}>(`select user_id::text from tabu_matchmaking_queue order by joined_at asc`);
    const index = rows.rows.findIndex((r) => r.user_id === String(userId));
    return { ok: true, state: 'queued', gameKey: 'tabu', total: rows.rowCount ?? 0, position: index < 0 ? 0 : index + 1, nextRetrySeconds: 2 };
  }

  async cancelQueue(userId: string) {
    await this.infra.db.query('delete from tabu_matchmaking_queue where user_id=$1', [userId]);
    return { ok: true, state: 'idle', gameKey: 'tabu' };
  }

  private addMessage(s: State, p: Player, role: GameMessage['role'], text: string) {
    s.messageSeq += 1;
    s.messages.push({ id: s.messageSeq, userId: p.id, name: p.name, role, text, at: new Date().toISOString() });
    if (s.messages.length > 120) s.messages.splice(0, s.messages.length - 120);
  }

  private async loadCard(s: State) {
    const card = await this.words.nextCard(s.players.map((p) => p.id), s.usedCardIds.slice(-18));
    s.card = card; s.usedCardIds.push(card.id); s.wordVersion += 1; s.lastResult = null;
  }

  private async grantXp(roomId: string, userId: string, delta: number, eventKey: string) {
    if (!delta) return;
    const inserted = await this.infra.db.query(`insert into tabu_game_xp_events(room_id,user_id,event_key,delta) values($1,$2,$3,$4) on conflict(room_id,user_id,event_key) do nothing returning id`, [roomId, userId, eventKey, delta]);
    if (!inserted.rowCount) return;
    await this.infra.db.query(`insert into user_wallets(user_id,profile_xp) values($1,greatest(0,$2)) on conflict(user_id) do update set profile_xp=greatest(0,user_wallets.profile_xp+$2)`, [userId, delta]).catch(() => undefined);
  }

  private async resolveWord(s: State, result: Omit<WordResult, 'target' | 'narratorUserId' | 'narratorName'>) {
    if (s.phase !== 'play') throw new BadRequestException('Bu kelime artık aktif değil.');
    const narrator = this.narrator(s);
    const full: WordResult = { ...result, target: s.card.word, narratorUserId: narrator.id, narratorName: narrator.name };
    s.lastResult = full; s.phase = 'word_result'; s.phaseEndsAtMs = Date.now() + TabuGameService.RESULT_MS;
    const eventBase = `w${s.wordVersion}`;
    if (result.kind === 'correct') {
      s.currentTurn.correct += 1; s.currentTurn.xp += 15; s.xp[narrator.id] = (s.xp[narrator.id] ?? 0) + 15;
      await this.grantXp(s.roomId, narrator.id, 15, `${eventBase}:narrator-correct`);
      if (result.guesserUserId) { s.xp[result.guesserUserId] = (s.xp[result.guesserUserId] ?? 0) + 20; await this.grantXp(s.roomId, result.guesserUserId, 20, `${eventBase}:guesser:${result.guesserUserId}`); }
    } else if (result.kind === 'tabu') {
      s.currentTurn.tabu += 1; s.currentTurn.xp -= 10; s.xp[narrator.id] = (s.xp[narrator.id] ?? 0) - 10;
      await this.grantXp(s.roomId, narrator.id, -10, `${eventBase}:tabu`);
    } else s.currentTurn.pass += 1;
    return full;
  }

  private finishTurn(s: State) {
    if (s.phase === 'final' || s.phase === 'turn_result') return;
    s.turnStats.push({ ...s.currentTurn }); s.phase = 'turn_result'; s.phaseEndsAtMs = Date.now() + TabuGameService.RESULT_MS;
  }

  private async nextNarrator(s: State) {
    s.narratorIndex += 1;
    if (s.narratorIndex >= s.players.length) {
      s.phase = 'final'; s.phaseEndsAtMs = Date.now();
      s.finalLeaderboard = s.players.map((p) => ({ id: p.id, name: p.name, photoUrl: p.photoUrl, xp: s.xp[p.id] ?? 0 })).sort((a, b) => b.xp - a.xp || Number(a.id) - Number(b.id));
      await this.infra.db.query(`update rooms set status='closed',closed_at=coalesce(closed_at,now()),closed_reason=coalesce(closed_reason,'game_finished') where id=$1 and room_mode='game'`, [s.roomId]).catch(() => undefined);
      return;
    }
    const narrator = this.narrator(s);
    s.currentTurn = { narratorUserId: narrator.id, correct: 0, tabu: 0, pass: 0, xp: 0 };
    s.turnEndsAtMs = Date.now() + TabuGameService.TURN_MS; s.phase = 'play'; s.phaseEndsAtMs = s.turnEndsAtMs;
    await this.loadCard(s);
  }

  private async sync(s: State) {
    if (s.phase === 'final') return;
    const now = Date.now();
    if (s.phase === 'play' && now >= s.turnEndsAtMs) { this.finishTurn(s); return; }
    if (s.phase === 'word_result' && now >= s.phaseEndsAtMs) {
      if (now >= s.turnEndsAtMs) this.finishTurn(s); else { s.phase = 'play'; s.phaseEndsAtMs = s.turnEndsAtMs; await this.loadCard(s); }
      return;
    }
    if (s.phase === 'turn_result' && now >= s.phaseEndsAtMs) await this.nextNarrator(s);
  }

  private viewRaw(s: State, userId: string) {
    const narrator = this.narrator(s); const isNarrator = narrator?.id === String(userId);
    return {
      roomId: s.roomId, game: 'tabu', phase: s.phase, phaseEndsAt: new Date(s.phaseEndsAtMs).toISOString(), turnEndsAt: new Date(s.turnEndsAtMs).toISOString(),
      narratorIndex: s.narratorIndex, totalNarrators: s.players.length, narratorUserId: narrator?.id ?? null, narratorName: narrator?.name ?? '', isNarrator, meUserId: String(userId),
      ...(isNarrator && s.phase !== 'final' ? { target: s.card.word, forbidden: s.card.forbidden } : {}),
      players: s.players.map((p) => ({ id: p.id, name: p.name, photoUrl: p.photoUrl, xp: s.xp[p.id] ?? 0 })), messages: s.messages, currentTurn: s.currentTurn,
      lastResult: s.phase === 'word_result' || s.phase === 'turn_result' ? s.lastResult : null,
      leaderboard: s.phase === 'final' ? s.finalLeaderboard : [], turnStats: s.phase === 'final' ? s.turnStats : undefined, wordVersion: s.wordVersion,
    };
  }

  async state(userId: string, roomId: string) {
    const s = this.games.get(roomId); if (!s) throw new BadRequestException('Tabu oyun durumu bulunamadı. Odayı yeniden oluştur.');
    this.assertPlayer(s, userId); await this.sync(s); return this.viewRaw(s, String(userId));
  }

  async clue(userId: string, roomId: string, raw: unknown) {
    const s = this.games.get(roomId); if (!s) throw new BadRequestException('Tabu oyun durumu bulunamadı.');
    this.assertPlayer(s, userId); await this.sync(s);
    const narrator = this.narrator(s); if (narrator.id !== String(userId)) throw new ForbiddenException('Sadece anlatıcı ipucu yazabilir.');
    if (s.phase !== 'play') throw new BadRequestException('Şu an ipucu gönderilemez.');
    const text = String(raw ?? '').trim(); if (text.length < 1 || text.length > 240) throw new BadRequestException('İpucu 1-240 karakter olmalı.');
    const banned = [s.card.word, ...s.card.forbidden].find((word) => this.containsExact(text, word));
    if (banned) {
      const result = await this.resolveWord(s, { kind: 'tabu', forbiddenWord: banned, narratorXpDelta: -10, guesserXpDelta: 0 });
      return { state: this.viewRaw(s, String(userId)), event: 'tabu:forbidden_used', eventData: result };
    }
    this.addMessage(s, narrator, 'narrator', text);
    return { state: this.viewRaw(s, String(userId)), event: 'tabu:speaker_message', eventData: { roomId, message: s.messages[s.messages.length - 1] } };
  }

  async guess(userId: string, roomId: string, raw: unknown) {
    const s = this.games.get(roomId); if (!s) throw new BadRequestException('Tabu oyun durumu bulunamadı.');
    this.assertPlayer(s, userId); await this.sync(s);
    const guesser = this.player(s, userId)!; const narrator = this.narrator(s);
    if (guesser.id === narrator.id) throw new ForbiddenException('Anlatıcı tahmin gönderemez.');
    if (s.phase !== 'play') throw new BadRequestException('Bu kelime için tahmin süresi kapandı.');
    const guess = String(raw ?? '').trim(); if (guess.length < 1 || guess.length > 80) throw new BadRequestException('Tahmin 1-80 karakter olmalı.');
    this.addMessage(s, guesser, 'guesser', guess);
    if (this.normalize(guess) !== this.normalize(s.card.word)) return { state: this.viewRaw(s, String(userId)), event: 'tabu:guess_submitted', eventData: { roomId, message: s.messages[s.messages.length - 1] } };
    const lockKey = `tabu:correct:${roomId}:${s.wordVersion}`;
    const won = await this.infra.redis.set(lockKey, String(userId), 'EX', 70, 'NX');
    if (won !== 'OK' || s.phase !== 'play') return { state: this.viewRaw(s, String(userId)), event: 'tabu:guess_submitted', eventData: { roomId, message: s.messages[s.messages.length - 1], accepted: false } };
    const result = await this.resolveWord(s, { kind: 'correct', guesserUserId: guesser.id, guesserName: guesser.name, narratorXpDelta: 15, guesserXpDelta: 20 });
    return { state: this.viewRaw(s, String(userId)), event: 'tabu:correct_guess', eventData: result };
  }

  async pass(userId: string, roomId: string) {
    const s = this.games.get(roomId); if (!s) throw new BadRequestException('Tabu oyun durumu bulunamadı.');
    this.assertPlayer(s, userId); await this.sync(s);
    if (this.narrator(s).id !== String(userId)) throw new ForbiddenException('Sadece anlatıcı pas geçebilir.');
    if (s.phase !== 'play') throw new BadRequestException('Şu an pas geçilemez.');
    const result = await this.resolveWord(s, { kind: 'pass', narratorXpDelta: 0, guesserXpDelta: 0 });
    return { state: this.viewRaw(s, String(userId)), event: 'tabu:word_skipped', eventData: result };
  }

  async tick(roomId: string) {
    const s = this.games.get(roomId); if (!s) return null;
    const before = `${s.phase}:${s.narratorIndex}:${s.wordVersion}`; await this.sync(s); const after = `${s.phase}:${s.narratorIndex}:${s.wordVersion}`;
    if (before === after) return null;
    const event = s.phase === 'final' ? 'tabu:game_finished' : s.phase === 'turn_result' ? 'tabu:speaker_turn_ended' : 'tabu:round_started';
    return { event, roomId };
  }

  memberIds(roomId: string) { return this.games.get(roomId)?.players.map((p) => p.id) ?? []; }
}
