import 'package:lpinyin/lpinyin.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';

class ArtistGroup {
  const ArtistGroup({
    required this.name,
    required this.songs,
    required this.albumCount,
    required this.artworkSongId,
  });

  final String name;
  final List<LibrarySong> songs;
  final int albumCount;
  final int artworkSongId;
}

class AlbumGroup {
  const AlbumGroup({
    required this.name,
    required this.songs,
    required this.duration,
  });

  final String name;
  final List<LibrarySong> songs;
  final int duration;
}

const artistRowHeight = 64.0;
const artistQuickJumpKeys = [
  '#',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];

List<ArtistGroup> buildArtistGroups(
  List<LibrarySong> songs,
  SmPlayerI18n i18n,
) {
  final groups = <String, List<LibrarySong>>{};
  for (final song in songs) {
    final artists = getSongArtists(song);
    final artistNames =
        artists.isEmpty ? [i18n.t('common.artistUnknown')] : artists;
    for (final artistName in artistNames) {
      final group = groups[artistName] ?? <LibrarySong>[];
      group.add(song);
      groups[artistName] = group;
    }
  }

  final artists =
      groups.entries.map((entry) {
        final artistSongs =
            entry.value.toList()..sort((left, right) {
              final albumCompare = compareArtistText(left.album, right.album);
              return albumCompare != 0
                  ? albumCompare
                  : compareArtistText(left.title, right.title);
            });
        final albums =
            artistSongs.map((song) => displayAlbum(song, i18n)).toSet();
        final artworkSong =
            artistSongs.any((song) => song.thumbnailPath.isNotEmpty)
                ? artistSongs.firstWhere(
                  (song) => song.thumbnailPath.isNotEmpty,
                )
                : (entry.value.toList()..sort(
                      (left, right) => DateTime.parse(
                        right.dateAdded,
                      ).compareTo(DateTime.parse(left.dateAdded)),
                    ))
                    .first;

        return ArtistGroup(
          name: entry.key,
          songs: artistSongs,
          albumCount: albums.length,
          artworkSongId: artworkSong.id,
        );
      }).toList();

  artists.sort((left, right) => compareArtistText(left.name, right.name));
  return artists;
}

List<AlbumGroup> buildAlbumGroups(List<LibrarySong> songs, SmPlayerI18n i18n) {
  final groups = <String, List<LibrarySong>>{};
  for (final song in songs) {
    final albumName = displayAlbum(song, i18n);
    final group = groups[albumName] ?? <LibrarySong>[];
    group.add(song);
    groups[albumName] = group;
  }

  final albums =
      groups.entries.map((entry) {
        final albumSongs =
            entry.value.toList()..sort(
              (left, right) => compareArtistText(left.title, right.title),
            );
        return AlbumGroup(
          name: entry.key,
          songs: albumSongs,
          duration: albumSongs.fold(0, (total, song) => total + song.duration),
        );
      }).toList();

  albums.sort((left, right) => compareArtistText(left.name, right.name));
  return albums;
}

List<ArtistGroup> searchArtists(List<ArtistGroup> artists, String query) {
  final keyword = query.trim();
  if (keyword.isEmpty) {
    return artists;
  }

  final scored =
      artists
          .map(
            (artist) => (
              artist: artist,
              score: evaluateString(artist.name, keyword),
            ),
          )
          .where((result) => result.score > 0)
          .toList();
  scored.sort((left, right) => right.score.compareTo(left.score));
  return scored.map((result) => result.artist).toList();
}

Map<String, int> buildArtistQuickJumpMap(List<ArtistGroup> artists) {
  final indexes = <String, int>{};
  for (var index = 0; index < artists.length; index += 1) {
    indexes.putIfAbsent(
      getArtistQuickJumpBucket(artists[index].name),
      () => index,
    );
  }
  return indexes;
}

String getArtistQuickJumpBucket(String artistName) {
  final trimmed = artistName.trim();
  if (trimmed.isEmpty) {
    return '#';
  }

  final firstChar = trimmed.substring(0, 1);
  final first = _foldLatinFirstChar(firstChar).toUpperCase();
  if (RegExp(r'^[A-Z]$').hasMatch(first)) {
    return first;
  }

  if (!_isCjkUnifiedIdeograph(firstChar)) {
    return '#';
  }

  final pinyin =
      PinyinHelper.getPinyinE(
        firstChar,
        separator: '',
        defPinyin: '',
        format: PinyinFormat.WITHOUT_TONE,
      ).toUpperCase();
  return pinyin.isNotEmpty && RegExp(r'^[A-Z]$').hasMatch(pinyin[0])
      ? pinyin[0]
      : '#';
}

String _foldLatinFirstChar(String value) {
  const folded = {
    'À': 'A',
    'Á': 'A',
    'Â': 'A',
    'Ã': 'A',
    'Ä': 'A',
    'Å': 'A',
    'Ā': 'A',
    'Ă': 'A',
    'Ą': 'A',
    'Ç': 'C',
    'Ć': 'C',
    'Ĉ': 'C',
    'Ċ': 'C',
    'Č': 'C',
    'È': 'E',
    'É': 'E',
    'Ê': 'E',
    'Ë': 'E',
    'Ē': 'E',
    'Ĕ': 'E',
    'Ė': 'E',
    'Ę': 'E',
    'Ě': 'E',
    'Ì': 'I',
    'Í': 'I',
    'Î': 'I',
    'Ï': 'I',
    'Ĩ': 'I',
    'Ī': 'I',
    'Ĭ': 'I',
    'Į': 'I',
    'Ñ': 'N',
    'Ń': 'N',
    'Ņ': 'N',
    'Ň': 'N',
    'Ò': 'O',
    'Ó': 'O',
    'Ô': 'O',
    'Õ': 'O',
    'Ö': 'O',
    'Ō': 'O',
    'Ŏ': 'O',
    'Ő': 'O',
    'Ù': 'U',
    'Ú': 'U',
    'Û': 'U',
    'Ü': 'U',
    'Ũ': 'U',
    'Ū': 'U',
    'Ŭ': 'U',
    'Ů': 'U',
    'Ű': 'U',
    'Ý': 'Y',
    'Ÿ': 'Y',
  };
  return folded[value.toUpperCase()] ?? value;
}

int compareArtistText(String left, String right) {
  final leftBucketIndex = artistQuickJumpKeys.indexOf(
    getArtistQuickJumpBucket(left),
  );
  final rightBucketIndex = artistQuickJumpKeys.indexOf(
    getArtistQuickJumpBucket(right),
  );
  if (leftBucketIndex != rightBucketIndex) {
    return leftBucketIndex.compareTo(rightBucketIndex);
  }

  final pinyinCompare = _compareNaturalText(
    _pinyinCompareKey(left),
    _pinyinCompareKey(right),
  );
  return pinyinCompare != 0
      ? pinyinCompare
      : _compareNaturalText(left.toLowerCase(), right.toLowerCase());
}

bool _isCjkUnifiedIdeograph(String value) {
  final codePoint = value.runes.first;
  return codePoint >= 0x3400 && codePoint <= 0x9fff;
}

String _pinyinCompareKey(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    if (_isCjkUnifiedIdeograph(character)) {
      buffer.write(
        PinyinHelper.getPinyinE(
          character,
          separator: '',
          defPinyin: character,
          format: PinyinFormat.WITHOUT_TONE,
        ),
      );
    } else {
      buffer.write(character);
    }
  }
  return buffer.toString().toLowerCase();
}

int _compareNaturalText(String left, String right) {
  final leftParts = _naturalTextParts(left);
  final rightParts = _naturalTextParts(right);
  final length =
      leftParts.length < rightParts.length
          ? leftParts.length
          : rightParts.length;

  for (var index = 0; index < length; index += 1) {
    final leftPart = leftParts[index];
    final rightPart = rightParts[index];
    final leftNumber = int.tryParse(leftPart);
    final rightNumber = int.tryParse(rightPart);
    if (leftNumber != null && rightNumber != null) {
      final numberCompare = leftNumber.compareTo(rightNumber);
      if (numberCompare != 0) {
        return numberCompare;
      }
      final lengthCompare = leftPart.length.compareTo(rightPart.length);
      if (lengthCompare != 0) {
        return lengthCompare;
      }
    } else {
      final textCompare = leftPart.compareTo(rightPart);
      if (textCompare != 0) {
        return textCompare;
      }
    }
  }

  return leftParts.length.compareTo(rightParts.length);
}

List<String> _naturalTextParts(String value) {
  return RegExp(
    r'\d+|\D+',
  ).allMatches(value).map((match) => match.group(0)!).toList();
}

List<String> getSongArtists(LibrarySong song) {
  final artists = song.artists.where((artist) => artist.isNotEmpty).toList();
  if (artists.isNotEmpty) {
    return artists;
  }

  return song.artist
      .split(RegExp(r'\s*(?:;|；|、|\|)\s*'))
      .map((artist) => artist.trim())
      .where((artist) => artist.isNotEmpty)
      .toList();
}

String displayArtists(LibrarySong song, SmPlayerI18n i18n) {
  final artists = getSongArtists(song);
  return artists.isEmpty
      ? i18n.t('common.artistUnknown')
      : artists.join(i18n.t('common.artistSeparator'));
}

String displayAlbum(LibrarySong song, SmPlayerI18n i18n) {
  return song.album.isEmpty ? i18n.t('common.albumUnknown') : song.album;
}

String formatDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final remainingSeconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

int evaluateString(String value, String keyword, [int offset = 0]) {
  if (value.isEmpty) {
    return 0;
  }

  if (value == keyword) {
    return 100 + offset;
  }

  final normalizedValue = value.toLowerCase();
  final normalizedKeyword = keyword.toLowerCase();

  if (normalizedValue == normalizedKeyword) {
    return 95 + offset;
  }

  if (value.startsWith(keyword)) {
    return 90 + offset;
  }

  if (normalizedValue.startsWith(normalizedKeyword)) {
    return 85 + offset;
  }

  if (value.contains(keyword)) {
    return 80 + offset;
  }

  if (normalizedValue.contains(normalizedKeyword)) {
    return 75 + offset;
  }

  if (normalizedKeyword.contains(normalizedValue)) {
    return 70 + offset;
  }

  final distance = _getEditDistance(value, keyword);
  final ratio =
      (distance * 100) ~/
      (value.length > keyword.length ? value.length : keyword.length);
  return ratio <= 60 ? 70 - ratio + offset : 0;
}

int _getEditDistance(String target, String given) {
  final rows = target.length;
  final columns = given.length;
  if (rows * columns == 0) {
    return rows + columns;
  }

  final dp = List.generate(
    rows + 1,
    (rowIndex) => List.generate(
      columns + 1,
      (columnIndex) =>
          rowIndex == 0
              ? columnIndex
              : columnIndex == 0
              ? rowIndex
              : 0,
    ),
  );

  for (var rowIndex = 1; rowIndex <= rows; rowIndex += 1) {
    for (var columnIndex = 1; columnIndex <= columns; columnIndex += 1) {
      final left = dp[rowIndex - 1][columnIndex] + 1;
      final down = dp[rowIndex][columnIndex - 1] + 1;
      final leftDown =
          dp[rowIndex - 1][columnIndex - 1] +
          (target[rowIndex - 1] == given[columnIndex - 1] ? 0 : 1);
      dp[rowIndex][columnIndex] = [
        left,
        down,
        leftDown,
      ].reduce((best, value) => value < best ? value : best);
    }
  }

  return dp[rows][columns];
}
