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
import { PatchesService } from './patches.service';
import { CreatePatchDto } from './dto/create-patch.dto';
import { ApiKeyGuard } from '../auth/api-key.guard';

@ApiTags('patches')
@ApiBearerAuth('api-key')
@UseGuards(ApiKeyGuard)
@Controller('projects/:projectId')
export class PatchesController {
  constructor(private readonly patches: PatchesService) {}

  @Post('releases/:releaseId/patches')
  @ApiOperation({
    summary: 'Create a patch',
    description:
      'Registers a patch and returns a pre-signed `uploadUrl` (15 min TTL) to `PUT` the bundle zip to. `manifest.bundle.sha256`/`size` must match `bundleSha256`/`bundleSize` or the request is rejected.',
  })
  @ApiResponse({
    status: 201,
    description: 'Patch registered. Upload the bundle to `uploadUrl`.',
    schema: {
      example: {
        patchId: 'clr0pat789',
        uploadUrl: 'https://s3.example.com/…?X-Amz-Signature=…',
        bundleUrl: 'https://cdn.example.com/projects/…/patches/my-app-1.0.0-4.zip',
      },
    },
  })
  @ApiResponse({ status: 400, description: 'manifest bundle sha256/size do not match the declared fields.' })
  @ApiResponse({ status: 401, description: 'Missing or invalid project API key.' })
  @ApiResponse({ status: 409, description: 'Patch number already exists (and is not a replaceable pending row).' })
  create(
    @Param('projectId') projectId: string,
    @Param('releaseId') releaseId: string,
    @Body() dto: CreatePatchDto,
  ) {
    return this.patches.create(projectId, releaseId, dto);
  }

  @Get('releases/:releaseId/patches')
  @ApiOperation({ summary: 'List patches for a release' })
  @ApiResponse({ status: 200, description: 'Array of patches, newest first.' })
  @ApiResponse({ status: 401, description: 'Missing or invalid project API key.' })
  findAll(
    @Param('projectId') projectId: string,
    @Param('releaseId') releaseId: string,
  ) {
    return this.patches.findAll(projectId, releaseId);
  }

  @Post('patches/:patchId/publish')
  @ApiOperation({
    summary: 'Publish a patch',
    description: 'Activates the patch, deactivates its siblings, and clears the manifest cache.',
  })
  @ApiResponse({ status: 201, description: 'Patch activated.', schema: { example: { status: 'active', patchId: 'clr0pat789', bundleUrl: 'https://…' } } })
  @ApiResponse({ status: 401, description: 'Missing or invalid project API key.' })
  @ApiResponse({ status: 404, description: 'Patch not found in this project.' })
  publish(
    @Param('projectId') projectId: string,
    @Param('patchId') patchId: string,
  ) {
    return this.patches.publish(projectId, patchId);
  }

  @Post('patches/:patchId/rollback')
  @ApiOperation({ summary: 'Roll back to a patch', description: 'Re-activates the given patch and clears the cache.' })
  @ApiResponse({ status: 201, description: 'Patch re-activated.', schema: { example: { status: 'active', patchId: 'clr0pat789' } } })
  @ApiResponse({ status: 401, description: 'Missing or invalid project API key.' })
  @ApiResponse({ status: 404, description: 'Patch not found in this project.' })
  rollback(
    @Param('projectId') projectId: string,
    @Param('patchId') patchId: string,
  ) {
    return this.patches.rollback(projectId, patchId);
  }

  @Delete('patches/:patchId')
  @ApiOperation({
    summary: 'Delete a patch',
    description:
      'Deletes the patch and its bundle object. Deleting the currently **active** patch is refused with 409 unless `force=true`, to avoid silently breaking live clients.',
  })
  @ApiQuery({
    name: 'force',
    required: false,
    type: Boolean,
    description: 'Set `true` to delete the active patch anyway.',
  })
  @ApiResponse({ status: 200, description: 'Patch deleted.', schema: { example: { deleted: true, patchId: 'clr0pat789' } } })
  @ApiResponse({ status: 401, description: 'Missing or invalid project API key.' })
  @ApiResponse({ status: 404, description: 'Patch not found in this project.' })
  @ApiResponse({ status: 409, description: 'Refusing to delete the active patch without `force=true`.' })
  remove(
    @Param('projectId') projectId: string,
    @Param('patchId') patchId: string,
    @Query('force') force?: string,
  ) {
    return this.patches.remove(projectId, patchId, force === 'true');
  }
}
