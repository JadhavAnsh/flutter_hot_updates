import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
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
  @ApiProperty({
    description: 'Device the install was attempted on.',
    example: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    maxLength: 256,
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(256)
  deviceId: string;

  @ApiProperty({
    description: 'The patch the client attempted to install, by manifest patch number.',
    example: 4,
    minimum: 1,
  })
  @IsInt()
  @Min(1)
  patchNumber: number;

  @ApiProperty({
    description: 'Outcome of the install attempt.',
    enum: ['pending', 'success', 'failed'],
    example: 'success',
  })
  @IsIn(['pending', 'success', 'failed'])
  status: string;

  @ApiPropertyOptional({
    description: 'Machine-readable failure reason when `status` is `failed`.',
    example: 'E_CHECKSUM_MISMATCH',
    maxLength: 256,
  })
  @IsOptional()
  @IsString()
  @MaxLength(256)
  errorCode?: string;
}
