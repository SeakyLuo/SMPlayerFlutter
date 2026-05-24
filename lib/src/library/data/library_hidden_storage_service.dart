import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'library_models.dart';

const _activeState = 1;
const _inactiveState = 0;
const _hiddenState = -1;
const _parentHiddenState = -2;

class LibraryHiddenStorageService {
  const LibraryHiddenStorageService();

  Future<void> hideSong(File databaseFile, int songId) async {
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

  Future<void> hideFolder(File databaseFile, String folderPath) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _hideFolderPathStateInsideTransaction(db, folderPath);
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

  Future<void> unhideSong(File databaseFile, int songId) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      final songPath = _readSongPath(db, songId);
      db.execute('BEGIN');
      try {
        db.execute('UPDATE Music SET State = ? WHERE Id = ?', [
          _activeState,
          songId,
        ]);
        db.execute('UPDATE File SET State = ? WHERE Path = ?', [
          _activeState,
          songPath,
        ]);
        db.execute(
          '''
          UPDATE HiddenStorageItem
          SET State = ?
          WHERE Type = ?
            AND Path = ?
        ''',
          [_inactiveState, 'file', songPath],
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

  Future<void> unhideFolder(File databaseFile, String folderPath) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        updateFolderPathStateInsideTransaction(db, [folderPath], _activeState);
        db.execute(
          '''
          UPDATE HiddenStorageItem
          SET State = ?
          WHERE Type = ?
            AND Path = ?
        ''',
          [_inactiveState, 'folder', folderPath],
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

  Future<List<HiddenStorageItem>> getHiddenStorageItems(
    File databaseFile,
  ) async {
    if (!databaseFile.existsSync()) {
      return const [];
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        _syncStorageStateFromHiddenItems(db);
        _syncHiddenItemsFromStorageState(db);
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
      final rows = db.select(
        '''
        SELECT Id AS id, Type AS type, Path AS path
        FROM HiddenStorageItem
        WHERE State = ?
        ORDER BY Type, Path
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

  Future<void> resumeHiddenStorageItem(
    File databaseFile,
    HiddenStorageItem item,
  ) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        if (item.type == 'folder') {
          _resumeHiddenFolderInsideTransaction(db, item.path);
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
          WHERE Type = ?
            AND Path = ?
        ''',
          [_inactiveState, item.type, item.path],
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

  void updateFolderPathStateInsideTransaction(
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

  ({List<String> folderPaths, List<String> filePaths})
  readActiveHiddenStoragePaths(Database db) {
    final rows = db.select(
      '''
      SELECT Type AS type, Path AS path
      FROM HiddenStorageItem
      WHERE State = ?
    ''',
      [_activeState],
    );
    return (
      folderPaths: [
        for (final row in rows)
          if (row['type'] == 'folder') row['path'] as String,
      ],
      filePaths: [
        for (final row in rows)
          if (row['type'] == 'file') row['path'] as String,
      ],
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

  String _readSongPath(Database db, int songId) {
    final rows = db.select(
      '''
      SELECT Path AS path
      FROM Music
      WHERE Id = ?
      LIMIT 1
    ''',
      [songId],
    );
    return rows.first['path'] as String;
  }

  void _hideFolderPathStateInsideTransaction(Database db, String folderPath) {
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE Path = ?
    ''',
      [_hiddenState, folderPath],
    );
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE Path LIKE ?
         OR Path LIKE ?
    ''',
      [_parentHiddenState, '$folderPath/%', '$folderPath\\%'],
    );
    db.execute(
      '''
      UPDATE Music
      SET State = ?
      WHERE Path LIKE ?
         OR Path LIKE ?
    ''',
      [_parentHiddenState, '$folderPath/%', '$folderPath\\%'],
    );
    db.execute(
      '''
      UPDATE File
      SET State = ?
      WHERE Path LIKE ?
         OR Path LIKE ?
    ''',
      [_parentHiddenState, '$folderPath/%', '$folderPath\\%'],
    );
  }

  void _resumeHiddenFolderInsideTransaction(Database db, String folderPath) {
    db.execute(
      '''
      UPDATE HiddenStorageItem
      SET State = ?
      WHERE Path = ?
         OR Path LIKE ?
         OR Path LIKE ?
    ''',
      [_inactiveState, folderPath, '$folderPath/%', '$folderPath\\%'],
    );
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE Path = ?
         OR Path LIKE ?
         OR Path LIKE ?
    ''',
      [_activeState, folderPath, '$folderPath/%', '$folderPath\\%'],
    );
    db.execute(
      '''
      UPDATE Music
      SET State = ?
      WHERE Path LIKE ?
         OR Path LIKE ?
    ''',
      [_activeState, '$folderPath/%', '$folderPath\\%'],
    );
    db.execute(
      '''
      UPDATE File
      SET State = ?
      WHERE Path LIKE ?
         OR Path LIKE ?
    ''',
      [_activeState, '$folderPath/%', '$folderPath\\%'],
    );
  }

  void _syncHiddenItemsFromStorageState(Database db) {
    db.execute(
      '''
      UPDATE HiddenStorageItem
      SET State = ?
      WHERE Type = 'folder'
        AND Path IN (SELECT Path FROM Folder WHERE State = ?)
    ''',
      [_activeState, _hiddenState],
    );
    db.execute(
      '''
      INSERT INTO HiddenStorageItem (Type, Path, State)
      SELECT 'folder', Folder.Path, ?
      FROM Folder
      WHERE State = ?
        AND NOT EXISTS (
          SELECT 1
          FROM HiddenStorageItem
          WHERE HiddenStorageItem.Type = 'folder'
            AND HiddenStorageItem.Path = Folder.Path
        )
    ''',
      [_activeState, _hiddenState],
    );
    db.execute(
      '''
      UPDATE HiddenStorageItem
      SET State = ?
      WHERE Type = 'file'
        AND Path IN (SELECT Path FROM File WHERE State = ?)
    ''',
      [_activeState, _hiddenState],
    );
    db.execute(
      '''
      INSERT INTO HiddenStorageItem (Type, Path, State)
      SELECT 'file', File.Path, ?
      FROM File
      WHERE State = ?
        AND NOT EXISTS (
          SELECT 1
          FROM HiddenStorageItem
          WHERE HiddenStorageItem.Type = 'file'
            AND HiddenStorageItem.Path = File.Path
        )
    ''',
      [_activeState, _hiddenState],
    );
  }

  void _syncStorageStateFromHiddenItems(Database db) {
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE EXISTS (
        SELECT 1
        FROM HiddenStorageItem
        WHERE HiddenStorageItem.Type = 'folder'
          AND HiddenStorageItem.Path = Folder.Path
          AND HiddenStorageItem.State = ?
      )
    ''',
      [_hiddenState, _activeState],
    );
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE State != ?
        AND EXISTS (
          SELECT 1
          FROM HiddenStorageItem
          WHERE HiddenStorageItem.Type = 'folder'
            AND HiddenStorageItem.State = ?
            AND (
              Folder.Path LIKE HiddenStorageItem.Path || '/%'
              OR Folder.Path LIKE HiddenStorageItem.Path || '\\%'
            )
        )
    ''',
      [_parentHiddenState, _hiddenState, _activeState],
    );
    db.execute(
      '''
      UPDATE Music
      SET State = ?
      WHERE EXISTS (
        SELECT 1
        FROM HiddenStorageItem
        WHERE HiddenStorageItem.Type = 'file'
          AND HiddenStorageItem.Path = Music.Path
          AND HiddenStorageItem.State = ?
      )
    ''',
      [_hiddenState, _activeState],
    );
    db.execute(
      '''
      UPDATE File
      SET State = ?
      WHERE EXISTS (
        SELECT 1
        FROM HiddenStorageItem
        WHERE HiddenStorageItem.Type = 'file'
          AND HiddenStorageItem.Path = File.Path
          AND HiddenStorageItem.State = ?
      )
    ''',
      [_hiddenState, _activeState],
    );
    db.execute(
      '''
      UPDATE Music
      SET State = ?
      WHERE State != ?
        AND EXISTS (
          SELECT 1
          FROM HiddenStorageItem
          WHERE HiddenStorageItem.Type = 'folder'
            AND HiddenStorageItem.State = ?
            AND (
              Music.Path LIKE HiddenStorageItem.Path || '/%'
              OR Music.Path LIKE HiddenStorageItem.Path || '\\%'
            )
        )
    ''',
      [_parentHiddenState, _hiddenState, _activeState],
    );
    db.execute(
      '''
      UPDATE File
      SET State = ?
      WHERE State != ?
        AND EXISTS (
          SELECT 1
          FROM HiddenStorageItem
          WHERE HiddenStorageItem.Type = 'folder'
            AND HiddenStorageItem.State = ?
            AND (
              File.Path LIKE HiddenStorageItem.Path || '/%'
              OR File.Path LIKE HiddenStorageItem.Path || '\\%'
            )
        )
    ''',
      [_parentHiddenState, _hiddenState, _activeState],
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
}
