import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { CreateReleaseDto } from './dto/create-release.dto';

@Injectable()
export class ReleasesService {
  constructor(private readonly prisma: PrismaService) {}

  async create(projectId: string, dto: CreateReleaseDto) {
    const existing = await this.prisma.release.findUnique({
      where: {
        projectId_appVersion_platform: {
          projectId,
          appVersion: dto.appVersion,
          platform: dto.platform,
        },
      },
    });
    if (existing) throw new ConflictException('release already exists');

    return this.prisma.release.create({
      data: {
        projectId,
        appVersion: dto.appVersion,
        platform: dto.platform,
      },
    });
  }

  findAll(projectId: string, platform?: string, appVersion?: string) {
    return this.prisma.release.findMany({
      where: { projectId, platform, appVersion },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOneOrThrow(projectId: string, releaseId: string) {
    const release = await this.prisma.release.findFirst({
      where: { id: releaseId, projectId },
    });
    if (!release) throw new NotFoundException('release not found');
    return release;
  }
}
