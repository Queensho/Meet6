import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class UpdateProfileDto {
  @IsOptional() @IsString() @MaxLength(80) displayName?: string;
  @IsOptional() @IsDateString() birthDate?: string;
  @IsOptional() @IsString() @MaxLength(30) gender?: string;
  @IsOptional() @IsString() @MaxLength(240) bio?: string;
  @IsOptional() @IsString() @MaxLength(100) city?: string;
  @IsOptional() @IsString() @MaxLength(100) country?: string;
  @IsOptional() @IsNumber() latitude?: number;
  @IsOptional() @IsNumber() longitude?: number;
  @IsOptional() @IsString() @MaxLength(160) profilePrompt?: string;
  @IsOptional() @IsString() @MaxLength(240) profileAnswer?: string;
  @IsOptional() @IsArray() @IsString({ each: true }) interests?: string[];
  @IsOptional() @IsArray() @IsString({ each: true }) photoUrls?: string[];
  @IsOptional() @IsBoolean() profileCompleted?: boolean;
}

export class UpdatePreferencesDto {
  @IsOptional() @IsString() lookingFor?: string;
  @IsOptional() @IsInt() @Min(18) @Max(65) minAge?: number;
  @IsOptional() @IsInt() @Min(18) @Max(65) maxAge?: number;
  @IsOptional() @IsInt() @Min(1) @Max(500) distanceKm?: number;
  @IsOptional() @IsString() @MaxLength(80) purpose?: string;
}
