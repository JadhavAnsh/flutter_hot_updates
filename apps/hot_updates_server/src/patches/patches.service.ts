import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { ReleasesService } from '../releases/releases.service';
import { RedisService } from '../cache/redis.service';
import {
  OBJECT_STORAGE,
  ObjectStorageProvider,
} from '../storage/storage.interface';
import { CreatePatchDto } from './dto/create-patch.dto';

@Injectable()
export class PatchesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly releases: ReleasesService,
    private readonly redis: RedisService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorageProvider,
  ) {}

  private storageKey(
    projectId: string,
    slug: string,
    platform: string,
    appVersion: string,
    patchNumber: number,
  ): string {
    return `projects/${projectId}/${platform}/${appVersion}/patches/${slug}-${appVersion}-${patchNumber}.zip`;
  }

  private cacheKey(projectId: string, platform: string, appVersion: string) {
    return `manifest:${projectId}:${platform}:${appVersion}`;
  }

  async create(projectId: string, releaseId: string, dto: CreatePatchDto) {
    const release = await this.releases.findOneOrThrow(projectId, releaseId);
    const project = await this.prisma.project.findUnique({
      where: { id: projectId },
    });

    const existing = await this.prisma.patch.findUnique({
      where: {
        releaseId_patchNumber: { releaseId, patchNumber: dto.patchNumber },
      },
    });
    // A `pending` patch never finished uploading and was never served, so a
    // retry may replace it. Published patches are immutable and still conflict.
    if (existing && existing.status !== 'pending') {
      throw new ConflictException('patch number already exists');
    }

    const key = this.storageKey(
      projectId,
      project.slug,
      release.platform,
      release.appVersion,
      dto.patchNumber,
    );
    const bundleUrl = this.storage.getPublicUrl(key);

    const signedBundle = (dto.manifest.bundle ?? {}) as Record<string, any>;
    if (
      typeof signedBundle.sha256 !== 'string' ||
      signedBundle.sha256.toLowerCase() !== dto.bundleSha256.toLowerCase() ||
      Number(signedBundle.size) !== dto.bundleSize
    ) {
      throw new BadRequestException(
        'manifest.bundle sha256/size must match bundleSha256/bundleSize',
      );
    }

    // Only bundle.url is rewritten to point at the real object-store URL, and
    // bundle.url is excluded from the signed payload, so the manifest signature
    // stays valid. sha256/size are signed and must be left untouched.
    const manifest = {
      ...dto.manifest,
      bundle: { ...signedBundle, url: bundleUrl },
    };

    const patch = await this.createPatchRow(
      releaseId,
      dto,
      bundleUrl,
      manifest,
    );

    const uploadUrl = await this.storage.getSignedUploadUrl({
      key,
      contentType: 'application/zip',
      expiresInSeconds: 900,
    });

    return { patchId: patch.id, uploadUrl, bundleUrl };
  }

  // Replaces a leftover `pending` row so a failed upload does not burn the patch
  // number, and maps a concurrent insert (P2002) to 409 instead of a 500.
  private async createPatchRow(
    releaseId: string,
    dto: CreatePatchDto,
    bundleUrl: string,
    manifest: Record<string, any>,
  ) {
    await this.prisma.patch.deleteMany({
      where: { releaseId, patchNumber: dto.patchNumber, status: 'pending' },
    });

    try {
      return await this.prisma.patch.create({
        data: {
          releaseId,
          patchNumber: dto.patchNumber,
          bundleUrl,
          bundleSha256: dto.bundleSha256,
          bundleSizeBytes: BigInt(dto.bundleSize),
          manifestData: manifest,
          signature: dto.signature,
          status: 'pending',
        },
      });
    } catch (error) {
      if ((error as { code?: string })?.code === 'P2002') {
        throw new ConflictException('patch number already exists');
      }
      throw error;
    }
  }

  async publish(projectId: string, patchId: string) {
    const patch = await this.getPatchInProject(projectId, patchId);
    const release = await this.prisma.release.findUnique({
      where: { id: patch.releaseId },
    });

    // Activate this patch, deactivate all siblings in the same release.
    await this.prisma.$transaction([
      this.prisma.patch.updateMany({
        where: { releaseId: patch.releaseId, status: 'active' },
        data: { status: 'inactive' },
      }),
      this.prisma.patch.update({
        where: { id: patchId },
        data: { status: 'active', publishedAt: new Date() },
      }),
    ]);

    await this.invalidate(projectId, release.platform, release.appVersion);
    return { status: 'active', patchId, bundleUrl: patch.bundleUrl };
  }

  async rollback(projectId: string, patchId: string) {
    const patch = await this.getPatchInProject(projectId, patchId);
    const release = await this.prisma.release.findUnique({
      where: { id: patch.releaseId },
    });

    await this.prisma.$transaction([
      this.prisma.patch.updateMany({
        where: { releaseId: patch.releaseId, status: 'active' },
        data: { status: 'inactive' },
      }),
      this.prisma.patch.update({
        where: { id: patchId },
        data: { status: 'active' },
      }),
    ]);

    await this.invalidate(projectId, release.platform, release.appVersion);
    return { status: 'active', patchId };
  }

  findAll(projectId: string, releaseId: string) {
    return this.prisma.patch.findMany({
      where: { releaseId, release: { projectId } },
      orderBy: { patchNumber: 'desc' },
      select: {
        id: true,
        patchNumber: true,
        status: true,
        bundleUrl: true,
        createdAt: true,
        publishedAt: true,
      },
    });
  }

  private async getPatchInProject(projectId: string, patchId: string) {
    const patch = await this.prisma.patch.findFirst({
      where: { id: patchId, release: { projectId } },
    });
    if (!patch) throw new NotFoundException('patch not found');
    return patch;
  }

  private async invalidate(
    projectId: string,
    platform: string,
    appVersion: string,
  ) {
    await this.redis.del(this.cacheKey(projectId, platform, appVersion));
  }
}
