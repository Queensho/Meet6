import { Body, Controller, Get, Headers, Post } from '@nestjs/common';

import { AuthService } from './auth.service';
import { BillingService } from './billing.service';

@Controller('billing')
export class BillingController {
  constructor(
    private readonly auth: AuthService,
    private readonly billing: BillingService,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  @Get('me')
  async me(@Headers('authorization') authorization?: string) {
    return this.billing.getSubscription(await this.userId(authorization));
  }

  @Post('me/refresh')
  async refresh(@Headers('authorization') authorization?: string) {
    return this.billing.syncFromRevenueCat(await this.userId(authorization));
  }

  @Post('revenuecat/webhook')
  async revenueCatWebhook(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: Record<string, unknown>,
  ) {
    return this.billing.handleRevenueCatWebhook(authorization, body);
  }
}
