# flutter_hot_updates

`flutter_hot_updates` is an open-source, self-hostable update layer for Flutter apps. The project is designed to let teams ship dynamic assets, remote configuration, and server-driven UI changes without requiring an APK reinstall.

This repository is currently in the repository foundation stage. The codebase is being organized as a monorepo before the first MVP features are implemented.

## Current Status

Pre-MVP. Not ready for production use and not published to pub.dev.

| Capability | Status |
| --- | --- |
| Check update manifest | Planned for v0.1 |
| Download updated assets | Planned for v0.1 |
| Remote configuration | Planned for v0.1 |
| Dynamic asset widgets | Planned for v0.1 |
| Patch signing | Planned for v0.2 |
| Rollback | Planned for v0.2 |
| CLI release and patch commands | Planned for v0.3 |
| Self-hosted backend | Planned for v0.3 |
| Admin dashboard | Planned for v0.5 |
| Runtime widgets | Planned for v0.4 |
| Flutter AOT binary patching | Research track for v2.0 |

## Repository Layout

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

Pre-1.0 versions should be treated as experimental. Do not use this project to distribute production updates until signature verification, rollback, and operational safeguards are complete.

`flutter_hot_updates` v0.x will update dynamic assets, configuration, and server-driven UI definitions. It will not patch compiled Dart code, native plugins, Android resources bundled in the APK, iOS binaries, or Flutter engine artifacts.
