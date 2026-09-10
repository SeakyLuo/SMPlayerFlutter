part of 'library_local_refresh_service.dart';

mixin _LibraryLocalFolderRefresh on _LibraryLocalRefreshOperations {
  LibraryReadService get _readService;
  LibraryHiddenStorageService get _hiddenStorageService;
  LibraryAudioMetadataService get _audioMetadataService;
  LibraryArtistSplitService get _artistSplitService;
  LibraryLocalDeleteService get _localDeleteService;

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
      final writePaths = metadataByPath.keys.toList();
      addedPaths.removeWhere((path) => !metadataByPath.containsKey(path));
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
        updateMovedSongFolders(db, movedSongs, folderIds);
        final scannedSongs = _buildScannedSongs(
          writePaths,
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
        final updatedPathKeys = {...movedNewPathKeys};
        final batchWriter = LibraryLocalScanBatchWriter(db);
        try {
          for (final entry in writePaths.indexed) {
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
                    : _songPropertiesService.normalizeArtists(
                      directSplit.artists,
                    );
            final parentId =
                folderIds[localScanPathComparisonKey(p.dirname(filePath))] ?? 0;
            final writeResult = batchWriter.write(
              filePath: filePath,
              song: scannedSong,
              metadata: metadataByPath[filePath]!,
              parentId: parentId,
              artists: artists,
            );
            final songId = writeResult.songId;
            final pathKey = localScanPathComparisonKey(filePath);
            if (writeResult.changed && !addedPathKeys.contains(pathKey)) {
              updatedPathKeys.add(pathKey);
            }
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
                writtenCount == writePaths.length) {
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
                  updatedCount: updatedPathKeys.length,
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
            updatedCount: updatedPathKeys.length,
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
