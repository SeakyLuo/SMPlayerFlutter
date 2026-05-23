import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:smplayer_flutter/src/library/data/id3_tag_service.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

void main() {
  test('defaultSmPlayerUserDataPath uses the canonical app data directory', () {
    if (Platform.isMacOS) {
      expect(
        defaultSmPlayerUserDataPath(),
        p.join(
          Platform.environment['HOME']!,
          'Library',
          'Application Support',
          'Simple Melody Player',
        ),
      );
    } else if (Platform.isWindows) {
      expect(
        defaultSmPlayerUserDataPath(),
        p.join(Platform.environment['APPDATA']!, 'simple-melody-player'),
      );
    } else {
      expect(
        defaultSmPlayerUserDataPath(),
        p.join(
          Platform.environment['HOME']!,
          '.config',
          'simple-melody-player',
        ),
      );
    }
  });

  test('detectMovedLocalAudioFiles mirrors Electron refresh result rules', () {
    final movedFiles = detectMovedLocalAudioFiles(
      addedPaths: const [
        r'C:\Music\Album\Track 01.mp3',
        r'C:\Music\Album\Fresh.mp3',
      ],
      removedPaths: const [r'C:\Music\Track 01.mp3', r'C:\Music\Deleted.mp3'],
    );

    expect(movedFiles, hasLength(1));
    expect(movedFiles.single.oldPath, r'C:\Music\Track 01.mp3');
    expect(movedFiles.single.newPath, r'C:\Music\Album\Track 01.mp3');
  });

  test('detectMovedLocalAudioFiles ignores ambiguous same-name changes', () {
    final movedFiles = detectMovedLocalAudioFiles(
      addedPaths: const [
        r'C:\Music\A\Track 01.mp3',
        r'C:\Music\B\Track 01.mp3',
      ],
      removedPaths: const [r'C:\Music\Track 01.mp3'],
    );

    expect(movedFiles, isEmpty);
  });

  test('addRecentSearch persists and returns the inserted entry', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer_recent_search_test_',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    _createBatchLyricsDatabase(databaseFile, ['${directory.path}/Song.mp3']);
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    final entry = await repository.addRecentSearch(
      '  Jazz  ',
      SearchHistoryType.sidebar,
    );

    expect(entry, isNotNull);
    expect(entry!.query, 'Jazz');
    expect(entry.type, SearchHistoryType.sidebar);
    expect(entry.id, greaterThan(0));
    final db = sqlite3.open(databaseFile.path);
    try {
      final rows = db.select('''
        SELECT Id AS id, Query AS query, Type AS type, SearchedAt AS searchedAt
        FROM SearchHistory
      ''');
      expect(rows, hasLength(1));
      expect(rows.single['id'], entry.id);
      expect(rows.single['query'], 'Jazz');
      expect(rows.single['type'], 'sidebar');
      expect(rows.single['searchedAt'], entry.searchedAt);
    } finally {
      db.dispose();
    }
  });

  test('addRecentSearch initializes a new macOS-style data store', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer_new_data_store_test_',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    final entry = await repository.addRecentSearch('Jazz');
    final snapshot = await repository.getLibraryViewData();

    expect(entry, isNotNull);
    expect(databaseFile.existsSync(), isTrue);
    expect(snapshot.recentSearches.map((search) => search.query), ['Jazz']);
    expect(snapshot.rootPath, '');
  });

  test('initializeLibraryDatabase adds missing schema columns', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer_schema_migration_test_',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    await databaseFile.parent.create(recursive: true);
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('''
        CREATE TABLE Settings (
          Id INTEGER PRIMARY KEY AUTOINCREMENT,
          RootPath TEXT DEFAULT ''
        )
      ''');
      db.execute('''
        CREATE TABLE SearchHistory (
          Id INTEGER PRIMARY KEY AUTOINCREMENT,
          Query TEXT NOT NULL
        )
      ''');
    } finally {
      db.dispose();
    }
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    await repository.initializeLibraryDatabase();

    final migrated = sqlite3.open(databaseFile.path);
    try {
      final settingsColumns =
          migrated
              .select("PRAGMA table_info('Settings')")
              .map((row) => row['name'])
              .toSet();
      final searchHistoryColumns =
          migrated
              .select("PRAGMA table_info('SearchHistory')")
              .map((row) => row['name'])
              .toSet();
      expect(settingsColumns, contains('SmartMultiArtistRecognition'));
      expect(settingsColumns, contains('DesktopLyricsEnabled'));
      expect(searchHistoryColumns, contains('Type'));
      expect(searchHistoryColumns, contains('SearchedAt'));
    } finally {
      migrated.dispose();
    }
  });

  test(
    'initializeLibraryDatabase creates the settings singleton row',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smplayer_empty_store_test_',
      );
      addTearDown(() async {
        await directory.delete(recursive: true);
      });
      final databaseFile = File('${directory.path}/SMPlayerSettings.db');
      final repository = LibraryRepository(
        databaseFileResolver: () async => databaseFile,
      );

      await repository.initializeLibraryDatabase();
      await repository.updateSettings(
        const AppSettingsUpdate(nightMode: NightMode.auto),
      );
      final snapshot = await repository.getSettingsSnapshot();

      expect(snapshot!.nightMode, NightMode.auto);
    },
  );

  test(
    'selectWindowsUwpDatabaseCandidate mirrors Electron library scoring',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smplayer-uwp-candidate-',
      );
      addTearDown(() async {
        await directory.delete(recursive: true);
      });

      final existingOne = File('${directory.path}/existing-one.mp3');
      final existingTwo = File('${directory.path}/existing-two.mp3');
      await existingOne.writeAsBytes(const []);
      await existingTwo.writeAsBytes(const []);

      final newerEmpty = File('${directory.path}/newer.db');
      final olderWithFiles = File('${directory.path}/older.db');
      _writeCandidateMusicDatabase(newerEmpty, const ['/missing-a.mp3']);
      _writeCandidateMusicDatabase(olderWithFiles, [
        existingOne.path,
        existingTwo.path,
        '/missing-b.mp3',
      ]);
      newerEmpty.setLastModifiedSync(DateTime(2026, 1, 2));
      olderWithFiles.setLastModifiedSync(DateTime(2026, 1, 1));

      expect(
        selectWindowsUwpDatabaseCandidate([newerEmpty, olderWithFiles]),
        olderWithFiles,
      );
    },
  );

  test(
    'findScannableAudioFiles mirrors Electron hidden scan filters',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smplayer-scan-filter-',
      );
      addTearDown(() async {
        await directory.delete(recursive: true);
      });

      final visible = File('${directory.path}/Visible.mp3');
      final resourceFork = File('${directory.path}/._Visible.mp3');
      final hiddenFile = File('${directory.path}/Hidden.mp3');
      final hiddenFolder = Directory('${directory.path}/HiddenFolder');
      final logicProject = Directory('${directory.path}/Project.logicx');
      await hiddenFolder.create();
      await logicProject.create();
      await visible.writeAsBytes(const []);
      await resourceFork.writeAsBytes(const []);
      await hiddenFile.writeAsBytes(const []);
      await File('${hiddenFolder.path}/Nested.mp3').writeAsBytes(const []);
      await File('${logicProject.path}/Bounce.mp3').writeAsBytes(const []);

      final files = findScannableAudioFiles(
        directory.path,
        hiddenFolderPaths: [hiddenFolder.path],
        hiddenFilePaths: [hiddenFile.path],
      );

      expect(files, [visible.path]);
    },
  );

  test(
    'importDataFrom rolls back current database when import is invalid',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smplayer-import-rollback-',
      );
      addTearDown(() async {
        await directory.delete(recursive: true);
      });
      final databaseFile = File('${directory.path}/SMPlayerSettings.db');
      final invalidImport = File('${directory.path}/broken.db');
      _createImportDatabase(
        databaseFile,
        rootPath: '/current',
        songPath: '/current/Track.mp3',
      );
      await invalidImport.writeAsString('not sqlite');
      final repository = LibraryRepository(
        databaseFileResolver: () async => databaseFile,
      );

      await expectLater(
        repository.importDataFrom(invalidImport.path),
        throwsA(isA<SqliteException>()),
      );

      final db = sqlite3.open(databaseFile.path);
      try {
        expect(
          db.select('SELECT RootPath FROM Settings').single['RootPath'],
          '/current',
        );
        expect(
          db.select('SELECT Path FROM Music').single['Path'],
          '/current/Track.mp3',
        );
      } finally {
        db.dispose();
      }
      expect(File('${databaseFile.path}.import-backup').existsSync(), isFalse);
    },
  );

  test('importDataFrom replaces imported root path references', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-import-root-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    final importedFile = File('${directory.path}/import.db');
    _createImportDatabase(
      databaseFile,
      rootPath: '/current',
      songPath: '/current/Old.mp3',
    );
    _createImportDatabase(
      importedFile,
      rootPath: '/imported',
      songPath: '/imported/Album/New.mp3',
    );
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    final imported = await repository.importDataFrom(importedFile.path);

    expect(imported, isTrue);
    final db = sqlite3.open(databaseFile.path);
    try {
      expect(
        db.select('SELECT RootPath FROM Settings').single['RootPath'],
        '/current',
      );
      expect(
        db.select('SELECT Path FROM Music').single['Path'],
        '/current/Album/New.mp3',
      );
      expect(
        db
            .select('SELECT Path FROM Folder ORDER BY Id')
            .map((row) => row['Path']),
        ['/current', '/current/Album'],
      );
      expect(
        db.select('SELECT Path FROM File').single['Path'],
        '/current/Album/New.mp3',
      );
      expect(
        db.select('SELECT Path FROM HiddenStorageItem').single['Path'],
        '/current/Hidden',
      );
    } finally {
      db.dispose();
    }
  });

  test(
    'importDataFrom rescans imported root when root path is unchanged',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smplayer-import-rescan-',
      );
      addTearDown(() async {
        await directory.delete(recursive: true);
      });
      final root = Directory('${directory.path}/Library');
      await root.create(recursive: true);
      final song = File('${root.path}/Imported.mp3');
      await song.writeAsBytes([0xff, 0xfb, 0x90, 0x64]);
      final databaseFile = File('${directory.path}/SMPlayerSettings.db');
      final importedFile = File('${directory.path}/import.db');
      _createScanDatabase(databaseFile, '');
      _setImportRootPath(databaseFile, root.path);
      _createScanDatabase(importedFile, '');
      _setImportRootPath(importedFile, root.path);
      final repository = LibraryRepository(
        databaseFileResolver: () async => databaseFile,
      );

      final imported = await repository.importDataFrom(importedFile.path);

      expect(imported, isTrue);
      final db = sqlite3.open(databaseFile.path);
      try {
        expect(
          db
              .select('SELECT Path FROM Music WHERE State = 1 ORDER BY Path')
              .map((row) => row['Path']),
          [song.path],
        );
        expect(
          db.select('SELECT RootPath FROM Settings').single['RootPath'],
          root.path,
        );
      } finally {
        db.dispose();
      }
    },
  );

  test('Local move undo restores file path and database rows', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-local-move-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });

    final source = Directory('${directory.path}/Source')..createSync();
    final target = Directory('${directory.path}/Target')..createSync();
    final song = File('${source.path}/Song.mp3')..writeAsBytesSync(const []);
    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    _createLocalMoveDatabase(
      databaseFile: databaseFile,
      sourceFolderPath: source.path,
      targetFolderPath: target.path,
      songPath: song.path,
    );
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    final result = await repository.moveLocalItemsToFolder(
      const [1],
      const [],
      target.path,
    );

    expect(result.itemCount, 1);
    expect(File(song.path).existsSync(), isFalse);
    expect(File(result.songs.single.newPath).existsSync(), isTrue);
    expect(_readMusicPath(databaseFile, 1), result.songs.single.newPath);

    await repository.undoMoveLocalItems(result);

    expect(File(song.path).existsSync(), isTrue);
    expect(_readMusicPath(databaseFile, 1), song.path);
  });

  test('Local move conflict can skip or replace like Electron', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-local-move-conflict-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });

    final source = Directory('${directory.path}/Source')..createSync();
    final target = Directory('${directory.path}/Target')..createSync();
    final song = File('${source.path}/Song.mp3')..writeAsStringSync('source');
    final targetSong = File('${target.path}/Song.mp3')
      ..writeAsStringSync('target');
    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    _createLocalMoveDatabase(
      databaseFile: databaseFile,
      sourceFolderPath: source.path,
      targetFolderPath: target.path,
      songPath: song.path,
    );
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    final skipped = await repository.moveSongToFolder(
      1,
      target.path,
      resolveConflict: (_, _) async => LocalMoveConflictResolution.skip,
    );

    expect(skipped.itemCount, 0);
    expect(song.existsSync(), isTrue);
    expect(targetSong.readAsStringSync(), 'target');

    final replaced = await repository.moveSongToFolder(
      1,
      target.path,
      resolveConflict: (_, _) async => LocalMoveConflictResolution.replace,
    );

    expect(replaced.itemCount, 1);
    expect(song.existsSync(), isFalse);
    expect(targetSong.readAsStringSync(), 'source');
    expect(_readMusicPath(databaseFile, 1), targetSong.path);
  });

  test(
    'Local folder move merges same-name target folder like Electron',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smplayer-local-folder-merge-',
      );
      addTearDown(() async {
        await directory.delete(recursive: true);
      });

      final sourceRoot = Directory('${directory.path}/Source')..createSync();
      final targetRoot = Directory('${directory.path}/Target')..createSync();
      final sourceAlbum = Directory('${sourceRoot.path}/Album')..createSync();
      final targetAlbum = Directory('${targetRoot.path}/Album')..createSync();
      final sourceNested = Directory('${sourceAlbum.path}/Nested')
        ..createSync();
      final sourceSong = File('${sourceAlbum.path}/Song.mp3')
        ..writeAsStringSync('source');
      final targetSong = File('${targetAlbum.path}/Song.mp3')
        ..writeAsStringSync('target');
      final nestedSong = File('${sourceNested.path}/Nested.mp3')
        ..writeAsStringSync('nested');
      final databaseFile = File('${directory.path}/SMPlayerSettings.db');
      _createLocalMoveDatabase(
        databaseFile: databaseFile,
        sourceFolderPath: sourceRoot.path,
        targetFolderPath: targetRoot.path,
        songPath: sourceSong.path,
      );
      _addLocalFolder(databaseFile, sourceAlbum.path, parentId: 1);
      _addLocalFolder(databaseFile, targetAlbum.path, parentId: 2);
      _addLocalFolder(databaseFile, sourceNested.path, parentId: 3);
      _addLocalSong(databaseFile, nestedSong.path, parentId: 5);
      final repository = LibraryRepository(
        databaseFileResolver: () async => databaseFile,
      );

      final result = await repository.moveLocalItemsToFolder(
        const [],
        [sourceAlbum.path],
        targetRoot.path,
        resolveConflict: (_, _) async => LocalMoveConflictResolution.keepBoth,
      );

      final keptBothSong = File('${targetAlbum.path}/Song (1).mp3');
      final movedNestedSong = File('${targetAlbum.path}/Nested/Nested.mp3');
      expect(sourceAlbum.existsSync(), isFalse);
      expect(targetSong.readAsStringSync(), 'target');
      expect(keptBothSong.readAsStringSync(), 'source');
      expect(movedNestedSong.readAsStringSync(), 'nested');
      expect(_readMusicPath(databaseFile, 1), keptBothSong.path);
      expect(_readMusicPath(databaseFile, 2), movedNestedSong.path);
      expect(_readFolderState(databaseFile, sourceAlbum.path), 0);

      await repository.undoMoveLocalItems(result);

      expect(sourceSong.readAsStringSync(), 'source');
      expect(nestedSong.readAsStringSync(), 'nested');
      expect(targetSong.readAsStringSync(), 'target');
      expect(_readMusicPath(databaseFile, 1), sourceSong.path);
      expect(_readMusicPath(databaseFile, 2), nestedSong.path);
      expect(_readFolderState(databaseFile, sourceAlbum.path), 1);
    },
  );

  test('Local hide undo restores song and folder state', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-local-hide-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });

    final source = Directory('${directory.path}/Source')..createSync();
    final target = Directory('${directory.path}/Target')..createSync();
    final song = File('${source.path}/Song.mp3')..writeAsBytesSync(const []);
    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    _createLocalMoveDatabase(
      databaseFile: databaseFile,
      sourceFolderPath: source.path,
      targetFolderPath: target.path,
      songPath: song.path,
    );
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    await repository.hideSong(1);
    expect(_readMusicState(databaseFile, 1), -1);
    await repository.unhideSong(1);
    expect(_readMusicState(databaseFile, 1), 1);

    await repository.hideFolder(source.path);
    expect(_readFolderState(databaseFile, source.path), -1);
    await repository.unhideFolder(source.path);
    expect(_readFolderState(databaseFile, source.path), 1);
  });

  test(
    'hidden folder state mirrors Electron parent-hidden semantics',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smplayer-hidden-parent-',
      );
      addTearDown(() async {
        await directory.delete(recursive: true);
      });

      final source = Directory('${directory.path}/Source')..createSync();
      final target = Directory('${directory.path}/Target')..createSync();
      final nested = Directory('${source.path}/Nested')..createSync();
      final song = File('${source.path}/Song.mp3')..writeAsBytesSync(const []);
      final nestedSong = File('${nested.path}/Nested.mp3')
        ..writeAsBytesSync(const []);
      final databaseFile = File('${directory.path}/SMPlayerSettings.db');
      _createLocalMoveDatabase(
        databaseFile: databaseFile,
        sourceFolderPath: source.path,
        targetFolderPath: target.path,
        songPath: song.path,
      );
      _addLocalFolder(databaseFile, nested.path, parentId: 1);
      _addLocalSong(databaseFile, nestedSong.path, parentId: 3);
      final repository = LibraryRepository(
        databaseFileResolver: () async => databaseFile,
      );

      await repository.hideFolder(source.path);

      expect(_readFolderState(databaseFile, source.path), -1);
      expect(_readFolderState(databaseFile, nested.path), -2);
      expect(_readMusicState(databaseFile, 1), -2);
      expect(_readMusicState(databaseFile, 2), -2);
      expect(_readFileState(databaseFile, song.path), -2);
      expect(_readFileState(databaseFile, nestedSong.path), -2);
      expect(
        (await repository.getHiddenStorageItems()).map((item) => item.path),
        [source.path],
      );

      await repository.resumeHiddenStorageItem(
        HiddenStorageItem(id: 1, type: 'folder', path: source.path),
      );

      expect(_readFolderState(databaseFile, source.path), 1);
      expect(_readFolderState(databaseFile, nested.path), 1);
      expect(_readMusicState(databaseFile, 1), 1);
      expect(_readMusicState(databaseFile, 2), 1);
      expect(_readFileState(databaseFile, song.path), 1);
      expect(_readFileState(databaseFile, nestedSong.path), 1);
      expect(await repository.getHiddenStorageItems(), isEmpty);
    },
  );

  test(
    'markSongPlayed increments play count and refreshes recent record',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smplayer-mark-played-',
      );
      addTearDown(() async {
        await directory.delete(recursive: true);
      });
      final databaseFile = File('${directory.path}/SMPlayerSettings.db');
      _createPlayedSongDatabase(databaseFile);
      final repository = LibraryRepository(
        databaseFileResolver: () async => databaseFile,
      );

      await repository.markSongPlayed(1);

      final db = sqlite3.open(databaseFile.path);
      try {
        expect(
          db
              .select('SELECT PlayCount FROM Music WHERE Id = 1')
              .single['PlayCount'],
          3,
        );
        expect(
          db
              .select(
                'SELECT State FROM RecentRecord WHERE Type = 0 AND ItemId = ? ORDER BY Id',
                ['1'],
              )
              .map((row) => row['State']),
          [0, 1],
        );
        expect(
          db.select(
            'SELECT Time FROM RecentRecord WHERE Type = 0 AND ItemId = ? AND State = 1',
            ['1'],
          ).single['Time'],
          isNotEmpty,
        );
      } finally {
        db.dispose();
      }
    },
  );

  test('getLibraryViewData cleans invalid recent played records', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-recent-cleanup-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    _createBatchLyricsDatabase(databaseFile, [
      '${directory.path}/Library/Song.mp3',
    ]);
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        'INSERT INTO RecentRecord (Type, ItemId, Time, State) VALUES (0, ?, ?, 1)',
        ['1', '2026-05-20T00:00:00.000Z'],
      );
      db.execute(
        'INSERT INTO RecentRecord (Type, ItemId, Time, State) VALUES (0, ?, ?, 1)',
        ['999', '2026-05-21T00:00:00.000Z'],
      );
    } finally {
      db.dispose();
    }
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    final snapshot = await repository.getLibraryViewData();

    expect(snapshot.recentSongs.map((song) => song.id), [1]);
    final checkDb = sqlite3.open(databaseFile.path);
    try {
      expect(
        checkDb
            .select('SELECT ItemId, State FROM RecentRecord ORDER BY Id')
            .map((row) => (itemId: row['ItemId'], state: row['State'])),
        [(itemId: '1', state: 1), (itemId: '999', state: 0)],
      );
    } finally {
      checkDb.dispose();
    }
  });

  test('getLibraryViewData cleans invalid playlist items', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-playlist-cleanup-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    _createBatchLyricsDatabase(databaseFile, [
      '${directory.path}/Library/Song.mp3',
    ]);
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('INSERT INTO Playlist (Id, Name, State) VALUES (?, ?, ?)', [
        10,
        'Mix',
        1,
      ]);
      db.execute('INSERT INTO Playlist (Id, Name, State) VALUES (?, ?, ?)', [
        11,
        'Old Mix',
        0,
      ]);
      db.execute(
        'INSERT INTO PlaylistItem (PlaylistId, ItemId, State) VALUES (?, ?, ?)',
        [10, 1, 1],
      );
      db.execute(
        'INSERT INTO PlaylistItem (PlaylistId, ItemId, State) VALUES (?, ?, ?)',
        [10, 999, 1],
      );
      db.execute(
        'INSERT INTO PlaylistItem (PlaylistId, ItemId, State) VALUES (?, ?, ?)',
        [11, 1, 1],
      );
    } finally {
      db.dispose();
    }
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    final snapshot = await repository.getLibraryViewData();

    expect(snapshot.playlists.single.songIds, [1]);
    final checkDb = sqlite3.open(databaseFile.path);
    try {
      expect(
        checkDb
            .select(
              'SELECT PlaylistId, ItemId, State FROM PlaylistItem ORDER BY Id',
            )
            .map(
              (row) => (
                playlistId: row['PlaylistId'],
                itemId: row['ItemId'],
                state: row['State'],
              ),
            ),
        [
          (playlistId: 10, itemId: 1, state: 1),
          (playlistId: 10, itemId: 999, state: 0),
          (playlistId: 11, itemId: 1, state: 0),
        ],
      );
    } finally {
      checkDb.dispose();
    }
  });

  test('restorePlaylist preserves Electron priority semantics', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-playlist-restore-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    _createBatchLyricsDatabase(databaseFile, [
      '${directory.path}/Library/Song.mp3',
    ]);
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute(
        'INSERT INTO Playlist (Id, Name, Criterion, Priority, State) VALUES (?, ?, ?, ?, ?)',
        [10, 'Earlier', -1, 0, 1],
      );
      db.execute(
        'INSERT INTO Playlist (Id, Name, Criterion, Priority, State) VALUES (?, ?, ?, ?, ?)',
        [11, 'Restored', -1, 1, 0],
      );
      db.execute(
        'INSERT INTO Playlist (Id, Name, Criterion, Priority, State) VALUES (?, ?, ?, ?, ?)',
        [12, 'Later', -1, 1, 1],
      );
      db.execute(
        'INSERT INTO PlaylistItem (PlaylistId, ItemId, State) VALUES (?, ?, ?)',
        [11, 1, 0],
      );
    } finally {
      db.dispose();
    }
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    await repository.restorePlaylist(
      const LibraryPlaylist(
        id: 11,
        name: 'Restored',
        priority: 1,
        songCount: 1,
        songIds: [1],
        sortCriterion: PlaylistSortCriterion.title,
        isBuiltIn: false,
      ),
    );

    final checkDb = sqlite3.open(databaseFile.path);
    try {
      expect(
        checkDb
            .select(
              'SELECT Id, Priority, State FROM Playlist WHERE Id IN (10, 11, 12) ORDER BY Id',
            )
            .map(
              (row) => (
                id: row['Id'],
                priority: row['Priority'],
                state: row['State'],
              ),
            ),
        [
          (id: 10, priority: 0, state: 1),
          (id: 11, priority: 1, state: 1),
          (id: 12, priority: 2, state: 1),
        ],
      );
      expect(
        checkDb
            .select(
              'SELECT ItemId, State FROM PlaylistItem WHERE PlaylistId = 11',
            )
            .map((row) => (itemId: row['ItemId'], state: row['State'])),
        [(itemId: 1, state: 1)],
      );
    } finally {
      checkDb.dispose();
    }
  });

  test(
    'removeSongFromNowPlaying mirrors Electron path-backed queue removal',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smplayer-now-playing-remove-',
      );
      addTearDown(() async {
        await directory.delete(recursive: true);
      });
      final songPaths = [
        '${directory.path}/Library/One.mp3',
        '${directory.path}/Library/Two.mp3',
        '${directory.path}/Library/Three.mp3',
      ];
      final databaseFile = File('${directory.path}/SMPlayerSettings.db');
      final nowPlayingFile = File('${directory.path}/NowPlaying.json');
      _createBatchLyricsDatabase(databaseFile, songPaths);
      nowPlayingFile.writeAsStringSync(
        jsonEncode([songPaths[0], songPaths[1], songPaths[0], songPaths[2]]),
      );
      final repository = LibraryRepository(
        databaseFileResolver: () async => databaseFile,
        nowPlayingFileResolver: () => nowPlayingFile,
      );

      await repository.removeSongFromNowPlaying(1);

      expect(jsonDecode(nowPlayingFile.readAsStringSync()), [
        songPaths[1],
        songPaths[2],
      ]);
    },
  );

  test('pending song delete commit uses system trash hook', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-trash-song-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final song = File('${directory.path}/Song.mp3')..writeAsBytesSync(const []);
    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    final pendingFile = File('${directory.path}/pending-song-deletes.json');
    _createPendingDeleteDatabase(databaseFile, song.path);
    final trashedPaths = <String>[];
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
      pendingDeleteFileResolver: () async => pendingFile,
      trashPath: (path) async {
        trashedPaths.add(path);
        await File(path).delete();
      },
    );

    final pendingDelete = await repository.beginDeleteSongFromDisk(1);
    await repository.commitDeleteSongFromDisk(pendingDelete.id);

    expect(trashedPaths, [song.path]);
    expect(song.existsSync(), isFalse);
    expect(pendingFile.readAsStringSync().trim(), '[]');
  });

  test('pending local item delete commit trashes every target path', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-trash-local-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final root = Directory('${directory.path}/Root')..createSync();
    final song = File('${root.path}/Song.mp3')..writeAsBytesSync(const []);
    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    final pendingFile = File('${directory.path}/pending-song-deletes.json');
    _createPendingDeleteDatabase(
      databaseFile,
      song.path,
      folderPath: root.path,
    );
    final trashedPaths = <String>[];
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
      pendingDeleteFileResolver: () async => pendingFile,
      trashPath: (path) async {
        trashedPaths.add(path);
        final type = FileSystemEntity.typeSync(path);
        if (type == FileSystemEntityType.directory) {
          await Directory(path).delete(recursive: true);
        } else if (type == FileSystemEntityType.file) {
          await File(path).delete();
        }
      },
    );

    final pendingDelete = await repository.beginDeleteLocalItems(const [], [
      root.path,
    ]);
    await repository.commitDeleteLocalItems(pendingDelete.id);

    expect(trashedPaths, [root.path]);
    expect(root.existsSync(), isFalse);
    expect(pendingFile.readAsStringSync().trim(), '[]');
  });

  test('scanAllMusicLibrary rebuilds Electron root scan graph', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-root-scan-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final root = Directory('${directory.path}/Library');
    final album = Directory('${root.path}/Album');
    final hidden = Directory('${root.path}/Hidden');
    await album.create(recursive: true);
    await hidden.create();
    final visibleSong = File('${album.path}/Visible.mp3');
    final hiddenSong = File('${hidden.path}/Hidden.mp3');
    await visibleSong.writeAsBytes([0xff, 0xfb, 0x90, 0x64]);
    await const Id3TagService().writeSongArtwork(
      visibleSong.path,
      Id3Picture(data: Uint8List.fromList(_pngBytes), format: 'image/png'),
    );
    await hiddenSong.writeAsBytes(const []);

    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    _createScanDatabase(databaseFile, hidden.path);
    final staleThumbnail = File(
      '${directory.path}/ArtworkCache/stale-thumbnail.png',
    );
    await staleThumbnail.create(recursive: true);
    await staleThumbnail.writeAsBytes([1, 2, 3]);

    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );
    final result = await repository.scanAllMusicLibrary(root.path);

    expect(result.filesAdded, [visibleSong.path]);
    expect(result.filesRemoved, [r'C:\Old\Missing.mp3']);

    final db = sqlite3.open(databaseFile.path);
    try {
      expect(
        db
            .select('SELECT RootPath AS rootPath FROM Settings')
            .single['rootPath'],
        root.path,
      );
      expect(
        db
            .select(
              'SELECT Path AS path FROM Music WHERE State = 1 ORDER BY Path',
            )
            .map((row) => row['path']),
        [visibleSong.path],
      );
      expect(
        db
            .select(
              'SELECT Path AS path FROM File WHERE State = 1 ORDER BY Path',
            )
            .map((row) => row['path']),
        [visibleSong.path],
      );
      expect(
        db
            .select(
              'SELECT Path AS path FROM Folder WHERE State = 1 ORDER BY Path',
            )
            .map((row) => row['path']),
        [root.path, album.path],
      );
      final thumbnailPath =
          db.select('SELECT ThumbnailPath FROM Music WHERE Path = ?', [
                visibleSong.path,
              ]).single['ThumbnailPath']
              as String;
      expect(thumbnailPath, isNotEmpty);
      expect(File(thumbnailPath).existsSync(), isTrue);
      expect(staleThumbnail.existsSync(), isFalse);
    } finally {
      db.dispose();
    }
  });

  test(
    'scanAllMusicLibrary auto-saves lyrics for added songs in background',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smplayer-root-scan-lyrics-',
      );
      addTearDown(() async {
        await directory.delete(recursive: true);
      });
      final root = Directory('${directory.path}/Library');
      await root.create(recursive: true);
      final visibleSong = File('${root.path}/Visible.mp3');
      await visibleSong.writeAsBytes([0xff, 0xfb, 0x90, 0x64]);

      final databaseFile = File('${directory.path}/SMPlayerSettings.db');
      _createScanDatabase(databaseFile, '', autoLyrics: true);
      final repository = LibraryRepository(
        databaseFileResolver: () async => databaseFile,
        internetLyricsResolver: (song) async => '[00:02.00]${song.title}',
      );

      final result = await repository.scanAllMusicLibrary(root.path);
      expect(result.filesAdded, [visibleSong.path]);

      await _waitForEmbeddedLyrics(visibleSong, '[00:02.00]Visible');
    },
  );

  test('scanAllMusicLibrary honors filename-title setting', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-root-scan-filename-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final root = Directory('${directory.path}/Library');
    await root.create(recursive: true);
    final song = File('${root.path}/Filename Title.mp3');
    await song.writeAsBytes([0xff, 0xfb, 0x90, 0x64]);
    await const Id3TagService().writeSongTagProperties(
      song.path,
      const Id3SongTagProperties(title: 'Tagged Title', artist: 'Artist'),
    );

    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    _createScanDatabase(databaseFile, '', useFilenameNotMusicName: true);
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    await repository.scanAllMusicLibrary(root.path);

    final db = sqlite3.open(databaseFile.path);
    try {
      expect(
        db.select('SELECT Name FROM Music WHERE Path = ?', [
          song.path,
        ]).single['Name'],
        'Filename Title',
      );
    } finally {
      db.dispose();
    }
  });

  test('createLocalFolder mirrors Electron create then refresh flow', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-create-local-folder-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final root = Directory('${directory.path}/Library');
    await root.create(recursive: true);
    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    _createScanDatabase(databaseFile, '');
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('UPDATE Settings SET RootPath = ?', [root.path]);
      db.execute('INSERT INTO Folder (Path, State) VALUES (?, 1)', [root.path]);
      db.execute(
        'INSERT INTO Folder (Path, ParentId, State) VALUES (?, 1, 1)',
        ['${root.path}/New Folder'],
      );
    } finally {
      db.dispose();
    }
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    final result = await repository.createLocalFolder(
      root.path,
      '',
      'New Folder',
    );

    final createdFolder = Directory('${root.path}/New Folder');
    expect(createdFolder.existsSync(), isTrue);
    expect(result.hasChanges, isFalse);
    final checkDb = sqlite3.open(databaseFile.path);
    try {
      expect(
        checkDb
            .select('SELECT Path FROM Folder WHERE State = 1 ORDER BY Path')
            .map((row) => row['Path']),
        [root.path],
      );
      expect(
        checkDb.select('SELECT State FROM Folder WHERE Path = ?', [
          createdFolder.path,
        ]).single['State'],
        0,
      );
    } finally {
      checkDb.dispose();
    }
  });

  test('scanAllMusicLibrary honors smart artist recognition setting', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-root-scan-artist-setting-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final root = Directory('${directory.path}/Library');
    await root.create(recursive: true);
    final song = File('${root.path}/Duet.mp3');
    await song.writeAsBytes([0xff, 0xfb, 0x90, 0x64]);
    await const Id3TagService().writeSongTagProperties(
      song.path,
      const Id3SongTagProperties(title: 'Duet', artist: 'Alice/Bob'),
    );

    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    _createScanDatabase(databaseFile, '', smartMultiArtistRecognition: false);
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    final result = await repository.scanAllMusicLibrary(root.path);

    expect(result.artistSplitsApplied, isEmpty);
    expect(result.artistSplitSuggestions, isEmpty);
    expect(result.artistMergeSuggestions, isEmpty);
  });

  test(
    'scanAllMusicLibrary cancellation stops before database writes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smplayer-root-scan-cancel-',
      );
      addTearDown(() async {
        await directory.delete(recursive: true);
      });
      final root = Directory('${directory.path}/Library');
      final album = Directory('${root.path}/Album');
      final hidden = Directory('${root.path}/Hidden');
      await album.create(recursive: true);
      await hidden.create();
      final visibleSong = File('${album.path}/Visible.mp3');
      await visibleSong.writeAsBytes([0xff, 0xfb, 0x90, 0x64]);

      final databaseFile = File('${directory.path}/SMPlayerSettings.db');
      _createScanDatabase(databaseFile, hidden.path);
      final repository = LibraryRepository(
        databaseFileResolver: () async => databaseFile,
      );
      final cancellation = LocalFolderScanCancellation();
      final stages = <LocalFolderRefreshStage>[];
      final checkingTotals = <int>[];

      await expectLater(
        repository.scanAllMusicLibrary(
          root.path,
          cancellation: cancellation,
          onProgress: (progress) {
            stages.add(progress.stage);
            if (progress.stage == LocalFolderRefreshStage.checking) {
              checkingTotals.add(progress.total);
            }
            if (progress.stage == LocalFolderRefreshStage.reading &&
                progress.current == 0) {
              cancellation.cancel();
            }
          },
        ),
        throwsA(isA<LocalFolderScanCanceledException>()),
      );

      expect(
        stages,
        containsAllInOrder([
          LocalFolderRefreshStage.checking,
          LocalFolderRefreshStage.reading,
        ]),
      );
      expect(checkingTotals, [2, 2]);
      final db = sqlite3.open(databaseFile.path);
      try {
        expect(
          db.select('SELECT RootPath FROM Settings').single['RootPath'],
          '',
        );
        expect(
          db
              .select('SELECT Path AS path FROM Music WHERE State = 1')
              .map((row) => row['path']),
          [r'C:\Old\Missing.mp3'],
        );
      } finally {
        db.dispose();
      }
    },
  );

  test(
    'external audio import caches embedded artwork like Electron scan',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smplayer-artwork-scan-',
      );
      addTearDown(() async {
        await directory.delete(recursive: true);
      });
      final songFile = File('${directory.path}/Artwork.mp3');
      await songFile.writeAsBytes([0xff, 0xfb, 0x90, 0x64]);
      await const Id3TagService().writeSongArtwork(
        songFile.path,
        Id3Picture(data: Uint8List.fromList(_pngBytes), format: 'image/png'),
      );

      final databaseFile = File('${directory.path}/SMPlayerSettings.db');
      _createScanDatabase(databaseFile, '${directory.path}/Hidden');
      final repository = LibraryRepository(
        databaseFileResolver: () async => databaseFile,
      );

      final songIds = await repository.importExternalAudioFiles([
        songFile.path,
      ]);

      expect(songIds, hasLength(1));
      final db = sqlite3.open(databaseFile.path);
      try {
        final thumbnailPath =
            db.select('SELECT ThumbnailPath FROM Music WHERE Path = ?', [
                  songFile.path,
                ]).single['ThumbnailPath']
                as String;
        expect(thumbnailPath, isNotEmpty);
        expect(File(thumbnailPath).existsSync(), isTrue);
        expect(File(thumbnailPath).readAsBytesSync(), _pngBytes);
      } finally {
        db.dispose();
      }
    },
  );

  test('external audio import syncs multi-value artists', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-external-artists-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final songFile = File('${directory.path}/Artists.mp3');
    await songFile.writeAsBytes([
      ..._id3v24TextTag({'TIT2': 'Duet', 'TPE1': 'Artist One\u0000Artist Two'}),
      0xff,
      0xfb,
      0x90,
      0x64,
    ]);

    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    _createScanDatabase(databaseFile, '${directory.path}/Hidden');
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    final songIds = await repository.importExternalAudioFiles([songFile.path]);

    expect(songIds, hasLength(1));
    final db = sqlite3.open(databaseFile.path);
    try {
      expect(
        db.select('SELECT Artist FROM Music WHERE Path = ?', [
          songFile.path,
        ]).single['Artist'],
        'Artist One, Artist Two',
      );
      expect(
        db
            .select(
              '''
              SELECT Name
              FROM MusicArtist
              WHERE MusicId = ?
                AND State = 1
              ORDER BY Priority
              ''',
              [songIds.single],
            )
            .map((row) => row['Name']),
        ['Artist One', 'Artist Two'],
      );
    } finally {
      db.dispose();
    }
  });

  test('startup artist split check only targets legacy libraries', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-startup-artists-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('''
        CREATE TABLE Music (
          Id INTEGER PRIMARY KEY AUTOINCREMENT,
          Path TEXT,
          Name TEXT,
          Artist TEXT,
          State INTEGER DEFAULT 1
        )
      ''');
      db.execute(
        'INSERT INTO Music (Path, Name, Artist, State) VALUES (?, ?, ?, 1)',
        ['song.mp3', 'Song', 'Artist A, Artist B'],
      );
    } finally {
      db.dispose();
    }
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    expect(await repository.shouldCheckStartupArtistSplits(), isTrue);
    expect(await repository.shouldCheckStartupArtistSplits(), isFalse);
  });

  test('readLyricsFromFile imports embedded audio lyrics', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-import-audio-lyrics-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final songFile = File('${directory.path}/Lyrics.mp3');
    await songFile.writeAsBytes([0xff, 0xfb, 0x90, 0x64]);
    await const Id3TagService().writeEmbeddedLyrics(
      songFile.path,
      '[00:01.00]Line one',
    );

    final repository = LibraryRepository();

    expect(
      await repository.readLyricsFromFile(songFile.path),
      '[00:01.00]Line one',
    );
  });

  test('getSongLyrics respects Electron lyrics request modes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-lyrics-mode-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final songFile = File('${directory.path}/Mode.mp3');
    await songFile.writeAsBytes([0xff, 0xfb, 0x90, 0x64]);
    await const Id3TagService().writeEmbeddedLyrics(
      songFile.path,
      '[00:02.00]Embedded line',
    );
    await _waitForEmbeddedLyrics(songFile, '[00:02.00]Embedded line');
    await File(
      p.setExtension(songFile.path, '.lrc'),
    ).writeAsString('[00:01.00]Local line');
    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    _createLyricsModeDatabase(databaseFile, songFile.path);
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    final local = await repository.getSongLyrics(
      1,
      mode: LyricsRequestMode.local,
    );
    final embedded = await repository.getSongLyrics(
      1,
      mode: LyricsRequestMode.embedded,
    );
    final automatic = await repository.getSongLyrics(
      1,
      mode: LyricsRequestMode.auto,
    );

    expect(local.source, LyricsSource.lrcFile);
    expect(local.lines.single.text, 'Local line');
    expect(embedded.source, LyricsSource.musicFile);
    expect(embedded.lines.single.text, 'Embedded line');
    expect(automatic.source, LyricsSource.lrcFile);
  });

  test('external audio import falls back to sibling folder artwork', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-folder-artwork-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final songFile = File('${directory.path}/NoEmbeddedArtwork.mp3');
    final folderArtwork = File('${directory.path}/Folder.JPG');
    await songFile.writeAsBytes([0xff, 0xfb, 0x90, 0x64]);
    await folderArtwork.writeAsBytes(_pngBytes);

    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    _createScanDatabase(databaseFile, '${directory.path}/Hidden');
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
    );

    await repository.importExternalAudioFiles([songFile.path]);

    final db = sqlite3.open(databaseFile.path);
    try {
      final thumbnailPath =
          db.select('SELECT ThumbnailPath FROM Music WHERE Path = ?', [
                songFile.path,
              ]).single['ThumbnailPath']
              as String;
      expect(thumbnailPath, isNotEmpty);
      expect(File(thumbnailPath).existsSync(), isTrue);
      expect(File(thumbnailPath).readAsBytesSync(), _pngBytes);
    } finally {
      db.dispose();
    }
  });

  test('external audio import falls back to shell thumbnail', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smplayer-shell-thumbnail-',
    );
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final songFile = File('${directory.path}/NoArtwork.mp3');
    await songFile.writeAsBytes([0xff, 0xfb, 0x90, 0x64]);

    final databaseFile = File('${directory.path}/SMPlayerSettings.db');
    _createScanDatabase(databaseFile, '${directory.path}/Hidden');
    final requestedPaths = <String>[];
    final repository = LibraryRepository(
      databaseFileResolver: () async => databaseFile,
      shellThumbnailResolver: (filePath) async {
        requestedPaths.add(filePath);
        return const ShellThumbnail(data: _pngBytes, extension: '.png');
      },
    );

    await repository.importExternalAudioFiles([songFile.path]);

    final db = sqlite3.open(databaseFile.path);
    try {
      final thumbnailPath =
          db.select('SELECT ThumbnailPath FROM Music WHERE Path = ?', [
                songFile.path,
              ]).single['ThumbnailPath']
              as String;
      expect(requestedPaths, [songFile.path]);
      expect(thumbnailPath, isNotEmpty);
      expect(File(thumbnailPath).existsSync(), isTrue);
      expect(File(thumbnailPath).readAsBytesSync(), _pngBytes);
    } finally {
      db.dispose();
    }
  });

  test(
    'batch lyrics records Electron-style details and backup stats',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smplayer-batch-lyrics-',
      );
      addTearDown(() async {
        await directory.delete(recursive: true);
      });
      final oldSong = File('${directory.path}/Old.mp3')
        ..writeAsBytesSync(const []);
      final newSong = File('${directory.path}/New.mp3')
        ..writeAsBytesSync(const []);
      final oldLyrics = File('${directory.path}/Old.lrc')
        ..writeAsStringSync('[00:01.00]Old line');
      final databaseFile = File('${directory.path}/SMPlayerSettings.db');
      _createBatchLyricsDatabase(databaseFile, [oldSong.path, newSong.path]);
      final repository = LibraryRepository(
        databaseFileResolver: () async => databaseFile,
        internetLyricsResolver:
            (song) async =>
                song.title == 'Old'
                    ? '[00:01.00]New old line'
                    : '[00:02.00]New line',
      );

      final result = await repository.batchAddInternetLyrics(overwrite: true);

      expect(result.saved, 1);
      expect(result.overwritten, 1);
      expect(result.backedUp, 1);
      expect(result.backupBytes, '[00:01.00]Old line'.length);
      expect(oldLyrics.readAsStringSync(), '[00:01.00]New old line');

      final overwritten = result.details.singleWhere(
        (detail) => detail.result == LyricsBatchDetailResult.overwritten,
      );
      expect(overwritten.title, 'Old');
      expect(overwritten.sourceRawLyrics, '[00:01.00]Old line');
      expect(overwritten.targetRawLyrics, '[00:01.00]New old line');

      final saved = result.details.singleWhere(
        (detail) => detail.result == LyricsBatchDetailResult.saved,
      );
      expect(saved.title, 'New');
      expect(saved.targetRawLyrics, '[00:02.00]New line');
    },
  );

  test(
    'preference settings repository mirrors Electron service operations',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smplayer-preferences-',
      );
      addTearDown(() async {
        await directory.delete(recursive: true);
      });
      final databaseFile = File('${directory.path}/SMPlayerSettings.db');
      _createPreferenceDatabase(databaseFile);

      final repository = LibraryRepository(
        databaseFileResolver: () async => databaseFile,
      );

      final initial = await repository.getPreferenceSettings();
      expect(initial.enabled[PreferenceSectionKey.songs], isTrue);
      expect(initial.enabled[PreferenceSectionKey.artists], isFalse);
      expect(initial.songs.single.name, 'Track');
      expect(initial.songs.single.tooltip, r'C:\Music\Track.mp3');
      expect(initial.songs.single.level, PreferenceLevel.high);
      expect(
        initial.artists.map((item) => item.name),
        containsAll(['Artist', 'Ghost']),
      );
      expect(
        initial.artists.singleWhere((item) => item.name == 'Ghost').isValid,
        isFalse,
      );
      expect(initial.folders.single.name, 'Album');
      expect(
        initial.others.map((item) => item.type),
        contains(PreferenceEntityType.recentAdded),
      );

      await repository.updatePreferenceSettings({
        PreferenceSectionKey.songs: false,
        PreferenceSectionKey.artists: true,
      });
      await repository.updatePreferenceItem(
        initial.songs.single.id,
        isEnabled: false,
        level: PreferenceLevel.veryHigh,
      );
      await repository.clearInvalidPreferenceItems(PreferenceEntityType.artist);
      await repository.removePreferenceItemById(initial.folders.single.id);

      final updated = await repository.getPreferenceSettings();
      expect(updated.enabled[PreferenceSectionKey.songs], isFalse);
      expect(updated.enabled[PreferenceSectionKey.artists], isTrue);
      expect(updated.songs.single.isEnabled, isFalse);
      expect(updated.songs.single.level, PreferenceLevel.veryHigh);
      expect(updated.artists.map((item) => item.name), ['Artist']);
      expect(updated.folders, isEmpty);
    },
  );

  test(
    'settings repository mirrors Electron Settings service fields',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smplayer-settings-',
      );
      addTearDown(() async {
        await directory.delete(recursive: true);
      });
      final databaseFile = File('${directory.path}/SMPlayerSettings.db');
      _createSettingsDatabase(databaseFile);
      final setupDb = sqlite3.open(databaseFile.path);
      try {
        setupDb.execute(
          'UPDATE Settings SET MyFavorites = 7, LastPlaylist = 42',
        );
        setupDb.execute('''
          CREATE TABLE Playlist (
            Id INTEGER PRIMARY KEY,
            Name TEXT,
            State INTEGER
          )
        ''');
        setupDb.execute(
          'INSERT INTO Playlist (Id, Name, State) VALUES (?, ?, ?)',
          [7, 'My Favorites', 1],
        );
      } finally {
        setupDb.dispose();
      }
      final repository = LibraryRepository(
        databaseFileResolver: () async => databaseFile,
      );

      final snapshot = await repository.getSettingsSnapshot();

      expect(snapshot!.rootPath, r'C:\Music');
      expect(snapshot.notificationSend, NotificationSendMode.musicChanged);
      expect(snapshot.showNotifications, isTrue);
      expect(snapshot.showLyricsInNotification, isTrue);
      expect(snapshot.notificationLyricsSource, LyricsRequestMode.local);
      expect(snapshot.lastMusicIndex, 7);
      expect(snapshot.volume, 35);
      expect(snapshot.mode, PlaybackMode.repeat);
      expect(snapshot.lastPage, '/local');
      expect(snapshot.lastPlaylistId, 7);

      await repository.updateSettings(
        const AppSettingsUpdate(
          notificationSend: NotificationSendMode.never,
          showNotifications: false,
          showLyricsInNotification: false,
          desktopLyricsEnabled: true,
          saveMusicProgress: false,
        ),
      );
      await repository.savePlaybackSettings(
        const PlaybackSettingsUpdate(
          lastMusicIndex: 3,
          volume: 72,
          isMuted: true,
          mode: PlaybackMode.shuffle,
          musicProgress: 44,
        ),
      );
      await repository.updateSongDuration(1, 188);
      await repository.saveViewState(lastPage: '/settings', lastPlaylistId: 42);

      final db = sqlite3.open(databaseFile.path);
      try {
        final row = db.select('SELECT * FROM Settings').single;
        expect(row['NotificationSend'], 0);
        expect(row['ShowLyricsInNotification'], 0);
        expect(row['DesktopLyricsEnabled'], 1);
        expect(row['SaveMusicProgress'], 0);
        expect(row['MusicProgress'], 0);
        expect(row['LastMusicIndex'], 3);
        expect(row['Volume'], 72);
        expect(row['IsMuted'], 1);
        expect(row['Mode'], 3);
        expect(row['LastPage'], '/settings');
        expect(row['LastPlaylist'], 42);
        final musicRow =
            db.select('SELECT Duration FROM Music WHERE Id = 1').single;
        expect(musicRow['Duration'], 188);
      } finally {
        db.dispose();
      }
    },
  );
}

void _createPlayedSongDatabase(File databaseFile) {
  final db = sqlite3.open(databaseFile.path);
  try {
    db.execute('''
      CREATE TABLE Music (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL UNIQUE,
        Name TEXT,
        Artist TEXT,
        Album TEXT,
        ThumbnailPath TEXT DEFAULT '',
        Duration INTEGER DEFAULT 0,
        PlayCount INTEGER DEFAULT 0,
        DateAdded TEXT DEFAULT '',
        LyricsOffsetMs INTEGER DEFAULT 0,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE RecentRecord (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Type INTEGER,
        ItemId TEXT,
        Time TEXT DEFAULT '',
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      INSERT INTO Music (
        Path, Name, Artist, Album, ThumbnailPath, Duration,
        PlayCount, DateAdded, LyricsOffsetMs, State
      )
      VALUES ('/music/song.mp3', 'Song', '', '', '', 0, 2, '', 0, 1)
    ''');
    db.execute(
      'INSERT INTO RecentRecord (Type, ItemId, Time, State) VALUES (0, ?, ?, 1)',
      ['1', '2026-05-20T00:00:00.000Z'],
    );
  } finally {
    db.dispose();
  }
}

void _writeCandidateMusicDatabase(File file, List<String> songPaths) {
  final db = sqlite3.open(file.path);
  try {
    db.execute(
      'CREATE TABLE Music (Id INTEGER PRIMARY KEY, Path TEXT, State INTEGER)',
    );
    for (final (index, songPath) in songPaths.indexed) {
      db.execute('INSERT INTO Music (Id, Path, State) VALUES (?, ?, 1)', [
        index + 1,
        songPath,
      ]);
    }
  } finally {
    db.dispose();
  }
}

void _createImportDatabase(
  File databaseFile, {
  required String rootPath,
  required String songPath,
}) {
  final db = sqlite3.open(databaseFile.path);
  try {
    db.execute('''
      CREATE TABLE Settings (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        RootPath TEXT DEFAULT ''
      )
    ''');
    db.execute('INSERT INTO Settings (RootPath) VALUES (?)', [rootPath]);
    db.execute('''
      CREATE TABLE Music (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL UNIQUE,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('INSERT INTO Music (Path, State) VALUES (?, 1)', [songPath]);
    db.execute('''
      CREATE TABLE Folder (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL UNIQUE,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('INSERT INTO Folder (Path, State) VALUES (?, 1)', [rootPath]);
    db.execute('INSERT INTO Folder (Path, State) VALUES (?, 1)', [
      '$rootPath/Album',
    ]);
    db.execute('''
      CREATE TABLE File (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL UNIQUE,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('INSERT INTO File (Path, State) VALUES (?, 1)', [songPath]);
    db.execute('''
      CREATE TABLE HiddenStorageItem (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Type TEXT,
        Path TEXT,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute(
      'INSERT INTO HiddenStorageItem (Type, Path, State) VALUES (?, ?, 1)',
      ['folder', '$rootPath/Hidden'],
    );
  } finally {
    db.dispose();
  }
}

void _setImportRootPath(File databaseFile, String rootPath) {
  final db = sqlite3.open(databaseFile.path);
  try {
    db.execute('UPDATE Settings SET RootPath = ?', [rootPath]);
  } finally {
    db.dispose();
  }
}

void _createScanDatabase(
  File databaseFile,
  String hiddenFolderPath, {
  bool autoLyrics = false,
  bool useFilenameNotMusicName = false,
  bool smartMultiArtistRecognition = true,
}) {
  final db = sqlite3.open(databaseFile.path);
  try {
    db.execute('''
      CREATE TABLE Settings (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        RootPath TEXT DEFAULT '',
        MusicLibraryCriterion INTEGER DEFAULT 0,
        AlbumsCriterion INTEGER DEFAULT -1,
        MyFavorites INTEGER DEFAULT 0,
        NowPlaying INTEGER DEFAULT 0,
        ShowCount INTEGER DEFAULT 1,
        HideMultiSelectCommandBarAfterOperation INTEGER DEFAULT 1,
        LocalViewMode INTEGER DEFAULT 0,
        AutoLyrics INTEGER DEFAULT 0,
        UseFilenameNotMusicName INTEGER DEFAULT 0,
        SmartMultiArtistRecognition INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE Music (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL UNIQUE,
        Name TEXT,
        Artist TEXT,
        Album TEXT,
        ThumbnailPath TEXT DEFAULT '',
        Duration INTEGER DEFAULT 0,
        PlayCount INTEGER DEFAULT 0,
        DateAdded TEXT DEFAULT '',
        LyricsOffsetMs INTEGER DEFAULT 0,
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
    db.execute('''
      CREATE TABLE Folder (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL UNIQUE,
        Criterion INTEGER DEFAULT 0,
        ParentId INTEGER DEFAULT 0,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE File (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL UNIQUE,
        ParentId INTEGER DEFAULT 0,
        FileId INTEGER DEFAULT 0,
        FileType INTEGER DEFAULT 0,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE HiddenStorageItem (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Type TEXT,
        Path TEXT,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE PlaylistItem (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        PlaylistId INTEGER,
        ItemId INTEGER,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute(
      '''
      INSERT INTO Settings (
        RootPath, AutoLyrics, UseFilenameNotMusicName,
        SmartMultiArtistRecognition
      )
      VALUES (?, ?, ?, ?)
    ''',
      [
        '',
        autoLyrics ? 1 : 0,
        useFilenameNotMusicName ? 1 : 0,
        smartMultiArtistRecognition ? 1 : 0,
      ],
    );
    db.execute(
      '''
      INSERT INTO Music (
        Path, Name, Artist, Album, ThumbnailPath, Duration,
        PlayCount, DateAdded, LyricsOffsetMs, State
      )
      VALUES (?, ?, ?, ?, '', 0, 5, ?, 0, 1)
    ''',
      [r'C:\Old\Missing.mp3', 'Missing', '', '', '2026-05-20'],
    );
    db.execute('INSERT INTO File (Path, FileId, State) VALUES (?, 1, 1)', [
      r'C:\Old\Missing.mp3',
    ]);
    db.execute(
      'INSERT INTO HiddenStorageItem (Type, Path, State) VALUES (?, ?, 1)',
      ['folder', hiddenFolderPath],
    );
  } finally {
    db.dispose();
  }
}

void _createLocalMoveDatabase({
  required File databaseFile,
  required String sourceFolderPath,
  required String targetFolderPath,
  required String songPath,
}) {
  final db = sqlite3.open(databaseFile.path);
  try {
    db.execute('''
      CREATE TABLE Music (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL UNIQUE,
        Name TEXT,
        Artist TEXT,
        Album TEXT,
        ThumbnailPath TEXT DEFAULT '',
        Duration INTEGER DEFAULT 0,
        PlayCount INTEGER DEFAULT 0,
        DateAdded TEXT DEFAULT '',
        LyricsOffsetMs INTEGER DEFAULT 0,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE Folder (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL UNIQUE,
        Criterion INTEGER DEFAULT 0,
        ParentId INTEGER DEFAULT 0,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE File (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL UNIQUE,
        ParentId INTEGER DEFAULT 0,
        FileId INTEGER DEFAULT 0,
        FileType INTEGER DEFAULT 0,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE HiddenStorageItem (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Type TEXT,
        Path TEXT,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('INSERT INTO Folder (Path, ParentId, State) VALUES (?, 0, 1)', [
      sourceFolderPath,
    ]);
    db.execute('INSERT INTO Folder (Path, ParentId, State) VALUES (?, 0, 1)', [
      targetFolderPath,
    ]);
    db.execute(
      '''
      INSERT INTO Music (
        Path, Name, Artist, Album, ThumbnailPath, Duration,
        PlayCount, DateAdded, LyricsOffsetMs, State
      )
      VALUES (?, 'Song', '', '', '', 0, 0, '', 0, 1)
    ''',
      [songPath],
    );
    db.execute(
      'INSERT INTO File (Path, ParentId, FileId, State) VALUES (?, 1, 1, 1)',
      [songPath],
    );
  } finally {
    db.dispose();
  }
}

void _addLocalFolder(
  File databaseFile,
  String folderPath, {
  required int parentId,
}) {
  final db = sqlite3.open(databaseFile.path);
  try {
    db.execute('INSERT INTO Folder (Path, ParentId, State) VALUES (?, ?, 1)', [
      folderPath,
      parentId,
    ]);
  } finally {
    db.dispose();
  }
}

void _addLocalSong(
  File databaseFile,
  String songPath, {
  required int parentId,
}) {
  final db = sqlite3.open(databaseFile.path);
  try {
    db.execute(
      '''
      INSERT INTO Music (
        Path, Name, Artist, Album, ThumbnailPath, Duration,
        PlayCount, DateAdded, LyricsOffsetMs, State
      )
      VALUES (?, 'Song', '', '', '', 0, 0, '', 0, 1)
    ''',
      [songPath],
    );
    final songId = db.select('SELECT last_insert_rowid() AS id').single['id'];
    db.execute(
      'INSERT INTO File (Path, ParentId, FileId, State) VALUES (?, ?, ?, 1)',
      [songPath, parentId, songId],
    );
  } finally {
    db.dispose();
  }
}

void _createLyricsModeDatabase(File databaseFile, String songPath) {
  final db = sqlite3.open(databaseFile.path);
  try {
    db.execute('''
      CREATE TABLE Settings (
        PreserveInternetLyricsTimestamps INTEGER DEFAULT 1
      )
    ''');
    db.execute(
      'INSERT INTO Settings (PreserveInternetLyricsTimestamps) VALUES (1)',
    );
    db.execute('''
      CREATE TABLE Music (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL,
        Name TEXT,
        Artist TEXT,
        Album TEXT,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute(
      '''
      INSERT INTO Music (Path, Name, Artist, Album, State)
      VALUES (?, 'Mode', 'Artist', 'Album', 1)
    ''',
      [songPath],
    );
  } finally {
    db.dispose();
  }
}

String _readMusicPath(File databaseFile, int songId) {
  final db = sqlite3.open(databaseFile.path);
  try {
    return db.select('SELECT Path FROM Music WHERE Id = ?', [
          songId,
        ]).single['Path']
        as String;
  } finally {
    db.dispose();
  }
}

List<int> _id3v24TextTag(Map<String, String> values) {
  final frames =
      values.entries.expand((entry) {
        final payload = [3, ...utf8.encode(entry.value)];
        return [
          ...ascii.encode(entry.key),
          ..._synchsafeBytes(payload.length),
          0,
          0,
          ...payload,
        ];
      }).toList();
  return [
    ...ascii.encode('ID3'),
    4,
    0,
    0,
    ..._synchsafeBytes(frames.length),
    ...frames,
  ];
}

List<int> _synchsafeBytes(int value) {
  return [
    (value >> 21) & 0x7f,
    (value >> 14) & 0x7f,
    (value >> 7) & 0x7f,
    value & 0x7f,
  ];
}

void _createPendingDeleteDatabase(
  File databaseFile,
  String songPath, {
  String? folderPath,
}) {
  final db = sqlite3.open(databaseFile.path);
  try {
    db.execute('''
      CREATE TABLE Music (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL UNIQUE,
        Name TEXT,
        Artist TEXT,
        Album TEXT,
        ThumbnailPath TEXT DEFAULT '',
        Duration INTEGER DEFAULT 0,
        PlayCount INTEGER DEFAULT 0,
        DateAdded TEXT DEFAULT '',
        LyricsOffsetMs INTEGER DEFAULT 0,
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
    db.execute('''
      CREATE TABLE PlaylistItem (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        PlaylistId INTEGER,
        ItemId INTEGER,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE RecentRecord (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Type INTEGER,
        ItemId TEXT,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE HiddenStorageItem (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Type TEXT,
        Path TEXT,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE Folder (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL UNIQUE,
        Criterion INTEGER DEFAULT 0,
        ParentId INTEGER DEFAULT 0,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE File (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL UNIQUE,
        ParentId INTEGER DEFAULT 0,
        FileId INTEGER DEFAULT 0,
        FileType INTEGER DEFAULT 0,
        State INTEGER DEFAULT 1
      )
    ''');
    if (folderPath != null) {
      db.execute('INSERT INTO Folder (Path, State) VALUES (?, 1)', [
        folderPath,
      ]);
    }
    db.execute(
      '''
      INSERT INTO Music (
        Path, Name, Artist, Album, ThumbnailPath, Duration,
        PlayCount, DateAdded, LyricsOffsetMs, State
      )
      VALUES (?, 'Song', '', '', '', 0, 0, '', 0, 1)
    ''',
      [songPath],
    );
    db.execute('INSERT INTO File (Path, FileId, State) VALUES (?, 1, 1)', [
      songPath,
    ]);
  } finally {
    db.dispose();
  }
}

void _createBatchLyricsDatabase(File databaseFile, List<String> songPaths) {
  final db = sqlite3.open(databaseFile.path);
  try {
    db.execute('''
      CREATE TABLE Settings (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        RootPath TEXT DEFAULT '',
        MusicLibraryCriterion INTEGER DEFAULT 0,
        AlbumsCriterion INTEGER DEFAULT -1,
        MyFavorites INTEGER DEFAULT 0,
        NowPlaying INTEGER DEFAULT 0,
        ShowCount INTEGER DEFAULT 1,
        HideMultiSelectCommandBarAfterOperation INTEGER DEFAULT 1,
        LocalViewMode INTEGER DEFAULT 0,
        UseFilenameNotMusicName INTEGER DEFAULT 0,
        SmartMultiArtistRecognition INTEGER DEFAULT 1
      )
    ''');
    db.execute('INSERT INTO Settings (RootPath) VALUES (?)', [
      p.dirname(songPaths.first),
    ]);
    db.execute('''
      CREATE TABLE Music (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL UNIQUE,
        Name TEXT,
        Artist TEXT,
        Album TEXT,
        ThumbnailPath TEXT DEFAULT '',
        Duration INTEGER DEFAULT 0,
        PlayCount INTEGER DEFAULT 0,
        DateAdded TEXT DEFAULT '',
        LyricsOffsetMs INTEGER DEFAULT 0,
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
    db.execute('''
      CREATE TABLE Folder (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Path TEXT NOT NULL UNIQUE,
        Criterion INTEGER DEFAULT 0,
        ParentId INTEGER DEFAULT 0,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE Playlist (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Name TEXT,
        Criterion INTEGER DEFAULT 0,
        Priority INTEGER DEFAULT 0,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE PlaylistItem (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        PlaylistId INTEGER,
        ItemId INTEGER,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE RecentRecord (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Type INTEGER,
        ItemId TEXT,
        Time TEXT DEFAULT '',
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('''
      CREATE TABLE SearchHistory (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Query TEXT,
        Type TEXT,
        SearchedAt TEXT
      )
    ''');
    for (final (index, songPath) in songPaths.indexed) {
      final title = p.basenameWithoutExtension(songPath);
      db.execute(
        '''
        INSERT INTO Music (
          Path, Name, Artist, Album, ThumbnailPath, Duration,
          PlayCount, DateAdded, LyricsOffsetMs, State
        )
        VALUES (?, ?, 'Artist', 'Album', '', 0, 0, '', 0, 1)
      ''',
        [songPath, title],
      );
      db.execute(
        'INSERT INTO MusicArtist (MusicId, Name, Priority, State) VALUES (?, ?, 0, 1)',
        [index + 1, 'Artist'],
      );
    }
  } finally {
    db.dispose();
  }
}

int _readMusicState(File databaseFile, int songId) {
  final db = sqlite3.open(databaseFile.path);
  try {
    return db.select('SELECT State FROM Music WHERE Id = ?', [
          songId,
        ]).single['State']
        as int;
  } finally {
    db.dispose();
  }
}

int _readFolderState(File databaseFile, String folderPath) {
  final db = sqlite3.open(databaseFile.path);
  try {
    return db.select('SELECT State FROM Folder WHERE Path = ?', [
          folderPath,
        ]).single['State']
        as int;
  } finally {
    db.dispose();
  }
}

int _readFileState(File databaseFile, String filePath) {
  final db = sqlite3.open(databaseFile.path);
  try {
    return db.select('SELECT State FROM File WHERE Path = ?', [
          filePath,
        ]).single['State']
        as int;
  } finally {
    db.dispose();
  }
}

void _createPreferenceDatabase(File databaseFile) {
  final db = sqlite3.open(databaseFile.path);
  try {
    db.execute('''
      CREATE TABLE PreferenceSetting (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Songs INTEGER DEFAULT 0,
        Artists INTEGER DEFAULT 0,
        Albums INTEGER DEFAULT 0,
        Playlists INTEGER DEFAULT 0,
        Folders INTEGER DEFAULT 0,
        RecentAddedId INTEGER DEFAULT 0,
        MyFavoritesId INTEGER DEFAULT 0,
        MostPlayedId INTEGER DEFAULT 0,
        LeastPlayedId INTEGER DEFAULT 0
      )
    ''');
    db.execute('''
      CREATE TABLE PreferenceItem (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Type INTEGER,
        ItemId TEXT,
        ItemName TEXT,
        IsEnabled INTEGER,
        Level INTEGER,
        State INTEGER
      )
    ''');
    db.execute('''
      CREATE TABLE Music (
        Id INTEGER PRIMARY KEY,
        Name TEXT,
        Path TEXT,
        Album TEXT,
        State INTEGER
      )
    ''');
    db.execute('''
      CREATE TABLE MusicArtist (
        MusicId INTEGER,
        Name TEXT,
        Priority INTEGER,
        State INTEGER
      )
    ''');
    db.execute('''
      CREATE TABLE Playlist (
        Id INTEGER PRIMARY KEY,
        Name TEXT,
        State INTEGER
      )
    ''');
    db.execute('''
      CREATE TABLE Folder (
        Id INTEGER PRIMARY KEY,
        Path TEXT,
        State INTEGER
      )
    ''');
    db.execute('''
      INSERT INTO PreferenceSetting (Songs, Artists, Albums, Playlists, Folders)
      VALUES (1, 0, 1, 0, 1)
    ''');
    db.execute(
      'INSERT INTO Music (Id, Name, Path, Album, State) VALUES (?, ?, ?, ?, ?)',
      [10, 'Track', r'C:\Music\Track.mp3', 'Album', 1],
    );
    db.execute(
      'INSERT INTO MusicArtist (MusicId, Name, Priority, State) VALUES (?, ?, ?, ?)',
      [10, 'Artist', 0, 1],
    );
    db.execute('INSERT INTO Folder (Id, Path, State) VALUES (?, ?, ?)', [
      20,
      r'C:\Music\Album',
      1,
    ]);
    db.execute(
      'INSERT INTO PreferenceItem (Type, ItemId, ItemName, IsEnabled, Level, State) VALUES (?, ?, ?, ?, ?, ?)',
      [0, '10', 'Old Track', 1, 2, 1],
    );
    db.execute(
      'INSERT INTO PreferenceItem (Type, ItemId, ItemName, IsEnabled, Level, State) VALUES (?, ?, ?, ?, ?, ?)',
      [1, 'Artist', 'Artist', 1, 1, 1],
    );
    db.execute(
      'INSERT INTO PreferenceItem (Type, ItemId, ItemName, IsEnabled, Level, State) VALUES (?, ?, ?, ?, ?, ?)',
      [1, 'Ghost', 'Ghost', 1, 1, 1],
    );
    db.execute(
      'INSERT INTO PreferenceItem (Type, ItemId, ItemName, IsEnabled, Level, State) VALUES (?, ?, ?, ?, ?, ?)',
      [4, '20', r'C:\Music\Album', 1, 1, 1],
    );
  } finally {
    db.dispose();
  }
}

void _createSettingsDatabase(File databaseFile) {
  final db = sqlite3.open(databaseFile.path);
  try {
    db.execute('''
      CREATE TABLE Settings (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        RootPath TEXT DEFAULT '',
        LastMusicIndex INTEGER DEFAULT -1,
        Mode INTEGER DEFAULT 0,
        Volume REAL DEFAULT 50,
        ThemeColor TEXT DEFAULT '#0078D7',
        NightMode INTEGER DEFAULT 3,
        NightModeStartTime TEXT DEFAULT '20:00',
        NightModeEndTime TEXT DEFAULT '06:00',
        NotificationSend INTEGER DEFAULT 1,
        NotificationDisplay INTEGER DEFAULT 1,
        LastPage TEXT DEFAULT '',
        LastPlaylist INTEGER DEFAULT 0,
        LocalViewMode INTEGER DEFAULT 0,
        MyFavorites INTEGER DEFAULT 0,
        NowPlaying INTEGER DEFAULT 0,
        IsMuted INTEGER DEFAULT 0,
        AutoPlay INTEGER DEFAULT 0,
        ShuffleAfterOneRound INTEGER DEFAULT 1,
        AutoLyrics INTEGER DEFAULT 1,
        SaveMusicProgress INTEGER DEFAULT 1,
        MusicProgress REAL DEFAULT 0,
        MusicLibraryCriterion INTEGER DEFAULT 0,
        AlbumsCriterion INTEGER DEFAULT -1,
        HideMultiSelectCommandBarAfterOperation INTEGER DEFAULT 1,
        ShowCount INTEGER DEFAULT 1,
        ShowLyricsInNotification INTEGER DEFAULT 0,
        VoiceAssistantPreferredLanguage INTEGER DEFAULT 0,
        SearchArtistsCriterion INTEGER DEFAULT -1,
        SearchAlbumsCriterion INTEGER DEFAULT -1,
        SearchSongsCriterion INTEGER DEFAULT -1,
        SearchPlaylistsCriterion INTEGER DEFAULT -1,
        SearchFoldersCriterion INTEGER DEFAULT -1,
        LastReleaseNotesVersion TEXT DEFAULT '',
        UseFilenameNotMusicName INTEGER DEFAULT 0,
        SmartMultiArtistRecognition INTEGER DEFAULT 1,
        NotificationLyricsSource INTEGER DEFAULT 0,
        PlayerLyricsSource INTEGER DEFAULT 3,
        SaveLyricsImmediately INTEGER DEFAULT 0,
        PreserveInternetLyricsTimestamps INTEGER DEFAULT 1,
        DesktopLyricsEnabled INTEGER DEFAULT 0,
        DesktopLyricsLocked INTEGER DEFAULT 0,
        DesktopLyricsColor TEXT DEFAULT '#4aa8ff',
        DesktopLyricsStrokeColor TEXT DEFAULT '#111111',
        DesktopLyricsFontSize INTEGER DEFAULT 28,
        DesktopLyricsFontFamily TEXT DEFAULT 'system',
        DesktopLyricsOpacity INTEGER DEFAULT 88,
        DesktopLyricsBounds TEXT DEFAULT '',
        MainWindowBounds TEXT DEFAULT '',
        MainWindowMaximized INTEGER DEFAULT 0,
        QuitOnClose INTEGER DEFAULT 1
      )
    ''');
    db.execute(
      '''
      INSERT INTO Settings (
        RootPath, LastMusicIndex, Mode, Volume, NotificationSend,
        ShowLyricsInNotification, NotificationLyricsSource, LastPage
      )
      VALUES (?, 7, 1, 35, 1, 1, 1, ?)
    ''',
      [r'C:\Music', '/local'],
    );
    db.execute('''
      CREATE TABLE Music (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Duration INTEGER DEFAULT 0,
        State INTEGER DEFAULT 1
      )
    ''');
    db.execute('INSERT INTO Music (Id, Duration, State) VALUES (1, 0, 1)');
  } finally {
    db.dispose();
  }
}

Future<void> _waitForEmbeddedLyrics(File file, String expected) async {
  const service = Id3TagService();
  for (var attempt = 0; attempt < 20; attempt += 1) {
    final lyrics = await service.readEmbeddedLyrics(file.path);
    if (lyrics == expected) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  expect(await service.readEmbeddedLyrics(file.path), expected);
}

const _pngBytes = [
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
];
