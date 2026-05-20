import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:sqlite3/sqlite3.dart';

import 'id3_tag_service.dart';
import 'artist_split_model.dart' as artist_split_model;
import 'library_models.dart';

const _activeState = 1;
const _inactiveState = 0;
const _hiddenState = -1;
const _smPlayerDatabaseName = 'SMPlayerSettings.db';
const _nowPlayingJsonName = 'NowPlaying.json';
const _legacyUwpPackageIdentityName = '23778SeakyTheLoner.SMPlayer';
const _recentSongLimit = 500;
const _recentCollectionLimit = 200;
const _audioFileExtensions = {
  '.aac',
  '.aiff',
  '.alac',
  '.ape',
  '.flac',
  '.m4a',
  '.mp3',
  '.ogg',
  '.opus',
  '.wav',
  '.wma',
};

const _recentRecordTypeSong = 0;
const _recentRecordTypePlaylist = 3;
const _recentRecordTypeAlbum = 4;
const _recentRecordTypeArtist = 5;
const _nowPlayingPlaylistName = 'Now Playing';
const _id3TagService = Id3TagService();

class LibraryRepository {
  const LibraryRepository();

  Future<MusicLibrarySnapshot> getMusicLibrarySnapshot() async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return const MusicLibrarySnapshot(
        songs: [],
        recentSongs: [],
        recentPlaylists: [],
        recentAlbums: [],
        recentArtists: [],
        recentSearches: [],
        playlists: [],
        folders: [],
        favoritePlaylistId: 0,
        nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
        hasLibrary: false,
        sortCriterion: MusicLibrarySortCriterion.title,
        albumsSort: AlbumSortCriterion.defaultSort,
        showCount: true,
        hideMultiSelectCommandBarAfterOperation: true,
        rootPath: '',
        databasePath: '',
      );
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readLibrarySettings(db);
      final songs = _readSongs(db);
      final folders = _readFolders(db);
      final playlists = _readPlaylists(db, settings);
      final recentSongs = _readRecentSongs(db, songs);
      final nowPlaying = _readNowPlaying(db, songs, settings.nowPlayingId);
      return MusicLibrarySnapshot(
        songs: songs,
        recentSongs: recentSongs,
        recentPlaylists: _readRecentPlaylists(db),
        recentAlbums: _readRecentAlbums(db),
        recentArtists: _readRecentArtists(db),
        recentSearches: _readRecentSearches(db),
        playlists: playlists,
        folders: folders,
        favoritePlaylistId: settings.myFavoritesId,
        nowPlaying: nowPlaying,
        hasLibrary: songs.isNotEmpty,
        sortCriterion: settings.sortCriterion,
        albumsSort: settings.albumsSort,
        showCount: settings.showCount,
        hideMultiSelectCommandBarAfterOperation:
            settings.hideMultiSelectCommandBarAfterOperation,
        rootPath: settings.rootPath,
        databasePath: databaseFile.path,
      );
    } finally {
      db.dispose();
    }
  }

  Future<bool> exportDataTo(String targetPath) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return false;
    }

    final target = File(targetPath);
    await target.parent.create(recursive: true);
    await databaseFile.copy(target.path);
    return true;
  }

  Future<bool> importDataFrom(String sourcePath) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      return false;
    }

    final databaseFile = await _resolveDatabaseFile();
    await databaseFile.parent.create(recursive: true);
    await source.copy(databaseFile.path);
    return true;
  }

  Future<void> replaceNowPlaying(List<int> songIds) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      _writeNowPlayingSongIds(db, songIds);
    } finally {
      db.dispose();
    }
  }

  Future<void> clearNowPlaying() async {
    await replaceNowPlaying([]);
  }

  Future<void> removeRecentPlayed(List<int> songIds) async {
    if (songIds.isEmpty) {
      return;
    }

    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final placeholders = List.filled(songIds.length, '?').join(', ');
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE RecentRecord
        SET State = ?
        WHERE Type = $_recentRecordTypeSong
          AND ItemId IN ($placeholders)
      ''',
        [_inactiveState, ...songIds.map((songId) => songId.toString())],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> clearRecentPlayed() async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE RecentRecord
        SET State = ?
        WHERE Type IN (
          $_recentRecordTypeSong,
          $_recentRecordTypePlaylist,
          $_recentRecordTypeAlbum,
          $_recentRecordTypeArtist
        )
      ''',
        [_inactiveState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> removeRecentSearches(List<int> entryIds) async {
    if (entryIds.isEmpty) {
      return;
    }

    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final placeholders = List.filled(entryIds.length, '?').join(', ');
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('DELETE FROM SearchHistory WHERE Id IN ($placeholders)', [
        ...entryIds,
      ]);
    } finally {
      db.dispose();
    }
  }

  Future<void> clearRecentSearches() async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('DELETE FROM SearchHistory');
    } finally {
      db.dispose();
    }
  }

  Future<void> deleteSongFromDisk(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songPath = _readActiveSongPath(db, songId);
      await File(songPath).delete();
      db.execute('BEGIN');
      try {
        _deleteSongsInsideTransaction(db, [songId], [songPath]);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> hideSong(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songPath = _readActiveSongPath(db, songId);
      db.execute('BEGIN');
      try {
        db.execute('UPDATE Music SET State = ? WHERE Id = ?', [
          _hiddenState,
          songId,
        ]);
        db.execute('UPDATE File SET State = ? WHERE Path = ?', [
          _hiddenState,
          songPath,
        ]);
        _upsertHiddenStorageItem(db, 'file', songPath);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> moveSongToFolder(int songId, String folderPath) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songPath = _readActiveSongPath(db, songId);
      if (_getFileParentPath(songPath) == folderPath) {
        return;
      }

      final targetDirectory = Directory(folderPath);
      if (targetDirectory.statSync().type != FileSystemEntityType.directory) {
        throw StateError('Target path is not a folder.');
      }

      var targetPath = p.join(folderPath, p.basename(songPath));
      if (FileSystemEntity.typeSync(targetPath) !=
          FileSystemEntityType.notFound) {
        targetPath = _getAvailableSiblingPath(targetPath);
      }

      await File(songPath).rename(targetPath);
      db.execute('BEGIN');
      try {
        final folderId = _readActiveFolderId(db, folderPath) ?? 0;
        db.execute(
          '''
          UPDATE Music
          SET Path = ?
          WHERE Id = ?
            AND State = ?
        ''',
          [targetPath, songId, _activeState],
        );
        db.execute(
          '''
          UPDATE File
          SET Path = ?, ParentId = ?
          WHERE Path = ?
        ''',
          [targetPath, folderId, songPath],
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> moveLocalItemsToFolder(
    List<int> songIds,
    List<String> folderPaths,
    String targetFolderPath,
  ) async {
    if (songIds.isEmpty && folderPaths.isEmpty) {
      return;
    }

    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final targetDirectory = Directory(targetFolderPath);
      if (targetDirectory.statSync().type != FileSystemEntityType.directory) {
        throw StateError('Target path is not a folder.');
      }

      final movedSongs = <({int id, String oldPath, String newPath})>[];
      if (songIds.isNotEmpty) {
        final placeholders = List.filled(songIds.length, '?').join(', ');
        final rows = db.select(
          '''
          SELECT Id AS id, Path AS path
          FROM Music
          WHERE Id IN ($placeholders)
            AND State = ?
        ''',
          [...songIds, _activeState],
        );
        for (final row in rows) {
          final songPath = row['path'] as String;
          if (_getFileParentPath(songPath) == targetFolderPath) {
            continue;
          }
          var targetPath = p.join(targetFolderPath, p.basename(songPath));
          if (FileSystemEntity.typeSync(targetPath) !=
              FileSystemEntityType.notFound) {
            targetPath = _getAvailableSiblingPath(targetPath);
          }
          await File(songPath).rename(targetPath);
          movedSongs.add((
            id: row['id'] as int,
            oldPath: songPath,
            newPath: targetPath,
          ));
        }
      }

      final movedFolders = <({String oldPath, String newPath})>[];
      for (final folderPath in folderPaths) {
        var targetPath = p.join(targetFolderPath, p.basename(folderPath));
        if (FileSystemEntity.typeSync(targetPath) !=
            FileSystemEntityType.notFound) {
          targetPath = _getAvailableSiblingPath(targetPath);
        }
        await Directory(folderPath).rename(targetPath);
        movedFolders.add((oldPath: folderPath, newPath: targetPath));
      }

      db.execute('BEGIN');
      try {
        final targetFolderId = _readActiveFolderId(db, targetFolderPath) ?? 0;
        for (final movedSong in movedSongs) {
          db.execute(
            '''
            UPDATE Music
            SET Path = ?
            WHERE Id = ?
              AND State = ?
          ''',
            [movedSong.newPath, movedSong.id, _activeState],
          );
          db.execute(
            '''
            UPDATE File
            SET Path = ?, ParentId = ?
            WHERE Path = ?
          ''',
            [movedSong.newPath, targetFolderId, movedSong.oldPath],
          );
        }

        for (final movedFolder in movedFolders) {
          _updatePathPrefixInsideTransaction(
            db,
            table: 'Music',
            oldPath: movedFolder.oldPath,
            newPath: movedFolder.newPath,
          );
          _updatePathPrefixInsideTransaction(
            db,
            table: 'File',
            oldPath: movedFolder.oldPath,
            newPath: movedFolder.newPath,
          );
          _updatePathPrefixInsideTransaction(
            db,
            table: 'Folder',
            oldPath: movedFolder.oldPath,
            newPath: movedFolder.newPath,
          );
          db.execute(
            '''
            UPDATE Folder
            SET ParentId = ?
            WHERE Path = ?
              AND State = ?
          ''',
            [targetFolderId, movedFolder.newPath, _activeState],
          );
        }
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> deleteLocalItems(
    List<int> songIds,
    List<String> folderPaths,
  ) async {
    if (songIds.isEmpty && folderPaths.isEmpty) {
      return;
    }

    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = _readActiveSongsForLocalItems(db, songIds, folderPaths);
      for (final row in songRows) {
        final file = File(row.path);
        if (file.existsSync()) {
          await file.delete();
        }
      }
      for (final folderPath in folderPaths) {
        final directory = Directory(folderPath);
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      }

      db.execute('BEGIN');
      try {
        if (songRows.isNotEmpty) {
          _deleteSongsInsideTransaction(
            db,
            songRows.map((row) => row.id).toList(),
            songRows.map((row) => row.path).toList(),
          );
        }
        _updateFolderPathStateInsideTransaction(
          db,
          folderPaths,
          _inactiveState,
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> hideFolder(String folderPath) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _updateFolderPathStateInsideTransaction(db, [folderPath], _hiddenState);
        _upsertHiddenStorageItem(db, 'folder', folderPath);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<List<HiddenStorageItem>> getHiddenStorageItems() async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return const [];
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT Id AS id, Type AS type, Path AS path
        FROM HiddenStorageItem
        WHERE State = ?
        ORDER BY Id DESC
      ''',
        [_activeState],
      );
      return [
        for (final row in rows)
          HiddenStorageItem(
            id: row['id'] as int,
            type: row['type'] as String,
            path: row['path'] as String,
          ),
      ];
    } finally {
      db.dispose();
    }
  }

  Future<void> resumeHiddenStorageItem(HiddenStorageItem item) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        if (item.type == 'folder') {
          _updateFolderPathStateInsideTransaction(db, [
            item.path,
          ], _activeState);
        } else {
          db.execute('UPDATE Music SET State = ? WHERE Path = ?', [
            _activeState,
            item.path,
          ]);
          db.execute('UPDATE File SET State = ? WHERE Path = ?', [
            _activeState,
            item.path,
          ]);
        }
        db.execute(
          '''
          UPDATE HiddenStorageItem
          SET State = ?
          WHERE Id = ?
        ''',
          [_inactiveState, item.id],
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> renameFolder(String folderPath, String name) async {
    final targetPath = p.join(p.dirname(folderPath), name);
    await Directory(folderPath).rename(targetPath);

    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _updatePathPrefixInsideTransaction(
          db,
          table: 'Music',
          oldPath: folderPath,
          newPath: targetPath,
        );
        _updatePathPrefixInsideTransaction(
          db,
          table: 'File',
          oldPath: folderPath,
          newPath: targetPath,
        );
        _updatePathPrefixInsideTransaction(
          db,
          table: 'Folder',
          oldPath: folderPath,
          newPath: targetPath,
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> addRecentSearch(
    String query, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) async {
    final nextQuery = query.trim();
    if (nextQuery.isEmpty) {
      return;
    }

    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        db.execute(
          '''
          DELETE FROM SearchHistory
          WHERE Query = ? COLLATE NOCASE
            AND Type = ?
        ''',
          [nextQuery, _toStoredSearchHistoryType(type)],
        );
        db.execute(
          '''
          INSERT INTO SearchHistory (Query, Type, SearchedAt)
          VALUES (?, ?, ?)
        ''',
          [
            nextQuery,
            _toStoredSearchHistoryType(type),
            DateTime.now().toUtc().toIso8601String(),
          ],
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> updateMusicLibrarySort(
    MusicLibrarySortCriterion criterion,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('UPDATE Settings SET MusicLibraryCriterion = ? WHERE Id = ?', [
        _toStoredSortCriterion(criterion),
        1,
      ]);
    } finally {
      db.dispose();
    }
  }

  Future<void> updateAlbumsSort(AlbumSortCriterion criterion) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('UPDATE Settings SET AlbumsCriterion = ? WHERE Id = ?', [
        _toStoredAlbumSortCriterion(criterion),
        1,
      ]);
    } finally {
      db.dispose();
    }
  }

  Future<void> updateLocalFolderSort(
    String folderPath,
    LocalFolderSortCriterion criterion,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE Folder
        SET Criterion = ?
        WHERE Path = ?
          AND State = ?
      ''',
        [
          _toStoredLocalFolderSortCriterion(criterion),
          folderPath,
          _activeState,
        ],
      );
    } finally {
      db.dispose();
    }
  }

  Future<LibraryPlaylist> createPlaylist(
    String name, [
    List<int> songIds = const [],
  ]) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readLibrarySettings(db);
      final nextName = _validatePlaylistName(db, name);
      db.execute('BEGIN');
      try {
        db.execute(
          '''
          UPDATE Playlist
          SET Priority = Priority + 1
          WHERE State = ?
            AND Id NOT IN (?, ?)
            AND Name <> ?
        ''',
          [
            _activeState,
            settings.myFavoritesId,
            settings.nowPlayingId,
            _nowPlayingPlaylistName,
          ],
        );
        db.execute(
          '''
          INSERT INTO Playlist (Name, Criterion, Priority, State)
          VALUES (?, -1, ?, ?)
        ''',
          [nextName, 0, _activeState],
        );
        final playlistId = db.lastInsertRowId;
        _setPlaylistSongsState(db, playlistId, songIds, true);
        db.execute('COMMIT');
        final playlistSongIds = _uniqueSongIds(songIds);
        return LibraryPlaylist(
          id: playlistId,
          name: nextName,
          priority: 0,
          songCount: playlistSongIds.length,
          songIds: playlistSongIds,
          sortCriterion: PlaylistSortCriterion.title,
          isBuiltIn: false,
        );
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> deletePlaylist(int playlistId) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readLibrarySettings(db);
      if (playlistId == settings.myFavoritesId ||
          playlistId == settings.nowPlayingId) {
        throw StateError('Built-in playlists cannot be deleted.');
      }

      db.execute('BEGIN');
      try {
        db.execute('UPDATE Playlist SET State = ? WHERE Id = ?', [
          _inactiveState,
          playlistId,
        ]);
        db.execute('UPDATE PlaylistItem SET State = ? WHERE PlaylistId = ?', [
          _inactiveState,
          playlistId,
        ]);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> renamePlaylist(int playlistId, String name) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readLibrarySettings(db);
      if (playlistId == settings.myFavoritesId ||
          playlistId == settings.nowPlayingId) {
        throw StateError('Built-in playlists cannot be renamed.');
      }

      final nextName = _validatePlaylistName(
        db,
        name,
        currentPlaylistId: playlistId,
      );
      db.execute('UPDATE Playlist SET Name = ? WHERE Id = ?', [
        nextName,
        playlistId,
      ]);
    } finally {
      db.dispose();
    }
  }

  Future<void> reorderPlaylists(List<int> playlistIds) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readLibrarySettings(db);
      final rows = db.select(
        '''
        SELECT Playlist.Id AS id
        FROM Playlist
        WHERE Playlist.State = ?
          AND Playlist.Id NOT IN (?, ?)
          AND Playlist.Name <> ?
        ORDER BY
          CASE WHEN Playlist.Priority < 0 THEN 2147483647 ELSE Playlist.Priority END,
          LOWER(Playlist.Name),
          Playlist.Id
      ''',
        [
          _activeState,
          settings.myFavoritesId,
          settings.nowPlayingId,
          _nowPlayingPlaylistName,
        ],
      );
      final currentPlaylistIds = rows.map((row) => row['id'] as int).toList();
      if (currentPlaylistIds.length <= 1) {
        return;
      }

      if (currentPlaylistIds.length != playlistIds.length ||
          currentPlaylistIds.any(
            (playlistId) => !playlistIds.contains(playlistId),
          )) {
        throw StateError(
          'Playlist reorder request is out of sync with the current playlist list.',
        );
      }

      final firstChangedIndex =
          playlistIds.indexed
              .where((entry) => entry.$2 != currentPlaylistIds[entry.$1])
              .map((entry) => entry.$1)
              .firstOrNull;
      if (firstChangedIndex == null) {
        return;
      }

      final reversedChangedIndex =
          playlistIds.reversed.indexed
              .where(
                (entry) =>
                    entry.$2 !=
                    currentPlaylistIds[currentPlaylistIds.length -
                        1 -
                        entry.$1],
              )
              .map((entry) => entry.$1)
              .first;
      final lastChangedIndex = playlistIds.length - 1 - reversedChangedIndex;
      final changedPlaylistIds = playlistIds.sublist(
        firstChangedIndex,
        lastChangedIndex + 1,
      );
      final priorityCases = List.filled(
        changedPlaylistIds.length,
        'WHEN ? THEN ?',
      ).join(' ');
      final playlistIdPlaceholders = List.filled(
        changedPlaylistIds.length,
        '?',
      ).join(', ');
      final priorityCaseValues =
          changedPlaylistIds.indexed
              .expand((entry) => [entry.$2, firstChangedIndex + entry.$1])
              .toList();

      db.execute(
        '''
        UPDATE Playlist
        SET Priority = CASE Id $priorityCases END
        WHERE Id IN ($playlistIdPlaceholders)
      ''',
        [...priorityCaseValues, ...changedPlaylistIds],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> setSongFavorite(int songId, bool favorite) async {
    await setSongsFavorite([songId], favorite);
  }

  Future<ArtistSplitAnalysisResult> analyzeArtistSplits() async {
    final snapshot = await getMusicLibrarySnapshot();
    return artist_split_model.analyzeArtistSplits(snapshot.songs);
  }

  Future<void> applyArtistSplits(List<ArtistSplitResultItem> splits) async {
    if (splits.isEmpty) {
      return;
    }

    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        for (final split in splits) {
          final artists = _normalizeArtists(split.artists).take(6).toList();
          db.execute(
            '''
            UPDATE Music
            SET Artist = ?
            WHERE Id = ?
              AND State = ?
          ''',
            [artists.join(', '), split.songId, _activeState],
          );
          _syncSongArtists(db, split.songId, artists);
        }
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<List<int>> importExternalAudioFiles(List<String> filePaths) async {
    final audioFiles =
        filePaths.where((filePath) {
          return _audioFileExtensions.contains(
                p.extension(filePath).toLowerCase(),
              ) &&
              File(filePath).existsSync();
        }).toList();
    if (audioFiles.isEmpty) {
      return const [];
    }

    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    final openedSongIds = <int>[];
    try {
      db.execute('BEGIN');
      try {
        for (final filePath in audioFiles) {
          openedSongIds.add(await _upsertExternalAudioFile(db, filePath));
        }
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }

    return openedSongIds;
  }

  Future<LocalFolderRefreshResult> refreshLocalFolder(
    String folderPath, {
    void Function(LocalFolderRefreshProgress progress)? onProgress,
  }) async {
    final scannedPaths = _findAudioFiles(folderPath);
    final scannedPathKeys = scannedPaths.map(_pathComparisonKey).toSet();
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final existingRows = db.select(
        '''
        SELECT Id AS id, Path AS path
        FROM Music
        WHERE State = ?
          AND (Path = ? OR Path LIKE ? OR Path LIKE ?)
      ''',
        [_activeState, folderPath, '$folderPath/%', '$folderPath\\%'],
      );
      final existingPathKeys = {
        for (final row in existingRows)
          _pathComparisonKey(row['path'] as String): row,
      };
      final addedPaths =
          scannedPaths.where((filePath) {
            return !existingPathKeys.containsKey(_pathComparisonKey(filePath));
          }).toList();
      final removedRows =
          existingRows.where((row) {
            return !scannedPathKeys.contains(
              _pathComparisonKey(row['path'] as String),
            );
          }).toList();

      db.execute('BEGIN');
      try {
        if (removedRows.isNotEmpty) {
          _deleteSongsInsideTransaction(
            db,
            removedRows.map((row) => row['id'] as int).toList(),
            removedRows.map((row) => row['path'] as String).toList(),
          );
        }
        for (final entry in addedPaths.indexed) {
          onProgress?.call(
            LocalFolderRefreshProgress(
              current: entry.$1,
              total: addedPaths.length,
              currentPath: entry.$2,
            ),
          );
          await _upsertExternalAudioFile(db, entry.$2);
        }

        final artistAnalysis = artist_split_model.analyzeArtistSplits(
          _readSongs(db),
        );
        for (final split in artistAnalysis.directSplits) {
          final artists = _normalizeArtists(split.artists).take(6).toList();
          db.execute(
            '''
            UPDATE Music
            SET Artist = ?
            WHERE Id = ?
              AND State = ?
          ''',
            [artists.join(', '), split.songId, _activeState],
          );
          _syncSongArtists(db, split.songId, artists);
        }
        db.execute('COMMIT');

        return LocalFolderRefreshResult(
          filesAdded: addedPaths,
          filesRemoved:
              removedRows.map((row) => row['path'] as String).toList(),
          filesMoved: const [],
          artistSplitsApplied: artistAnalysis.directSplits,
          artistSplitSuggestions: artistAnalysis.possibleSplits,
          artistMergeSuggestions: artistAnalysis.mergeSuggestions,
        );
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> setSongsFavorite(List<int> songIds, bool favorite) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readLibrarySettings(db);
      db.execute('BEGIN');
      try {
        _setPlaylistSongsState(db, settings.myFavoritesId, songIds, favorite);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<SongPropertiesSnapshot> getSongProperties(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT
          Id AS id,
          Path AS path,
          Name AS title,
          Artist AS artist,
          Album AS album,
          Duration AS duration,
          PlayCount AS playCount
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      final row = rows.first;
      final artists = _readSongArtists(db, songId, row['artist'] as String);
      final file = File(row['path'] as String);
      final stats = await file.stat();
      final extension = p.extension(file.path).replaceFirst('.', '');
      final id3Properties = await _id3TagService.readSongTagProperties(
        file.path,
      );
      final title = _normalizeTagText(id3Properties.title);
      final artist = _normalizeTagText(id3Properties.artist);
      final album = _normalizeTagText(id3Properties.album);

      return SongPropertiesSnapshot(
        songId: songId,
        path: file.path,
        title:
            title.isEmpty ? _normalizeTagText(row['title'] as String) : title,
        subtitle: id3Properties.subtitle,
        artist:
            artist.isEmpty
                ? _normalizeTagText(row['artist'] as String)
                : artist,
        artists: artists,
        album:
            album.isEmpty ? _normalizeTagText(row['album'] as String) : album,
        albumArtist: id3Properties.albumArtist,
        publisher: id3Properties.publisher,
        trackNumber: id3Properties.trackNumber,
        year: id3Properties.year,
        genre: id3Properties.genre,
        composers: id3Properties.composers,
        duration: row['duration'] as int,
        bitrate: 0,
        fileSize: stats.size,
        dateCreated: stats.changed.toIso8601String(),
        dateModified: stats.modified.toIso8601String(),
        fileType: extension.toUpperCase(),
        playCount: row['playCount'] as int,
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> updateSongProperties(
    int songId,
    SongPropertiesUpdate update,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    final title = update.title.trim();
    final artists = _normalizeArtists(update.artists).take(6).toList();
    final artist = artists.join(', ');
    final album = update.album.trim();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = db.select(
        '''
        SELECT Path AS path
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      final songPath = songRows.first['path'] as String;
      await _id3TagService.writeSongTagProperties(
        songPath,
        Id3SongTagProperties(
          title: title,
          subtitle: update.subtitle.trim(),
          artist: artist,
          album: album,
          albumArtist: update.albumArtist.trim(),
          publisher: update.publisher.trim(),
          trackNumber: update.trackNumber,
          year: update.year,
          genre: update.genre.trim(),
          composers: update.composers.trim(),
        ),
      );

      db.execute('BEGIN');
      try {
        db.execute(
          '''
          UPDATE Music
          SET Name = ?, Artist = ?, Album = ?, PlayCount = ?
          WHERE Id = ?
            AND State = ?
        ''',
          [title, artist, album, update.playCount, songId, _activeState],
        );
        _syncSongArtists(db, songId, artists);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> updateSongPlayCount(int songId, int playCount) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE Music
        SET PlayCount = ?
        WHERE Id = ?
          AND State = ?
      ''',
        [playCount, songId, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<LyricsSnapshot> getSongLyrics(int songId) async {
    final songPath = await _getSongPath(songId);
    final sidecarLyrics = await _getSidecarLyrics(songPath);
    if (sidecarLyrics != null) {
      return sidecarLyrics;
    }

    final embeddedLyrics = await _id3TagService.readEmbeddedLyrics(songPath);
    if (embeddedLyrics.trim().isNotEmpty) {
      return _createLyricsSnapshot(embeddedLyrics, LyricsSource.musicFile);
    }

    return _createLyricsSnapshot('', LyricsSource.none);
  }

  Future<void> saveSongLyrics(int songId, String rawLyrics) async {
    final songPath = await _getSongPath(songId);
    await _writeLyricsToSongPath(songPath, rawLyrics);
  }

  Future<void> updateLyricsOffset(int songId, int offsetMs) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE Music
        SET LyricsOffsetMs = ?
        WHERE Id = ?
          AND State = ?
      ''',
        [offsetMs, songId, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<LyricsSnapshot> getInternetLyrics(int songId) async {
    final song = await _getLyricsSongLookup(songId);
    final rawLyrics = await _searchInternetLyrics(song);
    return _createLyricsSnapshot(
      rawLyrics,
      rawLyrics.trim().isEmpty ? LyricsSource.none : LyricsSource.internet,
    );
  }

  Future<LyricsBatchResult> batchAddInternetLyrics({
    bool overwrite = false,
    void Function(LyricsBatchProgress progress)? onProgress,
    bool Function()? isCanceled,
  }) async {
    final snapshot = await getMusicLibrarySnapshot();
    var saved = 0;
    var overwritten = 0;
    var skipped = 0;
    var missing = 0;
    var failed = 0;
    var backedUp = 0;
    var backupBytes = 0;
    var lastRequestStartedAt = DateTime.fromMillisecondsSinceEpoch(0);
    final details = <LyricsBatchDetail>[];

    for (var index = 0; index < snapshot.songs.length; index += 1) {
      if (isCanceled?.call() == true) {
        break;
      }

      final song = snapshot.songs[index];
      onProgress?.call(
        LyricsBatchProgress(
          currentIndex: index + 1,
          total: snapshot.songs.length,
          currentSongTitle: song.title,
          saved: saved,
          overwritten: overwritten,
          skipped: skipped,
          missing: missing,
          failed: failed,
          backedUp: backedUp,
          backupBytes: backupBytes,
        ),
      );

      try {
        final localLyrics = await _getSongLyricsByPath(song.path);
        final existingRawLyrics = localLyrics.rawText;
        if (!overwrite && existingRawLyrics.trim().isNotEmpty) {
          skipped += 1;
          details.add(
            LyricsBatchDetail(
              songId: song.id,
              title: song.title,
              result: LyricsBatchDetailResult.skipped,
              reason: LyricsBatchSkipReason.alreadyExists,
            ),
          );
          continue;
        }

        final elapsed =
            DateTime.now().difference(lastRequestStartedAt).inMilliseconds;
        if (lastRequestStartedAt.millisecondsSinceEpoch > 0 && elapsed < 200) {
          await Future<void>.delayed(Duration(milliseconds: 200 - elapsed));
        }
        lastRequestStartedAt = DateTime.now();
        final internetLyrics = await _searchInternetLyrics(
          _LyricsSongLookup(
            title: song.title,
            artist: song.artist,
            album: song.album,
            path: song.path,
          ),
        );

        if (internetLyrics.trim().isEmpty) {
          missing += 1;
          details.add(
            LyricsBatchDetail(
              songId: song.id,
              title: song.title,
              result: LyricsBatchDetailResult.missing,
            ),
          );
          continue;
        }

        if (overwrite &&
            _normalizeLyricsForCompare(existingRawLyrics) ==
                _normalizeLyricsForCompare(internetLyrics)) {
          skipped += 1;
          details.add(
            LyricsBatchDetail(
              songId: song.id,
              title: song.title,
              result: LyricsBatchDetailResult.skipped,
              reason: LyricsBatchSkipReason.sameContent,
            ),
          );
          continue;
        }

        if (existingRawLyrics.trim().isNotEmpty) {
          backedUp += 1;
          backupBytes += utf8.encode(existingRawLyrics).length;
        }
        await _writeLyricsToSongPath(song.path, internetLyrics);
        if (existingRawLyrics.trim().isEmpty) {
          saved += 1;
          details.add(
            LyricsBatchDetail(
              songId: song.id,
              title: song.title,
              result: LyricsBatchDetailResult.saved,
            ),
          );
        } else {
          overwritten += 1;
          details.add(
            LyricsBatchDetail(
              songId: song.id,
              title: song.title,
              result: LyricsBatchDetailResult.overwritten,
            ),
          );
        }
      } on Object {
        failed += 1;
        details.add(
          LyricsBatchDetail(
            songId: song.id,
            title: song.title,
            result: LyricsBatchDetailResult.failed,
          ),
        );
      }
    }

    return LyricsBatchResult(
      total: snapshot.songs.length,
      saved: saved,
      overwritten: overwritten,
      skipped: skipped,
      missing: missing,
      failed: failed,
      backedUp: backedUp,
      backupBytes: backupBytes,
      details: details,
    );
  }

  Future<SongArtworkSnapshot> getSongArtworkSnapshot(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT Path AS path, ThumbnailPath AS thumbnailPath
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      return await _resolveSongArtworkSnapshot(
        db,
        songId,
        rows.first['path'] as String,
        rows.first['thumbnailPath'] as String,
      );
    } finally {
      db.dispose();
    }
  }

  Future<List<SongArtworkSnapshot>> getSongArtworkSnapshots(
    List<int> songIds,
  ) async {
    final uniqueIds = songIds.toSet().toList();
    if (uniqueIds.isEmpty) {
      return [];
    }

    final databaseFile = await _resolveDatabaseFile();
    final placeholders = List.filled(uniqueIds.length, '?').join(', ');
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT Id AS id, Path AS path, ThumbnailPath AS thumbnailPath
        FROM Music
        WHERE Id IN ($placeholders)
          AND State = ?
      ''',
        [...uniqueIds, _activeState],
      );
      final rowsById = {for (final row in rows) row['id'] as int: row};
      return [
        for (final songId in uniqueIds)
          if (rowsById[songId] case final row?)
            await _resolveSongArtworkSnapshot(
              db,
              songId,
              row['path'] as String,
              row['thumbnailPath'] as String,
            )
          else
            _createSongArtworkSnapshot(songId, ''),
      ];
    } finally {
      db.dispose();
    }
  }

  Future<String> prepareSongArtworkSource(String sourcePath) async {
    final source = File(sourcePath);
    final cacheDirectory = await _resolveArtworkCacheDirectory();
    final extension = p.extension(source.path);
    if (extension.toLowerCase() == '.mp3') {
      final picture = await _id3TagService.readFirstPicture(source.path);
      if (picture == null) {
        throw StateError('No album art found in the selected music file.');
      }

      final target = File(
        p.join(
          cacheDirectory.path,
          '${DateTime.now().microsecondsSinceEpoch}${_extensionForMimeType(picture.format)}',
        ),
      );
      await target.writeAsBytes(picture.data);
      return target.path;
    }

    final target = File(
      p.join(
        cacheDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}$extension',
      ),
    );
    await source.copy(target.path);
    return target.path;
  }

  Future<void> saveSongArtwork(int songId, String sourcePath) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = db.select(
        '''
        SELECT Path AS path
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      final songPath = songRows.first['path'] as String;
      await _id3TagService.writeSongArtwork(
        songPath,
        Id3Picture(
          data: await File(sourcePath).readAsBytes(),
          format: _getArtworkMimeType(sourcePath),
        ),
      );

      db.execute(
        '''
        UPDATE Music
        SET ThumbnailPath = ?
        WHERE Id = ?
          AND State = ?
      ''',
        [sourcePath, songId, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> saveAlbumArtwork(String albumName, String sourcePath) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = db.select(
        '''
        SELECT Path AS path
        FROM Music
        WHERE Album = ?
          AND State = ?
      ''',
        [albumName, _activeState],
      );
      final picture = Id3Picture(
        data: await File(sourcePath).readAsBytes(),
        format: _getArtworkMimeType(sourcePath),
      );
      for (final row in songRows) {
        await _id3TagService.writeSongArtwork(row['path'] as String, picture);
      }

      db.execute(
        '''
        UPDATE Music
        SET ThumbnailPath = ?
        WHERE Album = ?
          AND State = ?
      ''',
        [sourcePath, albumName, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> deleteSongArtwork(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = db.select(
        '''
        SELECT Path AS path
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      await _id3TagService.writeSongArtwork(
        songRows.first['path'] as String,
        null,
      );

      db.execute(
        '''
        UPDATE Music
        SET ThumbnailPath = ''
        WHERE Id = ?
          AND State = ?
      ''',
        [songId, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> deleteAlbumArtwork(String albumName) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = db.select(
        '''
        SELECT Path AS path
        FROM Music
        WHERE Album = ?
          AND State = ?
      ''',
        [albumName, _activeState],
      );
      for (final row in songRows) {
        await _id3TagService.writeSongArtwork(row['path'] as String, null);
      }

      db.execute(
        '''
        UPDATE Music
        SET ThumbnailPath = ''
        WHERE Album = ?
          AND State = ?
      ''',
        [albumName, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> addPreferenceItem(
    String type,
    String itemId,
    String name,
    String level,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final entityValue = _toPreferenceEntityValue(type);
      final levelValue = _toPreferenceLevelValue(level);
      db.execute(
        '''
        UPDATE PreferenceItem
        SET ItemName = ?, IsEnabled = 1, Level = ?
        WHERE Type = ?
          AND ItemId = ?
          AND State = ?
      ''',
        [name, levelValue, entityValue, itemId, _activeState],
      );

      final changedRows =
          db.select('SELECT changes() AS count').first['count'] as int;
      if (changedRows == 0) {
        db.execute(
          '''
          INSERT INTO PreferenceItem (Type, ItemId, ItemName, IsEnabled, Level, State)
          VALUES (?, ?, ?, 1, ?, ?)
        ''',
          [entityValue, itemId, name, levelValue, _activeState],
        );
      }
    } finally {
      db.dispose();
    }
  }

  Future<String?> getPreferenceLevel(String type, String itemId) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return null;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT Level AS level
        FROM PreferenceItem
        WHERE Type = ?
          AND ItemId = ?
          AND IsEnabled = 1
          AND State = ?
        LIMIT 1
      ''',
        [_toPreferenceEntityValue(type), itemId, _activeState],
      );
      if (rows.isEmpty) {
        return null;
      }
      return _toPreferenceLevelName(rows.first['level'] as int);
    } finally {
      db.dispose();
    }
  }

  Future<void> removePreferenceItem(String type, String itemId) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE PreferenceItem
        SET IsEnabled = 0
        WHERE Type = ?
          AND ItemId = ?
          AND State = ?
      ''',
        [_toPreferenceEntityValue(type), itemId, _activeState],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    await addSongsToPlaylist(playlistId, [songId]);
  }

  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _setPlaylistSongsState(db, playlistId, songIds, true);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    await removeSongsFromPlaylist(playlistId, [songId]);
  }

  Future<void> removeSongsFromPlaylist(
    int playlistId,
    List<int> songIds,
  ) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _setPlaylistSongsState(db, playlistId, songIds, false);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> reorderPlaylistSongs(
    int playlistId,
    List<int> songIds, [
    PlaylistSortCriterion? sortCriterion,
  ]) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final nextSongIds = _uniqueSongIds(songIds);
      final currentSongIds = _readPlaylistSongIds(db, playlistId);
      final currentSongIdSet = currentSongIds.toSet();
      if (currentSongIdSet.length <= 1) {
        return;
      }

      if (currentSongIdSet.length != nextSongIds.length ||
          nextSongIds.any((songId) => !currentSongIdSet.contains(songId))) {
        throw StateError(
          'Playlist reorder request is out of sync with the current playlist.',
        );
      }

      db.execute('BEGIN');
      try {
        db.execute('UPDATE PlaylistItem SET State = ? WHERE PlaylistId = ?', [
          _inactiveState,
          playlistId,
        ]);
        _insertPlaylistSongsInOrder(db, playlistId, nextSongIds);
        if (sortCriterion != null) {
          db.execute('UPDATE Playlist SET Criterion = ? WHERE Id = ?', [
            _toStoredPlaylistSortCriterion(sortCriterion),
            playlistId,
          ]);
        }
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> recordPlaylistPlayed(int playlistId) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _recordRecentItemPlayed(
          db,
          playlistId.toString(),
          _recentRecordTypePlaylist,
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> recordAlbumPlayed(String album) async {
    await _recordCollectionPlayed(album, _recentRecordTypeAlbum);
  }

  Future<void> recordArtistPlayed(String artist) async {
    await _recordCollectionPlayed(artist, _recentRecordTypeArtist);
  }

  Future<void> _recordCollectionPlayed(String itemId, int type) async {
    final databaseFile = await _resolveDatabaseFile();
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _recordRecentItemPlayed(db, itemId, type);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  void _recordRecentItemPlayed(Database db, String itemId, int type) {
    db.execute(
      '''
      UPDATE RecentRecord
      SET State = ?
      WHERE Type = ?
        AND ItemId = ?
    ''',
      [_inactiveState, type, itemId],
    );
    db.execute(
      '''
      INSERT INTO RecentRecord (Type, ItemId, Time, State)
      VALUES (?, ?, ?, ?)
    ''',
      [type, itemId, DateTime.now().toUtc().toIso8601String(), _activeState],
    );
  }

  _LibrarySettings _readLibrarySettings(Database db) {
    final rows = db.select('''
      SELECT
        RootPath AS rootPath,
        MusicLibraryCriterion AS musicLibraryCriterion,
        AlbumsCriterion AS albumsCriterion,
        MyFavorites AS myFavorites,
        NowPlaying AS nowPlaying,
        ShowCount AS showCount,
        HideMultiSelectCommandBarAfterOperation
          AS hideMultiSelectCommandBarAfterOperation
      FROM Settings
      ORDER BY Id
      LIMIT 1
    ''');
    final rootPath = rows.isEmpty ? '' : (rows.first['rootPath'] as String);
    final musicLibraryCriterion =
        rows.isEmpty ? 0 : (rows.first['musicLibraryCriterion'] as int);
    final albumsCriterion =
        rows.isEmpty ? -1 : (rows.first['albumsCriterion'] as int);
    final myFavorites = rows.isEmpty ? 0 : (rows.first['myFavorites'] as int);
    final nowPlaying = rows.isEmpty ? 0 : (rows.first['nowPlaying'] as int);
    final showCount = rows.isEmpty || (rows.first['showCount'] as int) != 0;
    final hideMultiSelectCommandBarAfterOperation =
        rows.isEmpty ||
        (rows.first['hideMultiSelectCommandBarAfterOperation'] as int) != 0;

    return _LibrarySettings(
      rootPath: rootPath,
      sortCriterion: _fromStoredSortCriterion(musicLibraryCriterion),
      albumsSort: _fromStoredAlbumSortCriterion(albumsCriterion),
      myFavoritesId: myFavorites,
      nowPlayingId: nowPlaying,
      showCount: showCount,
      hideMultiSelectCommandBarAfterOperation:
          hideMultiSelectCommandBarAfterOperation,
    );
  }

  List<LibrarySong> _readSongs(Database db) {
    final rows = db.select(
      '''
      WITH SettingsRow AS (
        SELECT MyFavorites AS favoritePlaylistId
        FROM Settings
        ORDER BY Id
        LIMIT 1
      )
      SELECT
        Music.Id AS id,
        Music.Path AS path,
        Music.ThumbnailPath AS thumbnailPath,
        Music.Name AS title,
        Music.Artist AS artist,
        Music.Album AS album,
        Music.Duration AS duration,
        Music.PlayCount AS playCount,
        Music.LyricsOffsetMs AS lyricsOffsetMs,
        CAST(Music.DateAdded AS TEXT) AS dateAdded,
        EXISTS(
          SELECT 1
          FROM PlaylistItem, SettingsRow
          WHERE PlaylistItem.PlaylistId = SettingsRow.favoritePlaylistId
            AND PlaylistItem.ItemId = Music.Id
            AND PlaylistItem.State = ?
        ) AS favorite,
        COALESCE((
          SELECT group_concat(Name, char(31))
          FROM (
            SELECT MusicArtist.Name AS Name
            FROM MusicArtist
            WHERE MusicArtist.MusicId = Music.Id
              AND MusicArtist.State = ?
            ORDER BY MusicArtist.Priority, MusicArtist.Id
          )
        ), '') AS artistsValue
      FROM Music
      WHERE Music.State = ?
      ORDER BY Music.Name COLLATE NOCASE, Music.Artist COLLATE NOCASE, Music.Id
    ''',
      [_activeState, _activeState, _activeState],
    );

    return rows.map((row) {
      final artist = _normalizeTagText(row['artist'] as String);
      final artistsValue = row['artistsValue'] as String;
      final artists =
          artistsValue.isEmpty
              ? [artist]
              : artistsValue
                  .split(String.fromCharCode(31))
                  .map(_normalizeTagText)
                  .where((value) => value.isNotEmpty)
                  .toSet()
                  .toList();

      return LibrarySong(
        id: row['id'] as int,
        path: row['path'] as String,
        thumbnailPath: row['thumbnailPath'] as String,
        title: _normalizeTagText(row['title'] as String),
        artist: artist,
        artists: artists.isEmpty ? [artist] : artists,
        album: _normalizeTagText(row['album'] as String),
        duration: row['duration'] as int,
        playCount: row['playCount'] as int,
        lyricsOffsetMs: row['lyricsOffsetMs'] as int,
        dateAdded: row['dateAdded'] as String,
        favorite: (row['favorite'] as int) != 0,
      );
    }).toList();
  }

  String _readActiveSongPath(Database db, int songId) {
    final rows = db.select(
      '''
      SELECT Path AS path
      FROM Music
      WHERE Id = ?
        AND State = ?
      LIMIT 1
    ''',
      [songId, _activeState],
    );
    return rows.first['path'] as String;
  }

  int? _readActiveFolderId(Database db, String folderPath) {
    final rows = db.select(
      '''
      SELECT Id AS id
      FROM Folder
      WHERE Path = ?
        AND State = ?
      LIMIT 1
    ''',
      [folderPath, _activeState],
    );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  List<({int id, String path})> _readActiveSongsForLocalItems(
    Database db,
    List<int> songIds,
    List<String> folderPaths,
  ) {
    final clauses = <String>[];
    final args = <Object?>[];
    if (songIds.isNotEmpty) {
      clauses.add('Id IN (${List.filled(songIds.length, '?').join(', ')})');
      args.addAll(songIds);
    }
    for (final folderPath in folderPaths) {
      clauses.add('(Path LIKE ? OR Path LIKE ?)');
      args
        ..add('$folderPath/%')
        ..add('$folderPath\\%');
    }

    final rows = db.select(
      '''
      SELECT Id AS id, Path AS path
      FROM Music
      WHERE State = ?
        AND (${clauses.join(' OR ')})
    ''',
      [_activeState, ...args],
    );
    return [
      for (final row in rows)
        (id: row['id'] as int, path: row['path'] as String),
    ];
  }

  void _updatePathPrefixInsideTransaction(
    Database db, {
    required String table,
    required String oldPath,
    required String newPath,
  }) {
    db.execute(
      '''
      UPDATE $table
      SET Path = ? || substr(Path, ?)
      WHERE Path = ?
        OR Path LIKE ?
        OR Path LIKE ?
    ''',
      [newPath, oldPath.length + 1, oldPath, '$oldPath/%', '$oldPath\\%'],
    );
  }

  void _updateFolderPathStateInsideTransaction(
    Database db,
    List<String> folderPaths,
    int state,
  ) {
    for (final folderPath in folderPaths) {
      db.execute(
        '''
        UPDATE Folder
        SET State = ?
        WHERE Path = ?
          OR Path LIKE ?
          OR Path LIKE ?
      ''',
        [state, folderPath, '$folderPath/%', '$folderPath\\%'],
      );
      db.execute(
        '''
        UPDATE Music
        SET State = ?
        WHERE Path LIKE ?
          OR Path LIKE ?
      ''',
        [state, '$folderPath/%', '$folderPath\\%'],
      );
      db.execute(
        '''
        UPDATE File
        SET State = ?
        WHERE Path LIKE ?
          OR Path LIKE ?
      ''',
        [state, '$folderPath/%', '$folderPath\\%'],
      );
    }
  }

  void _deleteSongsInsideTransaction(
    Database db,
    List<int> songIds,
    List<String> songPaths,
  ) {
    final songPlaceholders = List.filled(songIds.length, '?').join(', ');
    db.execute(
      '''
      UPDATE Music
      SET State = ?
      WHERE Id IN ($songPlaceholders)
    ''',
      [_inactiveState, ...songIds],
    );
    db.execute(
      '''
      UPDATE MusicArtist
      SET State = ?
      WHERE MusicId IN ($songPlaceholders)
    ''',
      [_inactiveState, ...songIds],
    );
    db.execute(
      '''
      UPDATE PlaylistItem
      SET State = ?
      WHERE ItemId IN ($songPlaceholders)
    ''',
      [_inactiveState, ...songIds],
    );
    db.execute(
      '''
      UPDATE RecentRecord
      SET State = ?
      WHERE Type = $_recentRecordTypeSong
        AND ItemId IN ($songPlaceholders)
    ''',
      [_inactiveState, ...songIds.map((songId) => songId.toString())],
    );

    final pathPlaceholders = List.filled(songPaths.length, '?').join(', ');
    db.execute(
      '''
      UPDATE File
      SET State = ?
      WHERE Path IN ($pathPlaceholders)
    ''',
      [_inactiveState, ...songPaths],
    );
    db.execute(
      '''
      UPDATE HiddenStorageItem
      SET State = ?
      WHERE Type = 'file'
        AND Path IN ($pathPlaceholders)
    ''',
      [_inactiveState, ...songPaths],
    );
  }

  void _upsertHiddenStorageItem(Database db, String type, String itemPath) {
    db.execute(
      '''
      UPDATE HiddenStorageItem
      SET State = ?
      WHERE Type = ?
        AND Path = ?
    ''',
      [_activeState, type, itemPath],
    );

    final changedRows =
        db.select('SELECT changes() AS count').first['count'] as int;
    if (changedRows == 0) {
      db.execute(
        '''
        INSERT INTO HiddenStorageItem (Type, Path, State)
        VALUES (?, ?, ?)
      ''',
        [type, itemPath, _activeState],
      );
    }
  }

  String _getAvailableSiblingPath(String targetPath) {
    final extension = p.extension(targetPath);
    final basePath = targetPath.substring(
      0,
      targetPath.length - extension.length,
    );
    var index = 1;
    var nextPath = '$basePath ($index)$extension';
    while (FileSystemEntity.typeSync(nextPath) !=
        FileSystemEntityType.notFound) {
      index += 1;
      nextPath = '$basePath ($index)$extension';
    }
    return nextPath;
  }

  List<String> _readSongArtists(
    Database db,
    int songId,
    String fallbackArtist,
  ) {
    final rows = db.select(
      '''
      SELECT Name AS name
      FROM MusicArtist
      WHERE MusicId = ?
        AND State = ?
      ORDER BY Priority, Id
    ''',
      [songId, _activeState],
    );
    final artists = _normalizeArtists(
      rows.map((row) => row['name'] as String).toList(),
    );
    if (artists.isNotEmpty) {
      return artists;
    }

    return _normalizeArtists([fallbackArtist]);
  }

  void _syncSongArtists(Database db, int songId, List<String> artists) {
    db.execute('UPDATE MusicArtist SET State = ? WHERE MusicId = ?', [
      _inactiveState,
      songId,
    ]);
    if (artists.isEmpty) {
      return;
    }

    final values = List.filled(artists.length, '(?, ?, ?, ?)').join(', ');
    db.execute(
      '''
      INSERT INTO MusicArtist (MusicId, Name, Priority, State)
      VALUES $values
    ''',
      [
        for (final entry in artists.indexed) ...[
          songId,
          entry.$2,
          entry.$1,
          _activeState,
        ],
      ],
    );
  }

  Future<int> _upsertExternalAudioFile(Database db, String filePath) async {
    final properties = await _id3TagService.readSongTagProperties(filePath);
    final title =
        properties.title.trim().isEmpty
            ? p.basenameWithoutExtension(filePath)
            : properties.title.trim();
    final artist = properties.artist.trim();
    final album = properties.album.trim();
    final dateAdded = DateTime.now().toIso8601String();
    final rows = db.select(
      '''
      INSERT INTO Music (
        Path,
        Name,
        Artist,
        Album,
        ThumbnailPath,
        Duration,
        PlayCount,
        DateAdded,
        State
      )
      VALUES (
        ?, ?, ?, ?, '', 0,
        COALESCE((SELECT PlayCount FROM Music WHERE Path = ?), 0),
        COALESCE((SELECT DateAdded FROM Music WHERE Path = ?), ?),
        ?
      )
      ON CONFLICT(Path) DO UPDATE SET
        Name = excluded.Name,
        Artist = excluded.Artist,
        Album = excluded.Album,
        ThumbnailPath = excluded.ThumbnailPath,
        Duration = excluded.Duration,
        State = excluded.State
      RETURNING Id AS id
    ''',
      [
        filePath,
        title,
        artist,
        album,
        filePath,
        filePath,
        dateAdded,
        _activeState,
      ],
    );
    final songId = rows.first['id'] as int;
    _syncSongArtists(db, songId, _normalizeArtists([artist]));
    return songId;
  }

  Future<String> _getSongPath(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT Path AS path
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      return rows.first['path'] as String;
    } finally {
      db.dispose();
    }
  }

  Future<_LyricsSongLookup> _getLyricsSongLookup(int songId) async {
    final databaseFile = await _resolveDatabaseFile();
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        '''
        SELECT
          Path AS path,
          Name AS title,
          Artist AS artist,
          Album AS album
        FROM Music
        WHERE Id = ?
          AND State = ?
        LIMIT 1
      ''',
        [songId, _activeState],
      );
      final row = rows.first;
      return _LyricsSongLookup(
        title: row['title'] as String,
        artist: row['artist'] as String,
        album: row['album'] as String,
        path: row['path'] as String,
      );
    } finally {
      db.dispose();
    }
  }

  Future<String> _searchInternetLyrics(_LyricsSongLookup song) async {
    final songMid = await _getSongMid(song);
    if (songMid.isEmpty) {
      return '';
    }

    final uri = Uri.parse(
      'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg',
    ).replace(
      queryParameters: {'songmid': songMid, 'format': 'json', 'nobase64': '1'},
    );
    try {
      final response = await _fetchLyricsJson(uri);
      final lyrics =
          _decodeHtmlEntities(response['lyric'] as String? ?? '').trim();
      if (lyrics.isEmpty || _isNoLyricsPlaceholder(lyrics)) {
        return '';
      }

      return lyrics;
    } catch (_) {
      return '';
    }
  }

  Future<LyricsSnapshot> _getSongLyricsByPath(String songPath) async {
    final sidecarLyrics = await _getSidecarLyrics(songPath);
    if (sidecarLyrics != null) {
      return sidecarLyrics;
    }

    final embeddedLyrics = await _id3TagService.readEmbeddedLyrics(songPath);
    if (embeddedLyrics.trim().isNotEmpty) {
      return _createLyricsSnapshot(embeddedLyrics, LyricsSource.musicFile);
    }

    return _createLyricsSnapshot('', LyricsSource.none);
  }

  Future<String> _getSongMid(_LyricsSongLookup song) async {
    for (final attempt in _buildLyricsSearchAttempts(song)) {
      final songMid = await _searchSongMidByKeyword(
        attempt.keyword,
        attempt.title,
        attempt.artist,
      );
      if (songMid.isNotEmpty) {
        return songMid;
      }
    }

    return '';
  }

  List<_LyricsSearchAttempt> _buildLyricsSearchAttempts(
    _LyricsSongLookup song,
  ) {
    final simplifiedTitle = _removeBraces(song.title);
    final simplifiedArtist = _removeBraces(song.artist);
    final attempts = [
      _LyricsSearchAttempt(
        keyword: '${song.title} ${song.artist}'.trim(),
        title: song.title,
        artist: song.artist,
      ),
      _LyricsSearchAttempt(
        keyword: song.title,
        title: song.title,
        artist: song.artist,
      ),
      _LyricsSearchAttempt(
        keyword: '$simplifiedTitle ${song.artist}'.trim(),
        title: simplifiedTitle,
        artist: song.artist,
      ),
      _LyricsSearchAttempt(
        keyword: '${song.title} $simplifiedArtist'.trim(),
        title: song.title,
        artist: simplifiedArtist,
      ),
      _LyricsSearchAttempt(
        keyword: '$simplifiedTitle $simplifiedArtist'.trim(),
        title: simplifiedTitle,
        artist: simplifiedArtist,
      ),
      _LyricsSearchAttempt(
        keyword: simplifiedTitle,
        title: simplifiedTitle,
        artist: simplifiedArtist,
      ),
    ];
    final seen = <String>{};
    return [
      for (final attempt in attempts)
        if (attempt.keyword.isNotEmpty &&
            seen.add('${attempt.keyword}\n${attempt.title}\n${attempt.artist}'))
          attempt,
    ];
  }

  Future<String> _searchSongMidByKeyword(
    String keyword,
    String title,
    String artist,
  ) async {
    final uri = Uri.parse(
      'https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg',
    ).replace(
      queryParameters: {
        'cv': '4747474',
        'ct': '24',
        'format': 'json',
        'inCharset': 'utf-8',
        'outCharset': 'utf-8',
        'notice': '0',
        'platform': 'yqq.json',
        'needNewCode': '1',
        'key': keyword,
      },
    );
    try {
      final response = await _fetchLyricsJson(uri);
      final data = response['data'] as Map<String, Object?>?;
      final song = data?['song'] as Map<String, Object?>?;
      final items = song?['itemlist'] as List<Object?>? ?? const [];
      Map<String, Object?>? bestMatch;
      var bestScore = -1;

      for (final item in items.whereType<Map<String, Object?>>()) {
        final score =
            _evaluateLyricsMatch(title, item['name'] as String? ?? '') * 2 +
            _evaluateLyricsMatch(artist, item['singer'] as String? ?? '');
        if (score > bestScore) {
          bestScore = score;
          bestMatch = item;
        }
      }

      return bestScore > 0 ? (bestMatch?['mid'] as String? ?? '') : '';
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, Object?>> _fetchLyricsJson(Uri uri) async {
    final response = await http
        .get(
          uri,
          headers: const {
            'accept': 'application/json',
            'accept-language': 'en-US',
            'referer': 'https://y.qq.com/portal/player.html',
            'user-agent': 'Mozilla/5.0',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Lyrics request failed: ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, Object?>;
  }

  int _evaluateLyricsMatch(String target, String candidate) {
    final normalizedTarget = _normalizeLyricsLookupText(target);
    final normalizedCandidate = _normalizeLyricsLookupText(candidate);
    if (normalizedTarget.isEmpty) {
      return normalizedCandidate.isNotEmpty ? 20 : 0;
    }
    if (normalizedTarget == normalizedCandidate) {
      return 100;
    }
    if (normalizedCandidate.contains(normalizedTarget) ||
        normalizedTarget.contains(normalizedCandidate)) {
      return 70;
    }

    final targetTokens = normalizedTarget
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty);
    final candidateTokens = normalizedCandidate
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty);
    var score = 0;
    for (final token in targetTokens) {
      if (candidateTokens.any(
        (candidateToken) =>
            candidateToken.contains(token) || token.contains(candidateToken),
      )) {
        score += 20;
      }
    }
    return score;
  }

  String _normalizeLyricsLookupText(String value) {
    return _removeBraces(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _removeBraces(String value) {
    return value
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\[[^\]]*]'), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
          return String.fromCharCode(int.parse(match.group(1)!));
        })
        .replaceAll(r'\n', '\n');
  }

  bool _isNoLyricsPlaceholder(String rawLyrics) {
    final normalized =
        rawLyrics
            .replaceAll(
              RegExp(r'\[(ti|ar|al|by|offset):[^\]]*\]', caseSensitive: false),
              ' ',
            )
            .replaceAll(RegExp(r'\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\]'), ' ')
            .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '')
            .toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    return normalized.contains('姝ゆ瓕鏇蹭负娌℃湁濉瘝鐨勭函闊充箰璇锋偍娆ｈ祻');
  }

  String _normalizeLyricsForCompare(String rawLyrics) {
    return rawLyrics
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  Future<LyricsSnapshot?> _getSidecarLyrics(String songPath) async {
    final lrcFile = File(p.setExtension(songPath, '.lrc'));
    if (await lrcFile.exists()) {
      return _createLyricsSnapshot(
        await lrcFile.readAsString(),
        LyricsSource.lrcFile,
      );
    }

    final textFile = File(p.setExtension(songPath, '.txt'));
    if (await textFile.exists()) {
      return _createLyricsSnapshot(
        await textFile.readAsString(),
        LyricsSource.textFile,
      );
    }

    return null;
  }

  Future<void> _writeLyricsToSongPath(String songPath, String rawLyrics) async {
    final lrcFile = File(p.setExtension(songPath, '.lrc'));
    final textFile = File(p.setExtension(songPath, '.txt'));
    if (p.extension(songPath).toLowerCase() == '.mp3') {
      await _id3TagService.writeEmbeddedLyrics(songPath, rawLyrics);
      if (await lrcFile.exists()) {
        await lrcFile.writeAsString(rawLyrics);
      }
      if (await textFile.exists()) {
        await textFile.writeAsString(rawLyrics);
      }
      return;
    }

    if (await lrcFile.exists()) {
      await lrcFile.writeAsString(rawLyrics);
      if (rawLyrics.trim().isNotEmpty) {
        return;
      }
    }

    if (await textFile.exists()) {
      await textFile.writeAsString(rawLyrics);
      if (rawLyrics.trim().isNotEmpty) {
        return;
      }
    }

    await lrcFile.writeAsString(rawLyrics);
  }

  LyricsSnapshot _createLyricsSnapshot(String rawText, LyricsSource source) {
    final normalizedText = rawText.replaceFirst('\uFEFF', '').trim();
    final lines = _parseLyricsLines(normalizedText);
    return LyricsSnapshot(
      source: source,
      isSynced: lines.any((line) => line.timestampMs != null),
      rawText: normalizedText,
      lines: lines,
    );
  }

  List<LyricsLine> _parseLyricsLines(String rawText) {
    if (rawText.isEmpty) {
      return [];
    }

    final metadataRegex = RegExp(
      r'^\[(ti|ar|al|by|offset):',
      caseSensitive: false,
    );
    final offsetRegex = RegExp(
      r'^\[offset:([+-]?\d+)\]$',
      caseSensitive: false,
    );
    final timestampRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
    var offsetMs = 0;
    var lineId = 0;
    final parsedLines = <LyricsLine>[];

    for (final rawLine in rawText.split(RegExp(r'\r\n|[\n\r\u2028\u2029]'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final offsetMatch = offsetRegex.firstMatch(line);
      if (offsetMatch != null) {
        offsetMs = int.parse(offsetMatch.group(1)!);
        continue;
      }
      if (metadataRegex.hasMatch(line)) {
        continue;
      }

      final matches = timestampRegex.allMatches(line).toList();
      final text = line.replaceAll(timestampRegex, '').trim();
      if (matches.isEmpty) {
        parsedLines.add(LyricsLine(id: lineId, timestampMs: null, text: text));
        lineId += 1;
        continue;
      }

      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fraction = match.group(3) ?? '0';
        final fractionMs =
            fraction.length == 1
                ? int.parse(fraction) * 100
                : fraction.length == 2
                ? int.parse(fraction) * 10
                : int.parse(fraction.padRight(3, '0').substring(0, 3));
        parsedLines.add(
          LyricsLine(
            id: lineId,
            timestampMs:
                minutes * 60000 + seconds * 1000 + fractionMs + offsetMs,
            text: text,
          ),
        );
        lineId += 1;
      }
    }

    parsedLines.sort((left, right) {
      final leftTimestamp = left.timestampMs;
      final rightTimestamp = right.timestampMs;
      if (leftTimestamp == null && rightTimestamp == null) {
        return left.id.compareTo(right.id);
      }
      if (leftTimestamp == null) {
        return 1;
      }
      if (rightTimestamp == null) {
        return -1;
      }
      final timestampCompare = leftTimestamp.compareTo(rightTimestamp);
      return timestampCompare == 0
          ? left.id.compareTo(right.id)
          : timestampCompare;
    });
    return parsedLines;
  }

  Future<SongArtworkSnapshot> _resolveSongArtworkSnapshot(
    Database db,
    int songId,
    String songPath,
    String thumbnailPath,
  ) async {
    if (thumbnailPath.isNotEmpty && File(thumbnailPath).existsSync()) {
      return _createSongArtworkSnapshot(songId, thumbnailPath);
    }

    final picture = await _id3TagService.readFirstPicture(songPath);
    if (picture == null) {
      return _createSongArtworkSnapshot(songId, '');
    }

    final cacheDirectory = await _resolveArtworkCacheDirectory();
    final target = File(
      p.join(
        cacheDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}_$songId${_extensionForMimeType(picture.format)}',
      ),
    );
    await target.writeAsBytes(picture.data);
    db.execute(
      '''
      UPDATE Music
      SET ThumbnailPath = ?
      WHERE Id = ?
        AND State = ?
    ''',
      [target.path, songId, _activeState],
    );
    return SongArtworkSnapshot(
      songId: songId,
      artworkUrl: target.path,
      sourceUrl: target.path,
      sourcePath: target.path,
      source: SongArtworkSource.embedded,
    );
  }

  SongArtworkSnapshot _createSongArtworkSnapshot(
    int songId,
    String thumbnailPath,
  ) {
    if (thumbnailPath.isEmpty || !File(thumbnailPath).existsSync()) {
      return SongArtworkSnapshot(
        songId: songId,
        artworkUrl: '',
        sourceUrl: '',
        sourcePath: '',
        source: SongArtworkSource.none,
      );
    }

    return SongArtworkSnapshot(
      songId: songId,
      artworkUrl: thumbnailPath,
      sourceUrl: thumbnailPath,
      sourcePath: thumbnailPath,
      source: SongArtworkSource.cached,
    );
  }

  Future<Directory> _resolveArtworkCacheDirectory() async {
    final databaseFile = await _resolveDatabaseFile();
    final directory = Directory(
      p.join(databaseFile.parent.path, 'ArtworkCache'),
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  String _getArtworkMimeType(String sourcePath) {
    return switch (p.extension(sourcePath).toLowerCase()) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.bmp' => 'image/bmp',
      _ => 'image/jpeg',
    };
  }

  String _extensionForMimeType(String mimeType) {
    return switch (mimeType.toLowerCase()) {
      'image/jpeg' || 'image/jpg' => '.jpg',
      'image/png' => '.png',
      'image/webp' => '.webp',
      'image/bmp' => '.bmp',
      _ => '.jpg',
    };
  }

  List<LibraryFolder> _readFolders(Database db) {
    final rows = db.select(
      '''
      SELECT
        Id AS id,
        Path AS path,
        ParentId AS parentId,
        Criterion AS criterion
      FROM Folder
      WHERE State = ?
      ORDER BY Path COLLATE NOCASE
    ''',
      [_activeState],
    );

    return rows.map((row) {
      return LibraryFolder(
        id: row['id'] as int,
        path: row['path'] as String,
        parentId: row['parentId'] as int,
        criterion: row['criterion'] as int,
      );
    }).toList();
  }

  List<LibraryPlaylist> _readPlaylists(Database db, _LibrarySettings settings) {
    final playlistRows = db.select(
      '''
      SELECT
        Playlist.Id AS id,
        Playlist.Name AS name,
        Playlist.Criterion AS criterion,
        Playlist.Priority AS priority,
        COUNT(Music.Id) AS songCount
      FROM Playlist
      LEFT JOIN PlaylistItem
        ON PlaylistItem.PlaylistId = Playlist.Id
       AND PlaylistItem.State = ?
      LEFT JOIN Music
        ON Music.Id = PlaylistItem.ItemId
       AND Music.State = ?
      WHERE Playlist.State = ?
      GROUP BY Playlist.Id, Playlist.Name, Playlist.Criterion, Playlist.Priority
      ORDER BY
        CASE
          WHEN Playlist.Id = ? THEN 0
          WHEN Playlist.Id = ? THEN 1
          ELSE 2
        END,
        CASE WHEN Playlist.Priority < 0 THEN 2147483647 ELSE Playlist.Priority END,
        LOWER(Playlist.Name),
        Playlist.Id
    ''',
      [
        _activeState,
        _activeState,
        _activeState,
        settings.myFavoritesId,
        settings.nowPlayingId,
      ],
    );
    final itemRows = db.select(
      '''
      SELECT
        PlaylistItem.PlaylistId AS playlistId,
        PlaylistItem.ItemId AS songId
      FROM PlaylistItem
      INNER JOIN Playlist
        ON Playlist.Id = PlaylistItem.PlaylistId
      INNER JOIN Music
        ON Music.Id = PlaylistItem.ItemId
      WHERE PlaylistItem.State = ?
        AND Playlist.State = ?
        AND Music.State = ?
      ORDER BY PlaylistItem.Id
    ''',
      [_activeState, _activeState, _activeState],
    );
    final playlistSongIds = <int, List<int>>{};
    for (final row in itemRows) {
      final playlistId = row['playlistId'] as int;
      final songIds = playlistSongIds[playlistId] ?? <int>[];
      songIds.add(row['songId'] as int);
      playlistSongIds[playlistId] = songIds;
    }

    return playlistRows.map((row) {
      final id = row['id'] as int;
      return LibraryPlaylist(
        id: id,
        name: row['name'] as String,
        priority: row['priority'] as int,
        songCount: row['songCount'] as int,
        songIds: playlistSongIds[id] ?? const [],
        sortCriterion: _fromStoredPlaylistSortCriterion(
          row['criterion'] as int,
        ),
        isBuiltIn: id == settings.myFavoritesId,
      );
    }).toList();
  }

  List<RecentLibrarySong> _readRecentSongs(
    Database db,
    List<LibrarySong> songs,
  ) {
    final rows = db.select(
      '''
      SELECT
        RecentRecord.ItemId AS itemId,
        CAST(RecentRecord.Time AS TEXT) AS playedAt
      FROM RecentRecord
      INNER JOIN Music
        ON Music.Id = CAST(RecentRecord.ItemId AS INTEGER)
      WHERE RecentRecord.Type = $_recentRecordTypeSong
        AND RecentRecord.State = ?
        AND Music.State = ?
      ORDER BY RecentRecord.Id DESC
      LIMIT ?
    ''',
      [_activeState, _activeState, _recentSongLimit],
    );
    final songsById = {for (final song in songs) song.id: song};
    return rows.expand((row) {
      final song = songsById[int.parse(row['itemId'] as String)];
      return song == null
          ? const <RecentLibrarySong>[]
          : [
            RecentLibrarySong.fromSong(
              song,
              playedAt: row['playedAt'] as String,
            ),
          ];
    }).toList();
  }

  List<RecentPlaylistPlayback> _readRecentPlaylists(Database db) {
    final rows = db.select(
      '''
      SELECT
        RecentRecord.Id AS id,
        RecentRecord.ItemId AS itemId,
        CAST(RecentRecord.Time AS TEXT) AS playedAt
      FROM RecentRecord
      INNER JOIN Playlist
        ON Playlist.Id = CAST(RecentRecord.ItemId AS INTEGER)
      WHERE RecentRecord.Type = $_recentRecordTypePlaylist
        AND RecentRecord.State = ?
        AND Playlist.State = ?
      ORDER BY RecentRecord.Id DESC
      LIMIT ?
    ''',
      [_activeState, _activeState, _recentCollectionLimit],
    );
    return rows.map((row) {
      return RecentPlaylistPlayback(
        id: row['id'] as int,
        playlistId: int.parse(row['itemId'] as String),
        playedAt: row['playedAt'] as String,
      );
    }).toList();
  }

  List<RecentAlbumPlayback> _readRecentAlbums(Database db) {
    final rows = db.select(
      '''
      SELECT
        Id AS id,
        ItemId AS itemId,
        CAST(Time AS TEXT) AS playedAt
      FROM RecentRecord
      WHERE Type = $_recentRecordTypeAlbum
        AND State = ?
      ORDER BY Id DESC
      LIMIT ?
    ''',
      [_activeState, _recentCollectionLimit],
    );
    return rows.map((row) {
      return RecentAlbumPlayback(
        id: row['id'] as int,
        album: row['itemId'] as String,
        playedAt: row['playedAt'] as String,
      );
    }).toList();
  }

  List<RecentArtistPlayback> _readRecentArtists(Database db) {
    final rows = db.select(
      '''
      SELECT
        RecentRecord.Id AS id,
        RecentRecord.ItemId AS itemId,
        CAST(RecentRecord.Time AS TEXT) AS playedAt
      FROM RecentRecord
      WHERE RecentRecord.Type = $_recentRecordTypeArtist
        AND RecentRecord.State = ?
        AND EXISTS (
          SELECT 1
          FROM MusicArtist
          INNER JOIN Music
            ON Music.Id = MusicArtist.MusicId
          WHERE MusicArtist.Name = RecentRecord.ItemId
            AND MusicArtist.State = ?
            AND Music.State = ?
        )
      ORDER BY RecentRecord.Id DESC
      LIMIT ?
    ''',
      [_activeState, _activeState, _activeState, _recentCollectionLimit],
    );
    return rows.map((row) {
      return RecentArtistPlayback(
        id: row['id'] as int,
        artist: row['itemId'] as String,
        playedAt: row['playedAt'] as String,
      );
    }).toList();
  }

  List<SearchHistoryEntry> _readRecentSearches(Database db) {
    final rows = db.select('''
      SELECT
        Id AS id,
        Query AS query,
        Type AS type,
        SearchedAt AS searchedAt
      FROM SearchHistory
      ORDER BY datetime(SearchedAt) DESC, Id DESC
    ''');
    return rows.map((row) {
      return SearchHistoryEntry(
        id: row['id'] as int,
        query: row['query'] as String,
        type: _fromStoredSearchHistoryType(row['type'] as String),
        searchedAt: row['searchedAt'] as String,
      );
    }).toList();
  }

  NowPlayingSnapshot _readNowPlaying(
    Database db,
    List<LibrarySong> songs,
    int fallbackPlaylistId,
  ) {
    final paths = _readNowPlayingPaths();
    final songsByPath = {for (final song in songs) song.path: song.id};
    final songIds =
        paths.isEmpty
            ? _readPlaylistSongIds(db, fallbackPlaylistId)
            : paths.expand((path) {
              final songId = songsByPath[path];
              return songId == null ? const <int>[] : [songId];
            }).toList();

    return NowPlayingSnapshot(playlistId: fallbackPlaylistId, songIds: songIds);
  }

  List<int> _readPlaylistSongIds(Database db, int playlistId) {
    if (playlistId <= 0) {
      return const [];
    }

    final rows = db.select(
      '''
      SELECT PlaylistItem.ItemId AS songId
      FROM PlaylistItem
      INNER JOIN Music
        ON Music.Id = PlaylistItem.ItemId
      WHERE PlaylistItem.PlaylistId = ?
        AND PlaylistItem.State = ?
        AND Music.State = ?
      ORDER BY PlaylistItem.Id
    ''',
      [playlistId, _activeState, _activeState],
    );
    return rows.map((row) => row['songId'] as int).toList();
  }

  List<String> _readNowPlayingPaths() {
    final file = File(
      p.join(_defaultElectronUserDataPath(), _nowPlayingJsonName),
    );
    try {
      final data = jsonDecode(file.readAsStringSync());
      return data is List
          ? data.whereType<String>().where((item) => item.isNotEmpty).toList()
          : const [];
    } on Object {
      return const [];
    }
  }

  void _writeNowPlayingSongIds(Database db, List<int> songIds) {
    final file = File(
      p.join(_defaultElectronUserDataPath(), _nowPlayingJsonName),
    );
    if (songIds.isEmpty) {
      file.writeAsStringSync('[]');
      return;
    }

    final placeholders = List.filled(songIds.length, '?').join(', ');
    final rows = db.select(
      '''
      SELECT Id AS id, Path AS path
      FROM Music
      WHERE Id IN ($placeholders)
        AND State = ?
    ''',
      [...songIds, _activeState],
    );
    final pathsById = {
      for (final row in rows) row['id'] as int: row['path'] as String,
    };
    final songPaths =
        songIds.expand((songId) {
          final songPath = pathsById[songId];
          return songPath == null ? const <String>[] : [songPath];
        }).toList();

    file.writeAsStringSync(jsonEncode(songPaths));
  }

  String _validatePlaylistName(
    Database db,
    String name, {
    int? currentPlaylistId,
  }) {
    final nextName = name.trim();
    if (nextName.isEmpty) {
      throw ArgumentError('Playlist name cannot be empty.');
    }

    final rows = db.select(
      '''
      SELECT Id
      FROM Playlist
      WHERE Name = ?
        AND State = ?
      LIMIT 1
    ''',
      [nextName, _activeState],
    );
    if (rows.isNotEmpty && rows.first['Id'] != currentPlaylistId) {
      throw ArgumentError('Playlist "$nextName" already exists.');
    }

    return nextName;
  }

  void _setPlaylistSongsState(
    Database db,
    int playlistId,
    List<int> songIds,
    bool isActive,
  ) {
    final uniqueIds = _uniqueSongIds(songIds);
    if (uniqueIds.isEmpty) {
      return;
    }

    final placeholders = List.filled(uniqueIds.length, '?').join(', ');
    if (isActive) {
      db.execute(
        '''
        UPDATE PlaylistItem
        SET State = ?
        WHERE PlaylistId = ?
          AND ItemId IN ($placeholders)
      ''',
        [_inactiveState, playlistId, ...uniqueIds],
      );
      db.execute(
        '''
        UPDATE PlaylistItem
        SET State = ?
        WHERE Id IN (
          SELECT MAX(Id)
          FROM PlaylistItem
          WHERE PlaylistId = ?
            AND ItemId IN ($placeholders)
          GROUP BY ItemId
        )
      ''',
        [_activeState, playlistId, ...uniqueIds],
      );
      db.execute(
        '''
        INSERT INTO PlaylistItem (PlaylistId, ItemId, State)
        SELECT ?, Music.Id, ?
        FROM Music
        WHERE Music.Id IN ($placeholders)
          AND Music.State = ?
          AND NOT EXISTS (
            SELECT 1
            FROM PlaylistItem
            WHERE PlaylistItem.PlaylistId = ?
              AND PlaylistItem.ItemId = Music.Id
          )
      ''',
        [playlistId, _activeState, ...uniqueIds, _activeState, playlistId],
      );
      return;
    }

    db.execute(
      '''
      UPDATE PlaylistItem
      SET State = ?
      WHERE PlaylistId = ?
        AND ItemId IN ($placeholders)
    ''',
      [_inactiveState, playlistId, ...uniqueIds],
    );
  }

  void _insertPlaylistSongsInOrder(
    Database db,
    int playlistId,
    List<int> songIds,
  ) {
    final rows = List.filled(songIds.length, '(?, ?)').join(', ');
    db.execute(
      '''
      WITH OrderedSongs(SongId, Position) AS (
        VALUES $rows
      )
      INSERT INTO PlaylistItem (PlaylistId, ItemId, State)
      SELECT ?, OrderedSongs.SongId, ?
      FROM OrderedSongs
      JOIN Music
        ON Music.Id = OrderedSongs.SongId
       AND Music.State = ?
      ORDER BY OrderedSongs.Position
    ''',
      [
        ...songIds.indexed.expand((entry) => [entry.$2, entry.$1]),
        playlistId,
        _activeState,
        _activeState,
      ],
    );
  }

  Future<File> _resolveDatabaseFile() async {
    if (Platform.isWindows) {
      final uwpDatabase = _resolveWindowsUwpDatabaseFile();
      if (uwpDatabase != null) {
        return uwpDatabase;
      }
    }

    final appDataPath = _defaultElectronUserDataPath();
    return File(p.join(appDataPath, _smPlayerDatabaseName));
  }

  File? _resolveWindowsUwpDatabaseFile() {
    final localAppDataPath = Platform.environment['LOCALAPPDATA'];
    if (localAppDataPath == null) {
      return null;
    }

    final packagesDirectory = Directory(p.join(localAppDataPath, 'Packages'));
    if (!packagesDirectory.existsSync()) {
      return null;
    }

    final candidates =
        packagesDirectory
            .listSync()
            .whereType<Directory>()
            .where(
              (entry) => p
                  .basename(entry.path)
                  .startsWith('${_legacyUwpPackageIdentityName}_'),
            )
            .map(
              (entry) =>
                  File(p.join(entry.path, 'LocalState', _smPlayerDatabaseName)),
            )
            .where((file) => file.existsSync())
            .toList();

    candidates.sort(
      (left, right) =>
          right.lastModifiedSync().compareTo(left.lastModifiedSync()),
    );
    return candidates.isEmpty ? null : candidates.first;
  }

  String _defaultElectronUserDataPath() {
    if (Platform.isWindows) {
      return p.join(Platform.environment['APPDATA']!, 'simple-melody-player');
    }

    if (Platform.isMacOS) {
      return p.join(
        Platform.environment['HOME']!,
        'Library',
        'Application Support',
        'simple-melody-player',
      );
    }

    return p.join(
      Platform.environment['HOME']!,
      '.config',
      'simple-melody-player',
    );
  }
}

String _getFileParentPath(String filePath) {
  final separatorIndex = filePath.lastIndexOf(RegExp(r'[\\/]'));
  return separatorIndex > -1 ? filePath.substring(0, separatorIndex) : '';
}

class _LibrarySettings {
  const _LibrarySettings({
    required this.rootPath,
    required this.sortCriterion,
    required this.albumsSort,
    required this.myFavoritesId,
    required this.nowPlayingId,
    required this.showCount,
    required this.hideMultiSelectCommandBarAfterOperation,
  });

  final String rootPath;
  final MusicLibrarySortCriterion sortCriterion;
  final AlbumSortCriterion albumsSort;
  final int myFavoritesId;
  final int nowPlayingId;
  final bool showCount;
  final bool hideMultiSelectCommandBarAfterOperation;
}

MusicLibrarySortCriterion _fromStoredSortCriterion(int value) {
  switch (value) {
    case 1:
      return MusicLibrarySortCriterion.artist;
    case 2:
      return MusicLibrarySortCriterion.album;
    case 3:
      return MusicLibrarySortCriterion.duration;
    case 4:
      return MusicLibrarySortCriterion.playCount;
    case 5:
      return MusicLibrarySortCriterion.dateAdded;
    default:
      return MusicLibrarySortCriterion.title;
  }
}

PlaylistSortCriterion _fromStoredPlaylistSortCriterion(int value) {
  switch (value) {
    case 1:
      return PlaylistSortCriterion.artist;
    case 2:
      return PlaylistSortCriterion.album;
    case 3:
      return PlaylistSortCriterion.duration;
    case 4:
      return PlaylistSortCriterion.playCount;
    case 5:
      return PlaylistSortCriterion.dateAdded;
    default:
      return PlaylistSortCriterion.title;
  }
}

SearchHistoryType _fromStoredSearchHistoryType(String value) {
  switch (value) {
    case 'artists':
      return SearchHistoryType.artists;
    case 'albums':
      return SearchHistoryType.albums;
    case 'songs':
      return SearchHistoryType.songs;
    case 'playlists':
      return SearchHistoryType.playlists;
    case 'folders':
      return SearchHistoryType.folders;
    default:
      return SearchHistoryType.sidebar;
  }
}

String _toStoredSearchHistoryType(SearchHistoryType value) {
  switch (value) {
    case SearchHistoryType.artists:
      return 'artists';
    case SearchHistoryType.albums:
      return 'albums';
    case SearchHistoryType.songs:
      return 'songs';
    case SearchHistoryType.playlists:
      return 'playlists';
    case SearchHistoryType.folders:
      return 'folders';
    case SearchHistoryType.sidebar:
      return 'sidebar';
  }
}

int _toStoredSortCriterion(MusicLibrarySortCriterion value) {
  switch (value) {
    case MusicLibrarySortCriterion.artist:
      return 1;
    case MusicLibrarySortCriterion.album:
      return 2;
    case MusicLibrarySortCriterion.duration:
      return 3;
    case MusicLibrarySortCriterion.playCount:
      return 4;
    case MusicLibrarySortCriterion.dateAdded:
      return 5;
    case MusicLibrarySortCriterion.title:
      return 0;
  }
}

AlbumSortCriterion _fromStoredAlbumSortCriterion(int value) {
  switch (value) {
    case 1:
      return AlbumSortCriterion.artist;
    case 6:
      return AlbumSortCriterion.name;
    default:
      return AlbumSortCriterion.defaultSort;
  }
}

int _toStoredAlbumSortCriterion(AlbumSortCriterion value) {
  switch (value) {
    case AlbumSortCriterion.artist:
      return 1;
    case AlbumSortCriterion.name:
      return 6;
    case AlbumSortCriterion.defaultSort:
    case AlbumSortCriterion.reverse:
      return -1;
  }
}

int _toPreferenceEntityValue(String type) {
  return switch (type) {
    'song' => 0,
    'artist' => 1,
    'album' => 2,
    'playlist' => 3,
    'folder' => 4,
    'recent-added' => 5,
    'my-favorites' => 6,
    'most-played' => 7,
    'least-played' => 8,
    _ => throw ArgumentError.value(type, 'type'),
  };
}

int _toPreferenceLevelValue(String level) {
  return switch (level) {
    'do-not-appear' => 0,
    'dislike' => -1,
    'normal' => 1,
    'high' => 2,
    'higher' => 3,
    'very-high' => 4,
    _ => throw ArgumentError.value(level, 'level'),
  };
}

String _toPreferenceLevelName(int level) {
  return switch (level) {
    0 => 'do-not-appear',
    -1 => 'dislike',
    1 => 'normal',
    2 => 'high',
    3 => 'higher',
    4 => 'very-high',
    _ => 'normal',
  };
}

int _toStoredLocalFolderSortCriterion(LocalFolderSortCriterion value) {
  switch (value) {
    case LocalFolderSortCriterion.artist:
      return 1;
    case LocalFolderSortCriterion.album:
      return 2;
    case LocalFolderSortCriterion.reverse:
      return 7;
    case LocalFolderSortCriterion.title:
      return 0;
  }
}

int _toStoredPlaylistSortCriterion(PlaylistSortCriterion value) {
  switch (value) {
    case PlaylistSortCriterion.artist:
      return 1;
    case PlaylistSortCriterion.album:
      return 2;
    case PlaylistSortCriterion.duration:
      return 3;
    case PlaylistSortCriterion.playCount:
      return 4;
    case PlaylistSortCriterion.dateAdded:
      return 5;
    case PlaylistSortCriterion.title:
      return 0;
  }
}

List<int> _uniqueSongIds(List<int> songIds) {
  return songIds.map((songId) => songId).toSet().toList();
}

String _normalizeTagText(String value) {
  return value.trim();
}

List<String> _normalizeArtists(List<String> artists) {
  return artists
      .map(_normalizeTagText)
      .where((artist) => artist.isNotEmpty)
      .toSet()
      .toList();
}

List<String> _findAudioFiles(String folderPath) {
  return Directory(
    folderPath,
  ).listSync(recursive: true).whereType<File>().map((file) => file.path).where((
    filePath,
  ) {
    return _audioFileExtensions.contains(p.extension(filePath).toLowerCase());
  }).toList();
}

String _pathComparisonKey(String path) {
  return path.replaceAll('\\', '/').toLowerCase();
}

class _LyricsSongLookup {
  const _LyricsSongLookup({
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
  });

  final String title;
  final String artist;
  final String album;
  final String path;
}

class LyricsBatchProgress {
  const LyricsBatchProgress({
    required this.currentIndex,
    required this.total,
    required this.currentSongTitle,
    required this.saved,
    required this.overwritten,
    required this.skipped,
    required this.missing,
    required this.failed,
    required this.backedUp,
    required this.backupBytes,
  });

  final int currentIndex;
  final int total;
  final String currentSongTitle;
  final int saved;
  final int overwritten;
  final int skipped;
  final int missing;
  final int failed;
  final int backedUp;
  final int backupBytes;
}

class LyricsBatchResult {
  const LyricsBatchResult({
    required this.total,
    required this.saved,
    required this.overwritten,
    required this.skipped,
    required this.missing,
    required this.failed,
    required this.backedUp,
    required this.backupBytes,
    required this.details,
  });

  final int total;
  final int saved;
  final int overwritten;
  final int skipped;
  final int missing;
  final int failed;
  final int backedUp;
  final int backupBytes;
  final List<LyricsBatchDetail> details;
}

enum LyricsBatchDetailResult { saved, overwritten, skipped, missing, failed }

enum LyricsBatchSkipReason { alreadyExists, sameContent }

class LyricsBatchDetail {
  const LyricsBatchDetail({
    required this.songId,
    required this.title,
    required this.result,
    this.reason,
  });

  final int songId;
  final String title;
  final LyricsBatchDetailResult result;
  final LyricsBatchSkipReason? reason;
}

class _LyricsSearchAttempt {
  const _LyricsSearchAttempt({
    required this.keyword,
    required this.title,
    required this.artist,
  });

  final String keyword;
  final String title;
  final String artist;
}
