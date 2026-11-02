import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'library_playback_history_service.dart';

class LibraryQueueBackup {
  const LibraryQueueBackup(this.paths, this.selectedPath, this.progress);

  final List<String> paths;
  final String? selectedPath;
  final double progress;

  static LibraryQueueBackup capture(File database, File queueFile) {
    final db = sqlite3.open(database.path);
    try {
      final settings =
          db.select('SELECT * FROM Settings ORDER BY Id DESC LIMIT 1').single;
      final queue = const LibraryPlaybackHistoryService().readNowPlaying(
        db,
        queueFile,
        settings['NowPlaying'] as int,
      );
      final paths = {
        for (final row in db.select(
          'SELECT Id, Path FROM Music WHERE State = 1',
        ))
          row['Id'] as int: row['Path'] as String,
      };
      return LibraryQueueBackup(
        queue.songIds.map((id) => paths[id]!).toList(),
        paths[settings['LastMusicId']],
        (settings['MusicProgress'] as num).toDouble(),
      );
    } finally {
      db.dispose();
    }
  }

  static LibraryQueueBackup? read(File database) {
    final db = sqlite3.open(database.path, mode: OpenMode.readOnly);
    try {
      if (db
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'BackupPlayback'",
          )
          .isEmpty) {
        return null;
      }
      final row =
          db
              .select(
                'SELECT Paths, SelectedPath, Progress FROM BackupPlayback',
              )
              .single;
      return LibraryQueueBackup(
        (jsonDecode(row['Paths'] as String) as List).cast<String>(),
        row['SelectedPath'] as String?,
        (row['Progress'] as num).toDouble(),
      );
    } finally {
      db.dispose();
    }
  }

  void writeToBackup(File database) {
    final db = sqlite3.open(database.path);
    try {
      db.execute('BEGIN');
      db.execute(
        'CREATE TABLE IF NOT EXISTS BackupPlayback (Paths TEXT NOT NULL, SelectedPath TEXT, Progress REAL NOT NULL)',
      );
      db.execute('DELETE FROM BackupPlayback');
      db.execute('INSERT INTO BackupPlayback VALUES (?, ?, ?)', [
        jsonEncode(paths),
        selectedPath,
        progress,
      ]);
      db.execute('COMMIT');
    } finally {
      db.dispose();
    }
  }

  void restore(
    File database,
    File queueFile, {
    String? oldRoot,
    String? newRoot,
  }) {
    String mapPath(String path) =>
        oldRoot != null && newRoot != null && p.isWithin(oldRoot, path)
            ? p.join(newRoot, p.relative(path, from: oldRoot))
            : path;
    final db = sqlite3.open(database.path);
    try {
      final ids = {
        for (final row in db.select(
          'SELECT Id, Path FROM Music WHERE State = 1',
        ))
          row['Path'] as String: row['Id'] as int,
      };
      final restored = paths.map(mapPath).where(ids.containsKey).toList();
      final selected = selectedPath == null ? null : mapPath(selectedPath!);
      final index = restored.indexOf(selected ?? '');
      final restoredIndex = index >= 0 ? index : (restored.isEmpty ? -1 : 0);
      db.execute(
        'UPDATE Settings SET LastMusicId = ?, LastMusicIndex = ?, MusicProgress = ?',
        [
          restoredIndex < 0 ? 0 : ids[restored[restoredIndex]],
          restoredIndex,
          index < 0 ? 0 : progress,
        ],
      );
      queueFile.parent.createSync(recursive: true);
      queueFile.writeAsStringSync(jsonEncode(restored), flush: true);
    } finally {
      db.dispose();
    }
  }
}
