import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';

import { AdminSupportActionDto } from './admin.dto';
import { InfrastructureService } from './infrastructure.service';

type AdminRole = 'super_admin' | 'moderator' | 'support';

@Injectable()
export class AdminSupportService {
  constructor(private readonly infra: InfrastructureService) {}

  private async requireAdmin(userId: string) {
    const result = await this.infra.db.query<{ role: AdminRole }>(
      `select role from admin_users where user_id=$1 and active=true`,
      [userId],
    );
    const role = result.rows[0]?.role;
    if (!role) throw new ForbiddenException('Bu hesap admin paneline yetkili değil.');
    return { userId, role };
  }

  async list(
    adminUserId: string,
    statusInput: string,
    priorityInput: string,
    searchInput: string,
    pageInput: number,
    limitInput: number,
  ) {
    const admin = await this.requireAdmin(adminUserId);
    const status = ['all', 'open', 'answered', 'closed'].includes(statusInput) ? statusInput : 'open';
    const priority = ['all', 'low', 'normal', 'high'].includes(priorityInput) ? priorityInput : 'all';
    const search = searchInput.trim().slice(0, 140);
    const page = Math.max(1, Math.floor(pageInput || 1));
    const limit = Math.min(50, Math.max(10, Math.floor(limitInput || 20)));
    const offset = (page - 1) * limit;

    const where = `
      where ($1::text='all' or s.status=$1)
        and ($2::text='all' or s.priority=$2)
        and (
          $3::text='' or
          s.id::text=$3 or
          lower(s.topic) like lower('%' || $3 || '%') or
          lower(s.message) like lower('%' || $3 || '%') or
          lower(coalesce(p.display_name,'')) like lower('%' || $3 || '%')
        )`;

    const [rows, total, statusCounts, priorityCounts] = await Promise.all([
      this.infra.db.query(
        `select s.id::text, s.user_id::text, p.display_name, p.photo_urls, p.city,
                s.topic, s.message, s.status, s.priority, s.admin_response,
                s.created_at, s.updated_at, s.responded_at, s.closed_at
         from support_requests s
         left join profiles p on p.user_id=s.user_id
         ${where}
         order by
           case s.priority when 'high' then 0 when 'normal' then 1 else 2 end,
           case s.status when 'open' then 0 when 'answered' then 1 else 2 end,
           s.created_at asc
         limit $4 offset $5`,
        [status, priority, search, limit, offset],
      ),
      this.infra.db.query<{ count: string }>(
        `select count(*)::text as count
         from support_requests s
         left join profiles p on p.user_id=s.user_id
         ${where}`,
        [status, priority, search],
      ),
      this.infra.db.query<{ status: string; count: string }>(
        `select status, count(*)::text as count
         from support_requests
         group by status`,
      ),
      this.infra.db.query<{ priority: string; count: string }>(
        `select priority, count(*)::text as count
         from support_requests
         where status <> 'closed'
         group by priority`,
      ),
    ]);

    const stats = { open: 0, answered: 0, closed: 0 };
    for (const row of statusCounts.rows) {
      if (row.status in stats) (stats as any)[row.status] = Number(row.count ?? 0);
    }
    const priorities = { low: 0, normal: 0, high: 0 };
    for (const row of priorityCounts.rows) {
      if (row.priority in priorities) (priorities as any)[row.priority] = Number(row.count ?? 0);
    }

    return {
      ok: true,
      admin,
      page,
      limit,
      total: Number(total.rows[0]?.count ?? 0),
      stats,
      priorities,
      requests: rows.rows.map((row: any) => ({
        id: row.id,
        user: {
          userId: row.user_id,
          displayName: row.display_name ?? 'İsimsiz kullanıcı',
          photoUrl: row.photo_urls?.[0] ?? null,
          city: row.city,
        },
        topic: row.topic,
        message: row.message,
        status: row.status,
        priority: row.priority,
        adminResponse: row.admin_response,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        respondedAt: row.responded_at,
        closedAt: row.closed_at,
      })),
    };
  }

  async detail(adminUserId: string, requestId: string) {
    const admin = await this.requireAdmin(adminUserId);
    const result = await this.infra.db.query(
      `select s.id::text, s.user_id::text, s.topic, s.message, s.status, s.priority,
              s.admin_response, s.created_at, s.updated_at, s.responded_at, s.closed_at,
              p.display_name, p.photo_urls, p.city, p.country,
              extract(year from age(current_date,p.birth_date))::int as age,
              u.created_at as user_created_at, u.last_seen_at,
              responder.display_name as responder_name
       from support_requests s
       join users u on u.id=s.user_id
       left join profiles p on p.user_id=s.user_id
       left join profiles responder on responder.user_id=s.responded_by_admin_id
       where s.id=$1`,
      [requestId],
    );
    const row = result.rows[0] as any;
    if (!row) throw new NotFoundException('Destek talebi bulunamadı.');

    return {
      ok: true,
      admin,
      request: {
        id: row.id,
        topic: row.topic,
        message: row.message,
        status: row.status,
        priority: row.priority,
        adminResponse: row.admin_response,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        respondedAt: row.responded_at,
        closedAt: row.closed_at,
        respondedBy: row.responder_name ?? null,
        user: {
          userId: row.user_id,
          displayName: row.display_name ?? 'İsimsiz kullanıcı',
          photoUrl: row.photo_urls?.[0] ?? null,
          city: row.city,
          country: row.country,
          age: row.age,
          createdAt: row.user_created_at,
          lastSeenAt: row.last_seen_at,
        },
      },
    };
  }

  async action(adminUserId: string, requestId: string, body: AdminSupportActionDto) {
    await this.requireAdmin(adminUserId);
    const existing = await this.infra.db.query<{ user_id: string; status: string; priority: string }>(
      `select user_id::text, status, priority from support_requests where id=$1`,
      [requestId],
    );
    const request = existing.rows[0];
    if (!request) throw new NotFoundException('Destek talebi bulunamadı.');

    if (body.action === 'reply') {
      const response = body.response?.trim() ?? '';
      if (response.length < 2) throw new BadRequestException('Admin cevabı gerekli.');
      await this.infra.db.query(
        `update support_requests
         set admin_response=$2, responded_at=now(), responded_by_admin_id=$3,
             status='answered', closed_at=null, updated_at=now()
         where id=$1`,
        [requestId, response, adminUserId],
      );
      await this.infra.db.query(
        `insert into notifications(user_id,type,title,body,data)
         values($1,'support_reply','Destek talebin yanıtlandı',$2,jsonb_build_object('supportRequestId',$3::text))`,
        [request.user_id, response.slice(0, 200), requestId],
      );
    } else if (body.action === 'close') {
      await this.infra.db.query(
        `update support_requests set status='closed', closed_at=now(), updated_at=now() where id=$1`,
        [requestId],
      );
    } else if (body.action === 'reopen') {
      await this.infra.db.query(
        `update support_requests set status='open', closed_at=null, updated_at=now() where id=$1`,
        [requestId],
      );
    } else if (body.action === 'set_priority') {
      const priority = body.priority;
      if (!priority || !['low', 'normal', 'high'].includes(priority)) {
        throw new BadRequestException('Geçerli bir öncelik seç.');
      }
      await this.infra.db.query(
        `update support_requests set priority=$2, updated_at=now() where id=$1`,
        [requestId, priority],
      );
    } else {
      throw new BadRequestException('Geçersiz destek işlemi.');
    }

    await this.infra.db.query(
      `insert into admin_audit_log(admin_user_id, action, target_type, target_id, detail)
       values($1,'support_request_action','support_request',$2,$3::jsonb)`,
      [
        adminUserId,
        requestId,
        JSON.stringify({
          action: body.action,
          response: body.action === 'reply' ? body.response?.trim() ?? null : null,
          priority: body.priority ?? null,
          previousStatus: request.status,
          previousPriority: request.priority,
        }),
      ],
    );

    return this.detail(adminUserId, requestId);
  }
}
