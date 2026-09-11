import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiQuery,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { ReleasesService } from './releases.service';
import { CreateReleaseDto } from './dto/create-release.dto';
import { ApiKeyGuard } from '../auth/api-key.guard';

@ApiTags('releases')
@ApiBearerAuth('api-key')
@UseGuards(ApiKeyGuard)
@Controller('projects/:projectId/releases')
export class ReleasesController {
  constructor(private readonly releases: ReleasesService) {}

  @Post()
  @ApiOperation({ summary: 'Create a release' })
  @ApiResponse({ status: 201, description: 'Release created.' })
  @ApiResponse({ status: 401, description: 'Missing or invalid project API key.' })
  @ApiResponse({ status: 409, description: 'A release for that platform/appVersion already exists.' })
  create(@Param('projectId') projectId: string, @Body() dto: CreateReleaseDto) {
    return this.releases.create(projectId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List releases', description: 'Optionally filtered by platform and/or appVersion.' })
  @ApiQuery({ name: 'platform', required: false, enum: ['android', 'ios', 'macos', 'linux', 'windows', 'web'] })
  @ApiQuery({ name: 'appVersion', required: false, example: '1.0.0' })
  @ApiResponse({ status: 200, description: 'Array of releases.' })
  @ApiResponse({ status: 401, description: 'Missing or invalid project API key.' })
  findAll(
    @Param('projectId') projectId: string,
    @Query('platform') platform?: string,
    @Query('appVersion') appVersion?: string,
  ) {
    return this.releases.findAll(projectId, platform, appVersion);
  }

  @Delete(':releaseId')
  @ApiOperation({
    summary: 'Delete a release',
    description:
      'Deletes the release and all its bundles from object storage, cascading to its patches and installations, and invalidates the manifest cache for that platform/appVersion.',
  })
  @ApiResponse({ status: 200, description: 'Release deleted.', schema: { example: { deleted: true, releaseId: 'clr0rel456' } } })
  @ApiResponse({ status: 401, description: 'Missing or invalid project API key.' })
  @ApiResponse({ status: 404, description: 'Release not found in this project.' })
  remove(
    @Param('projectId') projectId: string,
    @Param('releaseId') releaseId: string,
  ) {
    return this.releases.remove(projectId, releaseId);
  }
}
