part of 'library_lyrics_service.dart';

extension _LibraryLyricsInternet on LibraryLyricsService {
  Future<String> _searchInternetLyrics(_LyricsSongLookup song) async {
    final resolver = _internetLyricsResolver;
    if (resolver != null) {
      final lyrics = await resolver(
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
      return _isInvalidInternetLyricsResponse(lyrics) ? '' : lyrics;
    }

    final songMid = await _getSongMid(song);
    if (songMid.isEmpty) {
      return '';
    }

    try {
      return await _getRawLyricsBySongMid(songMid);
    } catch (_) {
      return '';
    }
  }

  Future<String> _getRawLyricsBySongMid(String songMid) async {
    final uri = Uri.parse(
      'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg',
    ).replace(
      queryParameters: {'songmid': songMid, 'format': 'json', 'nobase64': '1'},
    );
    final response = await _fetchLyricsJson(uri);
    return _decodeHtmlEntities(response['lyric'] as String? ?? '').trim();
  }

  Future<LyricsSnapshot?> _getSyncedInternetLyrics(
    _LyricsSongLookup song,
  ) async {
    final rawLyrics = await _searchInternetLyrics(song);
    if (rawLyrics.trim().isEmpty) {
      return null;
    }

    final snapshot = _createLyricsSnapshot(rawLyrics, LyricsSource.internet);
    return snapshot.isSynced && snapshot.lines.isNotEmpty ? snapshot : null;
  }

  Future<String> _prepareInternetLyrics(String rawLyrics) async {
    if (_isNoLyricsPlaceholder(rawLyrics)) {
      return '';
    }

    final snapshot = await _settingsSnapshotResolver();
    return _prepareInternetLyricsWithPreference(
      rawLyrics,
      preserveTimestamps:
          snapshot == null || snapshot.preserveInternetLyricsTimestamps,
    );
  }

  String _prepareInternetLyricsWithPreference(
    String rawLyrics, {
    required bool preserveTimestamps,
  }) {
    if (_isNoLyricsPlaceholder(rawLyrics)) {
      return '';
    }
    return preserveTimestamps ? rawLyrics : _stripLyricsTimestamps(rawLyrics);
  }

  String _stripLyricsTimestamps(String rawText) {
    final timestampRegex = RegExp(r'\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\]');
    final metadataRegex = RegExp(
      r'^\[(ti|ar|al|au|by|offset|re|ve|length):.*\]$',
      caseSensitive: false,
    );
    return rawText
        .split(RegExp(r'\r\n|[\n\r\u2028\u2029]'))
        .map((line) {
          final trimmedLine = line.trim();
          if (metadataRegex.hasMatch(trimmedLine)) {
            return '';
          }
          return line.replaceAll(timestampRegex, '').trimLeft();
        })
        .join('\n')
        .trim();
  }

  Future<String> _getSongMid(_LyricsSongLookup song) async {
    for (final attempt in _buildLyricsSearchAttempts(song)) {
      final songMid = await _searchSongMidByKeyword(
        attempt.keyword,
        attempt.title,
        attempt.artist,
      );
      if (songMid.isNotEmpty) {
        return songMid;
      }
    }

    return '';
  }

  List<_LyricsSearchAttempt> _buildLyricsSearchAttempts(
    _LyricsSongLookup song,
  ) {
    final simplifiedTitle = _removeBraces(song.title);
    final simplifiedArtist = _removeBraces(song.artist);
    final attempts = [
      _LyricsSearchAttempt(
        keyword: '${song.title} ${song.artist}'.trim(),
        title: song.title,
        artist: song.artist,
        originalTitle: song.title,
      ),
      _LyricsSearchAttempt(
        keyword: song.title,
        title: song.title,
        artist: song.artist,
        originalTitle: song.title,
      ),
      _LyricsSearchAttempt(
        keyword: '$simplifiedTitle ${song.artist}'.trim(),
        title: simplifiedTitle,
        artist: song.artist,
        originalTitle: song.title,
      ),
      _LyricsSearchAttempt(
        keyword: '${song.title} $simplifiedArtist'.trim(),
        title: song.title,
        artist: simplifiedArtist,
        originalTitle: song.title,
      ),
      _LyricsSearchAttempt(
        keyword: '$simplifiedTitle $simplifiedArtist'.trim(),
        title: simplifiedTitle,
        artist: simplifiedArtist,
        originalTitle: song.title,
      ),
      _LyricsSearchAttempt(
        keyword: simplifiedTitle,
        title: simplifiedTitle,
        artist: simplifiedArtist,
        originalTitle: song.title,
      ),
    ];
    final seen = <String>{};
    return [
      for (final attempt in attempts)
        if (attempt.keyword.isNotEmpty &&
            seen.add('${attempt.keyword}\n${attempt.title}\n${attempt.artist}'))
          attempt,
    ];
  }

  Future<String> _searchSongMidByKeyword(
    String keyword,
    String title,
    String artist,
  ) async {
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
        'key': keyword,
      },
    );
    try {
      final response = await _fetchLyricsJson(uri);
      final data = response['data'] as Map<String, Object?>?;
      final song = data?['song'] as Map<String, Object?>?;
      final items = song?['itemlist'] as List<Object?>? ?? const [];
      Map<String, Object?>? bestMatch;
      var bestScore = -1;

      for (final item in items.whereType<Map<String, Object?>>()) {
        final score =
            _evaluateLyricsMatch(title, item['name'] as String? ?? '') * 2 +
            _evaluateLyricsMatch(artist, item['singer'] as String? ?? '');
        if (score > bestScore) {
          bestScore = score;
          bestMatch = item;
        }
      }

      return bestScore > 0 ? (bestMatch?['mid'] as String? ?? '') : '';
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, Object?>> _fetchLyricsJson(Uri uri) async {
    final response = await http
        .get(
          uri,
          headers: const {
            'accept': 'application/json',
            'accept-language': 'en-US',
            'referer': 'https://y.qq.com/portal/player.html',
            'user-agent': 'Mozilla/5.0',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Lyrics request failed: ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, Object?>;
  }

  int _evaluateLyricsMatch(String target, String candidate) {
    final normalizedTarget = _normalizeLyricsLookupText(target);
    final normalizedCandidate = _normalizeLyricsLookupText(candidate);
    if (normalizedTarget.isEmpty) {
      return normalizedCandidate.isNotEmpty ? 20 : 0;
    }
    if (normalizedTarget == normalizedCandidate) {
      return 100;
    }
    if (normalizedCandidate.contains(normalizedTarget) ||
        normalizedTarget.contains(normalizedCandidate)) {
      return 70;
    }

    final targetTokens = normalizedTarget
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty);
    final candidateTokens = normalizedCandidate
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty);
    var score = 0;
    for (final token in targetTokens) {
      if (candidateTokens.any(
        (candidateToken) =>
            candidateToken.contains(token) || token.contains(candidateToken),
      )) {
        score += 20;
      }
    }
    return score;
  }

  int _evaluateLyricsVersionMatch(String target, String candidate) {
    final targetVersions = _lyricsVersionTokens(target);
    final candidateVersions = _lyricsVersionTokens(candidate);
    if (targetVersions.isEmpty) {
      return -30 * candidateVersions.length;
    }
    if (targetVersions.length == candidateVersions.length &&
        targetVersions.containsAll(candidateVersions)) {
      return 60;
    }

    final shared = targetVersions.intersection(candidateVersions).length;
    final missing = targetVersions.difference(candidateVersions).length;
    final extra = candidateVersions.difference(targetVersions).length;
    return shared * 30 - missing * 50 - extra * 15;
  }

  Set<String> _lyricsVersionTokens(String value) {
    final normalized = value.toLowerCase();
    final versions = <String>{};
    if (RegExp(r'(^|[^a-z])live([^a-z]|$)').hasMatch(normalized) ||
        normalized.contains('现场') ||
        normalized.contains('演唱会')) {
      versions.add('live');
    }
    if (normalized.contains('remix') || normalized.contains('混音')) {
      versions.add('remix');
    }
    if (normalized.contains('acoustic') || normalized.contains('不插电')) {
      versions.add('acoustic');
    }
    if (normalized.contains('instrumental') ||
        normalized.contains('off vocal') ||
        normalized.contains('伴奏') ||
        normalized.contains('纯音乐')) {
      versions.add('instrumental');
    }
    if (normalized.contains('demo')) {
      versions.add('demo');
    }
    if (normalized.contains('remaster') || normalized.contains('重制')) {
      versions.add('remaster');
    }
    if (normalized.contains('radio edit') ||
        normalized.contains('extended edit')) {
      versions.add('edit');
    }
    if (normalized.contains('karaoke') || normalized.contains('卡拉ok')) {
      versions.add('karaoke');
    }
    return versions;
  }

  String _normalizeLyricsLookupText(String value) {
    return _removeBraces(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _removeBraces(String value) {
    return value
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\[[^\]]*]'), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
          return String.fromCharCode(int.parse(match.group(1)!));
        })
        .replaceAll(r'\n', '\n');
  }

  bool _isNoLyricsPlaceholder(String rawLyrics) {
    final normalized =
        rawLyrics
            .replaceAll(
              RegExp(
                r'\[(ti|ar|al|au|by|offset|re|ve|length):[^\]]*\]',
                caseSensitive: false,
              ),
              ' ',
            )
            .replaceAll(RegExp(r'\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\]'), ' ')
            .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '')
            .toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    return normalized.contains(_qqNoLyricsPlaceholder) ||
        _isInstrumentalLyrics(_parseLyricsLines(rawLyrics));
  }

  bool _isInvalidInternetLyricsResponse(String rawLyrics) {
    return rawLyrics.trim().isEmpty ||
        rawLyrics.contains(_qqInvalidLyricsMarker) ||
        _isNoLyricsPlaceholder(rawLyrics);
  }
}
