import { IsIn, IsString, Matches } from 'class-validator';

export class CreateReleaseDto {
  @IsString()
  @Matches(/^\d+\.\d+\.\d+/, { message: 'appVersion must be semver-like' })
  appVersion: string;

  @IsIn(['android', 'ios', 'macos', 'linux', 'windows', 'web'])
  platform: string;
}
