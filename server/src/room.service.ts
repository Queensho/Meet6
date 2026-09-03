import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { InfrastructureService } from './infrastructure.service';
import { RuntimeSettings, RuntimeSettingsService } from './runtime-settings.service';

interface QueueProfileRow {
  user_id: string;
  display_name: string;
  birth_date: string;
  gender: string;
  latitude: number;
  longitude: number;
  photo_urls: string[];
  looking_for: string;
  min_age: number;
  max_age: number;
  distance_km: number;
  purpose: string;
  joined_at: Date;
}

@Injectable()
export class RoomService {
  constructor(
    private readonly infra: InfrastructureService,
    private readonly runtimeSettings: RuntimeSettingsService,
  ) {}

  private configInt(name: string, fallback: number, min = 1, max = 10_000) {
    const parsed = Number(process.env[name] ?? fallback);
    if (!Number.isFinite(parsed)) return fallback;
    return Math.max(min, Math.min(max, Math.floor(parsed)));
  }

  private get candidatePoolLimit() {
    return this.configInt('MATCHMAKING_CANDIDATE_POOL', 200, 20, 1000);
  }

  private get retrySeconds() {
    return this.configInt('MATCHMAKING_RETRY_SECONDS', 15, 5, 120);
  }

  private pairKey(a: string | number, b: string | number) {
    return [String(a), String(b)].sort().join(':');
  }

  private ageFromBirthDate(value: string | Date | null | undefined) {
    if (!value) return 0;
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return 0;
    const now = new Date();
    let age = now.getUTCFullYear() - date.getUTCFullYear();
    const month = now.getUTCMonth() - date.getUTCMonth();
    if (month < 0 || (month === 0 && now.getUTCDate() < date.getUTCDate())) age--;
    return age;
  }

  private accepts(preference: string, gender: string) {
    if (preference === 'Herkes') return true;
    if (preference === 'Kadınlar') return gender === 'Kadın';
    if (preference === 'Erkekler') return gender === 'Erkek';
    return false;
  }

  private distanceKm(a: QueueProfileRow, b: QueueProfileRow) {
    const rad = (degree: number) => degree * Math.PI / 180;
    const earth = 6371;
    const dLat = rad(Number(b.latitude) - Number(a.latitude));
    const dLon = rad(Number(b.longitude) - Number(a.longitude));
    const lat1 = rad(Number(a.latitude));
    const lat2 = rad(Number(b.latitude));
    const h = Math.sin(dLat / 2) ** 2
      + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
    return earth * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
  }

  private compatible(
    a: QueueProfileRow,
    b: QueueProfileRow,
    forbiddenPairs: Set<string>,
  ) {
    if (forbiddenPairs.has(this.pairKey(a.user_id, b.user_id))) return false;

    const ageA = this.ageFromBirthDate(a.birth_date);
    const ageB = this.ageFromBirthDate(b.birth_date);
    if (ageA < Number(b.min_age) || ageA > Number(b.max_age)) return false;
    if (ageB < Number(a.min_age) || ageB > Number(a.max_age)) return false;
    if (!this.accepts(a.looking_for, b.gender)) return false;
    if (!this.accepts(b.looking_for, a.gender)) return false;

    const distance = this.distanceKm(a, b);
    if (distance > Number(a.distance_km) || distance > Number(b.distance_km)) return false;
    return true;
  }

  async syncExpiredRooms() {
    const settings = await this.runtimeSettings.get();
    await this.infra.db.query(
      `update rooms
       set status = 'selection',
           selection_started_at = coalesce(selection_started_at, now()),
           selection_ends_at = coalesce(selection_ends_at, now() + ($1::int * interval '1 second'))
       where status = 'active' and ends_at <= now()`,
      [settings.selectionSeconds],
    );
    await this.infra.db.query(
      `update rooms
       set status = 'closed', closed_at = coalesce(closed_at, now())
       where status = 'selection' and selection_ends_at <= now()`,
    );
    await this.infra.db.query(
      `update room_members rm
       set left_at = coalesce(rm.left_at, r.closed_at, now())
       from rooms r
       where rm.room_id = r.id and r.status = 'closed' and rm.left_at is null`,
    );
  }

  private async ensureProfileReady(userId: string) {
    const result = await this.infra.db.query<{ profile_completed: boolean }>(
      `select profile_completed from profiles where user_id = $1`,
      [userId],
    );
    if (!result.rows[0]?.profile_completed) {
      throw new BadRequestException('Oda aramak için profilini tamamlamalısın.');
    }
  }

  private async currentOpenRoomId(userId: string) {
    await this.syncExpiredRooms();
    const result = await this.infra.db.query<{ room_id: string }>(
      `select rm.room_id
       from room_members rm
       join rooms r on r.id = rm.room_id
       where rm.user_id = $1 and rm.left_at is null and rm.admin_removed_at is null
         and r.status in ('active','selection')
       order by rm.room_id desc
       limit 1`,
      [userId],
    );
    return result.rows[0]?.room_id ?? null;
  }

  async joinQueue(userId: string) {
    const settings = await this.runtimeSettings.assertOperational();
    await this.ensureProfileReady(userId);
    const existingRoomId = await this.currentOpenRoomId(userId);
    if (existingRoomId) {
      return { ok: true, state: 'room', room: await this.getRoom(userId, existingRoomId) };
    }

    await this.infra.db.query(
      `insert into matchmaking_queue(user_id) values($1)
       on conflict(user_id) do nothing`,
      [userId],
    );
    await this.tryMatchmaking(settings);
    return this.queueStatus(userId);
  }

  async cancelQueue(userId: string) {
    await this.infra.db.query('delete from matchmaking_queue where user_id = $1', [userId]);
    return { ok: true };
  }

  async queueStatus(userId: string) {
    const settings = await this.runtimeSettings.get();
    const roomId = await this.currentOpenRoomId(userId);
    if (roomId) {
      await this.infra.db.query('delete from matchmaking_queue where user_id = $1', [userId]);
      return { ok: true, state: 'room', room: await this.getRoom(userId, roomId) };
    }

    const queue = await this.infra.db.query<{
      position: string;
      total: string;
      joined_at: Date;
    }>(
      `select
         (select count(*) from matchmaking_queue q2 where q2.joined_at <= q.joined_at)::text as position,
         (select count(*) from matchmaking_queue)::text as total,
         q.joined_at
       from matchmaking_queue q where q.user_id = $1`,
      [userId],
    );
    if (!queue.rows[0]) return { ok: true, state: 'idle', position: 0, total: 0 };

    const row = queue.rows[0];
    const waitSeconds = Math.max(
      0,
      Math.floor((Date.now() - new Date(row.joined_at).getTime()) / 1000),
    );
    return {
      ok: true,
      state: 'queued',
      position: Number(row.position),
      total: Number(row.total),
      waitSeconds,
      nextRetrySeconds: this.retrySeconds,
      waitingStrategy: 'strict',
      filters: {
        roomRepeatHours: settings.roomRepeatHours,
        recentMatchDays: settings.recentMatchDays,
        minimumRoomUsers: settings.minimumRoomUsers,
        blockAndReport: 'permanent',
        preferencesRelaxed: false,
      },
    };
  }

  async processQueue() {
    const settings = await this.runtimeSettings.get();
    if (settings.maintenanceMode) return false;
    const roomId = await this.tryMatchmaking(settings);
    return roomId != null;
  }

  private async tryMatchmaking(settings: RuntimeSettings): Promise<string | null> {
    if (settings.maintenanceMode) return null;
    const client = await this.infra.db.connect();
    try {
      await client.query('begin');
      await client.query('select pg_advisory_xact_lock(606060)');

      await client.query(
        `delete from matchmaking_queue q
         using room_members rm, rooms r
         where q.user_id = rm.user_id and rm.room_id = r.id
           and rm.left_at is null and r.status in ('active','selection')`,
      );

      const queued = await client.query<QueueProfileRow>(
        `select q.user_id::text, q.joined_at,
                p.display_name, p.birth_date::text, p.gender, p.latitude, p.longitude, p.photo_urls,
                mp.looking_for, mp.min_age, mp.max_age, mp.distance_km, mp.purpose
         from matchmaking_queue q
         join users u on u.id = q.user_id and u.status = 'active'
         join profiles p on p.user_id = q.user_id and p.profile_completed = true
         join matching_preferences mp on mp.user_id = q.user_id
         order by q.joined_at asc
         limit ${this.candidatePoolLimit}
         for update of q skip locked`,
      );

      const roomSize = settings.minimumRoomUsers;
      if (queued.rows.length < roomSize) {
        await client.query('commit');
        return null;
      }

      const ids = queued.rows.map((row) => row.user_id);
      const forbiddenPairs = new Set<string>();

      const blocks = await client.query<{
        blocker_user_id: string;
        blocked_user_id: string;
      }>(
        `select blocker_user_id::text, blocked_user_id::text
         from blocked_users
         where blocker_user_id = any($1::bigint[]) or blocked_user_id = any($1::bigint[])`,
        [ids],
      );
      for (const row of blocks.rows) {
        forbiddenPairs.add(this.pairKey(row.blocker_user_id, row.blocked_user_id));
      }

      const reports = await client.query<{
        reporter_user_id: string;
        reported_user_id: string;
      }>(
        `select reporter_user_id::text, reported_user_id::text
         from reports
         where reporter_user_id = any($1::bigint[]) or reported_user_id = any($1::bigint[])`,
        [ids],
      );
      for (const row of reports.rows) {
        forbiddenPairs.add(this.pairKey(row.reporter_user_id, row.reported_user_id));
      }

      const recentRoomPairs = await client.query<{
        user_a_id: string;
        user_b_id: string;
      }>(
        `select distinct rm1.user_id::text as user_a_id, rm2.user_id::text as user_b_id
         from room_members rm1
         join room_members rm2
           on rm2.room_id = rm1.room_id and rm1.user_id < rm2.user_id
         join rooms r on r.id = rm1.room_id
         where rm1.user_id = any($1::bigint[])
           and rm2.user_id = any($1::bigint[])
           and r.started_at >= now() - ($2::int * interval '1 hour')`,
        [ids, settings.roomRepeatHours],
      );
      for (const row of recentRoomPairs.rows) {
        forbiddenPairs.add(this.pairKey(row.user_a_id, row.user_b_id));
      }

      const recentMatches = await client.query<{
        user_a_id: string;
        user_b_id: string;
      }>(
        `select user_a_id::text, user_b_id::text
         from matches
         where user_a_id = any($1::bigint[])
           and user_b_id = any($1::bigint[])
           and (unmatched_at is null
                or created_at >= now() - ($2::int * interval '1 day'))`,
        [ids, settings.recentMatchDays],
      );
      for (const row of recentMatches.rows) {
        forbiddenPairs.add(this.pairKey(row.user_a_id, row.user_b_id));
      }

      let group: QueueProfileRow[] | null = null;
      for (let seedIndex = 0; seedIndex < queued.rows.length && !group; seedIndex++) {
        const candidateGroup = [queued.rows[seedIndex]];
        const rest = queued.rows
          .filter((_, index) => index !== seedIndex)
          .sort((a, b) => {
            const samePurposeA = a.purpose === candidateGroup[0].purpose ? 0 : 1;
            const samePurposeB = b.purpose === candidateGroup[0].purpose ? 0 : 1;
            if (samePurposeA !== samePurposeB) return samePurposeA - samePurposeB;
            return a.joined_at.getTime() - b.joined_at.getTime();
          });

        for (const row of rest) {
          if (candidateGroup.every((member) => this.compatible(member, row, forbiddenPairs))) {
            candidateGroup.push(row);
          }
          if (candidateGroup.length === roomSize) break;
        }
        if (candidateGroup.length === roomSize) group = candidateGroup;
      }

      if (!group) {
        await client.query('commit');
        return null;
      }

      const room = await client.query<{ id: string }>(
        `insert into rooms(status, started_at, ends_at)
         values('active', now(), now() + ($1::int * interval '1 minute')) returning id::text`,
        [settings.roomDurationMinutes],
      );
      const roomId = room.rows[0].id;
      const groupIds = group.map((row) => row.user_id);

      for (const memberId of groupIds) {
        await client.query(
          `insert into room_members(room_id, user_id) values($1, $2)`,
          [roomId, memberId],
        );
      }

      await client.query(
        `insert into room_messages(room_id, sender_user_id, body)
         values($1, null, $2)`,
        [roomId, `Oda hazır. ${roomSize} kişi burada — sohbet için ${settings.roomDurationMinutes} dakikan var.`],
      );
      await client.query('commit');
      return roomId;
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }

  private async assertMember(userId: string, roomId: string | number) {
    const result = await this.infra.db.query<{ exists: boolean }>(
      `select exists(
         select 1 from room_members
         where room_id = $1 and user_id = $2 and admin_removed_at is null
       ) as exists`,
      [roomId, userId],
    );
    if (!result.rows[0]?.exists) throw new ForbiddenException('Bu odaya erişimin yok.');
  }

  async getRoom(userId: string, roomId: string | number) {
    await this.syncExpiredRooms();
    await this.assertMember(userId, roomId);
    const roomResult = await this.infra.db.query<{
      id: string;
      status: string;
      started_at: Date;
      ends_at: Date;
      extended: boolean;
      selection_started_at: Date | null;
      selection_ends_at: Date | null;
    }>(
      `select id::text, status, started_at, ends_at, extended,
              selection_started_at, selection_ends_at
       from rooms where id = $1`,
      [roomId],
    );
    const room = roomResult.rows[0];
    if (!room) throw new NotFoundException('Oda bulunamadı.');

    const members = await this.infra.db.query(
      `select u.id::text as user_id, p.display_name,
              extract(year from age(current_date, p.birth_date))::int as age,
              p.gender, p.city, p.country, p.photo_urls
       from room_members rm
       join users u on u.id = rm.user_id
       join profiles p on p.user_id = u.id
       where rm.room_id = $1 and rm.admin_removed_at is null
       order by rm.joined_at asc`,
      [roomId],
    );

    const now = Date.now();
    const secondsLeft = room.status === 'active'
      ? Math.max(0, Math.ceil((new Date(room.ends_at).getTime() - now) / 1000))
      : 0;
    const selectionSecondsLeft = room.status === 'selection' && room.selection_ends_at
      ? Math.max(0, Math.ceil((new Date(room.selection_ends_at).getTime() - now) / 1000))
      : 0;

    const vote = await this.infra.db.query<{ vote: boolean }>(
      `select vote from room_extension_votes where room_id = $1 and user_id = $2`,
      [roomId, userId],
    );
    const selection = await this.infra.db.query<{ selected_user_id: string }>(
      `select selected_user_id::text from room_selections where room_id = $1 and user_id = $2`,
      [roomId, userId],
    );

    const settings = await this.runtimeSettings.get();
    return {
      id: room.id,
      status: room.status,
      startedAt: room.started_at,
      endsAt: room.ends_at,
      extended: room.extended,
      secondsLeft,
      selectionSecondsLeft,
      canVoteExtension: room.status === 'active' && !room.extended && secondsLeft > 0 && secondsLeft <= 120,
      myExtensionVote: vote.rows[0]?.vote ?? null,
      mySelectionUserId: selection.rows[0]?.selected_user_id ?? null,
      members: members.rows,
      config: {
        extensionMinutes: settings.extensionMinutes,
        selectionSeconds: settings.selectionSeconds,
        minimumUsers: settings.minimumRoomUsers,
      },
      serverTime: new Date().toISOString(),
    };
  }

  async messages(userId: string, roomId: string | number, afterId = 0) {
    await this.assertMember(userId, roomId);
    const result = await this.infra.db.query(
      `select m.id::text, m.sender_user_id::text, p.display_name, p.photo_urls,
              m.body, m.created_at
       from room_messages m
       left join profiles p on p.user_id = m.sender_user_id
       where m.room_id = $1 and m.id > $2
       order by m.id asc
       limit 200`,
      [roomId, afterId],
    );
    return { ok: true, messages: result.rows };
  }

  async sendMessage(userId: string, roomId: string | number, bodyInput: string) {
    await this.runtimeSettings.assertOperational();
    const body = bodyInput.trim();
    if (!body) throw new BadRequestException('Mesaj boş olamaz.');
    await this.syncExpiredRooms();
    await this.assertMember(userId, roomId);
    const room = await this.infra.db.query<{ status: string }>('select status from rooms where id = $1', [roomId]);
    if (room.rows[0]?.status !== 'active') throw new BadRequestException('Oda sohbeti kapandı.');

    const rateKey = `room-message:${roomId}:${userId}`;
    const allowed = await this.infra.redis.set(rateKey, '1', 'EX', 1, 'NX');
    if (!allowed) throw new BadRequestException('Çok hızlı mesaj gönderiyorsun.');

    const result = await this.infra.db.query(
      `insert into room_messages(room_id, sender_user_id, body)
       values($1,$2,$3)
       returning id::text, sender_user_id::text, body, created_at`,
      [roomId, userId, body],
    );
    return { ok: true, message: result.rows[0] };
  }

  async voteExtension(userId: string, roomId: string | number, vote: boolean) {
    const settings = await this.runtimeSettings.assertOperational();
    await this.syncExpiredRooms();
    await this.assertMember(userId, roomId);
    const room = await this.infra.db.query<{ status: string; extended: boolean; ends_at: Date }>(
      'select status, extended, ends_at from rooms where id = $1',
      [roomId],
    );
    const current = room.rows[0];
    if (!current || current.status !== 'active') throw new BadRequestException('Oda aktif değil.');
    const secondsLeft = Math.ceil((new Date(current.ends_at).getTime() - Date.now()) / 1000);
    if (current.extended || secondsLeft <= 0 || secondsLeft > 120) {
      throw new BadRequestException('Uzatma oylaması şu anda açık değil.');
    }

    await this.infra.db.query(
      `insert into room_extension_votes(room_id,user_id,vote)
       values($1,$2,$3)
       on conflict(room_id,user_id) do update set vote = excluded.vote, updated_at = now()`,
      [roomId, userId, vote],
    );
    const count = await this.infra.db.query<{ yes: string; total: string; members: string }>(
      `select
         (select count(*) from room_extension_votes where room_id=$1 and vote)::text as yes,
         (select count(*) from room_extension_votes where room_id=$1)::text as total,
         (select count(*) from room_members where room_id=$1 and admin_removed_at is null)::text as members`,
      [roomId],
    );
    const yes = Number(count.rows[0]?.yes ?? 0);
    const memberCount = Math.max(2, Number(count.rows[0]?.members ?? settings.minimumRoomUsers));
    const requiredYes = Math.max(2, Math.ceil(memberCount * 2 / 3));
    let extended = false;
    if (yes >= requiredYes) {
      const update = await this.infra.db.query(
        `update rooms set ends_at = ends_at + ($2::int * interval '1 minute'), extended = true
         where id = $1 and extended = false and status = 'active'
         returning id`,
        [roomId, settings.extensionMinutes],
      );
      extended = update.rowCount === 1;
      if (extended) {
        await this.infra.db.query(
          `insert into room_messages(room_id, sender_user_id, body)
           values($1, null, $2)`,
          [roomId, `Oylama tamamlandı. Sohbet +${settings.extensionMinutes} dakika uzatıldı.`],
        );
      }
    }
    return {
      ok: true,
      yesVotes: yes,
      totalVotes: Number(count.rows[0]?.total ?? 0),
      requiredYesVotes: requiredYes,
      extended,
    };
  }

  async submitSelection(userId: string, roomId: string | number, selectedUserId: number) {
    await this.runtimeSettings.assertOperational();
    await this.syncExpiredRooms();
    await this.assertMember(userId, roomId);
    if (String(selectedUserId) === String(userId)) throw new BadRequestException('Kendini seçemezsin.');

    const room = await this.infra.db.query<{ status: string }>('select status from rooms where id = $1', [roomId]);
    if (!room.rows[0] || !['selection', 'closed'].includes(room.rows[0].status)) {
      throw new BadRequestException('Seçim aşaması henüz başlamadı.');
    }
    const target = await this.infra.db.query<{ exists: boolean }>(
      `select exists(
         select 1 from room_members
         where room_id = $1 and user_id = $2 and admin_removed_at is null
       ) as exists`,
      [roomId, selectedUserId],
    );
    if (!target.rows[0]?.exists) throw new BadRequestException('Seçilen kişi bu odada değil.');

    await this.infra.db.query(
      `insert into room_selections(room_id,user_id,selected_user_id)
       values($1,$2,$3)
       on conflict(room_id,user_id) do update set selected_user_id = excluded.selected_user_id, updated_at = now()`,
      [roomId, userId, selectedUserId],
    );

    const reciprocal = await this.infra.db.query<{ exists: boolean }>(
      `select exists(
        select 1 from room_selections
        where room_id = $1 and user_id = $2 and selected_user_id = $3
       ) as exists`,
      [roomId, selectedUserId, userId],
    );

    let matchId: string | null = null;
    if (reciprocal.rows[0]?.exists) {
      const inserted = await this.infra.db.query<{ id: string }>(
        `insert into matches(user_a_id,user_b_id,source_room_id)
         values($1,$2,$3) on conflict do nothing returning id::text`,
        [userId, selectedUserId, roomId],
      );
      if (inserted.rows[0]?.id) {
        matchId = inserted.rows[0].id;
        await this.infra.db.query(
          `insert into notifications(user_id,type,title,body,data)
           values
             ($1,'match','Yeni eşleşme!','Karşılıklı seçim yaptınız.',jsonb_build_object('matchId',$3::text)),
             ($2,'match','Yeni eşleşme!','Karşılıklı seçim yaptınız.',jsonb_build_object('matchId',$3::text))`,
          [userId, selectedUserId, matchId],
        );
      } else {
        const existing = await this.infra.db.query<{ id: string }>(
          `select id::text from matches
           where unmatched_at is null
             and least(user_a_id,user_b_id) = least($1::bigint,$2::bigint)
             and greatest(user_a_id,user_b_id) = greatest($1::bigint,$2::bigint)
           limit 1`,
          [userId, selectedUserId],
        );
        matchId = existing.rows[0]?.id ?? null;
      }
    }

    return { ok: true, matched: matchId != null, matchId };
  }

  async selectionResult(userId: string, roomId: string | number) {
    await this.assertMember(userId, roomId);
    const own = await this.infra.db.query<{ selected_user_id: string }>(
      `select selected_user_id::text from room_selections where room_id=$1 and user_id=$2`,
      [roomId, userId],
    );
    const selectedUserId = own.rows[0]?.selected_user_id ?? null;
    if (!selectedUserId) return { ok: true, submitted: false, matched: false, matchId: null };

    const reciprocal = await this.infra.db.query<{ exists: boolean }>(
      `select exists(
         select 1 from room_selections
         where room_id=$1 and user_id=$2 and selected_user_id=$3
       ) as exists`,
      [roomId, selectedUserId, userId],
    );
    let matchId: string | null = null;
    if (reciprocal.rows[0]?.exists) {
      const match = await this.infra.db.query<{ id: string }>(
        `select id::text from matches
         where unmatched_at is null
           and least(user_a_id,user_b_id)=least($1::bigint,$2::bigint)
           and greatest(user_a_id,user_b_id)=greatest($1::bigint,$2::bigint)
         limit 1`,
        [userId, selectedUserId],
      );
      matchId = match.rows[0]?.id ?? null;
    }
    return { ok: true, submitted: true, selectedUserId, matched: matchId != null, matchId };
  }
}
