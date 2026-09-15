import 'dart:convert';
import 'dart:io';

import 'package:flutter_hot_updates/flutter_hot_updates.dart';
import 'package:flutter_hot_updates/src/models/update_event.dart';
import 'package:flutter_hot_updates/src/platform/app_info.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_hot_updates/testing.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HotUpdates end-to-end', () {
    late Directory tempDir;
    late String baseUrl;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hot_updates_e2e_');

      final assetContent = 'patched banner';
      final assetBytes = utf8.encode(assetContent);
      final assetSha = TestFixtures.sha256Hex(assetBytes);

      var manifest = TestFixtures.buildManifest(
        projectId: 'demo',
        platform: 'android',
        patch: 1,
        config: {'showReferral': true, 'theme': 'festival'},
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
        config: {'showReferral': true, 'theme': 'festival'},
        assets: [
          {
            'path': 'images/banner.png',
            'url': 'images/banner.png',
            'sha256': assetSha,
          },
        ],
        bundleUrl: 'patch_1.zip',
        bundleSha256: bundle.zipSha256,
        bundleSize: bundle.zipSize,
      );
      manifest = TestSigning.signManifest(manifest);
      await File('${tempDir.path}/manifest.json')
          .writeAsString(manifest.toJsonString());
      baseUrl = Uri.directory(tempDir.path).toString();
    });

    tearDown(() async {
      await HotUpdates.resetForTest();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('initialize, check, download, install, and activate', () async {
      final events = <UpdateEventType>[];

      await HotUpdates.initialize(
        projectId: 'demo',
        endpoint: baseUrl,
        publicKey: TestSigning.publicKeyPem,
        storageRootOverride: tempDir,
        appInfoOverride: AppInfo(
          appVersion: '1.0.0',
          buildNumber: '1',
          packageName: 'demo',
          platform: 'android',
        ),
      );

      final subscription = HotUpdates.events.listen((event) {
        events.add(event.type);
      });

      final checkResult = await HotUpdates.checkForUpdates();
      expect(checkResult.updateAvailable, isTrue);
      expect(checkResult.update?.patch, 1);

      await HotUpdates.downloadAndInstall(checkResult.update!);
      await HotUpdates.activate();

      expect(HotUpdates.config.getBool('showReferral'), isTrue);
      expect(HotUpdates.config.getString('theme'), 'festival');
      expect(events, contains(UpdateEventType.checking));
      expect(events, contains(UpdateEventType.available));
      expect(events, contains(UpdateEventType.downloading));
      expect(events, contains(UpdateEventType.installed));
      expect(events, contains(UpdateEventType.activated));

      final text = await HotUpdates.assetResolver.readTextAsset(
        'images/banner.png',
      );
      expect(text, 'patched banner');

      await subscription.cancel();
    });
  });
}
