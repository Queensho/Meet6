import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { AdminReportActionDto } from './admin.dto';
import { AdminService } from './admin.service';
import { InfrastructureService } from './infrastructure.service';

type AdminRole = 'super_admin' | 'moderator' | 'support';

type ReportRow = {
  id: string;
  reporter_user_id: string;
  reported_user_id: string;
  room_id: string | null;
  match_id: string | null;
  reason: string;
  detail: string | null;
  status: string;
  moderator_note: string | null;
  reviewed_by_admin_id: string | null;
  reviewed_at: Date | null;
  resolved_at: Date | null;
  resolution: string | null;
  created_at: Date;
  updated_at: Date;
};

@Injectable()
export class AdminReportService {
  constructor(
    private readonly infra: InfrastructureService,
    private readonly adminService: AdminService,
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

  async listReports(
    adminUserId: string,
    statusInput: string,
    searchInput: string,
    pageInput: number,
    limitInput: number,
  ) {
    const admin = await this.requireAdmin(adminUserId);
    const allowedStatuses = ['all', 'open', 'reviewing', 'resolved', 'rejected'];
    const status = allowedStatuses.includes(statusInput) ? statusInput : 'open';
    const search = searchInput.trim().slice(0, 140);
    const page = Math.max(1, Math.floor(pageInput || 1));
    const limit = Math.min(50, Math.max(10, Math.floor(limitInput || 20)));
    const offset = (page - 1) * limit;

    const where = `
      where ($1::text='all' or r.status=$1)
        and (
          $2::text='' or
          r.id::text=$2 or
          lower(r.reason) like lower('%' || $2 || '%') or
          lower(coalesce(r.detail,'')) like lower('%' || $2 || '%') or
          lower(coalesce(reporter.display_name,'')) like lower('%' || $2 || '%') or
          lower(coalesce(reported.display_name,'')) like lower('%' || $2 || '%')
        )`;

    const [rows, total, counts] = await Promise.all([
      this.infra.db.query(
        `select
           r.id::text,
           r.reporter_user_id::text,
           reporter.display_name as reporter_name,
           reporter.photo_urls as reporter_photos,
           r.reported_user_id::text,
           reported.display_name as reported_name,
           reported.photo_urls as reported_photos,
           r.reason,
           r.detail,
           r.status,
           r.room_id::text,
           r.match_id::text,
           r.created_at,
           r.reviewed_at,
           r.resolved_at,
           r.resolution,
           r.moderator_note,
           (select count(*)::int
              from reports old
             where old.reported_user_id=r.reported_user_id and old.id<>r.id) as previous_report_count,
           (select count(*)::int from report_evidence_messages ev where ev.report_id=r.id) as evidence_count,
           (select count(*)::int from report_evidence_messages ev where ev.report_id=r.id and ev.is_key_evidence) as key_evidence_count,
           (select count(*)::int from moderation_warnings w where w.user_id=r.reported_user_id) as warning_count,
           exists(
             select 1 from user_bans b
             where b.user_id=r.reported_user_id
               and b.revoked_at is null and (b.ends_at is null or b.ends_at>now())
           ) as actively_banned
         from reports r
         left join profiles reporter on reporter.user_id=r.reporter_user_id
         left join profiles reported on reported.user_id=r.reported_user_id
         ${where}
         order by
           case r.status when 'open' then 0 when 'reviewing' then 1 else 2 end,
           r.created_at desc
         limit $3 offset $4`,
        [status, search, limit, offset],
      ),
      this.infra.db.query<{ count: string }>(
        `select count(*)::text as count
         from reports r
         left join profiles reporter on reporter.user_id=r.reporter_user_id
         left join profiles reported on reported.user_id=r.reported_user_id
         ${where}`,
        [status, search],
      ),
      this.infra.db.query<{ status: string; count: string }>(
        `select status, count(*)::text as count
         from reports
         where status in ('open','reviewing','resolved','rejected')
         group by status`,
      ),
    ]);

    const stats: Record<string, number> = {
      open: 0,
      reviewing: 0,
      resolved: 0,
      rejected: 0,
    };
    for (const row of counts.rows) stats[row.status] = Number(row.count ?? 0);

    return {
      ok: true,
      admin,
      canModerate: admin.role !== 'support',
      page,
      limit,
      total: Number(total.rows[0]?.count ?? 0),
      stats,
      reports: rows.rows.map((row: any) => ({
        id: row.id,
        status: row.status,
        reason: row.reason,
        detail: row.detail,
        createdAt: row.created_at,
        reviewedAt: row.reviewed_at,
        resolvedAt: row.resolved_at,
        resolution: row.resolution,
        moderatorNote: row.moderator_note,
        roomId: row.room_id,
        matchId: row.match_id,
        contextType: row.match_id ? 'private_chat' : row.room_id ? 'room' : 'profile',
        reporter: {
          userId: row.reporter_user_id,
          displayName: row.reporter_name ?? 'İsimsiz kullanıcı',
          photoUrl: row.reporter_photos?.[0] ?? null,
        },
        reported: {
          userId: row.reported_user_id,
          displayName: row.reported_name ?? 'İsimsiz kullanıcı',
          photoUrl: row.reported_photos?.[0] ?? null,
          previousReportCount: Number(row.previous_report_count ?? 0),
          warningCount: Number(row.warning_count ?? 0),
          activelyBanned: row.actively_banned === true,
        },
        evidenceCount: Number(row.evidence_count ?? 0),
        keyEvidenceCount: Number(row.key_evidence_count ?? 0),
      })),
    };
  }

  async reportDetail(adminUserId: string, reportId: string) {
    const admin = await this.requireAdmin(adminUserId);
    const result = await this.infra.db.query(
      `select
         r.id::text,
         r.reporter_user_id::text,
         reporter.display_name as reporter_name,
         reporter.photo_urls as reporter_photos,
         reporter.city as reporter_city,
         r.reported_user_id::text,
         reported.display_name as reported_name,
         reported.photo_urls as reported_photos,
         reported.city as reported_city,
         ru.status as reported_account_status,
         r.room_id::text,
         r.match_id::text,
         r.reason,
         r.detail,
         r.status,
         r.moderator_note,
         r.reviewed_by_admin_id::text,
         reviewer.display_name as reviewer_name,
         r.reviewed_at,
         r.resolved_at,
         r.resolution,
         r.created_at,
         r.updated_at
       from reports r
       left join users ru on ru.id=r.reported_user_id
       left join profiles reporter on reporter.user_id=r.reporter_user_id
       left join profiles reported on reported.user_id=r.reported_user_id
       left join profiles reviewer on reviewer.user_id=r.reviewed_by_admin_id
       where r.id=$1`,
      [reportId],
    );
    const report = result.rows[0] as any;
    if (!report) throw new NotFoundException('Şikâyet bulunamadı.');

    const [evidence, previousReports, warnings, bans, notes, room, match] = await Promise.all([
      this.infra.db.query(
        `select ev.id::text, ev.source_type, ev.source_message_id::text,
                ev.sender_user_id::text, p.display_name as sender_name,
                ev.body, ev.message_created_at, ev.is_key_evidence, ev.created_at
         from report_evidence_messages ev
         left join profiles p on p.user_id=ev.sender_user_id
         where ev.report_id=$1
         order by ev.message_created_at asc, ev.id asc`,
        [reportId],
      ),
      this.infra.db.query(
        `select old.id::text, old.status, old.reason, old.detail,
                old.room_id::text, old.match_id::text, old.created_at,
                reporter.display_name as reporter_name
         from reports old
         left join profiles reporter on reporter.user_id=old.reporter_user_id
         where old.reported_user_id=$1 and old.id<>$2
         order by old.created_at desc
         limit 30`,
        [report.reported_user_id, reportId],
      ),
      this.infra.db.query(
        `select w.id::text, w.reason, w.created_at, p.display_name as admin_name
         from moderation_warnings w
         left join profiles p on p.user_id=w.admin_user_id
         where w.user_id=$1
         order by w.created_at desc
         limit 30`,
        [report.reported_user_id],
      ),
      this.infra.db.query(
        `select b.id::text, b.reason, b.starts_at, b.ends_at, b.revoked_at,
                p.display_name as admin_name
         from user_bans b
         left join profiles p on p.user_id=b.admin_user_id
         where b.user_id=$1
         order by b.created_at desc
         limit 30`,
        [report.reported_user_id],
      ),
      this.infra.db.query(
        `select n.id::text, n.note, n.created_at,
                n.admin_user_id::text, p.display_name as admin_name
         from report_moderation_notes n
         left join profiles p on p.user_id=n.admin_user_id
         where n.report_id=$1
         order by n.created_at desc`,
        [reportId],
      ),
      report.room_id
        ? this.infra.db.query(
            `select r.id::text, r.status, r.started_at, r.closed_at,
                    (select count(*)::int from room_messages m where m.room_id=r.id) as message_count
             from rooms r where r.id=$1`,
            [report.room_id],
          )
        : Promise.resolve({ rows: [] as any[] }),
      report.match_id
        ? this.infra.db.query(
            `select m.id::text, m.created_at, m.unmatched_at, m.source_room_id::text,
                    (select count(*)::int from private_messages pm where pm.match_id=m.id) as message_count
             from matches m where m.id=$1`,
            [report.match_id],
          )
        : Promise.resolve({ rows: [] as any[] }),
    ]);

    return {
      ok: true,
      admin,
      canModerate: admin.role !== 'support',
      report: {
        id: report.id,
        status: report.status,
        reason: report.reason,
        detail: report.detail,
        createdAt: report.created_at,
        updatedAt: report.updated_at,
        reviewedAt: report.reviewed_at,
        resolvedAt: report.resolved_at,
        resolution: report.resolution,
        moderatorNote: report.moderator_note,
        reviewedBy: report.reviewed_by_admin_id
          ? {
              userId: report.reviewed_by_admin_id,
              displayName: report.reviewer_name ?? 'Admin',
            }
          : null,
        roomId: report.room_id,
        matchId: report.match_id,
        contextType: report.match_id ? 'private_chat' : report.room_id ? 'room' : 'profile',
        room: room.rows[0] ?? null,
        match: match.rows[0] ?? null,
        reporter: {
          userId: report.reporter_user_id,
          displayName: report.reporter_name ?? 'İsimsiz kullanıcı',
          photoUrl: report.reporter_photos?.[0] ?? null,
          city: report.reporter_city,
        },
        reported: {
          userId: report.reported_user_id,
          displayName: report.reported_name ?? 'İsimsiz kullanıcı',
          photoUrl: report.reported_photos?.[0] ?? null,
          city: report.reported_city,
          accountStatus: report.reported_account_status,
        },
        evidenceMessages: evidence.rows,
        previousReports: previousReports.rows,
        warnings: warnings.rows,
        bans: bans.rows,
        moderatorNotes: notes.rows,
      },
    };
  }

  async action(adminUserId: string, reportId: string, body: AdminReportActionDto) {
    await this.requireModerator(adminUserId);
    const reportResult = await this.infra.db.query<ReportRow>(
      `select id::text, reporter_user_id::text, reported_user_id::text,
              room_id::text, match_id::text, reason, detail, status,
              moderator_note, reviewed_by_admin_id::text, reviewed_at,
              resolved_at, resolution, created_at, updated_at
       from reports where id=$1`,
      [reportId],
    );
    const report = reportResult.rows[0];
    if (!report) throw new NotFoundException('Şikâyet bulunamadı.');

    const note = body.note?.trim() ?? '';
    const reason = body.reason?.trim() || `Şikâyet #${reportId}: ${report.reason}`;
    let nextStatus = report.status;
    let resolution: string | null = report.resolution;
    let resolvedAt: Date | null = report.resolved_at;
    let sanction: Record<string, unknown> | null = null;

    if (body.action === 'warn') {
      sanction = await this.adminService.moderateUser(adminUserId, report.reported_user_id, {
        action: 'warn',
        reason,
      });
      nextStatus = 'reviewing';
    } else if (body.action.startsWith('ban_')) {
      const durationHours = body.action === 'ban_24h'
        ? 24
        : body.action === 'ban_7d'
            ? 24 * 7
            : body.action === 'ban_30d'
                ? 24 * 30
                : undefined;
      sanction = await this.adminService.moderateUser(adminUserId, report.reported_user_id, {
        action: 'ban',
        reason,
        durationHours,
      });
      nextStatus = 'reviewing';
    } else if (body.action === 'review') {
      nextStatus = 'reviewing';
      resolution = null;
      resolvedAt = null;
    } else if (body.action === 'resolve') {
      nextStatus = 'resolved';
      resolution = 'resolved';
      resolvedAt = new Date();
    } else if (body.action === 'reject') {
      nextStatus = 'rejected';
      resolution = 'rejected';
      resolvedAt = new Date();
    } else if (body.action === 'reopen') {
      nextStatus = 'open';
      resolution = null;
      resolvedAt = null;
    } else {
      throw new BadRequestException('Geçersiz moderasyon işlemi.');
    }

    const client = await this.infra.db.connect();
    try {
      await client.query('begin');
      await client.query(
        `update reports
         set status=$2,
             moderator_note=case when $3::text='' then moderator_note else $3 end,
             reviewed_by_admin_id=$4,
             reviewed_at=now(),
             resolved_at=$5,
             resolution=$6,
             updated_at=now()
         where id=$1`,
        [reportId, nextStatus, note, adminUserId, resolvedAt, resolution],
      );
      if (note) {
        await client.query(
          `insert into report_moderation_notes(report_id, admin_user_id, note)
           values($1,$2,$3)`,
          [reportId, adminUserId, note],
        );
      }
      await client.query(
        `insert into admin_audit_log(admin_user_id, action, target_type, target_id, detail)
         values($1,'moderate_report','report',$2,$3::jsonb)`,
        [
          adminUserId,
          reportId,
          JSON.stringify({
            action: body.action,
            fromStatus: report.status,
            toStatus: nextStatus,
            note: note || null,
            reason: reason || null,
          }),
        ],
      );
      await client.query('commit');
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }

    return {
      ok: true,
      reportId,
      action: body.action,
      status: nextStatus,
      resolution,
      sanction,
    };
  }

  async markEvidence(
    adminUserId: string,
    reportId: string,
    evidenceId: string,
    keyEvidence: boolean,
  ) {
    await this.requireModerator(adminUserId);
    const updated = await this.infra.db.query<{ id: string }>(
      `update report_evidence_messages
       set is_key_evidence=$3
       where id=$1 and report_id=$2
       returning id::text`,
      [evidenceId, reportId, keyEvidence],
    );
    if (!updated.rows[0]) throw new NotFoundException('Kanıt mesajı bulunamadı.');

    await this.infra.db.query(
      `insert into admin_audit_log(admin_user_id, action, target_type, target_id, detail)
       values($1,'mark_report_evidence','report',$2,$3::jsonb)`,
      [adminUserId, reportId, JSON.stringify({ evidenceId, keyEvidence })],
    );
    return { ok: true, reportId, evidenceId, keyEvidence };
  }
}
