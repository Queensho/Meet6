import { ForbiddenException, Injectable } from '@nestjs/common';

import { AdminPhotoModerationActionDto } from './admin.dto';
import { ContentSafetyService } from './content-safety.service';
import { InfrastructureService } from './infrastructure.service';

type AdminRole = 'super_admin' | 'moderator' | 'support';

@Injectable()
export class AdminSafetyService {
  constructor(
    private readonly infra: InfrastructureService,
    private readonly safety: ContentSafetyService,
  ) {}

  private async requireAdmin(userId: string) {
    const result = await this.infra.db.query<{ role: AdminRole }>(
      'select role from admin_users where user_id=$1 and active=true',
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

  async listPhotos(
    adminUserId: string,
    statusInput: string,
    searchInput: string,
    pageInput: number,
    limitInput: number,
  ) {
    const admin = await this.requireAdmin(adminUserId);
    const allowedStatuses = ['all', 'review', 'rejected', 'approved'];
    const status = allowedStatuses.includes(statusInput) ? statusInput : 'review';
    const search = searchInput.trim().slice(0, 140);
    const page = Math.max(1, Math.floor(pageInput || 1));
    const limit = Math.min(50, Math.max(10, Math.floor(limitInput || 20)));
    const offset = (page - 1) * limit;

    const where = `
      where ($1::text='all' or pm.status=$1)
        and (
          $2::text='' or
          pm.id::text=$2 or
          pm.user_id::text=$2 or
          lower(coalesce(p.display_name,'')) like lower('%' || $2 || '%') or
          lower(coalesce(pm.reason,'')) like lower('%' || $2 || '%')
        )`;

    const [rows, total, counts] = await Promise.all([
      this.infra.db.query(
        `select
           pm.id::text,
           pm.user_id::text,
           p.display_name,
           p.photo_urls,
           u.status as account_status,
           pm.original_name,
           pm.mime_type,
           pm.sha256,
           pm.status,
           pm.provider,
           pm.provider_result,
           pm.reason,
           pm.public_url,
           pm.created_at,
           pm.reviewed_at,
           coalesce(r.risk_score,0)::int as risk_score,
           coalesce(r.risk_level,'low') as risk_level,
           coalesce(r.report_score,0)::int as report_score,
           coalesce(r.spam_score,0)::int as spam_score,
           coalesce(r.fake_score,0)::int as fake_score,
           (select count(distinct other.user_id)::int
              from photo_moderation_items other
             where other.sha256=pm.sha256 and other.user_id<>pm.user_id) as duplicate_account_count
         from photo_moderation_items pm
         join users u on u.id=pm.user_id
         left join profiles p on p.user_id=pm.user_id
         left join user_risk_profiles r on r.user_id=pm.user_id
         ${where}
         order by
           case pm.status when 'review' then 0 when 'rejected' then 1 else 2 end,
           coalesce(r.risk_score,0) desc,
           pm.created_at asc
         limit $3 offset $4`,
        [status, search, limit, offset],
      ),
      this.infra.db.query<{ count: string }>(
        `select count(*)::text as count
         from photo_moderation_items pm
         left join profiles p on p.user_id=pm.user_id
         ${where}`,
        [status, search],
      ),
      this.infra.db.query<{ status: string; count: string }>(
        `select status, count(*)::text as count
         from photo_moderation_items
         group by status`,
      ),
    ]);

    const stats: Record<string, number> = { review: 0, rejected: 0, approved: 0 };
    for (const row of counts.rows) stats[row.status] = Number(row.count ?? 0);

    return {
      ok: true,
      admin,
      canModerate: admin.role !== 'support',
      page,
      limit,
      total: Number(total.rows[0]?.count ?? 0),
      stats,
      photos: rows.rows.map((row: any) => ({
        id: row.id,
        userId: row.user_id,
        displayName: row.display_name ?? 'İsimsiz kullanıcı',
        currentPhotoUrl: row.photo_urls?.[0] ?? null,
        accountStatus: row.account_status,
        originalName: row.original_name,
        mimeType: row.mime_type,
        status: row.status,
        provider: row.provider,
        providerResult: row.provider_result,
        reason: row.reason,
        publicUrl: row.public_url,
        createdAt: row.created_at,
        reviewedAt: row.reviewed_at,
        duplicateAccountCount: Number(row.duplicate_account_count ?? 0),
        risk: {
          score: Number(row.risk_score ?? 0),
          level: row.risk_level,
          reportScore: Number(row.report_score ?? 0),
          spamScore: Number(row.spam_score ?? 0),
          fakeScore: Number(row.fake_score ?? 0),
        },
      })),
    };
  }

  async priorityReports(
    adminUserId: string,
    searchInput: string,
    pageInput: number,
    limitInput: number,
  ) {
    const admin = await this.requireAdmin(adminUserId);
    const search = searchInput.trim().slice(0, 140);
    const page = Math.max(1, Math.floor(pageInput || 1));
    const limit = Math.min(50, Math.max(10, Math.floor(limitInput || 20)));
    const offset = (page - 1) * limit;

    const where = `
      where r.status in ('open','reviewing')
        and (
          $1::text='' or
          r.id::text=$1 or
          r.reported_user_id::text=$1 or
          lower(r.reason) like lower('%' || $1 || '%') or
          lower(coalesce(r.detail,'')) like lower('%' || $1 || '%') or
          lower(coalesce(p.display_name,'')) like lower('%' || $1 || '%')
        )`;

    const [rows, total] = await Promise.all([
      this.infra.db.query(
        `select
           r.id::text,
           r.reported_user_id::text,
           p.display_name,
           p.photo_urls,
           r.reason,
           r.detail,
           r.status,
           r.room_id::text,
           r.match_id::text,
           r.priority_score,
           r.triage_flags,
           r.created_at,
           coalesce(risk.risk_score,0)::int as risk_score,
           coalesce(risk.risk_level,'low') as risk_level,
           (select count(*)::int from report_evidence_messages ev where ev.report_id=r.id) as evidence_count,
           (select count(*)::int
              from reports old
             where old.reported_user_id=r.reported_user_id
               and old.created_at>now()-interval '7 days') as reports_7d
         from reports r
         left join profiles p on p.user_id=r.reported_user_id
         left join user_risk_profiles risk on risk.user_id=r.reported_user_id
         ${where}
         order by r.priority_score desc, r.created_at asc
         limit $2 offset $3`,
        [search, limit, offset],
      ),
      this.infra.db.query<{ count: string }>(
        `select count(*)::text as count
         from reports r
         left join profiles p on p.user_id=r.reported_user_id
         ${where}`,
        [search],
      ),
    ]);

    return {
      ok: true,
      admin,
      canModerate: admin.role !== 'support',
      page,
      limit,
      total: Number(total.rows[0]?.count ?? 0),
      reports: rows.rows.map((row: any) => ({
        id: row.id,
        reportedUserId: row.reported_user_id,
        displayName: row.display_name ?? 'İsimsiz kullanıcı',
        photoUrl: row.photo_urls?.[0] ?? null,
        reason: row.reason,
        detail: row.detail,
        status: row.status,
        roomId: row.room_id,
        matchId: row.match_id,
        contextType: row.match_id ? 'private_chat' : row.room_id ? 'room' : 'profile',
        priorityScore: Number(row.priority_score ?? 0),
        triageFlags: row.triage_flags ?? {},
        createdAt: row.created_at,
        evidenceCount: Number(row.evidence_count ?? 0),
        reports7d: Number(row.reports_7d ?? 0),
        risk: {
          score: Number(row.risk_score ?? 0),
          level: row.risk_level,
        },
      })),
    };
  }

  async riskUsers(
    adminUserId: string,
    levelInput: string,
    searchInput: string,
    pageInput: number,
    limitInput: number,
  ) {
    const admin = await this.requireAdmin(adminUserId);
    const allowedLevels = ['all', 'low', 'medium', 'high', 'critical'];
    const level = allowedLevels.includes(levelInput) ? levelInput : 'high';
    const search = searchInput.trim().slice(0, 140);
    const page = Math.max(1, Math.floor(pageInput || 1));
    const limit = Math.min(50, Math.max(10, Math.floor(limitInput || 20)));
    const offset = (page - 1) * limit;

    const levelPredicate = level === 'high'
      ? `risk.risk_level in ('high','critical')`
      : `($1::text='all' or risk.risk_level=$1)`;
    const params = [level, search, limit, offset];

    const [rows, total] = await Promise.all([
      this.infra.db.query(
        `select
           risk.user_id::text,
           p.display_name,
           p.photo_urls,
           u.status as account_status,
           risk.risk_score,
           risk.risk_level,
           risk.report_score,
           risk.spam_score,
           risk.fake_score,
           risk.restricted_until,
           risk.restriction_reason,
           risk.updated_at,
           (select count(*)::int
              from reports r
             where r.reported_user_id=risk.user_id
               and r.created_at>now()-interval '7 days') as reports_7d,
           (select count(*)::int
              from photo_moderation_items pm
             where pm.user_id=risk.user_id and pm.status='review') as pending_photos
         from user_risk_profiles risk
         join users u on u.id=risk.user_id
         left join profiles p on p.user_id=risk.user_id
         where ${levelPredicate}
           and (
             $2::text='' or
             risk.user_id::text=$2 or
             lower(coalesce(p.display_name,'')) like lower('%' || $2 || '%')
           )
         order by risk.risk_score desc, risk.updated_at desc
         limit $3 offset $4`,
        params,
      ),
      this.infra.db.query<{ count: string }>(
        `select count(*)::text as count
         from user_risk_profiles risk
         left join profiles p on p.user_id=risk.user_id
         where ${levelPredicate}
           and (
             $2::text='' or
             risk.user_id::text=$2 or
             lower(coalesce(p.display_name,'')) like lower('%' || $2 || '%')
           )`,
        [level, search],
      ),
    ]);

    return {
      ok: true,
      admin,
      canModerate: admin.role !== 'support',
      page,
      limit,
      total: Number(total.rows[0]?.count ?? 0),
      users: rows.rows.map((row: any) => ({
        userId: row.user_id,
        displayName: row.display_name ?? 'İsimsiz kullanıcı',
        photoUrl: row.photo_urls?.[0] ?? null,
        accountStatus: row.account_status,
        riskScore: Number(row.risk_score ?? 0),
        riskLevel: row.risk_level,
        reportScore: Number(row.report_score ?? 0),
        spamScore: Number(row.spam_score ?? 0),
        fakeScore: Number(row.fake_score ?? 0),
        restrictedUntil: row.restricted_until,
        restrictionReason: row.restriction_reason,
        reports7d: Number(row.reports_7d ?? 0),
        pendingPhotos: Number(row.pending_photos ?? 0),
        updatedAt: row.updated_at,
      })),
    };
  }

  async photoAction(
    adminUserId: string,
    moderationId: string,
    body: AdminPhotoModerationActionDto,
  ) {
    await this.requireModerator(adminUserId);
    return this.safety.reviewPhoto(moderationId, adminUserId, body.action, body.note);
  }
}
