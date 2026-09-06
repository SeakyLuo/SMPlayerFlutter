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

final recentSongsProvider =
    NotifierProvider<RecentSongsNotifier, List<RecentLibrarySong>>(
      RecentSongsNotifier.new,
    );

class RecentSongsNotifier extends Notifier<List<RecentLibrarySong>> {
  static const _limit = 500;

  @override
  List<RecentLibrarySong> build() {
    return ref.watch(recentPageDataProvider).valueOrNull?.recentSongs ??
        const [];
  }

  void recordPlayed(LibrarySong song, {required String playedAt}) {
    state =
        [
          RecentLibrarySong.fromSong(song, playedAt: playedAt),
          ...state.where((item) => item.id != song.id),
        ].take(_limit).toList();
  }

  void remove(Iterable<int> songIds) {
    final ids = songIds.toSet();
    state = state.where((song) => !ids.contains(song.id)).toList();
  }

  void restore(Iterable<RecentLibrarySong> songs) {
    final restored = songs.toList();
    final restoredIds = restored.map((song) => song.id).toSet();
    state = [
      ...restored,
      ...state.where((song) => !restoredIds.contains(song.id)),
    ]..sort(
      (left, right) =>
          int.parse(right.playedAt).compareTo(int.parse(left.playedAt)),
    );
  }

  void clear() {
    state = const [];
  }
}

class RecentPlayedCollections {
  const RecentPlayedCollections({
    required this.playlists,
    required this.albums,
    required this.artists,
  });

  final List<RecentPlaylistPlayback> playlists;
  final List<RecentAlbumPlayback> albums;
  final List<RecentArtistPlayback> artists;
}

final recentPlayedCollectionsProvider = AsyncNotifierProvider<
  RecentPlayedCollectionsNotifier,
  RecentPlayedCollections
>(RecentPlayedCollectionsNotifier.new);

class RecentPlayedCollectionsNotifier
    extends AsyncNotifier<RecentPlayedCollections> {
  static const _limit = 200;

  @override
  Future<RecentPlayedCollections> build() async {
    final snapshot = await ref.watch(recentPageDataProvider.future);
    return RecentPlayedCollections(
      playlists: snapshot.recentPlaylists,
      albums: snapshot.recentAlbums,
      artists: snapshot.recentArtists,
    );
  }

  Future<void> recordPlaylist(RecentPlaylistPlayback entry) async {
    final current = await future;
    state = AsyncData(
      RecentPlayedCollections(
        playlists:
            [
              entry,
              ...current.playlists.where(
                (item) => item.playlistId != entry.playlistId,
              ),
            ].take(_limit).toList(),
        albums: current.albums,
        artists: current.artists,
      ),
    );
  }

  Future<void> recordAlbum(RecentAlbumPlayback entry) async {
    final current = await future;
    state = AsyncData(
      RecentPlayedCollections(
        playlists: current.playlists,
        albums:
            [
              entry,
              ...current.albums.where((item) => item.album != entry.album),
            ].take(_limit).toList(),
        artists: current.artists,
      ),
    );
  }

  Future<void> recordArtist(RecentArtistPlayback entry) async {
    final current = await future;
    state = AsyncData(
      RecentPlayedCollections(
        playlists: current.playlists,
        albums: current.albums,
        artists:
            [
              entry,
              ...current.artists.where((item) => item.artist != entry.artist),
            ].take(_limit).toList(),
      ),
    );
  }

  Future<void> clear() async {
    await future;
    state = const AsyncData(
      RecentPlayedCollections(playlists: [], albums: [], artists: []),
    );
  }
}

Future<void> recordRecentPlaylistPlayback(WidgetRef ref, int playlistId) async {
  final repository = ref.read(libraryRepositoryProvider);
  final recentCollections = ref.read(recentPlayedCollectionsProvider.notifier);
  final entry = await repository.recordPlaylistPlayed(playlistId);
  await recentCollections.recordPlaylist(entry);
}

Future<void> recordRecentAlbumPlayback(WidgetRef ref, String album) async {
  final repository = ref.read(libraryRepositoryProvider);
  final recentCollections = ref.read(recentPlayedCollectionsProvider.notifier);
  final entry = await repository.recordAlbumPlayed(album);
  await recentCollections.recordAlbum(entry);
}

Future<void> recordRecentArtistPlayback(WidgetRef ref, String artist) async {
  final repository = ref.read(libraryRepositoryProvider);
  final recentCollections = ref.read(recentPlayedCollectionsProvider.notifier);
  final entry = await repository.recordArtistPlayed(artist);
  await recentCollections.recordArtist(entry);
}

final shellNavigationDataProvider = FutureProvider<ShellNavigationData>((ref) {
  return ref.watch(libraryRepositoryProvider).getShellNavigationData();
});

final recentSearchesProvider =
    AsyncNotifierProvider<RecentSearchesNotifier, List<SearchHistoryEntry>>(
      RecentSearchesNotifier.new,
    );

class RecentSearchesNotifier extends AsyncNotifier<List<SearchHistoryEntry>> {
  @override
  Future<List<SearchHistoryEntry>> build() {
    return ref.watch(libraryRepositoryProvider).getRecentSearches();
  }

  Future<void> record(SearchHistoryEntry entry) async {
    final entries = await future;
    state = AsyncData([
      entry,
      ...entries.where(
        (item) =>
            item.type != entry.type ||
            item.query.toLowerCase() != entry.query.toLowerCase(),
      ),
    ]);
  }

  Future<void> remove(Iterable<int> entryIds) async {
    final ids = entryIds.toSet();
    final entries = await future;
    state = AsyncData(
      entries.where((entry) => !ids.contains(entry.id)).toList(),
    );
  }

  Future<void> restore(Iterable<SearchHistoryEntry> restoredEntries) async {
    final restored = restoredEntries.toList();
    final restoredKeys =
        restored
            .map((entry) => (entry.type, entry.query.toLowerCase()))
            .toSet();
    final entries = [
      ...restored,
      ...(await future).where(
        (entry) =>
            !restoredKeys.contains((entry.type, entry.query.toLowerCase())),
      ),
    ];
    entries.sort((left, right) {
      final timeCompare = int.parse(
        right.searchedAt,
      ).compareTo(int.parse(left.searchedAt));
      return timeCompare != 0 ? timeCompare : right.id.compareTo(left.id);
    });
    state = AsyncData(entries);
  }

  Future<void> clear() async {
    await future;
    state = const AsyncData([]);
  }
}

final recentBrowsesProvider =
    AsyncNotifierProvider<RecentBrowsesNotifier, List<RecentBrowseEntry>>(
      RecentBrowsesNotifier.new,
    );

class RecentBrowsesNotifier extends AsyncNotifier<List<RecentBrowseEntry>> {
  static const _limit = 500;

  @override
  Future<List<RecentBrowseEntry>> build() async {
    return (await ref.watch(recentPageDataProvider.future)).recentBrowses;
  }

  Future<void> record(RecentBrowseEntry entry) async {
    final entries = await future;
    state = AsyncData(
      [
        entry,
        ...entries.where(
          (item) => item.type != entry.type || item.itemId != entry.itemId,
        ),
      ].take(_limit).toList(),
    );
  }

  Future<void> remove(Iterable<int> entryIds) async {
    final ids = entryIds.toSet();
    final entries = await future;
    state = AsyncData(
      entries.where((entry) => !ids.contains(entry.id)).toList(),
    );
  }

  Future<void> restore(Iterable<RecentBrowseEntry> restoredEntries) async {
    final restored = restoredEntries.toList();
    final restoredKeys =
        restored.map((entry) => (entry.type, entry.itemId)).toSet();
    final entries = [
      ...restored,
      ...(await future).where(
        (entry) => !restoredKeys.contains((entry.type, entry.itemId)),
      ),
    ]..sort((left, right) => right.id.compareTo(left.id));
    state = AsyncData(entries);
  }

  Future<void> clear() async {
    await future;
    state = const AsyncData([]);
  }
}

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

final libraryPlaylistOrderProvider = StateProvider<List<int>?>((ref) {
  return null;
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
  final orderNotifier = ref.read(libraryPlaylistOrderProvider.notifier);
  deletedNotifier.state = {...deletedNotifier.state}..remove(playlist.id);
  overrideNotifier.state = {...overrideNotifier.state, playlist.id: playlist};
  if (orderNotifier.state case final order?
      when !playlist.isBuiltIn && !order.contains(playlist.id)) {
    orderNotifier.state = [playlist.id, ...order];
  }
}

void removeLibraryPlaylistOverride(WidgetRef ref, int playlistId) {
  final overrideNotifier = ref.read(libraryPlaylistOverridesProvider.notifier);
  final deletedNotifier = ref.read(libraryDeletedPlaylistIdsProvider.notifier);
  overrideNotifier.state = {...overrideNotifier.state}..remove(playlistId);
  deletedNotifier.state = {...deletedNotifier.state, playlistId};
  final orderNotifier = ref.read(libraryPlaylistOrderProvider.notifier);
  if (orderNotifier.state case final order?) {
    orderNotifier.state =
        order.where((orderedId) => orderedId != playlistId).toList();
  }
}

void setLibraryPlaylistOrder(WidgetRef ref, List<int> playlistIds) {
  ref.read(libraryPlaylistOrderProvider.notifier).state = playlistIds;
}

LibraryContentData applyLibraryFavoriteOverrides(
  LibraryContentData snapshot,
  Map<int, bool> favoriteOverrides, [
  Map<int, LibrarySong> songOverrides = const {},
  Map<int, LibraryPlaylist> playlistOverrides = const {},
  Set<int> deletedPlaylistIds = const {},
  List<int>? playlistOrder,
]) {
  if (favoriteOverrides.isEmpty &&
      songOverrides.isEmpty &&
      playlistOverrides.isEmpty &&
      deletedPlaylistIds.isEmpty &&
      playlistOrder == null) {
    return snapshot;
  }
  final songs = applyFavoriteOverridesToSongs(
    snapshot.songs,
    favoriteOverrides,
    songOverrides,
  );
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
    playlistOrder,
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
  Set<int> deletedPlaylistIds, [
  List<int>? playlistOrder,
]) {
  if (playlistOverrides.isEmpty &&
      deletedPlaylistIds.isEmpty &&
      playlistOrder == null) {
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
  if (playlistOrder != null) {
    final builtInPlaylists =
        nextPlaylists.where((playlist) => playlist.isBuiltIn).toList();
    final customPlaylists =
        nextPlaylists.where((playlist) => !playlist.isBuiltIn).toList();
    final customById = {
      for (final playlist in customPlaylists) playlist.id: playlist,
    };
    final orderedIds = playlistOrder.toSet();
    nextPlaylists = [
      ...builtInPlaylists,
      ...playlistOrder.map((id) => customById[id]).whereType<LibraryPlaylist>(),
      ...customPlaylists.where((playlist) => !orderedIds.contains(playlist.id)),
    ];
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
