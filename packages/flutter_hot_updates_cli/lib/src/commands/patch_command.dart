import 'dart:io';

import '../environment.dart';
import '../models/hot_updates_manifest.dart';
import '../security/manifest_signer.dart';

class PatchCommand {
  PatchCommand(this.env);

  final CliEnvironment env;

  Future<int> run({
    String? platform,
    bool dryRun = false,
  }) async {
    final config = env.loadConfig();
    final selectedPlatform = platform ?? config.platforms.first;
    final outputDir = config.outputDirectory(env.projectRoot);

    final previousManifest = await _loadPreviousManifest(outputDir);
    if (previousManifest == null) {
      stderr.writeln('no previous manifest found, run release first');
      return 64;
    }

    final assets = await env.assetCollector.collect(
      projectRoot: env.projectRoot,
      includePatterns: config.assets.include,
      excludePatterns: config.assets.exclude,
    );

    final previousAssets = env.assetCollector.asMap(assets.where((a) {
      return previousManifest.assets.any((prev) => prev.path == a.path && prev.sha256 == a.sha256);
    }).toList());
    final currentAssets = env.assetCollector.asMap(assets);

    final diff = env.assetDiffCalculator.compare(
      previous: previousAssets,
      current: currentAssets,
    );

    final newPatch = previousManifest.patch + 1;

    if (dryRun) {
      stdout.writeln('dry-run patch $newPatch for $selectedPlatform');
      stdout.writeln('assets: ${assets.length}');
      stdout.writeln('added: ${diff.added.length}');
      stdout.writeln('modified: ${diff.modified.length}');
      stdout.writeln('removed: ${diff.removed.length}');
      return 0;
    }

    final bundle = await env.staticExporter.writeBundle(
      outputDirectory: outputDir,
      patch: newPatch,
      assets: assets,
      config: {},
    );

    final manifest = env.manifestBuilder.build(
      projectId: config.projectId,
      platform: selectedPlatform,
      appVersion: '1.0.0',
      patch: newPatch,
      assets: assets,
      config: {},
      bundleUrl: 'releases/patch_$newPatch/bundle.zip',
      bundleSha256: bundle.sha256,
      bundleSize: bundle.size,
    );

    final privateKeyFile = config.privateKeyFile(env.projectRoot);
    final signedManifest = privateKeyFile.existsSync()
        ? ManifestSigner(privateKeyPem: privateKeyFile.readAsStringSync())
            .signManifestMap(manifest.toJson(includeSignature: false))
        : manifest.toJsonString();

    final result = await env.staticExporter.writeManifest(
      bundle: bundle,
      manifest: HotUpdatesManifest.parse(signedManifest),
      config: {},
      patch: newPatch,
    );

    stdout.writeln('patch $newPatch for $selectedPlatform');
    stdout.writeln('assets: ${assets.length}');
    stdout.writeln('added: ${diff.added.length}');
    stdout.writeln('modified: ${diff.modified.length}');
    stdout.writeln('removed: ${diff.removed.length}');
    stdout.writeln('manifest: ${result.manifestFile.path}');
    stdout.writeln('bundle: ${result.bundleFile.path}');
    return 0;
  }

  Future<HotUpdatesManifest?> _loadPreviousManifest(Directory outputDir) async {
    final file = File('${outputDir.path}/manifest.json');
    if (!await file.exists()) return null;
    return HotUpdatesManifest.parse(await file.readAsString());
  }
}
