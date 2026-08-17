import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hot_updates/src/platform/app_info.dart';
import 'package:path/path.dart' as p;

/// Builds a writable local manifest fixture for the example app.
Future<Directory> prepareExampleFixture() async {
  final fixtureDir = Directory(
    p.join(Directory.systemTemp.path, 'hot_updates_example_fixture'),
  );
  if (await fixtureDir.exists()) {
    await fixtureDir.delete(recursive: true);
  }
  await fixtureDir.create(recursive: true);

  final bannerBytes = (await rootBundle.load(
    'assets/images/banner.png',
  )).buffer.asUint8List();
  final bannerSha = sha256.convert(bannerBytes).toString();

  const headlineText = 'Patched headline from hot update\n';
  final headlineBytes = utf8.encode(headlineText);
  final headlineSha = sha256.convert(headlineBytes).toString();

  final config = <String, dynamic>{
    'showReferral': true,
    'theme': 'festival',
  };

  final innerManifest = <String, dynamic>{
    'schemaVersion': 1,
    'projectId': 'basic_example',
    'appVersion': '1.0.1',
    'patch': 2,
    'minSupportedAppVersion': '1.0.1',
    'platform': AppInfo.currentPlatformName(),
    'createdAt': '2026-08-17T00:00:00.000Z',
    'assets': [
      {
        'path': 'images/banner.png',
        'url': 'images/banner.png',
        'sha256': bannerSha,
      },
      {
        'path': 'copy/home_headline.txt',
        'url': 'copy/home_headline.txt',
        'sha256': headlineSha,
      },
    ],
    'config': config,
    'bundle': {
      'url': 'patch_2.zip',
      'sha256': 'placeholder',
      'size': 1,
    },
  };

  final zipBytes = _buildZip({
    'manifest.json': utf8.encode(jsonEncode(innerManifest)),
    'config.json': utf8.encode(jsonEncode(config)),
    'assets/images/banner.png': bannerBytes,
    'assets/copy/home_headline.txt': headlineBytes,
  });
  final zipFile = File(p.join(fixtureDir.path, 'patch_2.zip'));
  await zipFile.writeAsBytes(zipBytes);

  final outerManifest = Map<String, dynamic>.from(innerManifest)
    ..['bundle'] = {
      'url': 'patch_2.zip',
      'sha256': sha256.convert(zipBytes).toString(),
      'size': zipBytes.length,
    };

  await File(p.join(fixtureDir.path, 'manifest.json'))
      .writeAsString(jsonEncode(outerManifest));

  return fixtureDir;
}

Uint8List _buildZip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(
      ArchiveFile(
        entry.key,
        entry.value.length,
        entry.value,
      ),
    );
  }

  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('failed to encode hot update fixture zip');
  }
  return Uint8List.fromList(encoded);
}
