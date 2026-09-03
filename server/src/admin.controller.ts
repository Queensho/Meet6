import { Body, Controller, Get, Headers, Param, Post, Query } from '@nestjs/common';

import { AdminRemovePhotoDto, AdminUserActionDto } from './admin.dto';
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

  @Get('users')
  async users(
    @Headers('authorization') authorization?: string,
    @Query('search') search?: string,
    @Query('status') status?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.admin.listUsers(
      userId,
      search ?? '',
      status ?? 'all',
      Number(page) || 1,
      Number(limit) || 20,
    );
  }

  @Get('users/:userId')
  async userDetail(
    @Headers('authorization') authorization: string | undefined,
    @Param('userId') targetUserId: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.admin.userDetail(userId, targetUserId);
  }

  @Get('users/:userId/moderation-history')
  async moderationHistory(
    @Headers('authorization') authorization: string | undefined,
    @Param('userId') targetUserId: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.admin.moderationHistory(userId, targetUserId);
  }

  @Post('users/:userId/action')
  async userAction(
    @Headers('authorization') authorization: string | undefined,
    @Param('userId') targetUserId: string,
    @Body() body: AdminUserActionDto,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.admin.moderateUser(userId, targetUserId, body);
  }

  @Post('users/:userId/remove-photo')
  async removePhoto(
    @Headers('authorization') authorization: string | undefined,
    @Param('userId') targetUserId: string,
    @Body() body: AdminRemovePhotoDto,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.admin.removePhoto(userId, targetUserId, body);
  }
}
