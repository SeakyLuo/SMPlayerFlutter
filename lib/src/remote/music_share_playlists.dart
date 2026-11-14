import 'dart:convert';
import 'dart:io';

import '../platform/system_log.dart';
import 'music_share_catalog.dart';
import 'music_share_models.dart';

import '../library/data/library_models.dart';
import '../library/data/library_repository.dart';

Map<String, dynamic> sharedPlaylistJson(
  LibraryPlaylist playlist,
  Set<int> songs,
) => {
  'id': playlist.id,
  'name': playlist.name,
  'priority': playlist.priority,
  'criterion': playlist.sortCriterion.index,
  'songs': playlist.songIds.where(songs.contains).toList(),
};

Future<Map<String, dynamic>> serveSharedPlaylists(
  HttpRequest request,
  LibraryRepository repository,
  Map<int, LibrarySong> sharedSongs,
  bool Function() canWrite,
  Map<int, (LibraryPlaylist, DateTime)> deletedPlaylists,
) async {
  final localPlaylists = await repository.getLocalPlaylists();
  final songs = sharedSongs.keys.toSet();
  deletedPlaylists.removeWhere(
    (_, value) =>
        DateTime.now().difference(value.$2) > const Duration(minutes: 2),
  );
  final playlists =
      localPlaylists.where((p) => !p.isBuiltIn && p.id > 0).toList();
  if (request.method == 'GET') {
    final eligibleSongs = sharedSongs.values;
    final catalog = {'songs': eligibleSongs.map(sharedSongJson).toList()};
    final revision = shareDigest(jsonEncode(catalog));
    final payload = <String, dynamic>{
      'revision': revision,
      if (request.uri.queryParameters['revision'] != revision) ...catalog,
    };
    return {
      ...payload,
      'playlists': playlists.map((p) => sharedPlaylistJson(p, songs)).toList(),
    };
  }
  if (request.method != 'POST') {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    return {};
  }
  final chunks = <int>[];
  await for (final chunk in request.timeout(const Duration(seconds: 15))) {
    chunks.addAll(chunk);
    if (chunks.length > 1024 * 1024) {
      request.response.statusCode = HttpStatus.requestEntityTooLarge;
      return {};
    }
  }
  final body = jsonDecode(utf8.decode(chunks)) as Map<String, dynamic>;
  final operation = body['operation'] as String;
  final songIds = (body['songs'] as List).cast<int>();
  if (!songIds.every(songs.contains)) {
    request.response.statusCode = HttpStatus.badRequest;
    return {};
  }
  if (!canWrite()) {
    request.response.statusCode = HttpStatus.forbidden;
    return {};
  }
  final id = body['id'] as int?;
  if (operation != 'create' &&
      operation != 'order' &&
      operation != 'restore' &&
      !playlists.any((p) => p.id == id)) {
    request.response.statusCode = HttpStatus.notFound;
    return {};
  }
  LibraryPlaylist? created;
  switch (operation) {
    case 'create':
      created = await repository.createPlaylist(
        body['name'] as String,
        songIds,
      );
    case 'rename':
      await repository.renamePlaylist(id!, body['name'] as String);
    case 'delete':
      final original = playlists.firstWhere((p) => p.id == id);
      await repository.deletePlaylist(id!);
      deletedPlaylists[id] = (original, DateTime.now());
    case 'add':
      await repository.addSongsToPlaylist(id!, songIds);
    case 'remove':
      await repository.removeSongsFromPlaylist(id!, songIds);
    case 'reorder':
      final original = playlists.firstWhere((p) => p.id == id);
      final visible = original.songIds.where(songs.contains).toSet();
      if (songIds.length != visible.length || !visible.containsAll(songIds)) {
        throw const FormatException('Invalid song order');
      }
      final order = songIds.iterator;
      final merged =
          original.songIds.map((song) {
            if (!songs.contains(song)) return song;
            order.moveNext();
            return order.current;
          }).toList();
      await repository.reorderPlaylistSongs(
        id!,
        merged,
        body['criterion'] == null
            ? null
            : PlaylistSortCriterion.values[body['criterion'] as int],
      );
    case 'order':
      final ids = (body['ids'] as List).cast<int>();
      final allowed = playlists.map((p) => p.id).toSet();
      if (!ids.every(allowed.contains)) {
        throw const FormatException('Invalid playlist');
      }
      await repository.reorderPlaylists(ids);
    case 'restore':
      final original = deletedPlaylists[id];
      if (original == null) {
        request.response.statusCode = HttpStatus.notFound;
        return {};
      }
      await repository.restorePlaylist(original.$1);
      deletedPlaylists.remove(id);
    default:
      throw const FormatException('Unknown playlist operation');
  }
  SystemLog.info(
    'Remote playlist mutation committed: operation=$operation; playlist=$id',
  );
  return {
    if (created != null)
      'created': {
        'id': created.id,
        'name': created.name,
        'priority': created.priority,
        'criterion': created.sortCriterion.index,
      },
  };
}
