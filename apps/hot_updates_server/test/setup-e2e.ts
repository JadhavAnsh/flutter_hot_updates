// Boot-time environment for e2e tests. Real DATABASE_URL / REDIS_URL come from
// the surrounding environment (`docker compose up db redis` provides the
// loopback defaults below). The S3_* values are dummies: these tests never
// touch object storage — publish/rollback are pure DB + Redis, and patches are
// seeded directly via Prisma — so the storage client is constructed but never
// called over the network.
process.env.DATABASE_URL ??=
  'postgresql://postgres:postgres@localhost:5432/hot_updates';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.ADMIN_TOKEN ??= 'e2e-admin-token';
process.env.S3_ENDPOINT ??= 'http://localhost:9000';
process.env.S3_REGION ??= 'us-west-000';
process.env.S3_ACCESS_KEY_ID ??= 'e2e';
process.env.S3_SECRET_ACCESS_KEY ??= 'e2e';
process.env.S3_BUCKET ??= 'e2e-bucket';
process.env.S3_PUBLIC_BASE_URL ??= 'http://localhost:9000/e2e-bucket';

// Mirror main.ts: Prisma BigInt fields would otherwise throw in JSON.stringify.
(BigInt.prototype as any).toJSON = function () {
  return this.toString();
};
