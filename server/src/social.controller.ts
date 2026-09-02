import { Body, Controller, Delete, Get, Headers, Param, Post, Put, Query } from '@nestjs/common';

import { AuthService } from './auth.service';
import { ReportUserDto, SendPrivateMessageDto, UpdateSettingsDto } from './social.dto';
import { SocialService } from './social.service';

@Controller()
export class SocialController {
  constructor(
    private readonly auth: AuthService,
    private readonly social: SocialService,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  @Get('matches')
  async matches(@Headers('authorization') authorization?: string) {
    return this.social.listMatches(await this.userId(authorization));
  }

  @Get('matches/:matchId')
  async matchDetail(
    @Headers('authorization') authorization: string | undefined,
    @Param('matchId') matchId: string,
  ) {
    return this.social.matchDetail(await this.userId(authorization), matchId);
  }

  @Get('matches/:matchId/messages')
  async messages(
    @Headers('authorization') authorization: string | undefined,
    @Param('matchId') matchId: string,
    @Query('after') after?: string,
  ) {
    return this.social.privateMessages(
      await this.userId(authorization),
      matchId,
      Number.parseInt(after ?? '0', 10) || 0,
    );
  }

  @Post('matches/:matchId/messages')
  async sendMessage(
    @Headers('authorization') authorization: string | undefined,
    @Param('matchId') matchId: string,
    @Body() body: SendPrivateMessageDto,
  ) {
    return this.social.sendPrivateMessage(await this.userId(authorization), matchId, body.body);
  }

  @Post('matches/:matchId/read')
  async read(
    @Headers('authorization') authorization: string | undefined,
    @Param('matchId') matchId: string,
  ) {
    return this.social.markRead(await this.userId(authorization), matchId);
  }

  @Delete('matches/:matchId')
  async unmatch(
    @Headers('authorization') authorization: string | undefined,
    @Param('matchId') matchId: string,
  ) {
    return this.social.unmatch(await this.userId(authorization), matchId);
  }

  @Get('blocks')
  async blocks(@Headers('authorization') authorization?: string) {
    return this.social.blocks(await this.userId(authorization));
  }

  @Post('users/:userId/block')
  async block(
    @Headers('authorization') authorization: string | undefined,
    @Param('userId') targetUserId: string,
  ) {
    return this.social.block(await this.userId(authorization), targetUserId);
  }

  @Delete('users/:userId/block')
  async unblock(
    @Headers('authorization') authorization: string | undefined,
    @Param('userId') targetUserId: string,
  ) {
    return this.social.unblock(await this.userId(authorization), targetUserId);
  }

  @Post('users/:userId/report')
  async report(
    @Headers('authorization') authorization: string | undefined,
    @Param('userId') targetUserId: string,
    @Body() body: ReportUserDto,
  ) {
    return this.social.report(
      await this.userId(authorization),
      targetUserId,
      body.reason,
      body.detail,
      body.roomId,
    );
  }

  @Get('me/settings')
  async settings(@Headers('authorization') authorization?: string) {
    return this.social.getSettings(await this.userId(authorization));
  }

  @Put('me/settings')
  async updateSettings(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: UpdateSettingsDto,
  ) {
    return this.social.updateSettings(await this.userId(authorization), body);
  }

  @Get('notifications')
  async notifications(@Headers('authorization') authorization?: string) {
    return this.social.notifications(await this.userId(authorization));
  }

  @Post('notifications/read')
  async readNotifications(@Headers('authorization') authorization?: string) {
    return this.social.markNotificationsRead(await this.userId(authorization));
  }
}
