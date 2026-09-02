import { ManifestsService } from './manifests.service';

describe('ManifestsService.getActiveManifest', () => {
  const redis = { get: jest.fn(), setex: jest.fn(), del: jest.fn() };
  const prisma = {
    release: { findUnique: jest.fn() },
    patch: { findFirst: jest.fn() },
  };
  const svc = new ManifestsService(prisma as any, redis as any);

  beforeEach(() => jest.clearAllMocks());

  it('returns cached value without hitting the db', async () => {
    redis.get.mockResolvedValue('{"updateAvailable":true,"manifest":{"x":1}}');
    const r = await svc.getActiveManifest('p', 'android', '1.0.0');
    expect(r).toEqual({ updateAvailable: true, manifest: { x: 1 } });
    expect(prisma.release.findUnique).not.toHaveBeenCalled();
  });

  it('returns updateAvailable=false when no release, and caches it', async () => {
    redis.get.mockResolvedValue(null);
    prisma.release.findUnique.mockResolvedValue(null);
    const r = await svc.getActiveManifest('p', 'android', '1.0.0');
    expect(r).toEqual({ updateAvailable: false });
    expect(redis.setex).toHaveBeenCalledWith(
      'manifest:p:android:1.0.0',
      60,
      JSON.stringify({ updateAvailable: false }),
    );
  });

  it('returns the active patch manifest', async () => {
    redis.get.mockResolvedValue(null);
    prisma.release.findUnique.mockResolvedValue({ id: 'r1' });
    prisma.patch.findFirst.mockResolvedValue({ manifestData: { patch: 4 } });
    const r = await svc.getActiveManifest('p', 'android', '1.0.0');
    expect(r).toEqual({ updateAvailable: true, manifest: { patch: 4 } });
  });
});
