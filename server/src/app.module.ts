import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { HealthController } from './health.controller';
import { InfrastructureService } from './infrastructure.service';
import { RoomsGateway } from './rooms.gateway';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['../.env', '.env'],
    }),
  ],
  controllers: [HealthController],
  providers: [InfrastructureService, RoomsGateway],
})
export class AppModule {}
