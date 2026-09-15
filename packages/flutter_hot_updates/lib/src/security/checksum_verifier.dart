import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:hot_updates_manifest/hot_updates_manifest.dart';

/// SHA256 checksum helpers.
class ChecksumVerifier {
  const ChecksumVerifier._();

  static String sha256Hex(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  static String sha256HexFromFileBytes(Uint8List bytes) => sha256Hex(bytes);

  static bool verifyHex(List<int> bytes, String expectedHex) {
    final actual = sha256Hex(bytes);
    return actual.toLowerCase() == expectedHex.toLowerCase();
  }

  static bool verifyJsonCanonical(
    Map<String, dynamic> payload,
    String expectedHex,
  ) {
    final canonical = canonicalJsonEncode(payload);
    return verifyHex(utf8.encode(canonical), expectedHex);
  }
}
