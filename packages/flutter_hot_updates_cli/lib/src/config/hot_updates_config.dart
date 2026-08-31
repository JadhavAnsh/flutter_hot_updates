import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class HotUpdatesAssetGlobs {
  const HotUpdatesAssetGlobs({
    required this.include,
    required this.exclude,
  });

  final List<String> include;
  final List<String> exclude;

  Map<String, dynamic> toJson() => {
        'include': include,
        'exclude': exclude,
      };
}

class HotUpdatesSigningConfig {
  const HotUpdatesSigningConfig({required this.privateKeyPath});

  final String privateKeyPath;

  Map<String, dynamic> toJson() => {
        'private_key_path': privateKeyPath,
      };
}

class HotUpdatesOutputConfig {
  const HotUpdatesOutputConfig({required this.directory});

  final String directory;

  Map<String, dynamic> toJson() => {
        'directory': directory,
      };
}

class HotUpdatesAuthConfig {
  const HotUpdatesAuthConfig({required this.tokenPath});

  final String tokenPath;

  Map<String, dynamic> toJson() => {
        'token_path': tokenPath,
      };
}

class HotUpdatesConfig {
  const HotUpdatesConfig({
    required this.projectId,
    required this.platforms,
    required this.assets,
    required this.signing,
    required this.output,
    required this.auth,
    this.endpoint,
  });

  factory HotUpdatesConfig.defaults({
    required String projectId,
    Uri? endpoint,
  }) {
    return HotUpdatesConfig(
      projectId: projectId,
      endpoint: endpoint,
      platforms: const ['android'],
      assets: const HotUpdatesAssetGlobs(
        include: ['assets/**'],
        exclude: <String>[],
      ),
      signing: const HotUpdatesSigningConfig(
        privateKeyPath: '.hot_updates/private_key.pem',
      ),
      output: const HotUpdatesOutputConfig(
        directory: '.hot_updates/build',
      ),
      auth: const HotUpdatesAuthConfig(tokenPath: '.hot_updates/token.json'),
    );
  }

  factory HotUpdatesConfig.fromFile(File file) {
    final baseDirectory = file.parent.parent.path;
    final content = file.readAsStringSync();
    final decoded = loadYaml(content);
    if (decoded is! YamlMap) {
      throw const FormatException('hot_updates config must be a YAML object');
    }
    return HotUpdatesConfig.fromYaml(
      decoded,
      baseDirectory: baseDirectory,
    );
  }

  factory HotUpdatesConfig.fromYaml(
    YamlMap yaml, {
    required String baseDirectory,
  }) {
    final projectId = _string(yaml['project_id'], 'project_id');
    final endpoint = _optionalString(yaml['endpoint']);
    final platforms = _stringList(yaml['platforms'], defaultValue: const ['android']);

    final assets = yaml['assets'];
    final signing = yaml['signing'];
    final output = yaml['output'];
    final auth = yaml['auth'];

    return HotUpdatesConfig(
      projectId: projectId,
      endpoint: endpoint == null ? null : Uri.parse(endpoint),
      platforms: platforms,
      assets: HotUpdatesAssetGlobs(
        include: _stringList(
          assets is YamlMap ? assets['include'] : null,
          defaultValue: const ['assets/**'],
        ),
        exclude: _stringList(
          assets is YamlMap ? assets['exclude'] : null,
          defaultValue: const <String>[],
        ),
      ),
      signing: HotUpdatesSigningConfig(
        privateKeyPath: _nestedString(
          signing,
          ['private_key_path'],
          defaultValue: '.hot_updates/private_key.pem',
        ),
      ),
      output: HotUpdatesOutputConfig(
        directory: _nestedString(
          output,
          ['directory'],
          defaultValue: '.hot_updates/build',
        ),
      ),
      auth: HotUpdatesAuthConfig(
        tokenPath: _nestedString(
          auth,
          ['token_path'],
          defaultValue: '.hot_updates/token.json',
        ),
      ),
    );
  }

  final String projectId;
  final Uri? endpoint;
  final List<String> platforms;
  final HotUpdatesAssetGlobs assets;
  final HotUpdatesSigningConfig signing;
  final HotUpdatesOutputConfig output;
  final HotUpdatesAuthConfig auth;

  Map<String, dynamic> toYamlMap() => {
        'project_id': projectId,
        if (endpoint != null) 'endpoint': endpoint.toString(),
        'platforms': platforms,
        'assets': assets.toJson(),
        'signing': signing.toJson(),
        'output': output.toJson(),
        'auth': auth.toJson(),
      };

  String toYamlString() {
    final buffer = StringBuffer();
    buffer.writeln('project_id: $projectId');
    if (endpoint != null) {
      buffer.writeln('endpoint: ${jsonEncode(endpoint.toString())}');
    }
    buffer.writeln('platforms:');
    for (final platform in platforms) {
      buffer.writeln('  - $platform');
    }
    buffer.writeln('assets:');
    buffer.writeln('  include:');
    for (final pattern in assets.include) {
      buffer.writeln('    - $pattern');
    }
    buffer.writeln('  exclude:');
    for (final pattern in assets.exclude) {
      buffer.writeln('    - $pattern');
    }
    buffer.writeln('signing:');
    buffer.writeln('  private_key_path: ${signing.privateKeyPath}');
    buffer.writeln('output:');
    buffer.writeln('  directory: ${output.directory}');
    buffer.writeln('auth:');
    buffer.writeln('  token_path: ${auth.tokenPath}');
    return buffer.toString();
  }

  HotUpdatesConfig copyWith({
    String? projectId,
    Uri? endpoint,
    List<String>? platforms,
    HotUpdatesAssetGlobs? assets,
    HotUpdatesSigningConfig? signing,
    HotUpdatesOutputConfig? output,
    HotUpdatesAuthConfig? auth,
  }) {
    return HotUpdatesConfig(
      projectId: projectId ?? this.projectId,
      endpoint: endpoint ?? this.endpoint,
      platforms: platforms ?? this.platforms,
      assets: assets ?? this.assets,
      signing: signing ?? this.signing,
      output: output ?? this.output,
      auth: auth ?? this.auth,
    );
  }

  File configFile(Directory projectRoot) =>
      File(p.join(projectRoot.path, '.hot_updates', 'hot_updates.yaml'));

  File privateKeyFile(Directory projectRoot) =>
      File(p.join(projectRoot.path, signing.privateKeyPath));

  File tokenFile(Directory projectRoot) =>
      File(p.join(projectRoot.path, auth.tokenPath));

  Directory outputDirectory(Directory projectRoot) =>
      Directory(p.join(projectRoot.path, output.directory));

  static String _string(Object? value, String key) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key is required');
    }
    return value;
  }

  static String? _optionalString(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw const FormatException('expected string value');
  }

  static List<String> _stringList(
    Object? value, {
    required List<String> defaultValue,
  }) {
    if (value == null) {
      return List<String>.from(defaultValue);
    }
    if (value is! YamlList) {
      throw const FormatException('expected a list');
    }
    return value.map((item) {
      if (item is! String || item.isEmpty) {
        throw const FormatException('expected a string list');
      }
      return item;
    }).toList(growable: false);
  }

  static String _nestedString(
    Object? yaml,
    List<String> keys, {
    required String defaultValue,
  }) {
    if (yaml is! YamlMap) {
      return defaultValue;
    }
    Object? value = yaml;
    for (final key in keys) {
      if (value is YamlMap) {
        value = value[key];
      } else {
        return defaultValue;
      }
    }
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return defaultValue;
  }
}
