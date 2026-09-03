import { IsBoolean, IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class AdminUserActionDto {
  @IsIn(['warn', 'ban', 'unban', 'remove_matchmaking'])
  action!: 'warn' | 'ban' | 'unban' | 'remove_matchmaking';

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(8760)
  durationHours?: number;
}

export class AdminRemovePhotoDto {
  @IsString()
  @MaxLength(600)
  photoUrl!: string;
}

export class AdminRoomActionDto {
  @IsString()
  @MaxLength(240)
  reason!: string;
}

export class AdminReportActionDto {
  @IsIn([
    'review',
    'resolve',
    'reject',
    'reopen',
    'warn',
    'ban_24h',
    'ban_7d',
    'ban_30d',
    'ban_permanent',
  ])
  action!:
    | 'review'
    | 'resolve'
    | 'reject'
    | 'reopen'
    | 'warn'
    | 'ban_24h'
    | 'ban_7d'
    | 'ban_30d'
    | 'ban_permanent';

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  note?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

export class AdminReportEvidenceDto {
  @IsString()
  messageId!: string;

  @IsBoolean()
  keyEvidence!: boolean;
}

export class AdminSupportActionDto {
  @IsIn(['reply', 'close', 'reopen', 'set_priority'])
  action!: 'reply' | 'close' | 'reopen' | 'set_priority';

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  response?: string;

  @IsOptional()
  @IsIn(['low', 'normal', 'high'])
  priority?: 'low' | 'normal' | 'high';
}
