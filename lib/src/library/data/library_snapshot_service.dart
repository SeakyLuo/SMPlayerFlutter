import 'dart:io';
import 'dart:isolate';

import 'library_browse_history_service.dart';
import 'library_database_service.dart';
import 'library_models.dart';
import 'library_playback_history_service.dart';
import 'library_playlist_service.dart';
import 'library_read_service.dart';
import 'library_search_history_service.dart';

class LibrarySnapshotService {
  const LibrarySnapshotService();

  static const _database = LibraryDatabaseService();
  static const _read = LibraryReadService();
  static const _playlists = LibraryPlaylistService();
  static const _history = LibraryPlaybackHistoryService();
  static const _search = LibrarySearchHistoryService(database: _database);
  static const _browse = LibraryBrowseHistoryService();
  static final _loads = <(String, String), Future<LibraryContentData>>{};
  static Future<void> _pending = Future.value();

  static Future<T> run<T>(T Function() operation) {
    final result = _pending.then((_) => Isolate.run(operation));
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<LibraryContentData> readContent(String path, String queuePath) {
    final key = (path, queuePath);
    return _loads.putIfAbsent(key, () {
      // Share overlapping page loads only; the next load must observe writes.
      return run(
        () => _readContent(path, queuePath),
      ).whenComplete(() => _loads.remove(key));
    });
  }

  Future<int> readSongCount(String path) => run(() {
    final db = _database.openInitializedLibraryDatabase(File(path));
    try {
      return _read.readLibrarySongCount(db);
    } finally {
      db.dispose();
    }
  });

  Future<List<LibrarySong>> readSongs(String path) => run(() {
    final db = _database.openInitializedLibraryDatabase(File(path));
    try {
      db.execute('BEGIN');
      final songs = _read.readSongs(db);
      db.execute('COMMIT');
      return songs;
    } finally {
      db.dispose();
    }
  });

  Future<RecentPageData> readRecent(String path, String queuePath) async {
    final content = await readContent(path, queuePath);
    final songs = content.songs;
    final recent = await run(() {
      final db = _database.openInitializedLibraryDatabase(File(path));
      try {
        _history.cleanupInvalidRecentPlayed(db);
        return (
          songs: _history.readRecentSongs(db, songs),
          playlists: _history.readRecentPlaylists(db),
          albums: _history.readRecentAlbums(db),
          artists: _history.readRecentArtists(db),
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

  Future<ShellNavigationData> readNavigation(
    String path,
    String queuePath,
  ) async {
    final content = await readContent(path, queuePath);
    return ShellNavigationData(
      songs: content.songs,
      playlists: content.playlists,
      folders: content.folders,
      recentSearches: content.recentSearches,
      nowPlaying: content.nowPlaying,
      rootPath: content.rootPath,
    );
  }

  static LibraryContentData _readContent(String path, String queuePath) {
    final db = _database.openInitializedLibraryDatabase(File(path));
    try {
      _playlists.cleanupInvalidPlaylistItems(db);
      db.execute('BEGIN');
      final settings = _read.readLibrarySettings(db);
      final songs = _read.readSongs(db);
      final content = LibraryContentData(
        songs: songs,
        folders: _read.readFolders(db),
        playlists: _playlists.readPlaylists(
          db,
          myFavoritesId: settings.myFavoritesId,
          nowPlayingId: settings.nowPlayingId,
        ),
        nowPlaying: _history.readNowPlaying(
          db,
          File(queuePath),
          settings.nowPlayingId,
        ),
        recentSearches: _search.readRecentSearches(db),
        favoritePlaylistId: settings.myFavoritesId,
        hasLibrary: songs.isNotEmpty,
        sortCriterion: settings.sortCriterion,
        albumsSort: settings.albumsSort,
        showCount: settings.showCount,
        hideMultiSelectCommandBarAfterOperation:
            settings.hideMultiSelectCommandBarAfterOperation,
        localViewMode: settings.localViewMode,
        rootPath: settings.rootPath,
        databasePath: path,
      );
      db.execute('COMMIT');
      return content;
    } finally {
      db.dispose();
    }
  }
}
