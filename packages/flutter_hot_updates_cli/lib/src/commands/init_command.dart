import 'dart:io';

import 'package:path/path.dart' as p;

import '../environment.dart';

class InitCommand {
  InitCommand(this.env);

  final CliEnvironment env;

  Future<int> run({
    required String projectId,
    Uri? endpoint,
    bool force = false,
  }) async {
    final config = env.defaultConfig(projectId: projectId, endpoint: endpoint);
    if (await env.configFile.exists() && !force) {
      stderr.writeln('config already exists at ${env.configFile.path}');
      return 64;
    }

    await env.configFile.parent.create(recursive: true);
    await env.configFile.writeAsString(config.toYamlString());
    await File(p.join(env.projectRoot.path, '.hot_updates', '.gitignore'))
        .writeAsString('build/\nprivate_key.pem\n');
    stdout.writeln('created ${env.configFile.path}');
    return 0;
  }
}
