part of 'library_local_refresh_service.dart';

class _ImportLocalAudioTask {
  const _ImportLocalAudioTask(
    this.service,
    this.databasePath,
    this.metadataByPath,
  );
  final _LibraryLocalRefreshOperations service;
  final String databasePath;
  final Map<String, AudioFileMetadata> metadataByPath;

  List<int> call() {
    final db = sqlite3.open(databasePath);
    final openedSongIds = <int>[];
    try {
      final settings = const LibraryReadService().readLibrarySettings(db);
      db.execute('BEGIN');
      try {
        for (final filePath in metadataByPath.keys) {
          openedSongIds.add(
            service.upsertExternalAudioFile(
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
}

class _RenameLocalFolderTask {
  const _RenameLocalFolderTask(
    this.service,
    this.databasePath,
    this.folderPath,
    this.name,
  );
  final _LibraryLocalRefreshOperations service;
  final String databasePath;
  final String folderPath;
  final String name;

  Future<void> call() =>
      service._renameFolderInBackground(File(databasePath), folderPath, name);
}
