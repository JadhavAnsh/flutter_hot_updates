import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsString, Matches } from 'class-validator';

export class CreateReleaseDto {
  @ApiProperty({
    description: 'Semver-like application version this release targets.',
    example: '1.0.0',
    pattern: '^\\d+\\.\\d+\\.\\d+',
  })
  @IsString()
  @Matches(/^\d+\.\d+\.\d+/, { message: 'appVersion must be semver-like' })
  appVersion: string;

  @ApiProperty({
    description: 'Target platform.',
    enum: ['android', 'ios', 'macos', 'linux', 'windows', 'web'],
    example: 'android',
  })
  @IsIn(['android', 'ios', 'macos', 'linux', 'windows', 'web'])
  platform: string;
}
