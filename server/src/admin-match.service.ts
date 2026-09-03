import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { InfrastructureService } from './infrastructure.service';
import { RoomsGateway } from './rooms.gateway';
import { SocialService } from './social.service';

type AdminRole = 'super_admin' | 'moderator' | 'support';

type MatchRow = {
  id: string;
  user_a_id: string;
  user_b_id: string;
  created_at: Date;
  unmatched_at: Date | null;
  source_room_id: string | null;
  unmatched_reason: string | null;
  ended_by_admin_id: string | null;
  admin_end_reason: string | null;
  user_a_name: string | null;
  user_b_name: string | null;
  user_a_photos: string[] | null;
  user_b_photos: string[] | null;
  last_message_at: Date | null;
  last_message: string | null;
  message_count: number;
  a_blocked_b: boolean;
  b_blocked_a: boolean;
  report_count: number;
  open_report_count: number;
};

@Injectable()
export class AdminMatchService {
  constructor(
    private readonly infra: InfrastructureService,
    private readonly roomsGateway: RoomsGateway,
    private readonly social: SocialService,
  ) {}

  private async requireAdmin(userId: string) {
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

  async listMatches(
    adminUserId: string,
    statusInput: string,
    searchInput: string,
    pageInput: number,
    limitInput: number,
  ) {
    const admin = await this.requireAdmin(adminUserId);
    const status = ['all', 'active', 'removed'].includes(statusInput) ? statusInput : 'all';
    const search = searchInput.trim().slice(0, 100);
    const page = Math.max(1, Math.floor(pageInput || 1));
    const limit = Math.min(50, Math.max(10, Math.floor(limitInput || 20)));
    const offset = (page - 1) * limit;

    const where = `where
      ($1::text = 'all'
       or ($1 = 'active' and m.unmatched_at is null)
       or ($1 = 'removed' and m.unmatched_at is not null))
      and (
        $2::text = ''
        or m.id::text = $2
        or coalesce(m.source_room_id::text, '') = $2
        or lower(coalesce(pa.display_name, '')) like lower('%' || $2 || '%')
        or lower(coalesce(pb.display_name, '')) like lower('%' || $2 || '%')
      )`;

    const [rows, total] = await Promise.all([
      this.infra.db.query<MatchRow>(
        `select
           m.id::text,
           m.user_a_id::text,
           m.user_b_id::text,
           m.created_at,
           m.unmatched_at,
           m.source_room_id::text,
           m.unmatched_reason,
           m.ended_by_admin_id::text,
           m.admin_end_reason,
           pa.display_name as user_a_name,
           pb.display_name as user_b_name,
           pa.photo_urls as user_a_photos,
           pb.photo_urls as user_b_photos,
           last_message.created_at as last_message_at,
           last_message.body as last_message,
           (select count(*)::int from private_messages pm where pm.match_id=m.id) as message_count,
           exists(
             select 1 from blocked_users b
             where b.blocker_user_id=m.user_a_id and b.blocked_user_id=m.user_b_id
           ) as a_blocked_b,
           exists(
             select 1 from blocked_users b
             where b.blocker_user_id=m.user_b_id and b.blocked_user_id=m.user_a_id
           ) as b_blocked_a,
           (select count(*)::int from reports r
            where (r.reporter_user_id=m.user_a_id and r.reported_user_id=m.user_b_id)
               or (r.reporter_user_id=m.user_b_id and r.reported_user_id=m.user_a_id)) as report_count,
           (select count(*)::int from reports r
            where r.status='open' and (
              (r.reporter_user_id=m.user_a_id and r.reported_user_id=m.user_b_id)
              or (r.reporter_user_id=m.user_b_id and r.reported_user_id=m.user_a_id)
            )) as open_report_count
         from matches m
         left join profiles pa on pa.user_id=m.user_a_id
         left join profiles pb on pb.user_id=m.user_b_id
         left join lateral (
           select pm.body, pm.created_at
           from private_messages pm
           where pm.match_id=m.id
           order by pm.id desc
           limit 1
         ) last_message on true
         ${where}
         order by coalesce(last_message.created_at, m.created_at) desc
         limit $3 offset $4`,
        [status, search, limit, offset],
      ),
      this.infra.db.query<{ count: string }>(
        `select count(*)::text as count
         from matches m
         left join profiles pa on pa.user_id=m.user_a_id
         left join profiles pb on pb.user_id=m.user_b_id
         ${where}`,
        [status, search],
      ),
    ]);

    return {
      ok: true,
      admin,
      page,
      limit,
      total: Number(total.rows[0]?.count ?? 0),
      matches: rows.rows.map((row) => this.serialize(row)),
    };
  }

  async matchDetail(adminUserId: string, matchId: string) {
    const admin = await this.requireAdmin(adminUserId);
    const result = await this.infra.db.query<MatchRow>(
      `select
         m.id::text,
         m.user_a_id::text,
         m.user_b_id::text,
         m.created_at,
         m.unmatched_at,
         m.source_room_id::text,
         m.unmatched_reason,
         m.ended_by_admin_id::text,
         m.admin_end_reason,
         pa.display_name as user_a_name,
         pb.display_name as user_b_name,
         pa.photo_urls as user_a_photos,
         pb.photo_urls as user_b_photos,
         last_message.created_at as last_message_at,
         last_message.body as last_message,
         (select count(*)::int from private_messages pm where pm.match_id=m.id) as message_count,
         exists(select 1 from blocked_users b where b.blocker_user_id=m.user_a_id and b.blocked_user_id=m.user_b_id) as a_blocked_b,
         exists(select 1 from blocked_users b where b.blocker_user_id=m.user_b_id and b.blocked_user_id=m.user_a_id) as b_blocked_a,
         (select count(*)::int from reports r
          where (r.reporter_user_id=m.user_a_id and r.reported_user_id=m.user_b_id)
             or (r.reporter_user_id=m.user_b_id and r.reported_user_id=m.user_a_id)) as report_count,
         (select count(*)::int from reports r
          where r.status='open' and (
            (r.reporter_user_id=m.user_a_id and r.reported_user_id=m.user_b_id)
            or (r.reporter_user_id=m.user_b_id and r.reported_user_id=m.user_a_id)
          )) as open_report_count
       from matches m
       left join profiles pa on pa.user_id=m.user_a_id
       left join profiles pb on pb.user_id=m.user_b_id
       left join lateral (
         select pm.body, pm.created_at
         from private_messages pm
         where pm.match_id=m.id
         order by pm.id desc limit 1
       ) last_message on true
       where m.id=$1`,
      [matchId],
    );
    const match = result.rows[0];
    if (!match) throw new NotFoundException('Eşleşme bulunamadı.');

    const [reports, messages] = await Promise.all([
      this.infra.db.query(
        `select r.id::text, r.reporter_user_id::text, reporter.display_name as reporter_name,
                r.reported_user_id::text, reported.display_name as reported_name,
                r.room_id::text, r.reason, r.detail, r.status, r.created_at
         from reports r
         left join profiles reporter on reporter.user_id=r.reporter_user_id
         left join profiles reported on reported.user_id=r.reported_user_id
         where (r.reporter_user_id=$1 and r.reported_user_id=$2)
            or (r.reporter_user_id=$2 and r.reported_user_id=$1)
         order by r.created_at desc
         limit 100`,
        [match.user_a_id, match.user_b_id],
      ),
      this.infra.db.query(
        `select * from (
           select pm.id::text, pm.sender_user_id::text, p.display_name,
                  pm.body, pm.created_at, pm.delivered_at, pm.read_at
           from private_messages pm
           left join profiles p on p.user_id=pm.sender_user_id
           where pm.match_id=$1
           order by pm.id desc
           limit 100
         ) latest
         order by id::bigint asc`,
        [matchId],
      ),
    ]);

    return {
      ok: true,
      admin,
      match: {
        ...this.serialize(match),
        reports: reports.rows,
        messages: messages.rows,
      },
    };
  }

  async endMatch(adminUserId: string, matchId: string, reasonInput: string) {
    await this.requireModerator(adminUserId);
    const reason = reasonInput.trim();
    if (reason.length < 3) throw new BadRequestException('Eşleşmeyi sonlandırmak için neden gerekli.');

    const client = await this.infra.db.connect();
    let userA = '';
    let userB = '';
    try {
      await client.query('begin');
      const current = await client.query<{
        user_a_id: string;
        user_b_id: string;
        unmatched_at: Date | null;
      }>(
        `select user_a_id::text, user_b_id::text, unmatched_at
         from matches where id=$1 for update`,
        [matchId],
      );
      const row = current.rows[0];
      if (!row) throw new NotFoundException('Eşleşme bulunamadı.');
      if (row.unmatched_at) throw new BadRequestException('Eşleşme zaten kaldırılmış.');
      userA = row.user_a_id;
      userB = row.user_b_id;

      await client.query(
        `update matches
         set unmatched_at=now(),
             unmatched_reason='admin',
             unmatched_by_user_id=null,
             ended_by_admin_id=$2,
             admin_end_reason=$3
         where id=$1`,
        [matchId, adminUserId, reason.slice(0, 240)],
      );
      await client.query('commit');
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }

    await this.audit(adminUserId, 'end_match', 'match', matchId, {
      userA,
      userB,
      reason,
    });

    const event = {
      matchId,
      reason,
      endedBy: 'admin',
      timestamp: new Date().toISOString(),
    };
    this.roomsGateway.server.to(`user:${userA}`).emit('match:ended-by-admin', event);
    this.roomsGateway.server.to(`user:${userB}`).emit('match:ended-by-admin', event);
    this.roomsGateway.server.in(`match:${matchId}`).socketsLeave(`match:${matchId}`);

    await Promise.all([
      this.social.listMatches(userA).then((snapshot) => {
        this.roomsGateway.server.to(`user:${userA}`).emit('matches:update', snapshot);
      }).catch(() => undefined),
      this.social.listMatches(userB).then((snapshot) => {
        this.roomsGateway.server.to(`user:${userB}`).emit('matches:update', snapshot);
      }).catch(() => undefined),
    ]);

    return { ok: true, matchId, status: 'removed' };
  }

  private serialize(row: MatchRow) {
    return {
      id: row.id,
      status: row.unmatched_at ? 'removed' : 'active',
      matchedAt: row.created_at,
      removedAt: row.unmatched_at,
      sourceRoomId: row.source_room_id,
      unmatchedReason: row.unmatched_reason,
      endedByAdminId: row.ended_by_admin_id,
      adminEndReason: row.admin_end_reason,
      userA: {
        id: row.user_a_id,
        displayName: row.user_a_name ?? 'Meet6',
        photoUrl: row.user_a_photos?.[0] ?? null,
        blockedOther: row.a_blocked_b === true,
      },
      userB: {
        id: row.user_b_id,
        displayName: row.user_b_name ?? 'Meet6',
        photoUrl: row.user_b_photos?.[0] ?? null,
        blockedOther: row.b_blocked_a === true,
      },
      blockState: {
        userABlockedUserB: row.a_blocked_b === true,
        userBBlockedUserA: row.b_blocked_a === true,
        any: row.a_blocked_b === true || row.b_blocked_a === true,
        mutual: row.a_blocked_b === true && row.b_blocked_a === true,
      },
      lastMessage: row.last_message,
      lastMessageAt: row.last_message_at,
      messageCount: Number(row.message_count ?? 0),
      reportCount: Number(row.report_count ?? 0),
      openReportCount: Number(row.open_report_count ?? 0),
      hasReports: Number(row.report_count ?? 0) > 0,
    };
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
}
