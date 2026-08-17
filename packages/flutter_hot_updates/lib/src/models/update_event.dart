import '../download/download_progress.dart';
import 'update_manifest.dart';

/// Lifecycle events emitted by [HotUpdates.events].
enum UpdateEventType {
  checking,
  available,
  downloading,
  installed,
  activated,
  failed,
}

class UpdateEvent {
  const UpdateEvent({
    required this.type,
    this.message,
    this.error,
    this.manifest,
    this.progress,
  });

  factory UpdateEvent.checking() =>
      const UpdateEvent(type: UpdateEventType.checking);

  factory UpdateEvent.available(UpdateManifest manifest) => UpdateEvent(
        type: UpdateEventType.available,
        manifest: manifest,
      );

  factory UpdateEvent.downloading(DownloadProgress progress) => UpdateEvent(
        type: UpdateEventType.downloading,
        progress: progress,
      );

  factory UpdateEvent.installed(UpdateManifest manifest) => UpdateEvent(
        type: UpdateEventType.installed,
        manifest: manifest,
      );

  factory UpdateEvent.activated(UpdateManifest manifest) => UpdateEvent(
        type: UpdateEventType.activated,
        manifest: manifest,
      );

  factory UpdateEvent.failed(String message, {Object? error}) => UpdateEvent(
        type: UpdateEventType.failed,
        message: message,
        error: error,
      );

  final UpdateEventType type;
  final String? message;
  final Object? error;
  final UpdateManifest? manifest;
  final DownloadProgress? progress;
}
