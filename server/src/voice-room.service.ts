import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { AccessToken } from 'livekit-server-sdk';

import { BillingService } from './billing.service';
import { InfrastructureService } from './infrastructure.service';
import { RoomService } from './room.service';
import { RuntimeSettings, RuntimeSettingsService } from './runtime-settings.service';

type VoiceQueueProfileRow = {
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
};

type VoicePreviewRoomRow = {
  room_mode: string;
  status: string;
  voice_stage: string | null;
  ends_at: Date;
  selection_ends_at: Date | null;
  member: boolean;
};

@Injectable()
export class VoiceRoomService {
  private static readonly pairSize = 2;
  private static readonly pairDurationMinutes = 15;
  private static readonly previewDurationSeconds = 45;

  constructor(
    private readonly infra: InfrastructureService,
    private readonly runtimeSettings: RuntimeSettingsService,
    private readonly billing: BillingService,
    private readonly rooms: RoomService,
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

  private distanceKm(a: VoiceQueueProfileRow, b: VoiceQueueProfileRow) {
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
    a: VoiceQueueProfileRow,
    b: VoiceQueueProfileRow,
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

  private async ensurePremium(userId: string) {
    if (!await this.billing.isPremium(userId)) {
      throw new ForbiddenException('Birebir sesli eşleşme yalnız Meet6 Premium üyelerine açıktır.');
    }
  }

  private async ensureProfileReady(userId: string) {
    const result = await this.infra.db.query<{ profile_completed: boolean }>(
      'select profile_completed from profiles where user_id=$1',
      [userId],
    );
    if (!result.rows[0]?.profile_completed) {
      throw new BadRequestException('Birebir sesli eşleşme aramak için profilini tamamlamalısın.');
    }
  }

  private async currentOpenRoom(userId: string) {
    await this.rooms.syncExpiredRooms();
    const result = await this.infra.db.query<{ room_id: string; room_mode: string }>(
      `select rm.room_id::text, r.room_mode
       from room_members rm
       join rooms r on r.id=rm.room_id
       where rm.user_id=$1 and rm.left_at is null and rm.admin_removed_at is null
         and r.status in ('active','selection')
       order by rm.room_id desc
       limit 1`,
      [userId],
    );
    return result.rows[0] ?? null;
  }

  private async previewRoom(userId: string, roomId: string) {
    await this.rooms.syncExpiredRooms();
    const result = await this.infra.db.query<VoicePreviewRoomRow>(
      `select r.room_mode, r.status, r.voice_stage, r.ends_at, r.selection_ends_at,
              exists(
                select 1 from room_members rm
                where rm.room_id=r.id and rm.user_id=$2
                  and rm.admin_removed_at is null
              ) as member
       from rooms r where r.id=$1`,
      [roomId, userId],
    );
    const row = result.rows[0];
    if (!row || !row.member || row.room_mode !== 'voice') {
      throw new ForbiddenException('Bu birebir sesli görüşmeye erişimin yok.');
    }
    return row;
  }

  async joinQueue(userId: string) {
    const settings = await this.runtimeSettings.assertOperational();
    await this.ensurePremium(userId);
    await this.ensureProfileReady(userId);

    const openRoom = await this.currentOpenRoom(userId);
    if (openRoom) {
      if (openRoom.room_mode !== 'voice') {
        throw new BadRequestException('Aktif yazılı odan varken birebir sesli eşleşme arayamazsın.');
      }
      return {
        ok: true,
        state: 'room',
        room: await this.rooms.getRoom(userId, openRoom.room_id),
        roomMode: 'voice',
      };
    }

    await this.infra.db.query(
      `insert into voice_matchmaking_queue(user_id) values($1)
       on conflict(user_id) do nothing`,
      [userId],
    );

    await this.tryMatchmaking(settings);
    return this.queueStatus(userId);
  }

  async cancelQueue(userId: string) {
    await this.infra.db.query('delete from voice_matchmaking_queue where user_id=$1', [userId]);
    return { ok: true };
  }

  async queueStatus(userId: string) {
    await this.ensurePremium(userId);
    const openRoom = await this.currentOpenRoom(userId);
    if (openRoom?.room_mode === 'voice') {
      await this.infra.db.query('delete from voice_matchmaking_queue where user_id=$1', [userId]);
      return {
        ok: true,
        state: 'room',
        room: await this.rooms.getRoom(userId, openRoom.room_id),
        roomMode: 'voice',
      };
    }
    if (openRoom) {
      throw new BadRequestException('Aktif yazılı odan varken birebir sesli eşleşme arayamazsın.');
    }

    const result = await this.infra.db.query<{
      position: string;
      total: string;
      joined_at: Date;
    }>(
      `select
         (select count(*) from voice_matchmaking_queue q2 where q2.joined_at <= q.joined_at)::text as position,
         (select count(*) from voice_matchmaking_queue)::text as total,
         q.joined_at
       from voice_matchmaking_queue q
       where q.user_id=$1`,
      [userId],
    );

    const row = result.rows[0];
    if (!row) return { ok: true, state: 'idle', position: 0, total: 0, roomMode: 'voice' };

    const waitSeconds = Math.max(
      0,
      Math.floor((Date.now() - new Date(row.joined_at).getTime()) / 1000),
    );
    return {
      ok: true,
      state: 'queued',
      roomMode: 'voice',
      position: Number(row.position),
      total: Number(row.total),
      waitSeconds,
      nextRetrySeconds: this.retrySeconds,
      premiumPriority: true,
      requestedRoomDurationMinutes: VoiceRoomService.pairDurationMinutes,
      filters: {
        roomRepeatHours: (await this.runtimeSettings.get()).roomRepeatHours,
        matchedUsers: 'permanent',
        minimumRoomUsers: VoiceRoomService.pairSize,
        mode: 'one-to-one',
        blockAndReport: 'permanent',
        preferencesRelaxed: false,
      },
    };
  }

  async processQueue() {
    const settings = await this.runtimeSettings.get();
    if (settings.maintenanceMode) return false;
    return (await this.tryMatchmaking(settings)) != null;
  }

  private async tryMatchmaking(settings: RuntimeSettings): Promise<string | null> {
    const client = await this.infra.db.connect();
    try {
      await client.query('begin');
      await client.query('select pg_advisory_xact_lock(606061)');

      await client.query(
        `delete from voice_matchmaking_queue q
         using room_members rm, rooms r
         where q.user_id=rm.user_id and rm.room_id=r.id
           and rm.left_at is null and r.status in ('active','selection')`,
      );

      await client.query(
        `delete from voice_matchmaking_queue q
         where not exists(
           select 1 from user_subscriptions s
           where s.user_id=q.user_id
             and s.status in ('active','grace_period','billing_issue')
             and (s.expires_at is null or s.expires_at > now())
         )`,
      );

      const queued = await client.query<VoiceQueueProfileRow>(
        `select q.user_id::text, q.joined_at,
                p.display_name, p.birth_date::text, p.gender, p.latitude, p.longitude, p.photo_urls,
                mp.looking_for, mp.min_age, mp.max_age, mp.distance_km, mp.purpose
         from voice_matchmaking_queue q
         join users u on u.id=q.user_id and u.status='active'
         join profiles p on p.user_id=q.user_id and p.profile_completed=true
         join matching_preferences mp on mp.user_id=q.user_id
         join user_subscriptions s on s.user_id=q.user_id
           and s.status in ('active','grace_period','billing_issue')
           and (s.expires_at is null or s.expires_at > now())
         order by q.joined_at asc
         limit ${this.candidatePoolLimit}
         for update of q skip locked`,
      );

      const roomSize = VoiceRoomService.pairSize;
      if (queued.rows.length < roomSize) {
        await client.query('commit');
        return null;
      }

      const ids = queued.rows.map((row) => row.user_id);
      const forbiddenPairs = new Set<string>();

      const blocks = await client.query<{ blocker_user_id: string; blocked_user_id: string }>(
        `select blocker_user_id::text, blocked_user_id::text
         from blocked_users
         where blocker_user_id=any($1::bigint[]) or blocked_user_id=any($1::bigint[])`,
        [ids],
      );
      for (const row of blocks.rows) forbiddenPairs.add(this.pairKey(row.blocker_user_id, row.blocked_user_id));

      const reports = await client.query<{ reporter_user_id: string; reported_user_id: string }>(
        `select reporter_user_id::text, reported_user_id::text
         from reports
         where reporter_user_id=any($1::bigint[]) or reported_user_id=any($1::bigint[])`,
        [ids],
      );
      for (const row of reports.rows) forbiddenPairs.add(this.pairKey(row.reporter_user_id, row.reported_user_id));

      const recentRoomPairs = await client.query<{ user_a_id: string; user_b_id: string }>(
        `select distinct rm1.user_id::text as user_a_id, rm2.user_id::text as user_b_id
         from room_members rm1
         join room_members rm2 on rm2.room_id=rm1.room_id and rm1.user_id < rm2.user_id
         join rooms r on r.id=rm1.room_id
         where rm1.user_id=any($1::bigint[])
           and rm2.user_id=any($1::bigint[])
           and r.started_at >= now() - ($2::int * interval '1 hour')`,
        [ids, settings.roomRepeatHours],
      );
      for (const row of recentRoomPairs.rows) forbiddenPairs.add(this.pairKey(row.user_a_id, row.user_b_id));

      const matchedPairs = await client.query<{ user_a_id: string; user_b_id: string }>(
        `select user_a_id::text, user_b_id::text
         from matches
         where user_a_id=any($1::bigint[]) and user_b_id=any($1::bigint[])`,
        [ids],
      );
      for (const row of matchedPairs.rows) forbiddenPairs.add(this.pairKey(row.user_a_id, row.user_b_id));

      let pair: VoiceQueueProfileRow[] | null = null;
      for (let seedIndex = 0; seedIndex < queued.rows.length && !pair; seedIndex++) {
        const seed = queued.rows[seedIndex];
        const rest = queued.rows
          .filter((_, index) => index !== seedIndex)
          .sort((a, b) => {
            const samePurposeA = a.purpose === seed.purpose ? 0 : 1;
            const samePurposeB = b.purpose === seed.purpose ? 0 : 1;
            if (samePurposeA !== samePurposeB) return samePurposeA - samePurposeB;
            return a.joined_at.getTime() - b.joined_at.getTime();
          });

        const partner = rest.find((candidate) => this.compatible(seed, candidate, forbiddenPairs));
        if (partner) pair = [seed, partner];
      }

      if (!pair) {
        await client.query('commit');
        return null;
      }

      const room = await client.query<{ id: string }>(
        `insert into rooms(
           status,started_at,ends_at,room_duration_minutes,room_mode,voice_stage,extended
         )
         values(
           'active',now(),now() + ($1::int * interval '1 second'),$2,'voice','preview',true
         )
         returning id::text`,
        [VoiceRoomService.previewDurationSeconds, VoiceRoomService.pairDurationMinutes],
      );
      const roomId = room.rows[0].id;
      const pairIds = pair.map((row) => row.user_id);

      for (const memberId of pairIds) {
        await client.query('insert into room_members(room_id,user_id) values($1,$2)', [roomId, memberId]);
      }
      await client.query(
        `insert into room_messages(room_id,sender_user_id,body)
         values($1,null,$2)`,
        [roomId, '45 saniyelik ön görüşme başladı. Süre bitince kararın gizli olarak sorulacak.'],
      );
      await client.query('delete from voice_matchmaking_queue where user_id=any($1::bigint[])', [pairIds]);
      await client.query('commit');
      return roomId;
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }

  async previewStatus(userId: string, roomId: string) {
    const room = await this.previewRoom(userId, roomId);
    const stage = room.voice_stage ?? 'main';
    const decision = await this.infra.db.query<{ decision: boolean }>(
      `select decision from voice_preview_decisions where room_id=$1 and user_id=$2`,
      [roomId, userId],
    );
    const now = Date.now();
    const previewSecondsLeft = stage === 'preview' && room.status === 'active'
      ? Math.max(0, Math.ceil((new Date(room.ends_at).getTime() - now) / 1000))
      : 0;
    const decisionSecondsLeft = stage === 'preview' && room.status === 'selection' && room.selection_ends_at
      ? Math.max(0, Math.ceil((new Date(room.selection_ends_at).getTime() - now) / 1000))
      : 0;

    return {
      ok: true,
      phase: stage === 'preview' ? 'preview' : 'main',
      roomStatus: room.status,
      decisionOpen: stage === 'preview' && room.status === 'selection',
      myDecision: decision.rows[0]?.decision ?? null,
      previewSecondsLeft,
      decisionSecondsLeft,
      previewDurationSeconds: VoiceRoomService.previewDurationSeconds,
      mainDurationMinutes: VoiceRoomService.pairDurationMinutes,
    };
  }

  async submitPreviewDecision(userId: string, roomId: string, decisionInput: unknown) {
    await this.runtimeSettings.assertOperational();
    if (typeof decisionInput !== 'boolean') {
      throw new BadRequestException('Ön görüşme kararı geçersiz.');
    }

    await this.rooms.syncExpiredRooms();
    const client = await this.infra.db.connect();
    let outcome: 'pending' | 'continued' | 'ended' = 'pending';
    try {
      await client.query('begin');
      const roomResult = await client.query<{
        room_mode: string;
        status: string;
        voice_stage: string | null;
        member: boolean;
      }>(
        `select r.room_mode, r.status, r.voice_stage,
                exists(
                  select 1 from room_members rm
                  where rm.room_id=r.id and rm.user_id=$2
                    and rm.admin_removed_at is null
                ) as member
         from rooms r
         where r.id=$1
         for update of r`,
        [roomId, userId],
      );
      const room = roomResult.rows[0];
      if (!room || !room.member || room.room_mode !== 'voice') {
        throw new ForbiddenException('Bu birebir sesli görüşmeye erişimin yok.');
      }

      const stage = room.voice_stage ?? 'main';
      if (stage === 'main') {
        await client.query('commit');
        return { ok: true, outcome: 'continued', phase: 'main' };
      }
      if (room.status === 'closed') {
        await client.query('commit');
        return { ok: true, outcome: 'ended', phase: 'preview' };
      }
      if (decisionInput === true && room.status !== 'selection') {
        throw new BadRequestException('Devam kararı ön görüşme bittikten sonra verilebilir.');
      }
      if (!['active', 'selection'].includes(room.status)) {
        throw new BadRequestException('Ön görüşme kararı şu anda açık değil.');
      }

      await client.query(
        `insert into voice_preview_decisions(room_id,user_id,decision)
         values($1,$2,$3)
         on conflict(room_id,user_id) do update set
           decision=excluded.decision, updated_at=now()`,
        [roomId, userId, decisionInput],
      );

      if (decisionInput === false) {
        await client.query(
          `update rooms
           set status='closed', closed_at=coalesce(closed_at,now()),
               closed_reason=coalesce(closed_reason,'voice_preview_skipped')
           where id=$1`,
          [roomId],
        );
        await client.query(
          `update room_members set left_at=coalesce(left_at,now())
           where room_id=$1 and left_at is null`,
          [roomId],
        );
        outcome = 'ended';
      } else {
        const count = await client.query<{ yes: string; members: string }>(
          `select
             (select count(*) from voice_preview_decisions where room_id=$1 and decision)::text as yes,
             (select count(*) from room_members where room_id=$1 and admin_removed_at is null)::text as members`,
          [roomId],
        );
        const yes = Number(count.rows[0]?.yes ?? 0);
        const members = Number(count.rows[0]?.members ?? 0);
        if (members === VoiceRoomService.pairSize && yes === members) {
          await client.query(
            `update rooms
             set status='active', voice_stage='main', started_at=now(),
                 ends_at=now() + ($2::int * interval '1 minute'),
                 room_duration_minutes=$2, extended=false,
                 selection_started_at=null, selection_ends_at=null,
                 closed_at=null, closed_reason=null
             where id=$1`,
            [roomId, VoiceRoomService.pairDurationMinutes],
          );
          await client.query('delete from room_extension_votes where room_id=$1', [roomId]);
          await client.query(
            `insert into room_messages(room_id,sender_user_id,body)
             values($1,null,$2)`,
            [roomId, 'İkiniz de devam etmek istediniz. 15 dakikalık birebir görüşme başladı.'],
          );
          outcome = 'continued';
        }
      }

      await client.query('commit');
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }

    return {
      ok: true,
      outcome,
      phase: outcome === 'continued' ? 'main' : 'preview',
    };
  }

  async liveKitToken(userId: string, roomId: string) {
    await this.runtimeSettings.assertOperational();
    await this.ensurePremium(userId);
    await this.rooms.syncExpiredRooms();

    const result = await this.infra.db.query<{
      room_mode: string;
      status: string;
      member: boolean;
    }>(
      `select r.room_mode, r.status,
              exists(
                select 1 from room_members rm
                where rm.room_id=r.id and rm.user_id=$2
                  and rm.admin_removed_at is null and rm.left_at is null
              ) as member
       from rooms r where r.id=$1`,
      [roomId, userId],
    );
    const row = result.rows[0];
    if (!row || !row.member || row.room_mode !== 'voice') {
      throw new ForbiddenException('Bu birebir sesli görüşmeye erişimin yok.');
    }
    if (row.status !== 'active') {
      throw new BadRequestException('Birebir sesli görüşme şu anda aktif değil.');
    }

    const url = (process.env.LIVEKIT_URL ?? '').trim();
    const apiKey = (process.env.LIVEKIT_API_KEY ?? '').trim();
    const apiSecret = (process.env.LIVEKIT_API_SECRET ?? '').trim();
    if (!url || !apiKey || !apiSecret) {
      throw new ServiceUnavailableException('Sesli sohbet altyapısı henüz yapılandırılmadı.');
    }

    const roomName = `meet6-voice-${roomId}`;
    const accessToken = new AccessToken(apiKey, apiSecret, {
      identity: String(userId),
      ttl: '30m',
    });
    accessToken.addGrant({
      roomJoin: true,
      room: roomName,
      canSubscribe: true,
      canPublish: true,
      canPublishData: false,
      canPublishSources: [2 as any],
    });

    return {
      ok: true,
      url,
      roomName,
      token: await accessToken.toJwt(),
      expiresInSeconds: 1800,
    };
  }
}
