import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { ProjectsService } from './projects.service';
import { CreateProjectDto } from './dto/create-project.dto';
import { AdminGuard } from '../auth/admin.guard';

@ApiTags('projects')
@ApiBearerAuth('admin-token')
@Controller('projects')
export class ProjectsController {
  constructor(private readonly projects: ProjectsService) {}

  @Post()
  @UseGuards(AdminGuard)
  @ApiOperation({
    summary: 'Create a project',
    description:
      'Creates a project and returns its API key. The `apiKey` is shown once and cannot be retrieved again.',
  })
  @ApiResponse({
    status: 201,
    description: 'Project created. Store `apiKey` — it is not shown again.',
    schema: {
      example: {
        id: 'clr0abc123',
        name: 'My App',
        slug: 'my-app',
        apiKey: 'hu_clr0abc123_a1b2c3d4e5f6',
      },
    },
  })
  @ApiResponse({ status: 401, description: 'Missing or invalid admin token.' })
  @ApiResponse({ status: 409, description: 'A project with that slug already exists.' })
  create(@Body() dto: CreateProjectDto) {
    return this.projects.create(dto);
  }

  @Get()
  @UseGuards(AdminGuard)
  @ApiOperation({ summary: 'List all projects' })
  @ApiResponse({ status: 200, description: 'Array of projects (without API keys).' })
  @ApiResponse({ status: 401, description: 'Missing or invalid admin token.' })
  findAll() {
    return this.projects.findAll();
  }

  @Get(':projectId')
  @UseGuards(AdminGuard)
  @ApiOperation({ summary: 'Get a project by id' })
  @ApiResponse({ status: 200, description: 'The project.' })
  @ApiResponse({ status: 401, description: 'Missing or invalid admin token.' })
  @ApiResponse({ status: 404, description: 'Project not found.' })
  findOne(@Param('projectId') projectId: string) {
    return this.projects.findOne(projectId);
  }

  @Delete(':projectId')
  @UseGuards(AdminGuard)
  @ApiOperation({
    summary: 'Delete a project',
    description:
      'Deletes the project and every bundle under `projects/{projectId}/` in object storage, cascading to releases, patches, installations, devices, and events.',
  })
  @ApiResponse({ status: 200, description: 'Project deleted.', schema: { example: { deleted: true, id: 'clr0abc123' } } })
  @ApiResponse({ status: 401, description: 'Missing or invalid admin token.' })
  @ApiResponse({ status: 404, description: 'Project not found.' })
  remove(@Param('projectId') projectId: string) {
    return this.projects.remove(projectId);
  }
}
