part of 'library_lyrics_service.dart';

extension LibraryLyricsCandidateSearch on LibraryLyricsService {
  Future<List<InternetLyricsCandidate>> searchInternetLyricsCandidates(
    File databaseFile,
    int songId,
  ) async {
    final song = _getLyricsSongLookup(databaseFile, songId);
    final resolver = _internetLyricsResolver;
    if (resolver != null) {
      final rawLyrics = await resolver(
        LibrarySong(
          id: song.id,
          path: song.path,
          title: song.title,
          artist: song.artist,
          artists: const [],
          album: song.album,
          duration: 0,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '',
          favorite: false,
          thumbnailPath: '',
        ),
      );
      if (_isInvalidInternetLyricsResponse(rawLyrics)) {
        return const [];
      }
      final preparedLyrics = await _prepareInternetLyrics(rawLyrics);
      return [
        InternetLyricsCandidate(
          sourceKey: 'resolver',
          title: song.title,
          artist: song.artist,
          lyrics: _createLyricsSnapshot(preparedLyrics, LyricsSource.internet),
        ),
      ];
    }

    final searchResults = await Future.wait(
      _buildLyricsSearchAttempts(song).map((attempt) async {
        try {
          return _LyricsCandidateSearchResult(
            succeeded: true,
            candidates: await _searchLyricsCandidatesByKeyword(attempt),
          );
        } catch (_) {
          return const _LyricsCandidateSearchResult(
            succeeded: false,
            candidates: [],
          );
        }
      }),
    );
    if (!searchResults.any((result) => result.succeeded)) {
      throw const HttpException('Lyrics search failed.');
    }

    final candidatesByMid = <String, _InternetLyricsCandidateMetadata>{};
    for (final candidate in searchResults.expand(
      (result) => result.candidates,
    )) {
      final current = candidatesByMid[candidate.mid];
      if (current == null || candidate.score > current.score) {
        candidatesByMid[candidate.mid] = candidate;
      }
    }
    final metadataCandidates =
        candidatesByMid.values.toList()
          ..sort((left, right) => right.score.compareTo(left.score));
    final limitedCandidates = metadataCandidates.take(8).toList();
    if (limitedCandidates.isEmpty) {
      return const [];
    }

    final settingsSnapshot = await _settingsSnapshotResolver();
    final preserveTimestamps =
        settingsSnapshot == null ||
        settingsSnapshot.preserveInternetLyricsTimestamps;
    final lyricsResults = await Future.wait(
      limitedCandidates.map((candidate) async {
        try {
          final rawLyrics = await _getRawLyricsBySongMid(candidate.mid);
          if (_isInvalidInternetLyricsResponse(rawLyrics)) {
            return const _LyricsCandidateLyricsResult(
              succeeded: true,
              candidate: null,
            );
          }
          final preparedLyrics = _prepareInternetLyricsWithPreference(
            rawLyrics,
            preserveTimestamps: preserveTimestamps,
          );
          return _LyricsCandidateLyricsResult(
            succeeded: true,
            candidate: InternetLyricsCandidate(
              sourceKey: candidate.mid,
              title: candidate.title,
              artist: candidate.artist,
              lyrics: _createLyricsSnapshot(
                preparedLyrics,
                LyricsSource.internet,
              ),
            ),
          );
        } catch (_) {
          return const _LyricsCandidateLyricsResult(
            succeeded: false,
            candidate: null,
          );
        }
      }),
    );
    if (!lyricsResults.any((result) => result.succeeded)) {
      throw const HttpException('Lyrics loading failed.');
    }
    final seenCandidates = <String>{};
    return lyricsResults
        .map((result) => result.candidate)
        .whereType<InternetLyricsCandidate>()
        .where(
          (candidate) => seenCandidates.add(
            '${_normalizeLyricsLookupText(candidate.title)}\n'
            '${_normalizeLyricsLookupText(candidate.artist)}\n'
            '${_normalizeLyricsForCompare(candidate.lyrics.rawText)}',
          ),
        )
        .toList();
  }

  Future<List<_InternetLyricsCandidateMetadata>>
  _searchLyricsCandidatesByKeyword(_LyricsSearchAttempt attempt) async {
    final uri = Uri.parse(
      'https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg',
    ).replace(
      queryParameters: {
        'cv': '4747474',
        'ct': '24',
        'format': 'json',
        'inCharset': 'utf-8',
        'outCharset': 'utf-8',
        'notice': '0',
        'platform': 'yqq.json',
        'needNewCode': '1',
        'key': attempt.keyword,
      },
    );
    final response = await _fetchLyricsJson(uri);
    final data = response['data'] as Map<String, Object?>?;
    final song = data?['song'] as Map<String, Object?>?;
    final items = song?['itemlist'] as List<Object?>? ?? const [];
    final candidates = <_InternetLyricsCandidateMetadata>[];
    for (final item in items.whereType<Map<String, Object?>>()) {
      final mid = item['mid'] as String? ?? '';
      final title = item['name'] as String? ?? '';
      final artist = item['singer'] as String? ?? '';
      final score =
          _evaluateLyricsMatch(attempt.title, title) * 2 +
          _evaluateLyricsMatch(attempt.artist, artist);
      if (mid.isNotEmpty && score > 0) {
        candidates.add(
          _InternetLyricsCandidateMetadata(
            mid: mid,
            title: title,
            artist: artist,
            score: score,
          ),
        );
      }
    }
    return candidates;
  }
}

class _InternetLyricsCandidateMetadata {
  const _InternetLyricsCandidateMetadata({
    required this.mid,
    required this.title,
    required this.artist,
    required this.score,
  });

  final String mid;
  final String title;
  final String artist;
  final int score;
}

class _LyricsCandidateSearchResult {
  const _LyricsCandidateSearchResult({
    required this.succeeded,
    required this.candidates,
  });

  final bool succeeded;
  final List<_InternetLyricsCandidateMetadata> candidates;
}

class _LyricsCandidateLyricsResult {
  const _LyricsCandidateLyricsResult({
    required this.succeeded,
    required this.candidate,
  });

  final bool succeeded;
  final InternetLyricsCandidate? candidate;
}
