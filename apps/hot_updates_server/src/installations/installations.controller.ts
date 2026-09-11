import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { InstallationsService } from './installations.service';
import { CreateInstallationDto } from './dto/create-installation.dto';
import { RateLimitGuard } from '../common/rate-limit.guard';

@ApiTags('installations')
@Controller('projects/:projectId')
export class InstallationsController {
  constructor(private readonly installations: InstallationsService) {}

  // Public, unauthenticated, rate-limited. Called by the Flutter client to
  // report the result of an install attempt.
  @Post('installations')
  @UseGuards(RateLimitGuard)
  @ApiOperation({
    summary: 'Record an install attempt',
    description:
      'Public and rate-limited (100 req/min per IP). Reports the outcome of a patch install.',
  })
  @ApiResponse({ status: 201, description: 'Installation recorded.' })
  @ApiResponse({ status: 429, description: 'Rate limit exceeded (100 req/min per IP).' })
  record(
    @Param('projectId') projectId: string,
    @Body() dto: CreateInstallationDto,
  ) {
    return this.installations.record(projectId, dto);
  }
}
