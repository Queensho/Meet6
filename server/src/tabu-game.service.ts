import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { InfrastructureService } from './infrastructure.service';
import { RoomService } from './room.service';

type Player = { id: string; name: string; test: boolean; photoUrl: string };
type TabuCard = { target: string; forbidden: string[] };
type GameMessage = {
  id: number;
  userId: string;
  name: string;
  role: 'narrator' | 'guesser' | 'system';
  text: string;
  at: string;
};
type TurnStat = { narratorUserId: string; correct: number; tabu: number; pass: number; xp: number };
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
  cardIndex: number;
  card: TabuCard;
  wordStartedAtMs: number;
  messages: GameMessage[];
  messageSeq: number;
  xp: Record<string, number>;
  turnStats: TurnStat[];
  currentTurn: TurnStat;
  lastResult: WordResult | null;
  finalLeaderboard: Array<{ id: string; name: string; photoUrl: string; xp: number }>;
};

@Injectable()
export class TabuGameService {
  private readonly games = new Map<string, State>();
  private static readonly TURN_MS = 60_000;
  private static readonly RESULT_MS = 3_000;

  private readonly cards: TabuCard[] = [
    { target: 'KAHVE', forbidden: ['fincan', 'kafe', 'sabah', 'içecek'] },
    { target: 'TELEFON', forbidden: ['arama', 'mesaj', 'ekran', 'mobil'] },
    { target: 'DENİZ', forbidden: ['su', 'dalga', 'sahil', 'yüzmek'] },
    { target: 'PİZZA', forbidden: ['peynir', 'dilim', 'italya', 'hamur'] },
    { target: 'KEDİ', forbidden: ['miyav', 'pati', 'hayvan', 'tüy'] },
    { target: 'UÇAK', forbidden: ['hava', 'pilot', 'uçmak', 'havalimanı'] },
    { target: 'FUTBOL', forbidden: ['top', 'gol', 'maç', 'takım'] },
    { target: 'ÇİKOLATA', forbidden: ['tatlı', 'kakao', 'şeker', 'kahverengi'] },
    { target: 'DOKTOR', forbidden: ['hastane', 'hasta', 'muayene', 'sağlık'] },
    { target: 'GÜNEŞ', forbidden: ['sıcak', 'gökyüzü', 'yaz', 'ışık'] },
    { target: 'KİTAP', forbidden: ['okumak', 'sayfa', 'yazar', 'roman'] },
    { target: 'ARABA', forbidden: ['tekerlek', 'sürmek', 'motor', 'yol'] },
    { target: 'MÜZİK', forbidden: ['şarkı', 'ses', 'dinlemek', 'ritim'] },
    { target: 'YAĞMUR', forbidden: ['ıslak', 'bulut', 'şemsiye', 'damla'] },
    { target: 'DONDURMA', forbidden: ['soğuk', 'külah', 'yaz', 'tatlı'] },
    { target: 'OKUL', forbidden: ['öğrenci', 'öğretmen', 'ders', 'sınıf'] },
    { target: 'SAAT', forbidden: ['zaman', 'dakika', 'kol', 'alarm'] },
    { target: 'BİSİKLET', forbidden: ['pedal', 'tekerlek', 'sürmek', 'zincir'] },
    { target: 'SİNEMA', forbidden: ['film', 'perde', 'salon', 'bilet'] },
    { target: 'EKMEK', forbidden: ['fırın', 'un', 'kahvaltı', 'dilim'] },
    { target: 'KÖPEK', forbidden: ['havlamak', 'pati', 'hayvan', 'tasmalı'] },
    { target: 'TATİL', forbidden: ['otel', 'seyahat', 'yaz', 'dinlenmek'] },
    { target: 'BİLGİSAYAR', forbidden: ['klavye', 'ekran', 'mouse', 'internet'] },
    { target: 'ÇAY', forbidden: ['bardak', 'demlik', 'sıcak', 'içecek'] },
    { target: 'AYNA', forbidden: ['yansıma', 'cam', 'bakmak', 'yüz'] },
    { target: 'MARKET', forbidden: ['alışveriş', 'ürün', 'kasa', 'sepet'] },
    { target: 'PASTA', forbidden: ['doğum günü', 'mum', 'tatlı', 'krem'] },
    { target: 'KAR', forbidden: ['beyaz', 'kış', 'soğuk', 'yağmak'] },
    { target: 'MOTOR', forbidden: ['iki teker', 'kask', 'sürmek', 'benzin'] },
    { target: 'ANAHTAR', forbidden: ['kapı', 'kilit', 'açmak', 'metal'] },
    { target: 'BALIK', forbidden: ['deniz', 'yüzmek', 'olta', 'akvaryum'] },
    { target: 'ÇİÇEK', forbidden: ['koku', 'bahçe', 'gül', 'bitki'] },
    { target: 'KOLTUK', forbidden: ['oturmak', 'salon', 'mobilya', 'kanepe'] },
    { target: 'DİŞ', forbidden: ['fırça', 'ağız', 'dişçi', 'beyaz'] },
    { target: 'AYAKKABI', forbidden: ['giymek', 'ayak', 'bağcık', 'spor'] },
    { target: 'KAMERA', forbidden: ['fotoğraf', 'çekmek', 'lens', 'video'] },
  ];

  constructor(private readonly infra: InfrastructureService, private readonly rooms: RoomService) {}

  private testIds(currentUserId: string) {
    if (process.env.GAME_ROOM_TEST_ENABLED !== 'true') {
      throw new ForbiddenException('Mini oyun test odası sunucuda kapalı.');
    }
    const ids = (process.env.GAME_ROOM_TEST_USER_IDS ?? '')
      .split(',')
      .map((v) => v.trim())
      .filter((v) => /^\d+$/.test(v) && v !== currentUserId);
    const unique = [...new Set(ids)];
    if (unique.length !== 5) {
      throw new BadRequestException('GAME_ROOM_TEST_USER_IDS içinde mevcut kullanıcı hariç tam 5 test kullanıcı ID olmalı.');
    }
    return unique;
  }

  private normalize(value: string) {
    return value
      .toLocaleLowerCase('tr-TR')
      .normalize('NFKD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9çğıöşü\s]/gi, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private containsForbidden(text: string, card: TabuCard) {
    const normalized = this.normalize(text);
    const tokens = normalized.split(' ').filter(Boolean);
    const banned = [card.target, ...card.forbidden].map((v) => this.normalize(v));
    for (const bannedWord of banned) {
      if (!bannedWord) continue;
      if (bannedWord.includes(' ')) {
        if (normalized.includes(bannedWord)) return bannedWord;
        continue;
      }
      if (tokens.some((token) => token === bannedWord || token.startsWith(bannedWord))) return bannedWord;
    }
    return null;
  }

  private narrator(state: State) {
    return state.players[state.narratorIndex];
  }

  private nextCard(state: State) {
    state.cardIndex = (state.cardIndex + 1) % this.cards.length;
    state.card = this.cards[state.cardIndex];
    state.wordStartedAtMs = Date.now();
    state.lastResult = null;
    const narrator = this.narrator(state);
    if (narrator?.test) {
      this.addMessage(state, narrator, 'narrator', 'Bu kelimeyi günlük hayatta sık kullanırız.');
    }
  }

  private addMessage(state: State, player: Player | null, role: GameMessage['role'], text: string) {
    state.messageSeq += 1;
    state.messages.push({
      id: state.messageSeq,
      userId: player?.id ?? '',
      name: player?.name ?? 'Meet6',
      role,
      text,
      at: new Date().toISOString(),
    });
    if (state.messages.length > 120) state.messages.splice(0, state.messages.length - 120);
  }

  private resolveWord(
    state: State,
    result: Omit<WordResult, 'target' | 'narratorUserId' | 'narratorName'>,
  ) {
    const narrator = this.narrator(state);
    if (!narrator || state.phase !== 'play') return;
    const full: WordResult = {
      ...result,
      target: state.card.target,
      narratorUserId: narrator.id,
      narratorName: narrator.name,
    };
    state.lastResult = full;
    state.phase = 'word_result';
    state.phaseEndsAtMs = Date.now() + TabuGameService.RESULT_MS;

    if (result.kind === 'correct') {
      state.currentTurn.correct += 1;
      state.currentTurn.xp += 15;
      state.xp[narrator.id] = (state.xp[narrator.id] ?? 0) + 15;
      if (result.guesserUserId) {
        state.xp[result.guesserUserId] = (state.xp[result.guesserUserId] ?? 0) + 20;
      }
    } else if (result.kind === 'tabu') {
      state.currentTurn.tabu += 1;
      state.currentTurn.xp -= 10;
      state.xp[narrator.id] = (state.xp[narrator.id] ?? 0) - 10;
    } else {
      state.currentTurn.pass += 1;
    }
  }

  private finishTurn(state: State) {
    if (state.phase === 'final') return;
    state.turnStats.push({ ...state.currentTurn });
    state.phase = 'turn_result';
    state.phaseEndsAtMs = Date.now() + TabuGameService.RESULT_MS;
  }

  private startNextNarrator(state: State) {
    state.narratorIndex += 1;
    if (state.narratorIndex >= state.players.length) {
      state.phase = 'final';
      state.phaseEndsAtMs = Date.now();
      state.finalLeaderboard = state.players
        .map((p) => ({ id: p.id, name: p.name, photoUrl: p.photoUrl, xp: state.xp[p.id] ?? 0 }))
        .sort((a, b) => b.xp - a.xp || Number(a.id) - Number(b.id));
      return;
    }
    const narrator = this.narrator(state);
    state.currentTurn = { narratorUserId: narrator.id, correct: 0, tabu: 0, pass: 0, xp: 0 };
    state.turnEndsAtMs = Date.now() + TabuGameService.TURN_MS;
    state.phase = 'play';
    state.phaseEndsAtMs = state.turnEndsAtMs;
    this.nextCard(state);
  }

  private maybeAutoTestAction(state: State) {
    if (state.phase !== 'play') return;
    const narrator = this.narrator(state);
    if (!narrator) return;
    const elapsed = Date.now() - state.wordStartedAtMs;

    if (narrator.test && elapsed >= 6_000) {
      const guesser = state.players.find((p) => p.id !== narrator.id && p.test) ?? state.players.find((p) => p.id !== narrator.id);
      if (!guesser) return;
      this.addMessage(state, guesser, 'guesser', state.card.target);
      this.resolveWord(state, {
        kind: 'correct',
        guesserUserId: guesser.id,
        guesserName: guesser.name,
        narratorXpDelta: 15,
        guesserXpDelta: 20,
      });
      return;
    }

    if (!narrator.test) {
      const hasHumanClue = state.messages.some(
        (m) => m.userId === narrator.id && m.role === 'narrator' && new Date(m.at).getTime() >= state.wordStartedAtMs,
      );
      if (hasHumanClue && elapsed >= 8_000) {
        const guesser = state.players.find((p) => p.test && p.id !== narrator.id);
        if (!guesser) return;
        this.addMessage(state, guesser, 'guesser', state.card.target);
        this.resolveWord(state, {
          kind: 'correct',
          guesserUserId: guesser.id,
          guesserName: guesser.name,
          narratorXpDelta: 15,
          guesserXpDelta: 20,
        });
      }
    }
  }

  private sync(state: State) {
    if (state.phase === 'final') return;
    const now = Date.now();
    if (now >= state.turnEndsAtMs && state.phase !== 'turn_result') {
      this.finishTurn(state);
      return;
    }
    if (state.phase === 'word_result' && now >= state.phaseEndsAtMs) {
      if (now >= state.turnEndsAtMs) this.finishTurn(state);
      else {
        state.phase = 'play';
        state.phaseEndsAtMs = state.turnEndsAtMs;
        this.nextCard(state);
      }
      return;
    }
    if (state.phase === 'turn_result' && now >= state.phaseEndsAtMs) {
      this.startNextNarrator(state);
      return;
    }
    this.maybeAutoTestAction(state);
  }

  private view(state: State, userId: string) {
    this.sync(state);
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
      target: isNarrator && state.phase !== 'final' ? state.card.target : null,
      forbidden: isNarrator && state.phase !== 'final' ? state.card.forbidden : [],
      players: state.players.map((p) => ({ id: p.id, name: p.name, photoUrl: p.photoUrl, xp: state.xp[p.id] ?? 0 })),
      messages: state.messages,
      currentTurn: state.currentTurn,
      lastResult: state.lastResult,
      leaderboard: state.phase === 'final'
        ? state.finalLeaderboard
        : state.players
            .map((p) => ({ id: p.id, name: p.name, photoUrl: p.photoUrl, xp: state.xp[p.id] ?? 0 }))
            .sort((a, b) => b.xp - a.xp || Number(a.id) - Number(b.id)),
    };
  }

  private async assertMember(userId: string, roomId: string) {
    const result = await this.infra.db.query(
      `select 1 from room_members rm join rooms r on r.id=rm.room_id
       where rm.room_id=$1 and rm.user_id=$2 and rm.left_at is null
         and rm.admin_removed_at is null and r.room_mode='game'`,
      [roomId, userId],
    );
    if (!result.rowCount) throw new ForbiddenException('Bu Tabu odasına erişimin yok.');
  }

  async create(userId: string) {
    const testIds = this.testIds(String(userId));
    const memberIds = [String(userId), ...testIds];
    const client = await this.infra.db.connect();
    try {
      await client.query('begin');
      await client.query('select pg_advisory_xact_lock(606063)');
      const profiles = await client.query<{ user_id: string; name: string; photo_url: string }>(
        `select u.id::text user_id,
                coalesce(nullif(trim(p.display_name),''),'Oyuncu') name,
                coalesce(p.photo_urls[1],'') photo_url
         from users u join profiles p on p.user_id=u.id
         where u.id=any($1::bigint[]) and u.status='active' and p.profile_completed=true`,
        [memberIds],
      );
      const ready = new Set(profiles.rows.map((r) => r.user_id));
      const missing = memberIds.filter((id) => !ready.has(id));
      if (missing.length) throw new BadRequestException(`Mini oyun test kullanıcıları hazır değil: ${missing.join(', ')}`);
      const busy = await client.query(
        `select 1 from room_members rm join rooms r on r.id=rm.room_id
         where rm.user_id=$1 and rm.left_at is null and rm.admin_removed_at is null
           and r.status in ('active','selection') limit 1`,
        [userId],
      );
      if (busy.rowCount) throw new BadRequestException('Önce mevcut aktif odandan çıkmalısın.');
      await client.query(
        `update room_members rm set left_at=now() from rooms r
         where rm.room_id=r.id and rm.user_id=any($1::bigint[])
           and rm.left_at is null and rm.admin_removed_at is null
           and r.status in ('active','selection')`,
        [testIds],
      );
      const created = await client.query<{ id: string }>(
        `insert into rooms(status,started_at,ends_at,room_duration_minutes,room_mode)
         values('active',now(),now()+interval '15 minutes',15,'game') returning id::text`,
      );
      const roomId = created.rows[0]?.id;
      if (!roomId) throw new BadRequestException('Tabu odası oluşturulamadı.');
      for (const id of memberIds) await client.query('insert into room_members(room_id,user_id) values($1,$2)', [roomId, id]);
      await client.query('delete from matchmaking_queue where user_id=any($1::bigint[])', [memberIds]);
      await client.query(
        `insert into room_messages(room_id,sender_user_id,body)
         values($1,null,'Meet6 Tabu başladı. 6 kişi • 60 sn anlatıcı • yazılı anlatım ve tahmin.')`,
        [roomId],
      );
      await client.query('commit');

      const byId = new Map(profiles.rows.map((r) => [r.user_id, r]));
      const players: Player[] = memberIds.map((id) => {
        const row = byId.get(id)!;
        return { id, name: row.name, photoUrl: row.photo_url, test: id !== String(userId) };
      });
      const narrator = players[0];
      const started = Date.now();
      const state: State = {
        roomId,
        players,
        narratorIndex: 0,
        turnEndsAtMs: started + TabuGameService.TURN_MS,
        phase: 'play',
        phaseEndsAtMs: started + TabuGameService.TURN_MS,
        cardIndex: Math.floor(Math.random() * this.cards.length),
        card: this.cards[0],
        wordStartedAtMs: started,
        messages: [],
        messageSeq: 0,
        xp: Object.fromEntries(players.map((p) => [p.id, 0])),
        turnStats: [],
        currentTurn: { narratorUserId: narrator.id, correct: 0, tabu: 0, pass: 0, xp: 0 },
        lastResult: null,
        finalLeaderboard: [],
      };
      state.card = this.cards[state.cardIndex];
      this.games.set(roomId, state);
      return {
        ok: true,
        state: 'room',
        testMode: true,
        participantCount: 6,
        gameKey: 'tabu',
        room: await this.rooms.getRoom(userId, roomId),
        gameState: this.view(state, String(userId)),
      };
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }

  async state(userId: string, roomId: string) {
    await this.assertMember(userId, roomId);
    const state = this.games.get(roomId);
    if (!state) throw new BadRequestException('Tabu oyun durumu bulunamadı. Odayı yeniden oluştur.');
    return this.view(state, String(userId));
  }

  async clue(userId: string, roomId: string, raw: unknown) {
    await this.assertMember(userId, roomId);
    const state = this.games.get(roomId);
    if (!state) throw new BadRequestException('Tabu oyun durumu bulunamadı.');
    this.sync(state);
    if (state.phase !== 'play') throw new BadRequestException('Şu anda anlatım gönderilemez.');
    const narrator = this.narrator(state);
    if (narrator?.id !== String(userId)) throw new ForbiddenException('Bu turda anlatıcı değilsin.');
    const text = String(raw ?? '').trim();
    if (text.length < 2 || text.length > 240) throw new BadRequestException('Anlatım 2-240 karakter arasında olmalı.');
    const forbiddenWord = this.containsForbidden(text, state.card);
    this.addMessage(state, narrator, 'narrator', text);
    if (forbiddenWord) {
      this.resolveWord(state, {
        kind: 'tabu',
        forbiddenWord,
        narratorXpDelta: -10,
        guesserXpDelta: 0,
      });
    }
    return this.view(state, String(userId));
  }

  async guess(userId: string, roomId: string, raw: unknown) {
    await this.assertMember(userId, roomId);
    const state = this.games.get(roomId);
    if (!state) throw new BadRequestException('Tabu oyun durumu bulunamadı.');
    this.sync(state);
    if (state.phase !== 'play') throw new BadRequestException('Bu kelime için tahmin süresi kapandı.');
    const narrator = this.narrator(state);
    if (narrator?.id === String(userId)) throw new ForbiddenException('Anlatıcı tahmin gönderemez.');
    const player = state.players.find((p) => p.id === String(userId));
    if (!player) throw new ForbiddenException('Oyuncu bulunamadı.');
    const text = String(raw ?? '').trim();
    if (text.length < 1 || text.length > 80) throw new BadRequestException('Tahmin 1-80 karakter arasında olmalı.');
    this.addMessage(state, player, 'guesser', text);
    if (this.normalize(text) === this.normalize(state.card.target)) {
      this.resolveWord(state, {
        kind: 'correct',
        guesserUserId: player.id,
        guesserName: player.name,
        narratorXpDelta: 15,
        guesserXpDelta: 20,
      });
    }
    return this.view(state, String(userId));
  }

  async pass(userId: string, roomId: string) {
    await this.assertMember(userId, roomId);
    const state = this.games.get(roomId);
    if (!state) throw new BadRequestException('Tabu oyun durumu bulunamadı.');
    this.sync(state);
    if (state.phase !== 'play') throw new BadRequestException('Şu anda pas geçilemez.');
    const narrator = this.narrator(state);
    if (narrator?.id !== String(userId)) throw new ForbiddenException('Sadece anlatıcı pas geçebilir.');
    this.resolveWord(state, { kind: 'pass', narratorXpDelta: 0, guesserXpDelta: 0 });
    return this.view(state, String(userId));
  }
}
