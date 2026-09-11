// Boot-time environment for e2e tests. Real DATABASE_URL / REDIS_URL come from
// the surrounding environment (`docker compose up db redis` provides the
// loopback defaults below). The S3_* values default to the bundled MinIO
// (`docker compose up minio createbuckets`): most specs never touch object
// storage (publish/rollback are pure DB + Redis, patches are seeded via
// Prisma), but the storage e2e exercises presigned downloads + prefix deletes
// against a live MinIO, so the defaults point there.
process.env.DATABASE_URL ??=
  'postgresql://postgres:postgres@localhost:5432/hot_updates';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.ADMIN_TOKEN ??= 'e2e-admin-token';
process.env.S3_ENDPOINT ??= 'http://localhost:9000';
process.env.S3_REGION ??= 'us-east-1';
process.env.S3_ACCESS_KEY_ID ??= 'minioadmin';
process.env.S3_SECRET_ACCESS_KEY ??= 'minioadmin';
process.env.S3_BUCKET ??= 'hot-updates-dev';
process.env.S3_PUBLIC_BASE_URL ??= 'http://localhost:9000/hot-updates-dev';

// Mirror main.ts: Prisma BigInt fields would otherwise throw in JSON.stringify.
(BigInt.prototype as any).toJSON = function () {
  return this.toString();
};
