part of 'library_local_refresh_service.dart';

mixin _LibraryLocalFolderRefresh on _LibraryLocalRefreshOperations {
  LibraryReadService get _readService;
  LibraryHiddenStorageService get _hiddenStorageService;
  LibraryAudioMetadataService get _audioMetadataService;
  LibraryArtistSplitService get _artistSplitService;
  LibraryLocalDeleteService get _localDeleteService;

  Future<ArtistSplitAnalysisResult> _analyzeUpdatedFolderArtists(
    Database db,
    Set<int> changedSongIds,
  ) async {
    if (changedSongIds.isEmpty) return _artistSplitService.emptyAnalysis();
    final songs = _readService.readSongs(db);
    return _artistSplitService.analyzeExistingLibrary(
      songs,
      songIds: changedSongIds,
    );
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
                  missingCount: removedSongs.length,
                  canCancel: true,
                ),
              );
            },
          );
      final rootPath =
          settings.rootPath.isEmpty ? folderPath : settings.rootPath;
      addedPaths.removeWhere((path) => !metadataByPath.containsKey(path));
      final folders = nonEmptyScannedFolders(rootPath, scannedPaths);
      final hasDatabaseChanges =
          changedMetadataPaths.isNotEmpty ||
          movedSongs.isNotEmpty ||
          removedSongs.isNotEmpty ||
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
      final writeTotal = max(writePaths.length + removedSongs.length, 1);
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

      final autoLyricsEnabled = readAutoLyricsEnabled(db);
      final writeResult = await _runScanWrite(
        _FolderScanWriteTask(
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
          folderPath: folderPath,
          removedSongs: removedSongs,
          movedFiles: movedFiles,
          requiresFullReload:
              addedPaths.isNotEmpty ||
              removedSongs.isNotEmpty ||
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
          missingCount: removedSongs.length,
        ),
      );

      return writeResult.result;
    } finally {
      db.dispose();
    }
  }
}
