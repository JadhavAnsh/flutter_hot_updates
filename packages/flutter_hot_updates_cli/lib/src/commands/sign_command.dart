import 'dart:io';

import 'package:args/args.dart';

import '../security/manifest_signer.dart';

class SignCommand {
  Future<int> run({
    required ArgResults args,
  }) async {
    final manifestPath = args['manifest'] as String?;
    final privateKeyPath = args['private-key'] as String?;
    final writeToStdout = args['stdout'] as bool;
    final outputPath = args['output'] as String?;

    if (manifestPath == null || manifestPath.isEmpty) {
      stderr.writeln('missing --manifest');
      return 64;
    }
    if (privateKeyPath == null || privateKeyPath.isEmpty) {
      stderr.writeln('missing --private-key');
      return 64;
    }

    final signer = ManifestSigner(
      privateKeyPem: await File(privateKeyPath).readAsString(),
    );
    final signedManifest = signer.signManifestJson(
      await File(manifestPath).readAsString(),
    );

    if (writeToStdout) {
      stdout.writeln(signedManifest);
      return 0;
    }

    final destination = outputPath == null || outputPath.isEmpty
        ? manifestPath
        : outputPath;
    final file = File(destination);
    await file.parent.create(recursive: true);
    await file.writeAsString(signedManifest);
    return 0;
  }
}
