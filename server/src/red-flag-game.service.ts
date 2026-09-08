import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { InfrastructureService } from './infrastructure.service';
import { RoomService } from './room.service';

type Choice = 'red' | 'green';
type Player = { id: string; name: string; test: boolean; gender: string; lookingFor: string; photoUrl: string };
type Question = { id: string; prompt: string; category: string; difficulty: string };
type AnswerRound = { questionId: string; choices: Record<string, Choice> };
type Suggestion = { partnerUserId: string; partnerName: string; partnerPhotoUrl: string; compatibility: number; sameAnswers: number; differentAnswers: number };
type State = {
  roomId: string; players: Player[]; questions: Question[]; questionIndex: number;
  phase: 'choice' | 'discussion' | 'final'; phaseEndsAt: Date; startedAtMs: number;
  choices: Record<string, Choice>; answers: AnswerRound[];
  suggestions: Record<string, Suggestion>; finalChoices: Record<string, 'match' | 'continue'>; matchIds: Record<string, string>;
};
type PairScore = { a: string; b: string; score: number; same: number; different: number };

@Injectable()
export class RedFlagGameService {
  private readonly games = new Map<string, State>();
  private static readonly CHOICE_MS = 15_000;
  private static readonly DISCUSSION_MS = 120_000;
  private static readonly QUESTION_MS = RedFlagGameService.CHOICE_MS + RedFlagGameService.DISCUSSION_MS;

  constructor(private readonly infra: InfrastructureService, private readonly rooms: RoomService) {}

  private testIds(currentUserId: string) {
    if (process.env.GAME_ROOM_TEST_ENABLED !== 'true') throw new ForbiddenException('Mini oyun test odası sunucuda kapalı.');
    const ids = (process.env.GAME_ROOM_TEST_USER_IDS ?? '').split(',').map((v) => v.trim()).filter((v) => /^\d+$/.test(v) && v !== currentUserId);
    const unique = [...new Set(ids)];
    if (unique.length !== 5) throw new BadRequestException('GAME_ROOM_TEST_USER_IDS içinde mevcut kullanıcı hariç tam 5 test kullanıcı ID olmalı.');
    return unique;
  }

  private accepts(pref: string, gender: string) {
    return pref === 'Herkes' || (pref === 'Kadınlar' && gender === 'Kadın') || (pref === 'Erkekler' && gender === 'Erkek');
  }

  private oppositeSex(a: string, b: string) {
    const normalize = (value: string) => String(value ?? '').trim().toLocaleLowerCase('tr-TR');
    const female = (value: string) => ['kadın', 'kadin', 'female', 'woman'].includes(normalize(value));
    const male = (value: string) => ['erkek', 'male', 'man'].includes(normalize(value));
    return (female(a) && male(b)) || (male(a) && female(b));
  }

  private botChoice(userId: string, questionId: string): Choice {
    return (Number(userId) + Number(questionId)) % 3 === 0 ? 'red' : 'green';
  }

  private questionChoiceEnd(s: State, index: number) {
    return s.startedAtMs + index * RedFlagGameService.QUESTION_MS + RedFlagGameService.CHOICE_MS;
  }

  private questionEnd(s: State, index: number) {
    return s.startedAtMs + (index + 1) * RedFlagGameService.QUESTION_MS;
  }

  private prepareQuestion(s: State, index: number) {
    s.questionIndex = index;
    s.phase = 'choice';
    s.phaseEndsAt = new Date(this.questionChoiceEnd(s, index));
    s.choices = {};
    const q = s.questions[index];
    if (!q) return;
    for (const p of s.players.filter((x) => x.test)) s.choices[p.id] = this.botChoice(p.id, q.id);
  }

  private async chooseQuestions(userId: string, age: number) {
    const load = async (avoidRecent: boolean) => this.infra.db.query<Question>(
      `select q.id::text,q.prompt,q.category,q.difficulty from red_flag_questions q
       where q.active=true and q.admin_approved=true and q.safe=true
         and q.min_age <= $2 and (q.max_age is null or q.max_age >= $2)
         and ($3::boolean=false or not exists (
           select 1 from red_flag_question_history h where h.user_id=$1 and h.question_id=q.id and h.seen_at>now()-interval '30 days'))
       order by random() limit 48`, [userId, age, avoidRecent]);
    let pool = (await load(true)).rows;
    if (pool.length < 6) pool = (await load(false)).rows;
    if (pool.length < 6) throw new BadRequestException('Red Flag / Green Flag soru havuzunda yeterli onaylı soru yok.');
    const selected: Question[] = [];
    while (selected.length < 6 && pool.length) {
      const prev = selected.length ? selected[selected.length - 1].category : '';
      let index = pool.findIndex((q) => q.category !== prev);
      if (index < 0) index = 0;
      selected.push(pool.splice(index, 1)[0]);
    }
    return selected;
  }

  private async completeQuestion(s: State, index: number, currentChoices?: Record<string, Choice>) {
    const q = s.questions[index];
    if (!q || s.answers.some((r) => r.questionId === q.id)) return;
    const choices: Record<string, Choice> = {};
    for (const p of s.players) choices[p.id] = currentChoices?.[p.id] ?? this.botChoice(p.id, q.id);
    s.answers.push({ questionId: q.id, choices });
    if (index === s.questionIndex) s.choices = { ...choices };
    const red = Object.values(choices).filter((v) => v === 'red').length;
    const green = 6 - red;
    await this.infra.db.query(
      `insert into room_messages(room_id,sender_user_id,body) values($1,null,$2)`,
      [s.roomId, `Sonuç: ${red} Red / ${green} Green. 2 dakikalık tartışma başladı.`],
    );
  }

  private compatibility(s: State, a: string, b: string) {
    const same = s.answers.filter((r) => r.choices[a] === r.choices[b]).length;
    const different = s.answers.length - same;
    return { same, different, score: s.answers.length ? Math.round(same * 100 / s.answers.length) : 0 };
  }

  private async buildSuggestions(s: State) {
    const ids = s.players.map((p) => p.id); const blocked = new Set<string>(); const key = (a: string, b: string) => [a,b].sort().join(':');
    const blocks = await this.infra.db.query<{a:string;b:string}>(`select blocker_user_id::text a,blocked_user_id::text b from blocked_users where blocker_user_id=any($1::bigint[]) or blocked_user_id=any($1::bigint[])`, [ids]);
    const reports = await this.infra.db.query<{a:string;b:string}>(`select reporter_user_id::text a,reported_user_id::text b from reports where reporter_user_id=any($1::bigint[]) or reported_user_id=any($1::bigint[])`, [ids]);
    const matches = await this.infra.db.query<{a:string;b:string}>(`select user_a_id::text a,user_b_id::text b from matches where user_a_id=any($1::bigint[]) and user_b_id=any($1::bigint[])`, [ids]);
    for (const r of [...blocks.rows,...reports.rows]) blocked.add(key(r.a,r.b));
    for (const r of matches.rows) {
      const a = s.players.find((p) => p.id === r.a);
      const b = s.players.find((p) => p.id === r.b);
      if (a?.test || b?.test) continue;
      blocked.add(key(r.a, r.b));
    }
    const partyTable = await this.infra.db.query<{exists:boolean}>(`select to_regclass('public.matchmaking_parties') is not null as exists`);
    if (partyTable.rows[0]?.exists) {
      const partyPairs = await this.infra.db.query<{a:string;b:string}>(
        `select owner_user_id::text a,guest_user_id::text b from matchmaking_parties
         where room_id=$1 and status='matched' and guest_user_id is not null`,
        [s.roomId],
      );
      for (const r of partyPairs.rows) blocked.add(key(r.a,r.b));
    }
    const pairs: PairScore[] = [];
    for (let i=0;i<s.players.length;i++) for (let j=i+1;j<s.players.length;j++) {
      const a=s.players[i], b=s.players[j]; if (blocked.has(key(a.id,b.id))) continue;
      if (!this.oppositeSex(a.gender,b.gender)) continue;
      const c=this.compatibility(s,a.id,b.id); pairs.push({a:a.id,b:b.id,score:c.score,same:c.same,different:c.different});
    }
    pairs.sort((x,y)=>y.score-x.score || Number(x.a)-Number(y.a) || Number(x.b)-Number(y.b));
    const best=new Map<string,PairScore>(); for(const p of pairs){ if(!best.has(p.a))best.set(p.a,p); if(!best.has(p.b))best.set(p.b,p); }
    const other=(p:PairScore,id:string)=>p.a===id?p.b:p.a; const assigned=new Set<string>(); const chosen:PairScore[]=[];
    for(const p of pairs){ const ab=best.get(p.a), bb=best.get(p.b); if(!ab||!bb||other(ab,p.a)!==p.b||other(bb,p.b)!==p.a)continue; if(assigned.has(p.a)||assigned.has(p.b))continue; chosen.push(p);assigned.add(p.a);assigned.add(p.b); }
    for(const p of pairs){ if(assigned.has(p.a)||assigned.has(p.b))continue;chosen.push(p);assigned.add(p.a);assigned.add(p.b); }
    s.suggestions={};
    for(const p of chosen){ const a=s.players.find(x=>x.id===p.a)!,b=s.players.find(x=>x.id===p.b)!;
      s.suggestions[a.id]={partnerUserId:b.id,partnerName:b.name,partnerPhotoUrl:b.photoUrl,compatibility:p.score,sameAnswers:p.same,differentAnswers:p.different};
      s.suggestions[b.id]={partnerUserId:a.id,partnerName:a.name,partnerPhotoUrl:a.photoUrl,compatibility:p.score,sameAnswers:p.same,differentAnswers:p.different}; }
    const human=s.players.find(p=>!p.test); if(human){ const rec=s.suggestions[human.id]; const bot=rec&&s.players.find(p=>p.id===rec.partnerUserId&&p.test); if(bot&&s.suggestions[bot.id]?.partnerUserId===human.id)s.finalChoices[bot.id]='match'; }
  }

  private async syncTimeline(s: State) {
    if (s.phase === 'final') return;
    const now = Date.now();
    const elapsed = Math.max(0, now - s.startedAtMs);
    const totalMs = s.questions.length * RedFlagGameService.QUESTION_MS;

    if (elapsed >= totalMs) {
      for (let i = 0; i < s.questions.length; i++) {
        await this.completeQuestion(s, i, i === s.questionIndex ? s.choices : undefined);
      }
      s.questionIndex = Math.max(0, s.questions.length - 1);
      s.phase = 'final';
      s.phaseEndsAt = new Date(s.startedAtMs + totalMs);
      await this.buildSuggestions(s);
      return;
    }

    const targetIndex = Math.floor(elapsed / RedFlagGameService.QUESTION_MS);
    while (s.questionIndex < targetIndex) {
      await this.completeQuestion(s, s.questionIndex, s.choices);
      this.prepareQuestion(s, s.questionIndex + 1);
    }

    const inQuestion = elapsed % RedFlagGameService.QUESTION_MS;
    if (inQuestion < RedFlagGameService.CHOICE_MS) {
      s.phase = 'choice';
      s.phaseEndsAt = new Date(this.questionChoiceEnd(s, s.questionIndex));
      return;
    }

    await this.completeQuestion(s, s.questionIndex, s.choices);
    s.phase = 'discussion';
    s.phaseEndsAt = new Date(this.questionEnd(s, s.questionIndex));
  }

  private decision(s: State,userId:string){ const rec=s.suggestions[userId]; if(!rec)return{status:'none'}; const id=s.matchIds[userId]; if(id)return{status:'matched',matchId:id}; const c=s.finalChoices[userId]; return{status:c==='continue'?'continue':c==='match'?'waiting':'pending'}; }
  private view(s:State,userId:string){ const q=s.questions[s.questionIndex]; const red=Object.values(s.choices).filter(v=>v==='red').length; return {roomId:s.roomId,game:'red_flag_green_flag',serverStartedAt:new Date(s.startedAtMs).toISOString(),phase:s.phase,questionIndex:s.questionIndex,totalQuestions:6,phaseEndsAt:s.phaseEndsAt.toISOString(),question:q??null,players:s.players.map(p=>({id:p.id,name:p.name,photoUrl:p.photoUrl})),myChoice:s.choices[userId]??null,result:s.phase==='discussion'?{red,green:6-red}:null,recommendation:s.phase==='final'?s.suggestions[userId]??null:null,finalDecision:s.phase==='final'?this.decision(s,userId):null}; }
  private async assertMember(userId:string,roomId:string){ const r=await this.infra.db.query(`select 1 from room_members rm join rooms r on r.id=rm.room_id where rm.room_id=$1 and rm.user_id=$2 and rm.left_at is null and rm.admin_removed_at is null and r.room_mode='game'`,[roomId,userId]); if(!r.rowCount)throw new ForbiddenException('Bu Red Flag / Green Flag odasına erişimin yok.'); }

  async create(userId:string){
    const testIds=this.testIds(String(userId)), memberIds=[String(userId),...testIds], client=await this.infra.db.connect();
    try{
      await client.query('begin'); await client.query('select pg_advisory_xact_lock(606062)');
      const profiles=await client.query<{user_id:string;name:string;gender:string;looking_for:string;photo_url:string;age:number}>(
        `select u.id::text user_id,coalesce(nullif(trim(p.display_name),''),'Oyuncu') name,coalesce(p.gender,'') gender,coalesce(mp.looking_for,'Herkes') looking_for,coalesce(p.photo_urls[1],'') photo_url,extract(year from age(current_date,p.birth_date))::int age from users u join profiles p on p.user_id=u.id left join matching_preferences mp on mp.user_id=u.id where u.id=any($1::bigint[]) and u.status='active' and p.profile_completed=true`,[memberIds]);
      const ready=new Set(profiles.rows.map(r=>r.user_id)), missing=memberIds.filter(id=>!ready.has(id)); if(missing.length)throw new BadRequestException(`Mini oyun test kullanıcıları hazır değil: ${missing.join(', ')}`);
      const busy=await client.query(`select 1 from room_members rm join rooms r on r.id=rm.room_id where rm.user_id=$1 and rm.left_at is null and rm.admin_removed_at is null and r.status in ('active','selection') limit 1`,[userId]); if(busy.rowCount)throw new BadRequestException('Önce mevcut aktif odandan çıkmalısın.');
      await client.query(`update room_members rm set left_at=now() from rooms r where rm.room_id=r.id and rm.user_id=any($1::bigint[]) and rm.left_at is null and rm.admin_removed_at is null and r.status in ('active','selection')`,[testIds]);
      const created=await client.query<{id:string}>(`insert into rooms(status,started_at,ends_at,room_duration_minutes,room_mode) values('active',now(),now()+interval '15 minutes',15,'game') returning id::text`); const roomId=created.rows[0]?.id; if(!roomId)throw new BadRequestException('Oda oluşturulamadı.');
      for(const id of memberIds)await client.query('insert into room_members(room_id,user_id) values($1,$2)',[roomId,id]);
      await client.query('delete from matchmaking_queue where user_id=any($1::bigint[])',[memberIds]); await client.query(`insert into room_messages(room_id,sender_user_id,body) values($1,null,'Red Flag / Green Flag başladı. 6 soru • 15 sn seçim • 2 dk tartışma.')`,[roomId]); await client.query('commit');
      const human=profiles.rows.find(r=>r.user_id===String(userId)),questions=await this.chooseQuestions(String(userId),human?.age??18);
      for(const q of questions)await this.infra.db.query(`insert into red_flag_question_history(user_id,question_id,seen_at) values($1,$2,now()) on conflict(user_id,question_id) do update set seen_at=excluded.seen_at`,[userId,q.id]);
      const byId=new Map(profiles.rows.map(r=>[r.user_id,r])); const players:Player[]=memberIds.map(id=>{const r=byId.get(id)!;return{id,name:r.name,test:id!==String(userId),gender:r.gender,lookingFor:r.looking_for,photoUrl:r.photo_url};});
      const startedAtMs=Date.now();
      const s:State={roomId,players,questions,questionIndex:0,phase:'choice',phaseEndsAt:new Date(startedAtMs+RedFlagGameService.CHOICE_MS),startedAtMs,choices:{},answers:[],suggestions:{},finalChoices:{},matchIds:{}}; this.prepareQuestion(s,0); this.games.set(roomId,s);
      return{ok:true,state:'room',testMode:true,participantCount:6,gameKey:'red_flag_green_flag',room:await this.rooms.getRoom(userId,roomId),gameState:this.view(s,String(userId))};
    }catch(e){await client.query('rollback').catch(()=>undefined);throw e;}finally{client.release();}
  }

  async state(userId:string,roomId:string){await this.assertMember(userId,roomId);const s=this.games.get(roomId);if(!s)throw new BadRequestException('Red Flag / Green Flag oyun durumu bulunamadı. Odayı yeniden oluştur.');await this.syncTimeline(s);return this.view(s,String(userId));}
  async choose(userId:string,roomId:string,raw:unknown){await this.assertMember(userId,roomId);const s=this.games.get(roomId);if(!s)throw new BadRequestException('Oyun durumu bulunamadı.');await this.syncTimeline(s);if(s.phase!=='choice')throw new BadRequestException('Seçim süresi kapandı.');const c=String(raw??'') as Choice;if(c!=='red'&&c!=='green')throw new BadRequestException('Red veya Green seçmelisin.');s.choices[String(userId)]=c;return this.view(s,String(userId));}
  async finalChoice(userId:string,roomId:string,raw:unknown){
    const s=this.games.get(roomId);if(!s)throw new BadRequestException('Oyun durumu bulunamadı.');
    if(!s.players.some((p)=>p.id===String(userId)))throw new ForbiddenException('Bu Red Flag / Green Flag oyununa erişimin yok.');
    await this.syncTimeline(s);if(s.phase!=='final')throw new BadRequestException('Oyun henüz tamamlanmadı.');
    const c=String(raw??'');if(c!=='match'&&c!=='continue')throw new BadRequestException('Geçerli final seçimi gönder.');
    const rec=s.suggestions[String(userId)];if(!rec)throw new BadRequestException('Uygun eşleşme önerisi bulunamadı.');
    s.finalChoices[String(userId)]=c;
    if(c==='match'){
      const partnerId=rec.partnerUserId;
      if(s.finalChoices[partnerId]==='match'&&s.suggestions[partnerId]?.partnerUserId===String(userId)){
        let matchId:string|undefined;
        const existing=await this.infra.db.query<{id:string}>(`select id::text from matches where unmatched_at is null and ((user_a_id=$1 and user_b_id=$2) or (user_a_id=$2 and user_b_id=$1)) order by id desc limit 1`,[userId,partnerId]);
        matchId=existing.rows[0]?.id;
        if(!matchId){
          const a=Number(userId)<=Number(partnerId)?String(userId):String(partnerId);
          const b=a===String(userId)?String(partnerId):String(userId);
          const ins=await this.infra.db.query<{id:string}>(`insert into matches(user_a_id,user_b_id,source_room_id) values($1,$2,$3) on conflict do nothing returning id::text`,[a,b,s.roomId]);
          matchId=ins.rows[0]?.id;
          if(!matchId){
            const retry=await this.infra.db.query<{id:string}>(`select id::text from matches where unmatched_at is null and ((user_a_id=$1 and user_b_id=$2) or (user_a_id=$2 and user_b_id=$1)) order by id desc limit 1`,[userId,partnerId]);
            matchId=retry.rows[0]?.id;
          }
        }
        if(matchId){
          s.matchIds[String(userId)]=matchId;s.matchIds[partnerId]=matchId;
          await this.infra.db.query(`insert into notifications(user_id,type,title,body,data) values($1,'match','Eşleştiniz 💚',$3,jsonb_build_object('matchId',$4::text,'userId',$2::text)),($2,'match','Eşleştiniz 💚',$5,jsonb_build_object('matchId',$4::text,'userId',$1::text))`,[userId,partnerId,`${rec.partnerName} ile oyun uyumunuz karşılıklı eşleşti.`,matchId,`${s.players.find(p=>p.id===String(userId))?.name??'Bir oyuncu'} ile oyun uyumunuz karşılıklı eşleşti.`]).catch(()=>undefined);
        }
      }
    }
    return this.view(s,String(userId));
  }
}
