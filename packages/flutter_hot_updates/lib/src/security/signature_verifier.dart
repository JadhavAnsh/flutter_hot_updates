import 'dart:convert';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:pointycastle/export.dart';

import '../errors.dart';
import '../models/update_manifest.dart';

/// RSA signature verification hooks for manifest integrity.
class SignatureVerifier {
  SignatureVerifier({this.publicKeyPem});

  final String? publicKeyPem;

  bool get isConfigured =>
      publicKeyPem != null && publicKeyPem!.trim().isNotEmpty;

  void verifyManifest(UpdateManifest manifest) {
    if (!isConfigured) {
      return;
    }

    final signature = manifest.signature;
    if (signature == null || signature.isEmpty) {
      throw const UpdateValidationException('manifest signature is required');
    }

    final payload = utf8.encode(jsonEncode(manifest.canonicalPayload()));
    final signatureBytes = base64.decode(signature);
    final publicKey = _parsePublicKey(publicKeyPem!);

    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

    final verified = signer.verifySignature(
      Uint8List.fromList(payload),
      RSASignature(signatureBytes),
    );

    if (!verified) {
      throw const UpdateValidationException('invalid manifest signature');
    }
  }

  RSAPublicKey _parsePublicKey(String pem) {
    final normalized = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();

    final keyBytes = base64.decode(normalized);
    final parser = ASN1Parser(keyBytes);
    final topLevel = parser.nextObject() as ASN1Sequence;
    final bitString = topLevel.elements![1] as ASN1BitString;
    final innerParser = ASN1Parser(bitString.contentBytes());
    final publicKeySequence = innerParser.nextObject() as ASN1Sequence;

    final modulus =
        (publicKeySequence.elements![0] as ASN1Integer).valueAsBigInteger;
    final exponentValue =
        (publicKeySequence.elements![1] as ASN1Integer).intValue;
    if (exponentValue == null) {
      throw const UpdateValidationException('invalid manifest public key');
    }

    return RSAPublicKey(modulus, BigInt.from(exponentValue));
  }
}
