import { ConflictException } from '@nestjs/common';
import { PatchesService } from './patches.service';

describe('PatchesService.remove', () => {
  const prisma = {
    patch: { findFirst: jest.fn(), delete: jest.fn() },
    release: { findUnique: jest.fn() },
  };
  const releases = {};
  const redis = { del: jest.fn() };
  const storage = { deleteObject: jest.fn() };

  const svc = new PatchesService(
    prisma as any,
    releases as any,
    redis as any,
    storage as any,
  );

  beforeEach(() => jest.clearAllMocks());

  it('deletes the object and row, and invalidates cache for an active patch', async () => {
    prisma.patch.findFirst.mockResolvedValue({
      id: 'pt1',
      releaseId: 'r1',
      status: 'active',
      bundleKey: 'projects/p/android/1.0.0/patches/x.zip',
    });
    storage.deleteObject.mockResolvedValue(undefined);
    prisma.patch.delete.mockResolvedValue({});
    prisma.release.findUnique.mockResolvedValue({
      platform: 'android',
      appVersion: '1.0.0',
    });

    const r = await svc.remove('p', 'pt1', true);

    expect(storage.deleteObject).toHaveBeenCalledWith(
      'projects/p/android/1.0.0/patches/x.zip',
    );
    expect(prisma.patch.delete).toHaveBeenCalledWith({ where: { id: 'pt1' } });
    expect(redis.del).toHaveBeenCalledWith('manifest:p:android:1.0.0');
    expect(r).toEqual({ deleted: true, patchId: 'pt1' });
  });

  it('refuses to delete the active patch without force', async () => {
    prisma.patch.findFirst.mockResolvedValue({
      id: 'pt1',
      releaseId: 'r1',
      status: 'active',
      bundleKey: 'k',
    });

    await expect(svc.remove('p', 'pt1')).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(prisma.patch.delete).not.toHaveBeenCalled();
    expect(storage.deleteObject).not.toHaveBeenCalled();
  });

  it('deletes an inactive patch without touching the cache', async () => {
    prisma.patch.findFirst.mockResolvedValue({
      id: 'pt2',
      releaseId: 'r1',
      status: 'inactive',
      bundleKey: 'k2',
    });
    storage.deleteObject.mockResolvedValue(undefined);
    prisma.patch.delete.mockResolvedValue({});

    await svc.remove('p', 'pt2');

    expect(prisma.patch.delete).toHaveBeenCalledWith({ where: { id: 'pt2' } });
    expect(redis.del).not.toHaveBeenCalled();
    expect(prisma.release.findUnique).not.toHaveBeenCalled();
  });
});
