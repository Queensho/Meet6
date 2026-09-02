import { IsString, MaxLength, MinLength } from 'class-validator';

export class CreateSupportRequestDto {
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  topic!: string;

  @IsString()
  @MinLength(5)
  @MaxLength(2000)
  message!: string;
}
