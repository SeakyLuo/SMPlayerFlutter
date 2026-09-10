import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:smplayer_flutter/src/library/data/library_artist_split_service.dart';
import 'package:smplayer_flutter/src/library/data/library_audio_metadata_service.dart';
import 'package:smplayer_flutter/src/library/data/library_database_service.dart';
import 'package:smplayer_flutter/src/library/data/library_hidden_storage_service.dart';
import 'package:smplayer_flutter/src/library/data/library_local_delete_service.dart';
import 'package:smplayer_flutter/src/library/data/library_local_refresh_service.dart';
import 'package:smplayer_flutter/src/library/data/library_pending_delete_service.dart';
import 'package:smplayer_flutter/src/library/data/library_read_service.dart';
import 'package:smplayer_flutter/src/library/data/library_song_properties_service.dart';

const _properties = LibrarySongPropertiesService();
const _hidden = LibraryHiddenStorageService();
const _service = LibraryLocalRefreshService(
  songPropertiesService: _properties,
  readService: LibraryReadService(),
  hiddenStorageService: _hidden,
  audioMetadataService: LibraryAudioMetadataService(),
  artistSplitService: LibraryArtistSplitService(
    songPropertiesService: _properties,
  ),
  localDeleteService: LibraryLocalDeleteService(
    hiddenStorageService: _hidden,
    pendingDeleteService: LibraryPendingDeleteService(),
  ),
);

void main() {
  for (final full in [true, false]) {
    test(
      '${full ? 'full' : 'folder'} scan preserves existing unreadable songs and imports valid files',
      () async {
        final temp = await Directory.systemTemp.createTemp(
          'scan-preserve-bad-',
        );
        addTearDown(() => temp.delete(recursive: true));
        final root = Directory(p.join(temp.path, 'music'))..createSync();
        final bad = File(p.join(root.path, 'existing.aac'))
          ..writeAsBytesSync([1, 2, 3]);
        final invalidNew = File(p.join(root.path, 'new-bad.aac'))
          ..writeAsBytesSync([1]);
        final good = File(p.join(root.path, 'good.wav'))
          ..writeAsBytesSync(_wav());
        final databaseFile = File(p.join(temp.path, 'library.db'));
        final db = const LibraryDatabaseService()
            .openInitializedLibraryDatabase(databaseFile);
        db.execute(
          'INSERT INTO Music (Path, Name, PlayCount) VALUES (?, ?, 5)',
          [bad.path, 'keep title'],
        );
        final before = Map<String, Object?>.from(
          db.select('SELECT * FROM Music').single,
        );
        final scan =
            full ? _service.scanAllMusicLibrary : _service.refreshLocalFolder;
        final result = await scan(
          databaseFile,
          root.path,
          cacheSongArtwork: (_, _) async => '',
          readAutoLyricsEnabled: (_) => false,
          autoAddInternetLyricsForPaths: (_) async {},
          pruneArtworkCache: (_) async {},
        );
        expect(result.filesAdded, [good.path]);
        expect(result.filesRemoved, isEmpty);
        expect(
          db.select('SELECT * FROM Music WHERE Path = ?', [bad.path]).single,
          before,
        );
        expect(
          db.select('SELECT Id FROM Music WHERE Path = ?', [invalidNew.path]),
          isEmpty,
        );
        db.dispose();
      },
    );

    test(
      '${full ? 'full' : 'folder'} scan moves identity without rereading tags',
      () async {
        final temp = await Directory.systemTemp.createTemp('scan-move-');
        addTearDown(() => temp.delete(recursive: true));
        final root = Directory(p.join(temp.path, 'music'))..createSync();
        final destination = Directory(p.join(root.path, 'new'))..createSync();
        final oldPath = p.join(root.path, 'track.wav');
        final newPath = p.join(destination.path, 'track.wav');
        File(newPath).writeAsBytesSync(_wav());
        final databaseFile = File(p.join(temp.path, 'library.db'));
        final db = const LibraryDatabaseService()
            .openInitializedLibraryDatabase(databaseFile);
        db.execute(
          'INSERT INTO Music (Path, Name, Artist, Album, Duration, PlayCount, LyricsOffsetMs, DateAdded, FileSize, DateModifiedMs) VALUES (?, ?, ?, ?, 123, 9, 400, ?, 8, 7)',
          [
            oldPath,
            'custom title',
            'custom artist',
            'custom album',
            '2001-01-01',
          ],
        );
        final songId = db.lastInsertRowId;
        db.execute('INSERT INTO File (Path, FileId) VALUES (?, ?)', [
          oldPath,
          songId,
        ]);
        db.execute(
          'INSERT INTO PlaylistItem (PlaylistId, ItemId) VALUES (1, ?)',
          [songId],
        );
        db.execute('INSERT INTO MusicArtist (MusicId, Name) VALUES (?, ?)', [
          songId,
          'custom artist',
        ]);
        final before = Map<String, Object?>.from(
          db.select('SELECT * FROM Music').single,
        );
        final scan =
            full ? _service.scanAllMusicLibrary : _service.refreshLocalFolder;
        var metadataReads = 0;
        final result = await scan(
          databaseFile,
          root.path,
          cacheSongArtwork: (_, _) async {
            metadataReads++;
            return '';
          },
          readAutoLyricsEnabled: (_) => false,
          autoAddInternetLyricsForPaths: (_) async {},
          pruneArtworkCache: (_) async {},
        );
        expect(result.filesMoved, [newPath]);
        expect(metadataReads, 0);
        expect(result.filesAdded, isEmpty);
        expect(result.filesRemoved, isEmpty);
        expect(
          Map<String, Object?>.from(db.select('SELECT * FROM Music').single),
          {...before, 'Path': newPath},
        );
        expect(
          db.select('SELECT ItemId FROM PlaylistItem').single['ItemId'],
          songId,
        );
        expect(
          db.select('SELECT Name FROM MusicArtist').single['Name'],
          'custom artist',
        );
        final folderId =
            db.select('SELECT Id FROM Folder WHERE Path = ?', [
              destination.path,
            ]).single['Id'];
        expect(
          db.select('SELECT ParentId FROM File WHERE FileId = ?', [
            songId,
          ]).single['ParentId'],
          folderId,
        );
        db.dispose();
      },
    );
  }

  test('bad file is skipped while a valid WAV is imported', () async {
    final temp = await Directory.systemTemp.createTemp('scan-bad-');
    addTearDown(() => temp.delete(recursive: true));
    final bad = File(p.join(temp.path, 'bad.aac'))..writeAsBytesSync([1, 2, 3]);
    final good = File(p.join(temp.path, 'good.wav'))..writeAsBytesSync(_wav());
    final result = await const LibraryAudioMetadataService()
        .readAudioFileMetadataBatch([
          bad.path,
          good.path,
        ], cacheSongArtwork: (_, _) async => '');
    expect(result.keys, [good.path]);
    expect(result[good.path]!.duration, 1);
  });
}

Uint8List _wav() {
  final bytes = Uint8List(44 + 8000);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  data.setUint32(4, bytes.length - 8, Endian.little);
  bytes.setRange(8, 16, 'WAVEfmt '.codeUnits);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 8000, Endian.little);
  data.setUint32(28, 8000, Endian.little);
  data.setUint16(32, 1, Endian.little);
  data.setUint16(34, 8, Endian.little);
  bytes.setRange(36, 40, 'data'.codeUnits);
  data.setUint32(40, 8000, Endian.little);
  return bytes;
}
