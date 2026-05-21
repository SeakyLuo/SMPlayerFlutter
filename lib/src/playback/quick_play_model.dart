import 'dart:math';

import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

const quickPlayDefaultLimit = 100;
const _randomPreferenceItems = 5;

List<int> quickPlaySongIds({
  required List<LibrarySong> songs,
  required List<LibraryPlaylist> playlists,
  required List<LibraryFolder> folders,
  required PreferenceSettingsSnapshot preferences,
  int randomLimit = quickPlayDefaultLimit,
}) {
  final songsById = {for (final song in songs) song.id: song};
  final playlistsById = {
    for (final playlist in playlists) playlist.id: playlist,
  };
  final foldersById = {for (final folder in folders) folder.id: folder};
  final selectedSongs = <int, LibrarySong>{};

  _addUniqueSongs(selectedSongs, _randomItems(songs, randomLimit * 2));

  if (preferences.enabled[PreferenceSectionKey.songs] == true) {
    for (final item in _enabledPreferenceItems(preferences.songs)) {
      final song = songsById[int.parse(item.itemId)];
      if (song != null) {
        _addUniqueSong(selectedSongs, song);
      }
    }
  }

  if (preferences.enabled[PreferenceSectionKey.artists] == true) {
    final preferredSongs =
        _enabledPreferenceItems(preferences.artists)
            .expand(
              (item) => _randomItems(
                _randomItems(
                  songs
                      .where((song) => _songArtists(song).contains(item.itemId))
                      .toList(),
                  _randomPreferredItemCount(item.level),
                ),
                _randomPreferenceItems,
              ),
            )
            .toList();
    _addUniqueSongs(selectedSongs, preferredSongs);
  }

  if (preferences.enabled[PreferenceSectionKey.albums] == true) {
    final preferredSongs =
        _enabledPreferenceItems(preferences.albums)
            .expand(
              (item) => _randomItems(
                _randomItems(
                  songs.where((song) => song.album == item.itemId).toList(),
                  _randomPreferredItemCount(item.level),
                ),
                _randomPreferenceItems,
              ),
            )
            .toList();
    _addUniqueSongs(selectedSongs, preferredSongs);
  }

  if (preferences.enabled[PreferenceSectionKey.playlists] == true) {
    final preferredSongs =
        _enabledPreferenceItems(preferences.playlists).expand((item) {
          final playlist = playlistsById[int.parse(item.itemId)];
          if (playlist == null) {
            return const <LibrarySong>[];
          }
          return _randomItems(
            playlist.songIds
                .map((songId) => songsById[songId])
                .whereType<LibrarySong>()
                .toList(),
            _randomPreferredItemCount(item.level),
          );
        }).toList();
    _addUniqueSongs(
      selectedSongs,
      _randomItems(preferredSongs, _randomPreferenceItems),
    );
  }

  if (preferences.enabled[PreferenceSectionKey.folders] == true) {
    final preferredSongs =
        _enabledPreferenceItems(preferences.folders).expand((item) {
          final folderId = int.tryParse(item.itemId);
          final folder = folderId == null ? null : foldersById[folderId];
          if (folder == null) {
            return const <LibrarySong>[];
          }
          return _randomItems(
            songs
                .where((song) => _isSongDirectlyInFolder(song, folder.path))
                .toList(),
            _randomPreferredItemCount(item.level),
          );
        }).toList();
    _addUniqueSongs(
      selectedSongs,
      _randomItems(preferredSongs, _randomPreferenceItems),
    );
  }

  final recentAddedCount = _enabledBuiltinPreferenceCount(
    preferences.others
        .where((item) => item.type == PreferenceEntityType.recentAdded)
        .firstOrNull,
  );
  if (recentAddedCount > 0) {
    _addUniqueSongs(
      selectedSongs,
      _randomItems(_recentAddedSongs(songs), recentAddedCount),
    );
  }

  final myFavoritesCount = _enabledBuiltinPreferenceCount(
    preferences.others
        .where((item) => item.type == PreferenceEntityType.myFavorites)
        .firstOrNull,
  );
  if (myFavoritesCount > 0) {
    _addUniqueSongs(
      selectedSongs,
      _randomItems(
        songs.where((song) => song.favorite).toList(),
        myFavoritesCount,
      ),
    );
  }

  if (_enabledBuiltinPreferenceCount(
        preferences.others
            .where((item) => item.type == PreferenceEntityType.mostPlayed)
            .firstOrNull,
      ) >
      0) {
    _addUniqueSongs(selectedSongs, _mostPlayedSongs(songs, randomLimit));
  }

  if (_enabledBuiltinPreferenceCount(
        preferences.others
            .where((item) => item.type == PreferenceEntityType.leastPlayed)
            .firstOrNull,
      ) >
      0) {
    _addUniqueSongs(selectedSongs, _leastPlayedSongs(songs, randomLimit));
  }

  _removeDislikedSongs(
    selectedSongs,
    songs,
    playlists,
    folders,
    preferences,
    PreferenceLevel.dislike,
  );
  _removeDislikedSongs(
    selectedSongs,
    songs,
    playlists,
    folders,
    preferences,
    PreferenceLevel.doNotAppear,
  );

  return _randomItems(
    selectedSongs.values.toList(),
    randomLimit,
  ).map((song) => song.id).toList();
}

void _addUniqueSong(Map<int, LibrarySong> target, LibrarySong song) {
  target[song.id] = song;
}

void _addUniqueSongs(Map<int, LibrarySong> target, List<LibrarySong> songs) {
  for (final song in songs) {
    _addUniqueSong(target, song);
  }
}

List<PreferenceItemSnapshot> _enabledPreferenceItems(
  List<PreferenceItemSnapshot> items,
) {
  final sourceItems =
      items.where((item) => item.isEnabled && item.isValid).toList();
  if (sourceItems.length <= 1) {
    return sourceItems;
  }

  return sourceItems.expand((item) {
    if (_preferenceLevelValue(item.level) <= 0) {
      return const <PreferenceItemSnapshot>[];
    }

    final selected = <PreferenceItemSnapshot>[];
    final maximum = _randomPreferredItemCount(item.level);
    for (var index = 0; index < maximum; index += 1) {
      if (_toss()) {
        selected.add(item);
      }
    }
    return _distinctPreferenceItems(
      _randomItems(selected, _randomPreferenceItems),
    );
  }).toList();
}

List<PreferenceItemSnapshot> _distinctPreferenceItems(
  List<PreferenceItemSnapshot> items,
) {
  final seen = <int>{};
  return items.where((item) => seen.add(item.id)).toList();
}

int _enabledBuiltinPreferenceCount(PreferenceItemSnapshot? item) {
  return item?.isEnabled == true ? _randomPreferredItemCount(item!.level) : 0;
}

void _removeDislikedSongs(
  Map<int, LibrarySong> selectedSongs,
  List<LibrarySong> songs,
  List<LibraryPlaylist> playlists,
  List<LibraryFolder> folders,
  PreferenceSettingsSnapshot preferences,
  PreferenceLevel level,
) {
  final items = [
    ...preferences.songs,
    ...preferences.artists,
    ...preferences.albums,
    ...preferences.playlists,
    ...preferences.folders,
  ].where((item) => item.isEnabled && item.isValid && item.level == level);
  final probability = level == PreferenceLevel.doNotAppear ? 1 : 2;
  final songIds =
      items
          .where((item) => item.type == PreferenceEntityType.song)
          .map((item) => int.parse(item.itemId))
          .toSet();
  final artists =
      items
          .where((item) => item.type == PreferenceEntityType.artist)
          .map((item) => item.itemId)
          .toSet();
  final albums =
      items
          .where((item) => item.type == PreferenceEntityType.album)
          .map((item) => item.itemId)
          .toSet();
  final playlistIds =
      items
          .where((item) => item.type == PreferenceEntityType.playlist)
          .map((item) => int.parse(item.itemId))
          .toSet();
  final folderIds =
      items
          .where((item) => item.type == PreferenceEntityType.folder)
          .map((item) => int.tryParse(item.itemId))
          .whereType<int>()
          .toSet();
  final folderItemPaths =
      items
          .where((item) => item.type == PreferenceEntityType.folder)
          .map((item) => item.itemId)
          .toSet();
  final playlistSongIds =
      playlists
          .where((playlist) => playlistIds.contains(playlist.id))
          .expand((playlist) => playlist.songIds)
          .toSet();
  final folderPaths =
      folders
          .where(
            (folder) =>
                folderIds.contains(folder.id) ||
                folderItemPaths.contains(folder.path),
          )
          .map((folder) => folder.path)
          .toList();

  for (final song in songs) {
    if (!selectedSongs.containsKey(song.id)) {
      continue;
    }
    if (_toss(probability) &&
        (songIds.contains(song.id) ||
            _songArtists(song).any(artists.contains) ||
            albums.contains(song.album) ||
            playlistSongIds.contains(song.id) ||
            folderPaths.any(
              (folderPath) => _isSongInFolder(song, folderPath),
            ))) {
      selectedSongs.remove(song.id);
    }
  }
}

int _preferenceLevelValue(PreferenceLevel level) {
  return switch (level) {
    PreferenceLevel.doNotAppear => 0,
    PreferenceLevel.dislike => -1,
    PreferenceLevel.normal => 1,
    PreferenceLevel.high => 2,
    PreferenceLevel.higher => 3,
    PreferenceLevel.veryHigh => 4,
  };
}

int _randomPreferredItemCount(PreferenceLevel level) {
  final minimum = _preferenceLevelValue(level) + 1;
  if (minimum <= 0) {
    return 0;
  }
  return Random().nextInt(minimum * 2) + minimum;
}

bool _toss([int probability = 2]) {
  return probability <= 1 || Random().nextInt(probability) == 0;
}

List<LibrarySong> _recentAddedSongs(List<LibrarySong> songs) {
  final sorted =
      songs.toList()
        ..sort((left, right) => right.dateAdded.compareTo(left.dateAdded));
  return sorted.take(500).toList();
}

List<LibrarySong> _mostPlayedSongs(List<LibrarySong> songs, int randomLimit) {
  return _playedSongs(songs, randomLimit, descending: true);
}

List<LibrarySong> _leastPlayedSongs(List<LibrarySong> songs, int randomLimit) {
  return _playedSongs(songs, randomLimit, descending: false);
}

List<LibrarySong> _playedSongs(
  List<LibrarySong> songs,
  int randomLimit, {
  required bool descending,
}) {
  final songsByPlayCount = <int, List<LibrarySong>>{};
  for (final song in songs) {
    songsByPlayCount[song.playCount] = [
      ...(songsByPlayCount[song.playCount] ?? const []),
      song,
    ];
  }

  final playCounts =
      songsByPlayCount.keys.toList()
        ..sort((left, right) => descending ? right - left : left - right);
  final selectedSongs = <LibrarySong>[];
  for (final playCount in playCounts) {
    if (selectedSongs.length > randomLimit) {
      break;
    }
    selectedSongs.addAll(songsByPlayCount[playCount]!);
  }
  return selectedSongs;
}

List<T> _randomItems<T>(List<T> items, int count) {
  if (count <= 0) {
    return const [];
  }
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

List<String> _songArtists(LibrarySong song) {
  return song.artists.isEmpty ? [song.artist] : song.artists;
}

bool _isSongInFolder(LibrarySong song, String folderPath) {
  return _getFileParentPath(song.path) == folderPath ||
      song.path.startsWith('$folderPath\\') ||
      song.path.startsWith('$folderPath/');
}

bool _isSongDirectlyInFolder(LibrarySong song, String folderPath) {
  return _getFileParentPath(song.path) == folderPath;
}

String _getFileParentPath(String path) {
  final separatorIndex = max(path.lastIndexOf('\\'), path.lastIndexOf('/'));
  return separatorIndex > -1 ? path.substring(0, separatorIndex) : '';
}
