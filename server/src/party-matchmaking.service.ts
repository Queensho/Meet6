import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { randomBytes } from 'crypto';

import { InfrastructureService } from './infrastructure.service';
import { MiniGameMatchmakingService } from './mini-game-matchmaking.service';
import { RoomService } from './room.service';
import { RuntimeSettingsService } from './runtime-settings.service';
import { TabuGameService } from './tabu-game.service';

type PartyMode = 'text' | 'game';
type GameKey = 'tabu' | 'red_flag_green_flag' | 'two_truths_one_lie';

type PartyRow = {
  id: string;
  code: string;
  owner_user_id: string;
  guest_user_id: string | null;
  room_mode: PartyMode;
  game_key: GameKey | null;
  room_duration_minutes: number;
  status: string;
  room_id: string | null;
  owner_name: string;
  guest_name: string | null;
  expires_at: Date;
};

type QueueProfile = {
  user_id: string;
  display_name: string;
  birth_date: string;
  gender: string;
  latitude: number;
  longitude: number;
  looking_for: string;
  min_age: number;
  max_age: number;
  distance_km: number;
  purpose: string;
  joined_at: Date;
};

@Injectable()
export class PartyMatchmakingService {
  private schemaReady = false;

  constructor(
    private readonly infra: InfrastructureService,
    private readonly rooms: RoomService,
    private readonly settings: RuntimeSettingsService,
    private readonly miniGames: MiniGameMatchmakingService,
    private readonly tabu: TabuGameService,
  ) {}

  private async ensureSchema() {
    if (this.schemaReady) return;
    await this.infra.db.query(`
      create table if not exists matchmaking_parties(
        id bigserial primary key,
        code varchar(8) not null unique,
        owner_user_id bigint not null references users(id) on delete cascade,
        guest_user_id bigint references users(id) on delete set null,
        room_mode varchar(16) not null,
        game_key varchar(64),
        room_duration_minutes int not null default 15,
        status varchar(24) not null default 'waiting_friend',
        room_id bigint references rooms(id) on delete set null,
        created_at timestamptz not null default now(),
        updated_at timestamptz not null default now(),
        expires_at timestamptz not null default (now() + interval '30 minutes')
      );
      create index if not exists matchmaking_parties_owner_active_idx
        on matchmaking_parties(owner_user_id,status,created_at desc);
      create index if not exists matchmaking_parties_guest_active_idx
        on matchmaking_parties(guest_user_id,status,created_at desc);
    `);
    this.schemaReady = true;
  }

  private normalizeCode(raw: unknown) {
    return String(raw ?? '').trim().toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 8);
  }

  private mode(raw: unknown): PartyMode {
    const value = String(raw ?? '').trim();
    if (value === 'text' || value === 'game') return value;
    throw new BadRequestException('Arkadaşınla Katıl yalnızca yazılı oda veya oyun odasında kullanılabilir.');
  }

  private gameKey(raw: unknown, mode: PartyMode): GameKey | null {
    if (mode !== 'game') return null;
    const value = String(raw ?? '').trim();
    if (value === 'tabu' || value === 'red_flag_green_flag' || value === 'two_truths_one_lie') {
      return value;
    }
    throw new BadRequestException('Geçerli bir mini oyun seçmelisin.');
  }

  private async assertReadyUser(userId: string) {
    const result = await this.infra.db.query(
      `select 1
       from users u
       join profiles p on p.user_id=u.id
       where u.id=$1 and u.status='active' and p.profile_completed=true`,
      [userId],
    );
    if (!result.rowCount) throw new BadRequestException('Arkadaşınla katılmak için profilini tamamlamalısın.');

    const busy = await this.infra.db.query(
      `select 1 from room_members rm
       join rooms r on r.id=rm.room_id
       where rm.user_id=$1 and rm.left_at is null and rm.admin_removed_at is null
         and r.status in ('active','selection') limit 1`,
      [userId],
    );
    if (busy.rowCount) throw new BadRequestException('Önce mevcut aktif odandan çıkmalısın.');
  }

  private async newCode() {
    for (let i = 0; i < 8; i++) {
      const code = randomBytes(4).toString('hex').toUpperCase().slice(0, 6);
      const exists = await this.infra.db.query('select 1 from matchmaking_parties where code=$1', [code]);
      if (!exists.rowCount) return code;
    }
    throw new BadRequestException('Davet kodu üretilemedi. Tekrar dene.');
  }

  private async partyByCode(code: string): Promise<PartyRow | null> {
    const result = await this.infra.db.query<PartyRow>(
      `select p.id::text,p.code,p.owner_user_id::text,p.guest_user_id::text,
              p.room_mode,p.game_key,p.room_duration_minutes,p.status,p.room_id::text,p.expires_at,
              coalesce(nullif(trim(op.display_name),''),'Arkadaş') owner_name,
              case when p.guest_user_id is null then null else coalesce(nullif(trim(gp.display_name),''),'Arkadaş') end guest_name
       from matchmaking_parties p
       join profiles op on op.user_id=p.owner_user_id
       left join profiles gp on gp.user_id=p.guest_user_id
       where p.code=$1
       limit 1`,
      [code],
    );
    return result.rows[0] ?? null;
  }

  private async ownedParty(userId: string) {
    const result = await this.infra.db.query<{ code: string }>(
      `select code from matchmaking_parties
       where owner_user_id=$1 and status in ('waiting_friend','ready','matching') and expires_at>now()
       order by created_at desc limit 1`,
      [userId],
    );
    return result.rows[0]?.code ?? null;
  }

  async create(userId: string, raw: { roomMode?: unknown; gameKey?: unknown; roomDurationMinutes?: unknown }) {
    await this.ensureSchema();
    await this.assertReadyUser(String(userId));
    const roomMode = this.mode(raw?.roomMode);
    const gameKey = this.gameKey(raw?.gameKey, roomMode);
    const requested = Number(raw?.roomDurationMinutes ?? 15);
    const roomDurationMinutes = roomMode === 'text' && requested === 30 ? 30 : 15;

    const existingCode = await this.ownedParty(String(userId));
    if (existingCode) return this.status(userId, existingCode);

    await this.infra.db.query(
      `update matchmaking_parties
       set status='cancelled',updated_at=now()
       where (owner_user_id=$1 or guest_user_id=$1)
         and status in ('waiting_friend','ready','matching')`,
      [userId],
    );

    const code = await this.newCode();
    await this.infra.db.query(
      `insert into matchmaking_parties(code,owner_user_id,room_mode,game_key,room_duration_minutes,status)
       values($1,$2,$3,$4,$5,'waiting_friend')`,
      [code, userId, roomMode, gameKey, roomDurationMinutes],
    );
    return this.status(userId, code);
  }

  async accept(userId: string, rawCode: unknown) {
    await this.ensureSchema();
    await this.assertReadyUser(String(userId));
    const code = this.normalizeCode(rawCode);
    if (!code) throw new BadRequestException('Davet kodunu yazmalısın.');

    const party = await this.partyByCode(code);
    if (!party || party.status === 'cancelled' || party.status === 'expired') {
      throw new NotFoundException('Davet bulunamadı.');
    }
    if (new Date(party.expires_at).getTime() <= Date.now()) {
      await this.infra.db.query(`update matchmaking_parties set status='expired',updated_at=now() where code=$1`, [code]);
      throw new BadRequestException('Bu davetin süresi dolmuş.');
    }
    if (party.owner_user_id === String(userId)) {
      throw new BadRequestException('Kendi davet kodunu kullanamazsın.');
    }
    if (party.guest_user_id && party.guest_user_id !== String(userId)) {
      throw new BadRequestException('Bu davete başka bir arkadaş zaten katılmış.');
    }

    await this.infra.db.query(
      `update matchmaking_parties
       set guest_user_id=$2,status='ready',updated_at=now()
       where code=$1 and status in ('waiting_friend','ready')`,
      [code, userId],
    );
    return this.status(userId, code);
  }

  private assertMember(party: PartyRow, userId: string) {
    if (party.owner_user_id !== String(userId) && party.guest_user_id !== String(userId)) {
      throw new NotFoundException('Bu davete erişimin yok.');
    }
  }

  private async response(party: PartyRow, userId: string, total = 2) {
    if (party.room_id) {
      return {
        ok: true,
        state: 'room',
        party: this.partyView(party, 6),
        roomMode: party.room_mode,
        gameKey: party.game_key,
        room: await this.rooms.getRoom(userId, party.room_id),
      };
    }
    const accepted = !!party.guest_user_id;
    return {
      ok: true,
      state: accepted ? 'queued' : 'waiting_friend',
      party: this.partyView(party, total),
      total,
      position: 1,
      needed: Math.max(0, 6 - total),
      nextRetrySeconds: 2,
    };
  }

  private partyView(party: PartyRow, total: number) {
    return {
      code: party.code,
      status: party.status,
      ownerUserId: party.owner_user_id,
      guestUserId: party.guest_user_id,
      ownerName: party.owner_name,
      guestName: party.guest_name,
      roomMode: party.room_mode,
      gameKey: party.game_key,
      roomDurationMinutes: Number(party.room_duration_minutes),
      participantCount: Math.min(6, total),
      needed: Math.max(0, 6 - total),
    };
  }

  async status(userId: string, rawCode: unknown) {
    await this.ensureSchema();
    const code = this.normalizeCode(rawCode);
    if (!code) throw new BadRequestException('Davet kodu gerekli.');
    const party = await this.partyByCode(code);
    if (!party) throw new NotFoundException('Davet bulunamadı.');
    this.assertMember(party, String(userId));
    if (party.status === 'cancelled' || party.status === 'expired') {
      return { ok: true, state: 'idle', party: this.partyView(party, party.guest_user_id ? 2 : 1) };
    }
    if (new Date(party.expires_at).getTime() <= Date.now() && !party.room_id) {
      await this.infra.db.query(`update matchmaking_parties set status='expired',updated_at=now() where code=$1`, [code]);
      return { ok: true, state: 'idle', party: this.partyView({ ...party, status: 'expired' }, party.guest_user_id ? 2 : 1) };
    }
    return this.response(party, String(userId), party.guest_user_id ? 2 : 1);
  }

  private age(value: string) {
    const birth = new Date(value);
    if (Number.isNaN(birth.getTime())) return 0;
    const now = new Date();
    let age = now.getUTCFullYear() - birth.getUTCFullYear();
    const month = now.getUTCMonth() - birth.getUTCMonth();
    if (month < 0 || (month === 0 && now.getUTCDate() < birth.getUTCDate())) age--;
    return age;
  }

  private accepts(preference: string, gender: string) {
    if (preference === 'Herkes') return true;
    if (preference === 'Kadınlar') return gender === 'Kadın';
    if (preference === 'Erkekler') return gender === 'Erkek';
    return false;
  }

  private pairKey(a: string, b: string) {
    return [String(a), String(b)].sort().join(':');
  }

  private distanceKm(a: QueueProfile, b: QueueProfile) {
    const rad = (degree: number) => degree * Math.PI / 180;
    const earth = 6371;
    const dLat = rad(Number(b.latitude) - Number(a.latitude));
    const dLon = rad(Number(b.longitude) - Number(a.longitude));
    const lat1 = rad(Number(a.latitude));
    const lat2 = rad(Number(b.latitude));
    const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
    return earth * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
  }

  private compatible(a: QueueProfile, b: QueueProfile, forbidden: Set<string>) {
    if (forbidden.has(this.pairKey(a.user_id, b.user_id))) return false;
    const ageA = this.age(a.birth_date);
    const ageB = this.age(b.birth_date);
    if (ageA < Number(b.min_age) || ageA > Number(b.max_age)) return false;
    if (ageB < Number(a.min_age) || ageB > Number(a.max_age)) return false;
    if (!this.accepts(a.looking_for, b.gender) || !this.accepts(b.looking_for, a.gender)) return false;
    const distance = this.distanceKm(a, b);
    return distance <= Number(a.distance_km) && distance <= Number(b.distance_km);
  }

  private async textProfiles(client: any, ids: string[]) {
    const result = await client.query(
      `select u.id::text user_id,coalesce(p.display_name,'') display_name,p.birth_date::text,p.gender,
              p.latitude,p.longitude,mp.looking_for,mp.min_age,mp.max_age,mp.distance_km,mp.purpose,now() joined_at
       from users u
       join profiles p on p.user_id=u.id and p.profile_completed=true
       join matching_preferences mp on mp.user_id=u.id
       where u.id=any($1::bigint[]) and u.status='active'`,
      [ids],
    );
    return result.rows as QueueProfile[];
  }

  private async forbiddenPairs(client: any, ids: string[]) {
    const forbidden = new Set<string>();
    const blocks = await client.query(
      `select blocker_user_id::text a,blocked_user_id::text b from blocked_users
       where blocker_user_id=any($1::bigint[]) or blocked_user_id=any($1::bigint[])`,
      [ids],
    );
    for (const row of blocks.rows) forbidden.add(this.pairKey(row.a, row.b));
    const reports = await client.query(
      `select reporter_user_id::text a,reported_user_id::text b from reports
       where reporter_user_id=any($1::bigint[]) or reported_user_id=any($1::bigint[])`,
      [ids],
    );
    for (const row of reports.rows) forbidden.add(this.pairKey(row.a, row.b));
    const matches = await client.query(
      `select user_a_id::text a,user_b_id::text b from matches
       where user_a_id=any($1::bigint[]) and user_b_id=any($1::bigint[])`,
      [ids],
    );
    for (const row of matches.rows) forbidden.add(this.pairKey(row.a, row.b));
    const runtime = await this.settings.get();
    const recent = await client.query(
      `select distinct rm1.user_id::text a,rm2.user_id::text b
       from room_members rm1 join room_members rm2 on rm2.room_id=rm1.room_id and rm1.user_id<rm2.user_id
       join rooms r on r.id=rm1.room_id
       where rm1.user_id=any($1::bigint[]) and rm2.user_id=any($1::bigint[])
         and r.started_at>=now()-($2::int*interval '1 hour')`,
      [ids, runtime.roomRepeatHours],
    );
    for (const row of recent.rows) forbidden.add(this.pairKey(row.a, row.b));
    return forbidden;
  }

  private async matchText(party: PartyRow, userId: string) {
    const ownerId = party.owner_user_id;
    const guestId = party.guest_user_id!;
    const client = await this.infra.db.connect();
    let roomId = '';
    let selected: string[] = [];
    try {
      await client.query('begin');
      await client.query('select pg_advisory_xact_lock(606066)');
      const locked = await client.query(`select status,room_id::text from matchmaking_parties where id=$1 for update`, [party.id]);
      if (locked.rows[0]?.room_id) {
        await client.query('commit');
        const latest = await this.partyByCode(party.code);
        return this.response(latest!, userId, 6);
      }

      const busy = await client.query(
        `select rm.user_id::text from room_members rm join rooms r on r.id=rm.room_id
         where rm.user_id=any($1::bigint[]) and rm.left_at is null and rm.admin_removed_at is null
           and r.status in ('active','selection')`,
        [[ownerId, guestId]],
      );
      if (busy.rowCount) throw new BadRequestException('Sen veya arkadaşın başka bir aktif odada.');

      const duration = Number(party.room_duration_minutes) === 30 ? 30 : 15;
      const queued = await client.query<QueueProfile>(
        `select q.user_id::text,q.joined_at,p.display_name,p.birth_date::text,p.gender,p.latitude,p.longitude,
                mp.looking_for,mp.min_age,mp.max_age,mp.distance_km,mp.purpose
         from matchmaking_queue q
         join users u on u.id=q.user_id and u.status='active'
         join profiles p on p.user_id=q.user_id and p.profile_completed=true
         join matching_preferences mp on mp.user_id=q.user_id
         where q.user_id<>all($1::bigint[]) and q.requested_room_duration_minutes=$2
           and not exists(select 1 from room_members rm join rooms r on r.id=rm.room_id
             where rm.user_id=q.user_id and rm.left_at is null and rm.admin_removed_at is null and r.status in ('active','selection'))
         order by q.priority_tier desc,q.joined_at asc
         limit 120 for update of q skip locked`,
        [[ownerId, guestId], duration],
      );
      const duoProfiles = await this.textProfiles(client, [ownerId, guestId]);
      if (duoProfiles.length !== 2) throw new BadRequestException('Sen veya arkadaşının eşleşme tercihleri eksik.');

      const allIds = [...duoProfiles.map((p) => p.user_id), ...queued.rows.map((p) => p.user_id)];
      const forbidden = await this.forbiddenPairs(client, allIds);
      const group: QueueProfile[] = [...duoProfiles];
      for (const candidate of queued.rows) {
        if (group.every((member) => this.compatible(member, candidate, forbidden))) group.push(candidate);
        if (group.length === 6) break;
      }
      if (group.length < 6) {
        await client.query(`update matchmaking_parties set status='matching',updated_at=now() where id=$1`, [party.id]);
        await client.query('commit');
        const latest = await this.partyByCode(party.code);
        return this.response(latest!, userId, Math.min(5, 2 + queued.rows.length));
      }

      selected = group.map((p) => p.user_id);
      const created = await client.query<{ id: string }>(
        `insert into rooms(status,started_at,ends_at,room_duration_minutes,room_mode)
         values('active',now(),now()+($1::int*interval '1 minute'),$1,'text') returning id::text`,
        [duration],
      );
      roomId = created.rows[0]?.id ?? '';
      if (!roomId) throw new BadRequestException('Arkadaş odası oluşturulamadı.');
      for (const id of selected) await client.query('insert into room_members(room_id,user_id) values($1,$2)', [roomId, id]);
      await client.query('delete from matchmaking_queue where user_id=any($1::bigint[])', [selected]);
      await client.query('delete from mini_game_matchmaking_queue where user_id=any($1::bigint[])', [selected]);
      await client.query('delete from tabu_matchmaking_queue where user_id=any($1::bigint[])', [selected]);
      await client.query(`update matchmaking_parties set status='matched',room_id=$2,updated_at=now() where id=$1`, [party.id, roomId]);
      await client.query(
        `insert into room_messages(room_id,sender_user_id,body) values($1,null,'Arkadaşınla Katıl: 2 arkadaş + 4 Meet6 kullanıcısı.')`,
        [roomId],
      );
      await client.query('commit');
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
    const latest = await this.partyByCode(party.code);
    return this.response(latest!, userId, 6);
  }

  private async matchGame(party: PartyRow, userId: string) {
    const gameKey = party.game_key!;
    const ownerId = party.owner_user_id;
    const guestId = party.guest_user_id!;
    const client = await this.infra.db.connect();
    let roomId = '';
    let chosenIds: string[] = [];
    let startedAtMs = Date.now();
    try {
      await client.query('begin');
      await client.query('select pg_advisory_xact_lock(606067)');
      const locked = await client.query(`select room_id::text from matchmaking_parties where id=$1 for update`, [party.id]);
      if (locked.rows[0]?.room_id) {
        await client.query('commit');
        const latest = await this.partyByCode(party.code);
        return this.response(latest!, userId, 6);
      }

      const busy = await client.query(
        `select 1 from room_members rm join rooms r on r.id=rm.room_id
         where rm.user_id=any($1::bigint[]) and rm.left_at is null and rm.admin_removed_at is null
           and r.status in ('active','selection') limit 1`,
        [[ownerId, guestId]],
      );
      if (busy.rowCount) throw new BadRequestException('Sen veya arkadaşın başka bir aktif odada.');

      const candidates = gameKey === 'tabu'
        ? await client.query<{ user_id: string }>(
            `select q.user_id::text from tabu_matchmaking_queue q
             join users u on u.id=q.user_id join profiles p on p.user_id=q.user_id
             where q.user_id<>all($1::bigint[]) and u.status='active' and p.profile_completed=true
               and not exists(select 1 from room_members rm join rooms r on r.id=rm.room_id
                 where rm.user_id=q.user_id and rm.left_at is null and rm.admin_removed_at is null and r.status in ('active','selection'))
             order by q.joined_at asc limit 4 for update of q skip locked`,
            [[ownerId, guestId]],
          )
        : await client.query<{ user_id: string }>(
            `select q.user_id::text from mini_game_matchmaking_queue q
             join users u on u.id=q.user_id join profiles p on p.user_id=q.user_id
             where q.user_id<>all($1::bigint[]) and q.game_key=$2 and u.status='active' and p.profile_completed=true
               and not exists(select 1 from room_members rm join rooms r on r.id=rm.room_id
                 where rm.user_id=q.user_id and rm.left_at is null and rm.admin_removed_at is null and r.status in ('active','selection'))
             order by q.joined_at asc limit 4 for update of q skip locked`,
            [[ownerId, guestId], gameKey],
          );

      if ((candidates.rowCount ?? 0) < 4) {
        await client.query(`update matchmaking_parties set status='matching',updated_at=now() where id=$1`, [party.id]);
        await client.query('commit');
        const latest = await this.partyByCode(party.code);
        return this.response(latest!, userId, 2 + (candidates.rowCount ?? 0));
      }

      chosenIds = [ownerId, guestId, ...candidates.rows.map((row) => row.user_id)];
      const duration = gameKey === 'tabu' ? 8 : 15;
      const created = await client.query<{ id: string; started_at: Date }>(
        `insert into rooms(status,started_at,ends_at,room_duration_minutes,room_mode)
         values('active',now(),now()+($1::int*interval '1 minute'),$1,'game') returning id::text,started_at`,
        [duration],
      );
      roomId = created.rows[0]?.id ?? '';
      startedAtMs = created.rows[0]?.started_at?.getTime() ?? Date.now();
      if (!roomId) throw new BadRequestException('Arkadaş oyun odası oluşturulamadı.');
      for (const id of chosenIds) await client.query('insert into room_members(room_id,user_id) values($1,$2)', [roomId, id]);
      await client.query('delete from matchmaking_queue where user_id=any($1::bigint[])', [chosenIds]);
      await client.query('delete from mini_game_matchmaking_queue where user_id=any($1::bigint[])', [chosenIds]);
      await client.query('delete from tabu_matchmaking_queue where user_id=any($1::bigint[])', [chosenIds]);
      const systemBody = gameKey === 'tabu'
        ? 'Mini oyun başladı: Tabu. Arkadaşınla Katıl.'
        : gameKey === 'red_flag_green_flag'
          ? 'Red Flag / Green Flag başladı. Arkadaşınla Katıl.'
          : 'Mini oyun başladı: İki Doğru Bir Yalan. Arkadaşınla Katıl.';
      await client.query('insert into room_messages(room_id,sender_user_id,body) values($1,null,$2)', [roomId, systemBody]);
      await client.query(`update matchmaking_parties set status='matched',room_id=$2,updated_at=now() where id=$1`, [party.id, roomId]);
      await client.query('commit');
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }

    try {
      if (gameKey === 'tabu') {
        const players = await (this.tabu as any).profiles(chosenIds);
        await (this.tabu as any).initialize(roomId, players);
      } else if (gameKey === 'red_flag_green_flag') {
        await (this.miniGames as any).initializeRedFlag(roomId, chosenIds);
      } else {
        await (this.miniGames as any).initializeTwoTruths(roomId, chosenIds, startedAtMs);
      }
    } catch (error) {
      await this.infra.db.query(`update rooms set status='closed',closed_at=now() where id=$1`, [roomId]).catch(() => undefined);
      await this.infra.db.query(`update room_members set left_at=now() where room_id=$1 and left_at is null`, [roomId]).catch(() => undefined);
      await this.infra.db.query(`update matchmaking_parties set status='cancelled',room_id=null,updated_at=now() where id=$1`, [party.id]).catch(() => undefined);
      throw error;
    }

    const latest = await this.partyByCode(party.code);
    return this.response(latest!, userId, 6);
  }

  async search(userId: string, rawCode: unknown) {
    await this.ensureSchema();
    const code = this.normalizeCode(rawCode);
    const party = await this.partyByCode(code);
    if (!party) throw new NotFoundException('Davet bulunamadı.');
    this.assertMember(party, String(userId));
    if (party.room_id) return this.response(party, String(userId), 6);
    if (!party.guest_user_id || party.status === 'waiting_friend') return this.response(party, String(userId), 1);
    if (!['ready', 'matching'].includes(party.status)) return this.response(party, String(userId), 2);
    return party.room_mode === 'game'
      ? this.matchGame(party, String(userId))
      : this.matchText(party, String(userId));
  }

  async cancel(userId: string, rawCode: unknown) {
    await this.ensureSchema();
    const code = this.normalizeCode(rawCode);
    const party = await this.partyByCode(code);
    if (!party) return { ok: true, state: 'idle' };
    this.assertMember(party, String(userId));
    if (party.room_id) throw new BadRequestException('Oda başladıktan sonra davet iptal edilemez.');

    if (party.owner_user_id === String(userId)) {
      await this.infra.db.query(`update matchmaking_parties set status='cancelled',updated_at=now() where id=$1`, [party.id]);
    } else {
      await this.infra.db.query(
        `update matchmaking_parties set guest_user_id=null,status='waiting_friend',updated_at=now() where id=$1`,
        [party.id],
      );
    }
    return { ok: true, state: 'idle' };
  }
}
