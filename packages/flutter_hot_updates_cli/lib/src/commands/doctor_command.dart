import 'dart:io';

import '../environment.dart';

class DoctorCommand {
  DoctorCommand(this.env);

  final CliEnvironment env;

  Future<int> run() async {
    final issues = <String>[];

    if (!env.configFile.existsSync()) {
      issues.add('missing config: ${env.configFile.path}');
    }

    final pubspec = File('${env.projectRoot.path}/pubspec.yaml');
    if (!pubspec.existsSync()) {
      issues.add('missing pubspec.yaml at ${pubspec.path}');
    }

    if (env.configFile.existsSync()) {
      try {
        final config = env.loadConfig();
        final privateKeyFile = config.privateKeyFile(env.projectRoot);
        if (!privateKeyFile.existsSync()) {
          issues.add('missing signing key: ${privateKeyFile.path}');
        }
        final outputDir = config.outputDirectory(env.projectRoot);
        await outputDir.create(recursive: true);
      } catch (error) {
        issues.add('invalid config: $error');
      }
    }

    if (issues.isEmpty) {
      stdout.writeln('ok');
      return 0;
    }

    for (final issue in issues) {
      stderr.writeln(issue);
    }
    return 1;
  }
}
