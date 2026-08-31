# flutter_hot_updates Implementation Plan

## 1. Product Direction

`flutter_hot_updates` will be an open-source, self-hostable update platform for Flutter apps. The first public versions should focus on reliable dynamic assets, remote configuration, manifest-based update checks, patch download/install bookkeeping, signatures, rollback, and developer tooling.

The product should be positioned honestly:

- Phase 1 does not replace compiled Dart AOT code.
- Phase 1 does not replace native Android or iOS code.
- Phase 1 can update assets, JSON, fonts, themes, configuration, and server-driven widget definitions without an APK reinstall.
- Binary patching of Flutter AOT artifacts is a later, separate research-heavy track.

The core developer experience:

```text
Write Flutter code / assets / config
      ↓
Run CLI release or patch command
      ↓
Upload manifest, patch bundle, and assets
      ↓
Flutter app checks manifest
      ↓
App verifies, downloads, installs, and activates update
      ↓
User sees changes without APK reinstall
```

## 2. Current Repository State

The repository currently looks like a default Flutter application scaffold:

```text
flutter_hot_updates/
├── android/
├── ios/
├── lib/
├── linux/
├── macos/
├── test/
├── web/
├── windows/
├── pubspec.yaml
└── README.md
```

The target product needs to become a workspace-style repository:

```text
flutter_hot_updates/
├── packages/
│   ├── flutter_hot_updates/
│   └── flutter_hot_updates_cli/
├── apps/
│   ├── hot_updates_server/
│   └── dashboard/
├── examples/
│   └── basic_flutter_app/
├── docs/
├── implementation-plan.md
├── README.md
└── melos.yaml
```

Use the existing Flutter scaffold as the first example app or replace it with a dedicated `examples/basic_flutter_app` after the package is extracted.

## 3. Guiding Technical Principles

- Keep v0.1 small enough to ship: manifest checks, assets, config, installation state, and an example app.
- Treat security as part of the update path from the start, even if full signing arrives in v0.2.
- Make update activation explicit and reversible.
- Keep the client package usable without the hosted backend by supporting static manifest URLs.
- Design the server and CLI around storage abstraction, not Backblaze-specific APIs.
- Keep every file written by the updater under app-controlled directories.
- Never silently activate a downloaded update unless verification passes.
- Make the roadmap clear that runtime widget updates are server-driven UI, not Dart code hot patching.

## 4. Milestone Overview

| Version | Goal | Main Deliverables |
| --- | --- | --- |
| v0.1 | Asset and config update MVP | Flutter package, manifest format, static hosting support, downloader, storage manager, basic example |
| v0.2 | Trust and rollback | Signature verification, checksums, rollback, install journal, analytics events |
| v0.3 | CLI and backend | Dart CLI, NestJS API, PostgreSQL schema, B2/S3 upload, release/patch commands |
| v0.4 | Runtime widgets | JSON widget schema, renderer, validation, remote screen/theme examples |
| v0.5 | Multi-project platform | Dashboard, devices, releases, patches, install analytics, project API keys |
| v1.0 | Production-ready platform | Stable package API, docs, migration guides, operational hardening |
| v2.0 | Binary patch research | Android AOT artifact diffing, native loader strategy, crash rollback, compatibility matrix |

## 5. Phase 0: Repository Foundation

### Goals

Create a maintainable monorepo before adding product logic.

### Tasks

1. Create package directories:

   ```text
   packages/flutter_hot_updates/
   packages/flutter_hot_updates_cli/
   apps/hot_updates_server/
   apps/dashboard/
   examples/basic_flutter_app/
   docs/
   ```

2. Move the current Flutter app into `examples/basic_flutter_app` or regenerate a cleaner example there.

3. Add `melos` for Dart/Flutter workspace management:

   ```yaml
   name: flutter_hot_updates_workspace

   packages:
     - packages/**
     - examples/**
   ```

4. Add root scripts:

   ```text
   melos bootstrap
   melos analyze
   melos test
   melos format
   ```

5. Update root `README.md` with:

   - Product description
   - Current capability matrix
   - Installation status
   - Roadmap
   - Security warning for pre-1.0 releases

6. Add docs:

   ```text
   docs/architecture.md
   docs/manifest-format.md
   docs/security-model.md
   docs/self-hosting.md
   docs/roadmap.md
   ```

### Acceptance Criteria

- `melos bootstrap` works.
- `melos analyze` runs across packages.
- Example app depends on local `flutter_hot_updates`.
- README no longer describes the project as a default Flutter app.

## 6. Phase 1: Flutter Package MVP

Package path:

```text
packages/flutter_hot_updates
```

### Public API

Initial API:

```dart
await HotUpdates.initialize(
  projectId: 'nextlearn',
  endpoint: 'https://updates.example.com',
  publicKey: '...',
);

final result = await HotUpdates.checkForUpdates();

await HotUpdates.downloadAndInstall(
  result.update!,
  onProgress: (progress) {},
);

await HotUpdates.activate();

final enabled = HotUpdates.config.getBool('showReferral');
```

Widgets:

```dart
HotImage('banner.png')
HotTextAsset('copy/home_headline.txt')
```

Streams:

```dart
HotUpdates.events.listen((event) {
  // checking, available, downloading, installed, activated, failed
});
```

### Internal Modules

```text
lib/src/
├── hot_updates.dart
├── models/
│   ├── update_manifest.dart
│   ├── update_release.dart
│   ├── update_asset.dart
│   ├── update_state.dart
│   └── update_event.dart
├── version/
│   └── version_manager.dart
├── network/
│   ├── update_checker.dart
│   └── update_client.dart
├── download/
│   ├── downloader.dart
│   └── download_progress.dart
├── storage/
│   ├── storage_manager.dart
│   └── install_journal.dart
├── security/
│   ├── checksum_verifier.dart
│   └── signature_verifier.dart
├── assets/
│   ├── hot_asset_bundle.dart
│   ├── hot_image.dart
│   └── asset_resolver.dart
├── config/
│   └── remote_config.dart
└── platform/
    └── app_info.dart
```

### Manifest Format v1

The first manifest should be explicit, versioned, and easy to serve from static hosting:

```json
{
  "schemaVersion": 1,
  "projectId": "nextlearn",
  "appVersion": "1.0.0",
  "patch": 4,
  "minSupportedAppVersion": "1.0.0",
  "platform": "android",
  "createdAt": "2026-08-17T00:00:00.000Z",
  "assets": [
    {
      "path": "images/banner.png",
      "url": "https://cdn.example.com/assets/images/banner.png",
      "sha256": "..."
    }
  ],
  "config": {
    "showReferral": true,
    "theme": "festival"
  },
  "bundle": {
    "url": "https://cdn.example.com/patches/v1.0.0/patch_4.zip",
    "sha256": "...",
    "size": 123456
  },
  "signature": "base64-rsa-signature"
}
```

### Local State Format

Store local state in app documents/support directory:

```json
{
  "projectId": "nextlearn",
  "currentAppVersion": "1.0.0",
  "activePatch": 4,
  "previousPatch": 3,
  "installedPatches": [
    {
      "patch": 3,
      "path": "updates/patch_3",
      "installedAt": "2026-08-17T00:00:00.000Z",
      "status": "inactive"
    },
    {
      "patch": 4,
      "path": "updates/patch_4",
      "installedAt": "2026-08-17T00:00:00.000Z",
      "status": "active"
    }
  ]
}
```

### Storage Layout

Android:

```text
<app-documents-or-support-dir>/
└── hot_updates/
    ├── state.json
    ├── manifests/
    │   └── active.json
    ├── downloads/
    │   └── patch_4.tmp
    └── patches/
        ├── patch_3/
        └── patch_4/
            ├── manifest.json
            ├── assets/
            └── config.json
```

### Update Flow

1. `initialize` loads local state, config, and active manifest.
2. `checkForUpdates` calls the manifest endpoint.
3. Client validates:

   - Matching `projectId`
   - Matching platform
   - Compatible app version
   - Remote patch number greater than local patch number

4. `downloadAndInstall` downloads bundle or individual assets.
5. Verify SHA256 checksums.
6. Verify manifest signature when public key is configured.
7. Unpack into a staging directory.
8. Write install journal.
9. Atomically mark the patch as installed.
10. `activate` switches active manifest/config.
11. Widgets and config readers resolve values from active patch.

### Required Dependencies

Likely package dependencies:

```yaml
dependencies:
  crypto: ^3.0.0
  dio: ^5.0.0
  path: ^1.9.0
  path_provider: ^2.1.0
  archive: ^4.0.0
  package_info_plus: ^8.0.0
  synchronized: ^3.0.0
```

Choose exact versions during implementation based on pub compatibility.

### v0.1 Acceptance Criteria

- Example app initializes the local package.
- Example app can load a local or remote manifest.
- Example app can replace an image through `HotImage`.
- Example app can read remote config values.
- Failed downloads do not change the active patch.
- Corrupt files are rejected by checksum validation.
- Basic unit tests cover manifest parsing, version comparison, config reads, and storage state transitions.

## 7. Phase 1.5: Security Model

Security should be designed before public release, even if strict enforcement is introduced in v0.2.

### Signing Model

1. CLI creates a manifest.
2. CLI computes SHA256 for every artifact.
3. CLI canonicalizes manifest payload without the `signature` field.
4. CLI signs the canonical payload with a private key.
5. Flutter package verifies with the app-embedded public key.

### Rejected Update Cases

- Manifest project ID mismatch.
- Platform mismatch.
- Unsupported app version.
- Patch downgrade unless rollback is explicitly requested.
- Missing artifact checksum.
- Artifact checksum mismatch.
- Invalid signature.
- Unpack path traversal attempt.
- Manifest references files outside the update directory.

### Key Management

For v0.2:

- `hot_updates keys generate`
- `hot_updates keys print-public`
- Private key stored locally or in CI secret manager.
- Public key embedded in Flutter app.
- Server never needs the private signing key.

## 8. Phase 2: CLI Package

Package path:

```text
packages/flutter_hot_updates_cli
```

Binary:

```text
hot_updates
```

Install:

```bash
dart pub global activate flutter_hot_updates_cli
```

### CLI Commands

```text
hot_updates init
hot_updates login
hot_updates release
hot_updates patch
hot_updates rollback
hot_updates keys generate
hot_updates keys print-public
hot_updates doctor
```

### `hot_updates init`

Creates:

```yaml
project_id: nextlearn
endpoint: https://updates.example.com
platforms:
  - android
assets:
  include:
    - assets/**
  exclude:
    - assets/**/*.psd
signing:
  private_key_path: .hot_updates/private_key.pem
output:
  directory: .hot_updates/build
```

### `hot_updates release`

Responsibilities:

- Read `hot_updates.yaml`.
- Read Flutter version from `pubspec.yaml`.
- Collect configured assets.
- Generate manifest.
- Build release artifact metadata.
- Sign manifest.
- Upload to backend or write to static output directory.

### `hot_updates patch`

v0.1-v0.5 patch means asset/config patch bundle, not binary code patch.

Responsibilities:

- Compare current asset/config state with previous release metadata.
- Generate a zip containing changed assets and `config.json`.
- Generate manifest with incremented patch number.
- Sign manifest.
- Upload bundle and manifest.

### `hot_updates rollback`

Responsibilities:

- Mark an older patch as active in the backend.
- Generate or update manifest pointer.
- Optionally create a rollback release event.

### CLI Implementation Modules

```text
bin/hot_updates.dart
lib/src/
├── commands/
│   ├── init_command.dart
│   ├── login_command.dart
│   ├── release_command.dart
│   ├── patch_command.dart
│   ├── rollback_command.dart
│   ├── keys_command.dart
│   └── doctor_command.dart
├── config/
│   └── hot_updates_config.dart
├── manifest/
│   ├── manifest_builder.dart
│   └── manifest_signer.dart
├── assets/
│   ├── asset_collector.dart
│   └── asset_diff.dart
├── upload/
│   ├── upload_client.dart
│   └── static_exporter.dart
└── auth/
    └── token_store.dart
```

### CLI Dependencies

Likely dependencies:

```yaml
dependencies:
  args: ^2.0.0
  cli_completion: ^0.5.0
  yaml: ^3.1.0
  crypto: ^3.0.0
  pointycastle: ^4.0.0
  archive: ^4.0.0
  path: ^1.9.0
  http: ^1.0.0
```

### CLI Acceptance Criteria

- `hot_updates init` creates a valid config.
- `hot_updates patch --dry-run` prints planned changes.
- `hot_updates patch --output ./dist` creates a signed static manifest and patch zip.
- `hot_updates doctor` detects missing config, missing signing key, and unsupported Flutter project layout.
- Unit tests cover config parsing, manifest signing, checksum generation, and asset diffing.

## 9. Phase 3: Backend API

App path:

```text
apps/hot_updates_server
```

Framework:

```text
NestJS
PostgreSQL
Prisma or TypeORM
S3-compatible storage client
```

Prefer Prisma if this project starts fresh. Prefer TypeORM only if matching an existing backend pattern is more important.

### Service Modules

```text
src/
├── app.module.ts
├── auth/
├── projects/
├── releases/
├── patches/
├── manifests/
├── devices/
├── installations/
├── analytics/
├── storage/
└── health/
```

### Database Schema

Use UUID primary keys and indexed lookup fields.

```sql
create table projects (
  id uuid primary key,
  name text not null,
  slug text unique not null,
  api_key_hash text not null,
  public_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table releases (
  id uuid primary key,
  project_id uuid not null references projects(id) on delete cascade,
  version text not null,
  platform text not null,
  status text not null,
  created_at timestamptz not null default now(),
  unique(project_id, version, platform)
);

create table patches (
  id uuid primary key,
  release_id uuid not null references releases(id) on delete cascade,
  patch_number integer not null,
  storage_url text not null,
  manifest_url text not null,
  checksum text not null,
  signature text not null,
  size_bytes bigint not null default 0,
  rollout_percentage integer not null default 100,
  status text not null,
  created_at timestamptz not null default now(),
  unique(release_id, patch_number)
);

create table devices (
  id uuid primary key,
  project_id uuid not null references projects(id) on delete cascade,
  device_id text not null,
  platform text not null,
  app_version text not null,
  active_patch integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(project_id, device_id)
);

create table installations (
  id uuid primary key,
  device_id uuid not null references devices(id) on delete cascade,
  patch_id uuid not null references patches(id) on delete cascade,
  status text not null,
  error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

### API Endpoints

Public app endpoints:

```http
GET /v1/projects/:projectId/manifest?platform=android&version=1.0.0&patch=3
POST /v1/projects/:projectId/devices
POST /v1/projects/:projectId/installations
POST /v1/projects/:projectId/events
```

CLI/admin endpoints:

```http
POST /v1/projects
GET /v1/projects
POST /v1/projects/:projectId/releases
GET /v1/projects/:projectId/releases
POST /v1/projects/:projectId/patches
POST /v1/projects/:projectId/patches/:patchId/upload-url
POST /v1/projects/:projectId/patches/:patchId/publish
POST /v1/projects/:projectId/patches/:patchId/rollback
```

Health:

```http
GET /health
```

### Manifest Response

If no update exists:

```json
{
  "updateAvailable": false
}
```

If update exists:

```json
{
  "updateAvailable": true,
  "manifest": {
    "schemaVersion": 1,
    "projectId": "nextlearn",
    "appVersion": "1.0.0",
    "patch": 4,
    "platform": "android",
    "bundle": {
      "url": "https://cdn.example.com/patches/v1.0.0/patch_4.zip",
      "sha256": "...",
      "size": 123456
    },
    "signature": "..."
  }
}
```

### Backend Acceptance Criteria

- CLI can create a project using an API key.
- CLI can upload a patch bundle to S3-compatible storage.
- App can fetch a manifest without admin credentials.
- Devices and installation statuses are recorded.
- Rollback changes the active manifest returned to clients.
- Integration tests cover manifest selection and rollback.

## 10. Phase 4: Storage Layer

Primary target:

```text
Backblaze B2 through S3-compatible APIs
```

Abstract storage behind:

```ts
interface ObjectStorage {
  putObject(input: PutObjectInput): Promise<PutObjectResult>;
  getSignedUploadUrl(input: SignedUploadInput): Promise<string>;
  getPublicUrl(key: string): string;
  deleteObject(key: string): Promise<void>;
}
```

Storage keys:

```text
projects/{projectId}/manifests/{platform}/{version}.json
projects/{projectId}/patches/{platform}/{version}/patch_{number}.zip
projects/{projectId}/assets/{platform}/{version}/{sha256}/{filename}
projects/{projectId}/releases/{platform}/{version}/metadata.json
```

Environment variables:

```text
S3_ENDPOINT=
S3_REGION=
S3_ACCESS_KEY_ID=
S3_SECRET_ACCESS_KEY=
S3_BUCKET=
S3_PUBLIC_BASE_URL=
```

Acceptance criteria:

- Local development can use MinIO.
- Production can use Backblaze B2.
- CDN URL generation is configurable.
- Uploads are private by default unless public CDN access is intentionally configured.

## 11. Phase 5: Admin Dashboard

App path:

```text
apps/dashboard
```

Framework:

```text
Next.js
TypeScript
Tailwind CSS
shadcn/ui
```

Pages:

```text
/overview
/projects
/projects/[projectId]
/projects/[projectId]/releases
/projects/[projectId]/patches
/projects/[projectId]/devices
/projects/[projectId]/analytics
/settings/api-keys
```

Core dashboard workflows:

- Create project.
- View releases by app version and platform.
- View patches for each release.
- Publish or pause a patch.
- Roll back to previous patch.
- Inspect install failures.
- View update adoption over time.

Analytics cards:

- Devices updated
- Success rate
- Failed installs
- Patch size
- Download count
- Active app versions
- Active patch distribution

Acceptance criteria:

- Dashboard can list projects, releases, patches, and devices.
- Rollback action calls backend and changes manifest behavior.
- Analytics charts are based on actual events, not mock data outside development.

## 12. Phase 6: Runtime Widget Updates

This is a separate feature track after asset/config updates are solid.

### Scope

Support a constrained JSON widget tree:

```json
{
  "type": "column",
  "children": [
    {
      "type": "text",
      "value": "Hello"
    },
    {
      "type": "image",
      "asset": "images/banner.png"
    }
  ]
}
```

Flutter API:

```dart
HotWidget.fromJson(data)
```

Supported widgets v0.4:

- Text
- Image
- Container
- Row
- Column
- Stack
- Padding
- Button
- Spacer
- Remote config conditional

Required safeguards:

- JSON schema validation.
- Maximum tree depth.
- Maximum child count.
- No arbitrary code execution.
- No raw network URLs unless allowed by config.
- Fail closed to fallback widget.

Acceptance criteria:

- Example screen can change headline, image, theme, and CTA remotely.
- Invalid widget JSON renders the fallback.
- Renderer has golden tests for common schemas.

## 13. Phase 7: Binary Patching Research

Do not start this before v0.5 has users.

Research areas:

- Flutter Android AOT build outputs.
- `libapp.so` compatibility across Flutter versions.
- Binary diff algorithms such as bsdiff.
- Android dynamic library loading constraints.
- Code signing and integrity.
- Crash detection and automatic rollback.
- Play Store policy constraints.
- ABI splits and architecture-specific patching.

Prototype goals:

- Generate diff between two `libapp.so` files from controlled builds.
- Apply diff on device storage.
- Verify checksum.
- Load patched artifact in a controlled test harness.
- Measure crash and startup risks.

This phase may require native Android code, Gradle integration, and deep Flutter engine knowledge.

## 14. Testing Strategy

### Flutter Package Tests

- Manifest JSON parsing.
- Version and patch comparison.
- Checksum verification.
- Signature verification.
- Storage state transitions.
- Rollback behavior.
- Asset resolution priority.
- Remote config type conversion.
- Downloader retry behavior with mocked HTTP.

### CLI Tests

- `hot_updates.yaml` parsing.
- Asset include/exclude matching.
- Manifest generation.
- Signature generation.
- Static export output.
- API upload request construction.
- Dry-run output.

### Backend Tests

- Project creation.
- API key authentication.
- Release creation.
- Patch upload lifecycle.
- Manifest selection.
- Rollout percentage behavior.
- Rollback behavior.
- Device event ingestion.

### End-to-End Tests

1. Start backend with local PostgreSQL and MinIO.
2. Run example Flutter app.
3. Publish patch from CLI.
4. App checks for update.
5. App downloads update.
6. App verifies update.
7. App activates update.
8. UI uses updated asset/config.
9. Rollback patch.
10. App returns to previous asset/config.

## 15. CI/CD Plan

Use GitHub Actions:

```text
.github/workflows/
├── dart.yml
├── server.yml
├── dashboard.yml
└── release.yml
```

Checks:

- Dart format
- Flutter analyze
- Flutter test
- CLI test
- NestJS lint/test
- Next.js lint/build
- Docker build for server

Release automation:

- Tag package releases.
- Publish package to pub.dev manually at first.
- Build Docker image for server.
- Generate changelog.

## 16. Documentation Plan

Docs required before v0.1 announcement:

```text
docs/getting-started.md
docs/static-hosting.md
docs/manifest-format.md
docs/client-api.md
docs/cli.md
docs/security-model.md
docs/self-hosting.md
docs/backblaze-b2.md
docs/cloudflare-cdn.md
docs/rollback.md
docs/limitations.md
```

Important wording for limitations:

```text
flutter_hot_updates v0.x updates dynamic assets, configuration, and server-driven UI definitions.
It does not patch compiled Dart code, native plugins, Android resources bundled in the APK,
iOS binaries, or Flutter engine artifacts.
```

## 17. Development Order

Recommended order of implementation:

1. Convert repo to monorepo layout.
2. Create `packages/flutter_hot_updates` package.
3. Implement manifest models and parsing.
4. Implement local storage manager.
5. Implement remote config.
6. Implement `HotImage`.
7. Implement update checker using static manifest URL.
8. Implement downloader and checksum verification.
9. Add example app using a local test manifest.
10. Add static export CLI command.
11. Add signing support.
12. Add rollback support.
13. Add NestJS API.
14. Add S3-compatible storage.
15. Add CLI upload flow.
16. Add dashboard.
17. Add runtime widgets.
18. Start binary patching research.

## 18. First Two-Week Sprint

### Week 1

Day 1:

- Create monorepo structure.
- Move current Flutter app to `examples/basic_flutter_app`.
- Add `packages/flutter_hot_updates`.
- Add workspace tooling.

Day 2:

- Add manifest model.
- Add JSON parsing.
- Add version/patch comparison.
- Add unit tests.

Day 3:

- Add storage manager.
- Add state file read/write.
- Add install journal.
- Add unit tests.

Day 4:

- Add update checker.
- Add HTTP client abstraction.
- Support static manifest endpoint.
- Add mocked HTTP tests.

Day 5:

- Add remote config.
- Add `HotUpdates.config`.
- Wire example app to show config-driven text/flags.

### Week 2

Day 6:

- Add asset resolver.
- Add `HotImage`.
- Add fallback to bundled asset.

Day 7:

- Add downloader.
- Add progress events.
- Add zip extraction.
- Add checksum verification.

Day 8:

- Add install and activate flow.
- Add rollback to previous patch.
- Add failure-safe staging directory.

Day 9:

- Add simple CLI static export:

  ```bash
  hot_updates patch --output ./dist
  ```

- Generate manifest and patch zip.

Day 10:

- End-to-end local demo.
- Update README.
- Add getting-started docs.
- Record known limitations.

## 19. Initial Issue Backlog

### Epic: Monorepo Setup

- Create workspace structure.
- Configure Melos.
- Move example app.
- Add root documentation.

### Epic: Flutter Client Package

- Implement `HotUpdates.initialize`.
- Implement manifest models.
- Implement `VersionManager`.
- Implement `UpdateChecker`.
- Implement `Downloader`.
- Implement `StorageManager`.
- Implement `RemoteConfig`.
- Implement `HotImage`.
- Implement event stream.
- Implement rollback.

### Epic: Security

- Implement SHA256 checks.
- Implement RSA key generation in CLI.
- Implement manifest signing.
- Implement manifest verification in client.
- Add tamper tests.

### Epic: CLI

- Add command framework.
- Implement `init`.
- Implement `doctor`.
- Implement `patch --dry-run`.
- Implement static export.
- Implement upload flow.
- Implement rollback.

### Epic: Backend

- Scaffold NestJS app.
- Add PostgreSQL schema.
- Add project API keys.
- Add release and patch endpoints.
- Add manifest endpoint.
- Add device install tracking.
- Add S3-compatible storage.

### Epic: Dashboard

- Scaffold Next.js app.
- Add project list.
- Add release list.
- Add patch details.
- Add rollback action.
- Add analytics views.

## 20. Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Users expect Dart code patching in v0.1 | Trust damage | Clear docs, naming, and limitation notices |
| Dynamic assets fail to load after install | Broken UI | Always keep bundled fallback assets |
| Corrupt or tampered patch activates | Security issue | Verify checksums and signatures before activation |
| Download interrupted | Bad install state | Use staging directory and install journal |
| Server outage blocks startup | Bad app UX | Load active local patch first, check updates asynchronously |
| CDN caches old manifest | Slow rollout/rollback | Use short TTL for manifests, long TTL for content-addressed assets |
| Runtime widget schema grows too powerful | Security/maintenance risk | Keep schema small and validated |
| Binary patching is harder than expected | Roadmap delay | Treat it as v2 research, not MVP dependency |

## 21. Definition of Done for MVP

The MVP is done when:

- A Flutter developer can install the local package.
- The example app can check a manifest.
- The app can download and activate a patch bundle.
- The app can use updated images and remote config.
- Corrupt updates are rejected.
- The previous patch can be restored.
- The CLI can generate a static patch bundle.
- Documentation explains setup, manifest format, limitations, and rollback.

## 22. Suggested Public Positioning

Use this message for early releases:

```text
flutter_hot_updates is an open-source update layer for Flutter assets,
remote configuration, and server-driven UI. It is built for teams that want
self-hosted control over non-binary app updates. Binary Dart/native patching
is planned as a later research track.
```

This avoids overpromising while still making the project useful and credible.

## 23. Current Implementation Status (as of 2026-08-31)

### Phase Assessment

**Current phase:** Early Phase 2 (CLI + Security)

**What exists:**
- ✅ Flutter package core (`packages/flutter_hot_updates/`)
- ✅ Manifest model and verification
- ✅ RSA signing/verification infrastructure
- ✅ Rollback functionality in client
- ✅ CLI security commands (keys, sign)
- ⚠️  CLI expanded to 2,200+ lines across 20+ files
- ⚠️  Backend client stub (88 lines, no backend exists)
- ⚠️  Release workflow (225 lines, unused)
- ⚠️  Auth/token store (no auth server)

**What's missing from plan:**
- Backend API (Phase 3)
- Dashboard (Phase 5)
- Documented self-hosting guide
- End-to-end test with real manifest server

### Drift Analysis

The CLI implementation deviated from the plan's lean approach:

**Plan expectation (Phase 2):**
```text
lib/src/
├── commands/          # 6-8 command files
├── config/           # Config parser
├── manifest/         # Builder + signer
├── assets/           # Collector + diff
├── upload/           # Client + static export
└── auth/             # Token store
```

**Current reality:**
```text
lib/src/
├── commands/         # 8 commands (339 lines)
├── config/           # Config parser
├── manifest/         # Manifest builder
├── output/           # Static exporter
├── project/          # Project inspector
├── release/          # Release workflow (225 lines)
├── backend/          # Backend client (88 lines, no backend)
├── auth/             # Token store (no auth)
├── security/         # 3 security utils
├── models/           # Manifest models
├── assets/           # (directory exists)
└── environment.dart
```

**Architecture debt:**
- Backend client built before backend exists (Phase 3 is unstarted)
- Release workflow orchestration for workflows that don't exist yet
- Project inspector inspecting unclear targets
- Auth/token infrastructure with no authentication server
- 8 command classes when 6 are simple arg parsing

### What Should Happen Next

**Option A: Continue forward (finish Phase 2 → start Phase 3)**
- Accept the current CLI structure
- Build the backend API it expects
- Wire up release/patch workflows end-to-end
- Validate with real self-hosting scenario

**Option B: Simplify CLI first (ponytail ultra)**
- Delete backend client until backend exists
- Delete release workflow orchestration
- Delete project inspector
- Delete auth/token store
- Collapse simple commands back into cli.dart
- Keep only: keys, sign, manifest builder, static export
- Ship static-hosting-first CLI (matches Phase 2 scope)
- Add backend integration in Phase 3 when backend exists

**Recommendation:**
- You're at Phase 2 with Phase 3 infrastructure already built
- The backend client/workflow code is speculative (no backend to call)
- The plan says Phase 3 starts the backend
- Current approach: build Phase 3 backend now to match the CLI
- Lazy approach: delete Phase 3 code from CLI, ship Phase 2, then add Phase 3 properly

**Ponytail ultra verdict:**
Delete: backend/, release/, auth/, project/
Keep: commands/, manifest/, output/, security/, models/
Save: ~600 lines, remove 3 dependencies (http likely unused without backend)
Ship: Static-export-focused CLI that matches Phase 2 plan
Add back: When Phase 3 backend exists and needs the client

### Minimal Viable Next Steps

**If keeping current structure:**
1. Build Phase 3 backend (NestJS + PostgreSQL + S3)
2. Wire release/patch commands to real backend
3. End-to-end test: CLI upload → backend storage → client download
4. Document self-hosting with Backblaze B2

**If simplifying first:**
1. Delete unused Phase 3 infrastructure
2. Document static export workflow
3. Ship Phase 2 CLI as planned
4. Start Phase 3 properly with backend

**Critical path:**
The 3-line manifest.json write in `hot_updates.dart` suggests the client expects it during install. Verify this is needed or if manifest already exists from bundle extraction.
