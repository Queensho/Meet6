import {
  BadRequestException,
  Controller,
  ForbiddenException,
  Get,
  Headers,
  Param,
  Put,
} from '@nestjs/common';

import { AuthService } from './auth.service';
import { InfrastructureService } from './infrastructure.service';
import { normalizeTurkishPhone } from './phone.util';
import { RoomsGateway } from './rooms.gateway';

@Controller('rooms')
export class RoomControlController {
  constructor(
    private readonly auth: AuthService,
    private readonly infra: InfrastructureService,
    private readonly realtime: RoomsGateway,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  private configuredPhone() {
    const raw = process.env.ROOM_FORCE_END_PHONE?.trim();
    if (!raw) return null;
    try {
      return normalizeTurkishPhone(raw);
    } catch (_) {
      return null;
    }
  }

  private async assertMember(userId: string, roomId: string) {
    const result = await this.infra.db.query<{ exists: boolean }>(
      `select exists(
         select 1 from room_members
         where room_id = $1 and user_id = $2 and left_at is null
       ) as exists`,
      [roomId, userId],
    );
    if (!result.rows[0]?.exists) {
      throw new ForbiddenException('Bu odaya erişimin yok.');
    }
  }

  private async allowed(userId: string) {
    const configured = this.configuredPhone();
    if (!configured) return false;
    const result = await this.infra.db.query<{ phone_e164: string }>(
      'select phone_e164 from users where id = $1',
      [userId],
    );
    return result.rows[0]?.phone_e164 === configured;
  }

  @Get(':roomId/force-selection-capability')
  async capability(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
  ) {
    const userId = await this.userId(authorization);
    await this.assertMember(userId, roomId);
    const room = await this.infra.db.query<{ status: string }>(
      'select status from rooms where id = $1',
      [roomId],
    );
    return {
      ok: true,
      allowed: room.rows[0]?.status === 'active' && await this.allowed(userId),
    };
  }

  @Put(':roomId/force-selection')
  async forceSelection(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
  ) {
    const userId = await this.userId(authorization);
    await this.assertMember(userId, roomId);
    if (!await this.allowed(userId)) {
      throw new ForbiddenException('Bu işlem için yetkin yok.');
    }

    const result = await this.infra.db.query<{ id: string }>(
      `update rooms
       set status = 'selection',
           ends_at = now(),
           selection_started_at = now(),
           selection_ends_at = now() + interval '10 seconds'
       where id = $1 and status = 'active'
       returning id::text`,
      [roomId],
    );
    if (!result.rows[0]) {
      throw new BadRequestException('Oda artık aktif değil.');
    }

    await this.infra.db.query(
      `insert into room_messages(room_id, sender_user_id, body)
       values($1, null, 'Sohbet erken bitirildi. Gizli seçim için 10 saniyen var.')`,
      [roomId],
    );

    await this.realtime.broadcastRoomUpdate(roomId);

    return {
      ok: true,
      roomId: result.rows[0].id,
      status: 'selection',
      selectionSecondsLeft: 10,
    };
  }
}
