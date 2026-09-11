import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, Matches } from 'class-validator';

export class CreateProjectDto {
  @ApiProperty({ description: 'Human-readable project name.', example: 'My App' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({
    description: 'URL-safe identifier: lowercase alphanumeric with dashes.',
    example: 'my-app',
    pattern: '^[a-z0-9-]+$',
  })
  @IsString()
  @Matches(/^[a-z0-9-]+$/, {
    message: 'slug must be lowercase alphanumeric with dashes',
  })
  slug: string;
}
