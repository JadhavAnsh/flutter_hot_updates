import 'dart:io';

import '../config/hot_updates_config.dart';
import '../environment.dart';
import '../models/hot_updates_manifest.dart';
import '../output/static_exporter.dart';
import '../security/manifest_signer.dart';
import '../upload/backend_client.dart';

class PatchCommand {
  PatchCommand(this.env);

  final CliEnvironment env;

  Future<int> run({
    String? platform,
    String? appVersion,
    bool dryRun = false,
    bool backend = false,
  }) async {
    final config = env.loadConfig();
    final selectedPlatform = platform ?? config.platforms.first;
    final resolvedAppVersion = appVersion ?? env.resolveAppVersion();
    if (resolvedAppVersion == null) {
      stderr.writeln(
        'could not read `version:` from pubspec.yaml, pass --app-version',
      );
      return 64;
    }
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
      appVersion: resolvedAppVersion,
      patch: newPatch,
      assets: assets,
      config: {},
      bundleUrl: 'releases/patch_$newPatch/bundle.zip',
      bundleSha256: bundle.sha256,
      bundleSize: bundle.size,
    );

    final privateKeyFile = config.privateKeyFile(env.projectRoot);
    if (!privateKeyFile.existsSync()) {
      stderr.writeln(
        'patch requires a signing key at ${config.signing.privateKeyPath}',
      );
      return 64;
    }
    final signedManifest = ManifestSigner(
      privateKeyPem: privateKeyFile.readAsStringSync(),
    ).signManifestMap(manifest.toJson(includeSignature: false));

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

    if (backend) {
      return _uploadToBackend(
        config: config,
        manifest: result.manifest,
        bundle: bundle,
        patch: newPatch,
      );
    }
    return 0;
  }

  Future<int> _uploadToBackend({
    required HotUpdatesConfig config,
    required HotUpdatesManifest manifest,
    required BundleArtifact bundle,
    required int patch,
  }) async {
    final endpoint = config.endpoint;
    if (endpoint == null) {
      stderr.writeln('--backend requires `endpoint` in hot_updates.yaml');
      return 64;
    }
    final apiKey = Platform.environment['HOT_UPDATES_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      stderr.writeln('--backend requires HOT_UPDATES_API_KEY');
      return 64;
    }
    // An empty signature would be stored and served as-is, and every client with
    // signature verification enabled would then reject the patch. Fail here
    // instead of publishing something unusable.
    final signature = manifest.signature;
    if (signature == null || signature.isEmpty) {
      stderr.writeln(
        '--backend requires a signed manifest, add a signing key at '
        '${config.signing.privateKeyPath}',
      );
      return 64;
    }

    final client = BackendClient(baseUrl: endpoint, apiKey: apiKey);
    try {
      final releaseId = await client.ensureRelease(
        projectId: manifest.projectId,
        appVersion: manifest.appVersion,
        platform: manifest.platform,
      );
      final created = await client.createPatch(
        projectId: manifest.projectId,
        releaseId: releaseId,
        patchNumber: patch,
        manifest: manifest.toJson(),
        bundleSha256: bundle.sha256,
        bundleSize: bundle.size,
        signature: signature,
      );
      await client.uploadBundle(
        created.uploadUrl,
        await bundle.bundleFile.readAsBytes(),
      );
      await client.publish(
        projectId: manifest.projectId,
        patchId: created.patchId,
      );
      stdout.writeln('published patch $patch to $endpoint');
      return 0;
    } catch (error) {
      stderr.writeln('backend upload failed: $error');
      return 70;
    } finally {
      client.close();
    }
  }

  Future<HotUpdatesManifest?> _loadPreviousManifest(Directory outputDir) async {
    final file = File('${outputDir.path}/manifest.json');
    if (!await file.exists()) return null;
    return HotUpdatesManifest.parse(await file.readAsString());
  }
}
