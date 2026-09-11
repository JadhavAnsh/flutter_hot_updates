import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
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
  @ApiProperty({
    description:
      'Client-generated stable device identifier. Bounded because this endpoint is public and unauthenticated.',
    example: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    maxLength: 256,
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(256)
  deviceId: string;

  @ApiProperty({
    description: 'Device platform.',
    enum: ['android', 'ios', 'macos', 'linux', 'windows', 'web'],
    example: 'android',
  })
  @IsIn(['android', 'ios', 'macos', 'linux', 'windows', 'web'])
  platform: string;

  @ApiProperty({
    description: 'Installed application version (semver-like).',
    example: '1.0.0',
    pattern: '^\\d+\\.\\d+\\.\\d+',
  })
  @IsString()
  @Matches(/^\d+\.\d+\.\d+/, { message: 'appVersion must be semver-like' })
  appVersion: string;

  @ApiPropertyOptional({
    description: 'Patch number the device currently has active, if any.',
    example: 3,
    minimum: 0,
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  activePatch?: number;
}
