import 'dart:convert';
import 'dart:io';

import 'package:flutter_hot_updates/src/config/remote_config.dart';
import 'package:flutter_hot_updates/src/errors.dart';
import 'package:flutter_hot_updates/src/models/update_state.dart';
import 'package:flutter_hot_updates/src/security/checksum_verifier.dart';
import 'package:flutter_hot_updates/src/storage/storage_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('ChecksumVerifier', () {
    test('verifies matching sha256 hex', () {
      final bytes = utf8.encode('hello patch');
      final digest = ChecksumVerifier.sha256Hex(bytes);
      expect(ChecksumVerifier.verifyHex(bytes, digest), isTrue);
      expect(ChecksumVerifier.verifyHex(bytes, 'deadbeef'), isFalse);
    });
  });

  group('RemoteConfig', () {
    test('returns typed defaults when key is missing', () {
      final config = RemoteConfig();
      expect(config.getBool('enabled', defaultValue: false), isFalse);
      expect(config.getString('title', defaultValue: 'fallback'), 'fallback');
      expect(config.getInt('count', defaultValue: 3), 3);
    });
  });

  group('StorageManager', () {
    late Directory tempDir;
    late StorageManager storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hot_updates_test_');
      storage = await StorageManager.create(tempDir);
      await storage.initialize();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists and reloads state', () async {
      final state = UpdateState.initial(
        projectId: 'demo',
        currentAppVersion: '1.0.0',
      );
      await storage.saveState(state);

      final reloaded = await StorageManager.create(tempDir);
      await reloaded.initialize();
      expect(reloaded.state?.projectId, 'demo');
      expect(reloaded.state?.activePatch, 0);
    });

    test('installs patch from zip and verifies assets', () async {
      final assetContent = 'updated banner';
      final assetBytes = utf8.encode(assetContent);
      final assetSha = TestFixtures.sha256Hex(assetBytes);

      var manifest = TestFixtures.buildManifest(
        projectId: 'demo',
        platform: 'android',
        patch: 1,
        assets: [
          {
            'path': 'images/banner.png',
            'url': 'images/banner.png',
            'sha256': assetSha,
          },
        ],
      );

      final bundle = await TestFixtures.createPatchBundle(
        root: tempDir,
        manifest: manifest,
        assetContents: {'images/banner.png': assetContent},
      );

      manifest = TestFixtures.buildManifest(
        projectId: 'demo',
        platform: 'android',
        patch: 1,
        assets: [
          {
            'path': 'images/banner.png',
            'url': 'images/banner.png',
            'sha256': assetSha,
          },
        ],
        bundleSha256: bundle.zipSha256,
        bundleSize: bundle.zipSize,
      );

      final zipBytes = await bundle.zipFile.readAsBytes();
      final staging = storage.stagingDirectoryForPatch(1);
      await storage.extractZipSafely(zipBytes: zipBytes, destination: staging);
      await storage.verifyInstalledAssets(manifest, staging);
      await storage.promoteStagingToInstalled(
        patch: 1,
        stagingDirectory: staging,
      );

      final installed = storage.patchDirectoryForPatch(1);
      final assetFile = File('${installed.path}/assets/images/banner.png');
      expect(await assetFile.readAsString(), assetContent);
    });

    test('rejects corrupt asset checksums', () async {
      final manifest = TestFixtures.buildManifest(
        projectId: 'demo',
        platform: 'android',
        patch: 2,
        assets: [
          {
            'path': 'images/banner.png',
            'url': 'images/banner.png',
            'sha256': 'deadbeef',
          },
        ],
        bundleSha256: 'abc',
        bundleSize: 10,
      );

      final bundle = await TestFixtures.createPatchBundle(
        root: tempDir,
        manifest: manifest,
        assetContents: {'images/banner.png': 'corrupt me'},
      );

      final staging = storage.stagingDirectoryForPatch(2);
      await storage.extractZipSafely(
        zipBytes: await bundle.zipFile.readAsBytes(),
        destination: staging,
      );

      expect(
        () => storage.verifyInstalledAssets(manifest, staging),
        throwsA(isA<UpdateOperationException>()),
      );
    });

    test('recovers incomplete install journal entries', () async {
      await storage.installJournal.begin(3, tempPath: storage.stagingDirectoryForPatch(3).path);
      await storage.installJournal.updateStage(
        3,
        InstallJournalStage.extracting,
      );
      await File(storage.downloadFileForPatch(3).path).create(recursive: true);

      final reloaded = await StorageManager.create(tempDir);
      await reloaded.initialize();

      expect(reloaded.installJournal.incompleteEntries(), isEmpty);
      expect(await storage.downloadFileForPatch(3).exists(), isFalse);
    });
  });
}
