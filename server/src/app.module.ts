import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { AdminController } from './admin.controller';
import { AdminMatchService } from './admin-match.service';
import { AdminReportService } from './admin-report.service';
import { AdminRoomService } from './admin-room.service';
import { AdminService } from './admin.service';
import { AdminSupportService } from './admin-support.service';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
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
import { SocialController } from './social.controller';
import { SocialService } from './social.service';
import { SupportController } from './support.controller';
import { SupportService } from './support.service';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['../.env', '.env'],
    }),
  ],
  controllers: [
    HealthController,
    AuthController,
    ProfileController,
    RoomController,
    RoomControlController,
    SocialController,
    SupportController,
    PushController,
    AdminController,
  ],
  providers: [
    InfrastructureService,
    AuthService,
    ProfileService,
    RoomService,
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
  ],
})
export class AppModule {}
