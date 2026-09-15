import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:hot_updates_manifest/hot_updates_manifest.dart';
import 'package:pointycastle/export.dart';

import '../models/update_manifest.dart';

/// Deterministic RSA key pair for tests and the example fixture.
class TestSigning {
  TestSigning._();

  static late final AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _keyPair =
      _generateKeyPair();
  static late final String publicKeyPem = _encodePublicKeyPem(_keyPair.publicKey);
  static late final RSAPrivateKey _privateKey = _keyPair.privateKey;

  static UpdateManifest signManifest(UpdateManifest manifest) {
    final json = manifest.toJson(includeSignature: false);
    final signature = _signManifestMap(json);
    return UpdateManifest.fromJson({...json, 'signature': signature});
  }

  static String signManifestJson(Map<String, dynamic> manifest) {
    final signature = _signManifestMap(manifest);
    return jsonEncode({...manifest, 'signature': signature});
  }

  static String _signManifestMap(Map<String, dynamic> manifest) {
    final payload = manifestSignaturePayload(manifest);
    final canonicalPayload = canonicalJsonEncode(payload);
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(_privateKey));
    final signature = signer.generateSignature(
      Uint8List.fromList(utf8.encode(canonicalPayload)),
    );
    return base64Encode(signature.bytes);
  }

  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _generateKeyPair() {
    final secureRandom = FortunaRandom();
    secureRandom.seed(KeyParameter(Uint8List.fromList(List.filled(32, 42))));
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

  static String _encodePublicKeyPem(RSAPublicKey publicKey) {
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
}
