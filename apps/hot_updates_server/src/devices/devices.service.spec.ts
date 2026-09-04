import { NotFoundException } from '@nestjs/common';
import { DevicesService } from './devices.service';

describe('DevicesService.register', () => {
  const prisma = { device: { upsert: jest.fn() } };
  const svc = new DevicesService(prisma as any);

  beforeEach(() => jest.clearAllMocks());

  it('upserts by (projectId, deviceId) and returns id + activePatch', async () => {
    prisma.device.upsert.mockResolvedValue({ id: 'd1', activePatch: 3 });

    const result = await svc.register('p1', {
      deviceId: 'dev-abc',
      platform: 'android',
      appVersion: '1.0.0',
      activePatch: 3,
    });

    expect(result).toEqual({ id: 'd1', activePatch: 3 });
    const args = prisma.device.upsert.mock.calls[0][0];
    expect(args.where).toEqual({
      projectId_deviceId: { projectId: 'p1', deviceId: 'dev-abc' },
    });
    expect(args.create.activePatch).toBe(3);
    expect(args.update.activePatch).toBe(3);
  });

  it('defaults activePatch to 0 on create and omits it from update when absent', async () => {
    prisma.device.upsert.mockResolvedValue({ id: 'd1', activePatch: 0 });

    await svc.register('p1', {
      deviceId: 'dev-abc',
      platform: 'android',
      appVersion: '1.0.0',
    });

    const args = prisma.device.upsert.mock.calls[0][0];
    expect(args.create.activePatch).toBe(0);
    expect('activePatch' in args.update).toBe(false);
  });

  it('maps an unknown-project FK error (P2003) to 404', async () => {
    prisma.device.upsert.mockRejectedValue({ code: 'P2003' });

    await expect(
      svc.register('missing', {
        deviceId: 'dev-abc',
        platform: 'android',
        appVersion: '1.0.0',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
