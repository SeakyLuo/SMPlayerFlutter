import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'library_hidden_storage_service.dart';
import 'library_models.dart';
import 'library_pending_delete_service.dart';

const _activeState = 1;
const _inactiveState = 0;
const _recentRecordTypeSong = 0;

class LibraryLocalDeleteService {
  const LibraryLocalDeleteService({
    required LibraryHiddenStorageService hiddenStorageService,
    required LibraryPendingDeleteService pendingDeleteService,
  }) : _hiddenStorageService = hiddenStorageService,
       _pendingDeleteService = pendingDeleteService;

  final LibraryHiddenStorageService _hiddenStorageService;
  final LibraryPendingDeleteService _pendingDeleteService;

  Future<PendingSongDelete> beginDeleteSongFromDisk(
    File databaseFile,
    File pendingFile,
    int songId,
  ) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      final songPath = _readActiveSongPath(db, songId);
      final record = PendingSongDeleteRecord(
        id: 'delete-${DateTime.now().microsecondsSinceEpoch}-$songId',
        songId: songId,
        songPath: songPath,
        musicArtistIds: _readActiveRowIds(db, 'MusicArtist', 'MusicId', songId),
        playlistItemIds: _readActiveRowIds(
          db,
          'PlaylistItem',
          'ItemId',
          songId,
        ),
        recentRecordIds: _readActiveRecentSongRowIds(db, songId),
        hiddenStorageItemIds: _readActiveHiddenFileRowIds(db, songPath),
      );
      await _pendingDeleteService.prependRecord(pendingFile, record);

      db.execute('BEGIN');
      try {
        deleteSongsInsideTransaction(db, [songId], [songPath]);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        await _pendingDeleteService.removeRecord(pendingFile, record.id);
        rethrow;
      }
      return PendingSongDelete(id: record.id, songId: songId);
    } finally {
      db.dispose();
    }
  }

  Future<void> undoDeleteSongFromDisk(
    File databaseFile,
    File pendingFile,
    String deleteId,
  ) async {
    final records = await _pendingDeleteService.readRecords(pendingFile);
    final record = _pendingDeleteService.findSongDeleteRecord(
      records,
      deleteId,
    );
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _restoreDeletedSongInsideTransaction(db, record);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
    await _pendingDeleteService.removeRecord(pendingFile, deleteId);
  }

  Future<PendingLocalItemsDelete> beginDeleteLocalItems(
    File databaseFile,
    File pendingFile,
    List<int> songIds,
    List<String> folderPaths,
  ) async {
    if (songIds.isEmpty && folderPaths.isEmpty) {
      return const PendingLocalItemsDelete(
        id: '',
        songIds: [],
        folderPaths: [],
      );
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final songRows = _readActiveSongsForLocalItems(db, songIds, folderPaths);
      final effectiveSongIds = songRows.map((row) => row.id).toList();
      final targetPaths = [
        ...songRows
            .map((row) => row.path)
            .where(
              (songPath) =>
                  !folderPaths.any(
                    (folderPath) => _isPathInsideFolder(songPath, folderPath),
                  ),
            ),
        ...folderPaths,
      ];
      final record = PendingLocalItemsDeleteRecord(
        id: 'delete-local-${DateTime.now().microsecondsSinceEpoch}',
        songIds: effectiveSongIds,
        folderPaths: folderPaths.toList(),
        targetPaths: targetPaths,
        musicIds: effectiveSongIds,
        musicArtistIds: _readActiveRowsForSongIds(
          db,
          'MusicArtist',
          'MusicId',
          effectiveSongIds,
        ),
        playlistItemIds: _readActiveRowsForSongIds(
          db,
          'PlaylistItem',
          'ItemId',
          effectiveSongIds,
        ),
        recentRecordIds: _readActiveRecentSongRowsForSongIds(
          db,
          effectiveSongIds,
        ),
        hiddenStorageItemIds: [
          ..._readActiveHiddenFileRowsForPaths(
            db,
            songRows.map((row) => row.path).toList(),
          ),
          ..._readActiveHiddenFolderRowsForPaths(db, folderPaths),
        ],
        folderIds: _readActiveFolderRowIdsForPaths(db, folderPaths),
        fileIds: _readActiveFileRowIdsForPaths(
          db,
          songRows.map((row) => row.path).toList(),
          folderPaths,
        ),
      );
      await _pendingDeleteService.prependRecord(pendingFile, record);

      db.execute('BEGIN');
      try {
        if (songRows.isNotEmpty) {
          deleteSongsInsideTransaction(
            db,
            effectiveSongIds,
            songRows.map((row) => row.path).toList(),
          );
        }
        _hiddenStorageService.updateFolderPathStateInsideTransaction(
          db,
          folderPaths,
          _inactiveState,
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        await _pendingDeleteService.removeRecord(pendingFile, record.id);
        rethrow;
      }

      return PendingLocalItemsDelete(
        id: record.id,
        songIds: record.songIds,
        folderPaths: record.folderPaths,
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> undoDeleteLocalItems(
    File databaseFile,
    File pendingFile,
    String deleteId,
  ) async {
    final records = await _pendingDeleteService.readRecords(pendingFile);
    final record = _pendingDeleteService.findLocalItemsDeleteRecord(
      records,
      deleteId,
    );
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _restoreDeletedLocalItemsInsideTransaction(db, record);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
    await _pendingDeleteService.removeRecord(pendingFile, deleteId);
  }

  void deleteSongsInsideTransaction(
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

  void _restoreDeletedSongInsideTransaction(
    Database db,
    PendingSongDeleteRecord record,
  ) {
    db.execute('UPDATE Music SET State = ? WHERE Id = ?', [
      _activeState,
      record.songId,
    ]);
    db.execute('UPDATE File SET State = ? WHERE Path = ?', [
      _activeState,
      record.songPath,
    ]);
    _restoreRowsById(db, 'MusicArtist', record.musicArtistIds);
    _restoreRowsById(db, 'PlaylistItem', record.playlistItemIds);
    _restoreRowsById(db, 'RecentRecord', record.recentRecordIds);
    _restoreRowsById(db, 'HiddenStorageItem', record.hiddenStorageItemIds);
  }

  void _restoreDeletedLocalItemsInsideTransaction(
    Database db,
    PendingLocalItemsDeleteRecord record,
  ) {
    _restoreRowsById(db, 'Music', record.musicIds);
    _restoreRowsById(db, 'MusicArtist', record.musicArtistIds);
    _restoreRowsById(db, 'PlaylistItem', record.playlistItemIds);
    _restoreRowsById(db, 'RecentRecord', record.recentRecordIds);
    _restoreRowsById(db, 'HiddenStorageItem', record.hiddenStorageItemIds);
    _restoreRowsById(db, 'Folder', record.folderIds);
    _restoreRowsById(db, 'File', record.fileIds);
  }

  void _restoreRowsById(Database db, String table, List<int> rowIds) {
    if (rowIds.isEmpty) {
      return;
    }

    final placeholders = List.filled(rowIds.length, '?').join(', ');
    db.execute(
      '''
      UPDATE $table
      SET State = ?
      WHERE Id IN ($placeholders)
    ''',
      [_activeState, ...rowIds],
    );
  }

  List<int> _readActiveRowIds(
    Database db,
    String table,
    String column,
    int value,
  ) {
    return db
        .select(
          '''
          SELECT Id AS id
          FROM $table
          WHERE $column = ?
            AND State = ?
        ''',
          [value, _activeState],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  List<int> _readActiveRecentSongRowIds(Database db, int songId) {
    return db
        .select(
          '''
          SELECT Id AS id
          FROM RecentRecord
          WHERE Type = $_recentRecordTypeSong
            AND ItemId = ?
            AND State = ?
        ''',
          [songId.toString(), _activeState],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  List<int> _readActiveHiddenFileRowIds(Database db, String songPath) {
    return db
        .select(
          '''
          SELECT Id AS id
          FROM HiddenStorageItem
          WHERE Type = 'file'
            AND Path = ?
            AND State = ?
        ''',
          [songPath, _activeState],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  List<int> _readActiveRowsForSongIds(
    Database db,
    String table,
    String column,
    List<int> songIds,
  ) {
    if (songIds.isEmpty) {
      return const [];
    }

    final placeholders = List.filled(songIds.length, '?').join(', ');
    return db
        .select(
          '''
          SELECT Id AS id
          FROM $table
          WHERE $column IN ($placeholders)
            AND State = ?
        ''',
          [...songIds, _activeState],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  List<int> _readActiveRecentSongRowsForSongIds(
    Database db,
    List<int> songIds,
  ) {
    if (songIds.isEmpty) {
      return const [];
    }

    final placeholders = List.filled(songIds.length, '?').join(', ');
    return db
        .select(
          '''
          SELECT Id AS id
          FROM RecentRecord
          WHERE Type = $_recentRecordTypeSong
            AND ItemId IN ($placeholders)
            AND State = ?
        ''',
          [...songIds.map((songId) => songId.toString()), _activeState],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  List<int> _readActiveHiddenFileRowsForPaths(
    Database db,
    List<String> songPaths,
  ) {
    if (songPaths.isEmpty) {
      return const [];
    }

    final placeholders = List.filled(songPaths.length, '?').join(', ');
    return db
        .select(
          '''
          SELECT Id AS id
          FROM HiddenStorageItem
          WHERE Type = 'file'
            AND Path IN ($placeholders)
            AND State = ?
        ''',
          [...songPaths, _activeState],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  List<int> _readActiveHiddenFolderRowsForPaths(
    Database db,
    List<String> folderPaths,
  ) {
    if (folderPaths.isEmpty) {
      return const [];
    }

    final placeholders = List.filled(folderPaths.length, '?').join(', ');
    return db
        .select(
          '''
          SELECT Id AS id
          FROM HiddenStorageItem
          WHERE Type = 'folder'
            AND Path IN ($placeholders)
            AND State = ?
        ''',
          [...folderPaths, _activeState],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  List<int> _readActiveFolderRowIdsForPaths(
    Database db,
    List<String> folderPaths,
  ) {
    if (folderPaths.isEmpty) {
      return const [];
    }

    final clauses = folderPaths
        .map((_) => '(Path = ? OR Path LIKE ? OR Path LIKE ?)')
        .join(' OR ');
    return db
        .select(
          '''
          SELECT Id AS id
          FROM Folder
          WHERE State = ?
            AND ($clauses)
        ''',
          [
            _activeState,
            for (final folderPath in folderPaths) ...[
              folderPath,
              '$folderPath/%',
              '$folderPath\\%',
            ],
          ],
        )
        .map((row) => row['id'] as int)
        .toList();
  }

  List<int> _readActiveFileRowIdsForPaths(
    Database db,
    List<String> songPaths,
    List<String> folderPaths,
  ) {
    final clauses = <String>[];
    final args = <Object?>[];
    if (songPaths.isNotEmpty) {
      clauses.add('Path IN (${List.filled(songPaths.length, '?').join(', ')})');
      args.addAll(songPaths);
    }
    for (final folderPath in folderPaths) {
      clauses.add('(Path LIKE ? OR Path LIKE ?)');
      args
        ..add('$folderPath/%')
        ..add('$folderPath\\%');
    }
    if (clauses.isEmpty) {
      return const [];
    }

    return db
        .select(
          '''
          SELECT Id AS id
          FROM File
          WHERE State = ?
            AND (${clauses.join(' OR ')})
        ''',
          [_activeState, ...args],
        )
        .map((row) => row['id'] as int)
        .toList();
  }
}

bool _isPathInsideFolder(String itemPath, String folderPath) {
  return itemPath.startsWith('$folderPath/') ||
      itemPath.startsWith('$folderPath\\');
}
