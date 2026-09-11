import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiParam, ApiResponse, ApiTags } from '@nestjs/swagger';
import { ManifestsService } from './manifests.service';
import { RateLimitGuard } from '../common/rate-limit.guard';

@ApiTags('manifests')
@Controller('projects/:projectId')
export class ManifestsController {
  constructor(private readonly manifests: ManifestsService) {}

  // Public, unauthenticated, rate-limited. Consumed by the Flutter client.
  @Get(':platform/:appVersion/manifest.json')
  @UseGuards(RateLimitGuard)
  @ApiOperation({
    summary: 'Get the active manifest for a release',
    description:
      'Public and rate-limited (100 req/min per IP). Cached 60s. When storage is private (the default) `manifest.bundle.url` is a short-lived presigned download URL generated per request; it is excluded from the signature.',
  })
  @ApiParam({ name: 'platform', enum: ['android', 'ios', 'macos', 'linux', 'windows', 'web'] })
  @ApiParam({ name: 'appVersion', example: '1.0.0' })
  @ApiResponse({
    status: 200,
    description: 'The active manifest, or `{ updateAvailable: false }` when none is published.',
    schema: {
      example: {
        updateAvailable: true,
        manifest: {
          schemaVersion: 1,
          bundle: {
            url: 'https://s3.example.com/…?X-Amz-Signature=…',
            sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            size: 123456,
          },
        },
      },
    },
  })
  @ApiResponse({ status: 429, description: 'Rate limit exceeded (100 req/min per IP).' })
  getManifest(
    @Param('projectId') projectId: string,
    @Param('platform') platform: string,
    @Param('appVersion') appVersion: string,
  ) {
    return this.manifests.getActiveManifest(projectId, platform, appVersion);
  }
}
