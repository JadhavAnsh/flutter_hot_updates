import { bootE2EApp, E2EApp } from './e2e-app';

// Covers Phase 3 acceptance criteria:
//  - "App can fetch a manifest without admin credentials."
//  - "Rollback changes the active manifest returned to clients."
//  - "Integration tests cover manifest selection and rollback."
//
// Requires Postgres and Redis (docker compose up db redis). Rollback invalidates
// the Redis manifest cache, so a live Redis is part of what this test verifies.
describe('manifest selection and rollback (e2e)', () => {
  let app: E2EApp;
  let projectId: string;
  let apiKey: string;
  let patch1Id: string;

  const platform = 'android';
  const appVersion = '1.0.0';
  const slug = `e2e-manifest-${Date.now()}`;
  const adminToken = process.env.ADMIN_TOKEN as string;

  const manifestPath = () =>
    `/projects/${projectId}/${platform}/${appVersion}/manifest.json`;

  const seedPatch = (releaseId: string, patchNumber: number, status: string) =>
    app.prisma.patch.create({
      data: {
        releaseId,
        patchNumber,
        bundleUrl: `https://example.test/${patchNumber}.zip`,
        bundleSha256: `sha-${patchNumber}`,
        bundleSizeBytes: BigInt(patchNumber),
        manifestData: { schemaVersion: 1, patch: patchNumber, platform, appVersion },
        signature: `sig-${patchNumber}`,
        status,
        ...(status === 'active' ? { publishedAt: new Date() } : {}),
      },
    });

  beforeAll(async () => {
    app = await bootE2EApp();

    // Project creation is the admin path exercised by `hot_updates project create`.
    const created = await app.req('POST', '/projects', {
      token: adminToken,
      body: { name: 'E2E Manifest', slug },
    });
    expect(created.status).toBe(201);
    projectId = created.body.id;
    apiKey = created.body.apiKey;

    const release = await app.prisma.release.create({
      data: { projectId, appVersion, platform, status: 'active' },
    });
    const p1 = await seedPatch(release.id, 1, 'inactive');
    await seedPatch(release.id, 2, 'active');
    patch1Id = p1.id;
  });

  afterAll(async () => {
    if (projectId) {
      await app.prisma.project
        .delete({ where: { id: projectId } })
        .catch(() => undefined);
    }
    await app?.close();
  });

  it('serves the active patch with the highest patch number, unauthenticated', async () => {
    const res = await app.req('GET', manifestPath());
    expect(res.status).toBe(200);
    expect(res.body.updateAvailable).toBe(true);
    expect(res.body.manifest.patch).toBe(2);
  });

  it('rollback flips the active patch and changes the served manifest', async () => {
    const rolled = await app.req(
      'POST',
      `/projects/${projectId}/patches/${patch1Id}/rollback`,
      { token: apiKey },
    );
    expect([200, 201]).toContain(rolled.status);

    const res = await app.req('GET', manifestPath());
    expect(res.status).toBe(200);
    expect(res.body.updateAvailable).toBe(true);
    expect(res.body.manifest.patch).toBe(1);
  });
});
