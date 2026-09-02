import { Body, Controller, Delete, Get, Headers, Post } from '@nestjs/common';

import { AuthService } from './auth.service';
import { RegisterPushDeviceDto, UnregisterPushDeviceDto } from './push.dto';
import { PushService } from './push.service';

@Controller('push')
export class PushController {
  constructor(
    private readonly auth: AuthService,
    private readonly push: PushService,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  @Get('status')
  async status(@Headers('authorization') authorization?: string) {
    return this.push.status(await this.userId(authorization));
  }

  @Post('devices')
  async register(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: RegisterPushDeviceDto,
  ) {
    return this.push.registerDevice(
      await this.userId(authorization),
      body.token,
      body.platform,
      body.appInstanceId,
    );
  }

  @Delete('devices')
  async unregister(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: UnregisterPushDeviceDto,
  ) {
    return this.push.unregisterDevice(await this.userId(authorization), body.token);
  }
}
