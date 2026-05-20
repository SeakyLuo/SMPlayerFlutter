import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/recent/recent_page_model.dart';

const sortOptions = [
  PlaylistSortCriterion.title,
  PlaylistSortCriterion.artist,
  PlaylistSortCriterion.album,
  PlaylistSortCriterion.duration,
  PlaylistSortCriterion.playCount,
  PlaylistSortCriterion.dateAdded,
];

const captions = {
  'album': 'common.album',
  'artist': 'common.artist',
  'cancel': 'common.cancel',
  'clear': 'common.clear',
  'delete': 'playlists.delete',
  'duration': 'common.duration',
  'editArtwork': 'albums.editArtwork',
  'multiSelect': 'albums.multiSelect',
  'name': 'common.name',
  'play': 'context.play',
  'removeSelected': 'playlists.removeSelected',
  'rename': 'playlists.rename',
  'save': 'playlists.save',
  'shuffle': 'nowPlaying.randomPlay',
  'sort': 'common.sort',
  'preferenceSettings': 'settings.preferenceSettings',
  'songArtist': 'headeredPlaylist.songArtist',
  'songsPrefix': 'headeredPlaylist.songsPrefix',
  'sort.album': 'table.album',
  'sort.artist': 'table.artist',
  'sort.date-added': 'table.dateAdded',
  'sort.duration': 'table.duration',
  'sort.play-count': 'table.playCount',
  'sort.reverse': 'albums.sort.reverse',
  'sort.title': 'table.title',
};

String getHeaderPlaylistInfo(List<LibrarySong> songs, SmPlayerI18n i18n) {
  final countText = '${i18n.t('headeredPlaylist.songsPrefix')}${songs.length}';
  if (songs.length < 2) {
    return countText;
  }

  final duration = songs.fold<int>(0, (total, song) => total + song.duration);
  return '$countText • ${formatDuration(duration)}';
}

String getAlbumPreferenceDisplayName(
  String albumName,
  List<LibrarySong> songs,
  SmPlayerI18n i18n,
) {
  final albumTitle =
      albumName.isEmpty ? i18n.t('common.albumUnknown') : albumName;
  final firstSong = songs.firstOrNull;
  final artist =
      firstSong == null
          ? i18n.t('common.artistUnknown')
          : _displayArtistsForPreference(firstSong, i18n);
  return '$albumTitle - $artist';
}

String _displayArtistsForPreference(LibrarySong song, SmPlayerI18n i18n) {
  final artists =
      song.artists.where((artist) => artist.trim().isNotEmpty).toList();
  if (artists.isNotEmpty) {
    return artists.join(i18n.t('common.artistSeparator'));
  }
  return song.artist.isEmpty ? i18n.t('common.artistUnknown') : song.artist;
}

List<LibrarySong> sortSongs(
  List<LibrarySong> songs,
  PlaylistSortCriterion criterion,
) {
  final sortedSongs = songs.toList();
  sortedSongs.sort((left, right) {
    return switch (criterion) {
      PlaylistSortCriterion.artist => displayArtists(
        left,
      ).compareTo(displayArtists(right)),
      PlaylistSortCriterion.album => left.album.compareTo(right.album),
      PlaylistSortCriterion.duration => left.duration.compareTo(right.duration),
      PlaylistSortCriterion.playCount => left.playCount.compareTo(
        right.playCount,
      ),
      PlaylistSortCriterion.dateAdded => left.dateAdded.compareTo(
        right.dateAdded,
      ),
      PlaylistSortCriterion.title => left.title.compareTo(right.title),
    };
  });
  return sortedSongs;
}

PlaylistSortCriterion inferSortCriterion(List<LibrarySong> songs) {
  for (final criterion in sortOptions) {
    final sortedSongIds =
        sortSongs(songs, criterion).map((song) => song.id).toList();
    if (sortedSongIds.indexed.every(
      (entry) => entry.$2 == songs[entry.$1].id,
    )) {
      return criterion;
    }
  }

  return PlaylistSortCriterion.title;
}

bool isBadNewPlaylistName(String name, SmPlayerI18n i18n) {
  return name == i18n.t('common.nowPlaying') ||
      name == i18n.t('common.myFavorites');
}

String validatePlaylistName(
  String name,
  List<LibraryPlaylist> playlists,
  String currentName,
  SmPlayerI18n i18n,
) {
  if (name.isEmpty) {
    return i18n.t('playlists.nameEmpty');
  }

  if (name.length > 50) {
    return i18n.t('playlists.nameTooLong');
  }

  if (playlists.any(
    (playlist) => playlist.name != currentName && playlist.name == name,
  )) {
    return i18n.t('playlists.nameUsed');
  }

  if (name.contains('+++++') || name.contains('{0}') || name.contains('{1}')) {
    return i18n.t('playlists.nameSpecial');
  }

  return '';
}

String getNextPlaylistName(String name, List<LibraryPlaylist> playlists) {
  if (name.isEmpty) {
    return '';
  }

  final playlistNames = playlists.map((playlist) => playlist.name).toSet();
  final siblingCount =
      playlists.where((playlist) => playlist.name.startsWith(name)).length;
  for (var index = 1; index <= siblingCount; index += 1) {
    final nextName = '$name ($index)';
    if (!playlistNames.contains(nextName)) {
      return nextName;
    }
  }

  return name;
}

List<int> shuffleSongIds(List<int> songIds) {
  return songIds.toList()..shuffle();
}

String getParentFolderPath(String filePath) {
  final index = [
    filePath.lastIndexOf('\\'),
    filePath.lastIndexOf('/'),
  ].reduce((left, right) => left > right ? left : right);
  return filePath.substring(0, index);
}

String captionForHeaderedPlaylist(
  SmPlayerI18n i18n,
  String key, [
  Map<String, Object>? values,
]) {
  return i18n.t(captions[key] ?? key, values ?? const {});
}

String sortCaptionKey(PlaylistSortCriterion criterion) {
  return switch (criterion) {
    PlaylistSortCriterion.album => 'sort.album',
    PlaylistSortCriterion.artist => 'sort.artist',
    PlaylistSortCriterion.dateAdded => 'sort.date-added',
    PlaylistSortCriterion.duration => 'sort.duration',
    PlaylistSortCriterion.playCount => 'sort.play-count',
    PlaylistSortCriterion.title => 'sort.title',
  };
}
