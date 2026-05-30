import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'library_artist_split_service.dart';
import 'library_audio_metadata_service.dart';
import 'library_hidden_storage_service.dart';
import 'library_local_delete_service.dart';
import 'library_local_scan_service.dart';
import 'library_models.dart';
import 'library_read_service.dart';
import 'library_song_properties_service.dart';
import 'library_time_codec.dart';

const _activeState = 1;
const _inactiveState = 0;
const _hiddenState = -1;
const _parentHiddenState = -2;

class LibraryLocalRefreshService {
  const LibraryLocalRefreshService({
    required LibrarySongPropertiesService songPropertiesService,
    required LibraryReadService readService,
    required LibraryHiddenStorageService hiddenStorageService,
    required LibraryAudioMetadataService audioMetadataService,
    required LibraryArtistSplitService artistSplitService,
    required LibraryLocalDeleteService localDeleteService,
  }) : _songPropertiesService = songPropertiesService,
       _readService = readService,
       _hiddenStorageService = hiddenStorageService,
       _audioMetadataService = audioMetadataService,
       _artistSplitService = artistSplitService,
       _localDeleteService = localDeleteService;

  final LibrarySongPropertiesService _songPropertiesService;
  final LibraryReadService _readService;
  final LibraryHiddenStorageService _hiddenStorageService;
  final LibraryAudioMetadataService _audioMetadataService;
  final LibraryArtistSplitService _artistSplitService;
  final LibraryLocalDeleteService _localDeleteService;

  Future<List<int>> importExternalAudioFiles(
    File databaseFile,
    List<String> filePaths, {
    required CacheSongArtwork cacheSongArtwork,
  }) async {
    final audioFiles =
        filePaths.where((filePath) {
          return isScannableAudioFile(filePath) && File(filePath).existsSync();
        }).toList();
    if (audioFiles.isEmpty) {
      return const [];
    }
    final metadataByPath = await _audioMetadataService
        .readAudioFileMetadataBatch(
          audioFiles,
          cacheSongArtwork: cacheSongArtwork,
        );

    final db = sqlite3.open(databaseFile.path);
    final openedSongIds = <int>[];
    try {
      final settings = _readService.readLibrarySettings(db);
      db.execute('BEGIN');
      try {
        for (final filePath in audioFiles) {
          openedSongIds.add(
            upsertExternalAudioFile(
              db,
              filePath,
              metadata: metadataByPath[filePath]!,
              useFilenameNotMusicName: settings.useFilenameNotMusicName,
            ),
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

    return openedSongIds;
  }

  Future<LocalFolderRefreshResult> scanAllMusicLibrary(
    File databaseFile,
    String rootPath, {
    required CacheSongArtwork cacheSongArtwork,
    required bool Function(Database db) readAutoLyricsEnabled,
    required Future<void> Function(List<String> songPaths)
    autoAddInternetLyricsForPaths,
    required Future<void> Function(Database db) pruneArtworkCache,
    void Function(LocalFolderRefreshProgress progress)? onProgress,
    LocalFolderScanCancellation? cancellation,
  }) async {
    final rootDirectory = Directory(rootPath);
    if (!rootDirectory.existsSync()) {
      throw StateError('Folder not found: $rootPath');
    }

    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readService.readLibrarySettings(db);
      final hiddenPaths = _hiddenStorageService.readActiveHiddenStoragePaths(
        db,
      );
      final preparedFolderCount =
          countScannableFolders(rootPath, hiddenPaths.folderPaths) + 1;
      var checkedFolderCount = 0;
      int folderProgressMax() => max(preparedFolderCount, checkedFolderCount);
      final scannedPaths = findScannableAudioFiles(
        rootPath,
        hiddenFolderPaths: hiddenPaths.folderPaths,
        hiddenFilePaths: hiddenPaths.filePaths,
        cancellation: cancellation,
        onFolder: (folderPath) {
          checkedFolderCount += 1;
          onProgress?.call(
            LocalFolderRefreshProgress(
              stage: LocalFolderRefreshStage.checking,
              current: checkedFolderCount,
              total: max(preparedFolderCount, checkedFolderCount),
              currentPath: folderPath,
              checkedFolderCount: checkedFolderCount,
              folderCount: folderProgressMax(),
              canCancel: true,
            ),
          );
        },
      );
      cancellation?.throwIfCanceled();
      final previousSongPaths = readActiveSongPaths(db);
      final scannedPathKeys =
          scannedPaths.map(localScanPathComparisonKey).toSet();
      final previousPathKeys =
          previousSongPaths.map(localScanPathComparisonKey).toSet();
      final movedFiles = detectMovedLocalAudioFiles(
        addedPaths:
            scannedPaths.where((filePath) {
              return !previousPathKeys.contains(
                localScanPathComparisonKey(filePath),
              );
            }).toList(),
        removedPaths:
            previousSongPaths.where((filePath) {
              return !scannedPathKeys.contains(
                localScanPathComparisonKey(filePath),
              );
            }).toList(),
      );
      final movedNewPathKeys =
          movedFiles
              .map((file) => localScanPathComparisonKey(file.newPath))
              .toSet();
      final movedOldPathKeys =
          movedFiles
              .map((file) => localScanPathComparisonKey(file.oldPath))
              .toSet();
      final addedPaths =
          scannedPaths
              .where(
                (filePath) =>
                    !previousPathKeys.contains(
                      localScanPathComparisonKey(filePath),
                    ) &&
                    !movedNewPathKeys.contains(
                      localScanPathComparisonKey(filePath),
                    ),
              )
              .toList();
      final addedPathKeys = addedPaths.map(localScanPathComparisonKey).toSet();
      final removedPaths =
          previousSongPaths
              .where(
                (filePath) =>
                    !scannedPathKeys.contains(
                      localScanPathComparisonKey(filePath),
                    ) &&
                    !movedOldPathKeys.contains(
                      localScanPathComparisonKey(filePath),
                    ),
              )
              .toList();
      final readTotal = max(scannedPaths.length, 1);
      var readAddedCount = 0;
      onProgress?.call(
        LocalFolderRefreshProgress(
          stage: LocalFolderRefreshStage.reading,
          current: 0,
          total: readTotal,
          currentPath: '',
          checkedFolderCount: checkedFolderCount,
          folderCount: folderProgressMax(),
          songCount: scannedPaths.length,
          updatedCount: movedFiles.length,
          missingCount: removedPaths.length,
          canCancel: true,
        ),
      );
      final metadataByPath = await _audioMetadataService
          .readAudioFileMetadataBatch(
            scannedPaths,
            cacheSongArtwork: cacheSongArtwork,
            cancellation: cancellation,
            onProgress: (filePath, completedCount) {
              if (addedPathKeys.contains(
                localScanPathComparisonKey(filePath),
              )) {
                readAddedCount += 1;
              }
              onProgress?.call(
                LocalFolderRefreshProgress(
                  stage: LocalFolderRefreshStage.reading,
                  current: completedCount,
                  total: readTotal,
                  currentPath: filePath,
                  checkedFolderCount: checkedFolderCount,
                  folderCount: folderProgressMax(),
                  processedSongCount: completedCount,
                  songCount: scannedPaths.length,
                  addedCount: readAddedCount,
                  updatedCount: movedFiles.length,
                  missingCount: removedPaths.length,
                  canCancel: true,
                ),
              );
            },
          );
      final folders = nonEmptyScannedFolders(rootPath, scannedPaths);
      final writeTotal = max(scannedPaths.length + 1, 1);
      onProgress?.call(
        LocalFolderRefreshProgress(
          stage: LocalFolderRefreshStage.updating,
          current: 0,
          total: writeTotal,
          currentPath: '',
          checkedFolderCount: checkedFolderCount,
          folderCount: folderProgressMax(),
          songCount: scannedPaths.length,
          addedCount: addedPaths.length,
          updatedCount: movedFiles.length,
          missingCount: removedPaths.length,
        ),
      );
      cancellation?.throwIfCanceled();

      db.execute('BEGIN');
      try {
        markScannedTablesInactive(db);
        final folderIds = upsertScannedFolders(db, rootPath, folders);
        for (final entry in scannedPaths.indexed) {
          final writtenCount = entry.$1 + 1;
          onProgress?.call(
            LocalFolderRefreshProgress(
              current: writtenCount,
              total: writeTotal,
              currentPath: entry.$2,
              stage: LocalFolderRefreshStage.updating,
              checkedFolderCount: checkedFolderCount,
              folderCount: folderProgressMax(),
              processedSongCount: writtenCount,
              songCount: scannedPaths.length,
              addedCount: addedPaths.length,
              updatedCount: movedFiles.length,
              missingCount: removedPaths.length,
            ),
          );
          upsertScannedAudioFile(
            db,
            entry.$2,
            folderIds,
            metadata: metadataByPath[entry.$2]!,
            useFilenameNotMusicName: settings.useFilenameNotMusicName,
          );
        }
        setRootPath(db, rootPath);

        final artistAnalysis =
            settings.smartMultiArtistRecognition
                ? _artistSplitService.analyze(_readService.readSongs(db))
                : _artistSplitService.emptyAnalysis();
        _artistSplitService.applySplitsInsideTransaction(
          db,
          artistAnalysis.directSplits,
        );
        onProgress?.call(
          LocalFolderRefreshProgress(
            stage: LocalFolderRefreshStage.updating,
            current: writeTotal,
            total: writeTotal,
            currentPath: '',
            checkedFolderCount: checkedFolderCount,
            folderCount: folderProgressMax(),
            processedSongCount: scannedPaths.length,
            songCount: scannedPaths.length,
            addedCount: addedPaths.length,
            updatedCount: movedFiles.length,
            missingCount: removedPaths.length,
          ),
        );

        final autoLyricsEnabled = readAutoLyricsEnabled(db);
        final autoLyricsPaths = addedPaths.toList();
        db.execute('COMMIT');
        if (autoLyricsEnabled) {
          unawaited(
            autoAddInternetLyricsForPaths(autoLyricsPaths).catchError((_) {}),
          );
        }
        await pruneArtworkCache(db);
        return LocalFolderRefreshResult(
          filesAdded: addedPaths,
          filesRemoved: removedPaths,
          filesMoved: movedFiles.map((file) => file.newPath).toList(),
          artistSplitsApplied: artistAnalysis.directSplits,
          artistSplitSuggestions: artistAnalysis.possibleSplits,
          artistMergeSuggestions: artistAnalysis.mergeSuggestions,
        );
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<LocalFolderRefreshResult> refreshLocalFolder(
    File databaseFile,
    String folderPath, {
    required CacheSongArtwork cacheSongArtwork,
    required bool Function(Database db) readAutoLyricsEnabled,
    required Future<void> Function(List<String> songPaths)
    autoAddInternetLyricsForPaths,
    required Future<void> Function(Database db) pruneArtworkCache,
    void Function(LocalFolderRefreshProgress progress)? onProgress,
    LocalFolderScanCancellation? cancellation,
  }) async {
    final db = sqlite3.open(databaseFile.path);
    try {
      final settings = _readService.readLibrarySettings(db);
      final hiddenPaths = _hiddenStorageService.readActiveHiddenStoragePaths(
        db,
      );
      final preparedFolderCount =
          countScannableFolders(folderPath, hiddenPaths.folderPaths) + 1;
      var checkedFolderCount = 0;
      int folderProgressMax() => max(preparedFolderCount, checkedFolderCount);
      final scannedPaths = findScannableAudioFiles(
        folderPath,
        hiddenFolderPaths: hiddenPaths.folderPaths,
        hiddenFilePaths: hiddenPaths.filePaths,
        cancellation: cancellation,
        onFolder: (folderPath) {
          checkedFolderCount += 1;
          onProgress?.call(
            LocalFolderRefreshProgress(
              stage: LocalFolderRefreshStage.checking,
              current: checkedFolderCount,
              total: max(preparedFolderCount, checkedFolderCount),
              currentPath: folderPath,
              checkedFolderCount: checkedFolderCount,
              folderCount: folderProgressMax(),
              canCancel: true,
            ),
          );
        },
      );
      cancellation?.throwIfCanceled();
      final scannedPathKeys =
          scannedPaths.map(localScanPathComparisonKey).toSet();
      final existingRows = db.select(
        '''
        SELECT Id AS id, Path AS path
        FROM Music
        WHERE State = ?
          AND (Path = ? OR Path LIKE ? OR Path LIKE ?)
      ''',
        [_activeState, folderPath, '$folderPath/%', '$folderPath\\%'],
      );
      final existingPathKeys = {
        for (final row in existingRows)
          localScanPathComparisonKey(row['path'] as String): row,
      };
      final addedCandidates =
          scannedPaths.where((filePath) {
            return !existingPathKeys.containsKey(
              localScanPathComparisonKey(filePath),
            );
          }).toList();
      final removedCandidates =
          existingRows
              .where((row) {
                return !scannedPathKeys.contains(
                  localScanPathComparisonKey(row['path'] as String),
                );
              })
              .map((row) {
                return _RefreshRemovedSong(
                  id: row['id'] as int,
                  path: row['path'] as String,
                );
              })
              .toList();
      final movedFiles = detectMovedLocalAudioFiles(
        addedPaths: addedCandidates,
        removedPaths: removedCandidates.map((song) => song.path).toList(),
      );
      final movedNewPathKeys =
          movedFiles
              .map((file) => localScanPathComparisonKey(file.newPath))
              .toSet();
      final movedOldPathKeys =
          movedFiles
              .map((file) => localScanPathComparisonKey(file.oldPath))
              .toSet();
      final movedSongs = [
        for (final movedFile in movedFiles)
          RefreshMovedSong(
            id:
                removedCandidates
                    .firstWhere(
                      (song) =>
                          localScanPathComparisonKey(song.path) ==
                          localScanPathComparisonKey(movedFile.oldPath),
                    )
                    .id,
            oldPath: movedFile.oldPath,
            newPath: movedFile.newPath,
          ),
      ];
      final addedPaths =
          addedCandidates
              .where(
                (filePath) =>
                    !movedNewPathKeys.contains(
                      localScanPathComparisonKey(filePath),
                    ),
              )
              .toList();
      final removedSongs =
          removedCandidates
              .where(
                (song) =>
                    !movedOldPathKeys.contains(
                      localScanPathComparisonKey(song.path),
                    ),
              )
              .toList();
      final readTotal = max(addedPaths.length, 1);
      var readAddedCount = 0;
      onProgress?.call(
        LocalFolderRefreshProgress(
          stage: LocalFolderRefreshStage.reading,
          current: 0,
          total: readTotal,
          currentPath: '',
          checkedFolderCount: checkedFolderCount,
          folderCount: folderProgressMax(),
          songCount: addedPaths.length,
          updatedCount: movedFiles.length,
          missingCount: removedSongs.length,
          canCancel: true,
        ),
      );
      final metadataByPath = await _audioMetadataService
          .readAudioFileMetadataBatch(
            addedPaths,
            cacheSongArtwork: cacheSongArtwork,
            cancellation: cancellation,
            onProgress: (filePath, completedCount) {
              readAddedCount += 1;
              onProgress?.call(
                LocalFolderRefreshProgress(
                  stage: LocalFolderRefreshStage.reading,
                  current: completedCount,
                  total: readTotal,
                  currentPath: filePath,
                  checkedFolderCount: checkedFolderCount,
                  folderCount: folderProgressMax(),
                  processedSongCount: completedCount,
                  songCount: addedPaths.length,
                  addedCount: readAddedCount,
                  updatedCount: movedFiles.length,
                  missingCount: removedSongs.length,
                  canCancel: true,
                ),
              );
            },
          );
      final rootPath =
          settings.rootPath.isEmpty ? folderPath : settings.rootPath;
      final folders = nonEmptyScannedFolders(rootPath, scannedPaths);
      final writeTotal = max(addedPaths.length + removedSongs.length + 1, 1);
      onProgress?.call(
        LocalFolderRefreshProgress(
          stage: LocalFolderRefreshStage.updating,
          current: 0,
          total: writeTotal,
          currentPath: '',
          checkedFolderCount: checkedFolderCount,
          folderCount: folderProgressMax(),
          songCount: addedPaths.length,
          addedCount: addedPaths.length,
          updatedCount: movedFiles.length,
          missingCount: removedSongs.length,
        ),
      );
      cancellation?.throwIfCanceled();

      db.execute('BEGIN');
      try {
        markScannedFoldersInactive(db, folderPath);
        for (final movedSong in movedSongs) {
          updateMovedSongPathInsideTransaction(db, movedSong);
        }
        if (removedSongs.isNotEmpty) {
          _localDeleteService.deleteSongsInsideTransaction(
            db,
            removedSongs.map((song) => song.id).toList(),
            removedSongs.map((song) => song.path).toList(),
          );
        }
        final removedProgress = removedSongs.length;
        if (removedProgress > 0) {
          onProgress?.call(
            LocalFolderRefreshProgress(
              stage: LocalFolderRefreshStage.updating,
              current: removedProgress,
              total: writeTotal,
              currentPath: '',
              checkedFolderCount: checkedFolderCount,
              folderCount: folderProgressMax(),
              songCount: addedPaths.length,
              addedCount: addedPaths.length,
              updatedCount: movedFiles.length,
              missingCount: removedSongs.length,
            ),
          );
        }
        final folderIds = upsertScannedFolders(db, rootPath, folders);
        for (final entry in addedPaths.indexed) {
          final writtenCount = entry.$1 + 1;
          onProgress?.call(
            LocalFolderRefreshProgress(
              current: removedProgress + writtenCount,
              total: writeTotal,
              currentPath: entry.$2,
              stage: LocalFolderRefreshStage.updating,
              checkedFolderCount: checkedFolderCount,
              folderCount: folderProgressMax(),
              processedSongCount: writtenCount,
              songCount: addedPaths.length,
              addedCount: addedPaths.length,
              updatedCount: movedFiles.length,
              missingCount: removedSongs.length,
            ),
          );
          upsertScannedAudioFile(
            db,
            entry.$2,
            folderIds,
            metadata: metadataByPath[entry.$2]!,
            useFilenameNotMusicName: settings.useFilenameNotMusicName,
          );
        }

        final artistAnalysis =
            settings.smartMultiArtistRecognition
                ? _artistSplitService.analyze(_readService.readSongs(db))
                : _artistSplitService.emptyAnalysis();
        _artistSplitService.applySplitsInsideTransaction(
          db,
          artistAnalysis.directSplits,
        );
        onProgress?.call(
          LocalFolderRefreshProgress(
            stage: LocalFolderRefreshStage.updating,
            current: writeTotal,
            total: writeTotal,
            currentPath: '',
            checkedFolderCount: checkedFolderCount,
            folderCount: folderProgressMax(),
            processedSongCount: addedPaths.length,
            songCount: addedPaths.length,
            addedCount: addedPaths.length,
            updatedCount: movedFiles.length,
            missingCount: removedSongs.length,
          ),
        );
        final autoLyricsEnabled = readAutoLyricsEnabled(db);
        final autoLyricsPaths = addedPaths.toList();
        db.execute('COMMIT');
        if (autoLyricsEnabled) {
          unawaited(
            autoAddInternetLyricsForPaths(autoLyricsPaths).catchError((_) {}),
          );
        }
        await pruneArtworkCache(db);

        return LocalFolderRefreshResult(
          filesAdded: addedPaths,
          filesRemoved: removedSongs.map((song) => song.path).toList(),
          filesMoved: movedSongs.map((song) => song.newPath).toList(),
          artistSplitsApplied: artistAnalysis.directSplits,
          artistSplitSuggestions: artistAnalysis.possibleSplits,
          artistMergeSuggestions: artistAnalysis.mergeSuggestions,
        );
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }

  Future<void> renameFolder(
    File databaseFile,
    String folderPath,
    String name,
  ) async {
    final targetPath = p.join(p.dirname(folderPath), name);
    await Directory(folderPath).rename(targetPath);

    final db = sqlite3.open(databaseFile.path);
    try {
      db.execute('BEGIN');
      try {
        updatePathPrefixInsideTransaction(
          db,
          table: 'Music',
          oldPath: folderPath,
          newPath: targetPath,
        );
        updatePathPrefixInsideTransaction(
          db,
          table: 'File',
          oldPath: folderPath,
          newPath: targetPath,
        );
        updatePathPrefixInsideTransaction(
          db,
          table: 'Folder',
          oldPath: folderPath,
          newPath: targetPath,
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

  Future<LocalFolderRefreshResult> createLocalFolder(
    String rootPath,
    String relativePath,
    String name, {
    required Future<LocalFolderRefreshResult> Function(
      String folderPath, {
      void Function(LocalFolderRefreshProgress progress)? onProgress,
      LocalFolderScanCancellation? cancellation,
    })
    refreshLocalFolder,
    void Function(LocalFolderRefreshProgress progress)? onProgress,
    LocalFolderScanCancellation? cancellation,
  }) async {
    final parentPath =
        relativePath.isEmpty ? rootPath : p.join(rootPath, relativePath);
    await Directory(p.join(parentPath, name)).create(recursive: true);
    return refreshLocalFolder(
      parentPath,
      onProgress: onProgress,
      cancellation: cancellation,
    );
  }

  List<String> readActiveSongPaths(Database db) {
    return db
        .select(
          '''
          SELECT Path AS path
          FROM Music
          WHERE State = ?
        ''',
          [_activeState],
        )
        .map((row) => row['path'] as String)
        .toList();
  }

  void markScannedTablesInactive(Database db) {
    db.execute(
      '''
      UPDATE Music
      SET State = ?
      WHERE State NOT IN (?, ?)
    ''',
      [_inactiveState, _hiddenState, _parentHiddenState],
    );
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE State NOT IN (?, ?)
    ''',
      [_inactiveState, _hiddenState, _parentHiddenState],
    );
    db.execute(
      '''
      UPDATE File
      SET State = ?
      WHERE State NOT IN (?, ?)
    ''',
      [_inactiveState, _hiddenState, _parentHiddenState],
    );
  }

  void markScannedFoldersInactive(Database db, String folderPath) {
    db.execute(
      '''
      UPDATE Folder
      SET State = ?
      WHERE State NOT IN (?, ?)
        AND (Path = ? OR Path LIKE ? OR Path LIKE ?)
    ''',
      [
        _inactiveState,
        _hiddenState,
        _parentHiddenState,
        folderPath,
        '$folderPath/%',
        '$folderPath\\%',
      ],
    );
  }

  void updateMovedSongPathInsideTransaction(
    Database db,
    RefreshMovedSong movedSong,
  ) {
    db.execute(
      '''
      UPDATE Music
      SET Path = ?
      WHERE Id = ?
        AND State = ?
    ''',
      [movedSong.newPath, movedSong.id, _activeState],
    );
    db.execute(
      '''
      UPDATE File
      SET Path = ?
      WHERE Path = ?
        AND State = ?
    ''',
      [movedSong.newPath, movedSong.oldPath, _activeState],
    );
  }

  void updatePathPrefixInsideTransaction(
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

  int upsertExternalAudioFile(
    Database db,
    String filePath, {
    required AudioFileMetadata metadata,
    bool useFilenameNotMusicName = false,
  }) {
    final properties = metadata.properties;
    final title =
        useFilenameNotMusicName || properties.title.trim().isEmpty
            ? p.basenameWithoutExtension(filePath)
            : properties.title.trim();
    final artists =
        _songPropertiesService
            .normalizeArtists(
              properties.artists.isNotEmpty
                  ? properties.artists
                  : [properties.artist],
            )
            .take(6)
            .toList();
    final artist = artists.join(', ');
    final album = properties.album.trim();
    final dateAdded = LibraryTimeCodec.nowUnixMillisecondsString();
    final rows = db.select(
      '''
      INSERT INTO Music (Path, Name, Artist, Album, ThumbnailPath, Duration, PlayCount, DateAdded, State)
      VALUES (
        ?, ?, ?, ?, ?,
        ?,
        COALESCE((SELECT PlayCount FROM Music WHERE Path = ?), 0),
        COALESCE((SELECT DateAdded FROM Music WHERE Path = ?), ?),
        ?
      )
      ON CONFLICT(Path) DO UPDATE SET
        Name = excluded.Name,
        Artist = excluded.Artist,
        Album = excluded.Album,
        ThumbnailPath = excluded.ThumbnailPath,
        Duration = excluded.Duration,
        State = excluded.State
      RETURNING Id AS id
    ''',
      [
        filePath,
        title,
        artist,
        album,
        metadata.thumbnailPath,
        metadata.duration,
        filePath,
        filePath,
        dateAdded,
        _activeState,
      ],
    );
    final songId = rows.first['id'] as int;
    _songPropertiesService.syncSongArtists(db, songId, artists);
    return songId;
  }

  int upsertScannedAudioFile(
    Database db,
    String filePath,
    Map<String, int> folderIds, {
    required AudioFileMetadata metadata,
    required bool useFilenameNotMusicName,
  }) {
    final songId = upsertExternalAudioFile(
      db,
      filePath,
      metadata: metadata,
      useFilenameNotMusicName: useFilenameNotMusicName,
    );
    final parentId =
        folderIds[localScanPathComparisonKey(p.dirname(filePath))] ?? 0;
    db.select(
      '''
      INSERT INTO File (Path, ParentId, FileId, FileType, State)
      VALUES (?, ?, ?, 0, ?)
      ON CONFLICT(Path) DO UPDATE SET
        ParentId = excluded.ParentId,
        FileId = excluded.FileId,
        State = excluded.State
      RETURNING Id AS id
    ''',
      [filePath, parentId, songId, _activeState],
    );
    return songId;
  }

  Map<String, int> upsertScannedFolders(
    Database db,
    String rootPath,
    List<String> folderPaths,
  ) {
    final folderIds = <String, int>{};
    final sortedFolders =
        folderPaths.toList()..sort(
          (left, right) =>
              localScanPathDepth(left).compareTo(localScanPathDepth(right)),
        );
    final rootKey = localScanPathComparisonKey(rootPath);
    for (final folderPath in sortedFolders) {
      final folderKey = localScanPathComparisonKey(folderPath);
      final parentId =
          folderKey == rootKey
              ? 0
              : folderIds[localScanPathComparisonKey(p.dirname(folderPath))] ??
                  _readActiveFolderId(db, p.dirname(folderPath)) ??
                  0;
      final rows = db.select(
        '''
        INSERT INTO Folder (Path, Criterion, ParentId, State)
        VALUES (?, 0, ?, ?)
        ON CONFLICT(Path) DO UPDATE SET
          ParentId = excluded.ParentId,
          State = excluded.State
        RETURNING Id AS id
      ''',
        [folderPath, parentId, _activeState],
      );
      folderIds[folderKey] = rows.first['id'] as int;
    }
    return folderIds;
  }

  void setRootPath(Database db, String rootPath) {
    db.execute('UPDATE Settings SET RootPath = ?', [rootPath]);
    final changedRows =
        db.select('SELECT changes() AS count').first['count'] as int;
    if (changedRows == 0) {
      db.execute('INSERT INTO Settings (RootPath) VALUES (?)', [rootPath]);
    }
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
}

class RefreshMovedSong {
  const RefreshMovedSong({
    required this.id,
    required this.oldPath,
    required this.newPath,
  });

  final int id;
  final String oldPath;
  final String newPath;
}

class _RefreshRemovedSong {
  const _RefreshRemovedSong({required this.id, required this.path});

  final int id;
  final String path;
}
