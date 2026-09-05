import { IsInt, IsString, MaxLength, Min } from 'class-validator';

export class SendRoomGiftDto {
  @IsInt()
  @Min(1)
  recipientUserId!: number;

  @IsString()
  @MaxLength(40)
  giftCode!: string;

  @IsString()
  @MaxLength(96)
  clientGiftId!: string;
}
