import 'dart:io';

import '../environment.dart';
import '../models/hot_updates_manifest.dart';
import '../security/manifest_signer.dart';

class ReleaseCommand {
  ReleaseCommand(this.env);

  final CliEnvironment env;

  Future<int> run({
    String? platform,
    String? appVersion,
    bool dryRun = false,
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

    final assets = await env.assetCollector.collect(
      projectRoot: env.projectRoot,
      includePatterns: config.assets.include,
      excludePatterns: config.assets.exclude,
    );

    if (dryRun) {
      stdout.writeln('dry-run release patch 0 for $selectedPlatform');
      stdout.writeln('assets: ${assets.length}');
      return 0;
    }

    final outputDir = config.outputDirectory(env.projectRoot);
    final bundle = await env.staticExporter.writeBundle(
      outputDirectory: outputDir,
      patch: 0,
      assets: assets,
      config: {},
    );

    final manifest = env.manifestBuilder.build(
      projectId: config.projectId,
      platform: selectedPlatform,
      appVersion: resolvedAppVersion,
      patch: 0,
      assets: assets,
      config: {},
      bundleUrl: 'releases/patch_0/bundle.zip',
      bundleSha256: bundle.sha256,
      bundleSize: bundle.size,
    );

    final privateKeyFile = config.privateKeyFile(env.projectRoot);
    if (!privateKeyFile.existsSync()) {
      stderr.writeln(
        'release requires a signing key at ${config.signing.privateKeyPath}',
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
      patch: 0,
    );

    stdout.writeln('release patch 0 for $selectedPlatform');
    stdout.writeln('assets: ${assets.length}');
    stdout.writeln('manifest: ${result.manifestFile.path}');
    stdout.writeln('bundle: ${result.bundleFile.path}');
    return 0;
  }
}

