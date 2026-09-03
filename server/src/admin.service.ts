import { ForbiddenException, Injectable } from '@nestjs/common';

import { InfrastructureService } from './infrastructure.service';
import { RoomsGateway } from './rooms.gateway';

type AdminRole = 'super_admin' | 'moderator' | 'support';

@Injectable()
export class AdminService {
  constructor(
    private readonly infra: InfrastructureService,
    private readonly roomsGateway: RoomsGateway,
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
        `select count(*)::text as count from users where status='banned'`,
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

  private websocketStatus() {
    const server = this.roomsGateway.server as any;
    if (!server) return { status: 'starting', connections: 0 };
    const directMap = server.sockets instanceof Map ? server.sockets : null;
    const nestedMap = server.sockets?.sockets instanceof Map ? server.sockets.sockets : null;
    const connections = Number((directMap ?? nestedMap)?.size ?? 0);
    return { status: 'ok', connections };
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
