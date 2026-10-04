import 'dart:async';
import 'dart:io';
import 'dart:isolate';
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
part 'library_local_folder_refresh.dart';
part 'library_local_scan_write_task.dart';
part 'library_local_import_task.dart';

const _activeState = 1;
const _inactiveState = 0;
const _hiddenState = -1;
const _parentHiddenState = -2;
const _scanWriteBatchSize = 32;

class LibraryLocalRefreshService
    with _LibraryLocalRefreshOperations, _LibraryLocalFolderRefresh {
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
  @override
  final LibraryReadService _readService;
  @override
  final LibraryHiddenStorageService _hiddenStorageService;
  @override
  final LibraryAudioMetadataService _audioMetadataService;
  @override
  final LibraryArtistSplitService _artistSplitService;
  @override
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

    return Isolate.run(
      _ImportLocalAudioTask(this, databaseFile.path, metadataByPath).call,
    );
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
      final previousSongIds = {
        for (final row in db.select(
          'SELECT Id, Path FROM Music WHERE State = 1',
        ))
          row['Path'] as String: row['Id'] as int,
      };
      final previousSongPaths = previousSongIds.keys.toList();
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
      final movedSongs = [
        for (final file in movedFiles)
          RefreshMovedSong(
            id: previousSongIds[file.oldPath]!,
            oldPath: file.oldPath,
            newPath: file.newPath,
          ),
      ];
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
      final changedMetadataPaths = <String>[];
      final metadataByPath = await _audioMetadataService
          .readAudioFileMetadataBatch(
            scannedPaths
                .where(
                  (path) =>
                      !movedNewPathKeys.contains(
                        localScanPathComparisonKey(path),
                      ),
                )
                .toList(),
            cacheSongArtwork: cacheSongArtwork,
            existingMetadataByPath: existingMetadataByPath,
            cancellation: cancellation,
            onMetadataChanged: changedMetadataPaths.add,
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
      addedPaths.removeWhere((path) => !metadataByPath.containsKey(path));
      final folders = nonEmptyScannedFolders(rootPath, scannedPaths);
      final hasDatabaseChanges =
          changedMetadataPaths.isNotEmpty ||
          movedSongs.isNotEmpty ||
          removedPaths.isNotEmpty ||
          settings.rootPath != rootPath;
      cancellation?.throwIfCanceled();
      if (!hasDatabaseChanges) {
        return const LocalFolderRefreshResult(
          libraryChanged: false,
          requiresFullReload: false,
          filesAdded: [],
          filesUpdated: [],
          filesRemoved: [],
          filesMoved: [],
          artistSplitsApplied: [],
          artistSplitSuggestions: [],
          artistMergeSuggestions: [],
        );
      }

      final writePaths = changedMetadataPaths;
      final writeTotal = max(writePaths.length, 1);
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

      final autoLyricsEnabled = readAutoLyricsEnabled(db);
      final writeResult = await _runScanWrite(
        _LibraryScanWriteTask(
          service: this,
          databasePath: databaseFile.path,
          rootPath: rootPath,
          settings: settings,
          scannedPaths: scannedPaths,
          scannedPathKeys: scannedPathKeys,
          writePaths: writePaths,
          metadataByPath: metadataByPath,
          folders: folders,
          movedSongs: movedSongs,
          movedNewPathKeys: movedNewPathKeys,
          addedPaths: addedPaths,
          addedPathKeys: addedPathKeys,
          writeTotal: writeTotal,
          checkedFolderCount: checkedFolderCount,
          folderCount: folderProgressMax(),
          removedPaths: removedPaths,
          movedFiles: movedFiles,
          requiresFullReload:
              addedPaths.isNotEmpty ||
              removedPaths.isNotEmpty ||
              movedSongs.isNotEmpty ||
              settings.rootPath != rootPath,
        ),
        onProgress,
      );
      if (autoLyricsEnabled && addedPaths.isNotEmpty) {
        unawaited(
          autoAddInternetLyricsForPaths(addedPaths.toList()).catchError((_) {}),
        );
      }
      if (writeResult.result.libraryChanged) {
        await pruneArtworkCache(db);
      }
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
          updatedCount: writeResult.updatedCount,
          missingCount: removedPaths.length,
        ),
      );

      return writeResult.result;
    } finally {
      db.dispose();
    }
  }
}
