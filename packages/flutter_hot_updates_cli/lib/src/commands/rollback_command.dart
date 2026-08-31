import 'dart:io';

import '../environment.dart';

class RollbackCommand {
  RollbackCommand(this.env);

  final CliEnvironment env;

  Future<int> run({required int patch}) async {
    final config = env.loadConfig();
    final outputDir = config.outputDirectory(env.projectRoot);

    await env.staticExporter.writeRollbackPointer(
      outputDirectory: outputDir,
      patch: patch,
    );

    stdout.writeln('rolled back to patch $patch');
    return 0;
  }
}
