import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { ReleasesService } from './releases.service';
import { CreateReleaseDto } from './dto/create-release.dto';
import { ApiKeyGuard } from '../auth/api-key.guard';

@ApiTags('releases')
@ApiBearerAuth()
@UseGuards(ApiKeyGuard)
@Controller('projects/:projectId/releases')
export class ReleasesController {
  constructor(private readonly releases: ReleasesService) {}

  @Post()
  create(
    @Param('projectId') projectId: string,
    @Body() dto: CreateReleaseDto,
  ) {
    return this.releases.create(projectId, dto);
  }

  @Get()
  findAll(
    @Param('projectId') projectId: string,
    @Query('platform') platform?: string,
    @Query('appVersion') appVersion?: string,
  ) {
    return this.releases.findAll(projectId, platform, appVersion);
  }
}
