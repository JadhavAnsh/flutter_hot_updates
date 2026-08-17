import '../models/update_manifest.dart';

/// Remote configuration values from the active manifest.
class RemoteConfig {
  RemoteConfig({Map<String, dynamic>? values}) : _values = Map.of(values ?? {});

  Map<String, dynamic> _values;

  Map<String, dynamic> get values => Map.unmodifiable(_values);

  void replaceAll(Map<String, dynamic> values) {
    _values = Map.of(values);
  }

  void clear() {
    _values = {};
  }

  bool? getBool(String key, {bool? defaultValue}) {
    final value = _values[key];
    if (value is bool) {
      return value;
    }
    return defaultValue;
  }

  String? getString(String key, {String? defaultValue}) {
    final value = _values[key];
    if (value is String) {
      return value;
    }
    if (value != null) {
      return value.toString();
    }
    return defaultValue;
  }

  int? getInt(String key, {int? defaultValue}) {
    final value = _values[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  double? getDouble(String key, {double? defaultValue}) {
    final value = _values[key];
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  Map<String, dynamic>? getMap(String key, {Map<String, dynamic>? defaultValue}) {
    final value = _values[key];
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return defaultValue;
  }

  dynamic getValue(String key, {dynamic defaultValue}) {
    return _values.containsKey(key) ? _values[key] : defaultValue;
  }

  void applyManifest(UpdateManifest? manifest) {
    if (manifest == null) {
      clear();
      return;
    }
    replaceAll(manifest.config);
  }
}
