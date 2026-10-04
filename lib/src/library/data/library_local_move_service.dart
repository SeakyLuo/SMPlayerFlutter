import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

part 'library_local_move_task.dart';

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
  }) {
    return moveLocalItemsToFolder(
      databaseFile,
      [songId],
      [],
      folderPath,
      resolveConflict: resolveConflict,
    );
  }

  Future<LocalItemsMoveResult> moveLocalItemsToFolder(
    File databaseFile,
    List<int> songIds,
    List<String> folderPaths,
    String targetFolderPath, {
    LocalMoveConflictResolver? resolveConflict,
  }) {
    return _runLocalMoveTask(
      _LocalMoveTask(databaseFile.path, songIds, folderPaths, targetFolderPath),
      resolveConflict,
    );
  }

  Future<void> undoMoveLocalItems(
    File databaseFile,
    LocalItemsMoveResult result,
  ) {
    return Isolate.run(_UndoLocalMoveTask(databaseFile.path, result).call);
  }

  Future<LocalItemsMoveResult> _moveLocalItemsToFolderInBackground(
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
        final folderIds = _readActiveFolderIds(db);
        final songIdsByPath = {
          for (final row in db.select(
            'SELECT Id, Path FROM Music WHERE State = ?',
            [_activeState],
          ))
            row['Path'] as String: row['Id'] as int,
        };
        final movedSongIds = movedSongs.map((song) => song.id).toSet();
        for (final movedFile in movedFiles) {
          final targetFolderId = folderIds[p.dirname(movedFile.newPath)] ?? 0;
          final sourceSongId = songIdsByPath[movedFile.oldPath];
          if (movedFile.replacedPath != null) {
            _markLocalFilePathInactiveInsideTransaction(
              db,
              movedFile.replacedPath!,
              exceptSongId: sourceSongId,
            );
            if (songIdsByPath[movedFile.replacedPath] != sourceSongId) {
              songIdsByPath.remove(movedFile.replacedPath);
            }
          }
          if (sourceSongId != null) {
            if (movedSongIds.add(sourceSongId)) {
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
            songIdsByPath.remove(movedFile.oldPath);
            songIdsByPath[movedFile.newPath] = sourceSongId;
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
          _updateFolderIdPaths(
            folderIds,
            movedFolder.oldPath,
            movedFolder.newPath,
          );
          final parentFolderId = folderIds[p.dirname(movedFolder.newPath)] ?? 0;
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

  Future<void> _undoMoveLocalItemsInBackground(
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
        final folderIds = _readActiveFolderIds(db);
        for (final movedSong in result.songs) {
          final parentFolderId =
              folderIds[_getFileParentPath(movedSong.oldPath)] ?? 0;
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
          _updateFolderIdPaths(
            folderIds,
            movedFolder.newPath,
            movedFolder.oldPath,
          );
          final parentFolderId =
              folderIds[_getFileParentPath(movedFolder.oldPath)] ?? 0;
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

  Map<String, int> _readActiveFolderIds(Database db) => {
    for (final row in db.select('SELECT Id, Path FROM Folder WHERE State = ?', [
      _activeState,
    ]))
      row['Path'] as String: row['Id'] as int,
  };

  void _updateFolderIdPaths(
    Map<String, int> folderIds,
    String oldPath,
    String newPath,
  ) {
    final moved = {
      for (final entry in folderIds.entries)
        if (entry.key == oldPath ||
            entry.key.startsWith('$oldPath/') ||
            entry.key.startsWith('$oldPath\\'))
          entry.key: entry.value,
    };
    for (final entry in moved.entries) {
      folderIds.remove(entry.key);
      folderIds[newPath + entry.key.substring(oldPath.length)] = entry.value;
    }
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
