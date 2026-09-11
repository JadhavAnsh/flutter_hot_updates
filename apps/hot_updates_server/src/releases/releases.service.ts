import {
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { RedisService } from '../cache/redis.service';
import {
  OBJECT_STORAGE,
  ObjectStorageProvider,
} from '../storage/storage.interface';
import { CreateReleaseDto } from './dto/create-release.dto';

@Injectable()
export class ReleasesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorageProvider,
  ) {}

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

  async remove(projectId: string, releaseId: string) {
    const release = await this.findOneOrThrow(projectId, releaseId);

    // Remove every bundle under this release before the DB rows go (Prisma
    // onDelete: Cascade drops the patches + installations).
    await this.storage.deletePrefix(
      `projects/${projectId}/${release.platform}/${release.appVersion}/patches/`,
    );
    await this.prisma.release.delete({ where: { id: releaseId } });

    // Live clients on this platform/version must stop seeing the deleted patch.
    await this.redis
      .del(`manifest:${projectId}:${release.platform}:${release.appVersion}`)
      .catch(() => undefined);

    return { deleted: true, releaseId };
  }
}
