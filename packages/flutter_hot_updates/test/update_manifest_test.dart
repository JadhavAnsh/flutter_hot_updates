import 'package:flutter_hot_updates/src/errors.dart';
import 'package:flutter_hot_updates/src/models/update_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateManifest', () {
    test('parses a valid manifest', () {
      final manifest = UpdateManifest.fromJson({
        'schemaVersion': 1,
        'projectId': 'demo',
        'appVersion': '1.0.1',
        'patch': 2,
        'minSupportedAppVersion': '1.0.1',
        'platform': 'android',
        'createdAt': '2026-08-17T00:00:00.000Z',
        'assets': [
          {
            'path': 'images/banner.png',
            'url': 'https://cdn.example.com/banner.png',
            'sha256': 'abc123',
          },
        ],
        'config': {'showReferral': true},
        'bundle': {
          'url': 'https://cdn.example.com/patch_2.zip',
          'sha256': 'def456',
          'size': 100,
        },
      });

      expect(manifest.projectId, 'demo');
      expect(manifest.patch, 2);
      expect(manifest.assets, hasLength(1));
      expect(manifest.config['showReferral'], isTrue);
    });

    test('rejects unsupported schema version', () {
      expect(
        () => UpdateManifest.fromJson({'schemaVersion': 2}),
        throwsA(isA<UpdateValidationException>()),
      );
    });

    test('rejects missing projectId', () {
      expect(
        () => UpdateManifest.fromJson({'schemaVersion': 1}),
        throwsA(isA<UpdateValidationException>()),
      );
    });

    test('rejects missing bundle', () {
      expect(
        () => UpdateManifest.fromJson({
          'schemaVersion': 1,
          'projectId': 'demo',
          'appVersion': '1.0.1',
          'patch': 1,
          'minSupportedAppVersion': '1.0.1',
          'platform': 'android',
          'createdAt': '2026-08-17T00:00:00.000Z',
          'assets': [],
          'config': {},
        }),
        throwsA(isA<UpdateValidationException>()),
      );
    });
  });
}
