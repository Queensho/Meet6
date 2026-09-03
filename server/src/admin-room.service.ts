import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { InfrastructureService } from './infrastructure.service';
import { RoomService } from './room.service';
import { RoomsGateway } from './rooms.gateway';

type AdminRole = 'super_admin' | 'moderator' | 'support';

type RoomRow = {
  id: string;
  status: string;
  started_at: Date;
  ends_at: Date;
  extended: boolean;
  selection_started_at: Date | null;
  selection_ends_at: Date | null;
  closed_at: Date | null;
  closed_reason: string | null;
  original_member_count: number;
  active_member_count: number;
  message_count: number;
  report_count: number;
  reconnect_count: number;
};

@Injectable()
export class AdminRoomService {
  constructor(
    private readonly infra: InfrastructureService,
    private readonly rooms: RoomService,
    private readonly roomsGateway: RoomsGateway,
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

  async listRooms(
    adminUserId: string,
    statusInput: string,
    pageInput: number,
    limitInput: number,
  ) {
    const admin = await this.requireAdmin(adminUserId);
    await this.rooms.syncExpiredRooms();

    const status = ['live', 'active', 'selection', 'closed', 'all'].includes(statusInput)
      ? statusInput
      : 'live';
    const page = Math.max(1, Math.floor(pageInput || 1));
    const limit = Math.min(50, Math.max(10, Math.floor(limitInput || 20)));
    const offset = (page - 1) * limit;

    const where = status === 'live'
      ? `where r.status in ('active','selection')`
      : status === 'all'
          ? ''
          : `where r.status = $1`;
    const params = status === 'live' || status === 'all'
      ? [limit, offset]
      : [status, limit, offset];
    const limitParam = status === 'live' || status === 'all' ? '$1' : '$2';
    const offsetParam = status === 'live' || status === 'all' ? '$2' : '$3';

    const rows = await this.infra.db.query<RoomRow>(
      `select
         r.id::text,
         r.status,
         r.started_at,
         r.ends_at,
         r.extended,
         r.selection_started_at,
         r.selection_ends_at,
         r.closed_at,
         r.closed_reason,
         count(rm.user_id)::int as original_member_count,
         count(rm.user_id) filter (where rm.left_at is null)::int as active_member_count,
         (select count(*)::int from room_messages m where m.room_id=r.id) as message_count,
         (select count(*)::int from reports rep where rep.room_id=r.id) as report_count,
         coalesce(sum(greatest(coalesce(rm.connection_count,0) - 1, 0)),0)::int as reconnect_count
       from rooms r
       left join room_members rm on rm.room_id=r.id
       ${where}
       group by r.id
       order by case when r.status in ('active','selection') then 0 else 1 end,
                coalesce(r.closed_at, r.started_at) desc
       limit ${limitParam} offset ${offsetParam}`,
      params,
    );

    const countParams = status === 'live' || status === 'all' ? [] : [status];
    const total = await this.infra.db.query<{ count: string }>(
      `select count(*)::text as count from rooms r ${where}`,
      countParams,
    );

    const roomIds = rows.rows.map((row) => row.id);
    const participants = roomIds.length
      ? await this.infra.db.query<{
          room_id: string;
          user_id: string;
          display_name: string | null;
          photo_urls: string[] | null;
          joined_at: Date;
          left_at: Date | null;
          admin_removed_at: Date | null;
          connection_count: number;
        }>(
          `select rm.room_id::text, rm.user_id::text, p.display_name, p.photo_urls,
                  rm.joined_at, rm.left_at, rm.admin_removed_at, rm.connection_count
           from room_members rm
           left join profiles p on p.user_id=rm.user_id
           where rm.room_id = any($1::bigint[])
           order by rm.room_id desc, rm.joined_at asc`,
          [roomIds],
        )
      : { rows: [] as any[] };

    const byRoom = new Map<string, typeof participants.rows>();
    for (const member of participants.rows) {
      const bucket = byRoom.get(member.room_id) ?? [];
      bucket.push(member);
      byRoom.set(member.room_id, bucket);
    }

    const connectedSets = new Map<string, Set<string>>();
    await Promise.all(rows.rows.map(async (room) => {
      if (room.status === 'active' || room.status === 'selection') {
        connectedSets.set(room.id, await this.roomsGateway.connectedUserIdsInRoom(room.id));
      }
    }));

    return {
      ok: true,
      admin,
      page,
      limit,
      total: Number(total.rows[0]?.count ?? 0),
      rooms: rows.rows.map((row) => {
        const connected = connectedSets.get(row.id) ?? new Set<string>();
        return {
          id: row.id,
          status: row.status,
          stage: this.stage(row),
          startedAt: row.started_at,
          endsAt: row.ends_at,
          selectionStartedAt: row.selection_started_at,
          selectionEndsAt: row.selection_ends_at,
          closedAt: row.closed_at,
          closedReason: row.closed_reason,
          extended: row.extended,
          remainingSeconds: this.remainingSeconds(row),
          originalMemberCount: row.original_member_count,
          activeMemberCount: row.active_member_count,
          messageCount: row.message_count,
          reportCount: row.report_count,
          hasReports: row.report_count > 0,
          reconnectCount: row.reconnect_count,
          participants: (byRoom.get(row.id) ?? []).map((member) => ({
            userId: member.user_id,
            displayName: member.display_name ?? 'Meet6',
            photoUrl: member.photo_urls?.[0] ?? null,
            connected: connected.has(member.user_id),
            reconnectCount: Math.max(0, Number(member.connection_count ?? 0) - 1),
            removed: member.admin_removed_at != null,
            leftAt: member.left_at,
          })),
        };
      }),
    };
  }

  async roomDetail(adminUserId: string, roomId: string) {
    const admin = await this.requireAdmin(adminUserId);
    await this.rooms.syncExpiredRooms();

    const roomResult = await this.infra.db.query<{
      id: string;
      status: string;
      started_at: Date;
      ends_at: Date;
      extended: boolean;
      selection_started_at: Date | null;
      selection_ends_at: Date | null;
      closed_at: Date | null;
      closed_reason: string | null;
      closed_by_admin_id: string | null;
    }>(
      `select id::text, status, started_at, ends_at, extended,
              selection_started_at, selection_ends_at, closed_at, closed_reason,
              closed_by_admin_id::text
       from rooms where id=$1`,
      [roomId],
    );
    const room = roomResult.rows[0];
    if (!room) throw new NotFoundException('Oda bulunamadı.');

    const [members, messages, reports, votes, selections, connected] = await Promise.all([
      this.infra.db.query<{
        user_id: string;
        display_name: string | null;
        photo_urls: string[] | null;
        joined_at: Date;
        left_at: Date | null;
        connection_count: number;
        last_connected_at: Date | null;
        admin_removed_at: Date | null;
        leave_reason: string | null;
        message_count: number;
        reports_received: number;
      }>(
        `select rm.user_id::text, p.display_name, p.photo_urls, rm.joined_at, rm.left_at,
                rm.connection_count, rm.last_connected_at, rm.admin_removed_at, rm.leave_reason,
                (select count(*)::int from room_messages m where m.room_id=rm.room_id and m.sender_user_id=rm.user_id) as message_count,
                (select count(*)::int from reports rep where rep.room_id=rm.room_id and rep.reported_user_id=rm.user_id) as reports_received
         from room_members rm
         left join profiles p on p.user_id=rm.user_id
         where rm.room_id=$1
         order by rm.joined_at asc`,
        [roomId],
      ),
      this.infra.db.query(
        `select * from (
           select m.id::text, m.sender_user_id::text, p.display_name, p.photo_urls,
                  m.body, m.created_at
           from room_messages m
           left join profiles p on p.user_id=m.sender_user_id
           where m.room_id=$1
           order by m.id desc
           limit 200
         ) latest order by id::bigint asc`,
        [roomId],
      ),
      this.infra.db.query(
        `select rep.id::text, rep.reporter_user_id::text, reporter.display_name as reporter_name,
                rep.reported_user_id::text, reported.display_name as reported_name,
                rep.reason, rep.detail, rep.status, rep.created_at
         from reports rep
         left join profiles reporter on reporter.user_id=rep.reporter_user_id
         left join profiles reported on reported.user_id=rep.reported_user_id
         where rep.room_id=$1
         order by rep.created_at desc`,
        [roomId],
      ),
      this.infra.db.query(
        `select v.user_id::text, p.display_name, v.vote, v.created_at, v.updated_at
         from room_extension_votes v
         left join profiles p on p.user_id=v.user_id
         where v.room_id=$1
         order by v.updated_at asc`,
        [roomId],
      ),
      this.infra.db.query(
        `select s.user_id::text, chooser.display_name as chooser_name,
                s.selected_user_id::text, selected.display_name as selected_name,
                s.created_at, s.updated_at
         from room_selections s
         left join profiles chooser on chooser.user_id=s.user_id
         left join profiles selected on selected.user_id=s.selected_user_id
         where s.room_id=$1
         order by s.updated_at asc`,
        [roomId],
      ),
      this.roomsGateway.connectedUserIdsInRoom(roomId),
    ]);

    const rowForStage: RoomRow = {
      ...room,
      original_member_count: members.rows.length,
      active_member_count: members.rows.filter((member) => member.left_at == null).length,
      message_count: messages.rows.length,
      report_count: reports.rows.length,
      reconnect_count: members.rows.reduce(
        (sum, member) => sum + Math.max(0, Number(member.connection_count ?? 0) - 1),
        0,
      ),
    };

    return {
      ok: true,
      admin,
      room: {
        id: room.id,
        status: room.status,
        stage: this.stage(rowForStage),
        startedAt: room.started_at,
        endsAt: room.ends_at,
        extended: room.extended,
        selectionStartedAt: room.selection_started_at,
        selectionEndsAt: room.selection_ends_at,
        closedAt: room.closed_at,
        closedReason: room.closed_reason,
        closedByAdminId: room.closed_by_admin_id,
        remainingSeconds: this.remainingSeconds(rowForStage),
        messageCount: await this.countRoomMessages(roomId),
        reportCount: reports.rows.length,
        hasReports: reports.rows.length > 0,
        reconnectCount: rowForStage.reconnect_count,
        participants: members.rows.map((member) => ({
          userId: member.user_id,
          displayName: member.display_name ?? 'Meet6',
          photoUrl: member.photo_urls?.[0] ?? null,
          joinedAt: member.joined_at,
          leftAt: member.left_at,
          connected: connected.has(member.user_id),
          reconnectCount: Math.max(0, Number(member.connection_count ?? 0) - 1),
          lastConnectedAt: member.last_connected_at,
          removedByAdmin: member.admin_removed_at != null,
          leaveReason: member.leave_reason,
          messageCount: Number(member.message_count ?? 0),
          reportsReceived: Number(member.reports_received ?? 0),
        })),
        messages: messages.rows,
        reports: reports.rows,
        extensionVotes: votes.rows,
        selections: selections.rows,
      },
    };
  }

  async closeRoom(adminUserId: string, roomId: string, reasonInput: string) {
    const admin = await this.requireModerator(adminUserId);
    const reason = reasonInput.trim();
    if (reason.length < 3) throw new BadRequestException('Odayı kapatmak için neden gerekli.');

    const client = await this.infra.db.connect();
    try {
      await client.query('begin');
      const current = await client.query<{ status: string }>(
        `select status from rooms where id=$1 for update`,
        [roomId],
      );
      if (!current.rows[0]) throw new NotFoundException('Oda bulunamadı.');
      if (current.rows[0].status === 'closed') {
        throw new BadRequestException('Oda zaten kapalı.');
      }
      await client.query(
        `update rooms
         set status='closed', closed_at=now(), closed_reason=$2, closed_by_admin_id=$3
         where id=$1`,
        [roomId, reason, adminUserId],
      );
      await client.query(
        `update room_members
         set left_at=coalesce(left_at, now()), leave_reason=coalesce(leave_reason, 'admin_room_closed')
         where room_id=$1`,
        [roomId],
      );
      await client.query(
        `insert into room_messages(room_id, sender_user_id, body)
         values($1, null, 'Oda moderasyon tarafından kapatıldı.')`,
        [roomId],
      );
      await client.query('commit');
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }

    await this.roomsGateway.adminCloseRoom(roomId, reason);
    await this.audit(adminUserId, 'close_room', 'room', roomId, { reason });
    return { ok: true, roomId, status: 'closed' };
  }

  async removeMember(
    adminUserId: string,
    roomId: string,
    targetUserId: string,
    reasonInput: string,
  ) {
    await this.requireModerator(adminUserId);
    const reason = reasonInput.trim();
    if (reason.length < 3) throw new BadRequestException('Kullanıcıyı çıkarmak için neden gerekli.');

    const client = await this.infra.db.connect();
    try {
      await client.query('begin');
      const room = await client.query<{ status: string }>(
        `select status from rooms where id=$1 for update`,
        [roomId],
      );
      if (!room.rows[0]) throw new NotFoundException('Oda bulunamadı.');
      if (!['active', 'selection'].includes(room.rows[0].status)) {
        throw new BadRequestException('Yalnızca canlı odadan kullanıcı çıkarılabilir.');
      }
      const member = await client.query(
        `select 1 from room_members
         where room_id=$1 and user_id=$2 and left_at is null and admin_removed_at is null
         for update`,
        [roomId, targetUserId],
      );
      if (!member.rowCount) throw new BadRequestException('Kullanıcı bu odada aktif değil.');

      await client.query(
        `update room_members
         set left_at=now(), admin_removed_at=now(), admin_removed_by=$3, leave_reason=$4
         where room_id=$1 and user_id=$2`,
        [roomId, targetUserId, adminUserId, reason.slice(0, 120)],
      );
      await client.query(
        `delete from room_extension_votes where room_id=$1 and user_id=$2`,
        [roomId, targetUserId],
      );
      await client.query(
        `delete from room_selections
         where room_id=$1 and (user_id=$2 or selected_user_id=$2)`,
        [roomId, targetUserId],
      );
      await client.query(
        `insert into room_messages(room_id, sender_user_id, body)
         values($1, null, 'Bir katılımcı odadan çıkarıldı.')`,
        [roomId],
      );
      await client.query('commit');
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }

    await this.roomsGateway.adminRemoveMember(roomId, targetUserId, reason);
    await this.roomsGateway.broadcastRoomUpdate(roomId);
    await this.audit(adminUserId, 'remove_room_member', 'room', roomId, {
      targetUserId,
      reason,
    });
    return { ok: true, roomId, userId: targetUserId };
  }

  private stage(room: Pick<RoomRow, 'status' | 'extended'>) {
    if (room.status === 'closed') return 'closed';
    if (room.status === 'selection') return 'selection';
    if (room.extended) return 'extension';
    return 'chat';
  }

  private remainingSeconds(room: Pick<RoomRow, 'status' | 'ends_at' | 'selection_ends_at'>) {
    const end = room.status === 'active'
      ? room.ends_at
      : room.status === 'selection'
          ? room.selection_ends_at
          : null;
    if (!end) return 0;
    return Math.max(0, Math.ceil((new Date(end).getTime() - Date.now()) / 1000));
  }

  private async countRoomMessages(roomId: string) {
    const result = await this.infra.db.query<{ count: string }>(
      `select count(*)::text as count from room_messages where room_id=$1`,
      [roomId],
    );
    return Number(result.rows[0]?.count ?? 0);
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
