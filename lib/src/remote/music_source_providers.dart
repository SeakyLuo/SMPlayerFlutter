import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/data/library_history_changes.dart';
import '../library/data/library_models.dart';
import '../library/data/library_providers.dart';
import '../library/data/library_repository.dart';
import 'music_share_access.dart';
import 'music_share_controller.dart';
import 'music_share_models.dart';

final ChangeNotifierProvider<MusicShareController> musicShareProvider =
    ChangeNotifierProvider<MusicShareController>((ref) {
      final dataRevision = ref.read(libraryDataRevisionProvider.notifier);
      final controller = MusicShareController(
        ref.read(libraryRepositoryProvider),
        (source) {
          dataRevision.state += 1;
          invalidateLibraryQueries(ref.invalidate, source: source);
        },
        loadLibrary: () => ref.read(libraryContentDataProvider.future),
        onScopedPeerChange: (device, ids, playlists) async {
          if (playlists) {
            invalidateLibraryQueries(
              ref.invalidate,
              source: device,
              kinds: const {
                LibraryQueryKind.playlists,
                LibraryQueryKind.playlistIndex,
              },
            );
          }
          if (ids.isNotEmpty) {
            final paths = {for (final id in ids) remoteMusicPath(device, id)};
            await refreshCachedSongDetails(
              ref.container,
              (song) => paths.contains(song.path),
            );
            invalidateSongMetadataQueries(ref.container, device);
          }
        },
        onHostDataChanged: (scopes) {
          notifyLibraryHistoryChanges('local', scopes);
          if (scopes.contains('library') ||
              scopes.any((scope) => scope.startsWith('song:'))) {
            invalidateLibraryQueries(ref.invalidate);
          } else if (scopes.contains('playlists')) {
            invalidateLibraryQueries(
              ref.invalidate,
              kinds: {
                LibraryQueryKind.playlists,
                LibraryQueryKind.playlistIndex,
              },
            );
          }
        },
        onPlaylistsChanged:
            (lists) => ref
                .read(libraryLoadedDataProvider.notifier)
                .setRemotePlaylists(lists),
      );
      activeMusicShareAccess = controller;
      ref.onDispose(() {
        if (identical(activeMusicShareAccess, controller)) {
          activeMusicShareAccess = null;
        }
      });
      return controller;
    });

final selectedLibraryDataSourceProvider = Provider<LibraryDataSource>((ref) {
  final source = ref.watch(
    musicShareProvider.select((share) => share.selectedSource),
  );
  return ref
      .read(libraryRepositoryProvider)
      .dataSource(LibrarySource.fromDevice(source));
});

final musicShareReadyProvider = FutureProvider<void>((ref) {
  return ref.watch(musicShareProvider.notifier).ready;
});

final libraryPlaylistSidebarVisibleProvider = StateProvider<bool>(
  (ref) => false,
);

final currentLibraryPlaylistsProvider =
    Provider.autoDispose<List<LibraryPlaylist>>((ref) {
      final source =
          ref.watch(selectedLibraryDataSourceProvider).source.deviceId;
      if (ref.watch(libraryPlaylistSidebarVisibleProvider)) {
        ref.watch(
          libraryPageQueryProvider(
            LibraryDataQuery(LibraryQueryKind.playlistIndex, source: source),
          ),
        );
      }
      if (source != 'local') {
        return ref.watch(
          musicShareProvider.select((share) => share.selectedPlaylists),
        );
      }
      return ref
              .watch(libraryLoadedDataProvider)
              .valueOrNull
              ?.playlists
              .where((playlist) => playlist.source.deviceId == source)
              .toList() ??
          const [];
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

final browsingLibraryPageProvider = Provider.autoDispose
    .family<AsyncValue<LibraryContentData>, LibraryDataQuery>(
      (ref, query) => _browse(ref, query: query),
    );

AsyncValue<LibraryContentData> _browse(
  Ref ref, {
  required LibraryDataQuery query,
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
  final sourceQuery = query.withPage(
    source:
        query.kind == LibraryQueryKind.queue ? 'local' : share.selectedSource,
  );
  final libraryValue =
      query.limit == null
          ? ref.watch(libraryPageQueryProvider(sourceQuery))
          : ref.watch(libraryPagedQueryProvider(sourceQuery));
  final playlists = ref.watch(currentLibraryPlaylistsProvider);
  final visibleValue =
      sourceQuery.source != 'local' && libraryValue.hasValue
          ? AsyncData(libraryValue.requireValue)
          : libraryValue;
  return visibleValue.whenData((source) {
    return LibraryContentData(
      songs: source.songs,
      totalSongCount: source.totalSongCount,
      totalDuration: source.totalDuration,
      pageOffset: source.pageOffset,
      anchorIndex: source.anchorIndex,
      anchorShift: source.anchorShift,
      anchorRevision: source.anchorRevision,
      songRows: source.songRows,
      quickJumpOffsets: source.quickJumpOffsets,
      artistSummaries: source.artistSummaries,
      albumSummaries: source.albumSummaries,
      folderSummaries: source.folderSummaries,
      songFolderPaths: source.songFolderPaths,
      folderSongRows: source.folderSongRows,
      hasLibrary: source.hasLibrary,
      sortCriterion: source.sortCriterion,
      albumsSort: source.albumsSort,
      databasePath: source.databasePath,
      recentSongs: source.recentSongs.where(share.includes).toList(),
      recentPlaylists: source.recentPlaylists,
      recentAlbums: source.recentAlbums,
      recentArtists: source.recentArtists,
      recentSearches: source.recentSearches,
      playlists:
          query.kind == LibraryQueryKind.playlists ||
                  query.kind == LibraryQueryKind.playlistIndex
              ? source.playlists
              : playlists,
      folders: source.folders,
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
