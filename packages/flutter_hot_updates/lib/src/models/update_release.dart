import 'update_manifest.dart';

/// An update eligible for download and install.
class UpdateRelease {
  const UpdateRelease({
    required this.manifest,
    required this.manifestUrl,
  });

  final UpdateManifest manifest;
  final String manifestUrl;

  int get patch => manifest.patch;

  String get appVersion => manifest.appVersion;
}
