import 'dart:async';
import 'dart:io';

import '../../platform/system_log.dart';
import '../../remote/music_share_models.dart';

String libraryQueryFailureMessage(Object error, StackTrace stack) {
  SystemLog.error('Library query failed', error, stack);
  if (error is MusicShareException) {
    if (error.httpStatusCode case final status? when status >= 500) {
      return 'share.pageLoadFailed';
    }
    return error.messageKey;
  }
  if (error is SocketException ||
      error is HandshakeException ||
      error is TimeoutException) {
    return 'share.connectionFailed';
  }
  return 'share.pageLoadFailed';
}
