import {
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomBytes } from 'crypto';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../database/prisma.service';
import {
  OBJECT_STORAGE,
  ObjectStorageProvider,
} from '../storage/storage.interface';
import { CreateProjectDto } from './dto/create-project.dto';

@Injectable()
export class ProjectsService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorageProvider,
  ) {}

  async create(dto: CreateProjectDto) {
    const existing = await this.prisma.project.findUnique({
      where: { slug: dto.slug },
    });
    if (existing) throw new ConflictException('slug already exists');

    const secret = randomBytes(24).toString('hex');
    const apiKeyHash = await bcrypt.hash(secret, 10);

    const project = await this.prisma.project.create({
      data: { name: dto.name, slug: dto.slug, apiKeyHash },
    });

    // Cleartext key is shown once; only the hash is stored.
    return {
      id: project.id,
      name: project.name,
      slug: project.slug,
      apiKey: `hu_${project.id}_${secret}`,
    };
  }

  async findAll() {
    return this.prisma.project.findMany({
      select: { id: true, name: true, slug: true, createdAt: true },
    });
  }

  async findOne(id: string) {
    const project = await this.prisma.project.findUnique({ where: { id } });
    if (!project) throw new NotFoundException('project not found');
    return {
      id: project.id,
      name: project.name,
      slug: project.slug,
      publicKey: project.publicKey,
      createdAt: project.createdAt,
    };
  }

  async remove(id: string) {
    const project = await this.prisma.project.findUnique({ where: { id } });
    if (!project) throw new NotFoundException('project not found');

    // Drop all bundles first, then the row. The DB cascade removes releases →
    // patches → installations, devices, and events. Manifest cache keys are per
    // platform/version and expire within their 60s TTL, so stale entries for a
    // now-deleted project are short-lived and harmless.
    await this.storage.deletePrefix(`projects/${id}/`);
    await this.prisma.project.delete({ where: { id } });

    return { deleted: true, id };
  }
}
