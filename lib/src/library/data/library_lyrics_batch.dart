part of 'library_lyrics_service.dart';

extension LibraryLyricsBatch on LibraryLyricsService {
  Future<LyricsBatchResult> batchAddInternetLyrics({
    required int songCount,
    required Stream<List<LibrarySong>> songPages,
    Future<void> Function(List<int>)? onPageCompleted,
    bool overwrite = false,
    void Function(LyricsBatchProgress progress)? onProgress,
    void Function(LyricsBatchDetail detail, LyricsBatchProgress progress)?
    onDetailCompleted,
    bool Function()? isCanceled,
    Future<void> Function()? waitIfPaused,
  }) async {
    var saved = 0;
    var overwritten = 0;
    var skipped = 0;
    var missing = 0;
    var failed = 0;
    var backedUp = 0;
    var backupBytes = 0;
    var lastRequestStartedAt = DateTime.fromMillisecondsSinceEpoch(0);
    final details = <LyricsBatchDetail>[];

    var index = 0;
    processing:
    await for (final songs in songPages) {
      final changedIds = <int>[];
      try {
        for (final song in songs) {
          index += 1;
          if (isCanceled?.call() == true) {
            break processing;
          }
          await waitIfPaused?.call();
          if (isCanceled?.call() == true) {
            break processing;
          }

          LyricsBatchProgress currentProgress() {
            return LyricsBatchProgress(
              currentIndex: index,
              total: songCount,
              currentSongTitle: [
                song.title,
                song.artist,
              ].where((part) => part.isNotEmpty).join(' - '),
              saved: saved,
              overwritten: overwritten,
              skipped: skipped,
              missing: missing,
              failed: failed,
              backedUp: backedUp,
              backupBytes: backupBytes,
            );
          }

          void recordDetail(LyricsBatchDetail detail) {
            details.add(detail);
            final progress = currentProgress();
            onProgress?.call(progress);
            onDetailCompleted?.call(detail, progress);
          }

          onProgress?.call(currentProgress());

          try {
            final localLyrics = await _getSongLyricsByPath(song.path);
            if (!overwrite && localLyrics.rawText.trim().isNotEmpty) {
              skipped += 1;
              recordDetail(
                LyricsBatchDetail(
                  songId: song.id,
                  title: song.title,
                  artist: song.artist,
                  thumbnailPath: song.thumbnailPath,
                  result: LyricsBatchDetailResult.skipped,
                  reason: LyricsBatchSkipReason.alreadyExists,
                  sourceRawLyrics: localLyrics.rawText,
                ),
              );
              continue;
            }

            final elapsed =
                DateTime.now().difference(lastRequestStartedAt).inMilliseconds;
            if (lastRequestStartedAt.millisecondsSinceEpoch > 0 &&
                elapsed < 200) {
              await Future<void>.delayed(Duration(milliseconds: 200 - elapsed));
            }
            if (isCanceled?.call() == true) {
              break processing;
            }
            lastRequestStartedAt = DateTime.now();
            final rawInternetLyrics =
                _internetLyricsResolver == null
                    ? await _searchInternetLyrics(
                      _LyricsSongLookup(
                        id: song.id,
                        title: song.title,
                        artist: song.artist,
                        album: song.album,
                        path: song.path,
                      ),
                    )
                    : await _internetLyricsResolver(song);
            final internetLyrics =
                _isInvalidInternetLyricsResponse(rawInternetLyrics)
                    ? ''
                    : await _prepareInternetLyrics(rawInternetLyrics);
            if (isCanceled?.call() == true) {
              break processing;
            }

            if (internetLyrics.trim().isEmpty) {
              missing += 1;
              recordDetail(
                LyricsBatchDetail(
                  songId: song.id,
                  title: song.title,
                  artist: song.artist,
                  thumbnailPath: song.thumbnailPath,
                  result: LyricsBatchDetailResult.missing,
                  sourceRawLyrics: localLyrics.rawText,
                ),
              );
              continue;
            }

            final latestLyrics = await _getSongLyricsByPath(song.path);
            if (isCanceled?.call() == true) {
              break processing;
            }
            final existingRawLyrics = latestLyrics.rawText;
            if (!overwrite && existingRawLyrics.trim().isNotEmpty) {
              skipped += 1;
              recordDetail(
                LyricsBatchDetail(
                  songId: song.id,
                  title: song.title,
                  artist: song.artist,
                  thumbnailPath: song.thumbnailPath,
                  result: LyricsBatchDetailResult.skipped,
                  reason: LyricsBatchSkipReason.alreadyExists,
                  sourceRawLyrics: existingRawLyrics,
                ),
              );
              continue;
            }

            if (overwrite &&
                _normalizeLyricsForCompare(existingRawLyrics) ==
                    _normalizeLyricsForCompare(internetLyrics)) {
              skipped += 1;
              recordDetail(
                LyricsBatchDetail(
                  songId: song.id,
                  title: song.title,
                  artist: song.artist,
                  thumbnailPath: song.thumbnailPath,
                  result: LyricsBatchDetailResult.skipped,
                  reason: LyricsBatchSkipReason.sameContent,
                  sourceRawLyrics: existingRawLyrics,
                  targetRawLyrics: internetLyrics,
                ),
              );
              continue;
            }

            final backup =
                overwrite
                    ? await _backUpBatchLyrics(song.path, existingRawLyrics)
                    : null;
            if (backup != null) {
              backedUp += 1;
              backupBytes += backup.bytes;
            }
            changedIds.add(song.id);
            if (backup == null) {
              await _writeLyricsToSongPath(song.path, internetLyrics);
            } else {
              await _applyBatchLyrics(backup, internetLyrics);
            }
            if (backup == null) {
              saved += 1;
              recordDetail(
                LyricsBatchDetail(
                  songId: song.id,
                  title: song.title,
                  artist: song.artist,
                  thumbnailPath: song.thumbnailPath,
                  result: LyricsBatchDetailResult.saved,
                  targetRawLyrics: internetLyrics,
                ),
              );
            } else {
              overwritten += 1;
              recordDetail(
                LyricsBatchDetail(
                  songId: song.id,
                  title: song.title,
                  artist: song.artist,
                  thumbnailPath: song.thumbnailPath,
                  result: LyricsBatchDetailResult.overwritten,
                  backup: backup,
                  sourceRawLyrics: existingRawLyrics,
                  targetRawLyrics: internetLyrics,
                ),
              );
            }
          } on Object {
            failed += 1;
            recordDetail(
              LyricsBatchDetail(
                songId: song.id,
                title: song.title,
                artist: song.artist,
                thumbnailPath: song.thumbnailPath,
                result: LyricsBatchDetailResult.failed,
              ),
            );
          }
        }
      } finally {
        await onPageCompleted?.call(changedIds);
      }
    }

    return LyricsBatchResult(
      total: songCount,
      saved: saved,
      overwritten: overwritten,
      skipped: skipped,
      missing: missing,
      failed: failed,
      backedUp: backedUp,
      backupBytes: backupBytes,
      details: details,
    );
  }
}
