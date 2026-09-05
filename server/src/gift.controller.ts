import { Body, Controller, Get, Headers, Param, Post, Query } from '@nestjs/common';

import { AuthService } from './auth.service';
import { SendRoomGiftDto } from './gift.dto';
import { GiftService } from './gift.service';
import { RoomsGateway } from './rooms.gateway';

@Controller('gifts')
export class GiftController {
  constructor(
    private readonly auth: AuthService,
    private readonly gifts: GiftService,
    private readonly realtime: RoomsGateway,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  @Get('catalog')
  async catalog(@Headers('authorization') authorization?: string) {
    return this.gifts.catalog(await this.userId(authorization));
  }

  @Get('me')
  async me(@Headers('authorization') authorization?: string) {
    return this.gifts.mySummary(await this.userId(authorization));
  }

  @Get('users/:userId')
  async userSummary(
    @Headers('authorization') authorization: string | undefined,
    @Param('userId') targetUserId: string,
  ) {
    return this.gifts.publicSummary(await this.userId(authorization), targetUserId);
  }

  @Get('rooms/:roomId')
  async roomHistory(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Query('after') after?: string,
  ) {
    return this.gifts.roomHistory(
      await this.userId(authorization),
      roomId,
      Number.parseInt(after ?? '0', 10) || 0,
    );
  }

  @Post('rooms/:roomId/send')
  async sendRoomGift(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Body() body: SendRoomGiftDto,
  ) {
    const result = await this.gifts.sendRoomGift(
      await this.userId(authorization),
      roomId,
      body.recipientUserId,
      body.giftCode,
      body.clientGiftId,
    );

    if (!result.deduplicated && result.gift) {
      this.realtime.server.to(`room:${roomId}`).emit('room:gift', {
        roomId,
        gift: result.gift,
      });
      // Older realtime clients already forward room:message. New clients use the
      // structured _kind=gift payload to render the richer gift card.
      this.realtime.server.to(`room:${roomId}`).emit('room:message', {
        roomId,
        message: result.gift,
      });
    }
    return result;
  }
}
