import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { CreateInstallationDto } from './dto/create-installation.dto';

@Injectable()
export class InstallationsService {
  constructor(private readonly prisma: PrismaService) {}

  // Records the outcome of a client install attempt. The client only knows its
  // own device id and the manifest patch number, so the device (which carries
  // platform/appVersion) is resolved first, then its release, then the patch.
  async record(projectId: string, dto: CreateInstallationDto) {
    const device = await this.prisma.device.findUnique({
      where: { projectId_deviceId: { projectId, deviceId: dto.deviceId } },
    });
    if (!device) throw new NotFoundException('device not registered');

    const release = await this.prisma.release.findUnique({
      where: {
        projectId_appVersion_platform: {
          projectId,
          appVersion: device.appVersion,
          platform: device.platform,
        },
      },
    });
    if (!release) throw new NotFoundException('release not found for device');

    const patch = await this.prisma.patch.findUnique({
      where: {
        releaseId_patchNumber: {
          releaseId: release.id,
          patchNumber: dto.patchNumber,
        },
      },
    });
    if (!patch) throw new NotFoundException('patch not found');

    const create = this.prisma.installation.create({
      data: {
        deviceId: device.id,
        patchId: patch.id,
        status: dto.status,
        errorCode: dto.errorCode ?? null,
      },
    });

    // A successful install is the device's new active patch; keep both writes
    // atomic so device.activePatch never disagrees with a recorded success.
    if (dto.status === 'success') {
      const [installation] = await this.prisma.$transaction([
        create,
        this.prisma.device.update({
          where: { id: device.id },
          data: { activePatch: dto.patchNumber },
        }),
      ]);
      return { id: installation.id, status: installation.status };
    }

    const installation = await create;
    return { id: installation.id, status: installation.status };
  }
}
