import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { ManifestsService } from './manifests.service';
import { RateLimitGuard } from '../common/rate-limit.guard';

@ApiTags('manifests')
@Controller('projects/:projectId')
export class ManifestsController {
  constructor(private readonly manifests: ManifestsService) {}

  // Public, unauthenticated, rate-limited. Consumed by the Flutter client.
  @Get(':platform/:appVersion/manifest.json')
  @UseGuards(RateLimitGuard)
  getManifest(
    @Param('projectId') projectId: string,
    @Param('platform') platform: string,
    @Param('appVersion') appVersion: string,
  ) {
    return this.manifests.getActiveManifest(projectId, platform, appVersion);
  }
}
