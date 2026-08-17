import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

Future<void> main() async {
  final fixtureRoot = Directory(
    'examples/basic_flutter_app/assets/hot_updates_fixture',
  );
  await fixtureRoot.create(recursive: true);

  const assetPath = 'images/banner.png';
  const assetContent = 'Patched banner content';
  final assetSha = sha256.convert(utf8.encode(assetContent)).toString();

  const config = {
    'showReferral': true,
    'theme': 'festival',
  };

  final manifest = {
    'schemaVersion': 1,
    'projectId': 'basic_example',
    'appVersion': '1.0.1',
    'patch': 1,
    'minSupportedAppVersion': '1.0.1',
    'platform': '__PLATFORM__',
    'createdAt': '2026-08-17T00:00:00.000Z',
    'assets': [
      {
        'path': assetPath,
        'url': 'images/banner.png',
        'sha256': assetSha,
      },
      {
        'path': 'copy/home_headline.txt',
        'url': 'copy/home_headline.txt',
        'sha256': sha256.convert(utf8.encode('Patched headline from hot update')).toString(),
      },
    ],
    'config': config,
    'bundle': {
      'url': 'patch_1.zip',
      'sha256': 'placeholder',
      'size': 1,
    },
  };

  final patchDir = Directory('${fixtureRoot.path}/patch_build');
  if (await patchDir.exists()) {
    await patchDir.delete(recursive: true);
  }
  final assetsDir = Directory('${patchDir.path}/assets');
  await Directory('${assetsDir.path}/images').create(recursive: true);
  await Directory('${assetsDir.path}/copy').create(recursive: true);
  await File('${assetsDir.path}/$assetPath').writeAsString(assetContent);
  await File('${assetsDir.path}/copy/home_headline.txt')
      .writeAsString('Patched headline from hot update');

  final manifestForZip = Map<String, dynamic>.from(manifest)
    ..remove('signature');
  manifestForZip['platform'] = 'android';
  await File('${patchDir.path}/manifest.json')
      .writeAsString(jsonEncode(manifestForZip));
  await File('${patchDir.path}/config.json').writeAsString(jsonEncode(config));

  final archive = Archive();
  for (final entity in patchDir.listSync(recursive: true)) {
    if (entity is File) {
      final relative = entity.path.substring('${patchDir.path}/'.length);
      archive.addFile(
        ArchiveFile(relative, entity.lengthSync(), entity.readAsBytesSync()),
      );
    }
  }

  final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
  final zipSha = sha256.convert(zipBytes).toString();
  manifest['bundle'] = {
    'url': 'patch_1.zip',
    'sha256': zipSha,
    'size': zipBytes.length,
  };

  await File('${fixtureRoot.path}/patch_1.zip').writeAsBytes(zipBytes);
  await File('${fixtureRoot.path}/manifest.template.json')
      .writeAsString(jsonEncode(manifest));
  await patchDir.delete(recursive: true);

  stdout.writeln('Generated fixture at ${fixtureRoot.path}');
}
