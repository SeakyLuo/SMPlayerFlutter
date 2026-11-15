import 'dart:isolate';

import 'library_browse_history_service.dart';
import 'package:sqlite3/sqlite3.dart';
import 'library_models.dart';
import 'library_playback_history_service.dart';
import 'library_read_service.dart';

class LibrarySnapshotService {
  const LibrarySnapshotService();

  static const _read = LibraryReadService();
  static const _history = LibraryPlaybackHistoryService();
  static const _browse = LibraryBrowseHistoryService();
  static Future<void> _pending = Future.value();

  static Future<T> run<T>(T Function() operation) {
    final result = _pending.then((_) => Isolate.run(operation));
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<void> runIfCurrent(
    void Function() operation,
    bool Function() isCurrent,
  ) {
    final result = _pending.then<void>((_) async {
      if (!isCurrent()) return;
      await Isolate.run(operation);
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<void> waitForPendingOperations() => _pending;

  Future<int> readSongCount(String path) async {
    await waitForPendingOperations();
    return Isolate.run(() {
      final db = sqlite3.open(path, mode: OpenMode.readOnly);
      try {
        return _read.readLibrarySongCount(db);
      } finally {
        db.dispose();
      }
    });
  }

  Future<List<LibrarySong>> readSongs(
    String path, {
    required List<int> songIds,
  }) async {
    await waitForPendingOperations();
    return Isolate.run(() {
      final db = sqlite3.open(path, mode: OpenMode.readOnly);
      try {
        db.execute('BEGIN');
        final songs = _read.readSongs(
          db,
          songIds: songIds,
          includeInactive: true,
        );
        db.execute('COMMIT');
        return songs;
      } finally {
        db.dispose();
      }
    });
  }

  Future<RecentPageData> readRecent(LibraryContentData content) async {
    final path = content.databasePath;
    final songs = content.songs;
    await waitForPendingOperations();
    final recent = await Isolate.run(() {
      final db = sqlite3.open(path, mode: OpenMode.readOnly);
      try {
        return (
          songs: _history.readRecentSongs(db, songs),
          playlists: _history.readRecentPlaylists(db),
          albums: _history.readRecentAlbums(db),
          artists: _history.readRecentArtists(db),
          nowPlaying: _history.readRecentNowPlaying(db),
          browses: _browse.read(db),
        );
      } finally {
        db.dispose();
      }
    });
    return RecentPageData(
      songs: songs,
      recentSongs: recent.songs,
      recentPlaylists: recent.playlists,
      recentAlbums: recent.albums,
      recentArtists: recent.artists,
      recentNowPlaying: recent.nowPlaying,
      recentBrowses: recent.browses,
      recentSearches: content.recentSearches,
      playlists: content.playlists,
      favoritePlaylistId: content.favoritePlaylistId,
      nowPlaying: content.nowPlaying,
      showCount: content.showCount,
      hideMultiSelectCommandBarAfterOperation:
          content.hideMultiSelectCommandBarAfterOperation,
    );
  }
}
