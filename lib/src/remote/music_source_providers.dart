import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/data/library_models.dart';
import '../library/data/library_providers.dart';
import 'music_share_access.dart';
import 'music_share_controller.dart';
import 'music_share_models.dart';

final ChangeNotifierProvider<MusicShareController>
musicShareProvider = ChangeNotifierProvider<MusicShareController>((ref) {
  final dataRevision = ref.read(libraryDataRevisionProvider.notifier);
  final controller = MusicShareController(
    ref.read(libraryRepositoryProvider),
    () {
      dataRevision.state += 1;
    },
    loadLibrary: () => ref.read(libraryContentDataProvider.future),
  );
  activeMusicShareAccess = controller;
  void updateSharedCatalog() {
    final snapshot = ref.read(libraryContentDataProvider).valueOrNull;
    if (controller.initialized && snapshot != null) {
      controller.server.updateLibrary(
        applyLibraryFavoriteOverrides(
          snapshot,
          const {},
          ref.read(librarySongOverridesProvider),
        ),
      );
    }
  }

  ref.listen(libraryContentDataProvider, (_, next) => updateSharedCatalog());
  ref.listen(librarySongOverridesProvider, (_, next) => updateSharedCatalog());
  ref.onDispose(() {
    if (identical(activeMusicShareAccess, controller)) {
      activeMusicShareAccess = null;
    }
  });
  return controller;
});

final musicShareReadyProvider = FutureProvider<void>((ref) {
  return ref.watch(musicShareProvider.notifier).ready;
});

final currentLibraryPlaylistsProvider = Provider<List<LibraryPlaylist>>((ref) {
  final selection = ref.watch(
    musicShareProvider.select(
      (share) => (share.selectedSource, share.selectedPlaylists),
    ),
  );
  final localPlaylists = ref.watch(
    libraryContentDataProvider.select((value) => value.valueOrNull?.playlists),
  );
  return [
    ...?localPlaylists?.where(
      (playlist) =>
          playlist.isBuiltIn ||
          selection.$1 == 'local' && playlist.remotePath.isEmpty,
    ),
    if (selection.$1 != 'local') ...selection.$2,
  ];
});

final remotePlaylistLoadStateProvider = Provider((ref) {
  return ref.watch(
    musicShareProvider.select(
      (share) => (
        remote: share.selectedSource != 'local',
        loading: share.selectedPlaylistsLoading,
        loaded: share.selectedPlaylistsLoaded,
      ),
    ),
  );
});

final browsingLibraryContentDataProvider =
    Provider<AsyncValue<LibraryContentData>>(
      (ref) => _browse(ref, includeUnavailable: true),
    );

final browsingAvailableLibraryContentDataProvider =
    Provider<AsyncValue<LibraryContentData>>(
      (ref) => _browse(ref, includeUnavailable: false),
    );

AsyncValue<LibraryContentData> _browse(
  Ref ref, {
  required bool includeUnavailable,
}) {
  ref.watch(
    musicShareProvider.select((share) {
      final peer =
          share.peers
              .where((peer) => peer.id == share.selectedSource)
              .firstOrNull;
      return (
        share.selectedSource,
        peer?.status,
        peer?.canWrite,
        share.selectedPlaylists,
        peer?.catalogLoaded,
        share.selectedPlaylistsLoading,
      );
    }),
  );
  final share = ref.read(musicShareProvider);
  final libraryValue = ref.watch(libraryContentDataProvider);
  final playlists = ref.watch(currentLibraryPlaylistsProvider);
  if (share.selectedSource != 'local') {
    final peer =
        share.peers
            .where((peer) => peer.id == share.selectedSource)
            .firstOrNull;
    final hasCachedSongs =
        libraryValue.valueOrNull?.songs.any(share.includes) ?? false;
    if ((peer == null || !peer.catalogLoaded) && !hasCachedSongs) {
      if (share.selectedPlaylistsLoading) {
        return const AsyncLoading();
      }
      return AsyncError(
        const MusicShareException('share.offline'),
        StackTrace.current,
      );
    }
    if (peer != null &&
        !peer.catalogPublished &&
        libraryValue.isLoading &&
        !hasCachedSongs) {
      return const AsyncLoading();
    }
    if (peer != null && libraryValue.hasValue && !libraryValue.isLoading) {
      peer.catalogPublished = true;
    }
  }
  return libraryValue.whenData((source) {
    final songs =
        source.songs
            .where(
              (song) =>
                  share.includes(song) &&
                  (includeUnavailable || song.remoteAvailable),
            )
            .toList();
    return LibraryContentData(
      songs: songs,
      hasLibrary: songs.isNotEmpty,
      sortCriterion: source.sortCriterion,
      albumsSort: source.albumsSort,
      databasePath: source.databasePath,
      recentSongs: source.recentSongs.where(share.includes).toList(),
      recentPlaylists: source.recentPlaylists,
      recentAlbums: source.recentAlbums,
      recentArtists: source.recentArtists,
      recentSearches: source.recentSearches,
      playlists: playlists,
      folders: share.selectedSource == 'local' ? source.folders : const [],
      favoritePlaylistId: source.favoritePlaylistId,
      nowPlaying: source.nowPlaying,
      showCount: source.showCount,
      hideMultiSelectCommandBarAfterOperation:
          source.hideMultiSelectCommandBarAfterOperation,
      localViewMode: source.localViewMode,
      rootPath: source.rootPath,
    );
  });
}
