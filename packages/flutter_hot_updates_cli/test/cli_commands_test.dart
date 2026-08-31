import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_hot_updates_cli/flutter_hot_updates_cli.dart';
import 'package:flutter_hot_updates_cli/src/security/rsa_pem_codec.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late Directory originalCurrent;

  setUp(() async {
    originalCurrent = Directory.current;
    tempDir = await Directory.systemTemp.createTemp('hot_updates_cli_');
    Directory.current = tempDir;
  });

  tearDown(() async {
    Directory.current = originalCurrent;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('init creates the default config scaffold', () async {
    final exit = await HotUpdatesCli().run([
      'init',
      '--project-id',
      'demo',
    ]);

    expect(exit, 0);

    final configFile = File('.hot_updates/hot_updates.yaml');
    expect(await configFile.exists(), isTrue);
    final config = await configFile.readAsString();
    expect(config, contains('project_id: demo'));
    expect(config, contains('directory: .hot_updates/build'));
  });

  test('doctor reports missing signing key', () async {
    await _writeProjectLayout();
    await _writeConfig(projectId: 'demo');

    final exit = await HotUpdatesCli().run(['doctor']);

    expect(exit, 1);
  });

  test('release writes a signed manifest and bundle without bundling manifest.json', () async {
    final keyPair = RsaPemCodec.generate();
    await _writeProjectLayout();
    await _writeConfig(projectId: 'demo');
    await File('.hot_updates/private_key.pem').writeAsString(keyPair.privateKeyPem);
    await File('.hot_updates/config.json').writeAsString(
      jsonEncode({'showReferral': true, 'theme': 'festival'}),
    );
    await File('assets/banner.txt').writeAsString('patched banner');
    await File('assets/skip.psd').writeAsString('skip me');

    final exit = await HotUpdatesCli().run([
      'release',
      '--platform',
      'android',
    ]);

    expect(exit, 0);

    final manifestFile = File('.hot_updates/build/manifest.json');
    final bundleFile = File('.hot_updates/build/releases/patch_0/bundle.zip');
    expect(await manifestFile.exists(), isTrue);
    expect(await bundleFile.exists(), isTrue);

    final manifest = HotUpdatesManifest.parse(await manifestFile.readAsString());
    expect(manifest.signature, isNotNull);
    expect(manifest.bundle.url, 'releases/patch_0/bundle.zip');
    expect(manifest.assets, hasLength(1));
    expect(manifest.assets.single.path, 'banner.txt');

    final archive = ZipDecoder().decodeBytes(await bundleFile.readAsBytes());
    final bundleEntries = archive
        .whereType<ArchiveFile>()
        .map((file) => file.name)
        .toList()
      ..sort();

    expect(bundleEntries, contains('assets/banner.txt'));
    expect(bundleEntries, contains('config.json'));
    expect(bundleEntries, isNot(contains('manifest.json')));
  });

  test('patch dry run reports the next patch without writing files', () async {
    final keyPair = RsaPemCodec.generate();
    await _writeProjectLayout();
    await _writeConfig(projectId: 'demo');
    await File('.hot_updates/private_key.pem').writeAsString(keyPair.privateKeyPem);
    await File('.hot_updates/config.json').writeAsString('{}');
    await File('assets/banner.txt').writeAsString('patched banner');

    final releaseExit = await HotUpdatesCli().run(['release']);
    expect(releaseExit, 0);

    final exit = await HotUpdatesCli().run([
      'patch',
      '--dry-run',
    ]);

    expect(exit, 0);
    expect(File('.hot_updates/build/releases/patch_1').existsSync(), isFalse);
  });
}

Future<void> _writeProjectLayout() async {
  await File('pubspec.yaml').writeAsString('''
name: demo
version: 1.2.3
environment:
  sdk: ^3.12.2
flutter:
  assets:
    - assets/banner.txt
''');
  await Directory('assets').create(recursive: true);
}

Future<void> _writeConfig({required String projectId}) async {
  await Directory('.hot_updates').create(recursive: true);
  final config = HotUpdatesConfig.defaults(projectId: projectId);
  await File('.hot_updates/hot_updates.yaml').writeAsString(
    config.toYamlString(),
  );
}
