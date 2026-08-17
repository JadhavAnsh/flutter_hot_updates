import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// App identity and runtime platform information.
class AppInfo {
  AppInfo({
    required this.appVersion,
    required this.buildNumber,
    required this.packageName,
    required this.platform,
  });

  factory AppInfo.fromPackageInfo(
    PackageInfo info, {
    String? platformOverride,
  }) {
    return AppInfo(
      appVersion: info.version,
      buildNumber: info.buildNumber,
      packageName: info.packageName,
      platform: platformOverride ?? currentPlatformName(),
    );
  }

  final String appVersion;
  final String buildNumber;
  final String packageName;
  final String platform;

  static String currentPlatformName() {
    if (kIsWeb) {
      return 'web';
    }

    switch (Platform.operatingSystem) {
      case 'android':
        return 'android';
      case 'ios':
        return 'ios';
      case 'macos':
        return 'macos';
      case 'linux':
        return 'linux';
      case 'windows':
        return 'windows';
      default:
        return Platform.operatingSystem;
    }
  }

  static Future<AppInfo> load({String? platformOverride}) async {
    final info = await PackageInfo.fromPlatform();
    return AppInfo.fromPackageInfo(info, platformOverride: platformOverride);
  }
}
