import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { HealthController } from './health.controller';
import { InfrastructureService } from './infrastructure.service';
import { ProfileController } from './profile.controller';
import { ProfileService } from './profile.service';
import { RoomsGateway } from './rooms.gateway';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['../.env', '.env'],
    }),
  ],
  controllers: [HealthController, AuthController, ProfileController],
  providers: [InfrastructureService, RoomsGateway, AuthService, ProfileService],
})
export class AppModule {}
