# Server tests

## Unit tests

Pure, fully mocked (no database or Redis). Run from `apps/hot_updates_server`:

```bash
npm test
```

## End-to-end tests

`test/*.e2e-spec.ts` boot the full Nest app on an ephemeral port and exercise
the real request pipeline (guards + validation). They require a live Postgres
and Redis and use the native `fetch` (no supertest dependency).

```bash
# 1. Start infra (loopback-only dev credentials)
docker compose up -d db redis

# 2. Apply the schema to the test database
npm run prisma:deploy      # or: npm run prisma:push

# 3. Run the e2e suite
npm run test:e2e
```

`test/setup-e2e.ts` supplies loopback defaults for `DATABASE_URL` / `REDIS_URL`
and dummy `S3_*` values (object storage is never called — publish/rollback are
pure DB + Redis, and patches are seeded directly via Prisma). Override
`DATABASE_URL` / `REDIS_URL` in the environment to target a different instance.

Coverage:

- `manifest-rollback.e2e-spec.ts` — manifest selection (active patch, highest
  number) and rollback changing the served manifest, including Redis cache
  invalidation.
- `devices.e2e-spec.ts` — device registration, installation recording
  (advancing `device.activePatch`), and event ingestion.
