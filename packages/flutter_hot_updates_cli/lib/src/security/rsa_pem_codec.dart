import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:pointycastle/export.dart';

class GeneratedKeyPair {
  const GeneratedKeyPair({
    required this.privateKeyPem,
    required this.publicKeyPem,
  });

  final String privateKeyPem;
  final String publicKeyPem;
}

class RsaPemCodec {
  const RsaPemCodec._();

  static GeneratedKeyPair generate({int bitLength = 2048}) {
    final secureRandom = _secureRandom();
    final keyGen = RSAKeyGenerator();
    keyGen.init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), bitLength, 64),
        secureRandom,
      ),
    );

    final pair = keyGen.generateKeyPair();
    final publicKey = pair.publicKey;
    final privateKey = pair.privateKey;

    return GeneratedKeyPair(
      privateKeyPem: encodePrivateKeyPem(privateKey),
      publicKeyPem: encodePublicKeyPem(publicKey),
    );
  }

  static RSAPrivateKey decodePrivateKeyPem(String pem) {
    final normalized = _stripPem(pem, 'PRIVATE KEY');
    final keyBytes = base64.decode(normalized);
    final parser = ASN1Parser(keyBytes);
    final sequence = parser.nextObject() as ASN1Sequence;

    final modulus = (sequence.elements[1] as ASN1Integer).valueAsBigInteger;
    final privateExponent =
        (sequence.elements[3] as ASN1Integer).valueAsBigInteger;
    final p = (sequence.elements[4] as ASN1Integer).valueAsBigInteger;
    final q = (sequence.elements[5] as ASN1Integer).valueAsBigInteger;

    return RSAPrivateKey(modulus, privateExponent, p, q);
  }

  static RSAPublicKey decodePublicKeyPem(String pem) {
    final normalized = _stripPem(pem, 'PUBLIC KEY');
    final keyBytes = base64.decode(normalized);
    final parser = ASN1Parser(keyBytes);
    final topLevel = parser.nextObject() as ASN1Sequence;
    final bitString = topLevel.elements[1] as ASN1BitString;
    final innerParser = ASN1Parser(bitString.contentBytes());
    final publicKeySequence = innerParser.nextObject() as ASN1Sequence;

    final modulus =
        (publicKeySequence.elements[0] as ASN1Integer).valueAsBigInteger;
    final exponent =
        (publicKeySequence.elements[1] as ASN1Integer).valueAsBigInteger;

    return RSAPublicKey(modulus, exponent);
  }

  static String encodePrivateKeyPem(RSAPrivateKey privateKey) {
    final modulus = privateKey.modulus;
    final privateExponent = privateKey.privateExponent;
    final p = privateKey.p;
    final q = privateKey.q;
    if (modulus == null || privateExponent == null || p == null || q == null) {
      throw ArgumentError('RSA private key is incomplete');
    }

    final dP = privateExponent.remainder(p - BigInt.one);
    final dQ = privateExponent.remainder(q - BigInt.one);
    final qInv = q.modInverse(p);
    final publicExponent = privateKey.publicExponent;
    if (publicExponent == null) {
      throw ArgumentError('RSA private key is incomplete');
    }

    final sequence = ASN1Sequence()
      ..add(ASN1Integer(BigInt.zero))
      ..add(ASN1Integer(modulus))
      ..add(ASN1Integer(publicExponent))
      ..add(ASN1Integer(privateExponent))
      ..add(ASN1Integer(p))
      ..add(ASN1Integer(q))
      ..add(ASN1Integer(dP))
      ..add(ASN1Integer(dQ))
      ..add(ASN1Integer(qInv));

    return _wrapPem('PRIVATE KEY', sequence.encodedBytes);
  }

  static String encodePublicKeyPem(RSAPublicKey publicKey) {
    final modulus = publicKey.modulus;
    final exponent = publicKey.exponent;
    if (modulus == null || exponent == null) {
      throw ArgumentError('RSA public key is incomplete');
    }

    final publicKeySequence = ASN1Sequence()
      ..add(ASN1Integer(modulus))
      ..add(ASN1Integer(exponent));

    final algorithm = ASN1Sequence()
      ..add(ASN1ObjectIdentifier([1, 2, 840, 113549, 1, 1, 1]))
      ..add(ASN1Null());

    final topLevel = ASN1Sequence()
      ..add(algorithm)
      ..add(ASN1BitString(publicKeySequence.encodedBytes));

    return _wrapPem('PUBLIC KEY', topLevel.encodedBytes);
  }

  static String encodePublicKeyPemFromPrivateKey(RSAPrivateKey privateKey) {
    final modulus = privateKey.modulus;
    final publicExponent = privateKey.publicExponent;
    if (modulus == null || publicExponent == null) {
      throw ArgumentError('RSA private key is incomplete');
    }
    return encodePublicKeyPem(RSAPublicKey(modulus, publicExponent));
  }

  static String _wrapPem(String label, List<int> derBytes) {
    final encoded = base64.encode(derBytes);
    final buffer = StringBuffer('-----BEGIN $label-----\n');
    for (var i = 0; i < encoded.length; i += 64) {
      final end = min(i + 64, encoded.length);
      buffer.writeln(encoded.substring(i, end));
    }
    buffer.write('-----END $label-----\n');
    return buffer.toString();
  }

  static String _stripPem(String pem, String label) {
    return pem
        .replaceAll('-----BEGIN $label-----', '')
        .replaceAll('-----END $label-----', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();
  }

  static SecureRandom _secureRandom() {
    final random = Random.secure();
    final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    final secureRandom = FortunaRandom();
    secureRandom.seed(KeyParameter(seed));
    return secureRandom;
  }
}
