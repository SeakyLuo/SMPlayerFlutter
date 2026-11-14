import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import '../../remote/music_share_models.dart';

class SongFileRelocation {
  const SongFileRelocation({
    required this.songId,
    required this.paths,
    required this.oldFolderId,
    required this.newFolderId,
  });
  final int songId;
  final List<(String, String)> paths;
  final int oldFolderId;
  final int newFolderId;
}

class LibraryFileRelocationService {
  const LibraryFileRelocationService();

  Future<SongFileRelocation> relocate(
    File database,
    int songId,
    String source,
    String target,
    int folderId,
    String root,
  ) async {
    final paths = <(String, String)>[(source, target)];
    for (final extension in const ['.lrc', '.txt']) {
      final old = p.withoutExtension(source) + extension;
      if (await File(old).exists()) {
        final resolved = await File(old).resolveSymbolicLinks();
        if (!p.isWithin(root, resolved)) {
          throw const MusicShareException('share.fileOutsideLibrary');
        }
        paths.add((old, p.withoutExtension(target) + extension));
      }
    }
    final db = sqlite3.open(database.path);
    try {
      final folders = db.select('SELECT Id, Path FROM Folder WHERE State = 1');
      final oldFolder =
          folders.where((row) => row['Path'] == p.dirname(source)).firstOrNull;
      final result = SongFileRelocation(
        songId: songId,
        paths: paths,
        oldFolderId: oldFolder == null ? 0 : oldFolder['Id'] as int,
        newFolderId: folderId,
      );
      await _apply(db, result, undo: false);
      return result;
    } finally {
      db.dispose();
    }
  }

  Future<void> undo(File database, SongFileRelocation result) async {
    final db = sqlite3.open(database.path);
    try {
      await _apply(db, result, undo: true);
    } finally {
      db.dispose();
    }
  }

  Future<void> _apply(
    Database db,
    SongFileRelocation result, {
    required bool undo,
  }) async {
    final paths = [
      for (final pair in result.paths) undo ? (pair.$2, pair.$1) : pair,
    ];
    for (final pair in paths) {
      if (await FileSystemEntity.type(pair.$2, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw const MusicShareException('share.fileExists');
      }
    }
    final targets = paths.map((pair) => pair.$2).toList();
    final placeholders = List.filled(targets.length, '?').join(',');
    final occupied = db.select(
      'SELECT Id FROM Music WHERE Path IN ($placeholders)',
      targets,
    );
    final files = db.select(
      'SELECT Id FROM File WHERE Path IN ($placeholders)',
      targets,
    );
    if (occupied.isNotEmpty || files.isNotEmpty) {
      throw const MusicShareException('share.fileTargetUnavailable');
    }
    final moved = <(String, String)>[];
    db.execute('BEGIN IMMEDIATE');
    try {
      for (final pair in paths) {
        await File(pair.$1).rename(pair.$2);
        moved.add(pair);
      }
      db.execute(
        'UPDATE Music SET Path = ? WHERE Id = ? AND Path = ? AND State = 1',
        [paths.first.$2, result.songId, paths.first.$1],
      );
      if (db.updatedRows != 1) {
        throw const MusicShareException('share.fileChanged');
      }
      final update = db.prepare(
        'UPDATE File SET Path = ?, ParentId = ? WHERE Path = ?',
      );
      try {
        for (final pair in paths) {
          update.execute([
            pair.$2,
            undo ? result.oldFolderId : result.newFolderId,
            pair.$1,
          ]);
        }
      } finally {
        update.dispose();
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      for (final pair in moved.reversed) {
        await File(pair.$2).rename(pair.$1);
      }
      rethrow;
    }
  }
}
