import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../models/update_state.dart';
import '../storage/storage_manager.dart';

/// Resolves asset paths from the active patch with bundled fallbacks.
class AssetResolver {
  AssetResolver({
    StorageManager? storage,
    required UpdateState? state,
  })  : _storage = storage,
        _state = state;

  final StorageManager? _storage;
  UpdateState? _state;

  void updateState(UpdateState? state) {
    _state = state;
  }

  Directory? get activePatchDirectory {
    final activePatch = _state?.activePatch ?? 0;
    if (activePatch <= 0) {
      return null;
    }

    final record = _state?.recordForPatch(activePatch);
    if (record != null) {
      return Directory(record.path);
    }

    final storage = _storage;
    if (storage == null) {
      return null;
    }

    final patchDir = storage.patchDirectoryForPatch(activePatch);
    if (patchDir.existsSync()) {
      return patchDir;
    }
    return null;
  }

  Future<File?> resolveFile(String assetPath) async {
    final normalized = _normalizeAssetPath(assetPath);
    final patchDirectory = activePatchDirectory;
    if (patchDirectory != null) {
      final patchFile = File(p.join(patchDirectory.path, 'assets', normalized));
      if (await patchFile.exists()) {
        return patchFile;
      }
    }
    return null;
  }

  Future<String?> readTextAsset(String assetPath) async {
    final patchFile = await resolveFile(assetPath);
    if (patchFile != null) {
      return patchFile.readAsString();
    }

    try {
      return await rootBundle.loadString(assetPath);
    } on FlutterError {
      return null;
    }
  }

  Future<ImageProvider?> resolveImageProvider(String assetPath) async {
    final patchFile = await resolveFile(assetPath);
    if (patchFile != null) {
      return FileImage(patchFile);
    }
    return AssetImage(assetPath);
  }

  String? resolveImagePath(String assetPath) {
    final normalized = _normalizeAssetPath(assetPath);
    final patchDirectory = activePatchDirectory;
    if (patchDirectory == null) {
      return null;
    }

    final patchFile = File(p.join(patchDirectory.path, 'assets', normalized));
    if (patchFile.existsSync()) {
      return patchFile.path;
    }
    return null;
  }

  static String _normalizeAssetPath(String assetPath) {
    var normalized = assetPath.replaceAll('\\', '/');
    if (normalized.startsWith('assets/')) {
      normalized = normalized.substring('assets/'.length);
    }
    return normalized;
  }
}
