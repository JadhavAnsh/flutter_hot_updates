import '../assets/asset_collector.dart';
import '../models/hot_updates_manifest.dart';

class ManifestBuilder {
  const ManifestBuilder();

  HotUpdatesManifest build({
    required String projectId,
    required String appVersion,
    required int patch,
    required String platform,
    required List<CollectedAsset> assets,
    required Map<String, dynamic> config,
    required String bundleUrl,
    required String bundleSha256,
    required int bundleSize,
    String minSupportedAppVersion = '1.0.0',
    String? createdAt,
  }) {
    return HotUpdatesManifest(
      schemaVersion: 1,
      projectId: projectId,
      appVersion: appVersion,
      patch: patch,
      minSupportedAppVersion: minSupportedAppVersion,
      platform: platform,
      createdAt: createdAt ?? DateTime.now().toUtc().toIso8601String(),
      assets: assets
          .map(
            (asset) => HotUpdatesAsset(
              path: asset.path,
              url: 'releases/patch_$patch/assets/${asset.path}',
              sha256: asset.sha256,
              size: asset.size,
            ),
          )
          .toList(growable: false),
      config: config,
      bundle: HotUpdatesBundle(
        url: bundleUrl,
        sha256: bundleSha256,
        size: bundleSize,
      ),
    );
  }
}
