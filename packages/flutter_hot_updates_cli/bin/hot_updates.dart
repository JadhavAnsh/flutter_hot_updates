import 'dart:io';

import 'package:args/args.dart';

import 'package:flutter_hot_updates_cli/src/security/manifest_signer.dart';
import 'package:flutter_hot_updates_cli/src/security/rsa_pem_codec.dart';

class HotUpdatesCli {
  HotUpdatesCli() {
    final keys = _parser.addCommand('keys');
    final generate = keys.addCommand('generate');
    generate.addOption('private-output');
    generate.addOption('public-output');
    generate.addOption('bit-length', defaultsTo: '2048');
    generate.addFlag('stdout', defaultsTo: false, negatable: false);

    final printPublic = keys.addCommand('print-public');
    printPublic.addOption('private-key');
    printPublic.addOption('output');

    final sign = _parser.addCommand('sign');
    sign.addOption('manifest');
    sign.addOption('private-key');
    sign.addOption('output');
    sign.addFlag('stdout', defaultsTo: false, negatable: false);
  }

  final ArgParser _parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false);

  Future<int> run(List<String> arguments) async {
    if (arguments.isEmpty ||
        arguments.contains('-h') ||
        arguments.contains('--help')) {
      _printUsage();
      return 0;
    }

    late ArgResults results;
    try {
      results = _parser.parse(arguments);
    } on FormatException catch (error) {
      stderr.writeln(error.message);
      _printUsage();
      return 64;
    }

    final command = results.command;
    if (command == null) {
      _printUsage();
      return 64;
    }

    switch (command.name) {
      case 'keys':
        return _runKeys(command);
      case 'sign':
        return _runSign(command);
      default:
        _printUsage();
        return 64;
    }
  }

  int _runKeys(ArgResults keys) {
    final command = keys.command;
    if (command == null) {
      stdout.writeln(_parser.usage);
      return 64;
    }

    switch (command.name) {
      case 'generate':
        return _runKeyGeneration(command);
      case 'print-public':
        return _runPrintPublic(command);
      default:
        stdout.writeln(_parser.usage);
        return 64;
    }
  }

  int _runKeyGeneration(ArgResults command) {
    final bitLength =
        int.tryParse(command['bit-length'] as String? ?? '') ?? 2048;
    final pair = RsaPemCodec.generate(bitLength: bitLength);
    final privateOutput = command['private-output'] as String?;
    final publicOutput = command['public-output'] as String?;
    final writeToStdout = command['stdout'] as bool;

    if (privateOutput == null && publicOutput == null && !writeToStdout) {
      stdout.writeln('--- PRIVATE KEY ---');
      stdout.write(pair.privateKeyPem);
      stdout.writeln('--- PUBLIC KEY ---');
      stdout.write(pair.publicKeyPem);
      return 0;
    }

    if (privateOutput != null) {
      final file = File(privateOutput);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(pair.privateKeyPem);
    }
    if (publicOutput != null) {
      final file = File(publicOutput);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(pair.publicKeyPem);
    }
    if (writeToStdout) {
      stdout.writeln('--- PRIVATE KEY ---');
      stdout.write(pair.privateKeyPem);
      stdout.writeln('--- PUBLIC KEY ---');
      stdout.write(pair.publicKeyPem);
    }

    return 0;
  }

  int _runPrintPublic(ArgResults command) {
    final privateKeyPath = command['private-key'] as String?;
    if (privateKeyPath == null || privateKeyPath.isEmpty) {
      stderr.writeln('missing --private-key');
      return 64;
    }

    final privateKeyPem = File(privateKeyPath).readAsStringSync();
    final privateKey = RsaPemCodec.decodePrivateKeyPem(privateKeyPem);
    final publicKeyPem = RsaPemCodec.encodePublicKeyPemFromPrivateKey(
      privateKey,
    );

    final output = command['output'] as String?;
    if (output == null || output.isEmpty) {
      stdout.write(publicKeyPem);
    } else {
      final file = File(output);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(publicKeyPem);
    }
    return 0;
  }

  int _runSign(ArgResults command) {
    final manifestPath = command['manifest'] as String?;
    final privateKeyPath = command['private-key'] as String?;
    final writeToStdout = command['stdout'] as bool;
    final outputPath = command['output'] as String?;

    if (manifestPath == null || manifestPath.isEmpty) {
      stderr.writeln('missing --manifest');
      return 64;
    }
    if (privateKeyPath == null || privateKeyPath.isEmpty) {
      stderr.writeln('missing --private-key');
      return 64;
    }

    final signer = ManifestSigner(
      privateKeyPem: File(privateKeyPath).readAsStringSync(),
    );
    final signedManifest = signer.signManifestJson(
      File(manifestPath).readAsStringSync(),
    );

    if (writeToStdout) {
      stdout.writeln(signedManifest);
      return 0;
    }

    final destination = outputPath == null || outputPath.isEmpty
        ? manifestPath
        : outputPath;
    final file = File(destination);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(signedManifest);
    return 0;
  }

  void _printUsage() {
    stdout.writeln('flutter_hot_updates CLI');
    stdout.writeln('');
    stdout.writeln('Usage: hot_updates <command> [arguments]');
    stdout.writeln('');
    stdout.writeln('Commands:');
    stdout.writeln('  keys generate');
    stdout.writeln('  keys print-public');
    stdout.writeln('  sign');
    stdout.writeln('');
    stdout.writeln('Use `hot_updates <command> --help` for command usage.');
  }
}

Future<void> main(List<String> arguments) async {
  final exit = await HotUpdatesCli().run(arguments);
  exitCode = exit;
}
