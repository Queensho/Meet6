import { Controller, Delete, Get, Headers, Post } from '@nestjs/common';

import { AuthService } from './auth.service';
import { TabuGameService } from './tabu-game.service';

@Controller('rooms/tabu/queue')
export class TabuQueueController {
  constructor(
    private readonly auth: AuthService,
    private readonly tabu: TabuGameService,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  @Post()
  async join(@Headers('authorization') authorization?: string) {
    return this.tabu.joinQueue(await this.userId(authorization));
  }

  @Get()
  async status(@Headers('authorization') authorization?: string) {
    return this.tabu.queueStatus(await this.userId(authorization));
  }

  @Delete()
  async cancel(@Headers('authorization') authorization?: string) {
    return this.tabu.cancelQueue(await this.userId(authorization));
  }
}
