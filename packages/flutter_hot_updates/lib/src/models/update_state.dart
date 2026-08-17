import 'dart:convert';

enum InstalledPatchStatus { active, inactive, staged }

class InstalledPatchRecord {
  const InstalledPatchRecord({
    required this.patch,
    required this.path,
    required this.installedAt,
    required this.status,
  });

  factory InstalledPatchRecord.fromJson(Map<String, dynamic> json) {
    final patch = json['patch'];
    final path = json['path'];
    final installedAt = json['installedAt'];
    final status = json['status'];

    if (patch is! num) {
      throw FormatException('installed patch number is invalid: $patch');
    }
    if (path is! String || path.isEmpty) {
      throw const FormatException('installed patch path is required');
    }
    if (installedAt is! String || installedAt.isEmpty) {
      throw const FormatException('installedAt is required');
    }

    return InstalledPatchRecord(
      patch: patch.toInt(),
      path: path,
      installedAt: installedAt,
      status: _parseStatus(status),
    );
  }

  final int patch;
  final String path;
  final String installedAt;
  final InstalledPatchStatus status;

  InstalledPatchRecord copyWith({
    int? patch,
    String? path,
    String? installedAt,
    InstalledPatchStatus? status,
  }) {
    return InstalledPatchRecord(
      patch: patch ?? this.patch,
      path: path ?? this.path,
      installedAt: installedAt ?? this.installedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'patch': patch,
        'path': path,
        'installedAt': installedAt,
        'status': status.name,
      };

  static InstalledPatchStatus _parseStatus(Object? value) {
    return InstalledPatchStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => InstalledPatchStatus.inactive,
    );
  }
}

/// Persisted local update state.
class UpdateState {
  const UpdateState({
    required this.projectId,
    required this.currentAppVersion,
    required this.activePatch,
    this.previousPatch,
    this.installedPatches = const [],
  });

  factory UpdateState.initial({
    required String projectId,
    required String currentAppVersion,
  }) {
    return UpdateState(
      projectId: projectId,
      currentAppVersion: currentAppVersion,
      activePatch: 0,
    );
  }

  factory UpdateState.fromJson(Map<String, dynamic> json) {
    final projectId = json['projectId'];
    final currentAppVersion = json['currentAppVersion'];
    final activePatch = json['activePatch'];
    final previousPatch = json['previousPatch'];
    final installedPatchesJson = json['installedPatches'];

    if (projectId is! String || projectId.isEmpty) {
      throw const FormatException('state.projectId is required');
    }
    if (currentAppVersion is! String || currentAppVersion.isEmpty) {
      throw const FormatException('state.currentAppVersion is required');
    }
    if (activePatch is! num) {
      throw const FormatException('state.activePatch is required');
    }

    final installedPatches = installedPatchesJson is List
        ? installedPatchesJson
            .map(
              (item) => InstalledPatchRecord.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false)
        : const <InstalledPatchRecord>[];

    return UpdateState(
      projectId: projectId,
      currentAppVersion: currentAppVersion,
      activePatch: activePatch.toInt(),
      previousPatch: previousPatch is num ? previousPatch.toInt() : null,
      installedPatches: installedPatches,
    );
  }

  final String projectId;
  final String currentAppVersion;
  final int activePatch;
  final int? previousPatch;
  final List<InstalledPatchRecord> installedPatches;

  UpdateState copyWith({
    String? projectId,
    String? currentAppVersion,
    int? activePatch,
    int? previousPatch,
    bool clearPreviousPatch = false,
    List<InstalledPatchRecord>? installedPatches,
  }) {
    return UpdateState(
      projectId: projectId ?? this.projectId,
      currentAppVersion: currentAppVersion ?? this.currentAppVersion,
      activePatch: activePatch ?? this.activePatch,
      previousPatch:
          clearPreviousPatch ? null : (previousPatch ?? this.previousPatch),
      installedPatches: installedPatches ?? this.installedPatches,
    );
  }

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'currentAppVersion': currentAppVersion,
        'activePatch': activePatch,
        if (previousPatch != null) 'previousPatch': previousPatch,
        'installedPatches':
            installedPatches.map((patch) => patch.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());

  InstalledPatchRecord? recordForPatch(int patch) {
    for (final record in installedPatches) {
      if (record.patch == patch) {
        return record;
      }
    }
    return null;
  }
}
