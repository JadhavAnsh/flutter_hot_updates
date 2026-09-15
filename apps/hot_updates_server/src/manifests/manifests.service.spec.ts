import { ManifestsService } from './manifests.service';

describe('ManifestsService.getActiveManifest', () => {
  const redis = { get: jest.fn(), setex: jest.fn(), del: jest.fn() };
  const prisma = {
    release: { findUnique: jest.fn() },
    patch: { findFirst: jest.fn() },
  };
  const storage = { getSignedDownloadUrl: jest.fn() };

  const build = (publicAccess: boolean) => {
    const config = {
      get: (key: string) =>
        key === 'storage.publicAccess'
          ? publicAccess
          : key === 'storage.downloadUrlTtlSeconds'
            ? 900
            : undefined,
    };
    return new ManifestsService(
      prisma as any,
      redis as any,
      storage as any,
      config as any,
    );
  };

  beforeEach(() => jest.clearAllMocks());

  it('returns cached value without hitting the db (public mode)', async () => {
    redis.get.mockResolvedValue('{"updateAvailable":true,"manifest":{"x":1}}');
    const r = await build(true).getActiveManifest('p', 'android', '1.0.0');
    expect(r).toEqual({ updateAvailable: true, manifest: { x: 1 } });
    expect(prisma.release.findUnique).not.toHaveBeenCalled();
  });

  it('returns updateAvailable=false when no release, and caches it', async () => {
    redis.get.mockResolvedValue(null);
    prisma.release.findUnique.mockResolvedValue(null);
    const r = await build(true).getActiveManifest('p', 'android', '1.0.0');
    expect(r).toEqual({ updateAvailable: false });
    expect(redis.setex).toHaveBeenCalledWith(
      'manifest:p:android:1.0.0',
      60,
      JSON.stringify({ updateAvailable: false }),
    );
  });

  it('returns the active patch manifest with the stored url in public mode', async () => {
    redis.get.mockResolvedValue(null);
    prisma.release.findUnique.mockResolvedValue({ id: 'r1' });
    prisma.patch.findFirst.mockResolvedValue({
      manifestData: { patch: 4, bundle: { url: 'https://cdn/pub.zip' } },
      bundleKey: 'projects/p/android/1.0.0/patches/x.zip',
    });
    const r = await build(true).getActiveManifest('p', 'android', '1.0.0');
    expect(r).toEqual({
      updateAvailable: true,
      manifest: { patch: 4, bundle: { url: 'https://cdn/pub.zip' } },
    });
    expect(storage.getSignedDownloadUrl).not.toHaveBeenCalled();
  });

  it('private mode replaces bundle.url with a signed url and never caches it', async () => {
    redis.get.mockResolvedValue(null);
    prisma.release.findUnique.mockResolvedValue({ id: 'r1' });
    prisma.patch.findFirst.mockResolvedValue({
      manifestData: { patch: 4, bundle: { url: 'https://cdn/pub.zip', sha256: 'a' } },
      bundleKey: 'projects/p/android/1.0.0/patches/x.zip',
    });
    storage.getSignedDownloadUrl.mockResolvedValue(
      'https://minio/x.zip?X-Amz-Signature=abc',
    );

    const r = await build(false).getActiveManifest('p', 'android', '1.0.0');

    expect(storage.getSignedDownloadUrl).toHaveBeenCalledWith({
      key: 'projects/p/android/1.0.0/patches/x.zip',
      expiresInSeconds: 900,
    });
    expect(r.manifest.bundle.url).toBe('https://minio/x.zip?X-Amz-Signature=abc');
    // sha256 (signed) preserved.
    expect(r.manifest.bundle.sha256).toBe('a');
    // The cached envelope must carry the public url, not the signed one.
    const cached = redis.setex.mock.calls[0][2];
    expect(cached).toContain('https://cdn/pub.zip');
    expect(cached).not.toContain('X-Amz-Signature');
  });

  it('private mode presigns per request on a cache hit via _bundleKey', async () => {
    redis.get.mockResolvedValue(
      JSON.stringify({
        updateAvailable: true,
        manifest: { patch: 4, bundle: { url: 'https://cdn/pub.zip' } },
        _bundleKey: 'projects/p/android/1.0.0/patches/x.zip',
      }),
    );
    storage.getSignedDownloadUrl.mockResolvedValue(
      'https://minio/x.zip?X-Amz-Signature=abc',
    );

    const r = await build(false).getActiveManifest('p', 'android', '1.0.0');

    expect(prisma.release.findUnique).not.toHaveBeenCalled();
    expect(r.manifest.bundle.url).toBe('https://minio/x.zip?X-Amz-Signature=abc');
    expect((r as any)._bundleKey).toBeUndefined();
  });

  it('private mode fails closed when presigning fails', async () => {
    redis.get.mockResolvedValue(null);
    prisma.release.findUnique.mockResolvedValue({ id: 'r1' });
    prisma.patch.findFirst.mockResolvedValue({
      manifestData: { patch: 4, bundle: { url: 'https://cdn/pub.zip' } },
      bundleKey: 'projects/p/android/1.0.0/patches/x.zip',
    });
    storage.getSignedDownloadUrl.mockRejectedValue(new Error('minio down'));

    await expect(
      build(false).getActiveManifest('p', 'android', '1.0.0'),
    ).rejects.toThrow('bundle download URL is temporarily unavailable');
  });
});
