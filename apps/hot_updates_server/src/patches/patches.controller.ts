import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { PatchesService } from './patches.service';
import { CreatePatchDto } from './dto/create-patch.dto';
import { ApiKeyGuard } from '../auth/api-key.guard';

@ApiTags('patches')
@ApiBearerAuth()
@UseGuards(ApiKeyGuard)
@Controller('projects/:projectId')
export class PatchesController {
  constructor(private readonly patches: PatchesService) {}

  @Post('releases/:releaseId/patches')
  create(
    @Param('projectId') projectId: string,
    @Param('releaseId') releaseId: string,
    @Body() dto: CreatePatchDto,
  ) {
    return this.patches.create(projectId, releaseId, dto);
  }

  @Get('releases/:releaseId/patches')
  findAll(
    @Param('projectId') projectId: string,
    @Param('releaseId') releaseId: string,
  ) {
    return this.patches.findAll(projectId, releaseId);
  }

  @Post('patches/:patchId/publish')
  publish(
    @Param('projectId') projectId: string,
    @Param('patchId') patchId: string,
  ) {
    return this.patches.publish(projectId, patchId);
  }

  @Post('patches/:patchId/rollback')
  rollback(
    @Param('projectId') projectId: string,
    @Param('patchId') patchId: string,
  ) {
    return this.patches.rollback(projectId, patchId);
  }
}
