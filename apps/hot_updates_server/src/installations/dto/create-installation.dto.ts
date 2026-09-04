import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateInstallationDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(256)
  deviceId: string;

  // The patch the client attempted to install, by manifest patch number.
  @IsInt()
  @Min(1)
  patchNumber: number;

  @IsIn(['pending', 'success', 'failed'])
  status: string;

  @IsOptional()
  @IsString()
  @MaxLength(256)
  errorCode?: string;
}
