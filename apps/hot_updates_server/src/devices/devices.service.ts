import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { RegisterDeviceDto } from './dto/register-device.dto';

@Injectable()
export class DevicesService {
  constructor(private readonly prisma: PrismaService) {}

  // Idempotent: the Flutter client calls this on every launch, so a repeat
  // registration must update the device's platform/appVersion/activePatch
  // rather than conflict.
  async register(projectId: string, dto: RegisterDeviceDto) {
    try {
      const device = await this.prisma.device.upsert({
        where: {
          projectId_deviceId: { projectId, deviceId: dto.deviceId },
        },
        create: {
          projectId,
          deviceId: dto.deviceId,
          platform: dto.platform,
          appVersion: dto.appVersion,
          activePatch: dto.activePatch ?? 0,
        },
        update: {
          platform: dto.platform,
          appVersion: dto.appVersion,
          ...(dto.activePatch !== undefined
            ? { activePatch: dto.activePatch }
            : {}),
        },
      });
      return { id: device.id, activePatch: device.activePatch };
    } catch (error) {
      // Unknown projectId fails the projects FK; report it as a clean 404
      // instead of a 500 (this endpoint has no API key to pre-validate against).
      if ((error as { code?: string })?.code === 'P2003') {
        throw new NotFoundException('project not found');
      }
      throw error;
    }
  }
}
