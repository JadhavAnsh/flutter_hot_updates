import { ApiProperty } from '@nestjs/swagger';
import {
  IsInt,
  IsNotEmpty,
  IsObject,
  IsPositive,
  IsString,
  Min,
} from 'class-validator';

export class CreatePatchDto {
  @ApiProperty({
    description: 'Monotonic patch number within the release.',
    example: 4,
    minimum: 1,
  })
  @IsInt()
  @Min(1)
  patchNumber: number;

  @ApiProperty({
    description:
      'Full manifest JSON built by the CLI (schema v1). Stored verbatim and served. `bundle.sha256`/`bundle.size` must match the fields below.',
    type: 'object',
    additionalProperties: true,
    example: {
      schemaVersion: 1,
      bundle: { sha256: 'ab12…', size: 123456 },
    },
  })
  @IsObject()
  manifest: Record<string, any>;

  @ApiProperty({
    description: 'SHA-256 of the bundle zip (hex). Must equal `manifest.bundle.sha256`.',
    example: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
  })
  @IsString()
  bundleSha256: string;

  @ApiProperty({
    description: 'Bundle size in bytes. Must equal `manifest.bundle.size`.',
    example: 123456,
    minimum: 1,
  })
  @IsInt()
  @IsPositive()
  bundleSize: number;

  @ApiProperty({
    description:
      'Detached RSA-SHA256 signature over the canonical manifest payload (base64). Required — an unsigned manifest is rejected by verifying clients.',
    example: 'base64signature==',
  })
  @IsString()
  @IsNotEmpty()
  signature: string;
}
