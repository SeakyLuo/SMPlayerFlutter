import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const _activeState = 1;
const _inactiveState = 0;

class LocalSongMove {
  const LocalSongMove({
    required this.id,
    required this.oldPath,
    required this.newPath,
  });

  final int id;
  final String oldPath;
  final String newPath;
}

class LocalFolderMove {
  const LocalFolderMove({required this.oldPath, required this.newPath});

  final String oldPath;
  final String newPath;
}

enum LocalMoveConflictResolution { replace, keepBoth, skip }

typedef LocalMoveConflictResolver =
    Future<LocalMoveConflictResolution> Function(
      String sourcePath,
      String targetPath,
    );

class LocalItemsMoveResult {
  const LocalItemsMoveResult({
    required this.songs,
    required this.folders,
    this.inactiveFolders = const [],
  });

  final List<LocalSongMove> songs;
  final List<LocalFolderMove> folders;
  final List<String> inactiveFolders;

  int get itemCount => songs.length + folders.length;
}

class LibraryLocalMoveService {
  const LibraryLocalMoveService();

  Future<LocalItemsMoveResult> moveSongToFolder(
    File databaseFile,
    int songId,
    String folderPath, {
    LocalMoveConflictResolver? resolveConflict,
  }) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      final songPath = _readActiveSongPath(db, songId);
      if (_getFileParentPath(songPath) == folderPath) {
        return const LocalItemsMoveResult(songs: [], folders: []);
      }

      final targetDirectory = Directory(folderPath);
      if (targetDirectory.statSync().type != FileSystemEntityType.directory) {
        throw StateError('Target path is not a folder.');
      }

      final target = await _resolveLocalFileMoveTarget(
        sourcePath: songPath,
        targetFolderPath: folderPath,
        resolveConflict: resolveConflict,
      );
      if (target == null) {
        return const LocalItemsMoveResult(songs: [], folders: []);
      }

      await File(songPath).rename(target.path);
      db.execute('BEGIN');
      try {
        final folderId = _readActiveFolderId(db, folderPath) ?? 0;
        if (target.replacedPath != null) {
          _markLocalFilePathInactiveInsideTransaction(
            db,
            target.replacedPath!,
            exceptSongId: songId,
          );
        }
        db.execute(
          '''
          UPDATE Music
          SET Path = ?
          WHERE Id = ?
            AND State = ?
        ''',
          [target.path, songId, _activeState],
        );
        db.execute(
          '''
          UPDATE File
          SET Path = ?, ParentId = ?
          WHERE Path = ?
        ''',
          [target.path, folderId, songPath],
        );
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
      return LocalItemsMoveResult(
        songs: [
          LocalSongMove(id: songId, oldPath: songPath, newPath: target.path),
        ],
        folders: const [],
      );
    } finally {
      db.dispose();
    }
  }

  Future<LocalItemsMoveResult> moveLocalItemsToFolder(
    File databaseFile,
    List<int> songIds,
    List<String> folderPaths,
    String targetFolderPath, {
    LocalMoveConflictResolver? resolveConflict,
  }) async {
    if (songIds.isEmpty && folderPaths.isEmpty) {
      return const LocalItemsMoveResult(songs: [], folders: []);
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final targetDirectory = Directory(targetFolderPath);
      if (targetDirectory.statSync().type != FileSystemEntityType.directory) {
        throw StateError('Target path is not a folder.');
      }

      final movedSongs = <LocalSongMove>[];
      final movedFiles = <_LocalFileMove>[];
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
          final target = await _resolveLocalFileMoveTarget(
            sourcePath: songPath,
            targetFolderPath: targetFolderPath,
            resolveConflict: resolveConflict,
          );
          if (target == null) {
            continue;
          }
          await File(songPath).rename(target.path);
          movedFiles.add(
            _LocalFileMove(
              oldPath: songPath,
              newPath: target.path,
              replacedPath: target.replacedPath,
            ),
          );
          movedSongs.add(
            LocalSongMove(
              id: row['id'] as int,
              oldPath: songPath,
              newPath: target.path,
            ),
          );
        }
      }

      final movedFolders = <LocalFolderMove>[];
      final inactiveFolders = <String>[];
      for (final folderPath in folderPaths) {
        if (folderPath == targetFolderPath ||
            targetFolderPath.startsWith('$folderPath/') ||
            targetFolderPath.startsWith('$folderPath\\')) {
          continue;
        }
        final targetPath = p.join(targetFolderPath, p.basename(folderPath));
        if (folderPath == targetPath) {
          continue;
        }
        final targetType = FileSystemEntity.typeSync(targetPath);
        if (targetType == FileSystemEntityType.notFound) {
          await Directory(folderPath).rename(targetPath);
          movedFolders.add(
            LocalFolderMove(oldPath: folderPath, newPath: targetPath),
          );
          continue;
        }

        if (targetType != FileSystemEntityType.directory) {
          throw StateError('Target path already exists and is not a folder.');
        }
        await _mergeLocalFolderIntoExistingTarget(
          sourceFolderPath: folderPath,
          targetFolderPath: targetPath,
          movedFiles: movedFiles,
          movedFolders: movedFolders,
          inactiveFolders: inactiveFolders,
          resolveConflict: resolveConflict,
        );
      }

      db.execute('BEGIN');
      try {
        for (final movedFile in movedFiles) {
          final targetFolderId =
              _readActiveFolderId(db, p.dirname(movedFile.newPath)) ?? 0;
          final sourceSongRows = db.select(
            '''
            SELECT Id AS id
            FROM Music
            WHERE Path = ?
              AND State = ?
            LIMIT 1
          ''',
            [movedFile.oldPath, _activeState],
          );
          final sourceSongId =
              sourceSongRows.isEmpty ? null : sourceSongRows.first['id'] as int;
          if (movedFile.replacedPath != null) {
            _markLocalFilePathInactiveInsideTransaction(
              db,
              movedFile.replacedPath!,
              exceptSongId: sourceSongId,
            );
          }
          if (sourceSongId != null) {
            if (!movedSongs.any((move) => move.id == sourceSongId)) {
              movedSongs.add(
                LocalSongMove(
                  id: sourceSongId,
                  oldPath: movedFile.oldPath,
                  newPath: movedFile.newPath,
                ),
              );
            }
            db.execute(
              '''
              UPDATE Music
              SET Path = ?
              WHERE Id = ?
                AND State = ?
            ''',
              [movedFile.newPath, sourceSongId, _activeState],
            );
          }
          db.execute(
            '''
            UPDATE File
            SET Path = ?, ParentId = ?
            WHERE Path = ?
          ''',
            [movedFile.newPath, targetFolderId, movedFile.oldPath],
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
          final parentFolderId =
              _readActiveFolderId(db, p.dirname(movedFolder.newPath)) ?? 0;
          db.execute(
            '''
            UPDATE Folder
            SET ParentId = ?
            WHERE Path = ?
              AND State = ?
          ''',
            [parentFolderId, movedFolder.newPath, _activeState],
          );
        }
        for (final inactiveFolder in inactiveFolders) {
          _markLocalFolderInactiveInsideTransaction(db, inactiveFolder);
        }
        db.execute('COMMIT');
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
      return LocalItemsMoveResult(
        songs: movedSongs,
        folders: movedFolders,
        inactiveFolders: inactiveFolders,
      );
    } finally {
      db.dispose();
    }
  }

  Future<void> undoMoveLocalItems(
    File databaseFile,
    LocalItemsMoveResult result,
  ) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      for (final movedFolder in result.folders.reversed) {
        Directory(p.dirname(movedFolder.oldPath)).createSync(recursive: true);
        await Directory(movedFolder.newPath).rename(movedFolder.oldPath);
      }
      for (final movedSong in result.songs) {
        Directory(p.dirname(movedSong.oldPath)).createSync(recursive: true);
        await File(movedSong.newPath).rename(movedSong.oldPath);
      }

      db.execute('BEGIN');
      try {
        for (final inactiveFolder in result.inactiveFolders) {
          db.execute(
            '''
            UPDATE Folder
            SET State = ?
            WHERE Path = ?
          ''',
            [_activeState, inactiveFolder],
          );
          db.execute(
            '''
            UPDATE HiddenStorageItem
            SET State = ?
            WHERE Type = 'folder'
              AND Path = ?
          ''',
            [_inactiveState, inactiveFolder],
          );
        }
        for (final movedSong in result.songs) {
          final parentFolderId =
              _readActiveFolderId(db, _getFileParentPath(movedSong.oldPath)) ??
              0;
          db.execute(
            '''
            UPDATE Music
            SET Path = ?
            WHERE Id = ?
          ''',
            [movedSong.oldPath, movedSong.id],
          );
          db.execute(
            '''
            UPDATE File
            SET Path = ?, ParentId = ?
            WHERE Path = ?
          ''',
            [movedSong.oldPath, parentFolderId, movedSong.newPath],
          );
        }

        for (final movedFolder in result.folders.reversed) {
          _updatePathPrefixInsideTransaction(
            db,
            table: 'Music',
            oldPath: movedFolder.newPath,
            newPath: movedFolder.oldPath,
          );
          _updatePathPrefixInsideTransaction(
            db,
            table: 'File',
            oldPath: movedFolder.newPath,
            newPath: movedFolder.oldPath,
          );
          _updatePathPrefixInsideTransaction(
            db,
            table: 'Folder',
            oldPath: movedFolder.newPath,
            newPath: movedFolder.oldPath,
          );
          final parentFolderId =
              _readActiveFolderId(
                db,
                _getFileParentPath(movedFolder.oldPath),
              ) ??
              0;
          db.execute(
            '''
            UPDATE Folder
            SET ParentId = ?
            WHERE Path = ?
          ''',
            [parentFolderId, movedFolder.oldPath],
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

  Future<bool> _mergeLocalFolderIntoExistingTarget({
    required String sourceFolderPath,
    required String targetFolderPath,
    required List<_LocalFileMove> movedFiles,
    required List<LocalFolderMove> movedFolders,
    required List<String> inactiveFolders,
    LocalMoveConflictResolver? resolveConflict,
  }) async {
    var movedAll = true;
    final entries = Directory(sourceFolderPath).listSync(followLinks: false);
    for (final entry in entries) {
      final sourcePath = entry.path;
      final targetPath = p.join(targetFolderPath, p.basename(sourcePath));
      final sourceType = FileSystemEntity.typeSync(
        sourcePath,
        followLinks: false,
      );

      if (sourceType == FileSystemEntityType.directory) {
        final targetType = FileSystemEntity.typeSync(targetPath);
        if (targetType == FileSystemEntityType.notFound) {
          await Directory(sourcePath).rename(targetPath);
          movedFolders.add(
            LocalFolderMove(oldPath: sourcePath, newPath: targetPath),
          );
          continue;
        }
        if (targetType != FileSystemEntityType.directory) {
          throw StateError('Target path already exists and is not a folder.');
        }
        final childMovedAll = await _mergeLocalFolderIntoExistingTarget(
          sourceFolderPath: sourcePath,
          targetFolderPath: targetPath,
          movedFiles: movedFiles,
          movedFolders: movedFolders,
          inactiveFolders: inactiveFolders,
          resolveConflict: resolveConflict,
        );
        movedAll = childMovedAll && movedAll;
        continue;
      }

      if (sourceType == FileSystemEntityType.file) {
        final target = await _resolveLocalFileMoveTarget(
          sourcePath: sourcePath,
          targetFolderPath: targetFolderPath,
          resolveConflict: resolveConflict,
        );
        if (target == null) {
          movedAll = false;
          continue;
        }
        await File(sourcePath).rename(target.path);
        movedFiles.add(
          _LocalFileMove(
            oldPath: sourcePath,
            newPath: target.path,
            replacedPath: target.replacedPath,
          ),
        );
        continue;
      }

      movedAll = false;
    }

    if (Directory(sourceFolderPath).listSync(followLinks: false).isEmpty) {
      await Directory(sourceFolderPath).delete();
      inactiveFolders.add(sourceFolderPath);
      return movedAll;
    }
    return false;
  }

  void _markLocalFilePathInactiveInsideTransaction(
    Database db,
    String filePath, {
    int? exceptSongId,
  }) {
    if (exceptSongId == null) {
      db.execute(
        '''
        UPDATE Music
        SET State = ?
        WHERE Path = ?
          AND State = ?
      ''',
        [_inactiveState, filePath, _activeState],
      );
    } else {
      db.execute(
        '''
        UPDATE Music
        SET State = ?
        WHERE Path = ?
          AND Id <> ?
          AND State = ?
      ''',
        [_inactiveState, filePath, exceptSongId, _activeState],
      );
    }
    db.execute(
      '''
      UPDATE File
      SET State = ?
      WHERE Path = ?
    ''',
      [_inactiveState, filePath],
    );
    db.execute(
      '''
      UPDATE HiddenStorageItem
      SET State = ?
      WHERE Type = 'file'
        AND Path = ?
    ''',
      [_inactiveState, filePath],
    );
  }

  void _markLocalFolderInactiveInsideTransaction(
    Database db,
    String folderPath,
  ) {
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE Path = ?
    ''',
      [_inactiveState, folderPath],
    );
    db.execute(
      '''
      UPDATE HiddenStorageItem
      SET State = ?
      WHERE Type = 'folder'
        AND Path = ?
    ''',
      [_inactiveState, folderPath],
    );
  }

  Future<_LocalResolvedFileMoveTarget?> _resolveLocalFileMoveTarget({
    required String sourcePath,
    required String targetFolderPath,
    LocalMoveConflictResolver? resolveConflict,
  }) async {
    final targetPath = p.join(targetFolderPath, p.basename(sourcePath));
    if (FileSystemEntity.typeSync(targetPath) ==
        FileSystemEntityType.notFound) {
      return _LocalResolvedFileMoveTarget(path: targetPath);
    }

    final resolution =
        resolveConflict == null
            ? LocalMoveConflictResolution.keepBoth
            : await resolveConflict(sourcePath, targetPath);
    return switch (resolution) {
      LocalMoveConflictResolution.skip => null,
      LocalMoveConflictResolution.keepBoth => _LocalResolvedFileMoveTarget(
        path: _getAvailableSiblingPath(targetPath),
      ),
      LocalMoveConflictResolution.replace => _LocalResolvedFileMoveTarget(
        path: await _replaceLocalMoveTarget(targetPath),
        replacedPath: targetPath,
      ),
    };
  }

  Future<String> _replaceLocalMoveTarget(String targetPath) async {
    await File(targetPath).delete();
    return targetPath;
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
}

class _LocalFileMove {
  const _LocalFileMove({
    required this.oldPath,
    required this.newPath,
    this.replacedPath,
  });

  final String oldPath;
  final String newPath;
  final String? replacedPath;
}

class _LocalResolvedFileMoveTarget {
  const _LocalResolvedFileMoveTarget({required this.path, this.replacedPath});

  final String path;
  final String? replacedPath;
}

String _getFileParentPath(String filePath) {
  final separatorIndex = filePath.lastIndexOf(RegExp(r'[\\/]'));
  return separatorIndex > -1 ? filePath.substring(0, separatorIndex) : '';
}
