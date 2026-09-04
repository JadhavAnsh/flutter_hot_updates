import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { CreateEventDto } from './dto/create-event.dto';

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  // Append-only ingestion of client update events. Aggregation/read views are
  // Phase 5 (dashboard); this only persists the raw events.
  async ingest(projectId: string, dto: CreateEventDto) {
    try {
      const event = await this.prisma.event.create({
        data: {
          projectId,
          deviceId: dto.deviceId ?? null,
          type: dto.type,
          patchNumber: dto.patchNumber ?? null,
          appVersion: dto.appVersion ?? null,
          platform: dto.platform ?? null,
          payload: dto.payload ?? undefined,
        },
      });
      return { id: event.id };
    } catch (error) {
      if ((error as { code?: string })?.code === 'P2003') {
        throw new NotFoundException('project not found');
      }
      throw error;
    }
  }
}
