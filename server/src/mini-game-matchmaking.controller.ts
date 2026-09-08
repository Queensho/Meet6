import { Body, Controller, Delete, Get, Headers, Post, Query } from '@nestjs/common';
import { AuthService } from './auth.service';
import { MiniGameMatchmakingService } from './mini-game-matchmaking.service';

@Controller('rooms/mini-game/queue')
export class MiniGameMatchmakingController {
  constructor(
    private readonly auth: AuthService,
    private readonly queue: MiniGameMatchmakingService,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  @Post()
  async join(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: { gameKey?: string },
  ) {
    return this.queue.join(await this.userId(authorization), body?.gameKey);
  }

  @Get()
  async status(
    @Headers('authorization') authorization: string | undefined,
    @Query('gameKey') gameKey?: string,
  ) {
    return this.queue.status(await this.userId(authorization), gameKey);
  }

  @Delete()
  async cancel(@Headers('authorization') authorization?: string) {
    return this.queue.cancel(await this.userId(authorization));
  }
}
