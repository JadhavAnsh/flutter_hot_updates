import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Talks to the hot_updates backend (Phase 3). Mirrors the NestJS API:
/// create release → create patch (get pre-signed URL) → upload bundle → publish.
class BackendClient {
  BackendClient({
    required Uri baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  })  : _base = _normalize(baseUrl),
        _http = httpClient ?? http.Client();

  final Uri _base;
  final String apiKey;
  final http.Client _http;

  Map<String, String> get _authJson => {
        'authorization': 'Bearer $apiKey',
        'content-type': 'application/json',
      };

  /// Returns the release id, reusing an existing release on 409.
  Future<String> ensureRelease({
    required String projectId,
    required String appVersion,
    required String platform,
  }) async {
    final res = await _http.post(
      _v1('projects/$projectId/releases'),
      headers: _authJson,
      body: jsonEncode({'appVersion': appVersion, 'platform': platform}),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return jsonDecode(res.body)['id'] as String;
    }
    if (res.statusCode == 409) {
      return _findRelease(projectId, appVersion, platform);
    }
    throw _err('create release', res);
  }

  Future<String> _findRelease(
    String projectId,
    String appVersion,
    String platform,
  ) async {
    final res = await _http.get(
      _v1('projects/$projectId/releases',
          {'platform': platform, 'appVersion': appVersion}),
      headers: _authJson,
    );
    if (res.statusCode != 200) throw _err('list releases', res);
    final list = jsonDecode(res.body) as List;
    if (list.isEmpty) throw StateError('release conflict but none found');
    return list.first['id'] as String;
  }

  /// Registers patch metadata and returns the pre-signed upload URL.
  Future<({String patchId, String uploadUrl})> createPatch({
    required String projectId,
    required String releaseId,
    required int patchNumber,
    required Map<String, dynamic> manifest,
    required String bundleSha256,
    required int bundleSize,
    required String signature,
  }) async {
    final res = await _http.post(
      _v1('projects/$projectId/releases/$releaseId/patches'),
      headers: _authJson,
      body: jsonEncode({
        'patchNumber': patchNumber,
        'manifest': manifest,
        'bundleSha256': bundleSha256,
        'bundleSize': bundleSize,
        'signature': signature,
      }),
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw _err('create patch', res);
    }
    final body = jsonDecode(res.body);
    return (
      patchId: body['patchId'] as String,
      uploadUrl: body['uploadUrl'] as String,
    );
  }

  /// Uploads the bundle bytes to the pre-signed S3 URL (PUT, no auth header).
  Future<void> uploadBundle(String uploadUrl, Uint8List bytes) async {
    final res = await _http.put(
      Uri.parse(uploadUrl),
      headers: {'content-type': 'application/zip'},
      body: bytes,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _err('upload bundle', res);
    }
  }

  Future<void> publish({
    required String projectId,
    required String patchId,
  }) async {
    final res = await _http.post(
      _v1('projects/$projectId/patches/$patchId/publish'),
      headers: _authJson,
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw _err('publish patch', res);
    }
  }

  /// Creates a project via the admin endpoint (`POST /v1/projects`) using the
  /// shared ADMIN_TOKEN. Static because there is no per-project API key yet at
  /// creation time. Returns the new project id and its one-time API key.
  static Future<({String id, String name, String slug, String apiKey})>
      createProject({
    required Uri baseUrl,
    required String adminToken,
    required String name,
    required String slug,
    http.Client? httpClient,
  }) async {
    final http.Client client = httpClient ?? http.Client();
    try {
      final base = _normalize(baseUrl);
      final url = base.replace(
        pathSegments: [...base.pathSegments, 'v1', 'projects']
            .where((s) => s.isNotEmpty)
            .toList(),
      );
      final res = await client.post(
        url,
        headers: {
          'authorization': 'Bearer $adminToken',
          'content-type': 'application/json',
        },
        body: jsonEncode({'name': name, 'slug': slug}),
      );
      if (res.statusCode != 201 && res.statusCode != 200) {
        throw Exception(
          'create project failed (${res.statusCode}): ${res.body}',
        );
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return (
        id: body['id'] as String,
        name: body['name'] as String,
        slug: body['slug'] as String,
        apiKey: body['apiKey'] as String,
      );
    } finally {
      if (httpClient == null) client.close();
    }
  }

  void close() => _http.close();

  Uri _v1(String path, [Map<String, String>? query]) {
    final base = _base.replace(
      pathSegments: [..._base.pathSegments, 'v1', ...path.split('/')]
          .where((s) => s.isNotEmpty)
          .toList(),
      queryParameters: query,
    );
    return base;
  }

  static Uri _normalize(Uri uri) {
    // Reduce the configured endpoint to the API mount root so `_v1` can append
    // `/v1/...` exactly once. Accepts either the bare host/mount path or the
    // runtime's full manifest URL
    // (`https://host/v1/projects/<id>/<platform>/<version>/manifest.json`):
    // a trailing manifest filename is dropped, then everything from the `v1`
    // prefix onwards. Query and fragment are discarded.
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty && segments.last.endsWith('.json')) {
      segments.removeLast();
    }
    final v1Index = segments.indexOf('v1');
    final root = v1Index == -1 ? segments : segments.sublist(0, v1Index);
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      pathSegments: root,
    );
  }

  Exception _err(String action, http.Response res) =>
      Exception('$action failed (${res.statusCode}): ${res.body}');
}
