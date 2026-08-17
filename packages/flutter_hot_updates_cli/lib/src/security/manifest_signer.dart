import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'canonical_json.dart';
import 'rsa_pem_codec.dart';

class ManifestSigner {
  ManifestSigner({required String privateKeyPem})
    : _privateKey = RsaPemCodec.decodePrivateKeyPem(privateKeyPem);

  final RSAPrivateKey _privateKey;

  String signManifestJson(String sourceJson) {
    final decoded = jsonDecode(sourceJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('manifest must be a JSON object');
    }

    return signManifestMap(decoded);
  }

  String signManifestMap(Map<String, dynamic> manifest) {
    final payload = Map<String, dynamic>.from(manifest)..remove('signature');
    final canonicalPayload = canonicalJsonEncode(payload);
    final signatureBytes = _sign(canonicalPayload);

    final signedManifest = Map<String, dynamic>.from(payload)
      ..['signature'] = base64Encode(signatureBytes);
    return canonicalJsonEncode(signedManifest);
  }

  Uint8List _sign(String canonicalPayload) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(_privateKey));
    final signature = signer.generateSignature(
      Uint8List.fromList(utf8.encode(canonicalPayload)),
    );
    return signature.bytes;
  }
}
