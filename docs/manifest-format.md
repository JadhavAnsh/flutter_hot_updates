# Manifest Format

The manifest describes the latest update available for a project, platform, and app version. The v0.1 schema is planned to support assets, configuration, patch bundle metadata, checksums, and a signature field.

Example shape:

```json
{
  "schemaVersion": 1,
  "projectId": "nextlearn",
  "appVersion": "1.0.0",
  "patch": 4,
  "minSupportedAppVersion": "1.0.0",
  "platform": "android",
  "assets": [],
  "config": {},
  "bundle": {
    "url": "https://cdn.example.com/patches/v1.0.0/patch_4.zip",
    "sha256": "...",
    "size": 123456
  },
  "signature": "base64-rsa-signature"
}
```

The client should reject manifests with a mismatched project ID, unsupported platform, unsupported app version, downgrade patch number, invalid checksum, or invalid signature.

This format is not stable until the package reaches a tagged MVP release.
