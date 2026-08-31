import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../assets/asset_collector.dart';
import '../models/hot_updates_manifest.dart';

class BundleArtifact {
  const BundleArtifact({
    required this.rootDirectory,
    required this.releaseDirectory,
    required this.bundleFile,
    required this.sha256,
    required this.size,
  });

  final Directory rootDirectory;
  final Directory releaseDirectory;
  final File bundleFile;
  final String sha256;
  final int size;
}

class ExportedRelease {
  const ExportedRelease({
    required this.rootDirectory,
    required this.releaseDirectory,
    required this.manifestFile,
    required this.bundleFile,
    required this.manifest,
  });

  final Directory rootDirectory;
  final Directory releaseDirectory;
  final File manifestFile;
  final File bundleFile;
  final HotUpdatesManifest manifest;
}

class StaticExporter {
  const StaticExporter();

  Future<BundleArtifact> writeBundle({
    required Directory outputDirectory,
    required int patch,
    required List<CollectedAsset> assets,
    required Map<String, dynamic> config,
  }) async {
    final releaseDirectory = Directory(
      p.join(outputDirectory.path, 'releases', 'patch_$patch'),
    );
    final assetsDirectory = Directory(p.join(releaseDirectory.path, 'assets'));
    await assetsDirectory.create(recursive: true);

    for (final asset in assets) {
      final destination = File(
        p.join(assetsDirectory.path, asset.path),
      );
      await destination.parent.create(recursive: true);
      await destination.writeAsBytes(await asset.file.readAsBytes());
    }

    final bundleFile = File(p.join(releaseDirectory.path, 'bundle.zip'));
    final zipBytes = _buildBundleZip(assets: assets, config: config);
    await bundleFile.writeAsBytes(zipBytes);

    return BundleArtifact(
      rootDirectory: outputDirectory,
      releaseDirectory: releaseDirectory,
      bundleFile: bundleFile,
      sha256: sha256.convert(zipBytes).toString(),
      size: zipBytes.length,
    );
  }

  Future<ExportedRelease> writeManifest({
    required BundleArtifact bundle,
    required HotUpdatesManifest manifest,
    required Map<String, dynamic> config,
    required int patch,
  }) async {
    if (bundle.sha256 != manifest.bundle.sha256) {
      throw StateError('bundle checksum mismatch while exporting release');
    }

    final manifestFile = File(
      p.join(bundle.releaseDirectory.path, 'manifest.json'),
    );
    await manifestFile.writeAsString(manifest.toJsonString());
    await File(p.join(bundle.rootDirectory.path, 'manifest.json'))
        .writeAsString(manifest.toJsonString());
    await File(p.join(bundle.rootDirectory.path, 'active.json')).writeAsString(
      jsonEncode({
        'patch': patch,
        'manifestPath': p.relative(manifestFile.path, from: bundle.rootDirectory.path),
      }),
    );
    await File(p.join(bundle.releaseDirectory.path, 'config.json'))
        .writeAsString(jsonEncode(config));

    return ExportedRelease(
      rootDirectory: bundle.rootDirectory,
      releaseDirectory: bundle.releaseDirectory,
      manifestFile: manifestFile,
      bundleFile: bundle.bundleFile,
      manifest: manifest,
    );
  }

  Future<ExportedRelease> writeRelease({
    required Directory outputDirectory,
    required int patch,
    required HotUpdatesManifest manifest,
    required List<CollectedAsset> assets,
    required Map<String, dynamic> config,
  }) async {
    final bundle = await writeBundle(
      outputDirectory: outputDirectory,
      patch: patch,
      assets: assets,
      config: config,
    );
    return writeManifest(
      bundle: bundle,
      manifest: manifest,
      config: config,
      patch: patch,
    );
  }

  Future<void> writeRollbackPointer({
    required Directory outputDirectory,
    required int patch,
  }) async {
    final manifestFile = File(
      p.join(outputDirectory.path, 'releases', 'patch_$patch', 'manifest.json'),
    );
    if (!await manifestFile.exists()) {
      throw FileSystemException('rollback target manifest not found', manifestFile.path);
    }
    await File(p.join(outputDirectory.path, 'manifest.json'))
        .writeAsString(await manifestFile.readAsString());
    await File(p.join(outputDirectory.path, 'active.json')).writeAsString(
      jsonEncode({
        'patch': patch,
        'manifestPath': p.relative(manifestFile.path, from: outputDirectory.path),
      }),
    );
  }

  Uint8List _buildBundleZip({
    required List<CollectedAsset> assets,
    required Map<String, dynamic> config,
  }) {
    final archive = Archive();

    for (final asset in assets) {
      archive.addFile(
        ArchiveFile(
          'assets/${asset.path}',
          asset.size,
          asset.file.readAsBytesSync(),
        ),
      );
    }

    final configBytes = utf8.encode(jsonEncode(config));
    archive.addFile(
      ArchiveFile('config.json', configBytes.length, configBytes),
    );

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }
}
