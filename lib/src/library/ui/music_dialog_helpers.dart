part of 'music_dialog.dart';

const _musicDialogAudioExtensions = [
  'aac',
  'aiff',
  'alac',
  'ape',
  'flac',
  'm4a',
  'mp3',
  'ogg',
  'opus',
  'wav',
  'wma',
];

const _lyricsImportExtensions = ['lrc', 'txt', ..._musicDialogAudioExtensions];

const _artworkImageExtensions = ['jpg', 'png', 'jpeg', 'webp', 'bmp'];

const _artworkSourceExtensions = [
  ..._artworkImageExtensions,
  ..._musicDialogAudioExtensions,
];

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

LyricsSnapshot? _lyricsWithRawText(LyricsSnapshot? current, String rawText) {
  if (current == null) {
    return current;
  }

  return LyricsSnapshot(
    source: current.source,
    isSynced: current.isSynced,
    rawText: rawText,
    lines: current.lines,
  );
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

            final sameAlbum =
                song.album.trim().isNotEmpty && candidate.album == song.album;
            final similarTitle = _isSimilarArtworkRecommendationTitle(
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

String _albumArtRecommendationRequestKey(
  LibrarySong currentSong,
  List<LibrarySong> songs,
) {
  final buffer =
      StringBuffer()
        ..write(currentSong.id)
        ..write('|')
        ..write(currentSong.title)
        ..write('|')
        ..write(currentSong.album)
        ..write('|')
        ..write(currentSong.artists.join(','))
        ..write('|');
  for (final song in songs) {
    buffer
      ..write(song.id)
      ..write('|')
      ..write(song.title)
      ..write('|')
      ..write(song.album)
      ..write('|')
      ..write(song.artists.join(','))
      ..write('|')
      ..write(song.playCount)
      ..write(';');
  }
  return buffer.toString();
}

List<_RankedSong> _getRankedArtworkSourceSongs({
  required List<LibrarySong> songs,
  required String albumName,
  required LibrarySong? currentSong,
  required String normalizedQuery,
}) {
  final artistSourceSongs =
      currentSong == null
          ? songs.where((song) => song.album == albumName)
          : [currentSong];
  final artistKeys =
      artistSourceSongs
          .expand((song) => _getSongArtists(song))
          .map((artist) => artist.toLowerCase())
          .toSet();
  final librarySongs =
      songs.where((song) => song.id != currentSong?.id).toList();
  List<_RankedSong> rankSongs(Iterable<LibrarySong> sourceSongs) {
    return sourceSongs
        .map((song) {
          final searchableText = _normalizeSearchText(
            [song.title, song.album, ..._getSongArtists(song)].join(' '),
          );
          if (normalizedQuery.isNotEmpty &&
              !searchableText.contains(normalizedQuery)) {
            return null;
          }

          final sameAlbum = albumName.isNotEmpty && song.album == albumName;
          final sameArtist = _isSameArtistSong(song, artistKeys);
          final similarTitle =
              currentSong == null
                  ? false
                  : _isSimilarArtworkLibraryTitle(
                    currentSong.title,
                    song.title,
                  );

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
        .toList()
      ..sort((left, right) {
        final scoreCompare = right.score.compareTo(left.score);
        if (scoreCompare != 0) {
          return scoreCompare;
        }
        return left.song.title.compareTo(right.song.title);
      });
  }

  if (normalizedQuery.isNotEmpty) {
    return rankSongs(librarySongs);
  }

  final sameArtistSongs =
      librarySongs
          .where((song) => _isSameArtistSong(song, artistKeys))
          .toList();
  if (sameArtistSongs.isNotEmpty) {
    return rankSongs(sameArtistSongs);
  }

  return [
    for (final entry in librarySongs.take(20).indexed)
      _RankedSong(song: entry.$2, score: 20 - entry.$1),
  ];
}

bool _isSameArtistSong(LibrarySong song, Set<String> artistKeys) {
  return _getSongArtists(
    song,
  ).any((artist) => artistKeys.contains(artist.toLowerCase()));
}

List<String> _getSongArtists(
  LibrarySong song, {
  String unknownArtist = 'Unknown artist',
}) {
  final artists = song_display.songArtists(song);
  return artists.isNotEmpty ? artists : [unknownArtist];
}

String _getDisplayArtists(LibrarySong song, SmPlayerI18n i18n) {
  return _getSongArtists(
    song,
    unknownArtist: i18n.t('common.artistUnknown'),
  ).join(i18n.t('common.artistSeparator'));
}

String _normalizeSearchText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

String _normalizeArtworkRecommendationMatchText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[（(【[].*?[）)】\]]'), '')
      .replaceAll(RegExp(r'[\s\-_.·・:：,，/\\|]+'), '')
      .trim();
}

bool _isSimilarArtworkRecommendationTitle(String left, String right) {
  final normalizedLeft = _normalizeArtworkRecommendationMatchText(left);
  final normalizedRight = _normalizeArtworkRecommendationMatchText(right);

  return normalizedLeft.length >= 2 &&
      normalizedRight.length >= 2 &&
      (normalizedLeft.contains(normalizedRight) ||
          normalizedRight.contains(normalizedLeft));
}

String _normalizeArtworkLibraryMatchText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
      .replaceAll(RegExp(r'[\s\-_.:/\\|]+'), '')
      .trim();
}

bool _isSimilarArtworkLibraryTitle(String left, String right) {
  final normalizedLeft = _normalizeArtworkLibraryMatchText(left);
  final normalizedRight = _normalizeArtworkLibraryMatchText(right);

  return normalizedLeft.length >= 2 &&
      normalizedRight.length >= 2 &&
      (normalizedLeft.contains(normalizedRight) ||
          normalizedRight.contains(normalizedLeft));
}
