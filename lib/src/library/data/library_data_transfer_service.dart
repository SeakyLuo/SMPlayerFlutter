import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'library_repository_paths.dart';
import 'library_database_service.dart';

const _activeState = 1;
const _legacyUwpPackageIdentityName = '23778SeakyTheLoner.SMPlayer';

Future<void> _copyDatabase(String sourcePath, String targetPath) {
  return Isolate.run(() async {
    final source = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
    try {
      final target = sqlite3.open(targetPath);
      try {
        // SQLite backup includes committed WAL pages and preserves a consistent
        // snapshot while the player continues reading the library.
        await source.backup(target, nPage: -1).drain<void>();
      } finally {
        target.dispose();
      }
    } finally {
      source.dispose();
    }
  });
}

class LibraryDataTransferService {
  const LibraryDataTransferService();

  Future<bool> exportDataTo(File databaseFile, String targetPath) async {
    if (!databaseFile.existsSync()) {
      return false;
    }

    final target = File(targetPath);
    await target.parent.create(recursive: true);
    await _copyDatabase(databaseFile.path, target.path);
    return true;
  }

  Future<bool> importDataFrom(
    File databaseFile,
    String sourcePath, {
    required Future<void> Function(String rootPath) rescanLibrary,
  }) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      return false;
    }

    await databaseFile.parent.create(recursive: true);
    final backupFile = File('${databaseFile.path}.import-backup');
    final hadExistingDatabase = databaseFile.existsSync();
    final currentRootPath =
        hadExistingDatabase ? _readDatabaseRootPath(databaseFile) : '';
    if (hadExistingDatabase) {
      await _copyDatabase(databaseFile.path, backupFile.path);
    }

    try {
      await _copyDatabase(source.path, databaseFile.path);
      await Isolate.run(() {
        final imported = const LibraryDatabaseService()
            .openInitializedLibraryDatabase(databaseFile);
        imported.dispose();
      });
      final importedRootPath = _readDatabaseRootPath(databaseFile);
      if (currentRootPath.isNotEmpty &&
          importedRootPath.isNotEmpty &&
          currentRootPath != importedRootPath) {
        _replaceRootPathReferences(
          databaseFile,
          originalPath: importedRootPath,
          nextPath: currentRootPath,
        );
      } else if (importedRootPath.isNotEmpty) {
        await rescanLibrary(importedRootPath);
      }
      return true;
    } catch (_) {
      if (hadExistingDatabase) {
        await _copyDatabase(backupFile.path, databaseFile.path);
      } else if (databaseFile.existsSync()) {
        await databaseFile.delete();
      }
      rethrow;
    } finally {
      if (backupFile.existsSync()) {
        await backupFile.delete();
      }
    }
  }

  File? resolveWindowsUwpDatabaseFile() {
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
                  File(p.join(entry.path, 'LocalState', smPlayerDatabaseName)),
            )
            .where((file) => file.existsSync())
            .toList();

    return selectWindowsUwpDatabaseCandidate(candidates);
  }

  String _readDatabaseRootPath(File databaseFile) {
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select(
        'SELECT RootPath AS rootPath FROM Settings ORDER BY Id LIMIT 1',
      );
      return rows.isEmpty ? '' : rows.first['rootPath'] as String;
    } finally {
      db.dispose();
    }
  }

  void _replaceRootPathReferences(
    File databaseFile, {
    required String originalPath,
    required String nextPath,
  }) {
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        db.execute('UPDATE Settings SET RootPath = replace(RootPath, ?, ?)', [
          originalPath,
          nextPath,
        ]);
        db.execute('UPDATE OR REPLACE Music SET Path = replace(Path, ?, ?)', [
          originalPath,
          nextPath,
        ]);
        db.execute('UPDATE OR REPLACE Folder SET Path = replace(Path, ?, ?)', [
          originalPath,
          nextPath,
        ]);
        db.execute('UPDATE OR REPLACE File SET Path = replace(Path, ?, ?)', [
          originalPath,
          nextPath,
        ]);
        db.execute(
          'UPDATE OR REPLACE HiddenStorageItem SET Path = replace(Path, ?, ?)',
          [originalPath, nextPath],
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
}

File? selectWindowsUwpDatabaseCandidate(List<File> candidates) {
  if (candidates.isEmpty) {
    return null;
  }

  final scoredCandidates =
      candidates.map(_scoreWindowsUwpDatabaseCandidate).toList();
  scoredCandidates.sort((left, right) {
    final existingSampleComparison = right.existingSampleCount.compareTo(
      left.existingSampleCount,
    );
    if (existingSampleComparison != 0) {
      return existingSampleComparison;
    }

    return right.updatedAt.compareTo(left.updatedAt);
  });
  return scoredCandidates.first.file;
}

_WindowsUwpDatabaseCandidateScore _scoreWindowsUwpDatabaseCandidate(File file) {
  return _WindowsUwpDatabaseCandidateScore(
    file: file,
    updatedAt: file.lastModifiedSync().millisecondsSinceEpoch,
    existingSampleCount: _readWindowsUwpDatabaseExistingSampleCount(file),
  );
}

int _readWindowsUwpDatabaseExistingSampleCount(File file) {
  Database? db;
  try {
    db = sqlite3.open(file.path);
    final hasMusicTable =
        db.select('''
          SELECT 1 AS found
          FROM sqlite_master
          WHERE type = 'table'
            AND name = 'Music'
          LIMIT 1
        ''').isNotEmpty;
    if (!hasMusicTable) {
      return 0;
    }

    final rows = db.select(
      '''
      SELECT Path AS path
      FROM Music
      WHERE State = ?
      ORDER BY Id
      LIMIT 96
    ''',
      [_activeState],
    );
    return rows.where((row) => File(row['path'] as String).existsSync()).length;
  } on Object {
    return 0;
  } finally {
    db?.dispose();
  }
}

class _WindowsUwpDatabaseCandidateScore {
  const _WindowsUwpDatabaseCandidateScore({
    required this.file,
    required this.updatedAt,
    required this.existingSampleCount,
  });

  final File file;
  final int updatedAt;
  final int existingSampleCount;
}
