import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'library_models.dart';

const _activeState = 1;
const _inactiveState = 0;
const _recentRecordTypeSong = 0;
const _recentRecordTypePlaylist = 3;
const _recentRecordTypeAlbum = 4;
const _recentRecordTypeArtist = 5;
const _recentSongLimit = 500;
const _recentCollectionLimit = 200;

class LibraryPlaybackHistoryService {
  const LibraryPlaybackHistoryService();

  Future<void> replaceNowPlaying(
    File databaseFile,
    File nowPlayingFile,
    List<int> songIds,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      _writeNowPlayingSongIds(db, nowPlayingFile, songIds);
    } finally {
      db.dispose();
    }
  }

  Future<void> removeSongFromNowPlaying(
    File databaseFile,
    File nowPlayingFile,
    int songId,
  ) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final nextSongIds =
          _readNowPlayingSongIdsByPath(
            db,
            nowPlayingFile,
          ).where((queuedSongId) => queuedSongId != songId).toList();
      _writeNowPlayingSongIds(db, nowPlayingFile, nextSongIds);
    } finally {
      db.dispose();
    }
  }

  Future<void> removeRecentPlayed(File databaseFile, List<int> songIds) async {
    if (songIds.isEmpty) {
      return;
    }
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

  Future<void> clearRecentPlayed(File databaseFile) async {
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

  Future<void> restoreRecentPlayed(File databaseFile, List<int> songIds) async {
    if (songIds.isEmpty) {
      return;
    }
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
        [_activeState, ...songIds.map((songId) => songId.toString())],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> markSongPlayed(File databaseFile, int songId) async {
    if (!databaseFile.existsSync()) {
      return;
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        db.execute(
          '''
          UPDATE Music
          SET PlayCount = PlayCount + 1
          WHERE Id = ?
            AND State = ?
        ''',
          [songId, _activeState],
        );
        _recordRecentItemPlayed(db, songId.toString(), _recentRecordTypeSong);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> recordPlaylistPlayed(File databaseFile, int playlistId) async {
    await _recordPlayed(
      databaseFile,
      playlistId.toString(),
      _recentRecordTypePlaylist,
    );
  }

  Future<void> recordAlbumPlayed(File databaseFile, String album) async {
    await _recordPlayed(databaseFile, album, _recentRecordTypeAlbum);
  }

  Future<void> recordArtistPlayed(File databaseFile, String artist) async {
    await _recordPlayed(databaseFile, artist, _recentRecordTypeArtist);
  }

  void cleanupInvalidRecentPlayed(Database db) {
    db.execute(
      '''
      UPDATE RecentRecord
      SET State = ?
      WHERE Type = $_recentRecordTypeSong
        AND State = ?
        AND NOT EXISTS (
          SELECT 1
          FROM Music
          WHERE Music.Id = CAST(RecentRecord.ItemId AS INTEGER)
            AND Music.State = ?
        )
    ''',
      [_inactiveState, _activeState, _activeState],
    );
  }

  List<RecentLibrarySong> readRecentSongs(
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

  List<RecentPlaylistPlayback> readRecentPlaylists(Database db) {
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

  List<RecentAlbumPlayback> readRecentAlbums(Database db) {
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

  List<RecentArtistPlayback> readRecentArtists(Database db) {
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

  NowPlayingSnapshot readNowPlaying(
    Database db,
    File nowPlayingFile,
    int fallbackPlaylistId,
  ) {
    final paths = _readNowPlayingPaths(nowPlayingFile);
    final songIds =
        paths.isEmpty
            ? _readPlaylistSongIds(db, fallbackPlaylistId)
            : _readNowPlayingSongIdsFromPaths(db, paths);

    return NowPlayingSnapshot(playlistId: fallbackPlaylistId, songIds: songIds);
  }

  Future<void> _recordPlayed(File databaseFile, String itemId, int type) async {
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

  List<int> _readNowPlayingSongIdsByPath(Database db, File nowPlayingFile) {
    final paths = _readNowPlayingPaths(nowPlayingFile);
    return _readNowPlayingSongIdsFromPaths(db, paths);
  }

  List<int> _readNowPlayingSongIdsFromPaths(Database db, List<String> paths) {
    if (paths.isEmpty) {
      return const [];
    }
    final placeholders = List.filled(paths.length, '?').join(', ');
    final rows = db.select(
      '''
      SELECT Id AS id, Path AS path
      FROM Music
      WHERE Path IN ($placeholders)
        AND State = ?
    ''',
      [...paths, _activeState],
    );
    final songIdsByPath = {
      for (final row in rows) row['path'] as String: row['id'] as int,
    };
    return paths.expand((songPath) {
      final songId = songIdsByPath[songPath];
      return songId == null ? const <int>[] : [songId];
    }).toList();
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

  List<String> _readNowPlayingPaths(File nowPlayingFile) {
    try {
      final data = jsonDecode(nowPlayingFile.readAsStringSync());
      return data is List
          ? data.whereType<String>().where((item) => item.isNotEmpty).toList()
          : const [];
    } on Object {
      return const [];
    }
  }

  void _writeNowPlayingSongIds(
    Database db,
    File nowPlayingFile,
    List<int> songIds,
  ) {
    if (songIds.isEmpty) {
      nowPlayingFile.writeAsStringSync('[]');
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

    nowPlayingFile.writeAsStringSync(jsonEncode(songPaths));
  }
}
