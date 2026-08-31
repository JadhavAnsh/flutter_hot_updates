import 'dart:io';

import 'package:crypto/crypto.dart';

class CollectedAsset {
  const CollectedAsset({
    required this.path,
    required this.file,
    required this.sha256,
    required this.size,
  });

  final String path;
  final File file;
  final String sha256;
  final int size;
}

class AssetCollector {
  const AssetCollector();

  Future<List<CollectedAsset>> collect({
    required Directory projectRoot,
    required List<String> includePatterns,
    required List<String> excludePatterns,
  }) async {
    final assets = <String, CollectedAsset>{};
    final files = projectRoot
        .listSync(recursive: true, followLinks: false)
        .whereType<File>();

    for (final file in files) {
      final relative = _relativePath(file.path, projectRoot.path);
      if (!_matches(relative, includePatterns)) continue;
      if (_matches(relative, excludePatterns)) continue;

      final manifestPath = _stripAssetRoot(relative);
      final bytes = await file.readAsBytes();
      assets[relative] = CollectedAsset(
        path: manifestPath,
        file: file,
        sha256: sha256.convert(bytes).toString(),
        size: bytes.length,
      );
    }

    final list = assets.values.toList(growable: false)
      ..sort((a, b) => a.path.compareTo(b.path));
    return list;
  }

  Map<String, CollectedAsset> asMap(List<CollectedAsset> assets) {
    return {for (final asset in assets) asset.path: asset};
  }

  String _relativePath(String path, String from) {
    final normalized = path.replaceAll('\\', '/');
    final base = from.replaceAll('\\', '/');
    return normalized.startsWith(base)
        ? normalized.substring(base.length + 1)
        : normalized;
  }

  bool _matches(String path, List<String> patterns) {
    // ponytail: glob replaced with simple contains/endsWith, add glob when patterns need **
    return patterns.any((p) => path.contains(p.replaceAll('**/', '').replaceAll('*', '')));
  }

  String _stripAssetRoot(String path) {
    return path.startsWith('assets/') ? path.substring(7) : path;
  }
}

class AssetDiff {
  const AssetDiff({
    required this.added,
    required this.modified,
    required this.removed,
    required this.unchanged,
  });

  final List<String> added;
  final List<String> modified;
  final List<String> removed;
  final List<String> unchanged;

  bool get isEmpty => added.isEmpty && modified.isEmpty && removed.isEmpty;
}

class AssetDiffCalculator {
  const AssetDiffCalculator();

  AssetDiff compare({
    required Map<String, CollectedAsset> previous,
    required Map<String, CollectedAsset> current,
  }) {
    final added = <String>[];
    final modified = <String>[];
    final removed = <String>[];
    final unchanged = <String>[];

    for (final entry in current.entries) {
      final prev = previous[entry.key];
      if (prev == null) {
        added.add(entry.key);
      } else if (prev.sha256 != entry.value.sha256) {
        modified.add(entry.key);
      } else {
        unchanged.add(entry.key);
      }
    }

    for (final path in previous.keys) {
      if (!current.containsKey(path)) removed.add(path);
    }

    return AssetDiff(
      added: added..sort(),
      modified: modified..sort(),
      removed: removed..sort(),
      unchanged: unchanged..sort(),
    );
  }
}
