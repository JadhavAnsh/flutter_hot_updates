import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateEventDto {
  @ApiProperty({
    description: 'Update lifecycle event type. Mirrors the client update event stream.',
    enum: [
      'checking',
      'available',
      'downloading',
      'installed',
      'activated',
      'failed',
    ],
    example: 'installed',
  })
  @IsIn([
    'checking',
    'available',
    'downloading',
    'installed',
    'activated',
    'failed',
  ])
  type: string;

  @ApiPropertyOptional({
    description: 'Device that emitted the event.',
    example: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    maxLength: 256,
  })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(256)
  deviceId?: string;

  @ApiPropertyOptional({
    description: 'Patch number the event relates to.',
    example: 4,
    minimum: 0,
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  patchNumber?: number;

  @ApiPropertyOptional({
    description: 'Application version at the time of the event.',
    example: '1.0.0',
    maxLength: 64,
  })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  appVersion?: string;

  @ApiPropertyOptional({
    description: 'Platform that emitted the event.',
    enum: ['android', 'ios', 'macos', 'linux', 'windows', 'web'],
    example: 'android',
  })
  @IsOptional()
  @IsIn(['android', 'ios', 'macos', 'linux', 'windows', 'web'])
  platform?: string;

  @ApiPropertyOptional({
    description: 'Free-form structured metadata attached to the event.',
    type: 'object',
    additionalProperties: true,
    example: { durationMs: 812 },
  })
  @IsOptional()
  @IsObject()
  payload?: Record<string, any>;
}
