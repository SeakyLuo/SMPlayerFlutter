import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../library/data/library_models.dart';
import '../library/data/library_repository.dart';
import 'music_share_catalog.dart';
import 'music_share_edit_codec.dart';
import 'music_share_song_editor.dart';

Future<Map<String, dynamic>> handleSharedBatchEdit(
  HttpRequest request,
  String resource,
  Map<int, LibrarySong> sharedSongs,
  String rootPath,
  LibraryRepository repository,
  bool Function() canWrite,
) async {
  final ids =
      request.uri.queryParameters['ids']!.split(',').map(int.parse).toList();
  if (ids.isEmpty || !ids.every(sharedSongs.containsKey)) {
    request.response.statusCode = HttpStatus.notFound;
    return {};
  }
  final root = await Directory(rootPath).resolveSymbolicLinks();
  for (final id in ids) {
    final path = await File(sharedSongs[id]!.path).resolveSymbolicLinks();
    if (!p.isWithin(root, path)) {
      request.response.statusCode = HttpStatus.forbidden;
      return {};
    }
  }
  if (request.method == 'GET' && resource == 'properties') {
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
  if (request.method == 'DELETE' && resource == 'artwork') {
    await repository.updateSharedSongsArtwork(ids, null);
  } else if (request.method == 'POST') {
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
    if (resource == 'favorites') {
      await repository.setSongsFavorite(ids, json['favorite'] as bool);
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
      final updated = await repository.getLibrarySongs(
        songIds: result.updatedSongIds,
      );
      return {
        'updated': result.updatedSongIds,
        'failed': result.failedSongIds,
        'songs': updated.map(sharedSongJson).toList(),
      };
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
  final songs = await repository.getLibrarySongs(songIds: ids);
  return {'songs': songs.map(sharedSongJson).toList()};
}
