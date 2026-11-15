import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import '../data/library_text.dart';
export '../data/library_text.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_time_codec.dart';
import '../data/library_models.dart';
import 'menu_flyout.dart';
import 'song_display_helpers.dart' as song_display;

part 'artist_group.dart';
part 'album_group.dart';
part 'artist_album_virtual_window.dart';

const artistRowContentHeight = 64.0;
const artistRowSpacing = 2.0;
const artistRowHeight = artistRowContentHeight + artistRowSpacing;
const artistOverscanRows = 10;
const artistAlbumCardHeaderHeight = 112.0;
const artistAlbumSongRowHeight = 82.0;
const artistAlbumCardGap = 22.0;
const artistAlbumOverscanRows = 2;
const compactArtistAlbumCardHeaderHeight = 88.0;
const compactArtistAlbumSongRowHeight = 78.0;
const compactArtistAlbumCardGap = 12.0;
const artistCountQuickJumpKeys = [
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  '11',
  '12',
  '13',
  '14',
  '15',
  '16',
  '17',
  '18',
  '19',
  '20',
  '20+',
];

enum ArtistSortCriterion { name, songCount, albumCount, reverse }

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
          artworkPath: artworkSong.thumbnailPath,
        );
      }).toList();

  artists.sort((left, right) => compareArtistText(left.name, right.name));
  return artists;
}

List<ArtistGroup> sortArtists(
  List<ArtistGroup> artists,
  ArtistSortCriterion criterion,
) {
  final sorted = artists.toList();
  switch (criterion) {
    case ArtistSortCriterion.name:
      sorted.sort((left, right) => compareArtistText(left.name, right.name));
      return sorted;
    case ArtistSortCriterion.songCount:
      sorted.sort((left, right) {
        final countCompare = right.songCount.compareTo(left.songCount);
        return countCompare != 0
            ? countCompare
            : compareArtistText(left.name, right.name);
      });
      return sorted;
    case ArtistSortCriterion.albumCount:
      sorted.sort((left, right) {
        final countCompare = right.albumCount.compareTo(left.albumCount);
        return countCompare != 0
            ? countCompare
            : compareArtistText(left.name, right.name);
      });
      return sorted;
    case ArtistSortCriterion.reverse:
      return sorted.reversed.toList();
  }
}

String artistSortLabel(SmPlayerI18n i18n, ArtistSortCriterion criterion) {
  switch (criterion) {
    case ArtistSortCriterion.name:
      return i18n.t('artists.sort.name');
    case ArtistSortCriterion.songCount:
      return i18n.t('artists.sort.songCount');
    case ArtistSortCriterion.albumCount:
      return i18n.t('artists.sort.albumCount');
    case ArtistSortCriterion.reverse:
      return i18n.t('local.sortReverseList');
  }
}

List<MenuFlyoutItem> artistSortMenuItems(
  SmPlayerI18n i18n,
  ArtistSortCriterion sortCriterion,
  ValueChanged<ArtistSortCriterion> onChangeArtistSort,
) {
  return [
    MenuFlyoutItem(
      key: 'artists-sort-reverse',
      text: i18n.t('local.sortReverseList'),
      onPressed: () {
        onChangeArtistSort(ArtistSortCriterion.reverse);
      },
    ),
    const MenuFlyoutItem.separator(key: 'artists-sort-separator'),
    MenuFlyoutItem(
      key: 'artists-sort-name',
      text: artistSortLabel(i18n, ArtistSortCriterion.name),
      icon:
          sortCriterion == ArtistSortCriterion.name
              ? FluentIcons.checkmark_20_regular
              : null,
      onPressed: () {
        onChangeArtistSort(ArtistSortCriterion.name);
      },
    ),
    MenuFlyoutItem(
      key: 'artists-sort-song-count',
      text: artistSortLabel(i18n, ArtistSortCriterion.songCount),
      icon:
          sortCriterion == ArtistSortCriterion.songCount
              ? FluentIcons.checkmark_20_regular
              : null,
      onPressed: () {
        onChangeArtistSort(ArtistSortCriterion.songCount);
      },
    ),
    MenuFlyoutItem(
      key: 'artists-sort-album-count',
      text: artistSortLabel(i18n, ArtistSortCriterion.albumCount),
      icon:
          sortCriterion == ArtistSortCriterion.albumCount
              ? FluentIcons.checkmark_20_regular
              : null,
      onPressed: () {
        onChangeArtistSort(ArtistSortCriterion.albumCount);
      },
    ),
  ];
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
  return headerHeight + album.songCount * songRowHeight + cardGap;
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

List<String> artistQuickJumpKeysForSort(ArtistSortCriterion sortCriterion) {
  switch (sortCriterion) {
    case ArtistSortCriterion.songCount:
    case ArtistSortCriterion.albumCount:
      return artistCountQuickJumpKeys;
    case ArtistSortCriterion.name:
    case ArtistSortCriterion.reverse:
      return artistQuickJumpKeys;
  }
}

Map<String, int> buildArtistQuickJumpMap(
  List<ArtistGroup> artists, [
  ArtistSortCriterion sortCriterion = ArtistSortCriterion.name,
]) {
  final indexes = <String, int>{};
  for (var index = 0; index < artists.length; index += 1) {
    indexes.putIfAbsent(
      getArtistQuickJumpBucketForSort(artists[index], sortCriterion),
      () => index,
    );
  }
  return indexes;
}

String getArtistQuickJumpBucketForSort(
  ArtistGroup artist,
  ArtistSortCriterion sortCriterion,
) {
  switch (sortCriterion) {
    case ArtistSortCriterion.songCount:
      return getArtistCountQuickJumpBucket(artist.songCount);
    case ArtistSortCriterion.albumCount:
      return getArtistCountQuickJumpBucket(artist.albumCount);
    case ArtistSortCriterion.name:
    case ArtistSortCriterion.reverse:
      return getArtistQuickJumpBucket(artist.name);
  }
}

String getArtistCountQuickJumpBucket(int count) {
  return count > 20 ? '20+' : '$count';
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
