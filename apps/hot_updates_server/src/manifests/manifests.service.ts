import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { RedisService } from '../cache/redis.service';

const CACHE_TTL_SECONDS = 60;

@Injectable()
export class ManifestsService {
  private readonly logger = new Logger(ManifestsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  async getActiveManifest(
    projectId: string,
    platform: string,
    appVersion: string,
  ) {
    const cacheKey = `manifest:${projectId}:${platform}:${appVersion}`;

    // The cache is best-effort: Postgres holds everything needed to answer, so a
    // Redis outage must not fail public update checks.
    const cached = await this.readCache(cacheKey);
    if (cached) return JSON.parse(cached);

    const release = await this.prisma.release.findUnique({
      where: {
        projectId_appVersion_platform: { projectId, appVersion, platform },
      },
    });

    let response: Record<string, any> = { updateAvailable: false };

    if (release) {
      const patch = await this.prisma.patch.findFirst({
        where: { releaseId: release.id, status: 'active' },
        orderBy: { patchNumber: 'desc' },
      });
      if (patch) {
        response = { updateAvailable: true, manifest: patch.manifestData };
      }
    }

    await this.writeCache(cacheKey, JSON.stringify(response));
    return response;
  }

  private async readCache(cacheKey: string): Promise<string | null> {
    try {
      return await this.redis.get(cacheKey);
    } catch (error) {
      this.logger.warn(`manifest cache read failed for ${cacheKey}: ${error}`);
      return null;
    }
  }

  private async writeCache(cacheKey: string, value: string): Promise<void> {
    try {
      await this.redis.setex(cacheKey, CACHE_TTL_SECONDS, value);
    } catch (error) {
      this.logger.warn(`manifest cache write failed for ${cacheKey}: ${error}`);
    }
  }
}
