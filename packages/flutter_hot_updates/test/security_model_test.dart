import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_hot_updates/src/errors.dart';
import 'package:flutter_hot_updates/src/models/update_manifest.dart';
import 'package:hot_updates_manifest/hot_updates_manifest.dart';
import 'package:flutter_hot_updates/src/security/checksum_verifier.dart';
import 'package:flutter_hot_updates/src/security/signature_verifier.dart';
import 'package:flutter_hot_updates/src/storage/storage_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:asn1lib/asn1lib.dart';

void main() {
  group('Security model', () {
    test('verifies canonical manifest signatures across map order changes', () {
      final keyPair = _generateRsaKeyPair();
      final publicKeyPem = _encodePublicKeyPem(keyPair.publicKey);
      final verifier = SignatureVerifier(publicKeyPem: publicKeyPem);

      final manifestA = _buildManifest(config: {'b': 2, 'a': 1});
      final signature = _signManifestPayload(manifestA, keyPair.privateKey);

      final signedA = Map<String, dynamic>.from(manifestA)
        ..['signature'] = signature;
      final signedB = Map<String, dynamic>.from(
        _buildManifest(config: {'a': 1, 'b': 2}),
      )..['signature'] = signature;

      expect(
        () => verifier.verifyManifest(UpdateManifest.fromJson(signedA)),
        returnsNormally,
      );
      expect(
        () => verifier.verifyManifest(UpdateManifest.fromJson(signedB)),
        returnsNormally,
      );
    });

    test('accepts a manifest whose bundle.url was rewritten by hosting', () {
      final keyPair = _generateRsaKeyPair();
      final verifier = SignatureVerifier(
        publicKeyPem: _encodePublicKeyPem(keyPair.publicKey),
      );
      final manifest = _buildManifest();
      final signature = _signManifestPayload(manifest, keyPair.privateKey);

      // The backend rewrites bundle.url to the object-store URL after signing;
      // bundle.sha256 still pins the bytes, so the signature must survive.
      final rehosted = Map<String, dynamic>.from(manifest)
        ..['bundle'] = {
          ...manifest['bundle'] as Map<String, dynamic>,
          'url': 'https://b2.example.com/demo/patch_2/bundle.zip',
        }
        ..['signature'] = signature;

      expect(
        () => verifier.verifyManifest(UpdateManifest.fromJson(rehosted)),
        returnsNormally,
      );
    });

    test('rejects manifests when no public key is configured', () {
      final verifier = SignatureVerifier();
      final manifest = UpdateManifest.fromJson(_buildManifest());

      expect(
        () => verifier.verifyManifest(manifest),
        throwsA(isA<UpdateValidationException>()),
      );
    });

    test('rejects tampered manifests when signature is configured', () {
      final keyPair = _generateRsaKeyPair();
      final verifier = SignatureVerifier(
        publicKeyPem: _encodePublicKeyPem(keyPair.publicKey),
      );
      final manifest = _buildManifest();
      final signature = _signManifestPayload(manifest, keyPair.privateKey);

      final tampered = Map<String, dynamic>.from(manifest)
        ..['config'] = {'showReferral': false}
        ..['signature'] = signature;

      expect(
        () => verifier.verifyManifest(UpdateManifest.fromJson(tampered)),
        throwsA(isA<UpdateValidationException>()),
      );
    });

    test('canonical json checksum ignores map insertion order', () {
      final payload = {
        'b': 2,
        'a': {'y': 2, 'x': 1},
      };
      final canonicalDigest = ChecksumVerifier.sha256Hex(
        utf8.encode(canonicalJsonEncode(payload)),
      );

      final reordered = {
        'a': {'x': 1, 'y': 2},
        'b': 2,
      };

      expect(
        ChecksumVerifier.verifyJsonCanonical(reordered, canonicalDigest),
        isTrue,
      );
    });

    test('rejects zip path traversal entries', () async {
      final tempDir = await Directory.systemTemp.createTemp('hot_updates_zip_');
      final storage = await StorageManager.create(tempDir);
      await storage.initialize();

      final archive = Archive()
        ..addFile(
          ArchiveFile(
            '../evil.txt',
            4,
            Uint8List.fromList(utf8.encode('evil')),
          ),
        );
      final zipBytes = ZipEncoder().encode(archive)!;

      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      expect(
        () => storage.extractZipSafely(
          zipBytes: zipBytes,
          destination: storage.stagingDirectoryForPatch(1),
        ),
        throwsA(isA<UpdateOperationException>()),
      );
    });
  });
}

Map<String, dynamic> _buildManifest({
  Map<String, dynamic> config = const {'showReferral': true},
}) {
  return {
    'schemaVersion': 1,
    'projectId': 'demo',
    'appVersion': '1.0.0',
    'patch': 2,
    'minSupportedAppVersion': '1.0.0',
    'platform': 'android',
    'createdAt': '2026-08-17T00:00:00.000Z',
    'assets': [
      {
        'path': 'images/banner.png',
        'url': 'images/banner.png',
        'sha256': 'abc123',
      },
    ],
    'config': config,
    'bundle': {
      'url': 'https://cdn.example.com/patch.zip',
      'sha256': 'def456',
      'size': 123,
    },
  };
}

AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _generateRsaKeyPair() {
  final secureRandom = _secureRandom();
  final keyGen = RSAKeyGenerator();
  keyGen.init(
    ParametersWithRandom(
      RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
      secureRandom,
    ),
  );
  final pair = keyGen.generateKeyPair();
  return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
    pair.publicKey as RSAPublicKey,
    pair.privateKey as RSAPrivateKey,
  );
}

String _signManifestPayload(
  Map<String, dynamic> manifest,
  RSAPrivateKey privateKey,
) {
  final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
  signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

  final payload = manifestSignaturePayload(manifest);
  final signature = signer.generateSignature(
    Uint8List.fromList(utf8.encode(canonicalJsonEncode(payload))),
  );
  return base64Encode(signature.bytes);
}

SecureRandom _secureRandom() {
  final random = Random.secure();
  final seed = Uint8List.fromList(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );
  final secureRandom = FortunaRandom();
  secureRandom.seed(KeyParameter(seed));
  return secureRandom;
}

String _encodePublicKeyPem(RSAPublicKey publicKey) {
  final publicKeySequence = ASN1Sequence()
    ..add(ASN1Integer(publicKey.modulus!))
    ..add(ASN1Integer(publicKey.exponent!));

  final algorithm = ASN1Sequence()
    ..add(ASN1ObjectIdentifier([1, 2, 840, 113549, 1, 1, 1]))
    ..add(ASN1Null());

  final topLevel = ASN1Sequence()
    ..add(algorithm)
    ..add(ASN1BitString(publicKeySequence.encodedBytes));

  final encoded = base64.encode(topLevel.encodedBytes);
  final buffer = StringBuffer('-----BEGIN PUBLIC KEY-----\n');
  for (var i = 0; i < encoded.length; i += 64) {
    final end = min(i + 64, encoded.length);
    buffer.writeln(encoded.substring(i, end));
  }
  buffer.write('-----END PUBLIC KEY-----\n');
  return buffer.toString();
}
