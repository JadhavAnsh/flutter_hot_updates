import 'dart:convert';

import '../errors.dart';
import '../security/canonical_json.dart';

/// Metadata for a downloadable patch bundle.
class BundleInfo {
  const BundleInfo({
    required this.url,
    required this.sha256,
    required this.size,
  });

  factory BundleInfo.fromJson(Map<String, dynamic> json) {
    final url = json['url'];
    final sha256 = json['sha256'];
    final size = json['size'];

    if (url is! String || url.isEmpty) {
      throw const UpdateValidationException('bundle.url is required');
    }
    if (sha256 is! String || sha256.isEmpty) {
      throw const UpdateValidationException('bundle.sha256 is required');
    }
    if (size is! num || size <= 0) {
      throw const UpdateValidationException('bundle.size must be positive');
    }

    return BundleInfo(
      url: url,
      sha256: sha256.toLowerCase(),
      size: size.toInt(),
    );
  }

  final String url;
  final String sha256;
  final int size;

  Map<String, dynamic> toJson() => {'url': url, 'sha256': sha256, 'size': size};
}

/// A single asset entry referenced by a manifest.
class UpdateAsset {
  const UpdateAsset({
    required this.path,
    required this.url,
    required this.sha256,
  });

  factory UpdateAsset.fromJson(Map<String, dynamic> json) {
    final path = json['path'];
    final url = json['url'];
    final sha256 = json['sha256'];

    if (path is! String || path.isEmpty) {
      throw const UpdateValidationException('asset.path is required');
    }
    if (url is! String || url.isEmpty) {
      throw const UpdateValidationException('asset.url is required');
    }
    if (sha256 is! String || sha256.isEmpty) {
      throw const UpdateValidationException('asset.sha256 is required');
    }

    return UpdateAsset(path: path, url: url, sha256: sha256.toLowerCase());
  }

  final String path;
  final String url;
  final String sha256;

  Map<String, dynamic> toJson() => {'path': path, 'url': url, 'sha256': sha256};
}

/// Parsed update manifest (schema v1).
class UpdateManifest {
  const UpdateManifest({
    required this.schemaVersion,
    required this.projectId,
    required this.appVersion,
    required this.patch,
    required this.minSupportedAppVersion,
    required this.platform,
    required this.createdAt,
    required this.assets,
    required this.config,
    required this.bundle,
    this.signature,
  });

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != 1) {
      throw UpdateValidationException(
        'unsupported schemaVersion: $schemaVersion',
      );
    }

    final projectId = json['projectId'];
    final appVersion = json['appVersion'];
    final patch = json['patch'];
    final minSupportedAppVersion = json['minSupportedAppVersion'];
    final platform = json['platform'];
    final createdAt = json['createdAt'];
    final assetsJson = json['assets'];
    final configJson = json['config'];
    final bundleJson = json['bundle'];

    if (projectId is! String || projectId.isEmpty) {
      throw const UpdateValidationException('projectId is required');
    }
    if (appVersion is! String || appVersion.isEmpty) {
      throw const UpdateValidationException('appVersion is required');
    }
    if (patch is! num || patch < 0) {
      throw const UpdateValidationException('patch must be a non-negative int');
    }
    if (minSupportedAppVersion is! String || minSupportedAppVersion.isEmpty) {
      throw const UpdateValidationException(
        'minSupportedAppVersion is required',
      );
    }
    if (platform is! String || platform.isEmpty) {
      throw const UpdateValidationException('platform is required');
    }
    if (createdAt is! String || createdAt.isEmpty) {
      throw const UpdateValidationException('createdAt is required');
    }
    if (assetsJson is! List) {
      throw const UpdateValidationException('assets must be a list');
    }
    if (configJson is! Map) {
      throw const UpdateValidationException('config must be an object');
    }
    if (bundleJson is! Map) {
      throw const UpdateValidationException('bundle is required');
    }

    final assets = assetsJson
        .map((item) => UpdateAsset.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);

    return UpdateManifest(
      schemaVersion: schemaVersion,
      projectId: projectId,
      appVersion: appVersion,
      patch: patch.toInt(),
      minSupportedAppVersion: minSupportedAppVersion,
      platform: platform,
      createdAt: createdAt,
      assets: assets,
      config: Map<String, dynamic>.from(configJson),
      bundle: BundleInfo.fromJson(Map<String, dynamic>.from(bundleJson)),
      signature: json['signature'] as String?,
    );
  }

  factory UpdateManifest.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const UpdateValidationException('manifest must be a JSON object');
    }
    return UpdateManifest.fromJson(decoded);
  }

  final int schemaVersion;
  final String projectId;
  final String appVersion;
  final int patch;
  final String minSupportedAppVersion;
  final String platform;
  final String createdAt;
  final List<UpdateAsset> assets;
  final Map<String, dynamic> config;
  final BundleInfo bundle;
  final String? signature;

  Map<String, dynamic> toJson({bool includeSignature = true}) => {
    'schemaVersion': schemaVersion,
    'projectId': projectId,
    'appVersion': appVersion,
    'patch': patch,
    'minSupportedAppVersion': minSupportedAppVersion,
    'platform': platform,
    'createdAt': createdAt,
    'assets': assets.map((asset) => asset.toJson()).toList(),
    'config': config,
    'bundle': bundle.toJson(),
    if (includeSignature && signature != null) 'signature': signature,
  };

  String toJsonString({bool includeSignature = true}) =>
      jsonEncode(toJson(includeSignature: includeSignature));

  /// Canonical JSON payload used for signature verification (no signature
  /// field, and no `bundle.url` — hosting rewrites it, see
  /// [manifestSignaturePayload]).
  Map<String, dynamic> canonicalPayload() =>
      manifestSignaturePayload(toJson(includeSignature: false));

  /// Canonical JSON string used for signing and verification.
  String canonicalJsonString() => canonicalJsonEncode(canonicalPayload());
}
