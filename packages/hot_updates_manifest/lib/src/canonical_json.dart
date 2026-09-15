import 'dart:convert';

/// Canonical JSON encoding with recursively sorted object keys.
String canonicalJsonEncode(Object? value) {
  return jsonEncode(_canonicalize(value));
}

/// Strips the fields that hosting may rewrite from a manifest map, leaving the
/// payload the signature is computed over.
///
/// `bundle.url` is excluded: the backend rewrites it to the object-store/CDN URL
/// after the CLI has signed the manifest. Integrity still holds because the
/// signed `bundle.sha256` pins the bytes, and the download is checksum-verified
/// against it before install.
Map<String, dynamic> manifestSignaturePayload(Map<String, dynamic> manifest) {
  final payload = Map<String, dynamic>.from(manifest)..remove('signature');
  final bundle = payload['bundle'];
  if (bundle is Map) {
    payload['bundle'] = Map<String, dynamic>.from(bundle)..remove('url');
  }
  return payload;
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
