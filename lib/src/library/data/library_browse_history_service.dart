import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'library_models.dart';
import 'library_time_codec.dart';

const _activeState = 1;
const _inactiveState = 0;
const _recentBrowseTypeSong = 10;
const _recentBrowseTypeArtist = 11;
const _recentBrowseTypeAlbum = 12;
const _recentBrowseTypePlaylist = 13;
const _recentBrowseLimit = 500;

class LibraryBrowseHistoryService {
  const LibraryBrowseHistoryService();

  Future<RecentBrowseEntry> record(
    File databaseFile,
    RecentBrowseType type,
    String itemId,
  ) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        final storedType = _storedType(type);
        final browsedAt = LibraryTimeCodec.nowUnixMillisecondsString();
        db.execute(
          '''
          UPDATE RecentRecord
          SET State = ?
          WHERE Type = ?
            AND ItemId = ?
        ''',
          [_inactiveState, storedType, itemId],
        );
        db.execute(
          '''
          INSERT INTO RecentRecord (Type, ItemId, Time, State)
          VALUES (?, ?, ?, ?)
        ''',
          [storedType, itemId, browsedAt, _activeState],
        );
        final id =
            db.select('SELECT last_insert_rowid() AS id').single['id'] as int;
        _trimActiveBrowseRecords(db);
        db.execute('COMMIT');
        return RecentBrowseEntry(
          id: id,
          type: type,
          itemId: itemId,
          browsedAt: browsedAt,
        );
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  List<RecentBrowseEntry> read(Database db) {
    final rows = db.select(
      '''
      SELECT Id AS id, Type AS type, ItemId AS itemId, CAST(Time AS TEXT) AS browsedAt
      FROM RecentRecord
      WHERE Type IN (
        $_recentBrowseTypeSong,
        $_recentBrowseTypeArtist,
        $_recentBrowseTypeAlbum,
        $_recentBrowseTypePlaylist
      )
        AND State = ?
      ORDER BY Id DESC
      LIMIT ?
    ''',
      [_activeState, _recentBrowseLimit],
    );
    return rows.map((row) {
      return RecentBrowseEntry(
        id: row['id'] as int,
        type: _browseType(row['type'] as int),
        itemId: row['itemId'] as String,
        browsedAt: row['browsedAt'] as String,
      );
    }).toList();
  }

  Future<void> remove(File databaseFile, List<int> entryIds) async {
    final placeholders = List.filled(entryIds.length, '?').join(', ');
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE RecentRecord
        SET State = ?
        WHERE Id IN ($placeholders)
      ''',
        [_inactiveState, ...entryIds],
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> restore(File databaseFile, List<int> entryIds) async {
    final placeholders = List.filled(entryIds.length, '?').join(', ');
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        db.execute(
          '''
          UPDATE RecentRecord AS current
          SET State = ?
          WHERE current.State = ?
            AND EXISTS (
              SELECT 1
              FROM RecentRecord AS restoring
              WHERE restoring.Id IN ($placeholders)
                AND restoring.Type = current.Type
                AND restoring.ItemId = current.ItemId
            )
        ''',
          [_inactiveState, _activeState, ...entryIds],
        );
        db.execute(
          '''
          UPDATE RecentRecord
          SET State = ?
          WHERE Id IN (
            SELECT MAX(Id)
            FROM RecentRecord
            WHERE Id IN ($placeholders)
            GROUP BY Type, ItemId
          )
        ''',
          [_activeState, ...entryIds],
        );
        _trimActiveBrowseRecords(db);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> clear(File databaseFile) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        '''
        UPDATE RecentRecord
        SET State = ?
        WHERE Type IN (
          $_recentBrowseTypeSong,
          $_recentBrowseTypeArtist,
          $_recentBrowseTypeAlbum,
          $_recentBrowseTypePlaylist
        )
      ''',
        [_inactiveState],
      );
    } finally {
      db.dispose();
    }
  }
}

void _trimActiveBrowseRecords(Database db) {
  db.execute(
    '''
    UPDATE RecentRecord
    SET State = ?
    WHERE Id IN (
      SELECT Id
      FROM RecentRecord
      WHERE Type IN (
        $_recentBrowseTypeSong,
        $_recentBrowseTypeArtist,
        $_recentBrowseTypeAlbum,
        $_recentBrowseTypePlaylist
      )
        AND State = ?
      ORDER BY Id DESC
      LIMIT -1 OFFSET $_recentBrowseLimit
    )
  ''',
    [_inactiveState, _activeState],
  );
}

int _storedType(RecentBrowseType type) {
  return switch (type) {
    RecentBrowseType.song => _recentBrowseTypeSong,
    RecentBrowseType.artist => _recentBrowseTypeArtist,
    RecentBrowseType.album => _recentBrowseTypeAlbum,
    RecentBrowseType.playlist => _recentBrowseTypePlaylist,
  };
}

RecentBrowseType _browseType(int type) {
  return switch (type) {
    _recentBrowseTypeSong => RecentBrowseType.song,
    _recentBrowseTypeArtist => RecentBrowseType.artist,
    _recentBrowseTypeAlbum => RecentBrowseType.album,
    _recentBrowseTypePlaylist => RecentBrowseType.playlist,
    _ => throw StateError('Unexpected recent browse type: $type'),
  };
}
