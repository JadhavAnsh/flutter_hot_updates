import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../database/prisma.service';
import { RedisService } from '../cache/redis.service';
import {
  OBJECT_STORAGE,
  ObjectStorageProvider,
} from '../storage/storage.interface';

const CACHE_TTL_SECONDS = 60;

@Injectable()
export class ManifestsService {
  private readonly logger = new Logger(ManifestsService.name);
  private readonly publicAccess: boolean;
  private readonly downloadUrlTtlSeconds: number;

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorageProvider,
    config: ConfigService,
  ) {
    this.publicAccess = config.get<boolean>('storage.publicAccess') ?? false;
    this.downloadUrlTtlSeconds =
      config.get<number>('storage.downloadUrlTtlSeconds') ?? 900;
  }

  async getActiveManifest(
    projectId: string,
    platform: string,
    appVersion: string,
  ) {
    const cacheKey = `manifest:${projectId}:${platform}:${appVersion}`;

    // The cache is best-effort: Postgres holds everything needed to answer, so a
    // Redis outage must not fail public update checks.
    const cached = await this.readCache(cacheKey);
    if (cached) return this.withDownloadUrl(JSON.parse(cached));

    const release = await this.prisma.release.findUnique({
      where: {
        projectId_appVersion_platform: { projectId, appVersion, platform },
      },
    });

    // Envelope cached in Redis. _bundleKey lets us presign a fresh download URL
    // per request without ever caching a (time-limited) signed URL.
    let envelope: Record<string, any> = { updateAvailable: false };

    if (release) {
      const patch = await this.prisma.patch.findFirst({
        where: { releaseId: release.id, status: 'active' },
        orderBy: { patchNumber: 'desc' },
      });
      if (patch) {
        envelope = {
          updateAvailable: true,
          manifest: patch.manifestData,
          _bundleKey: patch.bundleKey ?? undefined,
        };
      }
    }

    await this.writeCache(cacheKey, JSON.stringify(envelope));
    return this.withDownloadUrl(envelope);
  }

  // Presign a short-lived download URL per request when the bucket is private,
  // then strip the internal _bundleKey before returning to the client. Signed
  // URLs are therefore never cached — only DB/JSON data is.
  private async withDownloadUrl(envelope: Record<string, any>) {
    const { _bundleKey, ...response } = envelope;

    if (this.publicAccess || !_bundleKey || !response.manifest) {
      return response;
    }

    try {
      const url = await this.storage.getSignedDownloadUrl({
        key: _bundleKey,
        expiresInSeconds: this.downloadUrlTtlSeconds,
      });
      return {
        ...response,
        manifest: {
          ...response.manifest,
          bundle: { ...(response.manifest.bundle ?? {}), url },
        },
      };
    } catch (error) {
      // Fail open to the stored public URL rather than break update checks.
      this.logger.warn(`presign download url failed for ${_bundleKey}: ${error}`);
      return response;
    }
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
