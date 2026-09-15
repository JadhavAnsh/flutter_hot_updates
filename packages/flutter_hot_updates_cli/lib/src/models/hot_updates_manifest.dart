import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:hot_updates_manifest/hot_updates_manifest.dart';

class HotUpdatesBundle {
  const HotUpdatesBundle({
    required this.url,
    required this.sha256,
    required this.size,
  });

  factory HotUpdatesBundle.fromJson(Map<String, dynamic> json) {
    final url = json['url'];
    final sha256 = json['sha256'];
    final size = json['size'];
    if (url is! String || url.isEmpty) {
      throw const FormatException('bundle.url is required');
    }
    if (sha256 is! String || sha256.isEmpty) {
      throw const FormatException('bundle.sha256 is required');
    }
    if (size is! num || size <= 0) {
      throw const FormatException('bundle.size must be positive');
    }

    return HotUpdatesBundle(
      url: url,
      sha256: sha256.toLowerCase(),
      size: size.toInt(),
    );
  }

  final String url;
  final String sha256;
  final int size;

  Map<String, dynamic> toJson() => {
        'url': url,
        'sha256': sha256,
        'size': size,
      };
}

class HotUpdatesAsset {
  const HotUpdatesAsset({
    required this.path,
    required this.url,
    required this.sha256,
    required this.size,
  });

  factory HotUpdatesAsset.fromJson(Map<String, dynamic> json) {
    final path = json['path'];
    final url = json['url'];
    final sha256 = json['sha256'];
    final size = json['size'];

    if (path is! String || path.isEmpty) {
      throw const FormatException('asset.path is required');
    }
    if (url is! String || url.isEmpty) {
      throw const FormatException('asset.url is required');
    }
    if (sha256 is! String || sha256.isEmpty) {
      throw const FormatException('asset.sha256 is required');
    }

    return HotUpdatesAsset(
      path: path,
      url: url,
      sha256: sha256.toLowerCase(),
      size: size is num ? size.toInt() : 0,
    );
  }

  final String path;
  final String url;
  final String sha256;
  final int size;

  Map<String, dynamic> toJson() => {
        'path': path,
        'url': url,
        'sha256': sha256,
        if (size > 0) 'size': size,
      };
}

class HotUpdatesManifest {
  const HotUpdatesManifest({
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

  factory HotUpdatesManifest.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != 1) {
      throw FormatException('unsupported schemaVersion: $schemaVersion');
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
      throw const FormatException('projectId is required');
    }
    if (appVersion is! String || appVersion.isEmpty) {
      throw const FormatException('appVersion is required');
    }
    if (patch is! num || patch < 0) {
      throw const FormatException('patch must be a non-negative int');
    }
    if (minSupportedAppVersion is! String || minSupportedAppVersion.isEmpty) {
      throw const FormatException('minSupportedAppVersion is required');
    }
    if (platform is! String || platform.isEmpty) {
      throw const FormatException('platform is required');
    }
    if (createdAt is! String || createdAt.isEmpty) {
      throw const FormatException('createdAt is required');
    }
    if (assetsJson is! List) {
      throw const FormatException('assets must be a list');
    }
    if (configJson is! Map) {
      throw const FormatException('config must be an object');
    }
    if (bundleJson is! Map) {
      throw const FormatException('bundle is required');
    }

    return HotUpdatesManifest(
      schemaVersion: schemaVersion,
      projectId: projectId,
      appVersion: appVersion,
      patch: patch.toInt(),
      minSupportedAppVersion: minSupportedAppVersion,
      platform: platform,
      createdAt: createdAt,
      assets: assetsJson
          .map((item) => HotUpdatesAsset.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      config: Map<String, dynamic>.from(configJson),
      bundle: HotUpdatesBundle.fromJson(Map<String, dynamic>.from(bundleJson)),
      signature: json['signature'] as String?,
    );
  }

  factory HotUpdatesManifest.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('manifest must be a JSON object');
    }
    return HotUpdatesManifest.fromJson(decoded);
  }

  final int schemaVersion;
  final String projectId;
  final String appVersion;
  final int patch;
  final String minSupportedAppVersion;
  final String platform;
  final String createdAt;
  final List<HotUpdatesAsset> assets;
  final Map<String, dynamic> config;
  final HotUpdatesBundle bundle;
  final String? signature;

  Map<String, dynamic> toJson({bool includeSignature = true}) => {
        'schemaVersion': schemaVersion,
        'projectId': projectId,
        'appVersion': appVersion,
        'patch': patch,
        'minSupportedAppVersion': minSupportedAppVersion,
        'platform': platform,
        'createdAt': createdAt,
        'assets': assets.map((asset) => asset.toJson()).toList(growable: false),
        'config': config,
        'bundle': bundle.toJson(),
        if (includeSignature && signature != null) 'signature': signature,
      };

  String toJsonString({bool includeSignature = true}) =>
      jsonEncode(toJson(includeSignature: includeSignature));

  Map<String, dynamic> canonicalPayload() =>
      manifestSignaturePayload(toJson(includeSignature: false));

  String canonicalJsonString() => canonicalJsonEncode(canonicalPayload());

  String contentDigest() => sha256.convert(utf8.encode(canonicalJsonString())).toString();
}
