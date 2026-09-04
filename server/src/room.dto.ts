import { IsBoolean, IsIn, IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class JoinQueueDto {
  @IsOptional()
  @IsInt()
  @IsIn([15, 30])
  roomDurationMinutes?: number;
}

export class SendRoomMessageDto {
  @IsString()
  @MaxLength(1000)
  body!: string;
}

export class ExtensionVoteDto {
  @IsBoolean()
  vote!: boolean;
}

export class RoomSelectionDto {
  @IsInt()
  @Min(1)
  selectedUserId!: number;
}
