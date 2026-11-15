part of 'music_share_server.dart';

const _audioContentTypes = {
  '.aac': 'audio/aac',
  '.aiff': 'audio/aiff',
  '.alac': 'audio/mp4',
  '.ape': 'audio/x-ape',
  '.flac': 'audio/flac',
  '.m4a': 'audio/mp4',
  '.mp3': 'audio/mpeg',
  '.ogg': 'audio/ogg',
  '.opus': 'audio/ogg',
  '.wav': 'audio/wav',
  '.wma': 'audio/x-ms-wma',
};

Future<void> _sendFile(HttpRequest request, File file, ContentType type) async {
  final response = request.response;
  final length = await file.length();
  var start = 0;
  var end = length - 1;
  response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
  final range = request.headers.value(HttpHeaders.rangeHeader);
  if (range != null) {
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
    if (match == null || (match.group(1)!.isEmpty && match.group(2)!.isEmpty)) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
      return;
    }
    if (match.group(1)!.isEmpty) {
      start = max(0, length - int.parse(match.group(2)!));
    } else {
      start = int.parse(match.group(1)!);
      if (match.group(2)!.isNotEmpty) {
        end = min(end, int.parse(match.group(2)!));
      }
    }
    if (start > end || start >= length) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
      return;
    }
    response.statusCode = HttpStatus.partialContent;
    response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$end/$length',
    );
  }
  response.headers.contentType = type;
  response.contentLength = end - start + 1;
  if (request.method != 'HEAD') {
    await response.addStream(file.openRead(start, end + 1));
  }
}
