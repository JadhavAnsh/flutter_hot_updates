import { NotFoundException } from '@nestjs/common';
import { InstallationsService } from './installations.service';

describe('InstallationsService.record', () => {
  const prisma = {
    device: { findUnique: jest.fn(), update: jest.fn() },
    release: { findUnique: jest.fn() },
    patch: { findUnique: jest.fn() },
    installation: { create: jest.fn() },
    $transaction: jest.fn(),
  };
  const svc = new InstallationsService(prisma as any);

  const dto = { deviceId: 'dev-abc', patchNumber: 4, status: 'success' };

  beforeEach(() => jest.clearAllMocks());

  it('throws 404 when the device is not registered', async () => {
    prisma.device.findUnique.mockResolvedValue(null);
    await expect(svc.record('p1', dto)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('throws 404 when no release matches the device platform/version', async () => {
    prisma.device.findUnique.mockResolvedValue({
      id: 'd1',
      platform: 'android',
      appVersion: '1.0.0',
    });
    prisma.release.findUnique.mockResolvedValue(null);
    await expect(svc.record('p1', dto)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('throws 404 when the patch number does not exist', async () => {
    prisma.device.findUnique.mockResolvedValue({
      id: 'd1',
      platform: 'android',
      appVersion: '1.0.0',
    });
    prisma.release.findUnique.mockResolvedValue({ id: 'r1' });
    prisma.patch.findUnique.mockResolvedValue(null);
    await expect(svc.record('p1', dto)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('records a success atomically and advances device.activePatch', async () => {
    prisma.device.findUnique.mockResolvedValue({
      id: 'd1',
      platform: 'android',
      appVersion: '1.0.0',
    });
    prisma.release.findUnique.mockResolvedValue({ id: 'r1' });
    prisma.patch.findUnique.mockResolvedValue({ id: 'patch1' });
    prisma.$transaction.mockResolvedValue([
      { id: 'i1', status: 'success' },
      {},
    ]);

    const result = await svc.record('p1', dto);

    expect(result).toEqual({ id: 'i1', status: 'success' });
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(prisma.device.update).toHaveBeenCalledWith({
      where: { id: 'd1' },
      data: { activePatch: 4 },
    });
  });

  it('records a failure without touching device.activePatch', async () => {
    prisma.device.findUnique.mockResolvedValue({
      id: 'd1',
      platform: 'android',
      appVersion: '1.0.0',
    });
    prisma.release.findUnique.mockResolvedValue({ id: 'r1' });
    prisma.patch.findUnique.mockResolvedValue({ id: 'patch1' });
    prisma.installation.create.mockResolvedValue({ id: 'i2', status: 'failed' });

    const result = await svc.record('p1', {
      deviceId: 'dev-abc',
      patchNumber: 4,
      status: 'failed',
      errorCode: 'checksum_mismatch',
    });

    expect(result).toEqual({ id: 'i2', status: 'failed' });
    expect(prisma.$transaction).not.toHaveBeenCalled();
    expect(prisma.device.update).not.toHaveBeenCalled();
  });
});
