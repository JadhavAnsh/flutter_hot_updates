# Backend API Reference (v0.3)

Base URL: `{host}/v1`. Interactive Swagger docs at `{host}/api`.

## Auth

- **Admin** (`POST/GET /projects`): `Authorization: Bearer {ADMIN_TOKEN}`.
- **Project** (releases, patches): `Authorization: Bearer hu_{projectId}_{secret}`
  — the API key returned once at project creation.
- **Public** (manifest, health): no auth, rate-limited to 100 req/min per IP.

## Public endpoints

### `GET /projects/:projectId/:platform/:appVersion/manifest.json`

Returns the active patch manifest for a release. Cached 60s in Redis.

```json
{ "updateAvailable": false }
```
```json
{ "updateAvailable": true, "manifest": { "schemaVersion": 1, "...": "..." } }
```

When storage is private (`S3_PUBLIC_ACCESS=false`, the default),
`manifest.bundle.url` is a short-lived presigned download URL, generated per
request and never cached (`bundle.url` is excluded from the signature, so this
does not affect verification). With `S3_PUBLIC_ACCESS=true` it is the stored
public URL.

### `GET /health`

```json
{ "status": "ok", "version": "0.3.0", "db": true, "redis": true }
```

## Admin endpoints

### `POST /projects`
Body: `{ "name": "My App", "slug": "my-app" }`
Returns `{ id, name, slug, apiKey }`. **`apiKey` is shown once — store it.**

### `GET /projects` / `GET /projects/:projectId`
List / fetch projects.

### `DELETE /projects/:projectId`
Deletes the project and every bundle under `projects/{projectId}/` in object
storage, cascading to its releases, patches, installations, devices, and events.
Returns `{ deleted, id }`; 404 if the project does not exist.

## Project endpoints (API key)

### `POST /projects/:projectId/releases`
Body: `{ "appVersion": "1.0.0", "platform": "android" }` → release object.
Returns 409 if the release already exists.

### `GET /projects/:projectId/releases?platform=&appVersion=`
List releases.

### `DELETE /projects/:projectId/releases/:releaseId`
Deletes the release and all its bundles from object storage, cascading to its
patches and installations, and invalidates the manifest cache for that
platform/appVersion. Returns `{ deleted, releaseId }`; 404 if not found.

### `POST /projects/:projectId/releases/:releaseId/patches`
Body:
```json
{
  "patchNumber": 4,
  "manifest": { "...": "full manifest JSON" },
  "bundleSha256": "…",
  "bundleSize": 123456,
  "signature": "base64…"
}
```
Returns `{ patchId, uploadUrl, bundleUrl }`. Upload the bundle zip with a plain
`PUT` to `uploadUrl` (pre-signed, 15 min TTL). The backend rewrites
`manifest.bundle.url` to the public `bundleUrl`. `bundle.url` is excluded from
the signed payload for exactly that reason, so the rewrite keeps `signature`
valid; `bundle.sha256`/`bundle.size` *are* signed and must match the
`bundleSha256`/`bundleSize` fields or the request is rejected with 400. In
private mode the stored public URL is replaced by a presigned one when the
manifest is served (see the manifest endpoint above).

### `POST /projects/:projectId/patches/:patchId/publish`
Activates the patch (deactivating siblings) and clears the manifest cache.

### `POST /projects/:projectId/patches/:patchId/rollback`
Re-activates the given patch. Clears the cache.

### `GET /projects/:projectId/releases/:releaseId/patches`
List patches for a release.

### `DELETE /projects/:projectId/patches/:patchId?force=true`
Deletes the patch, its bundle object, and (if it was active) invalidates the
manifest cache. Deleting the currently **active** patch is refused with 409
unless `force=true`, to avoid silently breaking live clients. Returns
`{ deleted, patchId }`; 404 if the patch is not in the project.

## CLI

```bash
export HOT_UPDATES_API_KEY=hu_...
hot_updates patch --backend      # build → create release → create patch → upload → publish
```

Requires `endpoint:` set in `.hot_updates/hot_updates.yaml`. `endpoint:` may be
either the API root (`https://api.example.com`) or the runtime manifest URL — the
CLI reduces the latter to the API root. The manifest `appVersion` comes from
`version:` in `pubspec.yaml` (build number stripped); override with
`--app-version`. `--backend` refuses to publish an unsigned manifest, so a
signing key must exist at `signing.private_key_path`.
