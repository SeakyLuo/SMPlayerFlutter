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

LibraryContentData applyLibraryFavoriteOverrides(
  LibraryContentData snapshot,
  Map<int, bool> favoriteOverrides,
) {
  if (favoriteOverrides.isEmpty) {
    return snapshot;
  }
  final songs =
      snapshot.songs
          .map((song) => _applyFavoriteOverrideToSong(song, favoriteOverrides))
          .toList();
  final recentSongs =
      snapshot.recentSongs
          .map(
            (song) =>
                _applyFavoriteOverrideToRecentSong(song, favoriteOverrides),
          )
          .toList();
  final favoritePlaylistSongIds = _patchedFavoritePlaylistSongIds(
    snapshot,
    favoriteOverrides,
  );
  final playlists =
      snapshot.playlists
          .map(
            (playlist) =>
                playlist.id == snapshot.favoritePlaylistId
                    ? _copyPlaylistWithSongIds(
                      playlist,
                      favoritePlaylistSongIds,
                    )
                    : playlist,
          )
          .toList();
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

List<LibrarySong> applyFavoriteOverridesToSongs(
  List<LibrarySong> songs,
  Map<int, bool> favoriteOverrides,
) {
  if (favoriteOverrides.isEmpty) {
    return songs;
  }
  return songs
      .map((song) => _applyFavoriteOverrideToSong(song, favoriteOverrides))
      .toList();
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
  Map<int, bool> favoriteOverrides,
) {
  final favoritePlaylist = snapshot.playlists
      .where((playlist) => playlist.id == snapshot.favoritePlaylistId)
      .firstOrNull;
  final ids =
      favoritePlaylist?.songIds.toSet() ??
      snapshot.songs
          .where((song) => song.favorite)
          .map((song) => song.id)
          .toSet();
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
