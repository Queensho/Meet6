import { IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterPushDeviceDto {
  @IsString()
  @MinLength(16)
  @MaxLength(4096)
  token!: string;

  @IsString()
  @IsIn(['android', 'ios', 'web'])
  platform!: 'android' | 'ios' | 'web';

  @IsOptional()
  @IsString()
  @MaxLength(160)
  appInstanceId?: string;
}

export class UnregisterPushDeviceDto {
  @IsString()
  @MinLength(16)
  @MaxLength(4096)
  token!: string;
}
