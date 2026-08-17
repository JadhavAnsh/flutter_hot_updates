import 'dart:convert';
import 'dart:io';

import 'package:flutter_hot_updates/src/assets/asset_resolver.dart';
import 'package:flutter_hot_updates/src/models/update_state.dart';
import 'package:flutter_hot_updates/src/storage/storage_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssetResolver', () {
    late Directory tempDir;
    late StorageManager storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hot_updates_assets_');
      storage = await StorageManager.create(tempDir);
      await storage.initialize();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('resolves files from active patch directory', () async {
      final assetContent = 'headline from patch';
      final assetSha = TestFixtures.sha256Hex(utf8.encode(assetContent));
      final manifest = TestFixtures.buildManifest(
        projectId: 'demo',
        platform: 'android',
        patch: 1,
        assets: [
          {
            'path': 'copy/home_headline.txt',
            'url': 'copy/home_headline.txt',
            'sha256': assetSha,
          },
        ],
      );

      final bundle = await TestFixtures.createPatchBundle(
        root: tempDir,
        manifest: manifest,
        assetContents: {'copy/home_headline.txt': assetContent},
      );

      final staging = storage.stagingDirectoryForPatch(1);
      await storage.extractZipSafely(
        zipBytes: await bundle.zipFile.readAsBytes(),
        destination: staging,
      );
      await storage.promoteStagingToInstalled(
        patch: 1,
        stagingDirectory: staging,
      );

      final patchPath = storage.patchDirectoryForPatch(1).path;
      final state = UpdateState(
        projectId: 'demo',
        currentAppVersion: '1.0.0',
        activePatch: 1,
        installedPatches: [
          InstalledPatchRecord(
            patch: 1,
            path: patchPath,
            installedAt: DateTime.now().toUtc().toIso8601String(),
            status: InstalledPatchStatus.active,
          ),
        ],
      );

      final resolver = AssetResolver(storage: storage, state: state);
      final text = await resolver.readTextAsset('copy/home_headline.txt');
      expect(text, assetContent);
      expect(
        resolver.resolveImagePath('copy/home_headline.txt'),
        isNotNull,
      );
    });
  });
}
