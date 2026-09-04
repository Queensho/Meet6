import { Body, Controller, Delete, Get, Headers, Param, Post, Put, Query } from '@nestjs/common';

import { AuthService } from './auth.service';
import { InfrastructureService } from './infrastructure.service';
import { ReportService } from './report.service';
import { ReportUserDto, SendPrivateMessageDto, UpdateSettingsDto } from './social.dto';
import { SocialService } from './social.service';

@Controller()
export class SocialController {
  constructor(
    private readonly auth: AuthService,
    private readonly social: SocialService,
    private readonly reports: ReportService,
    private readonly infra: InfrastructureService,
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
    return this.reports.submit(
      await this.userId(authorization),
      targetUserId,
      body.reason,
      body.detail,
      body.roomId,
      body.matchId,
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

  @Get('me/data-export')
  async dataExport(@Headers('authorization') authorization?: string) {
    const userId = await this.userId(authorization);
    const [
      account,
      profile,
      matchingPreferences,
      settings,
      matches,
      privateMessages,
      roomMemberships,
      roomMessagesSent,
      roomSelections,
      blockedAccounts,
      reportsSubmitted,
      supportRequests,
      notifications,
    ] = await Promise.all([
      this.infra.db.query(
        `select id::text, phone_e164, status, created_at, updated_at, last_seen_at
         from users where id=$1`,
        [userId],
      ),
      this.infra.db.query(
        `select user_id::text, display_name, birth_date, gender, bio, city, country,
                latitude, longitude, profile_prompt, profile_answer, interests,
                photo_urls, profile_completed, created_at, updated_at
         from profiles where user_id=$1`,
        [userId],
      ),
      this.infra.db.query(
        `select user_id::text, looking_for, min_age, max_age, distance_km, purpose, updated_at
         from matching_preferences where user_id=$1`,
        [userId],
      ),
      this.infra.db.query(
        `select notifications_enabled, room_reminders, show_online, precise_location,
                vibration, allow_room_invites, allow_private_messages,
                hide_exact_distance, read_receipts, updated_at
         from user_settings where user_id=$1`,
        [userId],
      ),
      this.infra.db.query(
        `select id::text, user_a_id::text, user_b_id::text, created_at, unmatched_at
         from matches
         where user_a_id=$1 or user_b_id=$1
         order by created_at`,
        [userId],
      ),
      this.infra.db.query(
        `select pm.id::text, pm.match_id::text, pm.sender_user_id::text, pm.body,
                pm.created_at, pm.delivered_at, pm.read_at
         from private_messages pm
         join matches m on m.id=pm.match_id
         where m.user_a_id=$1 or m.user_b_id=$1
         order by pm.id`,
        [userId],
      ),
      this.infra.db.query(
        `select room_id::text, joined_at, left_at
         from room_members
         where user_id=$1
         order by room_id`,
        [userId],
      ),
      this.infra.db.query(
        `select id::text, room_id::text, sender_user_id::text, body, created_at
         from room_messages
         where sender_user_id=$1
         order by id`,
        [userId],
      ),
      this.infra.db.query(
        `select room_id::text, selected_user_id::text, created_at, updated_at
         from room_selections
         where user_id=$1
         order by room_id`,
        [userId],
      ),
      this.infra.db.query(
        `select blocked_user_id::text, created_at
         from blocked_users
         where blocker_user_id=$1
         order by created_at`,
        [userId],
      ),
      this.infra.db.query(
        `select id::text, reported_user_id::text, room_id::text, match_id::text,
                reason, detail, status, resolution, created_at, updated_at
         from reports
         where reporter_user_id=$1
         order by created_at`,
        [userId],
      ),
      this.infra.db.query(
        `select id::text, topic, message, status, priority, admin_response,
                responded_at, closed_at, created_at, updated_at
         from support_requests
         where user_id=$1
         order by created_at`,
        [userId],
      ),
      this.infra.db.query(
        `select id::text, type, title, body, data, read_at, created_at
         from notifications
         where user_id=$1
         order by created_at`,
        [userId],
      ),
    ]);

    return {
      ok: true,
      schemaVersion: 1,
      exportedAt: new Date().toISOString(),
      account: account.rows[0] ?? null,
      profile: profile.rows[0] ?? null,
      matchingPreferences: matchingPreferences.rows[0] ?? null,
      settings: settings.rows[0] ?? null,
      matches: matches.rows,
      privateMessages: privateMessages.rows,
      roomMemberships: roomMemberships.rows,
      roomMessagesSent: roomMessagesSent.rows,
      roomSelections: roomSelections.rows,
      blockedAccounts: blockedAccounts.rows,
      reportsSubmitted: reportsSubmitted.rows,
      supportRequests: supportRequests.rows,
      notifications: notifications.rows,
    };
  }

  @Get('notifications')
  async notifications(@Headers('authorization') authorization?: string) {
    const response = await this.social.notifications(await this.userId(authorization));
    const messageTypes = new Set(['message', 'private_message', 'room_message']);
    const notifications = (response.notifications ?? []).filter(
      (item: any) => !messageTypes.has(item.type?.toString() ?? ''),
    );
    const unread = notifications.filter((item: any) => item.read_at == null).length;
    return { ...response, notifications, unread };
  }

  @Post('notifications/:notificationId/read')
  async readNotification(
    @Headers('authorization') authorization: string | undefined,
    @Param('notificationId') notificationId: string,
  ) {
    const userId = await this.userId(authorization);
    const result = await this.infra.db.query<{ id: string; read_at: Date }>(
      `update notifications
       set read_at=coalesce(read_at,now())
       where id=$1 and user_id=$2
       returning id::text, read_at`,
      [notificationId, userId],
    );
    return { ok: true, notification: result.rows[0] ?? null };
  }

  @Post('notifications/read')
  async readNotifications(@Headers('authorization') authorization?: string) {
    return this.social.markNotificationsRead(await this.userId(authorization));
  }
}
