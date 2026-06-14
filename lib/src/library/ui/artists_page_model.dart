import 'package:lpinyin/lpinyin.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_time_codec.dart';
import '../data/library_models.dart';
import 'song_display_helpers.dart' as song_display;

part 'artist_group.dart';
part 'album_group.dart';
part 'artist_album_virtual_window.dart';

const artistRowContentHeight = 64.0;
const artistRowSpacing = 2.0;
const artistRowHeight = artistRowContentHeight + artistRowSpacing;
const artistOverscanRows = 10;
const artistAlbumCardHeaderHeight = 112.0;
const artistAlbumSongRowHeight = 48.0;
const artistAlbumCardGap = 22.0;
const artistAlbumOverscanRows = 2;
const compactArtistAlbumCardHeaderHeight = 88.0;
const compactArtistAlbumSongRowHeight = 42.0;
const compactArtistAlbumCardGap = 12.0;
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
        final songsByAlbumOrder =
            entry.value.toList()..sort((left, right) {
              final albumCompare = compareArtistText(
                displayAlbum(left, i18n),
                displayAlbum(right, i18n),
              );
              return albumCompare != 0
                  ? albumCompare
                  : compareArtistText(left.title, right.title);
            });
        final artworkSong =
            songsByAlbumOrder.any((song) => song.thumbnailPath.isNotEmpty)
                ? songsByAlbumOrder.firstWhere(
                  (song) => song.thumbnailPath.isNotEmpty,
                )
                : (entry.value.toList()..sort(
                      (left, right) => _parseSongDateAdded(
                        right.dateAdded,
                      ).compareTo(_parseSongDateAdded(left.dateAdded)),
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

DateTime _parseSongDateAdded(String rawValue) {
  return LibraryTimeCodec.parseStoredDateTime(rawValue);
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
        final albumSongs = entry.value.toList();
        return AlbumGroup(
          name: entry.key,
          songs: albumSongs,
          duration: albumSongs.fold(0, (total, song) => total + song.duration),
        );
      }).toList();

  albums.sort((left, right) => compareArtistText(left.name, right.name));
  return albums;
}

double getEstimatedArtistAlbumHeight(
  AlbumGroup album, {
  required bool compact,
}) {
  final headerHeight =
      compact
          ? compactArtistAlbumCardHeaderHeight
          : artistAlbumCardHeaderHeight;
  final songRowHeight =
      compact ? compactArtistAlbumSongRowHeight : artistAlbumSongRowHeight;
  final cardGap = compact ? compactArtistAlbumCardGap : artistAlbumCardGap;
  return headerHeight + album.songs.length * songRowHeight + cardGap;
}

ArtistAlbumVirtualWindow getArtistAlbumVirtualWindow(
  List<double> heights,
  double scrollTop,
  double viewportHeight,
) {
  final overscanHeight =
      artistAlbumOverscanRows *
      (artistAlbumCardHeaderHeight + artistAlbumSongRowHeight);
  final windowTop =
      (scrollTop - overscanHeight).clamp(0.0, double.infinity).toDouble();
  final windowBottom = scrollTop + viewportHeight + overscanHeight;
  var startIndex = 0;
  var endIndex = heights.length;
  var offset = 0.0;
  var topSpacerHeight = 0.0;

  for (var index = 0; index < heights.length; index += 1) {
    final nextOffset = offset + heights[index];
    if (nextOffset > windowTop) {
      startIndex = index;
      topSpacerHeight = offset;
      break;
    }
    offset = nextOffset;
  }

  offset = topSpacerHeight;
  for (var index = startIndex; index < heights.length; index += 1) {
    offset += heights[index];
    if (offset >= windowBottom) {
      endIndex = index + 1;
      break;
    }
  }

  final totalHeight = heights.fold(0.0, (sum, height) => sum + height);
  final renderedHeight = heights
      .sublist(startIndex, endIndex)
      .fold(0.0, (sum, height) => sum + height);
  final bottomSpacerHeight =
      (totalHeight - topSpacerHeight - renderedHeight)
          .clamp(0.0, double.infinity)
          .toDouble();

  return ArtistAlbumVirtualWindow(
    startIndex: startIndex,
    endIndex: endIndex,
    topSpacerHeight: topSpacerHeight,
    bottomSpacerHeight: bottomSpacerHeight,
  );
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

  final electronBucketOverride =
      _electronCjkQuickJumpBucketOverrides[firstChar];
  if (electronBucketOverride != null) {
    return electronBucketOverride;
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

const _electronCjkQuickJumpBucketOverrides = {
  // Electron's zh-Hans-CN-u-co-pinyin collator places this polyphonic
  // character at the Z boundary.
  '长': 'Z',
};

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
    'Ď': 'D',
    'È': 'E',
    'É': 'E',
    'Ê': 'E',
    'Ë': 'E',
    'Ē': 'E',
    'Ĕ': 'E',
    'Ė': 'E',
    'Ę': 'E',
    'Ě': 'E',
    'Ĝ': 'G',
    'Ğ': 'G',
    'Ġ': 'G',
    'Ģ': 'G',
    'Ĥ': 'H',
    'Ì': 'I',
    'Í': 'I',
    'Î': 'I',
    'Ï': 'I',
    'Ĩ': 'I',
    'Ī': 'I',
    'Ĭ': 'I',
    'Į': 'I',
    'İ': 'I',
    'Ĵ': 'J',
    'Ĺ': 'L',
    'Ļ': 'L',
    'Ľ': 'L',
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
    'Ŕ': 'R',
    'Ŗ': 'R',
    'Ř': 'R',
    'Ś': 'S',
    'Ŝ': 'S',
    'Ş': 'S',
    'Š': 'S',
    'Ţ': 'T',
    'Ť': 'T',
    'Ù': 'U',
    'Ú': 'U',
    'Û': 'U',
    'Ü': 'U',
    'Ũ': 'U',
    'Ū': 'U',
    'Ŭ': 'U',
    'Ů': 'U',
    'Ű': 'U',
    'Ų': 'U',
    'Ŵ': 'W',
    'Ý': 'Y',
    'Ŷ': 'Y',
    'Ÿ': 'Y',
    'Ź': 'Z',
    'Ż': 'Z',
    'Ž': 'Z',
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
  return song_display.songArtists(song);
}

String displayArtists(LibrarySong song, SmPlayerI18n i18n) {
  return song_display.displayArtists(song, i18n);
}

String displayAlbum(LibrarySong song, SmPlayerI18n i18n) {
  return song_display.displayAlbum(song, i18n);
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
