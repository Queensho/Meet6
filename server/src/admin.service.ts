import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { rm } from 'node:fs/promises';
import * as path from 'node:path';

import { AdminRemovePhotoDto, AdminUserActionDto } from './admin.dto';
import { AuthService } from './auth.service';
import { InfrastructureService } from './infrastructure.service';
import { RoomsGateway } from './rooms.gateway';

type AdminRole = 'super_admin' | 'moderator' | 'support';

type UserSummaryRow = {
  id: string;
  phone_e164: string;
  status: string;
  created_at: Date;
  last_seen_at: Date | null;
  display_name: string | null;
  birth_date: string | null;
  city: string | null;
  country: string | null;
  photo_urls: string[] | null;
  profile_completed: boolean | null;
  age: number | null;
  room_count: string;
  match_count: string;
  reports_received: string;
  reports_made: string;
  block_count: string;
  warning_count: string;
  ban_ends_at: Date | null;
  ban_reason: string | null;
};

@Injectable()
export class AdminService {
  constructor(
    private readonly infra: InfrastructureService,
    private readonly roomsGateway: RoomsGateway,
    private readonly auth: AuthService,
  ) {}

  async requireAdmin(userId: string) {
    const result = await this.infra.db.query<{ role: AdminRole }>(
      `select role from admin_users where user_id=$1 and active=true`,
      [userId],
    );
    const role = result.rows[0]?.role;
    if (!role) throw new ForbiddenException('Bu hesap admin paneline yetkili değil.');
    return { userId, role };
  }

  private async requireModerator(userId: string) {
    const admin = await this.requireAdmin(userId);
    if (admin.role === 'support') {
      throw new ForbiddenException('Bu işlem moderator veya super_admin yetkisi gerektirir.');
    }
    return admin;
  }

  async me(userId: string) {
    const admin = await this.requireAdmin(userId);
    const profile = await this.infra.db.query<{ display_name: string | null; phone_e164: string }>(
      `select p.display_name, u.phone_e164
       from users u
       left join profiles p on p.user_id=u.id
       where u.id=$1`,
      [userId],
    );
    return {
      ok: true,
      admin: {
        ...admin,
        displayName: profile.rows[0]?.display_name ?? 'Meet6 Admin',
        phoneMasked: this.maskPhone(profile.rows[0]?.phone_e164 ?? ''),
      },
    };
  }

  async dashboard(userId: string, periodDays: number) {
    const admin = await this.requireAdmin(userId);
    const days = periodDays === 30 ? 30 : 7;
    const todayStart = `(date_trunc('day', now() at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul')`;

    const [
      userCounts,
      queueCount,
      activeRooms,
      completedRooms,
      matchCounts,
      messageCounts,
      reports,
      support,
      bans,
      registrations,
      matches,
      onlineUsers,
      infraHealth,
    ] = await Promise.all([
      this.infra.db.query<{ total: string; today: string }>(
        `select count(*)::text as total,
                count(*) filter (where created_at >= ${todayStart})::text as today
         from users`,
      ),
      this.infra.db.query<{ count: string }>(`select count(*)::text as count from matchmaking_queue`),
      this.infra.db.query<{ count: string }>(
        `select count(*)::text as count from rooms where status in ('active','selection')`,
      ),
      this.infra.db.query<{ count: string }>(
        `select count(*)::text as count from rooms where status='closed' and closed_at >= ${todayStart}`,
      ),
      this.infra.db.query<{ total: string; today: string }>(
        `select count(*)::text as total,
                count(*) filter (where created_at >= ${todayStart})::text as today
         from matches`,
      ),
      this.infra.db.query<{ total: string; today: string }>(
        `select
           ((select count(*) from room_messages) + (select count(*) from private_messages))::text as total,
           ((select count(*) from room_messages where created_at >= ${todayStart}) +
            (select count(*) from private_messages where created_at >= ${todayStart}))::text as today`,
      ),
      this.infra.db.query<{ count: string }>(
        `select count(*)::text as count from reports where status='open'`,
      ),
      this.infra.db.query<{ count: string }>(
        `select count(*)::text as count from support_requests where status <> 'closed'`,
      ),
      this.infra.db.query<{ count: string }>(
        `select count(distinct user_id)::text as count
         from user_bans
         where revoked_at is null and (ends_at is null or ends_at > now())`,
      ),
      this.dailySeries('users', 'created_at', days),
      this.dailySeries('matches', 'created_at', days),
      this.onlineCount(),
      this.infra.health(),
    ]);

    const websocket = this.websocketStatus();

    return {
      ok: true,
      generatedAt: new Date().toISOString(),
      periodDays: days,
      admin,
      stats: {
        totalUsers: this.number(userCounts.rows[0]?.total),
        todayRegistrations: this.number(userCounts.rows[0]?.today),
        onlineUsers,
        queuedUsers: this.number(queueCount.rows[0]?.count),
        activeRooms: this.number(activeRooms.rows[0]?.count),
        todayCompletedRooms: this.number(completedRooms.rows[0]?.count),
        totalMatches: this.number(matchCounts.rows[0]?.total),
        todayMatches: this.number(matchCounts.rows[0]?.today),
        totalMessages: this.number(messageCounts.rows[0]?.total),
        todayMessages: this.number(messageCounts.rows[0]?.today),
        openReports: this.number(reports.rows[0]?.count),
        openSupportRequests: this.number(support.rows[0]?.count),
        bannedUsers: this.number(bans.rows[0]?.count),
      },
      charts: {
        registrations: registrations.rows.map((row) => ({
          date: row.day,
          value: this.number(row.value),
        })),
        matches: matches.rows.map((row) => ({
          date: row.day,
          value: this.number(row.value),
        })),
      },
      health: {
        api: 'ok',
        database: infraHealth.database,
        redis: infraHealth.redis,
        websocket: websocket.status,
        websocketConnections: websocket.connections,
        latencyMs: infraHealth.latencyMs,
      },
    };
  }

  async listUsers(
    adminUserId: string,
    searchInput: string,
    statusInput: string,
    pageInput: number,
    limitInput: number,
  ) {
    const admin = await this.requireAdmin(adminUserId);
    await this.releaseExpiredBans();

    const search = searchInput.trim().slice(0, 120);
    const status = ['all', 'active', 'banned', 'incomplete'].includes(statusInput)
      ? statusInput
      : 'all';
    const page = Math.max(1, Math.floor(pageInput || 1));
    const limit = Math.min(50, Math.max(10, Math.floor(limitInput || 20)));
    const offset = (page - 1) * limit;

    const where = `
      where (
        $1::text = '' or
        lower(coalesce(p.display_name, '')) like lower('%' || $1 || '%') or
        lower(coalesce(p.city, '')) like lower('%' || $1 || '%') or
        lower(coalesce(p.country, '')) like lower('%' || $1 || '%') or
        u.phone_e164 like '%' || regexp_replace($1, '[^0-9+]', '', 'g') || '%'
      )
      and (
        $2::text = 'all' or
        ($2 = 'active' and u.status <> 'banned') or
        ($2 = 'banned' and u.status = 'banned') or
        ($2 = 'incomplete' and coalesce(p.profile_completed, false) = false)
      )`;

    const [rows, total] = await Promise.all([
      this.infra.db.query<UserSummaryRow>(
        `select
           u.id::text,
           u.phone_e164,
           u.status,
           u.created_at,
           u.last_seen_at,
           p.display_name,
           p.birth_date::text,
           p.city,
           p.country,
           p.photo_urls,
           p.profile_completed,
           case when p.birth_date is null then null else extract(year from age(current_date, p.birth_date))::int end as age,
           (select count(*)::text from room_members rm where rm.user_id=u.id) as room_count,
           (select count(*)::text from matches m where m.unmatched_at is null and (m.user_a_id=u.id or m.user_b_id=u.id)) as match_count,
           (select count(*)::text from reports r where r.reported_user_id=u.id) as reports_received,
           (select count(*)::text from reports r where r.reporter_user_id=u.id) as reports_made,
           (select count(*)::text from blocked_users b where b.blocker_user_id=u.id) as block_count,
           (select count(*)::text from moderation_warnings w where w.user_id=u.id) as warning_count,
           ban.ends_at as ban_ends_at,
           ban.reason as ban_reason
         from users u
         left join profiles p on p.user_id=u.id
         left join lateral (
           select b.ends_at, b.reason
           from user_bans b
           where b.user_id=u.id and b.revoked_at is null and (b.ends_at is null or b.ends_at > now())
           order by b.created_at desc
           limit 1
         ) ban on true
         ${where}
         order by u.created_at desc
         limit $3 offset $4`,
        [search, status, limit, offset],
      ),
      this.infra.db.query<{ count: string }>(
        `select count(*)::text as count
         from users u
         left join profiles p on p.user_id=u.id
         ${where}`,
        [search, status],
      ),
    ]);

    const online = await this.onlineMap(rows.rows.map((row) => row.id));
    return {
      ok: true,
      admin,
      page,
      limit,
      total: this.number(total.rows[0]?.count),
      users: rows.rows.map((row) => this.userSummary(row, online.get(row.id) === true)),
    };
  }

  async userDetail(adminUserId: string, targetUserId: string) {
    const admin = await this.requireAdmin(adminUserId);
    await this.releaseExpiredBanForUser(targetUserId);

    const result = await this.infra.db.query<{
      id: string;
      phone_e164: string;
      status: string;
      created_at: Date;
      last_seen_at: Date | null;
      display_name: string | null;
      birth_date: string | null;
      gender: string | null;
      bio: string | null;
      city: string | null;
      country: string | null;
      profile_prompt: string | null;
      profile_answer: string | null;
      interests: string[] | null;
      photo_urls: string[] | null;
      profile_completed: boolean | null;
      latitude: number | null;
      longitude: number | null;
    }>(
      `select u.id::text, u.phone_e164, u.status, u.created_at, u.last_seen_at,
              p.display_name, p.birth_date::text, p.gender, p.bio, p.city, p.country,
              p.profile_prompt, p.profile_answer, p.interests, p.photo_urls,
              p.profile_completed, p.latitude, p.longitude
       from users u
       left join profiles p on p.user_id=u.id
       where u.id=$1`,
      [targetUserId],
    );
    const row = result.rows[0];
    if (!row) throw new NotFoundException('Kullanıcı bulunamadı.');

    const [stats, ban, warnings, online] = await Promise.all([
      this.infra.db.query<{
        rooms: string;
        matches: string;
        reports_received: string;
        reports_made: string;
        blocks: string;
        room_messages: string;
        private_messages: string;
      }>(
        `select
           (select count(*) from room_members where user_id=$1)::text as rooms,
           (select count(*) from matches where unmatched_at is null and (user_a_id=$1 or user_b_id=$1))::text as matches,
           (select count(*) from reports where reported_user_id=$1)::text as reports_received,
           (select count(*) from reports where reporter_user_id=$1)::text as reports_made,
           (select count(*) from blocked_users where blocker_user_id=$1)::text as blocks,
           (select count(*) from room_messages where sender_user_id=$1)::text as room_messages,
           (select count(*) from private_messages where sender_user_id=$1)::text as private_messages`,
        [targetUserId],
      ),
      this.infra.db.query<{ id: string; reason: string; starts_at: Date; ends_at: Date | null }>(
        `select id::text, reason, starts_at, ends_at
         from user_bans
         where user_id=$1 and revoked_at is null and (ends_at is null or ends_at > now())
         order by created_at desc limit 1`,
        [targetUserId],
      ),
      this.infra.db.query<{ id: string; reason: string; created_at: Date }>(
        `select id::text, reason, created_at
         from moderation_warnings where user_id=$1
         order by created_at desc limit 10`,
        [targetUserId],
      ),
      this.isOnline(targetUserId),
    ]);
    const s = stats.rows[0];
    const photos = row.photo_urls ?? [];

    return {
      ok: true,
      admin,
      user: {
        id: row.id,
        displayName: row.display_name ?? 'İsimsiz kullanıcı',
        phoneMasked: this.maskPhone(row.phone_e164),
        status: row.status,
        age: this.age(row.birth_date),
        city: row.city,
        country: row.country,
        gender: row.gender,
        bio: row.bio,
        profilePrompt: row.profile_prompt,
        profileAnswer: row.profile_answer,
        interests: row.interests ?? [],
        photoUrls: photos,
        profileCompleted: row.profile_completed === true,
        profileCompletion: this.profileCompletion({
          display_name: row.display_name,
          birth_date: row.birth_date,
          gender: row.gender,
          bio: row.bio,
          latitude: row.latitude,
          longitude: row.longitude,
          interests: row.interests,
          profile_prompt: row.profile_prompt,
          profile_answer: row.profile_answer,
          photo_urls: photos,
        }),
        hasPreciseLocation: row.latitude != null && row.longitude != null,
        createdAt: row.created_at,
        lastSeenAt: row.last_seen_at,
        online,
        stats: {
          rooms: this.number(s?.rooms),
          matches: this.number(s?.matches),
          reportsReceived: this.number(s?.reports_received),
          reportsMade: this.number(s?.reports_made),
          blocks: this.number(s?.blocks),
          roomMessages: this.number(s?.room_messages),
          privateMessages: this.number(s?.private_messages),
        },
        activeBan: ban.rows[0] ?? null,
        warnings: warnings.rows,
      },
    };
  }

  async moderationHistory(adminUserId: string, targetUserId: string) {
    await this.requireModerator(adminUserId);
    await this.assertUserExists(targetUserId);

    const [rooms, roomMessages, privateMessages] = await Promise.all([
      this.infra.db.query(
        `select r.id::text, r.status, r.started_at, r.closed_at, rm.joined_at, rm.left_at,
                (select count(*) from room_messages msg where msg.room_id=r.id)::int as message_count
         from room_members rm
         join rooms r on r.id=rm.room_id
         where rm.user_id=$1
         order by r.started_at desc
         limit 20`,
        [targetUserId],
      ),
      this.infra.db.query(
        `select id::text, room_id::text, body, created_at
         from room_messages
         where sender_user_id=$1
         order by created_at desc
         limit 50`,
        [targetUserId],
      ),
      this.infra.db.query(
        `select id::text, match_id::text, body, created_at, read_at
         from private_messages
         where sender_user_id=$1
         order by created_at desc
         limit 50`,
        [targetUserId],
      ),
    ]);

    await this.audit(adminUserId, 'view_moderation_history', 'user', targetUserId, {});
    return {
      ok: true,
      rooms: rooms.rows,
      roomMessages: roomMessages.rows,
      privateMessages: privateMessages.rows,
    };
  }

  async moderateUser(adminUserId: string, targetUserId: string, body: AdminUserActionDto) {
    const admin = await this.requireModerator(adminUserId);
    await this.assertModerationTarget(admin, targetUserId);

    const reason = body.reason?.trim() ?? '';
    if ((body.action === 'warn' || body.action === 'ban') && reason.length < 3) {
      throw new BadRequestException('Uyarı veya ban için en az 3 karakterlik neden gerekli.');
    }

    if (body.action === 'warn') {
      const warning = await this.infra.db.query<{ id: string; created_at: Date }>(
        `insert into moderation_warnings(user_id, admin_user_id, reason)
         values($1,$2,$3) returning id::text, created_at`,
        [targetUserId, adminUserId, reason],
      );
      await this.infra.db.query(
        `insert into notifications(user_id, type, title, body, data)
         values($1, 'moderation_warning', 'Meet6 uyarısı', $2, '{}'::jsonb)`,
        [targetUserId, reason],
      );
      await this.audit(adminUserId, 'warn_user', 'user', targetUserId, { reason });
      return { ok: true, action: 'warn', warning: warning.rows[0] };
    }

    if (body.action === 'ban') {
      const endsAt = body.durationHours
        ? new Date(Date.now() + body.durationHours * 60 * 60 * 1000)
        : null;
      const client = await this.infra.db.connect();
      try {
        await client.query('begin');
        await client.query(
          `update user_bans set revoked_at=now(), revoked_by=$2
           where user_id=$1 and revoked_at is null and (ends_at is null or ends_at > now())`,
          [targetUserId, adminUserId],
        );
        await client.query(
          `insert into user_bans(user_id, admin_user_id, reason, ends_at)
           values($1,$2,$3,$4)`,
          [targetUserId, adminUserId, reason, endsAt],
        );
        await client.query(`update users set status='banned', updated_at=now() where id=$1`, [targetUserId]);
        await client.query(`delete from matchmaking_queue where user_id=$1`, [targetUserId]);
        await client.query('commit');
      } catch (error) {
        await client.query('rollback').catch(() => undefined);
        throw error;
      } finally {
        client.release();
      }
      await this.disconnectUser(targetUserId);
      await this.audit(adminUserId, 'ban_user', 'user', targetUserId, {
        reason,
        durationHours: body.durationHours ?? null,
        endsAt,
      });
      return { ok: true, action: 'ban', permanent: endsAt == null, endsAt };
    }

    if (body.action === 'unban') {
      await this.infra.db.query(
        `update user_bans set revoked_at=now(), revoked_by=$2
         where user_id=$1 and revoked_at is null and (ends_at is null or ends_at > now())`,
        [targetUserId, adminUserId],
      );
      await this.infra.db.query(`update users set status='active', updated_at=now() where id=$1`, [targetUserId]);
      await this.audit(adminUserId, 'unban_user', 'user', targetUserId, {});
      return { ok: true, action: 'unban' };
    }

    await this.infra.db.query(`delete from matchmaking_queue where user_id=$1`, [targetUserId]);
    await this.roomsGateway.broadcastQueueStatus().catch(() => undefined);
    await this.audit(adminUserId, 'remove_from_matchmaking', 'user', targetUserId, {});
    return { ok: true, action: 'remove_matchmaking' };
  }

  async removePhoto(adminUserId: string, targetUserId: string, body: AdminRemovePhotoDto) {
    const admin = await this.requireModerator(adminUserId);
    await this.assertModerationTarget(admin, targetUserId);

    const photoUrl = body.photoUrl.trim();
    const profile = await this.infra.db.query<{ photo_urls: string[] | null }>(
      `select photo_urls from profiles where user_id=$1`,
      [targetUserId],
    );
    const photos = profile.rows[0]?.photo_urls ?? [];
    if (!photos.includes(photoUrl)) throw new NotFoundException('Profil fotoğrafı bulunamadı.');

    const remaining = photos.filter((value) => value !== photoUrl);
    await this.infra.db.query(
      `update profiles
       set photo_urls=$2,
           profile_completed=case when cardinality($2::text[]) >= 3 then profile_completed else false end,
           updated_at=now()
       where user_id=$1`,
      [targetUserId, remaining],
    );

    const ownPrefix = `/uploads/profile/${targetUserId}/`;
    if (photoUrl.startsWith(ownPrefix)) {
      const root = process.env.UPLOAD_ROOT ?? '/var/www/meet6/uploads';
      const filename = path.basename(photoUrl);
      await rm(path.join(root, 'profile', targetUserId, filename), { force: true }).catch(() => undefined);
    }

    await this.audit(adminUserId, 'remove_profile_photo', 'user', targetUserId, { photoUrl });
    return { ok: true, photoUrls: remaining, profileCompleted: remaining.length >= 3 };
  }

  private userSummary(row: UserSummaryRow, online: boolean) {
    const photos = row.photo_urls ?? [];
    return {
      id: row.id,
      displayName: row.display_name ?? 'İsimsiz kullanıcı',
      phoneMasked: this.maskPhone(row.phone_e164),
      age: row.age,
      city: row.city,
      country: row.country,
      status: row.status,
      online,
      createdAt: row.created_at,
      lastSeenAt: row.last_seen_at,
      photoUrl: photos[0] ?? null,
      photoCount: photos.length,
      profileCompleted: row.profile_completed === true,
      roomCount: this.number(row.room_count),
      matchCount: this.number(row.match_count),
      reportsReceived: this.number(row.reports_received),
      reportsMade: this.number(row.reports_made),
      blockCount: this.number(row.block_count),
      warningCount: this.number(row.warning_count),
      activeBan: row.status === 'banned'
        ? { endsAt: row.ban_ends_at, reason: row.ban_reason }
        : null,
    };
  }

  private async assertUserExists(userId: string) {
    const result = await this.infra.db.query(`select 1 from users where id=$1`, [userId]);
    if (!result.rowCount) throw new NotFoundException('Kullanıcı bulunamadı.');
  }

  private async assertModerationTarget(admin: { userId: string; role: AdminRole }, targetUserId: string) {
    await this.assertUserExists(targetUserId);
    if (admin.userId === targetUserId) {
      throw new BadRequestException('Kendi admin hesabında moderasyon işlemi yapamazsın.');
    }
    const targetAdmin = await this.infra.db.query<{ role: AdminRole }>(
      `select role from admin_users where user_id=$1 and active=true`,
      [targetUserId],
    );
    if (targetAdmin.rowCount && admin.role !== 'super_admin') {
      throw new ForbiddenException('Admin hesaplarını yalnızca super_admin yönetebilir.');
    }
  }

  private async disconnectUser(userId: string) {
    await this.auth.revokeAllSessions(userId).catch(() => undefined);
    await this.infra.redis.del(`presence:${userId}`).catch(() => undefined);
    try {
      const server = this.roomsGateway.server as any;
      server?.in?.(`user:${userId}`)?.disconnectSockets?.(true);
    } catch (_) {}
    await this.roomsGateway.broadcastQueueStatus().catch(() => undefined);
  }

  private async releaseExpiredBans() {
    await this.infra.db.query(
      `update users u set status='active', updated_at=now()
       where u.status='banned'
         and not exists (
           select 1 from user_bans b
           where b.user_id=u.id and b.revoked_at is null and (b.ends_at is null or b.ends_at > now())
         )`,
    );
  }

  private async releaseExpiredBanForUser(userId: string) {
    await this.infra.db.query(
      `update users u set status='active', updated_at=now()
       where u.id=$1 and u.status='banned'
         and not exists (
           select 1 from user_bans b
           where b.user_id=u.id and b.revoked_at is null and (b.ends_at is null or b.ends_at > now())
         )`,
      [userId],
    );
  }

  private async audit(
    adminUserId: string,
    action: string,
    targetType: string,
    targetId: string,
    detail: Record<string, unknown>,
  ) {
    await this.infra.db.query(
      `insert into admin_audit_log(admin_user_id, action, target_type, target_id, detail)
       values($1,$2,$3,$4,$5::jsonb)`,
      [adminUserId, action, targetType, targetId, JSON.stringify(detail)],
    );
  }

  private dailySeries(table: 'users' | 'matches', column: 'created_at', days: number) {
    return this.infra.db.query<{ day: string; value: string }>(
      `with days as (
         select generate_series(
           (now() at time zone 'Europe/Istanbul')::date - ($1::int - 1),
           (now() at time zone 'Europe/Istanbul')::date,
           interval '1 day'
         )::date as day
       )
       select d.day::text as day, count(t.*)::text as value
       from days d
       left join ${table} t
         on (t.${column} at time zone 'Europe/Istanbul')::date = d.day
       group by d.day
       order by d.day asc`,
      [days],
    );
  }

  private async onlineCount() {
    let cursor = '0';
    let count = 0;
    do {
      const [next, keys] = await this.infra.redis.scan(
        cursor,
        'MATCH',
        'presence:*',
        'COUNT',
        '200',
      );
      cursor = next;
      if (keys.length) {
        const pipeline = this.infra.redis.pipeline();
        for (const key of keys) pipeline.scard(key);
        const results = await pipeline.exec();
        for (const item of results ?? []) {
          const value = Number(item?.[1] ?? 0);
          if (value > 0) count += 1;
        }
      }
    } while (cursor !== '0');
    return count;
  }

  private async onlineMap(userIds: string[]) {
    const result = new Map<string, boolean>();
    if (!userIds.length) return result;
    const pipeline = this.infra.redis.pipeline();
    for (const id of userIds) pipeline.scard(`presence:${id}`);
    const values = await pipeline.exec().catch(() => null);
    userIds.forEach((id, index) => {
      result.set(id, Number(values?.[index]?.[1] ?? 0) > 0);
    });
    return result;
  }

  private async isOnline(userId: string) {
    return (await this.infra.redis.scard(`presence:${userId}`).catch(() => 0)) > 0;
  }

  private websocketStatus() {
    const server = this.roomsGateway.server as any;
    if (!server) return { status: 'starting', connections: 0 };
    const directMap = server.sockets instanceof Map ? server.sockets : null;
    const nestedMap = server.sockets?.sockets instanceof Map ? server.sockets.sockets : null;
    const connections = Number((directMap ?? nestedMap)?.size ?? 0);
    return { status: 'ok', connections };
  }

  private profileCompletion(row: {
    display_name: string | null;
    birth_date: string | null;
    gender: string | null;
    bio: string | null;
    latitude: number | null;
    longitude: number | null;
    interests: string[] | null;
    profile_prompt: string | null;
    profile_answer: string | null;
    photo_urls: string[] | null;
  }) {
    const checks = [
      !!row.display_name?.trim(),
      !!row.birth_date,
      !!row.gender?.trim(),
      !!row.bio?.trim(),
      row.latitude != null && row.longitude != null,
      (row.interests?.length ?? 0) > 0,
      !!row.profile_prompt?.trim() && !!row.profile_answer?.trim(),
      (row.photo_urls?.length ?? 0) >= 3,
    ];
    return Math.round((checks.filter(Boolean).length / checks.length) * 100);
  }

  private age(birthDate: string | null) {
    if (!birthDate) return null;
    const birth = new Date(`${birthDate}T00:00:00Z`);
    if (Number.isNaN(birth.getTime())) return null;
    const now = new Date();
    let age = now.getUTCFullYear() - birth.getUTCFullYear();
    const month = now.getUTCMonth() - birth.getUTCMonth();
    if (month < 0 || (month === 0 && now.getUTCDate() < birth.getUTCDate())) age--;
    return age;
  }

  private number(value: unknown) {
    const parsed = Number(value ?? 0);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  private maskPhone(phone: string) {
    if (phone.length < 7) return phone;
    return `${phone.slice(0, 4)}***${phone.slice(-3)}`;
  }
}
