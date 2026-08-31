import 'dart:io';

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
