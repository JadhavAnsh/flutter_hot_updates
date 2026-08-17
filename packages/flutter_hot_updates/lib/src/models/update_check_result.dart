import 'update_release.dart';

/// Result of [HotUpdates.checkForUpdates].
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.updateAvailable,
    this.update,
    this.reason,
  });

  const UpdateCheckResult.none({String? reason})
      : updateAvailable = false,
        update = null,
        reason = reason;

  const UpdateCheckResult.available(UpdateRelease release)
      : updateAvailable = true,
        update = release,
        reason = null;

  final bool updateAvailable;
  final UpdateRelease? update;
  final String? reason;
}
