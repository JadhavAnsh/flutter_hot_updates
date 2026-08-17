import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

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
    final canonical = jsonEncode(_sortMap(payload));
    return verifyHex(utf8.encode(canonical), expectedHex);
  }

  static Map<String, dynamic> _sortMap(Map<String, dynamic> input) {
    final sortedKeys = input.keys.toList()..sort();
    final result = <String, dynamic>{};
    for (final key in sortedKeys) {
      final value = input[key];
      if (value is Map<String, dynamic>) {
        result[key] = _sortMap(value);
      } else if (value is Map) {
        result[key] = _sortMap(Map<String, dynamic>.from(value));
      } else if (value is List) {
        result[key] = value
            .map(
              (item) => item is Map<String, dynamic>
                  ? _sortMap(item)
                  : item is Map
                      ? _sortMap(Map<String, dynamic>.from(item))
                      : item,
            )
            .toList();
      } else {
        result[key] = value;
      }
    }
    return result;
  }
}
