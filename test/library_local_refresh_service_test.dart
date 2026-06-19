import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:smplayer_flutter/src/library/data/id3_tag_service.dart';
import 'package:smplayer_flutter/src/library/data/library_artist_split_service.dart';
import 'package:smplayer_flutter/src/library/data/library_audio_metadata_service.dart';
import 'package:smplayer_flutter/src/library/data/library_hidden_storage_service.dart';
import 'package:smplayer_flutter/src/library/data/library_local_delete_service.dart';
import 'package:smplayer_flutter/src/library/data/library_local_refresh_service.dart';
import 'package:smplayer_flutter/src/library/data/library_pending_delete_service.dart';
import 'package:smplayer_flutter/src/library/data/library_read_service.dart';
import 'package:smplayer_flutter/src/library/data/library_song_properties_service.dart';

void main() {
  test(
    'upsertExternalAudioFile normalizes artist tag values before saving',
    () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      _createUpsertTables(db);
      const songPropertiesService = LibrarySongPropertiesService();
      const hiddenStorageService = LibraryHiddenStorageService();
      final service = LibraryLocalRefreshService(
        songPropertiesService: songPropertiesService,
        readService: const LibraryReadService(),
        hiddenStorageService: hiddenStorageService,
        audioMetadataService: const LibraryAudioMetadataService(),
        artistSplitService: const LibraryArtistSplitService(
          songPropertiesService: songPropertiesService,
        ),
        localDeleteService: const LibraryLocalDeleteService(
          hiddenStorageService: hiddenStorageService,
          pendingDeleteService: LibraryPendingDeleteService(),
        ),
      );

      service.upsertExternalAudioFile(
        db,
        '/music/Duet.mp3',
        metadata: const AudioFileMetadata(
          properties: Id3SongTagProperties(
            title: 'Duet',
            artist: '温岚',
            artists: ['周杰伦, 温岚'],
          ),
          duration: 180,
          thumbnailPath: '',
          dateAdded: '2026-06-19T00:00:00.000Z',
        ),
      );

      expect(
        db.select('SELECT Artist FROM Music WHERE Path = ?', [
          '/music/Duet.mp3',
        ]).single['Artist'],
        '周杰伦, 温岚',
      );
      expect(
        db
            .select('''
            SELECT Name
            FROM MusicArtist
            WHERE MusicId = 1 AND State = 1
            ORDER BY Priority
          ''')
            .map((row) => row['Name'])
            .toList(),
        ['周杰伦', '温岚'],
      );
    },
  );
}

void _createUpsertTables(Database db) {
  db.execute('''
    CREATE TABLE Music (
      Id INTEGER PRIMARY KEY AUTOINCREMENT,
      Path TEXT NOT NULL UNIQUE,
      Name TEXT,
      Artist TEXT,
      Album TEXT,
      ThumbnailPath TEXT,
      Duration INTEGER DEFAULT 0,
      PlayCount INTEGER DEFAULT 0,
      DateAdded TEXT,
      State INTEGER DEFAULT 1
    )
  ''');
  db.execute('''
    CREATE TABLE MusicArtist (
      Id INTEGER PRIMARY KEY AUTOINCREMENT,
      MusicId INTEGER,
      Name TEXT,
      Priority INTEGER DEFAULT 0,
      State INTEGER DEFAULT 1
    )
  ''');
}
