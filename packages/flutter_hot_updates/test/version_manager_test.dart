import 'package:flutter_hot_updates/src/version/version_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VersionManager', () {
    test('compare orders semantic versions', () {
      expect(VersionManager.compare('1.0.0', '1.0.1'), lessThan(0));
      expect(VersionManager.compare('1.2.0', '1.1.9'), greaterThan(0));
      expect(VersionManager.compare('1.0.0', '1.0.0'), 0);
    });

    test('isCompatibleAppVersion requires exact app version match', () {
      expect(
        VersionManager.isCompatibleAppVersion(
          currentAppVersion: '1.0.0',
          manifestAppVersion: '1.0.0',
          minSupportedAppVersion: '1.0.0',
        ),
        isTrue,
      );

      expect(
        VersionManager.isCompatibleAppVersion(
          currentAppVersion: '1.0.0',
          manifestAppVersion: '2.0.0',
          minSupportedAppVersion: '1.0.0',
        ),
        isFalse,
      );
    });

    test('isPatchEligible rejects downgrades by default', () {
      expect(
        VersionManager.isPatchEligible(remotePatch: 2, localPatch: 1),
        isTrue,
      );
      expect(
        VersionManager.isPatchEligible(remotePatch: 1, localPatch: 2),
        isFalse,
      );
      expect(
        VersionManager.isPatchEligible(
          remotePatch: 1,
          localPatch: 2,
          allowDowngrade: true,
        ),
        isTrue,
      );
    });
  });
}
