import 'package:flutter_hot_updates/src/errors.dart';
import 'package:flutter_hot_updates/src/network/update_checker.dart';
import 'package:flutter_hot_updates/src/platform/app_info.dart';
import 'package:flutter_hot_updates/src/security/signature_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('UpdateChecker.validateManifest', () {
    late UpdateChecker checker;

    setUp(() {
      checker = UpdateChecker(
        projectId: 'demo',
        endpoint: 'https://example.com',
        signatureVerifier: SignatureVerifier(),
      );
    });

    test('rejects wrong project', () {
      final manifest = TestFixtures.buildManifest(
        projectId: 'other',
        platform: 'android',
        patch: 2,
      );

      expect(
        () => checker.validateManifest(
          manifest: manifest,
          appInfo: AppInfo(
            appVersion: '1.0.0',
            buildNumber: '1',
            packageName: 'demo',
            platform: 'android',
          ),
          activePatch: 1,
        ),
        throwsA(isA<UpdateValidationException>()),
      );
    });

    test('rejects wrong platform', () {
      final manifest = TestFixtures.buildManifest(
        projectId: 'demo',
        platform: 'ios',
        patch: 2,
      );

      expect(
        () => checker.validateManifest(
          manifest: manifest,
          appInfo: AppInfo(
            appVersion: '1.0.0',
            buildNumber: '1',
            packageName: 'demo',
            platform: 'android',
          ),
          activePatch: 1,
        ),
        throwsA(isA<UpdateValidationException>()),
      );
    });

    test('rejects unsupported app version', () {
      final manifest = TestFixtures.buildManifest(
        projectId: 'demo',
        platform: 'android',
        patch: 2,
        appVersion: '2.0.0',
      );

      expect(
        () => checker.validateManifest(
          manifest: manifest,
          appInfo: AppInfo(
            appVersion: '1.0.0',
            buildNumber: '1',
            packageName: 'demo',
            platform: 'android',
          ),
          activePatch: 1,
        ),
        throwsA(isA<UpdateValidationException>()),
      );
    });

    test('rejects downgrade patch', () {
      final manifest = TestFixtures.buildManifest(
        projectId: 'demo',
        platform: 'android',
        patch: 1,
      );

      expect(
        () => checker.validateManifest(
          manifest: manifest,
          appInfo: AppInfo(
            appVersion: '1.0.0',
            buildNumber: '1',
            packageName: 'demo',
            platform: 'android',
          ),
          activePatch: 2,
        ),
        throwsA(isA<UpdateValidationException>()),
      );
    });
  });
}
