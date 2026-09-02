import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { HealthController } from './health.controller';
import { InfrastructureService } from './infrastructure.service';
import { ProfileController } from './profile.controller';
import { ProfileService } from './profile.service';
import { RoomControlController } from './room-control.controller';
import { RoomController } from './room.controller';
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
  ],
  providers: [
    InfrastructureService,
    AuthService,
    ProfileService,
    RoomService,
    SocialService,
    SupportService,
    RoomsGateway,
  ],
})
export class AppModule {}
