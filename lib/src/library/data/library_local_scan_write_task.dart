part of 'library_local_refresh_service.dart';

typedef _ScanWriteResult =
    ({LocalFolderRefreshResult result, int updatedCount});

abstract class _ScanWriteTask {
  SendPort? progressPort;
  void onProgress(LocalFolderRefreshProgress progress) =>
      progressPort?.send(progress);
  Future<_ScanWriteResult> call();
}

Future<_ScanWriteResult> _runScanWrite(
  _ScanWriteTask task,
  void Function(LocalFolderRefreshProgress)? onProgress,
) async {
  final port = ReceivePort();
  task.progressPort = port.sendPort;
  final subscription = port.listen((message) {
    onProgress?.call(message as LocalFolderRefreshProgress);
  });
  try {
    return await Isolate.run(task.call);
  } finally {
    await subscription.cancel();
    port.close();
  }
}

class _FolderScanWriteTask extends _ScanWriteTask {
  _FolderScanWriteTask({
    required this.service,
    required this.databasePath,
    required this.rootPath,
    required this.settings,
    required this.scannedPaths,
    required this.scannedPathKeys,
    required this.writePaths,
    required this.metadataByPath,
    required this.folders,
    required this.movedSongs,
    required this.movedNewPathKeys,
    required this.addedPaths,
    required this.addedPathKeys,
    required this.writeTotal,
    required this.checkedFolderCount,
    required this.folderCount,
    required this.folderPath,
    required this.removedSongs,
    required this.movedFiles,
    required this.requiresFullReload,
  });

  final _LibraryLocalFolderRefresh service;
  final String databasePath;
  final String rootPath;
  final LibraryReadSettings settings;
  final List<String> scannedPaths;
  final Set<String> scannedPathKeys;
  final List<String> writePaths;
  final Map<String, AudioFileMetadata> metadataByPath;
  final List<String> folders;
  final List<RefreshMovedSong> movedSongs;
  final Set<String> movedNewPathKeys;
  final List<String> addedPaths;
  final Set<String> addedPathKeys;
  final int writeTotal;
  final int checkedFolderCount;
  final int folderCount;
  final String folderPath;
  final List<_RefreshRemovedSong> removedSongs;
  final List<LocalMovedAudioFile> movedFiles;
  final bool requiresFullReload;

  @override
  Future<_ScanWriteResult> call() async {
    final db = sqlite3.open(databasePath);
    try {
      db.execute('BEGIN');
      try {
        service.markScannedFoldersInactive(db, folderPath);
        for (final movedSong in movedSongs) {
          service.updateMovedSongPathInsideTransaction(db, movedSong);
        }
        if (removedSongs.isNotEmpty) {
          service._localDeleteService.deleteSongsInsideTransaction(
            db,
            removedSongs.map((song) => song.id).toList(),
            removedSongs.map((song) => song.path).toList(),
          );
        }
        final removedProgress = removedSongs.length;
        if (removedProgress > 0) {
          onProgress(
            LocalFolderRefreshProgress(
              stage: LocalFolderRefreshStage.updating,
              current: removedProgress,
              total: writeTotal,
              currentPath: '',
              checkedFolderCount: checkedFolderCount,
              folderCount: folderCount,
              songCount: scannedPaths.length,
              addedCount: addedPaths.length,
              updatedCount: movedFiles.length,
              missingCount: removedSongs.length,
            ),
          );
        }
        final folderIds = service.upsertScannedFolders(db, rootPath, folders);
        service.updateMovedSongFolders(db, movedSongs, folderIds);
        final scannedSongs = service._buildScannedSongs(
          writePaths,
          metadataByPath,
          useFilenameNotMusicName: settings.useFilenameNotMusicName,
        );
        final changedSongIds = <int>{};
        final updatedPathKeys = {...movedNewPathKeys};
        final updatedPaths = <String>[];
        final batchWriter = LibraryLocalScanBatchWriter(db);
        try {
          for (final entry in writePaths.indexed) {
            final writtenCount = entry.$1 + 1;
            final filePath = entry.$2;
            final scannedSong = scannedSongs[entry.$1];
            final metadata = metadataByPath[filePath]!;
            final songMetadataChanged = batchWriter.hasSongMetadataChanges(
              filePath: filePath,
              song: scannedSong,
              metadata: metadata,
            );
            final parentId =
                folderIds[localScanPathComparisonKey(p.dirname(filePath))] ?? 0;
            final writeResult = batchWriter.write(
              filePath: filePath,
              song: scannedSong,
              metadata: metadata,
              parentId: parentId,
              artists: scannedSong.artists,
            );
            final songId = writeResult.songId;
            final pathKey = localScanPathComparisonKey(filePath);
            if (writeResult.changed && !addedPathKeys.contains(pathKey)) {
              updatedPathKeys.add(pathKey);
              if (!movedNewPathKeys.contains(pathKey)) {
                updatedPaths.add(filePath);
              }
            }
            if (songMetadataChanged || addedPathKeys.contains(pathKey)) {
              changedSongIds.add(songId);
            }
            if (writtenCount % _scanWriteBatchSize == 0 ||
                writtenCount == writePaths.length) {
              onProgress(
                LocalFolderRefreshProgress(
                  current: removedProgress + writtenCount,
                  total: writeTotal,
                  currentPath: filePath,
                  stage: LocalFolderRefreshStage.updating,
                  checkedFolderCount: checkedFolderCount,
                  folderCount: folderCount,
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
        final pendingArtistAnalysis =
            settings.smartMultiArtistRecognition
                ? await service._analyzeUpdatedFolderArtists(db, changedSongIds)
                : service._artistSplitService.emptyAnalysis();
        service._artistSplitService.applySplitsInsideTransaction(
          db,
          pendingArtistAnalysis.directSplits,
        );
        db.execute('COMMIT');
        return (
          result: LocalFolderRefreshResult(
            libraryChanged:
                requiresFullReload ||
                updatedPathKeys.isNotEmpty ||
                pendingArtistAnalysis.directSplits.isNotEmpty,
            requiresFullReload: requiresFullReload,
            filesAdded: addedPaths,
            filesUpdated: updatedPaths,
            filesRemoved: removedSongs.map((song) => song.path).toList(),
            filesMoved: movedSongs.map((song) => song.newPath).toList(),
            artistSplitsApplied: pendingArtistAnalysis.directSplits,
            artistSplitSuggestions: pendingArtistAnalysis.possibleSplits,
            artistMergeSuggestions: pendingArtistAnalysis.mergeSuggestions,
          ),
          updatedCount: updatedPathKeys.length,
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

class _LibraryScanWriteTask extends _ScanWriteTask {
  _LibraryScanWriteTask({
    required this.service,
    required this.databasePath,
    required this.rootPath,
    required this.settings,
    required this.scannedPaths,
    required this.scannedPathKeys,
    required this.writePaths,
    required this.metadataByPath,
    required this.folders,
    required this.movedSongs,
    required this.movedNewPathKeys,
    required this.addedPaths,
    required this.addedPathKeys,
    required this.writeTotal,
    required this.checkedFolderCount,
    required this.folderCount,
    required this.removedPaths,
    required this.movedFiles,
    required this.requiresFullReload,
  });

  final LibraryLocalRefreshService service;
  final String databasePath;
  final String rootPath;
  final LibraryReadSettings settings;
  final List<String> scannedPaths;
  final Set<String> scannedPathKeys;
  final List<String> writePaths;
  final Map<String, AudioFileMetadata> metadataByPath;
  final List<String> folders;
  final List<RefreshMovedSong> movedSongs;
  final Set<String> movedNewPathKeys;
  final List<String> addedPaths;
  final Set<String> addedPathKeys;
  final int writeTotal;
  final int checkedFolderCount;
  final int folderCount;
  final List<String> removedPaths;
  final List<LocalMovedAudioFile> movedFiles;
  final bool requiresFullReload;

  @override
  Future<_ScanWriteResult> call() async {
    final db = sqlite3.open(databasePath);
    try {
      db.execute('BEGIN');
      try {
        for (final movedSong in movedSongs) {
          service.updateMovedSongPathInsideTransaction(db, movedSong);
        }
        service.markScannedTablesInactive(db, scannedPaths.toSet());
        final folderIds = service.upsertScannedFolders(db, rootPath, folders);
        service.updateMovedSongFolders(db, movedSongs, folderIds);
        final scannedSongs = service._buildScannedSongs(
          writePaths,
          metadataByPath,
          useFilenameNotMusicName: settings.useFilenameNotMusicName,
        );
        final changedSongIds = <int>{};
        final updatedPathKeys = {...movedNewPathKeys};
        final updatedPaths = <String>[];
        final batchWriter = LibraryLocalScanBatchWriter(db);
        try {
          for (final entry in writePaths.indexed) {
            final writtenCount = entry.$1 + 1;
            final filePath = entry.$2;
            final scannedSong = scannedSongs[entry.$1];
            final metadata = metadataByPath[filePath]!;
            final songMetadataChanged = batchWriter.hasSongMetadataChanges(
              filePath: filePath,
              song: scannedSong,
              metadata: metadata,
            );
            final parentId =
                folderIds[localScanPathComparisonKey(p.dirname(filePath))] ?? 0;
            final writeResult = batchWriter.write(
              filePath: filePath,
              song: scannedSong,
              metadata: metadata,
              parentId: parentId,
              artists: scannedSong.artists,
            );
            final songId = writeResult.songId;
            final pathKey = localScanPathComparisonKey(filePath);
            if (writeResult.changed && !addedPathKeys.contains(pathKey)) {
              updatedPathKeys.add(pathKey);
              if (!movedNewPathKeys.contains(pathKey)) {
                updatedPaths.add(filePath);
              }
            }
            if (songMetadataChanged || addedPathKeys.contains(pathKey)) {
              changedSongIds.add(songId);
            }
            if (writtenCount % _scanWriteBatchSize == 0 ||
                writtenCount == writePaths.length) {
              onProgress(
                LocalFolderRefreshProgress(
                  current: writtenCount,
                  total: writeTotal,
                  currentPath: filePath,
                  stage: LocalFolderRefreshStage.updating,
                  checkedFolderCount: checkedFolderCount,
                  folderCount: folderCount,
                  processedSongCount: writtenCount,
                  songCount: scannedPaths.length,
                  addedCount: addedPaths.length,
                  updatedCount: updatedPathKeys.length,
                  missingCount: removedPaths.length,
                ),
              );
            }
          }
        } finally {
          batchWriter.dispose();
        }
        final pendingArtistAnalysis =
            settings.smartMultiArtistRecognition
                ? await service._analyzeUpdatedFolderArtists(db, changedSongIds)
                : service._artistSplitService.emptyAnalysis();
        service._artistSplitService.applySplitsInsideTransaction(
          db,
          pendingArtistAnalysis.directSplits,
        );
        service.setRootPath(db, rootPath);
        db.execute('COMMIT');
        return (
          result: LocalFolderRefreshResult(
            libraryChanged:
                requiresFullReload ||
                updatedPathKeys.isNotEmpty ||
                pendingArtistAnalysis.directSplits.isNotEmpty,
            requiresFullReload: requiresFullReload,
            filesAdded: addedPaths,
            filesUpdated: updatedPaths,
            filesRemoved: removedPaths,
            filesMoved: movedFiles.map((file) => file.newPath).toList(),
            artistSplitsApplied: pendingArtistAnalysis.directSplits,
            artistSplitSuggestions: pendingArtistAnalysis.possibleSplits,
            artistMergeSuggestions: pendingArtistAnalysis.mergeSuggestions,
          ),
          updatedCount: updatedPathKeys.length,
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
