import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';

import { AdminService } from './admin.service';
import { InfrastructureService } from './infrastructure.service';

type AdminRole = 'super_admin' | 'moderator' | 'support';

@Injectable()
export class AdminGovernanceService {
  constructor(
    private readonly infra: InfrastructureService,
    private readonly adminService: AdminService,
  ) {}

  private async requireModerator(userId: string) {
    const admin = await this.adminService.requireAdmin(userId);
    if (admin.role === 'support') {
      throw new ForbiddenException('Bu bölüm moderator veya super_admin yetkisi gerektirir.');
    }
    return admin as { userId: string; role: AdminRole };
  }

  private async requireSuperAdmin(userId: string) {
    const admin = await this.adminService.requireAdmin(userId);
    if (admin.role !== 'super_admin') {
      throw new ForbiddenException('Audit Log yalnızca super_admin tarafından görüntülenebilir.');
    }
    return admin as { userId: string; role: AdminRole };
  }

  async listBans(
    adminUserId: string,
    statusInput: string,
    searchInput: string,
    pageInput: number,
    limitInput: number,
  ) {
    const admin = await this.requireModerator(adminUserId);
    const status = ['all', 'active', 'revoked', 'expired'].includes(statusInput) ? statusInput : 'active';
    const search = searchInput.trim().slice(0, 140);
    const page = Math.max(1, Math.floor(pageInput || 1));
    const limit = Math.min(50, Math.max(10, Math.floor(limitInput || 20)));
    const offset = (page - 1) * limit;
    const stateExpr = `case
      when b.revoked_at is not null then 'revoked'
      when b.ends_at is null or b.ends_at > now() then 'active'
      else 'expired'
    end`;
    const where = `
      where ($1::text='all' or (${stateExpr})=$1)
        and (
          $2::text='' or
          b.id::text=$2 or
          lower(b.reason) like lower('%' || $2 || '%') or
          lower(coalesce(p.display_name,'')) like lower('%' || $2 || '%') or
          lower(coalesce(ap.display_name,'')) like lower('%' || $2 || '%') or
          u.phone_e164 like '%' || regexp_replace($2, '[^0-9+]', '', 'g') || '%'
        )`;

    const [rows, total, counts] = await Promise.all([
      this.infra.db.query(
        `select
           b.id::text,
           b.user_id::text,
           p.display_name,
           p.photo_urls,
           p.city,
           u.phone_e164,
           u.status as user_status,
           b.reason,
           b.starts_at,
           b.ends_at,
           b.revoked_at,
           b.created_at,
           (${stateExpr}) as ban_state,
           b.admin_user_id::text,
           ap.display_name as admin_name,
           au.role as admin_role,
           b.revoked_by::text,
           rp.display_name as revoked_by_name,
           (select count(*)::int from user_bans prev where prev.user_id=b.user_id and prev.id<>b.id) as previous_ban_count,
           (select count(*)::int from moderation_warnings w where w.user_id=b.user_id) as warning_count
         from user_bans b
         join users u on u.id=b.user_id
         left join profiles p on p.user_id=b.user_id
         left join profiles ap on ap.user_id=b.admin_user_id
         left join admin_users au on au.user_id=b.admin_user_id
         left join profiles rp on rp.user_id=b.revoked_by
         ${where}
         order by
           case (${stateExpr}) when 'active' then 0 when 'revoked' then 1 else 2 end,
           b.created_at desc
         limit $3 offset $4`,
        [status, search, limit, offset],
      ),
      this.infra.db.query<{ count: string }>(
        `select count(*)::text as count
         from user_bans b
         join users u on u.id=b.user_id
         left join profiles p on p.user_id=b.user_id
         left join profiles ap on ap.user_id=b.admin_user_id
         ${where}`,
        [status, search],
      ),
      this.infra.db.query<{ state: string; count: string }>(
        `select (${stateExpr}) as state, count(*)::text as count
         from user_bans b
         group by 1`,
      ),
    ]);

    const stats = { active: 0, revoked: 0, expired: 0 };
    for (const row of counts.rows) {
      if (row.state in stats) (stats as any)[row.state] = Number(row.count ?? 0);
    }

    return {
      ok: true,
      admin,
      page,
      limit,
      total: Number(total.rows[0]?.count ?? 0),
      stats,
      bans: rows.rows.map((row: any) => ({
        id: row.id,
        state: row.ban_state,
        reason: row.reason,
        startsAt: row.starts_at,
        endsAt: row.ends_at,
        permanent: row.ends_at == null,
        revokedAt: row.revoked_at,
        createdAt: row.created_at,
        user: {
          userId: row.user_id,
          displayName: row.display_name ?? 'İsimsiz kullanıcı',
          phoneMasked: this.maskPhone(row.phone_e164 ?? ''),
          photoUrl: row.photo_urls?.[0] ?? null,
          city: row.city,
          status: row.user_status,
        },
        bannedBy: {
          userId: row.admin_user_id,
          displayName: row.admin_name ?? 'Silinmiş admin',
          role: row.admin_role ?? null,
        },
        revokedBy: row.revoked_by
          ? { userId: row.revoked_by, displayName: row.revoked_by_name ?? 'Silinmiş admin' }
          : null,
        previousBanCount: Number(row.previous_ban_count ?? 0),
        warningCount: Number(row.warning_count ?? 0),
      })),
    };
  }

  async banDetail(adminUserId: string, banId: string) {
    const admin = await this.requireModerator(adminUserId);
    const result = await this.infra.db.query(
      `select b.id::text, b.user_id::text, b.reason, b.starts_at, b.ends_at,
              b.revoked_at, b.created_at, b.admin_user_id::text,
              p.display_name, p.photo_urls, p.city, u.phone_e164, u.status as user_status,
              ap.display_name as admin_name, au.role as admin_role,
              b.revoked_by::text, rp.display_name as revoked_by_name,
              case when b.revoked_at is not null then 'revoked'
                   when b.ends_at is null or b.ends_at > now() then 'active'
                   else 'expired' end as ban_state
       from user_bans b
       join users u on u.id=b.user_id
       left join profiles p on p.user_id=b.user_id
       left join profiles ap on ap.user_id=b.admin_user_id
       left join admin_users au on au.user_id=b.admin_user_id
       left join profiles rp on rp.user_id=b.revoked_by
       where b.id=$1`,
      [banId],
    );
    const row = result.rows[0] as any;
    if (!row) throw new NotFoundException('Ban kaydı bulunamadı.');

    const [bans, warnings, audit] = await Promise.all([
      this.infra.db.query(
        `select b.id::text, b.reason, b.starts_at, b.ends_at, b.revoked_at, b.created_at,
                p.display_name as admin_name, rp.display_name as revoked_by_name,
                case when b.revoked_at is not null then 'revoked'
                     when b.ends_at is null or b.ends_at > now() then 'active'
                     else 'expired' end as state
         from user_bans b
         left join profiles p on p.user_id=b.admin_user_id
         left join profiles rp on rp.user_id=b.revoked_by
         where b.user_id=$1
         order by b.created_at desc
         limit 50`,
        [row.user_id],
      ),
      this.infra.db.query(
        `select w.id::text, w.reason, w.created_at, p.display_name as admin_name
         from moderation_warnings w
         left join profiles p on p.user_id=w.admin_user_id
         where w.user_id=$1
         order by w.created_at desc
         limit 50`,
        [row.user_id],
      ),
      this.infra.db.query(
        `select l.id::text, l.action, l.detail, l.created_at,
                p.display_name as admin_name
         from admin_audit_log l
         left join profiles p on p.user_id=l.admin_user_id
         where l.target_type='user' and l.target_id=$1
         order by l.created_at desc
         limit 50`,
        [row.user_id],
      ),
    ]);

    return {
      ok: true,
      admin,
      canRevoke: row.ban_state === 'active',
      ban: {
        id: row.id,
        state: row.ban_state,
        reason: row.reason,
        startsAt: row.starts_at,
        endsAt: row.ends_at,
        permanent: row.ends_at == null,
        revokedAt: row.revoked_at,
        createdAt: row.created_at,
        user: {
          userId: row.user_id,
          displayName: row.display_name ?? 'İsimsiz kullanıcı',
          phoneMasked: this.maskPhone(row.phone_e164 ?? ''),
          photoUrl: row.photo_urls?.[0] ?? null,
          city: row.city,
          status: row.user_status,
        },
        bannedBy: {
          userId: row.admin_user_id,
          displayName: row.admin_name ?? 'Silinmiş admin',
          role: row.admin_role ?? null,
        },
        revokedBy: row.revoked_by
          ? { userId: row.revoked_by, displayName: row.revoked_by_name ?? 'Silinmiş admin' }
          : null,
        history: {
          bans: bans.rows,
          warnings: warnings.rows,
          audit: audit.rows,
        },
      },
    };
  }

  async revokeBan(adminUserId: string, banId: string, reasonInput: string) {
    const admin = await this.requireModerator(adminUserId);
    const reason = reasonInput.trim();
    if (reason.length < 3) throw new BadRequestException('Ban kaldırma nedeni en az 3 karakter olmalı.');

    const existing = await this.infra.db.query<{
      id: string;
      user_id: string;
      ban_reason: string;
    }>(
      `select id::text, user_id::text, reason as ban_reason
       from user_bans
       where id=$1 and revoked_at is null and (ends_at is null or ends_at > now())`,
      [banId],
    );
    const ban = existing.rows[0];
    if (!ban) throw new NotFoundException('Aktif ban kaydı bulunamadı.');
    if (ban.user_id === adminUserId) {
      throw new BadRequestException('Kendi admin hesabının banını kaldıramazsın.');
    }
    const targetAdmin = await this.infra.db.query<{ role: AdminRole }>(
      `select role from admin_users where user_id=$1 and active=true`,
      [ban.user_id],
    );
    if (targetAdmin.rowCount && admin.role !== 'super_admin') {
      throw new ForbiddenException('Admin hesaplarını yalnızca super_admin yönetebilir.');
    }

    const client = await this.infra.db.connect();
    try {
      await client.query('begin');
      const updated = await client.query(
        `update user_bans
         set revoked_at=now(), revoked_by=$2
         where id=$1 and revoked_at is null and (ends_at is null or ends_at > now())
         returning id`,
        [banId, adminUserId],
      );
      if (!updated.rowCount) throw new NotFoundException('Ban artık aktif değil.');
      const remaining = await client.query<{ exists: boolean }>(
        `select exists(
           select 1 from user_bans
           where user_id=$1 and revoked_at is null and (ends_at is null or ends_at > now())
         ) as exists`,
        [ban.user_id],
      );
      if (!remaining.rows[0]?.exists) {
        await client.query(`update users set status='active', updated_at=now() where id=$1`, [ban.user_id]);
      }
      await client.query(
        `insert into admin_audit_log(admin_user_id, action, target_type, target_id, detail)
         values($1,'unban_user','user',$2,$3::jsonb)`,
        [
          adminUserId,
          ban.user_id,
          JSON.stringify({ banId, reason, originalBanReason: ban.ban_reason }),
        ],
      );
      await client.query(
        `insert into notifications(user_id,type,title,body,data)
         values($1,'moderation_unban','Meet6 banı kaldırıldı',$2,jsonb_build_object('banId',$3::text))`,
        [ban.user_id, reason, banId],
      );
      await client.query('commit');
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }

    return { ok: true, banId, userId: ban.user_id, reason };
  }

  async auditLogs(
    adminUserId: string,
    actionInput: string,
    targetTypeInput: string,
    searchInput: string,
    pageInput: number,
    limitInput: number,
  ) {
    const admin = await this.requireSuperAdmin(adminUserId);
    const action = actionInput.trim().slice(0, 80) || 'all';
    const targetType = targetTypeInput.trim().slice(0, 40) || 'all';
    const search = searchInput.trim().slice(0, 160);
    const page = Math.max(1, Math.floor(pageInput || 1));
    const limit = Math.min(100, Math.max(20, Math.floor(limitInput || 30)));
    const offset = (page - 1) * limit;
    const where = `
      where ($1::text='all' or l.action=$1)
        and ($2::text='all' or coalesce(l.target_type,'')=$2)
        and (
          $3::text='' or
          l.id::text=$3 or
          lower(l.action) like lower('%' || $3 || '%') or
          lower(coalesce(l.target_type,'')) like lower('%' || $3 || '%') or
          lower(coalesce(l.target_id,'')) like lower('%' || $3 || '%') or
          lower(coalesce(l.detail::text,'')) like lower('%' || $3 || '%') or
          lower(coalesce(ap.display_name,'')) like lower('%' || $3 || '%') or
          lower(coalesce(tp.display_name,'')) like lower('%' || $3 || '%')
        )`;

    const [rows, total, actions] = await Promise.all([
      this.infra.db.query(
        `select l.id::text, l.action, l.target_type, l.target_id, l.detail, l.created_at,
                l.admin_user_id::text, ap.display_name as admin_name, au.role as admin_role,
                case when l.target_type='user' then tp.display_name else null end as target_user_name
         from admin_audit_log l
         left join profiles ap on ap.user_id=l.admin_user_id
         left join admin_users au on au.user_id=l.admin_user_id
         left join profiles tp on l.target_type='user' and tp.user_id::text=l.target_id
         ${where}
         order by l.created_at desc
         limit $4 offset $5`,
        [action, targetType, search, limit, offset],
      ),
      this.infra.db.query<{ count: string }>(
        `select count(*)::text as count
         from admin_audit_log l
         left join profiles ap on ap.user_id=l.admin_user_id
         left join profiles tp on l.target_type='user' and tp.user_id::text=l.target_id
         ${where}`,
        [action, targetType, search],
      ),
      this.infra.db.query<{ action: string; count: string }>(
        `select action, count(*)::text as count
         from admin_audit_log
         group by action
         order by count(*) desc, action asc`,
      ),
    ]);

    return {
      ok: true,
      admin,
      page,
      limit,
      total: Number(total.rows[0]?.count ?? 0),
      actions: actions.rows.map((row) => ({ action: row.action, count: Number(row.count ?? 0) })),
      logs: rows.rows.map((row: any) => ({
        id: row.id,
        action: row.action,
        targetType: row.target_type,
        targetId: row.target_id,
        targetLabel: row.target_type === 'user' && row.target_user_name
          ? row.target_user_name
          : row.target_type && row.target_id
              ? `${row.target_type} #${row.target_id}`
              : 'Sistem',
        detail: row.detail ?? {},
        createdAt: row.created_at,
        admin: {
          userId: row.admin_user_id,
          displayName: row.admin_name ?? 'Silinmiş admin',
          role: row.admin_role ?? null,
        },
      })),
    };
  }

  private maskPhone(phone: string) {
    if (phone.length < 7) return phone;
    return `${phone.slice(0, 4)}***${phone.slice(-3)}`;
  }
}
