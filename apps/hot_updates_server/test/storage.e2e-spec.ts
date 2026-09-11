import { bootE2EApp, E2EApp } from './e2e-app';

// Covers Phase 4 acceptance criteria:
//  - "Uploads are private by default" — the served manifest's bundle.url is a
//    short-lived presigned GET (contains X-Amz-Signature) when S3_PUBLIC_ACCESS
//    is not "true".
//  - Delete flows — removing a release drops its patches so the manifest goes
//    back to updateAvailable:false.
//
// Requires Postgres, Redis, and MinIO with the dev bucket:
//   docker compose up -d db redis minio createbuckets
// The DELETE release path calls storage.deletePrefix against MinIO; presigning
// is a local computation and needs no live object.
describe('storage: private downloads + delete flows (e2e)', () => {
  let app: E2EApp;
  let projectId: string;
  let apiKey: string;
  let releaseId: string;

  const platform = 'android';
  const appVersion = '1.0.0';
  const slug = `e2e-storage-${Date.now()}`;
  const adminToken = process.env.ADMIN_TOKEN as string;

  const manifestPath = () =>
    `/projects/${projectId}/${platform}/${appVersion}/manifest.json`;

  beforeAll(async () => {
    app = await bootE2EApp();

    const created = await app.req('POST', '/projects', {
      token: adminToken,
      body: { name: 'E2E Storage', slug },
    });
    expect(created.status).toBe(201);
    projectId = created.body.id;
    apiKey = created.body.apiKey;

    const release = await app.prisma.release.create({
      data: { projectId, appVersion, platform, status: 'active' },
    });
    releaseId = release.id;

    // Active patch carries a bundleKey so the manifest service presigns its url.
    await app.prisma.patch.create({
      data: {
        releaseId: release.id,
        patchNumber: 1,
        bundleUrl: 'http://localhost:9000/hot-updates-dev/pub.zip',
        bundleKey: `projects/${projectId}/${platform}/${appVersion}/patches/${slug}-${appVersion}-1.zip`,
        bundleSha256: 'sha-1',
        bundleSizeBytes: BigInt(1),
        manifestData: {
          schemaVersion: 1,
          patch: 1,
          platform,
          appVersion,
          bundle: {
            url: 'http://localhost:9000/hot-updates-dev/pub.zip',
            sha256: 'sha-1',
            size: 1,
          },
        },
        signature: 'sig-1',
        status: 'active',
        publishedAt: new Date(),
      },
    });
  });

  afterAll(async () => {
    if (projectId) {
      await app.prisma.project
        .delete({ where: { id: projectId } })
        .catch(() => undefined);
    }
    await app?.close();
  });

  it('serves a presigned download url in private mode', async () => {
    const res = await app.req('GET', manifestPath());
    expect(res.status).toBe(200);
    expect(res.body.updateAvailable).toBe(true);
    // Private-by-default: bundle.url is a short-lived presigned GET.
    expect(res.body.manifest.bundle.url).toContain('X-Amz-Signature');
    // Signed sha256/size are preserved for client verification.
    expect(res.body.manifest.bundle.sha256).toBe('sha-1');
  });

  it('deleting the release makes the manifest report no update', async () => {
    const del = await app.req('DELETE', `/projects/${projectId}/releases/${releaseId}`, {
      token: apiKey,
    });
    expect([200, 204]).toContain(del.status);

    const res = await app.req('GET', manifestPath());
    expect(res.status).toBe(200);
    expect(res.body.updateAvailable).toBe(false);
  });
});
