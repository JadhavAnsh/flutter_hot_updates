import 'dart:convert';

/// Canonical JSON encoding with recursively sorted object keys.
String canonicalJsonEncode(Object? value) {
  return jsonEncode(_canonicalize(value));
}

Object? _canonicalize(Object? value) {
  if (value is Map<String, dynamic>) {
    final sortedKeys = value.keys.toList()..sort();
    return <String, dynamic>{
      for (final key in sortedKeys) key: _canonicalize(value[key]),
    };
  }

  if (value is Map) {
    return _canonicalize(Map<String, dynamic>.from(value));
  }

  if (value is List) {
    return value.map(_canonicalize).toList(growable: false);
  }

  return value;
}
