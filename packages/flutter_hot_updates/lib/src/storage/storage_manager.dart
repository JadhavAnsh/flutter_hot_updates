import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../errors.dart';
import '../models/update_manifest.dart';
import '../models/update_state.dart';
import '../security/checksum_verifier.dart';

enum InstallJournalStage {
  downloading,
  extracting,
  installing,
  complete,
}

class InstallJournalEntry {
  const InstallJournalEntry({
    required this.patch,
    required this.stage,
    required this.startedAt,
    this.tempPath,
  });

  factory InstallJournalEntry.fromJson(Map<String, dynamic> json) {
    return InstallJournalEntry(
      patch: (json['patch'] as num).toInt(),
      stage: InstallJournalStage.values.firstWhere(
        (stage) => stage.name == json['stage'],
        orElse: () => InstallJournalStage.downloading,
      ),
      startedAt: json['startedAt'] as String,
      tempPath: json['tempPath'] as String?,
    );
  }

  final int patch;
  final InstallJournalStage stage;
  final String startedAt;
  final String? tempPath;

  InstallJournalEntry copyWith({
    InstallJournalStage? stage,
    String? tempPath,
  }) {
    return InstallJournalEntry(
      patch: patch,
      stage: stage ?? this.stage,
      startedAt: startedAt,
      tempPath: tempPath ?? this.tempPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'patch': patch,
        'stage': stage.name,
        'startedAt': startedAt,
        if (tempPath != null) 'tempPath': tempPath,
      };
}

/// Tracks in-progress installs for recovery and bookkeeping.
class InstallJournal {
  InstallJournal(this._file);

  final File _file;
  List<InstallJournalEntry> _entries = [];

  List<InstallJournalEntry> get entries =>
      List.unmodifiable(_entries);

  Future<void> load() async {
    if (!await _file.exists()) {
      _entries = [];
      return;
    }

    final content = await _file.readAsString();
    if (content.trim().isEmpty) {
      _entries = [];
      return;
    }

    final decoded = jsonDecode(content) as Map<String, dynamic>;
    final entriesJson = decoded['entries'];
    if (entriesJson is! List) {
      _entries = [];
      return;
    }

    _entries = entriesJson
        .map(
          (entry) => InstallJournalEntry.fromJson(
            Map<String, dynamic>.from(entry as Map),
          ),
        )
        .toList();
  }

  Future<void> save() async {
    await _file.parent.create(recursive: true);
    final payload = {
      'entries': _entries.map((entry) => entry.toJson()).toList(),
    };
    await _file.writeAsString(jsonEncode(payload));
  }

  Future<void> begin(int patch, {String? tempPath}) async {
    _entries.removeWhere((entry) => entry.patch == patch);
    _entries.add(
      InstallJournalEntry(
        patch: patch,
        stage: InstallJournalStage.downloading,
        startedAt: DateTime.now().toUtc().toIso8601String(),
        tempPath: tempPath,
      ),
    );
    await save();
  }

  Future<void> updateStage(int patch, InstallJournalStage stage) async {
    final index = _entries.indexWhere((entry) => entry.patch == patch);
    if (index == -1) {
      return;
    }
    _entries[index] = _entries[index].copyWith(stage: stage);
    await save();
  }

  Future<void> complete(int patch) async {
    _entries.removeWhere((entry) => entry.patch == patch);
    await save();
  }

  List<InstallJournalEntry> incompleteEntries() {
    return _entries
        .where((entry) => entry.stage != InstallJournalStage.complete)
        .toList(growable: false);
  }
}

/// App-owned storage for manifests, downloads, and installed patches.
class StorageManager {
  StorageManager({
    required this.rootDirectory,
    required File stateFile,
    required File activeManifestFile,
    required File installJournalFile,
  })  : _stateFile = stateFile,
        _activeManifestFile = activeManifestFile,
        _installJournal = InstallJournal(installJournalFile);

  final Directory rootDirectory;
  final File _stateFile;
  final File _activeManifestFile;
  final InstallJournal _installJournal;

  UpdateState? _state;
  UpdateManifest? _activeManifest;

  UpdateState? get state => _state;
  UpdateManifest? get activeManifest => _activeManifest;
  InstallJournal get installJournal => _installJournal;

  Directory get manifestsDir => Directory(p.join(rootDirectory.path, 'manifests'));
  Directory get downloadsDir => Directory(p.join(rootDirectory.path, 'downloads'));
  Directory get patchesDir => Directory(p.join(rootDirectory.path, 'patches'));
  Directory get stagingDir => Directory(p.join(rootDirectory.path, 'staging'));

  static Future<StorageManager> create(Directory rootDirectory) async {
    final hotUpdatesRoot = Directory(p.join(rootDirectory.path, 'hot_updates'));
    await hotUpdatesRoot.create(recursive: true);

    return StorageManager(
      rootDirectory: hotUpdatesRoot,
      stateFile: File(p.join(hotUpdatesRoot.path, 'state.json')),
      activeManifestFile: File(p.join(hotUpdatesRoot.path, 'manifests', 'active.json')),
      installJournalFile: File(p.join(hotUpdatesRoot.path, 'install_journal.json')),
    );
  }

  Future<void> initialize() async {
    await manifestsDir.create(recursive: true);
    await downloadsDir.create(recursive: true);
    await patchesDir.create(recursive: true);
    await stagingDir.create(recursive: true);

    await _installJournal.load();
    await _recoverIncompleteInstalls();
    await _loadState();
    await _loadActiveManifest();
  }

  Future<void> _recoverIncompleteInstalls() async {
    for (final entry in _installJournal.incompleteEntries()) {
      if (entry.tempPath != null) {
        final temp = Directory(entry.tempPath!);
        if (await temp.exists()) {
          await temp.delete(recursive: true);
        }
      }

      final downloadFile = downloadFileForPatch(entry.patch);
      if (await downloadFile.exists()) {
        await downloadFile.delete();
      }

      final staging = stagingDirectoryForPatch(entry.patch);
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }

    for (final entry in _installJournal.incompleteEntries()) {
      await _installJournal.complete(entry.patch);
    }
  }

  Future<void> _loadState() async {
    if (!await _stateFile.exists()) {
      _state = null;
      return;
    }

    final content = await _stateFile.readAsString();
    _state = UpdateState.fromJson(
      jsonDecode(content) as Map<String, dynamic>,
    );
  }

  Future<void> _loadActiveManifest() async {
    if (!await _activeManifestFile.exists()) {
      _activeManifest = null;
      return;
    }

    final content = await _activeManifestFile.readAsString();
    _activeManifest = UpdateManifest.parse(content);
  }

  Future<void> saveState(UpdateState state) async {
    _state = state;
    await _stateFile.parent.create(recursive: true);
    await _stateFile.writeAsString(state.toJsonString());
  }

  Future<void> saveActiveManifest(UpdateManifest manifest) async {
    _activeManifest = manifest;
    await manifestsDir.create(recursive: true);
    await _activeManifestFile.writeAsString(manifest.toJsonString());
  }

  File downloadFileForPatch(int patch) {
    return File(p.join(downloadsDir.path, 'patch_$patch.tmp'));
  }

  Directory patchDirectoryForPatch(int patch) {
    return Directory(p.join(patchesDir.path, 'patch_$patch'));
  }

  Directory stagingDirectoryForPatch(int patch) {
    return Directory(p.join(stagingDir.path, 'patch_$patch'));
  }

  Future<void> extractZipSafely({
    required List<int> zipBytes,
    required Directory destination,
  }) async {
    await destination.create(recursive: true);
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final destinationPath = p.normalize(destination.absolute.path);

    for (final file in archive) {
      if (!file.isFile) {
        continue;
      }

      final relativePath = p.normalize(file.name);
      if (relativePath.startsWith('..') ||
          relativePath.contains('..${p.separator}')) {
        throw const UpdateOperationException('zip path traversal detected');
      }

      final outputPath = p.normalize(p.join(destinationPath, relativePath));
      if (!outputPath.startsWith(destinationPath)) {
        throw const UpdateOperationException('zip path traversal detected');
      }

      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(file.content as List<int>);
    }
  }

  Future<UpdateManifest> readManifestFromDirectory(Directory directory) async {
    final manifestFile = File(p.join(directory.path, 'manifest.json'));
    if (!await manifestFile.exists()) {
      throw const UpdateOperationException('installed patch missing manifest.json');
    }
    return UpdateManifest.parse(await manifestFile.readAsString());
  }

  Future<void> verifyInstalledAssets(UpdateManifest manifest, Directory patchDir) async {
    for (final asset in manifest.assets) {
      final assetFile = File(p.join(patchDir.path, 'assets', asset.path));
      if (!await assetFile.exists()) {
        throw UpdateOperationException('missing installed asset: ${asset.path}');
      }

      final bytes = await assetFile.readAsBytes();
      if (!ChecksumVerifier.verifyHex(bytes, asset.sha256)) {
        throw UpdateOperationException(
          'asset checksum mismatch: ${asset.path}',
        );
      }
    }
  }

  Future<void> promoteStagingToInstalled({
    required int patch,
    required Directory stagingDirectory,
  }) async {
    final destination = patchDirectoryForPatch(patch);
    if (await destination.exists()) {
      await destination.delete(recursive: true);
    }

    await stagingDirectory.rename(destination.path);
  }

  Future<void> deletePatch(int patch) async {
    final patchDirectory = patchDirectoryForPatch(patch);
    if (await patchDirectory.exists()) {
      await patchDirectory.delete(recursive: true);
    }
  }
}
