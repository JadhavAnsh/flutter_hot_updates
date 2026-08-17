import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../download/download_progress.dart';
import '../errors.dart';
import '../security/checksum_verifier.dart';

typedef DownloadProgressCallback = void Function(DownloadProgress progress);

/// Downloads remote artifacts with checksum validation.
class Downloader {
  Downloader({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<File> downloadToFile({
    required String url,
    required File destination,
    required String expectedSha256,
    int? expectedSize,
    DownloadProgressCallback? onProgress,
  }) async {
    await destination.parent.create(recursive: true);
    final tempFile = File('${destination.path}.part');

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    try {
      if (url.startsWith('file://')) {
        final sourceFile = File(Uri.parse(url).toFilePath());
        if (!await sourceFile.exists()) {
          throw UpdateOperationException('download source not found: ${sourceFile.path}');
        }

        final bytes = await sourceFile.readAsBytes();
        onProgress?.call(
          DownloadProgress(
            receivedBytes: bytes.length,
            totalBytes: expectedSize ?? bytes.length,
          ),
        );

        if (expectedSize != null && bytes.length != expectedSize) {
          throw UpdateOperationException(
            'download size mismatch: expected $expectedSize got ${bytes.length}',
          );
        }

        if (!ChecksumVerifier.verifyHex(bytes, expectedSha256)) {
          throw const UpdateOperationException('download checksum mismatch');
        }

        await tempFile.writeAsBytes(Uint8List.fromList(bytes));
      } else {
        await _dio.download(
          url,
          tempFile.path,
          onReceiveProgress: (received, total) {
            final resolvedTotal = expectedSize ?? (total > 0 ? total : 0);
            onProgress?.call(
              DownloadProgress(
                receivedBytes: received,
                totalBytes: resolvedTotal,
              ),
            );
          },
        );
      }

      final bytes = await tempFile.readAsBytes();
      if (expectedSize != null && bytes.length != expectedSize) {
        throw UpdateOperationException(
          'download size mismatch: expected $expectedSize got ${bytes.length}',
        );
      }

      if (!ChecksumVerifier.verifyHex(bytes, expectedSha256)) {
        throw const UpdateOperationException('download checksum mismatch');
      }

      if (await destination.exists()) {
        await destination.delete();
      }
      await tempFile.rename(destination.path);
      return destination;
    } catch (error) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      if (error is UpdateOperationException) {
        rethrow;
      }
      throw UpdateOperationException('download failed', cause: error);
    }
  }
}
