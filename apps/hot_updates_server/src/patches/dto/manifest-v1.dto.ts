import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';

export class ManifestBundleDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  url?: string;

  @ApiProperty()
  @IsString()
  sha256: string;

  @ApiProperty()
  @IsInt()
  @Min(1)
  size: number;
}

export class ManifestAssetDto {
  @ApiProperty()
  @IsString()
  path: string;

  @ApiProperty()
  @IsString()
  url: string;

  @ApiProperty()
  @IsString()
  sha256: string;
}

export class ManifestV1Dto {
  @ApiProperty({ example: 1 })
  @IsInt()
  schemaVersion: number;

  @ApiProperty()
  @IsString()
  projectId: string;

  @ApiProperty()
  @IsString()
  appVersion: string;

  @ApiProperty()
  @IsInt()
  @Min(0)
  patch: number;

  @ApiProperty()
  @IsString()
  minSupportedAppVersion: string;

  @ApiProperty()
  @IsString()
  platform: string;

  @ApiProperty()
  @IsString()
  createdAt: string;

  @ApiProperty({ type: [ManifestAssetDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ManifestAssetDto)
  assets: ManifestAssetDto[];

  @ApiProperty({ type: 'object', additionalProperties: true })
  @IsObject()
  config: Record<string, unknown>;

  @ApiProperty({ type: ManifestBundleDto })
  @ValidateNested()
  @Type(() => ManifestBundleDto)
  bundle: ManifestBundleDto;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  signature?: string;
}
