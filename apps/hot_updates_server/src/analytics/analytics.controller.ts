import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { AnalyticsService } from './analytics.service';
import { CreateEventDto } from './dto/create-event.dto';
import { RateLimitGuard } from '../common/rate-limit.guard';

@ApiTags('analytics')
@Controller('projects/:projectId')
export class AnalyticsController {
  constructor(private readonly analytics: AnalyticsService) {}

  // Public, unauthenticated, rate-limited. Called by the Flutter client to
  // report update lifecycle events.
  @Post('events')
  @UseGuards(RateLimitGuard)
  @ApiOperation({
    summary: 'Ingest an update event',
    description:
      'Public and rate-limited (100 req/min per IP). Records a single update-lifecycle event.',
  })
  @ApiResponse({ status: 201, description: 'Event ingested.' })
  @ApiResponse({ status: 429, description: 'Rate limit exceeded (100 req/min per IP).' })
  ingest(@Param('projectId') projectId: string, @Body() dto: CreateEventDto) {
    return this.analytics.ingest(projectId, dto);
  }
}
