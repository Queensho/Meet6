import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { InfrastructureService } from './infrastructure.service';
import { RoomService } from './room.service';
import { TabuCard, TabuWordRepository } from './tabu-word.repository';

type Player = {
  id: string;
  name: string;
  test: boolean;
  photoUrl: string;
};

type GameMessage = {
  id: number;
  userId: string;
  name: string;
  role: 'narrator' | 'guesser';
  text: string;
  at: string;
};

type TurnStat = {
  narratorUserId: string;
  correct: number;
  tabu: number;
  pass: number;
  xp: number;
};

type WordResult = {
  kind: 'correct' | 'tabu' | 'pass';
  target: string;
  narratorUserId: string;
  narratorName: string;
  guesserUserId?: string;
  guesserName?: string;
  forbiddenWord?: string;
  narratorXpDelta: number;
  guesserXpDelta: number;
};

type State = {
  roomId: string;
  players: Player[];
  narratorIndex: number;
  turnEndsAtMs: number;
  phase: 'play' | 'word_result' | 'turn_result' | 'final';
  phaseEndsAtMs: number;
  card: TabuCard;
  usedCardIds: string[];
  wordVersion: number;
  messages: GameMessage[];
  messageSeq: number;
  xp: Record<string, number>;
  turnStats: TurnStat[];
  currentTurn: TurnStat;
  lastResult: WordResult | null;
  finalLeaderboard: Array<{
    id: string;
    name: string;
    photoUrl: string;
    xp: number;
  }>;
};

@Injectable()
export class TabuGameService {
  private readonly games = new Map<string, State>();
  private static readonly TURN_MS = 60_000;
  private static readonly RESULT_MS = 3_000;
  private static readonly MAX_MESSAGES_PER_SECOND = 6;

  constructor(
    private readonly infra: InfrastructureService,
    private readonly rooms: RoomService,
    private readonly words: TabuWordRepository,
  ) {}

  private normalize(value: string) {
    return String(value ?? '')
      .normalize('NFKC')
      .toLocaleLowerCase('tr-TR')
      .replace(/[’']/g, "'")
      .replace(/[^\p{L}\p{N}'-]+/gu, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private containsExact(text: string, needle: string) {
    const haystack = this.normalize(text);
    const target = this.normalize(needle);
    if (!haystack || !target) return false;
    return (` ${haystack} `).includes(` ${target} `);
  }

  private narrator(state: State) {
    return state.players[state.narratorIndex];
  }

  private player(state: State, userId: string) {
    return state.players.find((player) => player.id === String(userId));
  }

  private assertPlayer(state: State, userId: string) {
    if (!this.player(state, userId)) {
      throw new ForbiddenException('Bu Tabu oyununa erişimin yok.');
    }
  }

  private async checkRateLimit(roomId: string, userId: string) {
    const second = Math.floor(Date.now() / 1000);
    const key = `tabu:rate:${roomId}:${userId}:${second}`;
    const count = await this.infra.redis.incr(key);
    if (count === 1) await this.infra.redis.expire(key, 2);
    if (count > TabuGameService.MAX_MESSAGES_PER_SECOND) {
      throw new BadRequestException('Çok hızlı mesaj gönderiyorsun.');
    }
  }

  private async rejectDuplicate(
    state: State,
    userId: string,
    text: string,
    role: 'narrator' | 'guesser',
  ) {
    const normalized = this.normalize(text);
    if (!normalized) return;
    const compact = encodeURIComponent(normalized).slice(0, 160);
    const key = `tabu:spam:${state.roomId}:${state.wordVersion}:${userId}:${role}:${compact}`;
    const inserted = await this.infra.redis.set(key, '1', 'EX', 2, 'NX');
    if (inserted !== 'OK') {
      throw new BadRequestException('Aynı mesajı art arda gönderemezsin.');
    }
  }

  private async profiles(memberIds: string[]): Promise<Player[]> {
    const result = await this.infra.db.query<{
      user_id: string;
      name: string;
      photo_url: string;
    }>(
      `select u.id::text user_id,
              coalesce(nullif(trim(p.display_name),''),'Oyuncu') name,
              coalesce(p.photo_urls[1],'') photo_url
       from users u
       join profiles p on p.user_id=u.id
       where u.id=any($1::bigint[])
         and u.status='active'
         and p.profile_completed=true`,
      [memberIds],
    );

    const byId = new Map(result.rows.map((row) => [row.user_id, row]));
    if (memberIds.some((id) => !byId.has(id))) {
      throw new BadRequestException('Tabu oyuncu profillerinden biri hazır değil.');
    }

    return memberIds.map((id) => {
      const row = byId.get(id)!;
      return {
        id,
        name: row.name,
        photoUrl: row.photo_url,
        test: false,
      };
    });
  }

  private async initialize(roomId: string, players: Player[]) {
    const memberIds = players.map((player) => player.id);
    const firstCard = await this.words.nextCard(memberIds);
    const narrator = players[0];
    const turnEndsAtMs = Date.now() + TabuGameService.TURN_MS;

    const state: State = {
      roomId,
      players,
      narratorIndex: 0,
      turnEndsAtMs,
      phase: 'play',
      phaseEndsAtMs: turnEndsAtMs,
      card: firstCard,
      usedCardIds: [firstCard.id],
      wordVersion: 1,
      messages: [],
      messageSeq: 0,
      xp: Object.fromEntries(players.map((player) => [player.id, 0])),
      turnStats: [],
      currentTurn: {
        narratorUserId: narrator.id,
        correct: 0,
        tabu: 0,
        pass: 0,
        xp: 0,
      },
      lastResult: null,
      finalLeaderboard: [],
    };

    this.games.set(roomId, state);
    return state;
  }

  private async activeStateForUser(userId: string) {
    const result = await this.infra.db.query<{ room_id: string }>(
      `select rm.room_id::text
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

    const roomId = result.rows[0]?.room_id;
    if (!roomId) return null;
    const state = this.games.get(roomId);
    return state ? { roomId, state } : null;
  }

  async create(userId: string) {
    return this.joinQueue(userId);
  }

  async joinQueue(userId: string) {
    const current = await this.activeStateForUser(String(userId));
    if (current) {
      return {
        ok: true,
        state: 'room',
        gameKey: 'tabu',
        room: await this.rooms.getRoom(userId, current.roomId),
        gameState: this.view(current.state, String(userId)),
      };
    }

    const ready = await this.infra.db.query(
      `select 1
       from users u
       join profiles p on p.user_id=u.id
       where u.id=$1
         and u.status='active'
         and p.profile_completed=true`,
      [userId],
    );
    if (!ready.rowCount) {
      throw new BadRequestException('Tabu için profilini tamamlamalısın.');
    }

    const client = await this.infra.db.connect();
    let chosenIds: string[] = [];
    let roomId = '';

    try {
      await client.query('begin');
      await client.query('select pg_advisory_xact_lock(606064)');

      const busy = await client.query(
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

      await client.query(
        `insert into tabu_matchmaking_queue(user_id,joined_at)
         values($1,now())
         on conflict(user_id) do nothing`,
        [userId],
      );

      const candidates = await client.query<{ user_id: string }>(
        `select q.user_id::text
         from tabu_matchmaking_queue q
         join users u on u.id=q.user_id
         join profiles p on p.user_id=q.user_id
         where u.status='active'
           and p.profile_completed=true
           and not exists(
             select 1
             from room_members rm
             join rooms r on r.id=rm.room_id
             where rm.user_id=q.user_id
               and rm.left_at is null
               and rm.admin_removed_at is null
               and r.status in ('active','selection')
           )
         order by q.joined_at asc
         limit 6
         for update of q skip locked`,
      );

      chosenIds = candidates.rows.map((row) => row.user_id);
      if (chosenIds.length < 6) {
        await client.query('commit');
        return this.queueStatus(String(userId));
      }

      const created = await client.query<{ id: string }>(
        `insert into rooms(
           status,started_at,ends_at,room_duration_minutes,room_mode
         )
         values('active',now(),now()+interval '8 minutes',8,'game')
         returning id::text`,
      );
      roomId = created.rows[0]?.id ?? '';
      if (!roomId) throw new BadRequestException('Tabu odası oluşturulamadı.');

      for (const id of chosenIds) {
        await client.query(
          'insert into room_members(room_id,user_id) values($1,$2)',
          [roomId, id],
        );
      }

      await client.query(
        'delete from tabu_matchmaking_queue where user_id=any($1::bigint[])',
        [chosenIds],
      );
      await client.query(
        'delete from matchmaking_queue where user_id=any($1::bigint[])',
        [chosenIds],
      );
      await client.query(
        `insert into room_messages(room_id,sender_user_id,body)
         values($1,null,'Mini oyun başladı: Tabu.')`,
        [roomId],
      );
      await client.query('commit');
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }

    const players = await this.profiles(chosenIds);
    const state = await this.initialize(roomId, players);
    return {
      ok: true,
      state: 'room',
      participantCount: 6,
      gameKey: 'tabu',
      room: await this.rooms.getRoom(userId, roomId),
      gameState: this.view(state, String(userId)),
    };
  }

  async queueStatus(userId: string) {
    const current = await this.activeStateForUser(String(userId));
    if (current) {
      return {
        ok: true,
        state: 'room',
        gameKey: 'tabu',
        room: await this.rooms.getRoom(userId, current.roomId),
        gameState: this.view(current.state, String(userId)),
      };
    }

    const result = await this.infra.db.query<{ user_id: string }>(
      `select user_id::text
       from tabu_matchmaking_queue
       order by joined_at asc`,
    );
    const index = result.rows.findIndex(
      (row) => row.user_id === String(userId),
    );
    return {
      ok: true,
      state: 'queued',
      gameKey: 'tabu',
      total: result.rowCount ?? 0,
      position: index < 0 ? 0 : index + 1,
      nextRetrySeconds: 2,
    };
  }

  async cancelQueue(userId: string) {
    await this.infra.db.query(
      'delete from tabu_matchmaking_queue where user_id=$1',
      [userId],
    );
    return { ok: true, state: 'idle', gameKey: 'tabu' };
  }

  private addMessage(
    state: State,
    player: Player,
    role: GameMessage['role'],
    text: string,
  ) {
    state.messageSeq += 1;
    state.messages.push({
      id: state.messageSeq,
      userId: player.id,
      name: player.name,
      role,
      text,
      at: new Date().toISOString(),
    });
    if (state.messages.length > 120) {
      state.messages.splice(0, state.messages.length - 120);
    }
  }

  private async loadCard(state: State) {
    const card = await this.words.nextCard(
      state.players.map((player) => player.id),
      state.usedCardIds.slice(-18),
    );
    state.card = card;
    state.usedCardIds.push(card.id);
    state.wordVersion += 1;
    state.lastResult = null;
  }

  private async grantXp(
    roomId: string,
    userId: string,
    delta: number,
    eventKey: string,
  ) {
    if (!delta) return;
    const inserted = await this.infra.db.query(
      `insert into tabu_game_xp_events(room_id,user_id,event_key,delta)
       values($1,$2,$3,$4)
       on conflict(room_id,user_id,event_key) do nothing
       returning id`,
      [roomId, userId, eventKey, delta],
    );
    if (!inserted.rowCount) return;

    await this.infra.db
      .query(
        `insert into user_wallets(user_id,profile_xp)
         values($1,greatest(0,$2))
         on conflict(user_id) do update
         set profile_xp=greatest(0,user_wallets.profile_xp+$2)`,
        [userId, delta],
      )
      .catch(() => undefined);
  }

  private async resolveWord(
    state: State,
    result: Omit<WordResult, 'target' | 'narratorUserId' | 'narratorName'>,
  ) {
    if (state.phase !== 'play') {
      throw new BadRequestException('Bu kelime artık aktif değil.');
    }

    const narrator = this.narrator(state);
    const full: WordResult = {
      ...result,
      target: state.card.word,
      narratorUserId: narrator.id,
      narratorName: narrator.name,
    };

    state.lastResult = full;
    state.phase = 'word_result';
    state.phaseEndsAtMs = Date.now() + TabuGameService.RESULT_MS;
    const eventBase = `w${state.wordVersion}`;

    if (result.kind === 'correct') {
      state.currentTurn.correct += 1;
      state.currentTurn.xp += 15;
      state.xp[narrator.id] = (state.xp[narrator.id] ?? 0) + 15;
      await this.grantXp(
        state.roomId,
        narrator.id,
        15,
        `${eventBase}:narrator-correct`,
      );

      if (result.guesserUserId) {
        state.xp[result.guesserUserId] =
          (state.xp[result.guesserUserId] ?? 0) + 20;
        await this.grantXp(
          state.roomId,
          result.guesserUserId,
          20,
          `${eventBase}:guesser:${result.guesserUserId}`,
        );
      }
    } else if (result.kind === 'tabu') {
      state.currentTurn.tabu += 1;
      state.currentTurn.xp -= 10;
      state.xp[narrator.id] = (state.xp[narrator.id] ?? 0) - 10;
      await this.grantXp(
        state.roomId,
        narrator.id,
        -10,
        `${eventBase}:tabu`,
      );
    } else {
      state.currentTurn.pass += 1;
    }

    return full;
  }

  private finishTurn(state: State) {
    if (state.phase === 'final' || state.phase === 'turn_result') return;
    state.turnStats.push({ ...state.currentTurn });
    state.phase = 'turn_result';
    state.phaseEndsAtMs = Date.now() + TabuGameService.RESULT_MS;
  }

  private async nextNarrator(state: State) {
    state.narratorIndex += 1;
    if (state.narratorIndex >= state.players.length) {
      state.phase = 'final';
      state.phaseEndsAtMs = Date.now();
      state.finalLeaderboard = state.players
        .map((player) => ({
          id: player.id,
          name: player.name,
          photoUrl: player.photoUrl,
          xp: state.xp[player.id] ?? 0,
        }))
        .sort((a, b) => b.xp - a.xp || Number(a.id) - Number(b.id));

      await this.infra.db
        .query(
          `update rooms
           set status='closed',
               closed_at=coalesce(closed_at,now()),
               closed_reason=coalesce(closed_reason,'game_finished')
           where id=$1 and room_mode='game'`,
          [state.roomId],
        )
        .catch(() => undefined);
      return;
    }

    const narrator = this.narrator(state);
    state.currentTurn = {
      narratorUserId: narrator.id,
      correct: 0,
      tabu: 0,
      pass: 0,
      xp: 0,
    };
    state.turnEndsAtMs = Date.now() + TabuGameService.TURN_MS;
    state.phase = 'play';
    state.phaseEndsAtMs = state.turnEndsAtMs;
    await this.loadCard(state);
  }

  private async sync(state: State) {
    if (state.phase === 'final') return;
    const now = Date.now();

    if (state.phase === 'play' && now >= state.turnEndsAtMs) {
      this.finishTurn(state);
      return;
    }

    if (state.phase === 'word_result' && now >= state.phaseEndsAtMs) {
      if (now >= state.turnEndsAtMs) {
        this.finishTurn(state);
      } else {
        state.phase = 'play';
        state.phaseEndsAtMs = state.turnEndsAtMs;
        await this.loadCard(state);
      }
      return;
    }

    if (state.phase === 'turn_result' && now >= state.phaseEndsAtMs) {
      await this.nextNarrator(state);
    }
  }

  private view(state: State, userId: string) {
    const narrator = this.narrator(state);
    const isNarrator = narrator?.id === String(userId);

    return {
      roomId: state.roomId,
      game: 'tabu',
      phase: state.phase,
      phaseEndsAt: new Date(state.phaseEndsAtMs).toISOString(),
      turnEndsAt: new Date(state.turnEndsAtMs).toISOString(),
      narratorIndex: state.narratorIndex,
      totalNarrators: state.players.length,
      narratorUserId: narrator?.id ?? null,
      narratorName: narrator?.name ?? '',
      isNarrator,
      meUserId: String(userId),
      ...(isNarrator && state.phase !== 'final'
        ? {
            target: state.card.word,
            forbidden: state.card.forbidden,
          }
        : {}),
      players: state.players.map((player) => ({
        id: player.id,
        name: player.name,
        photoUrl: player.photoUrl,
        xp: state.xp[player.id] ?? 0,
      })),
      messages: state.messages,
      currentTurn: state.currentTurn,
      lastResult:
        state.phase === 'word_result' || state.phase === 'turn_result'
          ? state.lastResult
          : null,
      leaderboard: state.phase === 'final' ? state.finalLeaderboard : [],
      turnStats: state.phase === 'final' ? state.turnStats : undefined,
      wordVersion: state.wordVersion,
    };
  }

  async state(userId: string, roomId: string) {
    const state = this.games.get(roomId);
    if (!state) {
      throw new BadRequestException(
        'Tabu oyun durumu bulunamadı. Odayı yeniden oluştur.',
      );
    }
    this.assertPlayer(state, userId);
    await this.sync(state);
    return this.view(state, String(userId));
  }

  async clue(userId: string, roomId: string, raw: unknown) {
    const state = this.games.get(roomId);
    if (!state) throw new BadRequestException('Tabu oyun durumu bulunamadı.');
    this.assertPlayer(state, userId);
    await this.sync(state);

    const narrator = this.narrator(state);
    if (narrator.id !== String(userId)) {
      throw new ForbiddenException('Sadece anlatıcı ipucu yazabilir.');
    }
    if (state.phase !== 'play') {
      throw new BadRequestException('Şu an ipucu gönderilemez.');
    }

    const text = String(raw ?? '').trim();
    if (text.length < 1 || text.length > 240) {
      throw new BadRequestException('İpucu 1-240 karakter olmalı.');
    }

    await this.checkRateLimit(roomId, String(userId));
    await this.rejectDuplicate(state, String(userId), text, 'narrator');

    const forbidden = [state.card.word, ...state.card.forbidden].find((word) =>
      this.containsExact(text, word),
    );
    if (forbidden) {
      const result = await this.resolveWord(state, {
        kind: 'tabu',
        forbiddenWord: forbidden,
        narratorXpDelta: -10,
        guesserXpDelta: 0,
      });
      return {
        state: this.view(state, String(userId)),
        event: 'tabu:forbidden_used',
        eventData: result,
      };
    }

    this.addMessage(state, narrator, 'narrator', text);
    return {
      state: this.view(state, String(userId)),
      event: 'tabu:speaker_message',
      eventData: {
        roomId,
        message: state.messages[state.messages.length - 1],
      },
    };
  }

  async guess(userId: string, roomId: string, raw: unknown) {
    const state = this.games.get(roomId);
    if (!state) throw new BadRequestException('Tabu oyun durumu bulunamadı.');
    this.assertPlayer(state, userId);
    await this.sync(state);

    const guesser = this.player(state, userId)!;
    const narrator = this.narrator(state);
    if (guesser.id === narrator.id) {
      throw new ForbiddenException('Anlatıcı tahmin gönderemez.');
    }
    if (state.phase !== 'play') {
      throw new BadRequestException('Bu kelime için tahmin süresi kapandı.');
    }

    const guess = String(raw ?? '').trim();
    if (guess.length < 1 || guess.length > 80) {
      throw new BadRequestException('Tahmin 1-80 karakter olmalı.');
    }

    await this.checkRateLimit(roomId, String(userId));
    await this.rejectDuplicate(state, String(userId), guess, 'guesser');
    this.addMessage(state, guesser, 'guesser', guess);

    if (this.normalize(guess) !== this.normalize(state.card.word)) {
      return {
        state: this.view(state, String(userId)),
        event: 'tabu:guess_submitted',
        eventData: {
          roomId,
          message: state.messages[state.messages.length - 1],
        },
      };
    }

    const lockKey = `tabu:correct:${roomId}:${state.wordVersion}`;
    const won = await this.infra.redis.set(
      lockKey,
      String(userId),
      'EX',
      70,
      'NX',
    );

    if (won !== 'OK' || state.phase !== 'play') {
      return {
        state: this.view(state, String(userId)),
        event: 'tabu:guess_submitted',
        eventData: {
          roomId,
          message: state.messages[state.messages.length - 1],
          accepted: false,
        },
      };
    }

    const result = await this.resolveWord(state, {
      kind: 'correct',
      guesserUserId: guesser.id,
      guesserName: guesser.name,
      narratorXpDelta: 15,
      guesserXpDelta: 20,
    });
    return {
      state: this.view(state, String(userId)),
      event: 'tabu:correct_guess',
      eventData: result,
    };
  }

  async pass(userId: string, roomId: string) {
    const state = this.games.get(roomId);
    if (!state) throw new BadRequestException('Tabu oyun durumu bulunamadı.');
    this.assertPlayer(state, userId);
    await this.sync(state);

    if (this.narrator(state).id !== String(userId)) {
      throw new ForbiddenException('Sadece anlatıcı pas geçebilir.');
    }
    if (state.phase !== 'play') {
      throw new BadRequestException('Şu an pas geçilemez.');
    }

    const result = await this.resolveWord(state, {
      kind: 'pass',
      narratorXpDelta: 0,
      guesserXpDelta: 0,
    });
    return {
      state: this.view(state, String(userId)),
      event: 'tabu:word_skipped',
      eventData: result,
    };
  }

  async tick(roomId: string) {
    const state = this.games.get(roomId);
    if (!state) return null;
    const before = `${state.phase}:${state.narratorIndex}:${state.wordVersion}`;
    await this.sync(state);
    const after = `${state.phase}:${state.narratorIndex}:${state.wordVersion}`;
    if (before === after) return null;

    const event =
      state.phase === 'final'
        ? 'tabu:game_finished'
        : state.phase === 'turn_result'
          ? 'tabu:speaker_turn_ended'
          : 'tabu:round_started';
    return { event, roomId };
  }

  memberIds(roomId: string) {
    return this.games.get(roomId)?.players.map((player) => player.id) ?? [];
  }
}
