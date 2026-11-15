part of 'library_providers.dart';

// Entities already requested by a page or playback operation. This provider
// never queries the entire library when another consumer subscribes to it.
final libraryLoadedDataProvider =
    AsyncNotifierProvider<LibraryLoadedData, LibraryContentData>(
      LibraryLoadedData.new,
    );

// A view of already loaded entities for playback and cross-page actions.
// Database queries belong to libraryPageQueryProvider, not to this view.
final libraryContentDataProvider = FutureProvider<LibraryContentData>(
  (ref) => ref
      .watch(libraryLoadedDataProvider)
      .when(
        data: (data) => data,
        loading: () => ref.read(libraryLoadedDataProvider.future),
        error: (error, stack) => Future<LibraryContentData>.error(error, stack),
      ),
);

class LibraryLoadedData extends AsyncNotifier<LibraryContentData> {
  Set<int> _playbackIds = {};
  @override
  Future<LibraryContentData> build() => ref
      .read(libraryRepositoryProvider)
      .queryLibrary(const LibraryDataQuery(LibraryQueryKind.context));

  void setRemotePlaylists(List<LibraryPlaylist> playlists) {
    final current = state.requireValue;
    state = AsyncData(
      current.withPlaylists([
        ...current.playlists.where((playlist) => playlist.remotePath.isEmpty),
        ...playlists,
      ]),
    );
  }

  Future<void> addSongs(List<LibrarySong> songs) async {
    await future;
    _playbackIds = songs.map((song) => song.id).toSet();
    final current = state.requireValue;
    final page = LibraryContentData(
      songs: songs,
      hasLibrary: songs.isNotEmpty,
      sortCriterion: current.sortCriterion,
      albumsSort: current.albumsSort,
      databasePath: current.databasePath,
      rootPath: current.rootPath,
      favoritePlaylistId: current.favoritePlaylistId,
      nowPlaying: current.nowPlaying,
      showCount: current.showCount,
      hideMultiSelectCommandBarAfterOperation:
          current.hideMultiSelectCommandBarAfterOperation,
      localViewMode: current.localViewMode,
    );
    state = AsyncData(
      mergeLoadedLibraryData(
        current,
        page,
        LibraryDataQuery(
          LibraryQueryKind.queue,
          songIds: songs.map((song) => song.id).toList(),
        ),
      ),
    );
  }

  Future<void> publish(LibraryContentData page, LibraryDataQuery query) async {
    await future;
    final current = state.requireValue;
    final retained = current.withPage(
      songs:
          current.songs
              .where((song) => _playbackIds.contains(song.id))
              .toList(),
    );
    state = AsyncData(mergeLoadedLibraryData(retained, page, query));
  }
}

final libraryPlaylistQueryInvalidationProvider = Provider.autoDispose
    .family<Object, (String, int)>((ref, scope) => Object());

final libraryQueryInvalidationProvider = Provider.autoDispose
    .family<Object, (LibraryQueryKind, String)>((ref, scope) => Object());

// Share overlapping page loads only; the next load must observe writes.
final libraryPageQueryProvider = FutureProvider.autoDispose
    .family<LibraryContentData, LibraryDataQuery>((ref, query) async {
      ref.watch(libraryQueryInvalidationProvider((query.kind, query.source)));
      if (query.kind == LibraryQueryKind.playlists && query.playlistId != null)
        ref.watch(
          libraryPlaylistQueryInvalidationProvider((
            query.source,
            query.playlistId!,
          )),
        );
      var active = true;
      ref.onDispose(() => active = false);
      final previousPlaylists = ref.read(libraryPlaylistOverridesProvider);
      final previousSongs = ref.read(librarySongOverridesProvider);
      final previousFavorites = ref.read(libraryFavoriteOverridesProvider);
      final page = await ref
          .read(libraryRepositoryProvider)
          .queryLibrary(query);
      if (!active) return page;
      if (identical(
            ref.read(libraryPlaylistOverridesProvider),
            previousPlaylists,
          ) &&
          page.playlists.isNotEmpty) {
        final listIds = page.playlists.map((list) => list.id).toSet();
        ref.read(libraryPlaylistOverridesProvider.notifier).state = {
          ...previousPlaylists,
        }..removeWhere((id, _) => listIds.contains(id));
      }
      final ids = page.songs.map((song) => song.id).toSet();
      final songs = ref.read(librarySongOverridesProvider.notifier);
      if (identical(songs.state, previousSongs) && ids.isNotEmpty) {
        songs.state = {...songs.state}
          ..removeWhere((id, _) => ids.contains(id));
      }
      final favorites = ref.read(libraryFavoriteOverridesProvider.notifier);
      if (identical(favorites.state, previousFavorites) && ids.isNotEmpty) {
        favorites.state = {...favorites.state}
          ..removeWhere((id, _) => ids.contains(id));
      }
      await ref.read(libraryLoadedDataProvider.notifier).publish(page, query);
      return page;
    });

void invalidateLibraryQueries(
  void Function(ProviderOrFamily) invalidate, {
  String source = 'local',
  Set<LibraryQueryKind> kinds = const {
    LibraryQueryKind.context,
    LibraryQueryKind.songs,
    LibraryQueryKind.artistIndex,
    LibraryQueryKind.albumIndex,
    LibraryQueryKind.folders,
    LibraryQueryKind.playlists,
    LibraryQueryKind.playlistIndex,
    LibraryQueryKind.directoryIndex,
    LibraryQueryKind.recent,
    LibraryQueryKind.favorites,
    LibraryQueryKind.album,
    LibraryQueryKind.artist,
  },
}) {
  // Invalidating a family only re-queries its currently accessed instances.
  // The entity cache used by the player and inactive pages remains available.
  for (final kind in kinds) {
    invalidate(libraryQueryInvalidationProvider((kind, source)));
  }
}

Future<List<LibrarySong>> reloadRequestedLibrarySongs(
  WidgetRef ref,
  List<int> songIds,
) async {
  final container = ProviderScope.containerOf(ref.context, listen: false);
  final requested = songIds.toSet();
  final visibleIds =
      container
          .read(libraryLoadedDataProvider)
          .requireValue
          .songs
          .where((song) => requested.contains(song.id))
          .map((song) => song.id)
          .toList();
  final songs =
      visibleIds.isEmpty
          ? const <LibrarySong>[]
          : await container
              .read(libraryRepositoryProvider)
              .getLibrarySongs(songIds: visibleIds);
  final overrides = container.read(librarySongOverridesProvider.notifier);
  overrides.state = {
    ...overrides.state,
    for (final song in songs) song.id: song,
  };
  final favorites = container.read(libraryFavoriteOverridesProvider.notifier);
  favorites.state = {
    ...favorites.state,
    for (final song in songs) song.id: song.favorite,
  };
  return songs;
}

final libraryScopeIdsProvider = FutureProvider.autoDispose
    .family<List<int>, LibraryDataQuery>((ref, query) {
      ref.watch(libraryQueryInvalidationProvider((query.kind, query.source)));
      if (query.kind == LibraryQueryKind.playlists && query.playlistId != null)
        ref.watch(
          libraryPlaylistQueryInvalidationProvider((
            query.source,
            query.playlistId!,
          )),
        );
      return ref
          .read(libraryRepositoryProvider)
          .dataSource(LibrarySource.fromDevice(query.source))
          .resolveSongIds(query);
    });
