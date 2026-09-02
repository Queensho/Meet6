import { Body, Controller, Get, Headers, Put } from '@nestjs/common';

import { AuthService } from './auth.service';
import { UpdatePreferencesDto, UpdateProfileDto } from './profile.dto';
import { ProfileService } from './profile.service';

@Controller('me')
export class ProfileController {
  constructor(
    private readonly auth: AuthService,
    private readonly profiles: ProfileService,
  ) {}

  @Get()
  async me(@Headers('authorization') authorization?: string) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.profiles.getMe(userId);
  }

  @Put('profile')
  async updateProfile(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: UpdateProfileDto,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.profiles.updateProfile(userId, body);
  }

  @Put('preferences')
  async updatePreferences(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: UpdatePreferencesDto,
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.profiles.updatePreferences(userId, body);
  }
}
