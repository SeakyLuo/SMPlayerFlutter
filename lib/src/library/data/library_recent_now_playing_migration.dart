import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

const _recentNowPlayingType = 6;
const _favoritePlaylistType = 1;
const _nowPlayingPlaylistType = 2;
const _historyPlaylistType = 3;
const _recentNowPlayingLimit = 10;

void migratePlaylistType(Database db) {
  final columns =
      db
          .select("PRAGMA table_info('Playlist')")
          .map((row) => row['name'] as String)
          .toSet();
  if (columns.contains('IsHistory')) {
    db.execute('UPDATE Playlist SET Type = 3 WHERE IsHistory = 1');
  }
  db.execute('''
    UPDATE Playlist
    SET Type = $_historyPlaylistType
    WHERE Type = 1
      AND SnapshotKey <> ''
  ''');
  db.execute('''
    UPDATE Playlist
    SET Type = $_favoritePlaylistType
    WHERE Id = (SELECT MyFavorites FROM Settings ORDER BY Id LIMIT 1)
  ''');
  db.execute('''
    UPDATE Playlist
    SET Type = $_nowPlayingPlaylistType
    WHERE Id = (SELECT NowPlaying FROM Settings ORDER BY Id LIMIT 1)
  ''');
}

void migrateRecentNowPlayingSnapshots(Database db) {
  final hasActiveHistory =
      db
          .select(
            '''
      SELECT 1
      FROM RecentRecord
      WHERE Type = ?
        AND State = 1
      LIMIT 1
    ''',
            [_recentNowPlayingType],
          )
          .isNotEmpty;
  if (!hasActiveHistory) {
    return;
  }
  final recentRows = db.select(
    '''
      SELECT Id AS id, ItemId AS itemId
      FROM RecentRecord
      WHERE Type = ?
        AND ItemId LIKE '[%'
        AND Id IN (
          SELECT MAX(Id)
          FROM RecentRecord
          WHERE Type = ?
            AND ItemId LIKE '[%'
          GROUP BY ItemId
          ORDER BY MAX(Id) DESC
          LIMIT $_recentNowPlayingLimit
        )
      ORDER BY Id DESC
    ''',
    [_recentNowPlayingType, _recentNowPlayingType],
  );
  if (recentRows.isEmpty) {
    return;
  }

  final songIdsByPath = {
    for (final row in db.select(
      'SELECT Id AS id, Path AS path FROM Music WHERE State = 1',
    ))
      row['path'] as String: row['id'] as int,
  };
  final playlistIdsBySnapshotKey = {
    for (final row in db.select(
      '''
        SELECT Id AS id, SnapshotKey AS snapshotKey
        FROM Playlist
        WHERE Type = ?
        ORDER BY Id
      ''',
      [_historyPlaylistType],
    ))
      row['snapshotKey'] as String: row['id'] as int,
  };
  final insertPlaylistItem = db.prepare('''
      INSERT INTO PlaylistItem (PlaylistId, ItemId, State)
      VALUES (?, ?, 1)
    ''');
  try {
    for (final row in recentRows) {
      final snapshotKey = row['itemId'] as String;
      final paths = (jsonDecode(snapshotKey) as List).cast<String>();
      final songIds =
          paths.map((path) => songIdsByPath[path]).whereType<int>().toList();
      if (songIds.isEmpty) {
        db.execute('UPDATE RecentRecord SET State = 0 WHERE Id = ?', [
          row['id'] as int,
        ]);
        continue;
      }
      var playlistId = playlistIdsBySnapshotKey[snapshotKey];
      if (playlistId == null) {
        db.execute(
          '''
            INSERT INTO Playlist (
              Name,
              Criterion,
              Priority,
              Type,
              SnapshotKey,
              State
            )
            VALUES ('', -1, -1, ?, ?, 1)
          ''',
          [_historyPlaylistType, snapshotKey],
        );
        playlistId = db.lastInsertRowId;
        playlistIdsBySnapshotKey[snapshotKey] = playlistId;
        for (final songId in songIds) {
          insertPlaylistItem.execute([playlistId, songId]);
        }
      }
      db.execute('UPDATE Playlist SET State = 1 WHERE Id = ?', [playlistId]);
      db.execute('UPDATE PlaylistItem SET State = 1 WHERE PlaylistId = ?', [
        playlistId,
      ]);
      db.execute(
        '''
          UPDATE RecentRecord
          SET ItemId = ?, State = 1
          WHERE Id = ?
        ''',
        [playlistId.toString(), row['id'] as int],
      );
    }
  } finally {
    insertPlaylistItem.dispose();
  }
  db.execute('''
    UPDATE RecentRecord
    SET State = 0
    WHERE Type = $_recentNowPlayingType
      AND ItemId LIKE '[%'
  ''');
  _pruneRecentNowPlayingSnapshots(db);
}

void _pruneRecentNowPlayingSnapshots(Database db) {
  db.execute('''
      UPDATE RecentRecord
      SET State = 0
      WHERE Type = $_recentNowPlayingType
        AND State = 1
        AND Id NOT IN (
          SELECT MAX(Id)
          FROM RecentRecord
          WHERE Type = $_recentNowPlayingType
            AND State = 1
          GROUP BY ItemId
          ORDER BY MAX(Id) DESC
          LIMIT $_recentNowPlayingLimit
        )
    ''');
  db.execute('''
      UPDATE Playlist
      SET State = 0
      WHERE Type = $_historyPlaylistType
        AND NOT EXISTS (
          SELECT 1
          FROM RecentRecord
          WHERE RecentRecord.Type = $_recentNowPlayingType
            AND RecentRecord.State = 1
            AND CAST(RecentRecord.ItemId AS INTEGER) = Playlist.Id
        )
    ''');
  db.execute('''
      UPDATE PlaylistItem
      SET State = 0
      WHERE PlaylistId IN (
        SELECT Id
        FROM Playlist
        WHERE Type = $_historyPlaylistType
          AND State = 0
      )
    ''');
}
