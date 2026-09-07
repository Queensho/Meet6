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
type Question = {
  id: string;
  prompt: string;
  category: string;
  difficulty: string;
};
type Choice = 'red' | 'green';
type AnswerRound = {
  questionId: string;
  prompt: string;
  category: string;
  choices: Record<string, Choice>;
};
type Suggestion = {
  partnerUserId: string;
  partnerName: string;
  partnerPhotoUrl: string;
  compatibility: number;
  sameAnswers: number;
  differentAnswers: number;
};
type State = {
  roomId: string;
  players: Player[];
  questions: Question[];
  questionIndex: number;
  phase: 'choice' | 'discussion' | 'final';
  phaseEndsAt: Date;
  choices: Record<string, Choice>;
  answers: AnswerRound[];
  suggestions: Record<string, Suggestion>;
  finalChoices: Record<string, 'match' | 'continue'>;
  matchIds: Record<string, string>;
};
type PairScore = { a: string; b: string; score: number; same: number; different: number };

@Injectable()
export class RedFlagGameService {
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

  private botChoice(userId: string, questionId: string): Choice {
    return (Number(userId) + Number(questionId)) % 3 === 0 ? 'red' : 'green';
  }

  private startQuestion(state: State) {
    state.phase = 'choice';
    state.phaseEndsAt = new Date(Date.now() + 15_000);
    state.choices = {};
    const question = state.questions[state.questionIndex];
    for (const player of state.players.filter((p) => p.test)) {
      state.choices[player.id] = this.botChoice(player.id, question.id);
    }
  }

  private async chooseQuestions(userId: string, age: number) {
    const candidateResult = await this.infra.db.query<Question>(
      `select q.id::text, q.prompt, q.category, q.difficulty
       from red_flag_questions q
       where q.active=true and q.admin_approved=true and q.safe=true
         and q.min_age <= $2
         and (q.max_age is null or q.max_age >= $2)
         and not exists (
           select 1 from red_flag_question_history h
           where h.user_id=$1 and h.question_id=q.id
             and h.seen_at > now()-interval '30 days'
         )
       order by random()
       limit 36`,
      [userId, age],
    );

    let pool = [...candidateResult.rows];
    if (pool.length < 6) {
      const fallback = await this.infra.db.query<Question>(
        `select q.id::text, q.prompt, q.category, q.difficulty
         from red_flag_questions q
         where q.active=true and q.admin_approved=true and q.safe=true
           and q.min_age <= $1
           and (q.max_age is null or q.max_age >= $1)
         order by random()
         limit 48`,
        [age],
      );
      const seen = new Set(pool.map((q) => q.id));
      pool.push(...fallback.rows.filter((q) => !seen.has(q.id)));
    }
    if (pool.length < 6) throw new BadRequestException('Red Flag / Green Flag soru havuzunda yeterli onaylı soru yok.');

    const selected: Question[] = [];
    while (selected.length < 6 && pool.length) {
      const previousCategory = selected.lastOrNull?.category;
      let index = pool.findIndex((q) => q.category !== previousCategory);
      if (index < 0) index = 0;
      selected.push(pool.splice(index, 1)[0]);
    }
    return selected;
  }

  private async finishChoice(state: State) {
    if (state.phase !== 'choice') return;
    const q = state.questions[state.questionIndex];
    for (const player of state.players) {
      state.choices[player.id] ??= this.botChoice(player.id, q.id);
    }
    state.answers.push({
      questionId: q.id,
      prompt: q.prompt,
      category: q.category,
      choices: { ...state.choices },
    });
    const red = Object.values(state.choices).filter((v) => v === 'red').length;
    const green = Object.values(state.choices).filter((v) => v === 'green').length;
    state.phase = 'discussion';
    state.phaseEndsAt = new Date(Date.now() + 120_000);
    await this.infra.db.query(
      `insert into room_messages(room_id,sender_user_id,body)
       values($1,null,$2)`,
      [state.roomId, `Sonuç: ${red} Red / ${green} Green. 2 dakikalık tartışma başladı.`],
    );
  }

  private pairCompatibility(state: State, a: string, b: string) {
    const same = state.answers.filter((r) => r.choices[a] === r.choices[b]).length;
    const different = state.answers.length - same;
    const score = state.answers.length ? Math.round((same / state.answers.length) * 100) : 0;
    return { score, same, different };
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
        const c = this.pairCompatibility(state, a.id, b.id);
        pairs.push({ a: a.id, b: b.id, score: c.score, same: c.same, different: c.different });
      }
    }
    pairs.sort((x, y) => y.score - x.score || Number(x.a) - Number(y.a) || Number(x.b) - Number(y.b));

    const bestFor = new Map<string, PairScore>();
    for (const pair of pairs) {
      if (!bestFor.has(pair.a)) bestFor.set(pair.a, pair);
      if (!bestFor.has(pair.b)) bestFor.set(pair.b, pair);
    }
    const other = (pair: PairScore, id: string) => pair.a === id ? pair.b : pair.a;
    const assigned = new Set<string>();
    const chosen: PairScore[] = [];
    for (const pair of pairs.filter((pair) => {
      const aBest = bestFor.get(pair.a);
      const bBest = bestFor.get(pair.b);
      return aBest && bBest && other(aBest, pair.a) === pair.b && other(bBest, pair.b) === pair.a;
    })) {
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
        sameAnswers: pair.same,
        differentAnswers: pair.different,
      };
      state.suggestions[b.id] = {
        partnerUserId: a.id,
        partnerName: a.name,
        partnerPhotoUrl: a.photoUrl,
        compatibility: pair.score,
        sameAnswers: pair.same,
        differentAnswers: pair.different,
      };
    }

    const human = state.players.find((p) => !p.test);
    if (human) {
      const rec = state.suggestions[human.id];
      const bot = rec && state.players.find((p) => p.id === rec.partnerUserId && p.test);
      if (bot && state.suggestions[bot.id]?.partnerUserId === human.id) {
        state.finalChoices[bot.id] = 'match';
      }
    }
  }

  private async advanceByTime(state: State) {
    if (state.phase === 'final') return;
    const now = Date.now();
    if (state.phase === 'choice' && now >= state.phaseEndsAt.getTime()) {
      await this.finishChoice(state);
      return;
    }
    if (state.phase === 'discussion' && now >= state.phaseEndsAt.getTime()) {
      if (state.questionIndex >= 5) {
        state.phase = 'final';
        state.phaseEndsAt = new Date();
        await this.buildSuggestions(state);
      } else {
        state.questionIndex += 1;
        this.startQuestion(state);
      }
    }
  }

  private finalDecision(state: State, userId: string) {
    const rec = state.suggestions[userId];
    if (!rec) return { status: 'none' };
    const matchId = state.matchIds[userId];
    if (matchId) return { status: 'matched', matchId };
    const choice = state.finalChoices[userId];
    if (choice === 'continue') return { status: 'continue' };
    if (choice === 'match') return { status: 'waiting' };
    return { status: 'pending' };
  }

  private view(state: State, userId: string) {
    const q = state.questions[state.questionIndex];
    const redCount = Object.values(state.choices).filter((v) => v === 'red').length;
    const greenCount = Object.values(state.choices).filter((v) => v === 'green').length;
    return {
      roomId: state.roomId,
      game: 'red_flag_green_flag',
      phase: state.phase,
      questionIndex: state.questionIndex,
      totalQuestions: 6,
      phaseEndsAt: state.phaseEndsAt.toISOString(),
      question: q ?? null,
      players: state.players.map((p) => ({ id: p.id, name: p.name, photoUrl: p.photoUrl })),
      myChoice: state.choices[userId] ?? null,
      result: state.phase === 'discussion' ? { red: redCount, green: greenCount } : null,
      recommendation: state.phase === 'final' ? state.suggestions[userId] ?? null : null,
      finalDecision: state.phase === 'final' ? this.finalDecision(state, userId) : null,
    };
  }

  private async assertMember(userId: string, roomId: string) {
    const result = await this.infra.db.query(
      `select 1 from room_members rm join rooms r on r.id=rm.room_id
       where rm.room_id=$1 and rm.user_id=$2 and rm.left_at is null
         and rm.admin_removed_at is null and r.room_mode='game'`,
      [roomId, userId],
    );
    if (result.rowCount === 0) throw new ForbiddenException('Bu Red Flag / Green Flag odasına erişimin yok.');
  }

  async create(userId: string) {
    const testUserIds = this.testIds(userId);
    const memberIds = [String(userId), ...testUserIds];
    const client = await this.infra.db.connect();
    try {
      await client.query('begin');
      await client.query('select pg_advisory_xact_lock(606062)');
      const profiles = await client.query<{
        user_id: string; name: string; gender: string; looking_for: string; photo_url: string; age: number;
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
      if (!roomId) throw new BadRequestException('Red Flag / Green Flag test odası oluşturulamadı.');
      for (const id of memberIds) {
        await client.query('insert into room_members(room_id,user_id) values($1,$2)', [roomId, id]);
      }
      await client.query('delete from matchmaking_queue where user_id=any($1::bigint[])', [memberIds]);
      await client.query(
        `insert into room_messages(room_id,sender_user_id,body)
         values($1,null,'Red Flag / Green Flag başladı. 6 soru, her soruda 15 sn seçim ve 2 dk tartışma.')`,
        [roomId],
      );
      await client.query('commit');

      const human = profiles.rows.find((r) => r.user_id === String(userId));
      const questions = await this.chooseQuestions(String(userId), human?.age ?? 18);
      for (const question of questions) {
        await this.infra.db.query(
          `insert into red_flag_question_history(user_id,question_id,seen_at)
           values($1,$2,now())
           on conflict(user_id,question_id) do update set seen_at=excluded.seen_at`,
          [userId, question.id],
        );
      }

      const byId = new Map(profiles.rows.map((r) => [r.user_id, r]));
      const players: Player[] = memberIds.map((id) => {
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
        questions,
        questionIndex: 0,
        phase: 'choice',
        phaseEndsAt: new Date(),
        choices: {},
        answers: [],
        suggestions: {},
        finalChoices: {},
        matchIds: {},
      };
      this.startQuestion(state);
      this.games.set(roomId, state);
      return {
        ok: true,
        state: 'room',
        testMode: true,
        participantCount: 6,
        gameKey: 'red_flag_green_flag',
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
    if (!state) throw new BadRequestException('Red Flag / Green Flag oyun durumu bulunamadı. Odayı yeniden oluştur.');
    await this.advanceByTime(state);
    return this.view(state, String(userId));
  }

  async choose(userId: string, roomId: string, rawChoice: unknown) {
    await this.assertMember(userId, roomId);
    const state = this.games.get(roomId);
    if (!state) throw new BadRequestException('Oyun durumu bulunamadı.');
    await this.advanceByTime(state);
    if (state.phase !== 'choice') throw new BadRequestException('Seçim süresi kapandı.');
    const choice = String(rawChoice ?? '') as Choice;
    if (!['red','green'].includes(choice)) throw new BadRequestException('Red veya Green seçmelisin.');
    state.choices[String(userId)] = choice;
    if (state.players.every((p) => state.choices[p.id])) await this.finishChoice(state);
    return this.view(state, String(userId));
  }

  async finalChoice(userId: string, roomId: string, raw: unknown) {
    await this.assertMember(userId, roomId);
    const state = this.games.get(roomId);
    if (!state) throw new BadRequestException('Oyun durumu bulunamadı.');
    await this.advanceByTime(state);
    if (state.phase !== 'final') throw new BadRequestException('Oyun henüz tamamlanmadı.');
    const choice = String(raw ?? '');
    if (!['match','continue'].includes(choice)) throw new BadRequestException('Geçerli final seçimi gönder.');
    const rec = state.suggestions[String(userId)];
    if (!rec) throw new BadRequestException('Bu oyun için uygun eşleşme önerisi bulunamadı.');
    state.finalChoices[String(userId)] = choice as 'match' | 'continue';

    if (choice === 'match') {
      const partnerId = rec.partnerUserId;
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
            [
              userId,
              partnerId,
              `${rec.partnerName} ile Red Flag / Green Flag uyumunuz karşılıklı eşleşti.`,
              matchId,
              `${state.players.find((p) => p.id === String(userId))?.name ?? 'Bir oyuncu'} ile Red Flag / Green Flag uyumunuz karşılıklı eşleşti.`,
            ],
          );
        }
      }
    }
    return this.view(state, String(userId));
  }
}
