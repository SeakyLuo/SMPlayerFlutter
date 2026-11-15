import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../library/data/library_models.dart';
import 'music_share_identity.dart';
import 'music_share_models.dart';
import 'music_share_scan_codec.dart';

Future<Map<String, dynamic>> refreshRemoteDirectory(
  MusicShareTransport transport,
  String folderPath,
  LocalFolderScanCancellation cancellation,
  void Function(LocalFolderRefreshProgress) onProgress,
) async {
  final uri = Uri.parse(folderPath);
  unawaited(cancellation.whenCanceled.then((_) => transport.close()));
  try {
    final response = await transport.open(
      '/directory-refresh',
      method: 'POST',
      body: {'path': uri.pathSegments.join('/')},
    );
    if (response.statusCode != HttpStatus.ok) {
      final text = await utf8.decoder.bind(response).join();
      if (text.isNotEmpty) {
        final body = jsonDecode(text) as Map<String, dynamic>;
        throw MusicShareException(body['error'] as String);
      }
      throw MusicShareException(
        response.statusCode == HttpStatus.notFound
            ? 'share.directoryUpgradeRequired'
            : response.statusCode == HttpStatus.forbidden
            ? 'share.readOnlyPermission'
            : 'share.connectionFailed',
      );
    }
    await for (final line in response
        .timeout(const Duration(seconds: 30))
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final value = jsonDecode(line) as Map<String, dynamic>;
      switch (value['type']) {
        case 'progress':
          onProgress(readSharedScanProgress(value));
        case 'canceled':
          throw const LocalFolderScanCanceledException();
        case 'error':
          throw MusicShareException(value['message'] as String);
        case 'result':
          return value;
      }
    }
    cancellation.throwIfCanceled();
    throw const MusicShareException('share.connectionFailed');
  } catch (error) {
    cancellation.throwIfCanceled();
    if (error is TimeoutException) {
      throw const MusicShareException('share.requestTimedOut');
    }
    rethrow;
  } finally {
    transport.close();
  }
}
