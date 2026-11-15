import 'dart:math';
import '../library/data/library_models.dart';
import '../library/ui/song_display_helpers.dart';

List<int> randomLibrarySongIds(List<LibrarySong> songs, int randomLimit) {
  return _randomItems(songs, randomLimit).map((song) => song.id).toList();
}

List<int> shuffleSongIds(List<LibrarySong> songs) {
  final shuffled = songs.toList()..shuffle(Random());
  return shuffled.map((song) => song.id).toList();
}

List<int> randomArtistSongIds(List<LibrarySong> songs, int randomLimit) {
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

List<int> randomAlbumSongIds(List<LibrarySong> songs, int randomLimit) {
  return _randomItems(
    _randomSongGroup(songs, (song) => song.album),
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> randomPlaylistSongIds(
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

List<int> randomFolderSongIds(
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
                        (song) => isSongDirectlyInFolder(song, folder.path),
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

List<int> randomRecentAddedSongIds(List<LibrarySong> songs, int randomLimit) {
  final sorted =
      songs.toList()
        ..sort((left, right) => right.dateAdded.compareTo(left.dateAdded));
  return _randomItems(
    sorted.take(500).toList(),
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> randomMostPlayedSongIds(List<LibrarySong> songs, int randomLimit) {
  return shuffleSongIds(
    _playedSongs(songs, randomLimit, descending: true),
  ).take(randomLimit).toList();
}

List<int> randomLeastPlayedSongIds(List<LibrarySong> songs, int randomLimit) {
  return shuffleSongIds(
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

bool isSongDirectlyInFolder(LibrarySong song, String folderPath) {
  return randomSongFolderPath(song.path) == folderPath;
}

String randomSongFolderPath(String path) {
  final separatorIndex = max(path.lastIndexOf('\\'), path.lastIndexOf('/'));
  return separatorIndex > -1 ? path.substring(0, separatorIndex) : '';
}
