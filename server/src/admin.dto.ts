import { IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

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
