import 'dart:convert';
import 'dart:io';
import '../library/data/library_repository.dart';
import '../library/data/library_models.dart';
import '../library/data/library_recent_data.dart';
import '../library/data/library_database_service.dart';
import '../library/data/library_playback_history_service.dart';
import '../library/data/library_browse_history_service.dart';
import '../library/data/library_search_history_service.dart';
import 'music_share_catalog.dart';
import 'music_share_models.dart';

Map<String, dynamic> searchHistoryJson(SearchHistoryEntry e) => {
  'id': e.id,
  'query': e.query,
  'type': e.type.index,
  'time': e.searchedAt,
};
Map<String, dynamic> browseHistoryJson(RecentBrowseEntry e) => {
  'id': e.id,
  'type': e.type.index,
  'item': e.itemId,
  'time': e.browsedAt,
};
SearchHistoryEntry searchHistoryFromJson(Map e) => SearchHistoryEntry(
  id: e['id'] as int,
  query: e['query'] as String,
  type: SearchHistoryType.values[e['type'] as int],
  searchedAt: e['time'] as String,
);
RecentBrowseEntry browseHistoryFromJson(Map e) => RecentBrowseEntry(
  id: e['id'] as int,
  type: RecentBrowseType.values[e['type'] as int],
  itemId: e['item'] as String,
  browsedAt: e['time'] as String,
);

Future<Map<String, dynamic>> handleSharedHistory(
  HttpRequest request,
  LibraryRepository repository,
  bool Function() canWrite,
) async {
  if (request.method == 'GET') {
    if (request.uri.queryParameters['section'] == 'searches') {
      final entries = await const LibrarySearchHistoryService(
        database: LibraryDatabaseService(),
      ).getRecentSearches(File(await repository.getDatabasePath()));
      return {'searches': entries.map(searchHistoryJson).toList()};
    }
    final data = await readLocalRecentData(repository);
    return {
      'songs': data.songs.map(sharedSongJson).toList(),
      'played': [
        for (final s in data.recentSongs) {'song': s.id, 'time': s.playedAt},
      ],
      'playlists': [
        for (final e in data.recentPlaylists)
          {'id': e.id, 'item': e.playlistId, 'time': e.playedAt},
      ],
      'albums': [
        for (final e in data.recentAlbums)
          {'id': e.id, 'item': e.album, 'time': e.playedAt},
      ],
      'artists': [
        for (final e in data.recentArtists)
          {'id': e.id, 'item': e.artist, 'time': e.playedAt},
      ],
      'searches': data.recentSearches.map(searchHistoryJson).toList(),
      'browses': data.recentBrowses.map(browseHistoryJson).toList(),
    };
  }
  final body = StringBuffer();
  await for (final chunk in utf8.decoder
      .bind(request)
      .timeout(const Duration(seconds: 15))) {
    body.write(chunk);
    if (body.length > 1024 * 1024) {
      throw const FormatException('History request too large');
    }
  }
  final values = jsonDecode(body.toString()) as Map<String, dynamic>;
  final file = File(await repository.getDatabasePath());
  final operation = values['operation'] as String;
  if (operation.startsWith('remove') ||
      operation.startsWith('restore') ||
      operation.startsWith('clear')) {
    if (!canWrite()) {
      throw const MusicShareException('share.readOnlyPermission');
    }
  }
  return () async {
    const history = LibraryPlaybackHistoryService();
    const browse = LibraryBrowseHistoryService();
    const search = LibrarySearchHistoryService(
      database: LibraryDatabaseService(),
    );
    List<int> ids() => (values['ids'] as List).cast<int>();
    switch (values['operation']) {
      case 'song':
        await history.markSongPlayed(file, values['song'] as int);
      case 'playlist':
        final e = await history.recordPlaylistPlayed(
          file,
          values['item'] as int,
        );
        return {'id': e.id, 'time': e.playedAt};
      case 'album':
        final e = await history.recordAlbumPlayed(
          file,
          values['item'] as String,
        );
        return {'id': e.id, 'time': e.playedAt};
      case 'artist':
        final e = await history.recordArtistPlayed(
          file,
          values['item'] as String,
        );
        return {'id': e.id, 'time': e.playedAt};
      case 'browse':
        return browseHistoryJson(
          await browse.record(
            file,
            RecentBrowseType.values[values['type'] as int],
            values['item'] as String,
          ),
        );
      case 'search':
        final e = await search.addRecentSearch(
          file,
          values['query'] as String,
          SearchHistoryType.values[values['type'] as int],
        );
        return {'entry': e == null ? null : searchHistoryJson(e)};
      case 'removePlayed':
        await history.removeRecentPlayed(file, ids());
      case 'restorePlayed':
        await history.restoreRecentPlayed(file, ids());
      case 'clearPlayed':
        await history.clearRecentPlayed(file);
      case 'removeBrowses':
        await browse.remove(file, ids());
      case 'restoreBrowses':
        await browse.restore(file, ids());
      case 'clearBrowses':
        await browse.clear(file);
      case 'removeSearches':
        await search.removeRecentSearches(file, ids());
      case 'restoreSearches':
        await search.restoreRecentSearches(
          file,
          (values['entries'] as List)
              .cast<Map>()
              .map(searchHistoryFromJson)
              .toList(),
        );
      case 'clearSearches':
        await search.clearRecentSearches(file);
      default:
        throw const FormatException('Unknown history operation');
    }
    return <String, dynamic>{};
  }();
}
