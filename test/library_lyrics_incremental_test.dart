import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:smplayer_flutter/src/library/data/library_database_service.dart';
import 'package:smplayer_flutter/src/library/data/library_lyrics_search_service.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';

void main() {
  test(
    'scan indexes only changed audio or sidecars across service instances',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lyrics-incremental-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final audio = File(p.join(directory.path, 'song.mp3'))
        ..writeAsBytesSync([1]);
      final sidecar = File(p.setExtension(audio.path, '.lrc'));
      final databaseFile = File(p.join(directory.path, 'library.db'));
      const database = LibraryDatabaseService();
      final db = database.openInitializedLibraryDatabase(databaseFile);
      db.execute('INSERT INTO Music (Path) VALUES (?)', [audio.path]);
      db.dispose();
      var reads = 0;
      Future<LyricsSnapshot> resolve(String path) async {
        reads++;
        final text =
            sidecar.existsSync() ? sidecar.readAsStringSync() : 'embedded';
        return LyricsSnapshot(
          source: LyricsSource.lrcFile,
          isSynced: false,
          rawText: text,
          lines: [LyricsLine(id: 0, timestampMs: null, text: text)],
        );
      }

      LibraryLyricsSearchService service() => LibraryLyricsSearchService(
        database: database,
        localLyricsResolver: resolve,
      );
      Future<void> scan() => service().refreshFolder(
        databaseFile,
        directory.path,
        onlyChanged: true,
      );
      await scan();
      await scan();
      expect(reads, 1);
      sidecar.writeAsStringSync('new lyrics');
      await scan();
      expect(reads, 2);
      expect(
        await service().searchAvailable(databaseFile, 'new lyrics'),
        hasLength(1),
      );
      await scan();
      expect(reads, 2);
      sidecar.deleteSync();
      await scan();
      expect(reads, 3);
      expect(
        await service().searchAvailable(databaseFile, 'new lyrics'),
        isEmpty,
      );
      audio.writeAsBytesSync([1, 2]);
      await scan();
      expect(reads, 4);
      final txt = File(p.setExtension(audio.path, '.txt'))
        ..writeAsStringSync('text');
      await scan();
      expect(reads, 5);
      txt.writeAsStringSync('changed text');
      await scan();
      expect(reads, 6);
      await service().refreshSongIds(databaseFile, [1]);
      expect(reads, 7);
    },
  );

  test(
    'failed lyrics read does not stop other songs or mark failure indexed',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lyrics-failure-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final databaseFile = File(p.join(directory.path, 'library.db'));
      const database = LibraryDatabaseService();
      final db = database.openInitializedLibraryDatabase(databaseFile);
      for (final name in ['bad', 'good']) {
        final audio = File(p.join(directory.path, '$name.mp3'))
          ..writeAsBytesSync([1]);
        db.execute('INSERT INTO Music (Path) VALUES (?)', [audio.path]);
      }
      db.dispose();
      var fail = true;
      final service = LibraryLyricsSearchService(
        database: database,
        localLyricsResolver: (path) async {
          if (fail && p.basename(path) == 'bad.mp3') {
            throw const FormatException('bad tags');
          }
          return const LyricsSnapshot(
            source: LyricsSource.lrcFile,
            isSynced: false,
            rawText: 'search me',
            lines: [LyricsLine(id: 0, timestampMs: null, text: 'search me')],
          );
        },
      );
      await service.indexMissingSongs(databaseFile);
      expect(
        await service.searchAvailable(databaseFile, 'search me'),
        hasLength(1),
      );
      fail = false;
      await service.indexMissingSongs(databaseFile);
      expect(
        await service.searchAvailable(databaseFile, 'search me'),
        hasLength(2),
      );
    },
  );
}
