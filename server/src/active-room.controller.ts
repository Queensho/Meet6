import { Controller, Delete, Get, Headers, Param } from '@nestjs/common';

import { AuthService } from './auth.service';
import { InfrastructureService } from './infrastructure.service';
import { RoomRefillService } from './room-refill.service';
import { RoomService } from './room.service';
import { RoomsGateway } from './rooms.gateway';

@Controller('room-session')
export class ActiveRoomController {
  constructor(
    private readonly auth: AuthService,
    private readonly infra: InfrastructureService,
    private readonly rooms: RoomService,
    private readonly refills: RoomRefillService,
    private readonly realtime: RoomsGateway,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  @Get('current')
  async current(@Headers('authorization') authorization?: string) {
    const userId = await this.userId(authorization);
    await this.rooms.syncExpiredRooms();
    const result = await this.infra.db.query<{ room_id: string; room_mode: string }>(
      `select rm.room_id::text, r.room_mode
       from room_members rm
       join rooms r on r.id=rm.room_id
       where rm.user_id=$1
         and rm.left_at is null
         and rm.admin_removed_at is null
         and r.status in ('active','selection')
       order by rm.room_id desc
       limit 1`,
      [userId],
    );
    const row = result.rows[0];
    if (!row) return { ok: true, room: null };
    const room = await this.rooms.getRoom(userId, row.room_id) as Record<string, any>;
    return {
      ok: true,
      room: {
        ...room,
        roomMode: row.room_mode,
      },
    };
  }

  @Delete(':roomId')
  async leave(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
  ) {
    const userId = await this.userId(authorization);
    await this.rooms.syncExpiredRooms();

    const membership = await this.infra.db.query<{
      room_mode: string;
      status: string;
      started_at: Date;
    }>(
      `select r.room_mode, r.status, r.started_at
       from room_members rm
       join rooms r on r.id=rm.room_id
       where rm.room_id=$1
         and rm.user_id=$2
         and rm.left_at is null
         and rm.admin_removed_at is null
         and r.status in ('active','selection')
       limit 1`,
      [roomId, userId],
    );
    const current = membership.rows[0];
    if (!current) {
      return { ok: true, roomId, left: false };
    }

    if (current.room_mode === 'voice') {
      const client = await this.infra.db.connect();
      try {
        await client.query('begin');
        const members = await client.query<{ user_id: string }>(
          `select user_id::text
           from room_members
           where room_id=$1
             and left_at is null
             and admin_removed_at is null`,
          [roomId],
        );
        const memberIds = members.rows.map((row) => row.user_id);

        await client.query(
          `update rooms
           set status='closed',
               closed_at=coalesce(closed_at,now()),
               closed_reason=coalesce(closed_reason,'participant_left')
           where id=$1 and status in ('active','selection')`,
          [roomId],
        );
        await client.query(
          `update room_members
           set left_at=coalesce(left_at,now()),
               leave_reason=case
                 when user_id=$2 then 'voluntary_leave'
                 else coalesce(leave_reason,'peer_left')
               end
           where room_id=$1 and left_at is null`,
          [roomId, userId],
        );
        if (memberIds.length) {
          await client.query('delete from matchmaking_queue where user_id=any($1::bigint[])', [memberIds]);
          await client.query('delete from voice_matchmaking_queue where user_id=any($1::bigint[])', [memberIds]);
        }
        await client.query('commit');
      } catch (error) {
        await client.query('rollback').catch(() => undefined);
        throw error;
      } finally {
        client.release();
      }

      // A one-to-one voice call is atomic: one participant leaving ends it for both.
      await this.realtime.broadcastRoomUpdate(roomId);
      return {
        ok: true,
        roomId,
        left: true,
        closedForEveryone: true,
        roomMode: 'voice',
      };
    }

    const result = await this.infra.db.query<{
      room_id: string;
      started_at: Date;
      status: string;
    }>(
      `update room_members rm
       set left_at=now(),
           admin_removed_at=now(),
           admin_removed_by=null,
           leave_reason='voluntary_leave'
       from rooms r
       where rm.room_id=r.id
         and rm.room_id=$1
         and rm.user_id=$2
         and rm.left_at is null
         and rm.admin_removed_at is null
         and r.status in ('active','selection')
       returning rm.room_id::text, r.started_at, r.status`,
      [roomId, userId],
    );

    await this.infra.db.query('delete from matchmaking_queue where user_id=$1', [userId]);
    await this.infra.db.query('delete from voice_matchmaking_queue where user_id=$1', [userId]);

    const left = (result.rowCount ?? 0) > 0;
    const row = result.rows[0];
    const elapsedSeconds = row
      ? Math.max(0, Math.floor((Date.now() - new Date(row.started_at).getTime()) / 1000))
      : Number.POSITIVE_INFINITY;
    const refillOpen = left && row?.status === 'active' && elapsedSeconds < 5 * 60;

    if (left) {
      await this.infra.db.query(
        `insert into room_messages(room_id,sender_user_id,body)
         values($1,null,$2)`,
        [
          roomId,
          refillOpen
            ? 'Bir kişi odadan ayrıldı. İlk 5 dakika içinde yeni bir kişi katılabilir.'
            : 'Bir kişi odadan ayrıldı. Oda kalan kişilerle devam ediyor.',
        ],
      );
    }

    const refilledRooms = refillOpen ? await this.refills.processOpenSeats() : [];
    const roomsToRefresh = new Set<string>([roomId, ...refilledRooms]);
    if (left) {
      for (const changedRoomId of roomsToRefresh) {
        await this.realtime.broadcastRoomUpdate(changedRoomId);
      }
      if (refilledRooms.length) {
        await this.realtime.broadcastQueueStatus();
      }
    }

    return {
      ok: true,
      roomId,
      left,
      roomMode: 'text',
      refillOpen,
      refilled: refilledRooms.includes(roomId),
    };
  }
}
