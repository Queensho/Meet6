import { Controller, Delete, Get, Headers, Param } from '@nestjs/common';

import { AuthService } from './auth.service';
import { InfrastructureService } from './infrastructure.service';
import { RoomService } from './room.service';
import { RoomsGateway } from './rooms.gateway';

@Controller('room-session')
export class ActiveRoomController {
  constructor(
    private readonly auth: AuthService,
    private readonly infra: InfrastructureService,
    private readonly rooms: RoomService,
    private readonly realtime: RoomsGateway,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  @Get('current')
  async current(@Headers('authorization') authorization?: string) {
    const userId = await this.userId(authorization);
    await this.rooms.syncExpiredRooms();
    const result = await this.infra.db.query<{ room_id: string }>(
      `select rm.room_id::text
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
    const roomId = result.rows[0]?.room_id;
    if (!roomId) return { ok: true, room: null };
    return { ok: true, room: await this.rooms.getRoom(userId, roomId) };
  }

  @Delete(':roomId')
  async leave(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
  ) {
    const userId = await this.userId(authorization);
    await this.rooms.syncExpiredRooms();
    const result = await this.infra.db.query<{ room_id: string }>(
      `update room_members rm
       set left_at=now()
       from rooms r
       where rm.room_id=r.id
         and rm.room_id=$1
         and rm.user_id=$2
         and rm.left_at is null
         and rm.admin_removed_at is null
         and r.status in ('active','selection')
       returning rm.room_id::text`,
      [roomId, userId],
    );

    await this.infra.db.query('delete from matchmaking_queue where user_id=$1', [userId]);
    await this.infra.db.query('delete from voice_matchmaking_queue where user_id=$1', [userId]);

    if (result.rowCount) {
      await this.realtime.broadcastRoomUpdate(roomId);
    }

    return {
      ok: true,
      roomId,
      left: (result.rowCount ?? 0) > 0,
    };
  }
}
