import { bootE2EApp, E2EApp } from './e2e-app';

// Covers the Phase 3 acceptance criterion "Devices and installation statuses
// are recorded" (plus event ingestion). Requires Postgres and Redis
// (docker compose up db redis) — the public endpoints run behind the rate-limit
// guard, which reads Redis.
describe('device / installation / event recording (e2e)', () => {
  let app: E2EApp;
  let projectId: string;
  let patchId: string;

  const platform = 'android';
  const appVersion = '1.0.0';
  const deviceId = 'dev-e2e-1';
  const slug = `e2e-devices-${Date.now()}`;
  const adminToken = process.env.ADMIN_TOKEN as string;

  beforeAll(async () => {
    app = await bootE2EApp();

    const created = await app.req('POST', '/projects', {
      token: adminToken,
      body: { name: 'E2E Devices', slug },
    });
    expect(created.status).toBe(201);
    projectId = created.body.id;

    // Installations resolve device -> release (by platform/appVersion) -> patch,
    // so a matching release + patch must exist for a success to be recordable.
    const release = await app.prisma.release.create({
      data: { projectId, appVersion, platform, status: 'active' },
    });
    const patch = await app.prisma.patch.create({
      data: {
        releaseId: release.id,
        patchNumber: 1,
        bundleUrl: 'https://example.test/1.zip',
        bundleSha256: 'sha-1',
        bundleSizeBytes: BigInt(1),
        manifestData: { schemaVersion: 1, patch: 1, platform, appVersion },
        signature: 'sig-1',
        status: 'active',
        publishedAt: new Date(),
      },
    });
    patchId = patch.id;
  });

  afterAll(async () => {
    if (projectId) {
      await app.prisma.project
        .delete({ where: { id: projectId } })
        .catch(() => undefined);
    }
    await app?.close();
  });

  it('registers a device (unauthenticated) and persists the row', async () => {
    const res = await app.req('POST', `/projects/${projectId}/devices`, {
      body: { deviceId, platform, appVersion },
    });
    expect(res.status).toBe(201);
    expect(res.body.activePatch).toBe(0);

    const row = await app.prisma.device.findUnique({
      where: { projectId_deviceId: { projectId, deviceId } },
    });
    expect(row).not.toBeNull();
  });

  it('records a successful installation and advances device.activePatch', async () => {
    const res = await app.req('POST', `/projects/${projectId}/installations`, {
      body: { deviceId, patchNumber: 1, status: 'success' },
    });
    expect(res.status).toBe(201);
    expect(res.body.status).toBe('success');

    const device = await app.prisma.device.findUnique({
      where: { projectId_deviceId: { projectId, deviceId } },
    });
    expect(device?.activePatch).toBe(1);

    const installation = await app.prisma.installation.findFirst({
      where: { deviceId: device!.id, patchId },
    });
    expect(installation?.status).toBe('success');
  });

  it('ingests a lifecycle event', async () => {
    const res = await app.req('POST', `/projects/${projectId}/events`, {
      body: { type: 'installed', deviceId, patchNumber: 1, platform, appVersion },
    });
    expect(res.status).toBe(201);
    expect(res.body.id).toBeDefined();

    const count = await app.prisma.event.count({
      where: { projectId, type: 'installed' },
    });
    expect(count).toBe(1);
  });
});
