import { Injectable } from '@nestjs/common';
import type { PoolClient } from 'pg';

import { InfrastructureService } from './infrastructure.service';
import { RuntimeSettingsService } from './runtime-settings.service';

type QueueProfileRow = {
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
  priority_tier: number;
  requested_room_duration_minutes: number;
};

type RefillRoomRow = {
  id: string;
  room_duration_minutes: number;
  active_count: number;
};

@Injectable()
export class RoomRefillService {
  private static readonly refillWindowMinutes = 5;

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

  private async forbiddenPairs(
    client: PoolClient,
    ids: string[],
    roomRepeatHours: number,
  ) {
    const forbidden = new Set<string>();
    if (ids.length < 2) return forbidden;

    const blocks = await client.query<{
      blocker_user_id: string;
      blocked_user_id: string;
    }>(
      `select blocker_user_id::text, blocked_user_id::text
       from blocked_users
       where blocker_user_id = any($1::bigint[])
         and blocked_user_id = any($1::bigint[])`,
      [ids],
    );
    for (const row of blocks.rows) {
      forbidden.add(this.pairKey(row.blocker_user_id, row.blocked_user_id));
    }

    const reports = await client.query<{
      reporter_user_id: string;
      reported_user_id: string;
    }>(
      `select reporter_user_id::text, reported_user_id::text
       from reports
       where reporter_user_id = any($1::bigint[])
         and reported_user_id = any($1::bigint[])`,
      [ids],
    );
    for (const row of reports.rows) {
      forbidden.add(this.pairKey(row.reporter_user_id, row.reported_user_id));
    }

    const matches = await client.query<{
      user_a_id: string;
      user_b_id: string;
    }>(
      `select user_a_id::text, user_b_id::text
       from matches
       where user_a_id = any($1::bigint[])
         and user_b_id = any($1::bigint[])`,
      [ids],
    );
    for (const row of matches.rows) {
      forbidden.add(this.pairKey(row.user_a_id, row.user_b_id));
    }

    const recentPairs = await client.query<{
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
      [ids, roomRepeatHours],
    );
    for (const row of recentPairs.rows) {
      forbidden.add(this.pairKey(row.user_a_id, row.user_b_id));
    }

    return forbidden;
  }

  async processOpenSeats(): Promise<string[]> {
    const settings = await this.runtimeSettings.get();
    if (settings.maintenanceMode) return [];

    const roomSize = Number(settings.minimumRoomUsers);
    if (!Number.isFinite(roomSize) || roomSize < 2) return [];

    const client = await this.infra.db.connect();
    try {
      await client.query('begin');
      await client.query('select pg_advisory_xact_lock(606062)');

      // Keep stale queue rows from competing with users who are already in a room.
      await client.query(
        `delete from matchmaking_queue q
         using room_members rm, rooms r
         where q.user_id=rm.user_id
           and rm.room_id=r.id
           and rm.left_at is null
           and rm.admin_removed_at is null
           and r.status in ('active','selection')`,
      );

      // Keep Premium priority and 30-minute entitlement fresh before refill selection.
      await client.query(
        `update matchmaking_queue q
         set priority_tier = case when exists(
               select 1 from user_subscriptions s
               where s.user_id=q.user_id
                 and s.status in ('active','grace_period','billing_issue')
                 and (s.expires_at is null or s.expires_at > now())
             ) then 1 else 0 end,
             requested_room_duration_minutes = case
               when q.requested_room_duration_minutes=30 and not exists(
                 select 1 from user_subscriptions s
                 where s.user_id=q.user_id
                   and s.status in ('active','grace_period','billing_issue')
                   and (s.expires_at is null or s.expires_at > now())
               ) then 15
               else q.requested_room_duration_minutes
             end`,
      );

      const queued = await client.query<QueueProfileRow>(
        `select q.user_id::text, q.joined_at, q.priority_tier,
                q.requested_room_duration_minutes,
                p.display_name, p.birth_date::text, p.gender,
                p.latitude, p.longitude, p.photo_urls,
                mp.looking_for, mp.min_age, mp.max_age, mp.distance_km, mp.purpose
         from matchmaking_queue q
         join users u on u.id=q.user_id and u.status='active'
         join profiles p on p.user_id=q.user_id and p.profile_completed=true
         join matching_preferences mp on mp.user_id=q.user_id
         order by q.priority_tier desc, q.joined_at asc
         limit ${this.candidatePoolLimit}
         for update of q skip locked`,
      );
      if (!queued.rows.length) {
        await client.query('commit');
        return [];
      }

      const rooms = await client.query<RefillRoomRow>(
        `select r.id::text, r.room_duration_minutes,
                (select count(*)::int
                 from room_members rm
                 where rm.room_id=r.id
                   and rm.left_at is null
                   and rm.admin_removed_at is null) as active_count
         from rooms r
         where r.status='active'
           and r.room_mode='text'
           and r.started_at > now() - (${RoomRefillService.refillWindowMinutes} * interval '1 minute')
           and (select count(*)
                from room_members rm
                where rm.room_id=r.id
                  and rm.left_at is null
                  and rm.admin_removed_at is null) between 1 and $1 - 1
         order by r.started_at asc
         for update of r skip locked`,
        [roomSize],
      );

      const assigned = new Set<string>();
      const changedRooms: string[] = [];

      for (const room of rooms.rows) {
        const activeMembers = await client.query<QueueProfileRow>(
          `select rm.user_id::text,
                  p.display_name, p.birth_date::text, p.gender,
                  p.latitude, p.longitude, p.photo_urls,
                  mp.looking_for, mp.min_age, mp.max_age, mp.distance_km, mp.purpose,
                  rm.joined_at,
                  0::int as priority_tier,
                  $2::int as requested_room_duration_minutes
           from room_members rm
           join users u on u.id=rm.user_id and u.status='active'
           join profiles p on p.user_id=rm.user_id and p.profile_completed=true
           join matching_preferences mp on mp.user_id=rm.user_id
           where rm.room_id=$1
             and rm.left_at is null
             and rm.admin_removed_at is null
           order by rm.joined_at asc`,
          [room.id, Number(room.room_duration_minutes)],
        );

        const priorMembers = await client.query<{ user_id: string }>(
          'select user_id::text from room_members where room_id=$1',
          [room.id],
        );
        const priorIds = new Set(priorMembers.rows.map((row) => row.user_id));
        const available = queued.rows.filter((candidate) =>
          !assigned.has(candidate.user_id)
          && !priorIds.has(candidate.user_id)
          && Number(candidate.requested_room_duration_minutes) === Number(room.room_duration_minutes),
        );
        if (!available.length) continue;

        const universe = [
          ...activeMembers.rows.map((row) => row.user_id),
          ...available.map((row) => row.user_id),
        ];
        const forbidden = await this.forbiddenPairs(client, universe, settings.roomRepeatHours);

        const members = [...activeMembers.rows];
        const seats = Math.max(0, roomSize - Number(room.active_count));
        const selected: QueueProfileRow[] = [];

        for (const candidate of available) {
          if (selected.length >= seats) break;
          if (members.every((member) => this.compatible(member, candidate, forbidden))) {
            selected.push(candidate);
            members.push(candidate);
          }
        }

        if (!selected.length) continue;

        for (const candidate of selected) {
          await client.query(
            `insert into room_members(room_id,user_id)
             values($1,$2)`,
            [room.id, candidate.user_id],
          );
          assigned.add(candidate.user_id);
        }

        await client.query(
          `insert into room_messages(room_id,sender_user_id,body)
           values($1,null,$2)`,
          [
            room.id,
            selected.length === 1
              ? 'Yeni bir kişi odaya katıldı. Süre değişmedi; sohbet kaldığı yerden devam ediyor.'
              : `${selected.length} yeni kişi odaya katıldı. Süre değişmedi; sohbet kaldığı yerden devam ediyor.`,
          ],
        );
        changedRooms.push(room.id);
      }

      await client.query('commit');
      return changedRooms;
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }
}
