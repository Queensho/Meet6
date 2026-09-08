import { Body, Controller, Delete, Get, Headers, Post, Query } from '@nestjs/common';

import { AuthService } from './auth.service';
import { PartyMatchmakingService } from './party-matchmaking.service';

@Controller('rooms/party')
export class PartyMatchmakingController {
  constructor(
    private readonly auth: AuthService,
    private readonly parties: PartyMatchmakingService,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  @Post()
  async create(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: { roomMode?: string; gameKey?: string; roomDurationMinutes?: number },
  ) {
    return this.parties.create(await this.userId(authorization), body ?? {});
  }

  @Post('accept')
  async accept(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: { code?: string },
  ) {
    return this.parties.accept(await this.userId(authorization), body?.code);
  }

  @Post('search')
  async search(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: { code?: string },
  ) {
    return this.parties.search(await this.userId(authorization), body?.code);
  }

  @Get()
  async status(
    @Headers('authorization') authorization: string | undefined,
    @Query('code') code?: string,
  ) {
    return this.parties.status(await this.userId(authorization), code);
  }

  @Delete()
  async cancel(
    @Headers('authorization') authorization: string | undefined,
    @Query('code') code?: string,
  ) {
    return this.parties.cancel(await this.userId(authorization), code);
  }
}
