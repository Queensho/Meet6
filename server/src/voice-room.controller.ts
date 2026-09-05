import { Body, Controller, Delete, Get, Headers, Param, Post, Put } from '@nestjs/common';

import { AuthService } from './auth.service';
import { RoomsGateway } from './rooms.gateway';
import { VoiceRoomService } from './voice-room.service';

@Controller('voice-rooms')
export class VoiceRoomController {
  constructor(
    private readonly auth: AuthService,
    private readonly voiceRooms: VoiceRoomService,
    private readonly realtime: RoomsGateway,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  @Post('queue')
  async joinQueue(@Headers('authorization') authorization?: string) {
    return this.voiceRooms.joinQueue(await this.userId(authorization));
  }

  @Get('queue')
  async queueStatus(@Headers('authorization') authorization?: string) {
    return this.voiceRooms.queueStatus(await this.userId(authorization));
  }

  @Delete('queue')
  async cancelQueue(@Headers('authorization') authorization?: string) {
    return this.voiceRooms.cancelQueue(await this.userId(authorization));
  }

  @Get(':roomId/preview')
  async previewStatus(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
  ) {
    return this.voiceRooms.previewStatus(await this.userId(authorization), roomId);
  }

  @Put(':roomId/preview-decision')
  async previewDecision(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Body() body: { continue?: unknown },
  ) {
    const result = await this.voiceRooms.submitPreviewDecision(
      await this.userId(authorization),
      roomId,
      body?.continue,
    );
    await this.realtime.broadcastRoomUpdate(roomId);
    return result;
  }

  @Post(':roomId/token')
  async token(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
  ) {
    return this.voiceRooms.liveKitToken(await this.userId(authorization), roomId);
  }
}
