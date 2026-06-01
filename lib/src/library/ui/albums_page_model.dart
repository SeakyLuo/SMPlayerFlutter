part of 'albums_page.dart';

const _albumTileTrackWidth = 180.0;
const _albumColumnGap = 30.0;
const _albumQuickJumpWidth = 22.0;
const _albumGridShellGap = 4.0;
const _albumRowHeight = 250.0;
const _albumCompactRowHeight = 234.0;
const _albumOverscanRows = 2;

class AlbumView extends AlbumTileData {
  const AlbumView({
    required super.name,
    required super.artist,
    required super.songs,
    required super.duration,
    required super.artworkSong,
    required this.artists,
  });

  final List<String> artists;
}

List<AlbumView> buildAlbumViews(List<LibrarySong> songs, SmPlayerI18n i18n) {
  final groups = <String, List<LibrarySong>>{};
  for (final song in songs) {
    final albumName = _electronAlbumName(song, i18n);
    final group = groups[albumName] ?? <LibrarySong>[];
    group.add(song);
    groups[albumName] = group;
  }

  return groups.entries.map((entry) {
    final sourceAlbumSongs = entry.value;
    final albumSongs =
        sourceAlbumSongs.toList()
          ..sort((left, right) => compareArtistText(left.title, right.title));
    final artists = getAlbumArtists(albumSongs, i18n);
    final artworkSong =
        sourceAlbumSongs.any((song) => song.thumbnailPath.isNotEmpty)
            ? sourceAlbumSongs.firstWhere(
              (song) => song.thumbnailPath.isNotEmpty,
            )
            : sourceAlbumSongs.first;
    return AlbumView(
      name: entry.key,
      artists: artists,
      artist: artists.first,
      songs: albumSongs,
      artworkSong: artworkSong,
      duration: albumSongs.fold(0, (total, song) => total + song.duration),
    );
  }).toList();
}

String _electronAlbumName(LibrarySong song, SmPlayerI18n i18n) {
  return song.album.isEmpty ? i18n.t('common.albumUnknown') : song.album;
}

List<String> getAlbumArtists(List<LibrarySong> songs, SmPlayerI18n i18n) {
  final artistCounts = <String, int>{};
  for (final song in songs) {
    final artists = getSongArtists(song);
    final artistNames =
        artists.isEmpty ? [i18n.t('common.artistUnknown')] : artists;
    for (final artist in artistNames) {
      artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
    }
  }

  final entries =
      artistCounts.entries.toList()..sort((left, right) {
        if (left.value != right.value) {
          return right.value.compareTo(left.value);
        }
        return compareArtistText(left.key, right.key);
      });
  return entries.map((entry) => entry.key).toList();
}

List<AlbumView> searchAlbums(List<AlbumView> albums, String query) {
  final keyword = query.trim();
  if (keyword.isEmpty) {
    return albums;
  }

  final scored =
      albums
          .map(
            (album) => (
              album: album,
              score: evaluateString(album.name, keyword),
            ),
          )
          .where((result) => result.score > 0)
          .toList();
  scored.sort((left, right) => right.score.compareTo(left.score));
  return scored.map((result) => result.album).toList();
}

Map<String, int> buildAlbumQuickJumpMap(List<AlbumView> albums) {
  final indexes = <String, int>{};
  for (var index = 0; index < albums.length; index += 1) {
    indexes.putIfAbsent(
      getArtistQuickJumpBucket(albums[index].name),
      () => index,
    );
  }
  return indexes;
}

List<AlbumView> sortAlbums(
  List<AlbumView> albums,
  AlbumSortCriterion criterion,
) {
  final sorted = albums.toList();
  switch (criterion) {
    case AlbumSortCriterion.artist:
      sorted.sort((left, right) {
        final artistCompare = compareArtistText(left.artist, right.artist);
        return artistCompare != 0
            ? artistCompare
            : compareArtistText(left.name, right.name);
      });
      return sorted;
    case AlbumSortCriterion.name:
    case AlbumSortCriterion.defaultSort:
      sorted.sort((left, right) {
        final nameCompare = compareArtistText(left.name, right.name);
        return nameCompare != 0
            ? nameCompare
            : compareArtistText(left.artist, right.artist);
      });
      return sorted;
    case AlbumSortCriterion.reverse:
      return sorted.reversed.toList();
  }
}

String _albumSortLabel(SmPlayerI18n i18n, AlbumSortCriterion criterion) {
  switch (criterion) {
    case AlbumSortCriterion.artist:
      return i18n.t('albums.sort.artist');
    case AlbumSortCriterion.name:
      return i18n.t('albums.sort.name');
    case AlbumSortCriterion.reverse:
      return i18n.t('local.sortReverseList');
    case AlbumSortCriterion.defaultSort:
      return i18n.t('albums.sort.default');
  }
}

List<MenuFlyoutItem> _albumSortMenuItems(
  SmPlayerI18n i18n,
  AlbumSortCriterion sortCriterion,
  ValueChanged<AlbumSortCriterion> onChangeAlbumSort,
) {
  return [
    MenuFlyoutItem(
      key: 'albums-sort-reverse',
      text: i18n.t('local.sortReverseList'),
      onPressed: () {
        onChangeAlbumSort(AlbumSortCriterion.reverse);
      },
    ),
    MenuFlyoutItem(
      key: 'albums-sort-default',
      text: i18n.t('albums.sort.default'),
      icon:
          sortCriterion == AlbumSortCriterion.defaultSort
              ? FluentIcons.checkmark_20_regular
              : null,
      onPressed: () {
        onChangeAlbumSort(AlbumSortCriterion.defaultSort);
      },
    ),
    MenuFlyoutItem(
      key: 'albums-sort-name',
      text: i18n.t('albums.sort.name'),
      icon:
          sortCriterion == AlbumSortCriterion.name
              ? FluentIcons.checkmark_20_regular
              : null,
      onPressed: () {
        onChangeAlbumSort(AlbumSortCriterion.name);
      },
    ),
    MenuFlyoutItem(
      key: 'albums-sort-artist',
      text: i18n.t('albums.sort.artist'),
      icon:
          sortCriterion == AlbumSortCriterion.artist
              ? FluentIcons.checkmark_20_regular
              : null,
      onPressed: () {
        onChangeAlbumSort(AlbumSortCriterion.artist);
      },
    ),
  ];
}
