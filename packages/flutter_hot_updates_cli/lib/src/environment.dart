import 'dart:io';

import 'package:yaml/yaml.dart';

import 'assets/asset_collector.dart';
import 'config/hot_updates_config.dart';
import 'manifest/manifest_builder.dart';
import 'output/static_exporter.dart';

class CliEnvironment {
  CliEnvironment({
    required this.projectRoot,
    required this.configFile,
    required this.assetCollector,
    required this.assetDiffCalculator,
    required this.manifestBuilder,
    required this.staticExporter,
  });

  factory CliEnvironment.fromWorkingDirectory(Directory workingDirectory) {
    final projectRoot = _findProjectRoot(workingDirectory) ?? workingDirectory.absolute;
    final configFile = File('${projectRoot.path}/.hot_updates/hot_updates.yaml');
    return CliEnvironment(
      projectRoot: projectRoot,
      configFile: configFile,
      assetCollector: const AssetCollector(),
      assetDiffCalculator: const AssetDiffCalculator(),
      manifestBuilder: const ManifestBuilder(),
      staticExporter: const StaticExporter(),
    );
  }

  final Directory projectRoot;
  final File configFile;
  final AssetCollector assetCollector;
  final AssetDiffCalculator assetDiffCalculator;
  final ManifestBuilder manifestBuilder;
  final StaticExporter staticExporter;

  HotUpdatesConfig loadConfig() {
    if (!configFile.existsSync()) {
      throw FileSystemException('config not found', configFile.path);
    }
    return HotUpdatesConfig.fromFile(configFile);
  }

  HotUpdatesConfig defaultConfig({
    required String projectId,
    Uri? endpoint,
  }) {
    return HotUpdatesConfig.defaults(projectId: projectId, endpoint: endpoint);
  }

  /// Host app version taken from `pubspec.yaml` (`version: 1.2.3+45` yields
  /// `1.2.3`, the build number is not part of the store version). Returns null
  /// when there is no usable `version:` entry: the runtime only installs a patch
  /// whose `appVersion` matches the running app exactly, so callers must report
  /// that instead of guessing a value.
  String? resolveAppVersion() {
    final pubspec = File('${projectRoot.path}/pubspec.yaml');
    if (!pubspec.existsSync()) {
      return null;
    }
    final decoded = loadYaml(pubspec.readAsStringSync());
    if (decoded is! YamlMap) {
      return null;
    }
    final version = decoded['version'];
    if (version == null) {
      return null;
    }
    final normalized = version.toString().trim().split('+').first.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static Directory? _findProjectRoot(Directory dir) {
    // ponytail: naive upward search, add .git check if needed
    var current = dir;
    for (var i = 0; i < 10; i++) {
      if (File('${current.path}/pubspec.yaml').existsSync()) {
        return current;
      }
      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
    return null;
  }
}
