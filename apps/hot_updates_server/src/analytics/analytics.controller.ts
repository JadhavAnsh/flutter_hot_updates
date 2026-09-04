import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
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
  ingest(@Param('projectId') projectId: string, @Body() dto: CreateEventDto) {
    return this.analytics.ingest(projectId, dto);
  }
}
