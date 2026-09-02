import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../errors.dart';
import '../models/update_check_result.dart';
import '../models/update_manifest.dart';
import '../models/update_release.dart';
import '../platform/app_info.dart';
import '../security/signature_verifier.dart';
import '../version/version_manager.dart';

/// Fetches and validates remote or local manifests.
class UpdateChecker {
  UpdateChecker({
    required this.projectId,
    required this.endpoint,
    required SignatureVerifier signatureVerifier,
    Dio? dio,
  })  : _signatureVerifier = signatureVerifier,
        _dio = dio ?? Dio();

  final String projectId;
  final String endpoint;
  final SignatureVerifier _signatureVerifier;
  final Dio _dio;

  String get manifestUrl => _resolveManifestUrl(endpoint);

  Future<UpdateCheckResult> check({
    required AppInfo appInfo,
    required int activePatch,
    bool allowDowngrade = false,
  }) async {
    final manifest = await fetchManifestOrNull(manifestUrl);
    if (manifest == null) {
      return UpdateCheckResult.none(reason: 'server reported no update');
    }
    validateManifest(
      manifest: manifest,
      appInfo: appInfo,
      activePatch: activePatch,
      allowDowngrade: allowDowngrade,
      allowSamePatch: true,
    );

    if (!VersionManager.isPatchEligible(
      remotePatch: manifest.patch,
      localPatch: activePatch,
      allowDowngrade: allowDowngrade,
    )) {
      return UpdateCheckResult.none(
        reason: 'patch ${manifest.patch} is not newer than $activePatch',
      );
    }

    return UpdateCheckResult.available(
      UpdateRelease(manifest: manifest, manifestUrl: manifestUrl),
    );
  }

  Future<UpdateManifest> fetchManifest(String url) async {
    final manifest = await fetchManifestOrNull(url);
    if (manifest == null) {
      throw const UpdateOperationException('no update available');
    }
    return manifest;
  }

  /// Like [fetchManifest] but returns null when the backend answers that no
  /// update is available.
  Future<UpdateManifest?> fetchManifestOrNull(String url) async {
    final String content;
    if (url.startsWith('file://')) {
      final file = File(Uri.parse(url).toFilePath());
      if (!await file.exists()) {
        throw UpdateOperationException('manifest not found: ${file.path}');
      }
      content = await file.readAsString();
    } else {
      try {
        final response = await _dio.get<String>(
          url,
          options: Options(responseType: ResponseType.plain),
        );
        content = response.data ?? '';
      } catch (error) {
        throw UpdateOperationException('manifest fetch failed', cause: error);
      }
    }

    if (content.trim().isEmpty) {
      throw const UpdateOperationException('manifest response was empty');
    }

    return _parseManifestPayload(content);
  }

  /// Accepts either a bare manifest (static hosting) or the backend envelope
  /// `{"updateAvailable": bool, "manifest": {...}}`. Returns null when the
  /// backend reports that no update is available.
  static UpdateManifest? _parseManifestPayload(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const UpdateValidationException('manifest must be a JSON object');
    }
    if (!decoded.containsKey('updateAvailable')) {
      return UpdateManifest.fromJson(decoded);
    }
    if (decoded['updateAvailable'] != true) {
      return null;
    }
    final manifest = decoded['manifest'];
    if (manifest is! Map) {
      throw const UpdateValidationException(
        'updateAvailable was true but manifest was missing',
      );
    }
    return UpdateManifest.fromJson(Map<String, dynamic>.from(manifest));
  }

  void validateManifest({
    required UpdateManifest manifest,
    required AppInfo appInfo,
    required int activePatch,
    bool allowDowngrade = false,
    bool allowSamePatch = false,
  }) {
    if (manifest.projectId != projectId) {
      throw UpdateValidationException(
        'projectId mismatch: expected $projectId got ${manifest.projectId}',
      );
    }

    if (manifest.platform != appInfo.platform) {
      throw UpdateValidationException(
        'platform mismatch: expected ${appInfo.platform} got ${manifest.platform}',
      );
    }

    if (!VersionManager.isCompatibleAppVersion(
      currentAppVersion: appInfo.appVersion,
      manifestAppVersion: manifest.appVersion,
      minSupportedAppVersion: manifest.minSupportedAppVersion,
    )) {
      throw UpdateValidationException(
        'app version ${appInfo.appVersion} is incompatible with manifest '
        '${manifest.appVersion} (min ${manifest.minSupportedAppVersion})',
      );
    }

    final eligible = VersionManager.isPatchEligible(
      remotePatch: manifest.patch,
      localPatch: activePatch,
      allowDowngrade: allowDowngrade,
    );
    final samePatch = manifest.patch == activePatch;
    if (!eligible && !(allowSamePatch && samePatch)) {
      throw UpdateValidationException(
        'patch ${manifest.patch} is not eligible from active patch $activePatch',
      );
    }

    _signatureVerifier.verifyManifest(manifest);
  }

  static String _resolveManifestUrl(String endpoint) {
    final trimmed = endpoint.trim();
    if (trimmed.endsWith('.json')) {
      return trimmed;
    }
    if (trimmed.startsWith('file://')) {
      final path = Uri.parse(trimmed).toFilePath();
      if (path.endsWith('.json')) {
        return trimmed;
      }
      return Uri.file('$path/manifest.json').toString();
    }

    final normalized = trimmed.endsWith('/') ? trimmed : '$trimmed/';
    return '${normalized}manifest.json';
  }
}

/// Resolves relative asset and bundle URLs against a manifest base URL.
class UpdateClient {
  const UpdateClient();

  String resolveUrl(String baseUrl, String relativeOrAbsoluteUrl) {
    if (relativeOrAbsoluteUrl.startsWith('http://') ||
        relativeOrAbsoluteUrl.startsWith('https://') ||
        relativeOrAbsoluteUrl.startsWith('file://')) {
      return relativeOrAbsoluteUrl;
    }

    final baseUri = Uri.parse(baseUrl);
    if (baseUri.scheme == 'file') {
      final basePath = baseUri.toFilePath();
      final baseDir = File(basePath).parent.path;
      return Uri.file(p.join(baseDir, relativeOrAbsoluteUrl)).toString();
    }

    final origin = baseUri.replace(path: '', query: '', fragment: '');
    return origin.resolve(relativeOrAbsoluteUrl).toString();
  }
}
