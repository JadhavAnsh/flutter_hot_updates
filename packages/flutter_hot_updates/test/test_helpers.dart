import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_hot_updates/src/models/update_manifest.dart';
import 'package:path/path.dart' as p;

class TestFixtures {
  static String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

  static Future<TestPatchBundle> createPatchBundle({
    required Directory root,
    required UpdateManifest manifest,
    Map<String, String> assetContents = const {},
  }) async {
    final patchDir = Directory(p.join(root.path, 'patch_${manifest.patch}'));
    final assetsDir = Directory(p.join(patchDir.path, 'assets'));
    await assetsDir.create(recursive: true);

    for (final asset in manifest.assets) {
      final content = assetContents[asset.path] ?? 'asset:${asset.path}';
      final bytes = utf8.encode(content);
      final file = File(p.join(assetsDir.path, asset.path));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    }

    await File(p.join(patchDir.path, 'manifest.json'))
        .writeAsString(manifest.toJsonString());
    await File(p.join(patchDir.path, 'config.json'))
        .writeAsString(jsonEncode(manifest.config));

    final archive = Archive();
    for (final entity in patchDir.listSync(recursive: true)) {
      if (entity is File) {
        final relative = p.relative(entity.path, from: patchDir.path);
        archive.addFile(
          ArchiveFile(
            relative,
            entity.lengthSync(),
            entity.readAsBytesSync(),
          ),
        );
      }
    }

    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
    final zipFile = File(p.join(root.path, 'patch_${manifest.patch}.zip'));
    await zipFile.writeAsBytes(zipBytes);

    return TestPatchBundle(
      patchDirectory: patchDir,
      zipFile: zipFile,
      zipSha256: sha256Hex(zipBytes),
      zipSize: zipBytes.length,
    );
  }

  static UpdateManifest buildManifest({
    required String projectId,
    required String platform,
    required int patch,
    String appVersion = '1.0.0',
    String minSupportedAppVersion = '1.0.0',
    Map<String, dynamic> config = const {'showReferral': true},
    List<Map<String, dynamic>> assets = const [
      {
        'path': 'images/banner.png',
        'url': 'images/banner.png',
        'sha256': 'placeholder',
      },
    ],
    String bundleUrl = 'patch.zip',
    String bundleSha256 = 'placeholder',
    int bundleSize = 1,
  }) {
    return UpdateManifest.fromJson({
      'schemaVersion': 1,
      'projectId': projectId,
      'appVersion': appVersion,
      'patch': patch,
      'minSupportedAppVersion': minSupportedAppVersion,
      'platform': platform,
      'createdAt': '2026-08-17T00:00:00.000Z',
      'assets': assets,
      'config': config,
      'bundle': {
        'url': bundleUrl,
        'sha256': bundleSha256,
        'size': bundleSize,
      },
    });
  }
}

class TestPatchBundle {
  const TestPatchBundle({
    required this.patchDirectory,
    required this.zipFile,
    required this.zipSha256,
    required this.zipSize,
  });

  final Directory patchDirectory;
  final File zipFile;
  final String zipSha256;
  final int zipSize;
}
