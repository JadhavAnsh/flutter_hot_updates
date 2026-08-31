import 'dart:io';

import 'package:flutter_hot_updates_cli/flutter_hot_updates_cli.dart';

Future<void> main(List<String> arguments) async {
  final exit = await HotUpdatesCli().run(arguments);
  exitCode = exit;
}
