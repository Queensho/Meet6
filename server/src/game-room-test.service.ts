import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';

import { InfrastructureService } from './infrastructure.service';
import { RoomService } from './room.service';

type Player = {
  id: string;
  name: string;
  test: boolean;
  gender: string;
  lookingFor: string;
  photoUrl: string;
};
type Round = {
  ownerUserId: string;
  statements: string[];
  lieIndex: number;
  votes: Record<string, number>;
  resolved: boolean;
  result?: { lieIndex: number; correctUserIds: string[]; voteCounts: number[] };
};
type CompletedRound = {
  ownerUserId: string;
  lieIndex: number;
  votes: Record<string, number>;
};
type Suggestion = {
  partnerUserId: string;
  partnerName: string;
  partnerPhotoUrl: string;
  compatibility: number;
};
type State = {
  roomId: string;
  players: Player[];
  roundIndex: number;
  round: Round;
  xpEarned: Record<string, number>;
  completedRounds: CompletedRound[];
  finished: boolean;
  suggestions: Record<string, Suggestion>;
  finalChoices: Record<string, 'match' | 'continue'>;
  matchIds: Record<string, string>;
};

type PairScore = { a: string; b: string; score: number };

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

  private accepts(preference: string, gender: string) {
    if (preference === 'Herkes') return true;
    if (preference === 'Kadınlar') return gender === 'Kadın';
    if (preference === 'Erkekler') return gender === 'Erkek';
    return false;
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

  private async resolve(state: State) {
    if (state.round.resolved) return;
    const eligible = state.players.filter((p) => p.id !== state.round.ownerUserId);
    if (!eligible.every((p) => state.round.votes[p.id] !== undefined)) return;

    const counts = [0, 0, 0];
    for (const vote of Object.values(state.round.votes)) counts[vote]++;
    const correct = eligible
      .filter((p) => state.round.votes[p.id] === state.round.lieIndex)
      .map((p) => p.id);

    state.round.resolved = true;
    state.round.result = {
      lieIndex: state.round.lieIndex,
      correctUserIds: correct,
      voteCounts: counts,
    };
    state.completedRounds.push({
      ownerUserId: state.round.ownerUserId,
      lieIndex: state.round.lieIndex,
      votes: { ...state.round.votes },
    });

    for (const correctUserId of correct) {
      state.xpEarned[correctUserId] = (state.xpEarned[correctUserId] ?? 0) + 20;
      await this.infra.db.query(
        `insert into user_wallets(user_id,profile_xp)
         values($1,20)
         on conflict(user_id) do update
         set profile_xp=user_wallets.profile_xp+20, updated_at=now()`,
        [correctUserId],
      );
    }
  }

  private async autoVotes(state: State, exceptUserId?: string) {
    for (const player of state.players) {
      if (player.id === state.round.ownerUserId || player.id === exceptUserId) continue;
      state.round.votes[player.id] = (Number(player.id) + state.roundIndex) % 3;
    }
    await this.resolve(state);
  }

  private pairCompatibility(state: State, a: string, b: string) {
    const shared = state.completedRounds.filter((round) =>
      round.ownerUserId !== a &&
      round.ownerUserId !== b &&
      round.votes[a] !== undefined &&
      round.votes[b] !== undefined,
    );
    if (!shared.length) return 0;

    const sameAnswers = shared.filter((round) => round.votes[a] === round.votes[b]).length / shared.length;
    const sameCorrectness = shared.filter((round) =>
      (round.votes[a] === round.lieIndex) === (round.votes[b] === round.lieIndex),
    ).length / shared.length;

    const accuracy = (userId: string) => {
      const answered = state.completedRounds.filter((round) => round.votes[userId] !== undefined);
      if (!answered.length) return 0;
      return answered.filter((round) => round.votes[userId] === round.lieIndex).length / answered.length;
    };
    const accuracyCloseness = 1 - Math.abs(accuracy(a) - accuracy(b));
    return Math.max(0, Math.min(100, Math.round(
      sameAnswers * 50 + sameCorrectness * 30 + accuracyCloseness * 20,
    )));
  }

  private async buildSuggestions(state: State) {
    const ids = state.players.map((p) => p.id);
    const blocked = new Set<string>();
    const key = (a: string, b: string) => [a, b].sort().join(':');

    const blocks = await this.infra.db.query<{ a: string; b: string }>(
      `select blocker_user_id::text a, blocked_user_id::text b
       from blocked_users
       where blocker_user_id=any($1::bigint[]) or blocked_user_id=any($1::bigint[])`,
      [ids],
    );
    for (const row of blocks.rows) blocked.add(key(row.a, row.b));

    const reports = await this.infra.db.query<{ a: string; b: string }>(
      `select reporter_user_id::text a, reported_user_id::text b
       from reports
       where reporter_user_id=any($1::bigint[]) or reported_user_id=any($1::bigint[])`,
      [ids],
    );
    for (const row of reports.rows) blocked.add(key(row.a, row.b));

    const existingMatches = await this.infra.db.query<{ a: string; b: string }>(
      `select user_a_id::text a, user_b_id::text b
       from matches
       where user_a_id=any($1::bigint[]) and user_b_id=any($1::bigint[])`,
      [ids],
    );
    for (const row of existingMatches.rows) blocked.add(key(row.a, row.b));

    const pairs: PairScore[] = [];
    for (let i = 0; i < state.players.length; i++) {
      for (let j = i + 1; j < state.players.length; j++) {
        const a = state.players[i];
        const b = state.players[j];
        if (blocked.has(key(a.id, b.id))) continue;
        if (!this.accepts(a.lookingFor, b.gender) || !this.accepts(b.lookingFor, a.gender)) continue;
        pairs.push({ a: a.id, b: b.id, score: this.pairCompatibility(state, a.id, b.id) });
      }
    }
    pairs.sort((x, y) => y.score - x.score || Number(x.a) - Number(y.a) || Number(x.b) - Number(y.b));

    const bestFor = new Map<string, PairScore>();
    for (const pair of pairs) {
      if (!bestFor.has(pair.a)) bestFor.set(pair.a, pair);
      if (!bestFor.has(pair.b)) bestFor.set(pair.b, pair);
    }

    const assigned = new Set<string>();
    const chosen: PairScore[] = [];
    const other = (pair: PairScore, id: string) => pair.a === id ? pair.b : pair.a;
    const mutual = pairs.filter((pair) => {
      const aBest = bestFor.get(pair.a);
      const bBest = bestFor.get(pair.b);
      return aBest != null && bBest != null &&
        other(aBest, pair.a) === pair.b && other(bBest, pair.b) === pair.a;
    });
    for (const pair of mutual) {
      if (assigned.has(pair.a) || assigned.has(pair.b)) continue;
      chosen.push(pair);
      assigned.add(pair.a);
      assigned.add(pair.b);
    }
    for (const pair of pairs) {
      if (assigned.has(pair.a) || assigned.has(pair.b)) continue;
      chosen.push(pair);
      assigned.add(pair.a);
      assigned.add(pair.b);
    }

    state.suggestions = {};
    for (const pair of chosen) {
      const a = state.players.find((p) => p.id === pair.a)!;
      const b = state.players.find((p) => p.id === pair.b)!;
      state.suggestions[a.id] = {
        partnerUserId: b.id,
        partnerName: b.name,
        partnerPhotoUrl: b.photoUrl,
        compatibility: pair.score,
      };
      state.suggestions[b.id] = {
        partnerUserId: a.id,
        partnerName: a.name,
        partnerPhotoUrl: a.photoUrl,
        compatibility: pair.score,
      };
    }

    const human = state.players.find((p) => !p.test);
    if (human) {
      const suggestion = state.suggestions[human.id];
      const bot = suggestion && state.players.find((p) => p.id === suggestion.partnerUserId && p.test);
      if (bot && state.suggestions[bot.id]?.partnerUserId === human.id) {
        state.finalChoices[bot.id] = 'match';
      }
    }
  }

  private finalDecision(state: State, userId: string) {
    const suggestion = state.suggestions[userId];
    if (!suggestion) return { status: 'none' };
    const matchId = state.matchIds[userId];
    if (matchId) return { status: 'matched', matchId };
    const choice = state.finalChoices[userId];
    const partnerChoice = state.finalChoices[suggestion.partnerUserId];
    if (choice === 'continue') return { status: 'continue' };
    if (choice === 'match' && partnerChoice === 'continue') return { status: 'no_match' };
    if (choice === 'match') return { status: 'waiting' };
    return { status: 'pending' };
  }

  private view(state: State, userId: string) {
    const owner = state.players.find((p) => p.id === state.round.ownerUserId);
    const leaderboard = state.players
      .map((p) => ({ id: p.id, name: p.name, photoUrl: p.photoUrl, xp: state.xpEarned[p.id] ?? 0 }))
      .sort((a, b) => b.xp - a.xp || Number(a.id) - Number(b.id));
    return {
      roomId: state.roomId,
      game: 'two_truths_one_lie',
      roundIndex: state.roundIndex,
      totalRounds: 6,
      players: state.players.map((p) => ({ id: p.id, name: p.name, photoUrl: p.photoUrl })),
      ownerUserId: state.round.ownerUserId,
      ownerName: owner?.name ?? 'Oyuncu',
      isMyTurn: state.round.ownerUserId === userId,
      phase: state.finished ? 'final' : state.round.resolved ? 'result' : state.round.statements.length === 3 ? 'vote' : 'write',
      statements: state.round.statements,
      myVote: state.round.votes[userId] ?? null,
      votes: state.round.votes,
      result: state.round.result ?? null,
      xpEarned: state.xpEarned,
      leaderboard,
      recommendation: state.finished ? state.suggestions[userId] ?? null : null,
      finalDecision: state.finished ? this.finalDecision(state, userId) : null,
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
      const profiles = await client.query<{
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
      for (const id of memberIds) {
        await client.query('insert into room_members(room_id,user_id) values($1,$2)', [roomId, id]);
      }
      await client.query('delete from matchmaking_queue where user_id=any($1::bigint[])', [memberIds]);
      await client.query(
        `insert into room_messages(room_id,sender_user_id,body)
         values($1,null,'Mini oyun başladı: İki Doğru Bir Yalan.')`,
        [roomId],
      );
      await client.query('commit');

      const byId = new Map(profiles.rows.map((r) => [r.user_id, r]));
      const players = memberIds.map((id) => {
        const row = byId.get(id)!;
        return {
          id,
          name: row.name,
          test: id !== String(userId),
          gender: row.gender,
          lookingFor: row.looking_for,
          photoUrl: row.photo_url,
        };
      });
      const state: State = {
        roomId,
        players,
        roundIndex: 0,
        round: this.round(players, 0),
        xpEarned: Object.fromEntries(players.map((p) => [p.id, 0])),
        completedRounds: [],
        finished: false,
        suggestions: {},
        finalChoices: {},
        matchIds: {},
      };
      this.games.set(roomId, state);
      return {
        ok: true,
        state: 'room',
        testMode: true,
        participantCount: 6,
        room: await this.rooms.getRoom(userId, roomId),
        gameState: this.view(state, String(userId)),
      };
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
    if (state.round.resolved) throw new BadRequestException('Bu tur tamamlandı.');
    if (state.round.ownerUserId !== String(userId)) throw new BadRequestException('Şu an sıra sende değil.');
    if (!Array.isArray(statements) || statements.length !== 3) throw new BadRequestException('Tam 3 ifade girmelisin.');
    const clean = statements.map((v) => String(v ?? '').trim());
    if (clean.some((v) => v.length < 2 || v.length > 120)) throw new BadRequestException('İfadeler 2-120 karakter arasında olmalı.');
    const lie = Number(lieIndex);
    if (![0, 1, 2].includes(lie)) throw new BadRequestException('Yalan olan ifadeyi seç.');
    state.round.statements = clean;
    state.round.lieIndex = lie;
    await this.autoVotes(state);
    return this.view(state, String(userId));
  }

  private async finalChoice(userId: string, state: State, raw: unknown) {
    const choice = String(raw ?? '');
    if (!['match', 'continue'].includes(choice)) throw new BadRequestException('Geçerli final seçimi gönder.');
    const suggestion = state.suggestions[String(userId)];
    if (!suggestion) throw new BadRequestException('Bu oyun için uygun eşleşme önerisi bulunamadı.');
    state.finalChoices[String(userId)] = choice as 'match' | 'continue';

    if (choice === 'match') {
      const partnerId = suggestion.partnerUserId;
      if (state.finalChoices[partnerId] === 'match' && state.suggestions[partnerId]?.partnerUserId === String(userId)) {
        const inserted = await this.infra.db.query<{ id: string }>(
          `insert into matches(user_a_id,user_b_id,source_room_id)
           values($1,$2,$3) on conflict do nothing returning id::text`,
          [userId, partnerId, state.roomId],
        );
        let matchId = inserted.rows[0]?.id;
        if (!matchId) {
          const existing = await this.infra.db.query<{ id: string }>(
            `select id::text from matches
             where (user_a_id=$1 and user_b_id=$2) or (user_a_id=$2 and user_b_id=$1)
             order by id desc limit 1`,
            [userId, partnerId],
          );
          matchId = existing.rows[0]?.id;
        }
        if (matchId) {
          state.matchIds[String(userId)] = matchId;
          state.matchIds[partnerId] = matchId;
          await this.infra.db.query(
            `insert into notifications(user_id,type,title,body,data)
             values
             ($1,'match','Eşleştiniz 💚',$3,jsonb_build_object('matchId',$4::text,'userId',$2::text)),
             ($2,'match','Eşleştiniz 💚',$5,jsonb_build_object('matchId',$4::text,'userId',$1::text))`,
            [userId, partnerId, `${suggestion.partnerName} ile oyun uyumunuz karşılıklı eşleşti.`, matchId,
              `${state.players.find((p) => p.id === String(userId))?.name ?? 'Bir oyuncu'} ile oyun uyumunuz karşılıklı eşleşti.`],
          );
        }
      }
    }
    return this.view(state, String(userId));
  }

  async vote(userId: string, roomId: string, choice: unknown) {
    await this.assertMember(userId, roomId);
    const state = this.games.get(roomId);
    if (!state) throw new BadRequestException('Mini oyun durumu bulunamadı.');

    if (state.finished && choice && typeof choice === 'object') {
      return this.finalChoice(userId, state, (choice as Record<string, unknown>).finalChoice);
    }
    if (state.finished) throw new BadRequestException('Oyun tamamlandı.');
    if (state.round.resolved) throw new BadRequestException('Bu tur tamamlandı.');
    if (state.round.statements.length !== 3) throw new BadRequestException('Oylama henüz başlamadı.');
    if (state.round.ownerUserId === String(userId)) throw new BadRequestException('Kendi turunda oy kullanamazsın.');
    const selected = Number(choice);
    if (![0, 1, 2].includes(selected)) throw new BadRequestException('Geçerli bir ifade seç.');
    state.round.votes[String(userId)] = selected;
    await this.autoVotes(state, String(userId));
    return this.view(state, String(userId));
  }

  async nextRound(userId: string, roomId: string) {
    await this.assertMember(userId, roomId);
    const state = this.games.get(roomId);
    if (!state) throw new BadRequestException('Mini oyun durumu bulunamadı.');
    if (state.finished) return this.view(state, String(userId));
    if (!state.round.resolved) throw new BadRequestException('Önce mevcut turu tamamla.');

    if (state.roundIndex >= 5) {
      state.finished = true;
      await this.buildSuggestions(state);
      return this.view(state, String(userId));
    }
    state.roundIndex += 1;
    state.round = this.round(state.players, state.roundIndex);
    return this.view(state, String(userId));
  }
}
