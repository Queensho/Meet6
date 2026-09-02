import { Body, Controller, Delete, Get, Headers, Param, Post, Put, Query } from '@nestjs/common';

import { AuthService } from './auth.service';
import { ExtensionVoteDto, RoomSelectionDto, SendRoomMessageDto } from './room.dto';
import { RoomService } from './room.service';
import { RoomsGateway } from './rooms.gateway';

@Controller('rooms')
export class RoomController {
  constructor(
    private readonly auth: AuthService,
    private readonly rooms: RoomService,
    private readonly realtime: RoomsGateway,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  @Post('queue')
  async joinQueue(@Headers('authorization') authorization?: string) {
    const result = await this.rooms.joinQueue(await this.userId(authorization)) as Record<string, any>;
    if (result.state === 'room' && result.room) {
      const roomId = (result.room as Record<string, any>).id?.toString();
      if (roomId) await this.realtime.broadcastRoomUpdate(roomId);
    }
    return result;
  }

  @Get('queue')
  async queueStatus(@Headers('authorization') authorization?: string) {
    return this.rooms.queueStatus(await this.userId(authorization));
  }

  @Delete('queue')
  async cancelQueue(@Headers('authorization') authorization?: string) {
    return this.rooms.cancelQueue(await this.userId(authorization));
  }

  @Get(':roomId')
  async room(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
  ) {
    return this.rooms.getRoom(await this.userId(authorization), roomId);
  }

  @Get(':roomId/messages')
  async messages(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Query('after') after?: string,
  ) {
    return this.rooms.messages(
      await this.userId(authorization),
      roomId,
      Number.parseInt(after ?? '0', 10) || 0,
    );
  }

  @Post(':roomId/messages')
  async sendMessage(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Body() body: SendRoomMessageDto,
  ) {
    return this.rooms.sendMessage(await this.userId(authorization), roomId, body.body);
  }

  @Put(':roomId/extension-vote')
  async extensionVote(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Body() body: ExtensionVoteDto,
  ) {
    const result = await this.rooms.voteExtension(await this.userId(authorization), roomId, body.vote);
    await this.realtime.broadcastRoomUpdate(roomId);
    return result;
  }

  @Put(':roomId/selection')
  async selection(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Body() body: RoomSelectionDto,
  ) {
    return this.rooms.submitSelection(await this.userId(authorization), roomId, body.selectedUserId);
  }

  @Get(':roomId/selection-result')
  async selectionResult(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
  ) {
    return this.rooms.selectionResult(await this.userId(authorization), roomId);
  }
}
