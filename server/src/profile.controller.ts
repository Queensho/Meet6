import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  Post,
  Put,
  UploadedFiles,
  UseInterceptors,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';

import { AuthService } from './auth.service';
import { UpdatePreferencesDto, UpdateProfileDto } from './profile.dto';
import { ProfileService } from './profile.service';

type UploadedPhoto = {
  buffer: Buffer;
  mimetype: string;
  size: number;
  originalname: string;
};

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

  @Post('photos')
  @UseInterceptors(
    FilesInterceptor('photos', 4, {
      limits: { fileSize: 8 * 1024 * 1024, files: 4 },
    }),
  )
  async uploadPhotos(
    @Headers('authorization') authorization: string | undefined,
    @UploadedFiles() files: UploadedPhoto[],
  ) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    return this.profiles.uploadPhotos(userId, files ?? []);
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

  @Delete()
  async deleteAccount(@Headers('authorization') authorization?: string) {
    const { userId } = await this.auth.userIdFromAuthorization(authorization);
    await this.profiles.deleteAccount(userId);
    await this.auth.revokeAllSessions(userId);
    return { ok: true };
  }
}
