import 'dart:io';

import '../upload/backend_client.dart';

/// `hot_updates project create` — provisions a project on the backend using the
/// admin token, then prints the one-time API key the CLI/CI uses for uploads.
class ProjectCommand {
  Future<int> create({
    required Uri? endpoint,
    required String? slug,
    String? name,
  }) async {
    if (endpoint == null) {
      stderr.writeln('project create requires --endpoint');
      return 64;
    }
    if (slug == null || slug.isEmpty) {
      stderr.writeln('project create requires --slug');
      return 64;
    }
    final adminToken = Platform.environment['HOT_UPDATES_ADMIN_TOKEN'];
    if (adminToken == null || adminToken.isEmpty) {
      stderr.writeln('project create requires HOT_UPDATES_ADMIN_TOKEN');
      return 64;
    }

    try {
      final project = await BackendClient.createProject(
        baseUrl: endpoint,
        adminToken: adminToken,
        name: name ?? slug,
        slug: slug,
      );
      stdout.writeln('created project ${project.slug} (${project.id})');
      stdout.writeln('API key (shown once, store as HOT_UPDATES_API_KEY):');
      stdout.writeln(project.apiKey);
      return 0;
    } catch (error) {
      stderr.writeln('create project failed: $error');
      return 70;
    }
  }
}
