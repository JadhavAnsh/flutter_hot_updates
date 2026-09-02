import {
  IsInt,
  IsNotEmpty,
  IsObject,
  IsPositive,
  IsString,
  Min,
} from 'class-validator';

export class CreatePatchDto {
  @IsInt()
  @Min(1)
  patchNumber: number;

  // Full manifest JSON built by the CLI (schema v1). Stored verbatim and served.
  @IsObject()
  manifest: Record<string, any>;

  @IsString()
  bundleSha256: string;

  @IsInt()
  @IsPositive()
  bundleSize: number;

  // Detached RSA-SHA256 signature over the canonical manifest payload. Required:
  // an empty signature would publish a patch every verifying client refuses.
  @IsString()
  @IsNotEmpty()
  signature: string;
}
