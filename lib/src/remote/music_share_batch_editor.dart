import '../library/data/library_queries.dart';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../library/data/library_repository.dart';
import 'music_share_edit_codec.dart';
import 'music_share_song_editor.dart';

Future<Map<String, dynamic>> handleSharedBatchEdit(
  HttpRequest request,
  String resource,
  LibraryRepository repository,
  bool Function() canWrite,
) async {
  final buffer = StringBuffer();
  await for (final chunk in utf8.decoder
      .bind(request)
      .timeout(const Duration(seconds: 15))) {
    buffer.write(chunk);
    if (buffer.length > 16 * 1024 * 1024) {
      request.response.statusCode = HttpStatus.requestEntityTooLarge;
      return {};
    }
  }
  final envelope = jsonDecode(buffer.toString()) as Map<String, dynamic>;
  final ids = (envelope['ids'] as List).cast<int>();
  final method = envelope['method'] as String;
  final references = await repository.songReferences(ids);
  final context = await repository.queryLibrary(
    const LibraryDataQuery(LibraryQueryKind.context),
  );
  final rootPath = context.rootPath;
  if (ids.isEmpty || !ids.every(references.containsKey)) {
    request.response.statusCode = HttpStatus.notFound;
    return {};
  }
  final root = await Directory(rootPath).resolveSymbolicLinks();
  for (final id in ids) {
    final path = await File(references[id]!).resolveSymbolicLinks();
    if (!p.isWithin(root, path)) {
      request.response.statusCode = HttpStatus.forbidden;
      return {};
    }
  }
  if (method == 'GET' && resource == 'properties') {
    final values = await repository.getSongPropertiesBatch(ids);
    return {
      'properties': [
        for (final value in values)
          {'id': value.songId, ...sharedPropertiesJson(value)},
      ],
    };
  }
  if (!canWrite()) {
    request.response.statusCode = HttpStatus.forbidden;
    return {};
  }
  if (method == 'DELETE' && resource == 'artwork') {
    await repository.updateSharedSongsArtwork(ids, null);
  } else if (method == 'POST') {
    final json = envelope['data'] as Map<String, dynamic>;
    if (!canWrite()) {
      request.response.statusCode = HttpStatus.forbidden;
      return {};
    }
    if (resource == 'favorites') {
      final changed = await repository.setSongsFavorite(
        ids,
        json['favorite'] as bool,
      );
      return {'changed': changed};
    } else if (resource == 'artist-splits') {
      final artists = (json['artists'] as Map).cast<String, dynamic>();
      if (artists.length != ids.toSet().length ||
          !ids.every((id) => artists.containsKey('$id'))) {
        throw const FormatException('Invalid song selection');
      }
      await repository.applySharedArtistValues({
        for (final id in ids) id: (artists['$id'] as List).cast<String>(),
      });
    } else if (resource == 'properties') {
      final rawUpdates = (json['updates'] as Map).cast<String, dynamic>();
      if (rawUpdates.length != ids.toSet().length ||
          !ids.every((id) => rawUpdates.containsKey('$id'))) {
        throw const FormatException('Invalid song selection');
      }
      final result = await repository.updateSongPropertiesBatch({
        for (final id in ids)
          id: sharedUpdateFromJson(
            (rawUpdates['$id'] as Map).cast<String, dynamic>(),
          ),
      });
      return {'updated': result.updatedSongIds, 'failed': result.failedSongIds};
    }
    if (resource == 'artwork') {
      await withSharedArtwork(
        json,
        repository,
        canWrite,
        (path) => repository.updateSharedSongsArtwork(ids, path),
      );
    }
  } else {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    return {};
  }
  return {'changed': ids};
}
