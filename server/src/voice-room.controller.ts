import { Controller, Delete, Get, Headers, Param, Post } from '@nestjs/common';

import { AuthService } from './auth.service';
import { VoiceRoomService } from './voice-room.service';

@Controller('voice-rooms')
export class VoiceRoomController {
  constructor(
    private readonly auth: AuthService,
    private readonly voiceRooms: VoiceRoomService,
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

  @Post(':roomId/token')
  async token(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
  ) {
    return this.voiceRooms.liveKitToken(await this.userId(authorization), roomId);
  }
}
