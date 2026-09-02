import { IsBoolean, IsInt, IsString, MaxLength, Min } from 'class-validator';

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
