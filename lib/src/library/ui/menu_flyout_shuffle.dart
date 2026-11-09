part of 'menu_flyout_helpers.dart';

List<MenuFlyoutItem> buildShuffleMenuFlyoutItems({
  required SmPlayerI18n i18n,
  required List<LibrarySong> songs,
  required List<LibrarySong> librarySongs,
  required List<LibrarySong> recentSongs,
  required List<LibraryPlaylist> playlists,
  required List<LibraryFolder> folders,
  required int randomLimit,
  required ValueChanged<List<int>> onPlaySongs,
}) {
  void playSongs(List<LibrarySong> sourceSongs) {
    onPlaySongs(_randomLibrary(sourceSongs, randomLimit));
  }

  void playAllSongs(List<LibrarySong> sourceSongs) {
    onPlaySongs(_shuffleSongIds(sourceSongs));
  }

  final playableFolders =
      folders
          .where(
            (folder) => librarySongs.any(
              (song) => _isSongDirectlyInFolder(song, folder.path),
            ),
          )
          .toList();
  final playablePlaylists =
      playlists.where((playlist) => playlist.songIds.isNotEmpty).toList();
  final favoriteSongs = librarySongs.where((song) => song.favorite).toList();
  final items = <MenuFlyoutItem>[];

  if (librarySongs.isNotEmpty) {
    items.addAll([
      MenuFlyoutItem(
        key: 'library',
        text: i18n.t('random.musicLibrary'),
        icon: FluentIcons.library_24_regular,
        onPressed: () => playSongs(librarySongs),
      ),
      MenuFlyoutItem(
        key: 'artist',
        text: i18n.t('common.artist'),
        icon: FluentIcons.people_24_regular,
        onPressed: () => onPlaySongs(_randomArtist(librarySongs, randomLimit)),
      ),
      MenuFlyoutItem(
        key: 'album',
        text: i18n.t('common.album'),
        useAlbumIcon: true,
        onPressed: () => onPlaySongs(_randomAlbum(librarySongs, randomLimit)),
      ),
    ]);
  }

  if (playableFolders.isNotEmpty) {
    items.add(
      MenuFlyoutItem(
        key: 'folder',
        text: i18n.t('random.localFolder'),
        icon: FluentIcons.hard_drive_24_regular,
        onPressed: () {
          onPlaySongs(
            _randomFolder(librarySongs, playableFolders, randomLimit),
          );
        },
      ),
    );
  }

  if (librarySongs.isNotEmpty) {
    items.add(
      MenuFlyoutItem(
        key: 'recent-added',
        text: i18n.t('common.recentAdded'),
        icon: FluentIcons.clock_24_regular,
        onPressed:
            () => onPlaySongs(_randomRecentAdded(librarySongs, randomLimit)),
      ),
    );
  }

  if (recentSongs.isNotEmpty) {
    items.add(
      MenuFlyoutItem(
        key: 'recent-played',
        text: i18n.t('random.recentPlayed'),
        icon: FluentIcons.clock_24_regular,
        onPressed: () => onPlaySongs(_shuffleSongIds(recentSongs)),
      ),
    );
  }

  if (librarySongs.length > randomLimit) {
    items.addAll([
      MenuFlyoutItem(
        key: 'most-played',
        text: i18n.t('random.mostPlayed'),
        icon: FluentIcons.clock_24_regular,
        onPressed:
            () => onPlaySongs(_randomMostPlayed(librarySongs, randomLimit)),
      ),
      MenuFlyoutItem(
        key: 'least-played',
        text: i18n.t('random.leastPlayed'),
        icon: FluentIcons.clock_24_regular,
        onPressed:
            () => onPlaySongs(_randomLeastPlayed(librarySongs, randomLimit)),
      ),
    ]);
  }

  if (songs.isNotEmpty) {
    items.add(
      MenuFlyoutItem(
        key: 'now-playing',
        text: i18n.t('common.nowPlaying'),
        icon: FluentIcons.headphones_24_regular,
        onPressed: () => playAllSongs(songs),
      ),
    );
  }

  if (favoriteSongs.isNotEmpty) {
    items.add(
      MenuFlyoutItem(
        key: 'my-favorites',
        text: i18n.t('common.myFavorites'),
        icon: FluentIcons.heart_24_regular,
        onPressed: () => playSongs(favoriteSongs),
      ),
    );
  }

  if (playablePlaylists.isNotEmpty) {
    items.add(
      MenuFlyoutItem(
        key: 'playlist',
        text: i18n.t('common.playlist'),
        usePlaylistIcon: true,
        onPressed: () {
          onPlaySongs(
            _randomPlaylist(librarySongs, playablePlaylists, randomLimit),
          );
        },
      ),
    );
  }

  return items;
}

List<int> _randomLibrary(List<LibrarySong> songs, int randomLimit) {
  return _randomItems(songs, randomLimit).map((song) => song.id).toList();
}

List<int> _shuffleSongIds(List<LibrarySong> songs) {
  final shuffled = songs.toList()..shuffle(Random());
  return shuffled.map((song) => song.id).toList();
}

List<int> _randomArtist(List<LibrarySong> songs, int randomLimit) {
  final songsByArtist = <String, List<LibrarySong>>{};
  for (final song in songs) {
    final artists = _randomSongArtists(song);
    for (final artist in artists) {
      songsByArtist[artist] = [...(songsByArtist[artist] ?? []), song];
    }
  }
  final group = _randomItem(songsByArtist.values.toList());
  return _randomItems(group, randomLimit).map((song) => song.id).toList();
}

List<int> _randomAlbum(List<LibrarySong> songs, int randomLimit) {
  return _randomItems(
    _randomSongGroup(songs, (song) => song.album),
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomPlaylist(
  List<LibrarySong> songs,
  List<LibraryPlaylist> playlists,
  int randomLimit,
) {
  final songsById = {for (final song in songs) song.id: song};
  final playlist = _randomItem(playlists);
  final playlistSongs =
      playlist.songIds
          .map((songId) => songsById[songId])
          .whereType<LibrarySong>()
          .toList();
  return _randomItems(
    playlistSongs,
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomFolder(
  List<LibrarySong> songs,
  List<LibraryFolder> folders,
  int randomLimit,
) {
  final playableFolders =
      folders
          .map(
            (folder) => (
              folder: folder,
              songs:
                  songs
                      .where(
                        (song) => _isSongDirectlyInFolder(song, folder.path),
                      )
                      .toList(),
            ),
          )
          .where((entry) => entry.songs.isNotEmpty)
          .toList();
  if (playableFolders.isEmpty) {
    return const [];
  }
  return _randomItems(
    _randomItem(playableFolders).songs,
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomRecentAdded(List<LibrarySong> songs, int randomLimit) {
  final sorted =
      songs.toList()
        ..sort((left, right) => right.dateAdded.compareTo(left.dateAdded));
  return _randomItems(
    sorted.take(500).toList(),
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomMostPlayed(List<LibrarySong> songs, int randomLimit) {
  return _shuffleSongIds(
    _playedSongs(songs, randomLimit, descending: true),
  ).take(randomLimit).toList();
}

List<int> _randomLeastPlayed(List<LibrarySong> songs, int randomLimit) {
  return _shuffleSongIds(
    _playedSongs(songs, randomLimit, descending: false),
  ).take(randomLimit).toList();
}

List<LibrarySong> _playedSongs(
  List<LibrarySong> songs,
  int randomLimit, {
  required bool descending,
}) {
  final songsByPlayCount = <int, List<LibrarySong>>{};
  for (final song in songs) {
    songsByPlayCount[song.playCount] = [
      ...(songsByPlayCount[song.playCount] ?? const <LibrarySong>[]),
      song,
    ];
  }

  final playCounts =
      songsByPlayCount.keys.toList()..sort(
        (left, right) =>
            descending ? right.compareTo(left) : left.compareTo(right),
      );
  final selectedSongs = <LibrarySong>[];
  for (final playCount in playCounts) {
    if (selectedSongs.length > randomLimit) {
      break;
    }
    selectedSongs.addAll(songsByPlayCount[playCount]!);
  }
  return selectedSongs;
}

List<LibrarySong> _randomSongGroup(
  List<LibrarySong> songs,
  String Function(LibrarySong song) getKey,
) {
  final groups = <String, List<LibrarySong>>{};
  for (final song in songs) {
    final key = getKey(song);
    groups[key] = [...(groups[key] ?? []), song];
  }
  return _randomItem(groups.values.toList()).toList()..shuffle(Random());
}

List<T> _randomItems<T>(List<T> items, int count) {
  if (items.length <= count) {
    return items.toList()..shuffle(Random());
  }

  final indices = <int>{};
  final random = Random();
  while (indices.length < count) {
    indices.add(random.nextInt(items.length));
  }
  return [for (final index in indices) items[index]];
}

T _randomItem<T>(List<T> items) {
  return items[Random().nextInt(items.length)];
}

List<String> _randomSongArtists(LibrarySong song) {
  final artists = songArtists(song);
  return artists.isEmpty ? const ['Unknown artist'] : artists;
}

bool _isSongDirectlyInFolder(LibrarySong song, String folderPath) {
  return _getFileParentPath(song.path) == folderPath;
}

String _getFileParentPath(String path) {
  final separatorIndex = max(path.lastIndexOf('\\'), path.lastIndexOf('/'));
  return separatorIndex > -1 ? path.substring(0, separatorIndex) : '';
}
