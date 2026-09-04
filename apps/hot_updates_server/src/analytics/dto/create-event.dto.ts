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
  // Mirrors the client's update event stream.
  @IsIn([
    'checking',
    'available',
    'downloading',
    'installed',
    'activated',
    'failed',
  ])
  type: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(256)
  deviceId?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  patchNumber?: number;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  appVersion?: string;

  @IsOptional()
  @IsIn(['android', 'ios', 'macos', 'linux', 'windows', 'web'])
  platform?: string;

  @IsOptional()
  @IsObject()
  payload?: Record<string, any>;
}
