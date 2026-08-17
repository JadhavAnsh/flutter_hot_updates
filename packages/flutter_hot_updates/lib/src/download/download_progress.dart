/// Download progress for bundle or asset transfers.
class DownloadProgress {
  const DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int totalBytes;

  double get fraction {
    if (totalBytes <= 0) {
      return 0;
    }
    return receivedBytes / totalBytes;
  }

  int get percent => (fraction * 100).round().clamp(0, 100);
}
