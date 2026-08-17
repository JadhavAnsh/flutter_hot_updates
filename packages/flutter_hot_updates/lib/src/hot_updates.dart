import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

import 'assets/asset_resolver.dart';
import 'config/remote_config.dart';
import 'download/downloader.dart';
import 'download/download_progress.dart';
import 'errors.dart';
import 'models/update_check_result.dart';
import 'models/update_event.dart';
import 'models/update_manifest.dart';
import 'models/update_release.dart';
import 'models/update_state.dart';
import 'network/update_checker.dart';
import 'platform/app_info.dart';
import 'security/signature_verifier.dart';
import 'storage/storage_manager.dart';

export 'config/remote_config.dart';

typedef HotUpdatesProgressCallback = void Function(DownloadProgress progress);

/// Entry point for manifest-driven asset and config hot updates.
final class HotUpdates {
  HotUpdates._();

  static const String version = '0.1.0';

  static bool _initialized = false;
  static final Lock _lock = Lock();

  static late String _projectId;
  static late String _endpoint;
  static late AppInfo _appInfo;
  static late StorageManager _storage;
  static late UpdateChecker _updateChecker;
  static late UpdateClient _updateClient;
  static late Downloader _downloader;
  static late SignatureVerifier _signatureVerifier;
  static RemoteConfig _remoteConfig = RemoteConfig();
  static AssetResolver _assetResolver = AssetResolver(state: null);

  static UpdateRelease? _pendingRelease;
  static UpdateManifest? _installedManifest;

  static final StreamController<UpdateEvent> _eventController =
      StreamController<UpdateEvent>.broadcast(sync: true);

  /// Lifecycle events for update checks, downloads, installs, and activation.
  static Stream<UpdateEvent> get events => _eventController.stream;

  /// Remote config values from the active manifest.
  static RemoteConfig get config => _remoteConfig;

  /// Asset resolver used by [HotImage] and [HotTextAsset].
  static AssetResolver get assetResolver {
    return _assetResolver;
  }

  /// Initializes local state, storage, and the active manifest/config.
  static Future<void> initialize({
    required String projectId,
    required String endpoint,
    String? publicKey,
    Dio? dio,
    Directory? storageRootOverride,
    AppInfo? appInfoOverride,
  }) async {
    await _lock.synchronized(() async {
      _projectId = projectId;
      _endpoint = endpoint;
      _signatureVerifier = SignatureVerifier(publicKeyPem: publicKey);
      _updateClient = const UpdateClient();
      _downloader = Downloader(dio: dio);
      _remoteConfig = RemoteConfig();

      final storageRoot = storageRootOverride ??
          await getApplicationSupportDirectory();
      _storage = await StorageManager.create(storageRoot);
      await _storage.initialize();

      _appInfo = appInfoOverride ?? await AppInfo.load();
      _updateChecker = UpdateChecker(
        projectId: projectId,
        endpoint: endpoint,
        signatureVerifier: _signatureVerifier,
        dio: dio,
      );

      if (_storage.state == null) {
        await _storage.saveState(
          UpdateState.initial(
            projectId: projectId,
            currentAppVersion: _appInfo.appVersion,
          ),
        );
      } else if (_storage.state!.currentAppVersion != _appInfo.appVersion) {
        await _storage.saveState(
          _storage.state!.copyWith(currentAppVersion: _appInfo.appVersion),
        );
      }

      _assetResolver = AssetResolver(
        storage: _storage,
        state: _storage.state,
      );
      _remoteConfig.applyManifest(_storage.activeManifest);
      _initialized = true;
    });
  }

  /// Checks the manifest endpoint for a newer eligible patch.
  static Future<UpdateCheckResult> checkForUpdates({
    bool allowDowngrade = false,
  }) async {
    _ensureInitialized();
    _emit(UpdateEvent.checking());

    try {
      final activePatch = _storage.state?.activePatch ?? 0;
      final result = await _updateChecker.check(
        appInfo: _appInfo,
        activePatch: activePatch,
        allowDowngrade: allowDowngrade,
      );

      if (result.updateAvailable && result.update != null) {
        _emit(UpdateEvent.available(result.update!.manifest));
      }

      return result;
    } catch (error) {
      _emit(UpdateEvent.failed('update check failed', error: error));
      rethrow;
    }
  }

  /// Downloads, verifies, and installs a patch without activating it.
  static Future<void> downloadAndInstall(
    UpdateRelease release, {
    HotUpdatesProgressCallback? onProgress,
  }) async {
    _ensureInitialized();

    final manifest = release.manifest;
    final patch = manifest.patch;
    final stagingDirectory = _storage.stagingDirectoryForPatch(patch);
    final downloadFile = _storage.downloadFileForPatch(patch);

    try {
      _updateChecker.validateManifest(
        manifest: manifest,
        appInfo: _appInfo,
        activePatch: _storage.state?.activePatch ?? 0,
      );

      await _storage.installJournal.begin(
        patch,
        tempPath: stagingDirectory.path,
      );
      _emit(UpdateEvent.downloading(DownloadProgress(
        receivedBytes: 0,
        totalBytes: manifest.bundle.size,
      )));

      final bundleUrl = _updateClient.resolveUrl(
        release.manifestUrl,
        manifest.bundle.url,
      );

      await _downloader.downloadToFile(
        url: bundleUrl,
        destination: downloadFile,
        expectedSha256: manifest.bundle.sha256,
        expectedSize: manifest.bundle.size,
        onProgress: (progress) {
          _emit(UpdateEvent.downloading(progress));
          onProgress?.call(progress);
        },
      );

      await _storage.installJournal.updateStage(
        patch,
        InstallJournalStage.extracting,
      );

      final zipBytes = await downloadFile.readAsBytes();
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
      await _storage.extractZipSafely(
        zipBytes: zipBytes,
        destination: stagingDirectory,
      );

      await _storage.installJournal.updateStage(
        patch,
        InstallJournalStage.installing,
      );

      final installedManifest =
          await _storage.readManifestFromDirectory(stagingDirectory);
      _updateChecker.validateManifest(
        manifest: installedManifest,
        appInfo: _appInfo,
        activePatch: _storage.state?.activePatch ?? 0,
      );
      await _storage.verifyInstalledAssets(installedManifest, stagingDirectory);

      await _storage.promoteStagingToInstalled(
        patch: patch,
        stagingDirectory: stagingDirectory,
      );

      final installedAt = DateTime.now().toUtc().toIso8601String();
      final installedPath = _storage.patchDirectoryForPatch(patch).path;
      final currentState = _storage.state!;
      final updatedRecords = [
        for (final record in currentState.installedPatches)
          if (record.patch != patch)
            record.copyWith(status: InstalledPatchStatus.inactive),
        InstalledPatchRecord(
          patch: patch,
          path: installedPath,
          installedAt: installedAt,
          status: InstalledPatchStatus.staged,
        ),
      ];

      await _storage.saveState(
        currentState.copyWith(installedPatches: updatedRecords),
      );
      _assetResolver.updateState(_storage.state);

      await downloadFile.delete();
      await _storage.installJournal.complete(patch);

      _installedManifest = installedManifest;
      _pendingRelease = release;
      _emit(UpdateEvent.installed(installedManifest));
    } catch (error) {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
      if (await downloadFile.exists()) {
        await downloadFile.delete();
      }
      await _storage.installJournal.complete(patch);
      _emit(UpdateEvent.failed('download and install failed', error: error));
      rethrow;
    }
  }

  /// Activates the most recently installed patch.
  static Future<void> activate({int? patch}) async {
    _ensureInitialized();

    final targetPatch = patch ?? _installedManifest?.patch;
    if (targetPatch == null) {
      throw const UpdateOperationException('no installed patch to activate');
    }

    final record = _storage.state?.recordForPatch(targetPatch);
    if (record == null) {
      throw UpdateOperationException('patch $targetPatch is not installed');
    }

    final manifest = await _storage.readManifestFromDirectory(
      Directory(record.path),
    );

    final currentState = _storage.state!;
    final previousPatch = currentState.activePatch;
    final updatedRecords = [
      for (final installed in currentState.installedPatches)
        installed.copyWith(
          status: installed.patch == targetPatch
              ? InstalledPatchStatus.active
              : InstalledPatchStatus.inactive,
        ),
    ];

    await _storage.saveActiveManifest(manifest);
    await _storage.saveState(
      currentState.copyWith(
        activePatch: targetPatch,
        previousPatch: previousPatch > 0 ? previousPatch : null,
        clearPreviousPatch: previousPatch <= 0,
        installedPatches: updatedRecords,
      ),
    );

    _assetResolver.updateState(_storage.state);
    _remoteConfig.applyManifest(manifest);
    _installedManifest = null;
    _pendingRelease = null;
    _emit(UpdateEvent.activated(manifest));
  }

  /// Resets internal singleton state. Intended for tests.
  static Future<void> resetForTest() async {
    await _lock.synchronized(() async {
      _initialized = false;
      _pendingRelease = null;
      _installedManifest = null;
    });
  }

  static void _ensureInitialized() {
    if (!_initialized) {
      throw const HotUpdatesNotInitializedException();
    }
  }

  static void _emit(UpdateEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }
}
