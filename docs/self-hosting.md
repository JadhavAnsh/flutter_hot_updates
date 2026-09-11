# Self-Hosting

The self-hosted stack (Phase 3):

- NestJS API (`apps/hot_updates_server`)
- PostgreSQL database
- Redis (manifest cache + rate limiting)
- S3-compatible object storage: MinIO for local dev, Backblaze B2 in production
- Cloudflare CDN (optional) in front of public bundle URLs

Storage goes through one S3-compatible abstraction. Locally, a bundled MinIO
container provides it; in production, point the same `S3_*` variables at
Backblaze B2 (or any S3-compatible service). Buckets are **private by default**:
clients receive short-lived presigned download URLs injected into the manifest,
so the bucket never needs public read access. Set `S3_PUBLIC_ACCESS=true` only
if you intentionally serve bundles from a public CDN bucket.

## Quick start (local)

```bash
cd apps/hot_updates_server
cp .env.example .env          # ADMIN_TOKEN; S3_* default to the bundled MinIO
docker compose up --build
```

This starts `api` (port 3000), `db` (PostgreSQL 16), `redis`, `minio` (S3 API
on 9000, console on 9001), and a one-shot `createbuckets` job that creates the
`hot-updates-dev` bucket and leaves it private. With no `S3_*` overrides in your
environment, `api` talks to MinIO automatically (`minioadmin`/`minioadmin`).

To run only the infrastructure (e.g. for tests or `npm run start:dev` on the
host):

```bash
docker compose up -d db redis minio createbuckets
```

Apply the schema once the DB is up:

```bash
docker compose exec api npm run prisma:deploy
```

`prisma:deploy` (`prisma migrate deploy`) applies the committed migrations in
`prisma/migrations/`. If you have an existing database that was created with the
old `prisma db push` flow, baseline it once so `deploy` treats the initial
migration as already applied:

```bash
docker compose exec api npx prisma migrate resolve --applied 0_init
```

`db` and `redis` are published on `127.0.0.1` only — they use dev credentials
(and Redis has no password), so do not expose them to a network.

Health check:

```bash
curl http://localhost:3000/v1/health
```

## Environment variables

```text
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/hot_updates
REDIS_URL=redis://localhost:6379
S3_ENDPOINT=https://s3.us-west-000.backblazeb2.com
S3_REGION=us-west-000
S3_ACCESS_KEY_ID=
S3_SECRET_ACCESS_KEY=
S3_BUCKET=hot-updates-dev
S3_PUBLIC_BASE_URL=https://f000.backblazeb2.com/file/hot-updates-dev
S3_PUBLIC_ACCESS=false           # true only for a public CDN bucket
S3_DOWNLOAD_URL_TTL=900          # presigned download URL lifetime (seconds)
ADMIN_TOKEN=change_me            # guards POST /v1/projects
PORT=3000
TRUST_PROXY_HOPS=0               # set to the number of proxies in front of the API
```

All of the above except `S3_REGION`, `S3_PUBLIC_ACCESS`, `S3_DOWNLOAD_URL_TTL`,
`PORT` and `TRUST_PROXY_HOPS` are required — the API refuses to boot with any of
them unset.

With `S3_PUBLIC_ACCESS=false` (the default), the bucket stays private and each
served manifest carries a presigned download URL valid for `S3_DOWNLOAD_URL_TTL`
seconds; presigned URLs are computed per request and never cached. With
`S3_PUBLIC_ACCESS=true`, the manifest instead serves the stored
`S3_PUBLIC_BASE_URL`-based URL and the bucket must allow public reads.

Behind a CDN or reverse proxy, set `TRUST_PROXY_HOPS` to the number of trusted
hops (Cloudflare alone: `1`). Otherwise `req.ip` is the proxy's address and the
per-IP rate limiter throttles all clients as one.

`S3_PUBLIC_BASE_URL` is what gets written into served manifests **when
`S3_PUBLIC_ACCESS=true`**, so point it at your CDN if you have one in front of
B2. In the default private mode it is used only as the object's canonical
location; clients download via the presigned URL instead.

The client package also supports static manifest hosting, so developers can try
the MVP without running the backend at all — see the API reference below for the
dynamic path.
