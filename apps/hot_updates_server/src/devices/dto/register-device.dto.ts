import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';

export class RegisterDeviceDto {
  // Client-generated stable device identifier. Bounded because this endpoint is
  // public and unauthenticated.
  @IsString()
  @IsNotEmpty()
  @MaxLength(256)
  deviceId: string;

  @IsIn(['android', 'ios', 'macos', 'linux', 'windows', 'web'])
  platform: string;

  @IsString()
  @Matches(/^\d+\.\d+\.\d+/, { message: 'appVersion must be semver-like' })
  appVersion: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  activePatch?: number;
}
