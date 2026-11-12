import 'dart:convert';
import 'dart:io';

import '../library/data/library_models.dart';
import '../library/data/library_repository.dart';
import 'music_share_edit_codec.dart';

Future<Map<String, dynamic>> handleSharedSongEdit(
  HttpRequest request,
  LibrarySong song,
  String resource,
  LibraryRepository repository, {
  required bool Function() canWrite,
}) async {
  if (request.method == 'GET' && resource == 'properties') {
    return sharedPropertiesJson(await repository.getSongProperties(song.id));
  }
  if (request.method != 'GET' && !canWrite()) {
    request.response.statusCode = HttpStatus.forbidden;
    return {};
  }
  if (request.method == 'DELETE' && resource == 'artwork') {
    await repository.deleteSongArtwork(song.id);
    return {};
  }
  if (request.method != 'POST' ||
      !{'properties', 'lyrics', 'artwork', 'play-count'}.contains(resource)) {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    return {};
  }
  final bytes = <int>[];
  await for (final chunk in request.timeout(const Duration(seconds: 15))) {
    bytes.addAll(chunk);
    if (bytes.length > 16 * 1024 * 1024) {
      request.response.statusCode = HttpStatus.requestEntityTooLarge;
      return {};
    }
  }
  final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  if (!canWrite()) {
    request.response.statusCode = HttpStatus.forbidden;
    return {};
  }
  switch (resource) {
    case 'properties':
      await repository.updateSongProperties(
        song.id,
        sharedUpdateFromJson(json),
      );
    case 'lyrics':
      await repository.saveSongLyrics(song.id, json['rawText'] as String);
    case 'play-count':
      await repository.updateSongPlayCount(song.id, json['playCount'] as int);
    case 'artwork':
      final image = base64Decode(json['image'] as String);
      final header = String.fromCharCodes(image.take(12));
      final extension = switch (header) {
        String h when h.startsWith('\u00ff\u00d8') => '.jpg',
        String h when h.startsWith('\u0089PNG\r\n\u001a\n') => '.png',
        String h when h.startsWith('RIFF') && h.endsWith('WEBP') => '.webp',
        String h when h.startsWith('BM') => '.bmp',
        _ => throw const FormatException('Unsupported artwork format'),
      };
      final directory = await Directory.systemTemp.createTemp(
        'shared-artwork-',
      );
      try {
        final file = File('${directory.path}/cover$extension');
        await file.writeAsBytes(image);
        final prepared = await repository.prepareSongArtworkSource(file.path);
        if (!canWrite()) {
          request.response.statusCode = HttpStatus.forbidden;
          return {};
        }
        await repository.saveSongArtwork(song.id, prepared);
      } finally {
        await directory.delete(recursive: true);
      }
  }
  return {};
}
