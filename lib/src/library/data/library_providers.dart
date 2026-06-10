import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_models.dart';
import 'library_repository.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return const LibraryRepository();
});

final libraryDatabaseInitializationProvider = FutureProvider<void>((ref) {
  return ref.watch(libraryRepositoryProvider).initializeLibraryDatabase();
});

final recentPageDataProvider = FutureProvider<RecentPageData>((ref) {
  return ref.watch(libraryRepositoryProvider).getRecentPageData();
});

final shellNavigationDataProvider = FutureProvider<ShellNavigationData>((ref) {
  return ref.watch(libraryRepositoryProvider).getShellNavigationData();
});

final recentSearchesProvider = FutureProvider<List<SearchHistoryEntry>>((ref) {
  return ref.watch(libraryRepositoryProvider).getRecentSearches();
});

final librarySongCountProvider = FutureProvider<int>((ref) {
  return ref.watch(libraryRepositoryProvider).getLibrarySongCount();
});

final libraryContentDataProvider = FutureProvider<LibraryContentData>((
  ref,
) async {
  return ref.watch(libraryRepositoryProvider).getLibraryContentData();
});

final libraryFavoriteOverridesProvider = StateProvider<Map<int, bool>>((ref) {
  return const {};
});

final librarySongOverridesProvider = StateProvider<Map<int, LibrarySong>>((
  ref,
) {
  return const {};
});

final libraryPlaylistOverridesProvider =
    StateProvider<Map<int, LibraryPlaylist>>((ref) {
      return const {};
    });

final libraryDeletedPlaylistIdsProvider = StateProvider<Set<int>>((ref) {
  return const {};
});

final nowPlayingQueueOverrideProvider = StateProvider<List<int>?>((ref) {
  return null;
});

final lyricsSavedEventProvider = StateProvider<({int revision, int songId})?>((
  ref,
) {
  return null;
});

void notifyLyricsSaved(WidgetRef ref, int songId) {
  final notifier = ref.read(lyricsSavedEventProvider.notifier);
  notifier.state = (
    revision: (notifier.state?.revision ?? 0) + 1,
    songId: songId,
  );
}

void invalidateRecentSearchData(WidgetRef ref) {
  ref.invalidate(libraryContentDataProvider);
  ref.invalidate(recentPageDataProvider);
  ref.invalidate(shellNavigationDataProvider);
  ref.invalidate(recentSearchesProvider);
}

void patchLibraryFavoriteOverrides(
  WidgetRef ref,
  List<int> songIds,
  bool favorite,
) {
  final notifier = ref.read(libraryFavoriteOverridesProvider.notifier);
  notifier.state = {
    ...notifier.state,
    for (final songId in songIds) songId: favorite,
  };
}

void patchLibrarySongOverride(WidgetRef ref, LibrarySong song) {
  final notifier = ref.read(librarySongOverridesProvider.notifier);
  notifier.state = {...notifier.state, song.id: song};
}

void patchLibraryPlaylistOverride(WidgetRef ref, LibraryPlaylist playlist) {
  final overrideNotifier = ref.read(libraryPlaylistOverridesProvider.notifier);
  final deletedNotifier = ref.read(libraryDeletedPlaylistIdsProvider.notifier);
  deletedNotifier.state = {...deletedNotifier.state}..remove(playlist.id);
  overrideNotifier.state = {...overrideNotifier.state, playlist.id: playlist};
}

void removeLibraryPlaylistOverride(WidgetRef ref, int playlistId) {
  final overrideNotifier = ref.read(libraryPlaylistOverridesProvider.notifier);
  final deletedNotifier = ref.read(libraryDeletedPlaylistIdsProvider.notifier);
  overrideNotifier.state = {...overrideNotifier.state}..remove(playlistId);
  deletedNotifier.state = {...deletedNotifier.state, playlistId};
}

LibraryContentData applyLibraryFavoriteOverrides(
  LibraryContentData snapshot,
  Map<int, bool> favoriteOverrides, [
  Map<int, LibrarySong> songOverrides = const {},
  Map<int, LibraryPlaylist> playlistOverrides = const {},
  Set<int> deletedPlaylistIds = const {},
]) {
  if (favoriteOverrides.isEmpty &&
      songOverrides.isEmpty &&
      playlistOverrides.isEmpty &&
      deletedPlaylistIds.isEmpty) {
    return snapshot;
  }
  final songs =
      snapshot.songs
          .map(
            (song) => _applyFavoriteOverrideToSong(
              _applySongOverrideToSong(song, songOverrides),
              favoriteOverrides,
            ),
          )
          .toList();
  final recentSongs =
      snapshot.recentSongs
          .map(
            (song) => _applyFavoriteOverrideToRecentSong(
              _applySongOverrideToRecentSong(song, songOverrides),
              favoriteOverrides,
            ),
          )
          .toList();
  final favoritePlaylistSongIds = _patchedFavoritePlaylistSongIds(
    snapshot,
    songs,
    favoriteOverrides,
  );
  final playlists = applyLibraryPlaylistOverridesToPlaylists(
    snapshot.playlists
        .map(
          (playlist) =>
              playlist.id == snapshot.favoritePlaylistId
                  ? _copyPlaylistWithSongIds(playlist, favoritePlaylistSongIds)
                  : playlist,
        )
        .toList(),
    playlistOverrides,
    deletedPlaylistIds,
  );
  return LibraryContentData(
    songs: songs,
    recentSongs: recentSongs,
    recentPlaylists: snapshot.recentPlaylists,
    recentAlbums: snapshot.recentAlbums,
    recentArtists: snapshot.recentArtists,
    recentSearches: snapshot.recentSearches,
    playlists: playlists,
    folders: snapshot.folders,
    favoritePlaylistId: snapshot.favoritePlaylistId,
    nowPlaying: snapshot.nowPlaying,
    hasLibrary: snapshot.hasLibrary,
    sortCriterion: snapshot.sortCriterion,
    albumsSort: snapshot.albumsSort,
    showCount: snapshot.showCount,
    hideMultiSelectCommandBarAfterOperation:
        snapshot.hideMultiSelectCommandBarAfterOperation,
    localViewMode: snapshot.localViewMode,
    rootPath: snapshot.rootPath,
    databasePath: snapshot.databasePath,
  );
}

List<LibraryPlaylist> applyLibraryPlaylistOverridesToPlaylists(
  List<LibraryPlaylist> playlists,
  Map<int, LibraryPlaylist> playlistOverrides,
  Set<int> deletedPlaylistIds,
) {
  if (playlistOverrides.isEmpty && deletedPlaylistIds.isEmpty) {
    return playlists;
  }
  var nextPlaylists =
      playlists
          .where((playlist) => !deletedPlaylistIds.contains(playlist.id))
          .map((playlist) => playlistOverrides[playlist.id] ?? playlist)
          .toList();
  final playlistIds = nextPlaylists.map((playlist) => playlist.id).toSet();
  for (final playlist in playlistOverrides.values) {
    if (playlistIds.contains(playlist.id) ||
        deletedPlaylistIds.contains(playlist.id)) {
      continue;
    }
    nextPlaylists = _insertCustomPlaylistFirst(nextPlaylists, playlist);
    playlistIds.add(playlist.id);
  }
  return nextPlaylists;
}

List<LibrarySong> applyFavoriteOverridesToSongs(
  List<LibrarySong> songs,
  Map<int, bool> favoriteOverrides, [
  Map<int, LibrarySong> songOverrides = const {},
]) {
  if (favoriteOverrides.isEmpty && songOverrides.isEmpty) {
    return songs;
  }
  return songs
      .map(
        (song) => _applyFavoriteOverrideToSong(
          _applySongOverrideToSong(song, songOverrides),
          favoriteOverrides,
        ),
      )
      .toList();
}

LibrarySong _applySongOverrideToSong(
  LibrarySong song,
  Map<int, LibrarySong> songOverrides,
) {
  return songOverrides[song.id] ?? song;
}

RecentLibrarySong _applySongOverrideToRecentSong(
  RecentLibrarySong song,
  Map<int, LibrarySong> songOverrides,
) {
  final override = songOverrides[song.id];
  if (override == null) {
    return song;
  }
  return RecentLibrarySong(
    id: override.id,
    path: override.path,
    title: override.title,
    artist: override.artist,
    artists: override.artists,
    album: override.album,
    duration: override.duration,
    playCount: override.playCount,
    lyricsOffsetMs: override.lyricsOffsetMs,
    dateAdded: override.dateAdded,
    favorite: override.favorite,
    thumbnailPath: override.thumbnailPath,
    playedAt: song.playedAt,
  );
}

LibrarySong _applyFavoriteOverrideToSong(
  LibrarySong song,
  Map<int, bool> favoriteOverrides,
) {
  final favorite = favoriteOverrides[song.id];
  if (favorite == null || favorite == song.favorite) {
    return song;
  }
  return LibrarySong(
    id: song.id,
    path: song.path,
    title: song.title,
    artist: song.artist,
    artists: song.artists,
    album: song.album,
    duration: song.duration,
    playCount: song.playCount,
    lyricsOffsetMs: song.lyricsOffsetMs,
    dateAdded: song.dateAdded,
    favorite: favorite,
    thumbnailPath: song.thumbnailPath,
  );
}

RecentLibrarySong _applyFavoriteOverrideToRecentSong(
  RecentLibrarySong song,
  Map<int, bool> favoriteOverrides,
) {
  final favorite = favoriteOverrides[song.id];
  if (favorite == null || favorite == song.favorite) {
    return song;
  }
  return RecentLibrarySong(
    id: song.id,
    path: song.path,
    title: song.title,
    artist: song.artist,
    artists: song.artists,
    album: song.album,
    duration: song.duration,
    playCount: song.playCount,
    lyricsOffsetMs: song.lyricsOffsetMs,
    dateAdded: song.dateAdded,
    favorite: favorite,
    thumbnailPath: song.thumbnailPath,
    playedAt: song.playedAt,
  );
}

List<int> _patchedFavoritePlaylistSongIds(
  LibraryContentData snapshot,
  List<LibrarySong> songs,
  Map<int, bool> favoriteOverrides,
) {
  final favoritePlaylist =
      snapshot.playlists
          .where((playlist) => playlist.id == snapshot.favoritePlaylistId)
          .firstOrNull;
  final ids =
      favoritePlaylist?.songIds.toSet() ??
      songs.where((song) => song.favorite).map((song) => song.id).toSet();
  for (final entry in favoriteOverrides.entries) {
    if (entry.value) {
      ids.add(entry.key);
    } else {
      ids.remove(entry.key);
    }
  }
  return ids.toList();
}

LibraryPlaylist _copyPlaylistWithSongIds(
  LibraryPlaylist playlist,
  List<int> songIds,
) {
  return LibraryPlaylist(
    id: playlist.id,
    name: playlist.name,
    priority: playlist.priority,
    songCount: songIds.length,
    songIds: songIds,
    sortCriterion: playlist.sortCriterion,
    isBuiltIn: playlist.isBuiltIn,
  );
}

List<LibraryPlaylist> _insertCustomPlaylistFirst(
  List<LibraryPlaylist> playlists,
  LibraryPlaylist playlist,
) {
  final index = playlists.indexWhere((item) => !item.isBuiltIn);
  final nextPlaylists = playlists.toList();
  nextPlaylists.insert(index == -1 ? nextPlaylists.length : index, playlist);
  return nextPlaylists;
}
