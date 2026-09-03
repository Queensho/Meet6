import { Controller, Get, Headers, Query } from '@nestjs/common';

import { AdminService } from './admin.service';
import { AuthService } from './auth.service';

@Controller('admin')
export class AdminController {
  constructor(
    private readonly auth: AuthService,
    private readonly admin: AdminService,
  ) {}

  @Get('me')
  async me(@Headers('authorization') authorization?: string) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.admin.me(userId);
  }

  @Get('dashboard')
  async dashboard(
    @Headers('authorization') authorization?: string,
    @Query('period') period?: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.admin.dashboard(userId, Number(period) === 30 ? 30 : 7);
  }
}
