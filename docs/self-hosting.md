# Self-Hosting

The self-hosted stack (Phase 3):

- NestJS API (`apps/hot_updates_server`)
- PostgreSQL database
- Redis (manifest cache + rate limiting)
- Backblaze B2 for object storage (local dev and production), via its S3-compatible API
- Cloudflare CDN (optional) in front of public bundle URLs

Storage uses Backblaze B2 in every environment — local dev just points at a
separate bucket (e.g. `hot-updates-dev`). There is no MinIO container.

## Quick start (local)

```bash
cd apps/hot_updates_server
cp .env.example .env          # fill in your B2 credentials + ADMIN_TOKEN
docker compose up --build
```

This starts three services: `api` (port 3000), `db` (PostgreSQL 16), and
`redis`. Create the schema once the DB is up:

```bash
docker compose exec api npm run prisma:push
```

No migrations are committed yet, so `npm run prisma:deploy`
(`prisma migrate deploy`) would apply nothing and leave the database empty.
`prisma:push` (`prisma db push`) syncs `prisma/schema.prisma` directly. Once an
initial migration exists, switch deploys back to `prisma:deploy`.

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
ADMIN_TOKEN=change_me            # guards POST /v1/projects
PORT=3000
TRUST_PROXY_HOPS=0               # set to the number of proxies in front of the API
```

All of the above except `S3_REGION`, `PORT` and `TRUST_PROXY_HOPS` are required —
the API refuses to boot with any of them unset.

Behind a CDN or reverse proxy, set `TRUST_PROXY_HOPS` to the number of trusted
hops (Cloudflare alone: `1`). Otherwise `req.ip` is the proxy's address and the
per-IP rate limiter throttles all clients as one.

`S3_PUBLIC_BASE_URL` is what gets written into served manifests, so point it at
your CDN if you have one in front of B2.

The client package also supports static manifest hosting, so developers can try
the MVP without running the backend at all — see the API reference below for the
dynamic path.
