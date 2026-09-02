import 'dart:convert';

import 'package:flutter_hot_updates_cli/src/upload/backend_client.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('BackendClient', () {
    test('builds /v1 paths from a bare host', () async {
      Uri? seen;
      final client = BackendClient(
        baseUrl: Uri.parse('https://api.example.com'),
        apiKey: 'hu_p_s',
        httpClient: MockClient((req) async {
          seen = req.url;
          return http.Response(jsonEncode({'id': 'rel1'}), 201);
        }),
      );

      final id = await client.ensureRelease(
        projectId: 'p',
        appVersion: '1.0.0',
        platform: 'android',
      );

      expect(id, 'rel1');
      expect(seen!.host, 'api.example.com');
      expect(seen!.path, '/v1/projects/p/releases');
    });

    test('strips a trailing manifest.json from the endpoint', () async {
      final seen = <String>[];
      final client = BackendClient(
        baseUrl: Uri.parse('https://cdn.example.com/updates/manifest.json'),
        apiKey: 'hu_p_s',
        httpClient: MockClient((req) async {
          seen.add(req.url.path);
          return http.Response(jsonEncode({'id': 'r'}), 201);
        }),
      );
      await client.ensureRelease(
          projectId: 'p', appVersion: '1.0.0', platform: 'android');
      expect(seen.single, '/updates/v1/projects/p/releases');
    });

    test('reuses an existing release on 409', () async {
      final client = BackendClient(
        baseUrl: Uri.parse('https://api.example.com'),
        apiKey: 'hu_p_s',
        httpClient: MockClient((req) async {
          if (req.method == 'POST') return http.Response('conflict', 409);
          // GET list
          return http.Response(jsonEncode([{'id': 'existing'}]), 200);
        }),
      );
      final id = await client.ensureRelease(
          projectId: 'p', appVersion: '1.0.0', platform: 'android');
      expect(id, 'existing');
    });
  });
}
