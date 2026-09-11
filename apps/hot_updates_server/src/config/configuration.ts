// Config that the app cannot run without. Validated at load time so a
// misconfigured deploy fails at boot instead of at the first request that
// happens to need the value (e.g. an S3 call with undefined credentials).
const REQUIRED_ENV = [
  'DATABASE_URL',
  'ADMIN_TOKEN',
  'S3_ENDPOINT',
  'S3_ACCESS_KEY_ID',
  'S3_SECRET_ACCESS_KEY',
  'S3_BUCKET',
  'S3_PUBLIC_BASE_URL',
];

function assertRequiredEnv(): void {
  const missing = REQUIRED_ENV.filter((name) => !process.env[name]?.trim());
  if (missing.length > 0) {
    throw new Error(
      `missing required environment variables: ${missing.join(', ')}`,
    );
  }
}

export default () => {
  assertRequiredEnv();

  return {
    port: parseInt(process.env.PORT, 10) || 3000,
    adminToken: process.env.ADMIN_TOKEN,
    database: {
      url: process.env.DATABASE_URL,
    },
    redis: {
      url: process.env.REDIS_URL || 'redis://localhost:6379',
    },
    storage: {
      endpoint: process.env.S3_ENDPOINT,
      region: process.env.S3_REGION || 'us-west-000',
      accessKeyId: process.env.S3_ACCESS_KEY_ID,
      secretAccessKey: process.env.S3_SECRET_ACCESS_KEY,
      bucket: process.env.S3_BUCKET,
      publicBaseUrl: process.env.S3_PUBLIC_BASE_URL,
      // Private by default: clients get short-lived presigned download URLs
      // unless the bucket is intentionally configured for public CDN access.
      publicAccess: process.env.S3_PUBLIC_ACCESS === 'true',
      downloadUrlTtlSeconds: parseInt(process.env.S3_DOWNLOAD_URL_TTL, 10) || 900,
    },
  };
};
