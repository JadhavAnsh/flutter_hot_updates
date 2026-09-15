# flutter_hot_updates

`flutter_hot_updates` is an open-source, self-hostable update layer for Flutter apps. The project is designed to let teams ship dynamic assets, remote configuration, and server-driven UI changes without requiring an APK reinstall.

The repository currently includes the Flutter client package, security verification primitives, and a CLI package with key-generation and manifest-signing support.

## Current Status

Pre-MVP. Not ready for production use and not published to pub.dev.

| Capability | Status |
| --- | --- |
| Check update manifest | Implemented in `flutter_hot_updates` |
| Download updated assets | Implemented in `flutter_hot_updates` |
| Remote configuration | Implemented in `flutter_hot_updates` |
| Dynamic asset widgets | Implemented in `flutter_hot_updates` |
| SHA256 checksum verification | Implemented in `flutter_hot_updates` |
| Manifest signature verification | Implemented in `flutter_hot_updates` |
| Safe archive extraction | Implemented in `flutter_hot_updates` |
| Rollback to previous patch | Implemented in `flutter_hot_updates` |
| CLI key generation | Implemented in `flutter_hot_updates_cli` |
| CLI manifest signing | Implemented in `flutter_hot_updates_cli` |
| CLI release and patch commands | Implemented in `flutter_hot_updates_cli` |
| Self-hosted backend (NestJS) | Implemented in `apps/hot_updates_server` |
| Admin dashboard | Planned for v0.5 |
| Runtime widgets | Planned for v0.4 |
| Flutter AOT binary patching | Research track for v2.0 |

## Repository Layout

```text
flutter_hot_updates/
├── packages/
│   ├── hot_updates_manifest/
│   ├── flutter_hot_updates/
│   └── flutter_hot_updates_cli/
├── apps/
│   ├── hot_updates_server/
│   └── dashboard/
├── examples/
│   └── basic_flutter_app/
├── docs/
├── implementation-plan.md
├── melos.yaml
└── README.md
```

## Development

This repository uses Melos to manage Dart and Flutter packages.

```bash
dart pub global activate melos
dart pub global run melos bootstrap
dart pub global run melos analyze
dart pub global run melos test
```

Useful package-level checks:

```bash
cd packages/flutter_hot_updates
flutter test

cd ../flutter_hot_updates_cli
dart analyze
dart run bin/hot_updates.dart --help
```

The current Flutter scaffold has been preserved as `examples/basic_flutter_app`.

## Roadmap

- v0.1: manifest checks, asset downloads, remote config, and a working example app.
- v0.2: patch signatures, checksums, rollback, and basic analytics events.
- v0.3: CLI commands, NestJS backend, PostgreSQL schema, and S3-compatible storage.
- v0.4: constrained runtime widget updates from JSON definitions.
- v0.5: multi-project dashboard with releases, patches, devices, and analytics.
- v1.0: stable public APIs, production documentation, and operational hardening.
- v2.0: Android binary patching research for Flutter AOT artifacts.

## Security Notice

Pre-1.0 versions should be treated as experimental. The client requires an embedded public key and rejects unsigned manifests. Checksums and signatures are verified before install and activation. Backend upload via the CLI is available; rollout management, the admin dashboard, and production hardening are not complete yet.

`flutter_hot_updates` v0.x will update dynamic assets, configuration, and server-driven UI definitions. It will not patch compiled Dart code, native plugins, Android resources bundled in the APK, iOS binaries, or Flutter engine artifacts.
