import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'library_artist_split_service.dart';
import 'library_artist_tag_normalizer.dart' as artist_tags;
import 'library_audio_metadata_service.dart';
import 'library_hidden_storage_service.dart';
import 'library_local_delete_service.dart';
import 'library_local_metadata_cache.dart';
import 'library_local_scan_batch_writer.dart';
import 'library_local_scan_service.dart';
import 'library_models.dart';
import 'library_read_service.dart';
import 'library_song_properties_service.dart';

part 'library_local_refresh_operations.dart';

const _activeState = 1;
const _inactiveState = 0;
const _hiddenState = -1;
const _parentHiddenState = -2;
const _scanWriteBatchSize = 32;

class LibraryLocalRefreshService with _LibraryLocalRefreshOperations {
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

  @override
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
          await countScannableFolders(rootPath, hiddenPaths.folderPaths) + 1;
      var checkedFolderCount = 0;
      int folderProgressMax() => max(preparedFolderCount, checkedFolderCount);
      final scannedPaths = await findScannableAudioFiles(
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
      final storedMetadataByKey = {
        for (final entry in readStoredAudioFileMetadata(db).entries)
          localScanPathComparisonKey(entry.key): entry.value,
      };
      final existingMetadataByPath = {
        for (final filePath in scannedPaths)
          if (storedMetadataByKey[localScanPathComparisonKey(filePath)]
              case final metadata?)
            filePath: metadata,
      };
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
            existingMetadataByPath: existingMetadataByPath,
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
        markScannedTablesInactive(db, scannedPaths.toSet());
        final folderIds = upsertScannedFolders(db, rootPath, folders);
        final scannedSongs = _buildScannedSongs(
          scannedPaths,
          metadataByPath,
          useFilenameNotMusicName: settings.useFilenameNotMusicName,
        );
        final artistAnalysis =
            settings.smartMultiArtistRecognition
                ? _artistSplitService.analyzeScannedLibrary(
                  const <LibrarySong>[],
                  scannedSongs: scannedSongs,
                )
                : _artistSplitService.emptyAnalysis();
        final directSplitsByTempId = {
          for (final split in artistAnalysis.directSplits) split.songId: split,
        };
        final possibleSplitsByTempId = {
          for (final split in artistAnalysis.possibleSplits)
            split.songId: split,
        };
        final mergeSuggestionsByTempId = {
          for (final split in artistAnalysis.mergeSuggestions)
            split.songId: split,
        };
        final appliedSplits = <ArtistSplitResultItem>[];
        final possibleSplits = <ArtistSplitResultItem>[];
        final mergeSuggestions = <ArtistSplitResultItem>[];
        final batchWriter = LibraryLocalScanBatchWriter(db);
        try {
          for (final entry in scannedPaths.indexed) {
            if (entry.$1 > 0 && entry.$1 % _scanWriteBatchSize == 0) {
              await Future<void>.delayed(Duration.zero);
            }
            final writtenCount = entry.$1 + 1;
            final filePath = entry.$2;
            final scannedSong = scannedSongs[entry.$1];
            final mergeSuggestion = mergeSuggestionsByTempId[scannedSong.id];
            final directSplit =
                mergeSuggestion == null
                    ? directSplitsByTempId[scannedSong.id]
                    : null;
            final artists =
                directSplit == null
                    ? scannedSong.artists
                    : _songPropertiesService
                        .normalizeArtists(directSplit.artists)
                        .take(6)
                        .toList();
            final parentId =
                folderIds[localScanPathComparisonKey(p.dirname(filePath))] ?? 0;
            final songId = batchWriter.write(
              filePath: filePath,
              song: scannedSong,
              metadata: metadataByPath[filePath]!,
              parentId: parentId,
              artists: artists,
            );
            if (directSplit != null) {
              appliedSplits.add(_withSongId(directSplit, songId));
            }
            if (mergeSuggestion != null) {
              mergeSuggestions.add(_withSongId(mergeSuggestion, songId));
            }
            final possibleSplit =
                mergeSuggestion == null
                    ? possibleSplitsByTempId[scannedSong.id]
                    : null;
            if (possibleSplit != null) {
              possibleSplits.add(_withSongId(possibleSplit, songId));
            }
            if (writtenCount % _scanWriteBatchSize == 0 ||
                writtenCount == scannedPaths.length) {
              onProgress?.call(
                LocalFolderRefreshProgress(
                  current: writtenCount,
                  total: writeTotal,
                  currentPath: filePath,
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
            }
          }
        } finally {
          batchWriter.dispose();
        }
        setRootPath(db, rootPath);
        final autoLyricsEnabled = readAutoLyricsEnabled(db);
        final autoLyricsPaths = addedPaths.toList();
        db.execute('COMMIT');
        if (autoLyricsEnabled) {
          unawaited(
            autoAddInternetLyricsForPaths(autoLyricsPaths).catchError((_) {}),
          );
        }
        await pruneArtworkCache(db);
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
        return LocalFolderRefreshResult(
          filesAdded: addedPaths,
          filesRemoved: removedPaths,
          filesMoved: movedFiles.map((file) => file.newPath).toList(),
          artistSplitsApplied: appliedSplits,
          artistSplitSuggestions: possibleSplits,
          artistMergeSuggestions: mergeSuggestions,
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
          await countScannableFolders(folderPath, hiddenPaths.folderPaths) + 1;
      var checkedFolderCount = 0;
      int folderProgressMax() => max(preparedFolderCount, checkedFolderCount);
      final scannedPaths = await findScannableAudioFiles(
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
      final storedMetadataByKey = {
        for (final entry
            in readStoredAudioFileMetadata(db, folderPath: folderPath).entries)
          localScanPathComparisonKey(entry.key): entry.value,
      };
      final existingMetadataByPath = {
        for (final filePath in scannedPaths)
          if (storedMetadataByKey[localScanPathComparisonKey(filePath)]
              case final metadata?)
            filePath: metadata,
      };
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
      final addedPathKeys = addedPaths.map(localScanPathComparisonKey).toSet();
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
          missingCount: removedSongs.length,
          canCancel: true,
        ),
      );
      final metadataByPath = await _audioMetadataService
          .readAudioFileMetadataBatch(
            scannedPaths,
            cacheSongArtwork: cacheSongArtwork,
            existingMetadataByPath: existingMetadataByPath,
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
                  missingCount: removedSongs.length,
                  canCancel: true,
                ),
              );
            },
          );
      final rootPath =
          settings.rootPath.isEmpty ? folderPath : settings.rootPath;
      final folders = nonEmptyScannedFolders(rootPath, scannedPaths);
      final writeTotal = max(scannedPaths.length + removedSongs.length + 1, 1);
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
              songCount: scannedPaths.length,
              addedCount: addedPaths.length,
              updatedCount: movedFiles.length,
              missingCount: removedSongs.length,
            ),
          );
        }
        final folderIds = upsertScannedFolders(db, rootPath, folders);
        final scannedSongs = _buildScannedSongs(
          scannedPaths,
          metadataByPath,
          useFilenameNotMusicName: settings.useFilenameNotMusicName,
        );
        final artistAnalysis =
            settings.smartMultiArtistRecognition
                ? _artistSplitService.analyzeScannedLibrary(
                  _readService.readSongs(db),
                  scannedSongs: scannedSongs,
                )
                : _artistSplitService.emptyAnalysis();
        final directSplitsByTempId = {
          for (final split in artistAnalysis.directSplits) split.songId: split,
        };
        final possibleSplitsByTempId = {
          for (final split in artistAnalysis.possibleSplits)
            split.songId: split,
        };
        final mergeSuggestionsByTempId = {
          for (final split in artistAnalysis.mergeSuggestions)
            split.songId: split,
        };
        final appliedSplits = <ArtistSplitResultItem>[];
        final possibleSplits = <ArtistSplitResultItem>[];
        final mergeSuggestions = <ArtistSplitResultItem>[];
        final batchWriter = LibraryLocalScanBatchWriter(db);
        try {
          for (final entry in scannedPaths.indexed) {
            if (entry.$1 > 0 && entry.$1 % _scanWriteBatchSize == 0) {
              await Future<void>.delayed(Duration.zero);
            }
            final writtenCount = entry.$1 + 1;
            final filePath = entry.$2;
            final scannedSong = scannedSongs[entry.$1];
            final mergeSuggestion = mergeSuggestionsByTempId[scannedSong.id];
            final directSplit =
                mergeSuggestion == null
                    ? directSplitsByTempId[scannedSong.id]
                    : null;
            final artists =
                directSplit == null
                    ? scannedSong.artists
                    : _songPropertiesService
                        .normalizeArtists(directSplit.artists)
                        .take(6)
                        .toList();
            final parentId =
                folderIds[localScanPathComparisonKey(p.dirname(filePath))] ?? 0;
            final songId = batchWriter.write(
              filePath: filePath,
              song: scannedSong,
              metadata: metadataByPath[filePath]!,
              parentId: parentId,
              artists: artists,
            );
            if (directSplit != null) {
              appliedSplits.add(_withSongId(directSplit, songId));
            }
            if (mergeSuggestion != null) {
              mergeSuggestions.add(_withSongId(mergeSuggestion, songId));
            }
            final possibleSplit =
                mergeSuggestion == null
                    ? possibleSplitsByTempId[scannedSong.id]
                    : null;
            if (possibleSplit != null) {
              possibleSplits.add(_withSongId(possibleSplit, songId));
            }
            if (writtenCount % _scanWriteBatchSize == 0 ||
                writtenCount == scannedPaths.length) {
              onProgress?.call(
                LocalFolderRefreshProgress(
                  current: removedProgress + writtenCount,
                  total: writeTotal,
                  currentPath: filePath,
                  stage: LocalFolderRefreshStage.updating,
                  checkedFolderCount: checkedFolderCount,
                  folderCount: folderProgressMax(),
                  processedSongCount: writtenCount,
                  songCount: scannedPaths.length,
                  addedCount: addedPaths.length,
                  updatedCount: movedFiles.length,
                  missingCount: removedSongs.length,
                ),
              );
            }
          }
        } finally {
          batchWriter.dispose();
        }
        final autoLyricsEnabled = readAutoLyricsEnabled(db);
        final autoLyricsPaths = addedPaths.toList();
        db.execute('COMMIT');
        if (autoLyricsEnabled) {
          unawaited(
            autoAddInternetLyricsForPaths(autoLyricsPaths).catchError((_) {}),
          );
        }
        await pruneArtworkCache(db);
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
            missingCount: removedSongs.length,
          ),
        );

        return LocalFolderRefreshResult(
          filesAdded: addedPaths,
          filesRemoved: removedSongs.map((song) => song.path).toList(),
          filesMoved: movedSongs.map((song) => song.newPath).toList(),
          artistSplitsApplied: appliedSplits,
          artistSplitSuggestions: possibleSplits,
          artistMergeSuggestions: mergeSuggestions,
        );
      } on Object {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.dispose();
    }
  }
}
