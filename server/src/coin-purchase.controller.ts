import { Controller, Get, Headers, Post } from '@nestjs/common';

import { AuthService } from './auth.service';
import { CoinPurchaseService } from './coin-purchase.service';

@Controller('coins')
export class CoinPurchaseController {
  constructor(
    private readonly auth: AuthService,
    private readonly coins: CoinPurchaseService,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  @Get('packs')
  async packs(@Headers('authorization') authorization?: string) {
    return this.coins.packs(await this.userId(authorization));
  }

  @Post('sync')
  async sync(@Headers('authorization') authorization?: string) {
    return this.coins.sync(await this.userId(authorization));
  }
}
