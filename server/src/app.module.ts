import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { AdminController } from './admin.controller';
import { AdminGovernanceService } from './admin-governance.service';
import { AdminMatchService } from './admin-match.service';
import { AdminReportService } from './admin-report.service';
import { AdminRoomService } from './admin-room.service';
import { AdminSafetyService } from './admin-safety.service';
import { AdminService } from './admin.service';
import { AdminSettingsService } from './admin-settings.service';
import { AdminSupportService } from './admin-support.service';
import { AppConfigController } from './app-config.controller';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { BillingController } from './billing.controller';
import { BillingService } from './billing.service';
import { ContentSafetyService } from './content-safety.service';
import { HealthController } from './health.controller';
import { InfrastructureService } from './infrastructure.service';
import { MatchmakingSchedulerService } from './matchmaking-scheduler.service';
import { PrivateMessageGateway } from './private-message.gateway';
import { ProfileController } from './profile.controller';
import { ProfileService } from './profile.service';
import { PushController } from './push.controller';
import { PushService } from './push.service';
import { ReportService } from './report.service';
import { RoomControlController } from './room-control.controller';
import { RoomController } from './room.controller';
import { RoomMessageService } from './room-message.service';
import { RoomService } from './room.service';
import { RoomsGateway } from './rooms.gateway';
import { RuntimeSettingsService } from './runtime-settings.service';
import { SocialController } from './social.controller';
import { SocialService } from './social.service';
import { SupportController } from './support.controller';
import { SupportService } from './support.service';
import { VoiceRoomController } from './voice-room.controller';
import { VoiceRoomService } from './voice-room.service';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['../.env', '.env'],
    }),
  ],
  controllers: [
    HealthController,
    AppConfigController,
    AuthController,
    ProfileController,
    BillingController,
    RoomController,
    VoiceRoomController,
    RoomControlController,
    SocialController,
    SupportController,
    PushController,
    AdminController,
  ],
  providers: [
    InfrastructureService,
    RuntimeSettingsService,
    ContentSafetyService,
    AuthService,
    ProfileService,
    BillingService,
    RoomService,
    VoiceRoomService,
    RoomMessageService,
    SocialService,
    ReportService,
    SupportService,
    PushService,
    RoomsGateway,
    PrivateMessageGateway,
    MatchmakingSchedulerService,
    AdminService,
    AdminRoomService,
    AdminMatchService,
    AdminReportService,
    AdminSupportService,
    AdminGovernanceService,
    AdminSettingsService,
    AdminSafetyService,
  ],
})
export class AppModule {}
