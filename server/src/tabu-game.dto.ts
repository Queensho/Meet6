import { IsString, MaxLength, MinLength } from 'class-validator';

export class TabuSpeakerMessageDto {
  @IsString()
  @MinLength(1)
  @MaxLength(240)
  text!: string;
}

export class TabuGuessDto {
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  guess!: string;
}
