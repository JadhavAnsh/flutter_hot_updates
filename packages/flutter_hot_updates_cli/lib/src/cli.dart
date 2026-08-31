import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'commands/doctor_command.dart';
import 'commands/init_command.dart';
import 'commands/keys_command.dart';
import 'commands/patch_command.dart';
import 'commands/release_command.dart';
import 'commands/rollback_command.dart';
import 'commands/sign_command.dart';
import 'environment.dart';

class HotUpdatesCli {
  HotUpdatesCli() {
    final init = _parser.addCommand('init');
    init.addOption('project-id');
    init.addOption('endpoint');
    init.addFlag('force', defaultsTo: false, negatable: false);

    final release = _parser.addCommand('release');
    release.addOption('platform');
    release.addFlag('dry-run', defaultsTo: false, negatable: false);

    final patch = _parser.addCommand('patch');
    patch.addOption('platform');
    patch.addFlag('dry-run', defaultsTo: false, negatable: false);

    final rollback = _parser.addCommand('rollback');
    rollback.addOption('patch');

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

    _parser.addCommand('doctor');
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

    final env = CliEnvironment.fromWorkingDirectory(Directory.current);

    switch (command.name) {
      case 'init':
        return InitCommand(env).run(
          projectId: command['project-id'] as String? ?? p.basename(env.projectRoot.path),
          endpoint: _parseUri(command['endpoint'] as String?),
          force: command['force'] as bool,
        );
      case 'release':
        return ReleaseCommand(env).run(
          platform: command['platform'] as String?,
          dryRun: command['dry-run'] as bool,
        );
      case 'patch':
        return PatchCommand(env).run(
          platform: command['platform'] as String?,
          dryRun: command['dry-run'] as bool,
        );
      case 'rollback':
        final patch = int.tryParse(command['patch'] as String? ?? '');
        if (patch == null) {
          stderr.writeln('missing --patch');
          return 64;
        }
        return RollbackCommand(env).run(patch: patch);
      case 'keys':
        return _runKeys(command);
      case 'sign':
        return SignCommand().run(args: command);
      case 'doctor':
        return DoctorCommand(env).run();
      default:
        _printUsage();
        return 64;
    }
  }

  Future<int> _runKeys(ArgResults keys) async {
    final command = keys.command;
    if (command == null) {
      _printUsage();
      return 64;
    }

    final keysCommand = KeysCommand();
    switch (command.name) {
      case 'generate':
        return keysCommand.generate(args: command);
      case 'print-public':
        return keysCommand.printPublic(args: command);
      default:
        _printUsage();
        return 64;
    }
  }

  void _printUsage() {
    stdout.writeln('flutter_hot_updates CLI');
    stdout.writeln('');
    stdout.writeln('Usage: hot_updates <command> [arguments]');
    stdout.writeln('');
    stdout.writeln('Commands:');
    stdout.writeln('  init');
    stdout.writeln('  release');
    stdout.writeln('  patch');
    stdout.writeln('  rollback');
    stdout.writeln('  keys generate');
    stdout.writeln('  keys print-public');
    stdout.writeln('  sign');
    stdout.writeln('  doctor');
    stdout.writeln('');
    stdout.writeln('Use `hot_updates <command> --help` for command usage.');
  }

  Uri? _parseUri(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return Uri.parse(value);
  }
}
