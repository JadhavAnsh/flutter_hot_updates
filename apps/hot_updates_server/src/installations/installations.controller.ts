import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
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
  record(
    @Param('projectId') projectId: string,
    @Body() dto: CreateInstallationDto,
  ) {
    return this.installations.record(projectId, dto);
  }
}
