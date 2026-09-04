import { Body, Controller, Get, Headers, Param, Post, Query } from '@nestjs/common';

import {
  AdminPhotoModerationActionDto,
  AdminRemovePhotoDto,
  AdminReportActionDto,
  AdminReportEvidenceDto,
  AdminRoomActionDto,
  AdminRuntimeSettingsDto,
  AdminSupportActionDto,
  AdminUserActionDto,
} from './admin.dto';
import { AdminGovernanceService } from './admin-governance.service';
import { AdminMatchService } from './admin-match.service';
import { AdminReportService } from './admin-report.service';
import { AdminRoomService } from './admin-room.service';
import { AdminSafetyService } from './admin-safety.service';
import { AdminService } from './admin.service';
import { AdminSettingsService } from './admin-settings.service';
import { AdminSupportService } from './admin-support.service';
import { AuthService } from './auth.service';

@Controller('admin')
export class AdminController {
  constructor(
    private readonly auth: AuthService,
    private readonly admin: AdminService,
    private readonly adminRooms: AdminRoomService,
    private readonly adminMatches: AdminMatchService,
    private readonly adminReports: AdminReportService,
    private readonly adminSupport: AdminSupportService,
    private readonly governance: AdminGovernanceService,
    private readonly adminSettings: AdminSettingsService,
    private readonly adminSafety: AdminSafetyService,
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

  @Get('settings')
  async settings(@Headers('authorization') authorization?: string) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminSettings.get(userId);
  }

  @Post('settings')
  async updateSettings(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: AdminRuntimeSettingsDto,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminSettings.update(userId, body);
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
    return this.admin.listUsers(userId, search ?? '', status ?? 'all', Number(page) || 1, Number(limit) || 20);
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

  @Get('safety/photos')
  async safetyPhotos(
    @Headers('authorization') authorization: string | undefined,
    @Query('status') status?: string,
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminSafety.listPhotos(
      userId,
      status ?? 'review',
      search ?? '',
      Number(page) || 1,
      Number(limit) || 20,
    );
  }

  @Post('safety/photos/:moderationId/action')
  async safetyPhotoAction(
    @Headers('authorization') authorization: string | undefined,
    @Param('moderationId') moderationId: string,
    @Body() body: AdminPhotoModerationActionDto,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminSafety.photoAction(userId, moderationId, body);
  }

  @Get('safety/reports')
  async safetyReports(
    @Headers('authorization') authorization: string | undefined,
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminSafety.priorityReports(
      userId,
      search ?? '',
      Number(page) || 1,
      Number(limit) || 20,
    );
  }

  @Get('safety/risk-users')
  async safetyRiskUsers(
    @Headers('authorization') authorization: string | undefined,
    @Query('level') level?: string,
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminSafety.riskUsers(
      userId,
      level ?? 'high',
      search ?? '',
      Number(page) || 1,
      Number(limit) || 20,
    );
  }

  @Get('rooms')
  async rooms(
    @Headers('authorization') authorization: string | undefined,
    @Query('status') status?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminRooms.listRooms(userId, status ?? 'live', Number(page) || 1, Number(limit) || 20);
  }

  @Get('rooms/:roomId')
  async roomDetail(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminRooms.roomDetail(userId, roomId);
  }

  @Post('rooms/:roomId/close')
  async closeRoom(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Body() body: AdminRoomActionDto,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminRooms.closeRoom(userId, roomId, body.reason);
  }

  @Post('rooms/:roomId/members/:targetUserId/remove')
  async removeRoomMember(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Param('targetUserId') targetUserId: string,
    @Body() body: AdminRoomActionDto,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminRooms.removeMember(userId, roomId, targetUserId, body.reason);
  }

  @Get('matches')
  async matches(
    @Headers('authorization') authorization: string | undefined,
    @Query('status') status?: string,
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminMatches.listMatches(userId, status ?? 'all', search ?? '', Number(page) || 1, Number(limit) || 20);
  }

  @Get('matches/:matchId')
  async matchDetail(
    @Headers('authorization') authorization: string | undefined,
    @Param('matchId') matchId: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminMatches.matchDetail(userId, matchId);
  }

  @Post('matches/:matchId/end')
  async endMatch(
    @Headers('authorization') authorization: string | undefined,
    @Param('matchId') matchId: string,
    @Body() body: AdminRoomActionDto,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminMatches.endMatch(userId, matchId, body.reason);
  }

  @Get('reports')
  async reports(
    @Headers('authorization') authorization: string | undefined,
    @Query('status') status?: string,
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminReports.listReports(userId, status ?? 'open', search ?? '', Number(page) || 1, Number(limit) || 20);
  }

  @Get('reports/:reportId')
  async reportDetail(
    @Headers('authorization') authorization: string | undefined,
    @Param('reportId') reportId: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminReports.reportDetail(userId, reportId);
  }

  @Post('reports/:reportId/action')
  async reportAction(
    @Headers('authorization') authorization: string | undefined,
    @Param('reportId') reportId: string,
    @Body() body: AdminReportActionDto,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminReports.action(userId, reportId, body);
  }

  @Post('reports/:reportId/evidence')
  async markReportEvidence(
    @Headers('authorization') authorization: string | undefined,
    @Param('reportId') reportId: string,
    @Body() body: AdminReportEvidenceDto,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminReports.markEvidence(userId, reportId, body.messageId, body.keyEvidence);
  }

  @Get('support')
  async supportRequests(
    @Headers('authorization') authorization: string | undefined,
    @Query('status') status?: string,
    @Query('priority') priority?: string,
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminSupport.list(userId, status ?? 'open', priority ?? 'all', search ?? '', Number(page) || 1, Number(limit) || 20);
  }

  @Get('support/:requestId')
  async supportRequestDetail(
    @Headers('authorization') authorization: string | undefined,
    @Param('requestId') requestId: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminSupport.detail(userId, requestId);
  }

  @Post('support/:requestId/action')
  async supportRequestAction(
    @Headers('authorization') authorization: string | undefined,
    @Param('requestId') requestId: string,
    @Body() body: AdminSupportActionDto,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.adminSupport.action(userId, requestId, body);
  }

  @Get('bans')
  async bans(
    @Headers('authorization') authorization: string | undefined,
    @Query('status') status?: string,
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.governance.listBans(userId, status ?? 'active', search ?? '', Number(page) || 1, Number(limit) || 20);
  }

  @Get('bans/:banId')
  async banDetail(
    @Headers('authorization') authorization: string | undefined,
    @Param('banId') banId: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.governance.banDetail(userId, banId);
  }

  @Post('bans/:banId/revoke')
  async revokeBan(
    @Headers('authorization') authorization: string | undefined,
    @Param('banId') banId: string,
    @Body() body: AdminRoomActionDto,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.governance.revokeBan(userId, banId, body.reason);
  }

  @Get('audit-logs')
  async auditLogs(
    @Headers('authorization') authorization: string | undefined,
    @Query('action') action?: string,
    @Query('targetType') targetType?: string,
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.governance.auditLogs(userId, action ?? 'all', targetType ?? 'all', search ?? '', Number(page) || 1, Number(limit) || 30);
  }
}
