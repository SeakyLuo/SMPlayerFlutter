import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../library/data/library_models.dart';
import '../library/data/library_repository.dart';
import '../platform/system_log.dart';
import 'music_share_models.dart';
import 'music_share_scan_codec.dart';

Future<void> refreshSharedDirectory(
  HttpRequest request,
  LibraryRepository repository,
  String rootPath,
  bool Function() canWrite,
  Future<void> Function(String) prepare,
  Future<Map<String, dynamic>> Function(LocalFolderRefreshResult, String)
  publish,
) async {
  if (request.method != 'POST') {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    return;
  }
  final buffer = StringBuffer();
  await for (final chunk in utf8.decoder
      .bind(request)
      .timeout(const Duration(seconds: 15))) {
    buffer.write(chunk);
    if (buffer.length > 16384) {
      throw const FormatException('Directory request too large');
    }
  }
  final relative = (jsonDecode(buffer.toString()) as Map)['path'] as String;
  if (p.posix.isAbsolute(relative) ||
      relative.contains('\\') ||
      relative.split('/').contains('..')) {
    throw const MusicShareException('share.fileOutsideLibrary');
  }
  final root = await Directory(rootPath).resolveSymbolicLinks();
  final path =
      await Directory(
        p.joinAll([root, ...relative.split('/')]),
      ).resolveSymbolicLinks();
  if (path != root && !p.isWithin(root, path)) {
    throw const MusicShareException('share.fileOutsideLibrary');
  }
  if (!canWrite()) throw const MusicShareException('share.readOnlyPermission');
  final cancellation = LocalFolderScanCancellation();
  final response = request.response;
  response.headers.contentType = ContentType('application', 'x-ndjson');
  response.bufferOutput = false;
  var finished = false;
  var connected = true;
  unawaited(
    response.done.then(
      (_) {
        if (!finished) {
          connected = false;
          cancellation.cancel();
        }
      },
      onError: (Object _, StackTrace __) {
        connected = false;
        cancellation.cancel();
      },
    ),
  );
  final clock = Stopwatch()..start();
  var lastProgress = -100;
  var latest = const LocalFolderRefreshProgress(
    current: 0,
    total: 1,
    currentPath: '',
    stage: LocalFolderRefreshStage.checking,
    canCancel: true,
  );
  void progress(LocalFolderRefreshProgress value) {
    latest = value;
    if (!canWrite()) cancellation.cancel();
    if (cancellation.isCanceled ||
        clock.elapsedMilliseconds - lastProgress < 100) {
      return;
    }
    lastProgress = clock.elapsedMilliseconds;
    response.writeln(
      jsonEncode({'type': 'progress', ...sharedScanProgress(value)}),
    );
    unawaited(
      response.flush().catchError((Object _, StackTrace __) {
        connected = false;
        cancellation.cancel();
      }),
    );
  }

  final heartbeat = Timer.periodic(
    const Duration(seconds: 1),
    (_) => progress(latest),
  );
  try {
    response.writeln(
      jsonEncode({
        'type': 'progress',
        ...sharedScanProgress(
          const LocalFolderRefreshProgress(
            current: 0,
            total: 1,
            currentPath: '',
            stage: LocalFolderRefreshStage.checking,
            canCancel: true,
          ),
        ),
      }),
    );
    await response.flush();
    await prepare(path);
    final result = await repository.refreshLocalFolder(
      path,
      cancellation: cancellation,
      onProgress: progress,
    );
    final changes = await publish(result, path);
    response.writeln(
      jsonEncode({
        'type': 'result',
        'result': sharedScanResult(result, root),
        ...changes,
      }),
    );
    await response.flush();
  } on LocalFolderScanCanceledException {
    if (connected && canWrite()) {
      response.writeln(jsonEncode({'type': 'canceled'}));
    } else if (connected) {
      response.writeln(
        jsonEncode({'type': 'error', 'message': 'share.readOnlyPermission'}),
      );
    }
  } catch (error, stack) {
    SystemLog.error('Shared directory refresh failed', error, stack);
    if (connected && !cancellation.isCanceled) {
      response.writeln(
        jsonEncode({
          'type': 'error',
          'message':
              error is MusicShareException
                  ? error.messageKey
                  : 'song.updateFailed',
        }),
      );
    }
  } finally {
    heartbeat.cancel();
    finished = true;
  }
}
