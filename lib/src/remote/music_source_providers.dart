import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/data/library_models.dart';
import '../library/data/library_providers.dart';
import 'music_share_access.dart';
import 'music_share_controller.dart';

final musicShareProvider = ChangeNotifierProvider<MusicShareController>((ref) {
  final controller = MusicShareController(
    ref.read(libraryRepositoryProvider),
    () {
      ref.invalidate(libraryContentDataProvider);
      ref.invalidate(shellNavigationDataProvider);
      ref.invalidate(recentPageDataProvider);
      ref.invalidate(librarySongCountProvider);
    },
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
  final share = ref.watch(musicShareProvider);
  return ref.watch(libraryContentDataProvider).whenData((source) {
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
      playlists: source.playlists,
      folders:
          share.selectedSource == 'local' || share.selectedSource == 'all'
              ? source.folders
              : const [],
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
