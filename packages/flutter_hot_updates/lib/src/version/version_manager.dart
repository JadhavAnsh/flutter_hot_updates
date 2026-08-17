/// Semantic version comparison utilities.
class VersionManager {
  const VersionManager._();

  /// Parses `major.minor.patch` with optional pre-release/build suffix ignored.
  static List<int> parse(String version) {
    final core = version.split('+').first.split('-').first.trim();
    if (core.isEmpty) {
      throw FormatException('invalid version: $version');
    }

    final parts = core.split('.');
    if (parts.length != 3) {
      throw FormatException('expected major.minor.patch: $version');
    }

    return parts.map(int.parse).toList(growable: false);
  }

  /// Returns negative if [left] < [right], zero if equal, positive if greater.
  static int compare(String left, String right) {
    final leftParts = parse(left);
    final rightParts = parse(right);

    for (var index = 0; index < 3; index++) {
      final delta = leftParts[index] - rightParts[index];
      if (delta != 0) {
        return delta;
      }
    }
    return 0;
  }

  static bool isGreater(String left, String right) => compare(left, right) > 0;

  static bool isGreaterOrEqual(String left, String right) =>
      compare(left, right) >= 0;

  static bool isCompatibleAppVersion({
    required String currentAppVersion,
    required String manifestAppVersion,
    required String minSupportedAppVersion,
  }) {
    if (currentAppVersion != manifestAppVersion) {
      return false;
    }
    return isGreaterOrEqual(currentAppVersion, minSupportedAppVersion);
  }

  static bool isPatchEligible({
    required int remotePatch,
    required int localPatch,
    bool allowDowngrade = false,
  }) {
    if (allowDowngrade) {
      return remotePatch != localPatch;
    }
    return remotePatch > localPatch;
  }
}
