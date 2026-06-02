part of 'music_dialog.dart';

const _lyricsImportExtensions = [
  'lrc',
  'txt',
  'aac',
  'aiff',
  'aif',
  'alac',
  'ape',
  'flac',
  'm4a',
  'mp3',
  'mp4',
  'oga',
  'ogg',
  'opus',
  'wav',
  'wma',
];

Uri musicLyricsSearchUri({
  required String locale,
  required String title,
  required String artist,
}) {
  final isChineseLanguage = locale == 'zh-CN' || locale == 'zh-Hant';
  final keyword = isChineseLanguage ? '歌词' : 'lyrics';
  final host =
      isChineseLanguage
          ? 'https://cn.bing.com/search'
          : 'https://www.bing.com/search';
  return Uri.parse(
    '$host?q=${Uri.encodeQueryComponent([keyword, title, artist].where((value) => value.isNotEmpty).join(' '))}',
  );
}

final _lyricsTimestampRegex = RegExp(r'\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\]');
final _lyricsMetadataRegex = RegExp(
  r'^\[(ti|ar|al|au|by|offset|re|ve|length):.*\]$',
  caseSensitive: false,
);
final _lyricsLineBreakRegex = RegExp(r'\r\n|[\n\r\u2028\u2029]');

String _stripLyricsTimestamps(String rawText) {
  return rawText
      .split(_lyricsLineBreakRegex)
      .map((line) {
        final trimmedLine = line.trim();
        if (_lyricsMetadataRegex.hasMatch(trimmedLine)) {
          return '';
        }

        return line.replaceAll(_lyricsTimestampRegex, '').trimLeft();
      })
      .join('\n')
      .trim();
}

String _mergePlainLyricsWithTimedRaw(String rawText, String plainText) {
  final plainLines = plainText.split(_lyricsLineBreakRegex);
  var plainLineIndex = 0;
  final mergedLines =
      rawText.split(_lyricsLineBreakRegex).map((line) {
        final timestampTags =
            _lyricsTimestampRegex
                .allMatches(line)
                .map((match) => match.group(0)!)
                .toList();
        if (timestampTags.isEmpty) {
          if (_lyricsMetadataRegex.hasMatch(line.trim()) ||
              line.trim().isEmpty) {
            return line;
          }

          final plainLine =
              plainLineIndex < plainLines.length
                  ? plainLines[plainLineIndex]
                  : line;
          plainLineIndex += 1;
          return plainLine;
        }

        final fallbackText =
            line.replaceAll(_lyricsTimestampRegex, '').trimLeft();
        final plainLine =
            plainLineIndex < plainLines.length
                ? plainLines[plainLineIndex]
                : fallbackText;
        plainLineIndex += 1;
        return '${timestampTags.join()}$plainLine';
      }).toList();

  while (plainLineIndex < plainLines.length) {
    mergedLines.add(plainLines[plainLineIndex]);
    plainLineIndex += 1;
  }

  return mergedLines.join('\n').trim();
}

List<LyricsLine> _parseLyricsLines(String rawText) {
  final lines = rawText.split(_lyricsLineBreakRegex);
  return [
    for (final entry in lines.indexed)
      LyricsLine(
        id: entry.$1,
        timestampMs: _parseLyricsTimestamp(entry.$2),
        text: entry.$2.replaceAll(_lyricsTimestampRegex, '').trim(),
      ),
  ];
}

int? _parseLyricsTimestamp(String line) {
  final match = RegExp(
    r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]',
  ).firstMatch(line);
  if (match == null) {
    return null;
  }

  final minutes = int.parse(match.group(1)!);
  final seconds = int.parse(match.group(2)!);
  final fractionText = match.group(3) ?? '0';
  final fraction = int.parse(fractionText.padRight(3, '0').substring(0, 3));
  return minutes * 60000 + seconds * 1000 + fraction;
}

class _RankedSong {
  const _RankedSong({required this.song, required this.score});

  final LibrarySong song;
  final int score;
}

List<_RankedSong> _getAlbumArtRecommendationCandidates(
  LibrarySong song,
  List<LibrarySong> songs,
) {
  final artistKeys =
      _getSongArtists(song).map((artist) => artist.toLowerCase()).toSet();
  final candidates =
      songs
          .where((candidate) => candidate.id != song.id)
          .map((candidate) {
            final sameArtist = _getSongArtists(
              candidate,
            ).any((artist) => artistKeys.contains(artist.toLowerCase()));
            if (!sameArtist) {
              return null;
            }

            final albumName = song_display.canonicalAlbumName(song);
            final sameAlbum =
                albumName.isNotEmpty &&
                song_display.canonicalAlbumName(candidate) == albumName;
            final similarTitle = _isSimilarArtworkTitle(
              song.title,
              candidate.title,
            );
            if (!sameAlbum && !similarTitle) {
              return null;
            }

            return _RankedSong(
              song: candidate,
              score:
                  (sameAlbum ? 10 : 0) +
                  (similarTitle ? 4 : 0) +
                  (candidate.playCount > 0 ? 1 : 0),
            );
          })
          .whereType<_RankedSong>()
          .toList()
        ..sort((left, right) {
          final scoreCompare = right.score.compareTo(left.score);
          if (scoreCompare != 0) {
            return scoreCompare;
          }
          return left.song.title.compareTo(right.song.title);
        });

  return candidates.take(24).toList();
}

List<_RankedSong> _getRankedArtworkSourceSongs({
  required List<LibrarySong> songs,
  required String albumName,
  required LibrarySong currentSong,
  required String normalizedQuery,
}) {
  final artistKeys =
      _getSongArtists(
        currentSong,
      ).map((artist) => artist.toLowerCase()).toSet();
  final librarySongs =
      songs.where((song) => song.id != currentSong.id).toList();
  final ranked =
      librarySongs
          .map((song) {
            final searchableText = _normalizeSearchText(
              song_display.searchableSongText(song),
            );
            if (normalizedQuery.isNotEmpty &&
                !searchableText.contains(normalizedQuery)) {
              return null;
            }

            final sameAlbum =
                albumName.isNotEmpty &&
                song_display.canonicalAlbumName(song) == albumName;
            final sameArtist = _isSameArtistSong(song, artistKeys);
            final similarTitle = _isSimilarArtworkTitle(
              currentSong.title,
              song.title,
            );
            if (normalizedQuery.isEmpty && !sameArtist) {
              return null;
            }

            return _RankedSong(
              song: song,
              score:
                  (sameAlbum ? 40 : 0) +
                  (sameArtist ? 20 : 0) +
                  (similarTitle ? 12 : 0) +
                  song.playCount.clamp(0, 5).toInt(),
            );
          })
          .whereType<_RankedSong>()
          .toList();

  if (ranked.isEmpty && normalizedQuery.isEmpty) {
    return [
      for (final entry in librarySongs.take(20).indexed)
        _RankedSong(song: entry.$2, score: 20 - entry.$1),
    ];
  }

  ranked.sort((left, right) {
    final scoreCompare = right.score.compareTo(left.score);
    if (scoreCompare != 0) {
      return scoreCompare;
    }
    return left.song.title.compareTo(right.song.title);
  });
  return ranked;
}

bool _isSameArtistSong(LibrarySong song, Set<String> artistKeys) {
  return _getSongArtists(
    song,
  ).any((artist) => artistKeys.contains(artist.toLowerCase()));
}

List<String> _getSongArtists(LibrarySong song) {
  return song_display.songArtists(song);
}

String _getDisplayArtists(LibrarySong song, SmPlayerI18n i18n) {
  final artists = _getSongArtists(song);
  if (artists.isEmpty) {
    return i18n.t('common.artistUnknown');
  }

  return artists.join(i18n.t('common.artistSeparator'));
}

String _normalizeSearchText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

String _normalizeArtworkMatchText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
      .replaceAll(RegExp(r'[\s\-_.:/\\|]+'), '')
      .trim();
}

bool _isSimilarArtworkTitle(String left, String right) {
  final normalizedLeft = _normalizeArtworkMatchText(left);
  final normalizedRight = _normalizeArtworkMatchText(right);

  return normalizedLeft.length >= 2 &&
      normalizedRight.length >= 2 &&
      (normalizedLeft.contains(normalizedRight) ||
          normalizedRight.contains(normalizedLeft));
}
