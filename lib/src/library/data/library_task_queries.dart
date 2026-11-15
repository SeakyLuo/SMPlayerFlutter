part of 'library_repository.dart';

extension LibraryTaskQueries on LibraryRepository {
  Future<void> applySharedArtistValues(Map<int, List<String>> values) async {
    await LibraryRepository._artistSplitService.applyValues(
      await _resolveDatabaseFile(),
      values,
    );
    activeMusicShareAccess?.localDataChanged('library');
  }

  Future<(int count, int lastId)> localTaskRange({String? folder}) async {
    final file = await _resolveDatabaseFile();
    await LibrarySnapshotService.waitForPendingOperations();
    return Isolate.run(() {
      final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
      try {
        final row =
            db.select(
              "SELECT COUNT(*) AS count, COALESCE(MAX(Id), 0) AS lastId FROM Music WHERE State = 1 AND Path NOT LIKE 'smplayer-music://%' ${folder == null ? '' : 'AND substr(Path, 1, ?) = ?'}",
              [
                if (folder != null) ...[
                  folder.length + 1,
                  '$folder${Platform.pathSeparator}',
                ],
              ],
            ).first;
        return (row['count'] as int, row['lastId'] as int);
      } finally {
        db.dispose();
      }
    });
  }

  Future<List<LibrarySong>> readLocalTaskBatch(
    int afterId,
    int lastId,
    int size, {
    String? folder,
  }) async {
    final file = await _resolveDatabaseFile();
    await LibrarySnapshotService.waitForPendingOperations();
    return Isolate.run(() {
      final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
      try {
        db.execute('BEGIN');
        final ids =
            db
                .select(
                  "SELECT Id FROM Music WHERE State = 1 AND Path NOT LIKE 'smplayer-music://%' AND Id > ? AND Id <= ? ${folder == null ? '' : 'AND substr(Path, 1, ?) = ?'} ORDER BY Id LIMIT ?",
                  [
                    afterId,
                    lastId,
                    if (folder != null) ...[
                      folder.length + 1,
                      '$folder${Platform.pathSeparator}',
                    ],
                    size,
                  ],
                )
                .map((row) => row['Id'] as int)
                .toList();
        final songs = LibraryRepository._readService.readSongs(
          db,
          songIds: ids,
        );
        db.execute('COMMIT');
        return songs;
      } finally {
        db.dispose();
      }
    });
  }

  Stream<List<LibrarySong>> localTaskBatches(
    (int count, int lastId) range, {
    String? folder,
    bool Function()? isCanceled,
    Future<void> Function()? waitIfPaused,
  }) async* {
    const batchSize = 100;
    var afterId = 0;
    for (
      var batch = 0;
      batch < (range.$1 + batchSize - 1) ~/ batchSize;
      batch++
    ) {
      if (isCanceled?.call() == true) return;
      await waitIfPaused?.call();
      if (isCanceled?.call() == true) return;
      final songs = await readLocalTaskBatch(
        afterId,
        range.$2,
        batchSize,
        folder: folder,
      );
      if (songs.isEmpty) return;
      afterId = songs.map((song) => song.id).reduce((a, b) => a > b ? a : b);
      yield songs;
    }
  }

  Future<ArtistSplitAnalysisResult> analyzeLocalArtistBatches({
    String? folder,
    void Function(double)? onProgress,
  }) async {
    onProgress?.call(0);
    final file = await _resolveDatabaseFile();
    await LibrarySnapshotService.waitForPendingOperations();
    final rules = await Isolate.run(() {
      final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
      try {
        return artist_rules.buildArtistSplitRules(
          LibraryRepository._artistSplitService.readRecognitionSources(
            db,
            folder: folder,
          ),
        );
      } finally {
        db.dispose();
      }
    });
    final range = await localTaskRange(folder: folder);
    final direct = <ArtistSplitResultItem>[];
    final possible = <ArtistSplitResultItem>[];
    final merges = <ArtistSplitResultItem>[];
    var processed = 0;
    onProgress?.call(0.1);
    await for (final page in localTaskBatches(range, folder: folder)) {
      final result = rules.apply(page);
      direct.addAll(result.directSplits);
      possible.addAll(result.possibleSplits);
      merges.addAll(result.mergeSuggestions);
      processed += page.length;
      onProgress?.call(0.1 + 0.9 * processed / range.$1);
    }
    onProgress?.call(1);
    return ArtistSplitAnalysisResult(
      directSplits: direct,
      possibleSplits: possible,
      mergeSuggestions: merges,
    );
  }

  Future<LyricsBatchResult> runInternetLyricsBatch({
    required bool overwrite,
    void Function(LyricsBatchProgress progress)? onProgress,
    void Function(LyricsBatchDetail detail, LyricsBatchProgress progress)?
    onDetailCompleted,
    bool Function()? isCanceled,
    Future<void> Function()? waitIfPaused,
  }) async {
    final range = await localTaskRange();
    final databaseFile = await _resolveDatabaseFile();
    return _lyricsService.batchAddInternetLyrics(
      onPageCompleted:
          (ids) => _lyricsSearchService.refreshSongIds(databaseFile, ids),
      songCount: range.$1,
      songPages: localTaskBatches(
        range,
        isCanceled: isCanceled,
        waitIfPaused: waitIfPaused,
      ),
      overwrite: overwrite,
      onProgress: onProgress,
      isCanceled: isCanceled,
      waitIfPaused: waitIfPaused,
      onDetailCompleted: (detail, progress) {
        if (detail.result == LyricsBatchDetailResult.saved ||
            detail.result == LyricsBatchDetailResult.overwritten) {
          _invalidateLyricsCache([detail.songId]);
        }
        onDetailCompleted?.call(detail, progress);
      },
    );
  }
}
