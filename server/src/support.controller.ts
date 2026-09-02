import { Body, Controller, Get, Headers, Post } from '@nestjs/common';

import { AuthService } from './auth.service';
import { CreateSupportRequestDto } from './support.dto';
import { SupportService } from './support.service';

@Controller('support')
export class SupportController {
  constructor(
    private readonly auth: AuthService,
    private readonly support: SupportService,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  @Post()
  async create(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: CreateSupportRequestDto,
  ) {
    return this.support.create(
      await this.userId(authorization),
      body.topic,
      body.message,
    );
  }

  @Get()
  async list(@Headers('authorization') authorization?: string) {
    return this.support.list(await this.userId(authorization));
  }
}
