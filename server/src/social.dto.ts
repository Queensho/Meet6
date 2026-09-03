import { IsBoolean, IsOptional, IsString, MaxLength } from 'class-validator';

export class SendPrivateMessageDto {
  @IsString()
  @MaxLength(2000)
  body!: string;
}

export class ReportUserDto {
  @IsString()
  @MaxLength(120)
  reason!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  detail?: string;

  @IsOptional()
  @IsString()
  roomId?: string;

  @IsOptional()
  @IsString()
  matchId?: string;
}

export class UpdateSettingsDto {
  @IsOptional() @IsBoolean() notificationsEnabled?: boolean;
  @IsOptional() @IsBoolean() roomReminders?: boolean;
  @IsOptional() @IsBoolean() showOnline?: boolean;
  @IsOptional() @IsBoolean() preciseLocation?: boolean;
  @IsOptional() @IsBoolean() vibration?: boolean;
}
