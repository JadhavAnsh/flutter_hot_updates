import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { ProjectsService } from './projects.service';
import { CreateProjectDto } from './dto/create-project.dto';
import { AdminGuard } from '../auth/admin.guard';

@ApiTags('projects')
@ApiBearerAuth()
@Controller('projects')
export class ProjectsController {
  constructor(private readonly projects: ProjectsService) {}

  @Post()
  @UseGuards(AdminGuard)
  create(@Body() dto: CreateProjectDto) {
    return this.projects.create(dto);
  }

  @Get()
  @UseGuards(AdminGuard)
  findAll() {
    return this.projects.findAll();
  }

  @Get(':projectId')
  @UseGuards(AdminGuard)
  findOne(@Param('projectId') projectId: string) {
    return this.projects.findOne(projectId);
  }
}
