# Architecture

`flutter_hot_updates` is planned as a monorepo with four main product surfaces:

- Flutter client package for checking, downloading, verifying, storing, and activating updates.
- Dart CLI for creating releases, generating patch bundles, signing manifests, and uploading artifacts.
- Self-hosted backend for projects, releases, patches, devices, installation events, and manifest selection.
- Admin dashboard for release visibility, rollout control, rollback, and analytics.

The first MVP focuses on dynamic assets and remote configuration. Binary patching is intentionally outside the MVP because it requires deeper work with Flutter AOT artifacts and native loading behavior.

## Update Flow

```text
Flutter app
  -> checks manifest endpoint
  -> compares local version and patch
  -> downloads patch bundle
  -> verifies checksum/signature
  -> installs into app-controlled storage
  -> activates update
  -> resolves assets/config from active patch
```

## Storage Model

Client updates will be stored under an app-controlled directory such as application support or documents storage. The package must stage downloads separately from active patches so failed updates cannot corrupt the currently active version.

Server artifacts will be stored through an S3-compatible abstraction. Backblaze B2 is the first intended production storage provider, with MinIO as the local development option.
