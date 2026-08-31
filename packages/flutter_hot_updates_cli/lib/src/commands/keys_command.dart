import 'dart:io';

import 'package:args/args.dart';

import '../security/rsa_pem_codec.dart';

class KeysCommand {
  Future<int> generate({
    required ArgResults args,
  }) async {
    final bitLength = int.tryParse(args['bit-length'] as String? ?? '') ?? 2048;
    final pair = RsaPemCodec.generate(bitLength: bitLength);
    final privateOutput = args['private-output'] as String?;
    final publicOutput = args['public-output'] as String?;
    final writeToStdout = args['stdout'] as bool;

    if (privateOutput == null && publicOutput == null && !writeToStdout) {
      stdout.writeln('--- PRIVATE KEY ---');
      stdout.write(pair.privateKeyPem);
      stdout.writeln('--- PUBLIC KEY ---');
      stdout.write(pair.publicKeyPem);
      return 0;
    }

    if (privateOutput != null && privateOutput.isNotEmpty) {
      final file = File(privateOutput);
      await file.parent.create(recursive: true);
      await file.writeAsString(pair.privateKeyPem);
    }
    if (publicOutput != null && publicOutput.isNotEmpty) {
      final file = File(publicOutput);
      await file.parent.create(recursive: true);
      await file.writeAsString(pair.publicKeyPem);
    }
    if (writeToStdout) {
      stdout.writeln('--- PRIVATE KEY ---');
      stdout.write(pair.privateKeyPem);
      stdout.writeln('--- PUBLIC KEY ---');
      stdout.write(pair.publicKeyPem);
    }
    return 0;
  }

  Future<int> printPublic({
    required ArgResults args,
  }) async {
    final privateKeyPath = args['private-key'] as String?;
    if (privateKeyPath == null || privateKeyPath.isEmpty) {
      stderr.writeln('missing --private-key');
      return 64;
    }

    final privateKeyPem = await File(privateKeyPath).readAsString();
    final privateKey = RsaPemCodec.decodePrivateKeyPem(privateKeyPem);
    final publicKeyPem = RsaPemCodec.encodePublicKeyPemFromPrivateKey(
      privateKey,
    );

    final output = args['output'] as String?;
    if (output == null || output.isEmpty) {
      stdout.write(publicKeyPem);
    } else {
      final file = File(output);
      await file.parent.create(recursive: true);
      await file.writeAsString(publicKeyPem);
    }
    return 0;
  }
}
