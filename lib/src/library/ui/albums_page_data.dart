part of 'albums_page.dart';

typedef _AlbumsLibraryDataRequest =
    ({
      LibraryContentData snapshot,
      Map<int, LibrarySong> songOverrides,
      SmPlayerI18n i18n,
    });

class _AlbumsLibraryData {
  const _AlbumsLibraryData({
    required this.snapshot,
    required this.albums,
    required this.songsById,
  });

  final LibraryContentData snapshot;
  final List<AlbumView> albums;
  final Map<int, LibrarySong> songsById;
}

final _albumsLibraryDataProvider = Provider.autoDispose.family<
  _AlbumsLibraryData,
  _AlbumsLibraryDataRequest
>((ref, request) {
  final snapshot = applyLibraryFavoriteOverrides(
    request.snapshot,
    const {},
    request.songOverrides,
    ref.watch(libraryPlaylistOverridesProvider),
    ref.watch(libraryDeletedPlaylistIdsProvider),
    ref.watch(libraryPlaylistOrderProvider),
  );
  return _AlbumsLibraryData(
    snapshot: snapshot,
    albums: [
      for (final item in snapshot.albumSummaries)
        AlbumView(
          name:
              item.name.isEmpty
                  ? request.i18n.t('common.albumUnknown')
                  : item.name,
          rawName: item.name,
          artist:
              item.artists.first.isEmpty
                  ? request.i18n.t('common.artistUnknown')
                  : item.artists.first,
          artists: [
            for (final artist in item.artists)
              artist.isEmpty ? request.i18n.t('common.artistUnknown') : artist,
          ],
          songs:
              snapshot.songs.where((song) => song.album == item.name).toList(),
          duration: item.duration,
          artworkSong: null,
          artworkPath: item.artworkPath,
          summarySongCount: item.songCount,
        ),
    ],
    songsById: {for (final song in snapshot.songs) song.id: song},
  );
});

typedef _VisibleAlbumsRequest =
    ({
      List<AlbumView> albums,
      AlbumSortCriterion criterion,
      String searchQuery,
      bool reverse,
      LibraryIndex libraryIndex,
    });

class _VisibleAlbumsData {
  const _VisibleAlbumsData({required this.albums, required this.quickJumpMap});

  final List<AlbumView> albums;
  final Map<String, int> quickJumpMap;
}

final _visibleAlbumsProvider = Provider.autoDispose
    .family<_VisibleAlbumsData, _VisibleAlbumsRequest>((ref, request) {
      final baseAlbums =
          request.searchQuery.trim().isEmpty
              ? sortAlbums(
                request.albums,
                request.criterion,
                libraryIndex: request.libraryIndex,
              )
              : searchAlbums(request.albums, request.searchQuery);
      final albums =
          request.reverse ? baseAlbums.reversed.toList() : baseAlbums;
      return _VisibleAlbumsData(
        albums: albums,
        quickJumpMap: buildAlbumQuickJumpMap(
          albums,
          criterion: request.criterion,
          libraryIndex: request.libraryIndex,
        ),
      );
    });

typedef _AlbumSearchSuggestionsRequest =
    ({List<AlbumView> albums, String searchDraft});

final _albumSearchSuggestionsProvider = Provider.autoDispose
    .family<List<String>, _AlbumSearchSuggestionsRequest>((ref, request) {
      if (request.searchDraft.trim().isEmpty) {
        return const [];
      }
      return searchAlbums(
        request.albums,
        request.searchDraft,
      ).take(8).map((album) => album.name).toList();
    });

extension _AlbumSummaryActions on _AlbumsPageState {
  Future<AlbumView> _loadAlbumSummary(AlbumView album) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final query = LibraryDataQuery(
      LibraryQueryKind.album,
      album: album.preferenceId,
      source: container.read(musicShareProvider).selectedSource,
    );
    final source = container.read(selectedLibraryDataSourceProvider);
    final results = await Future.wait([
      source.query(
        LibraryDataQuery(
          LibraryQueryKind.album,
          album: album.preferenceId,
          limit: 1,
        ),
      ),
      source.resolveSongIds(query),
    ]);
    final page = results[0] as LibraryContentData;
    return album.withSongs(page.songs, ids: results[1] as List<int>);
  }

  Future<void> _playAlbumSummary(AlbumView album) async {
    final ids = await ref
        .read(selectedLibraryDataSourceProvider)
        .resolveSongIds(
          LibraryDataQuery(LibraryQueryKind.album, album: album.preferenceId),
        );
    if (!mounted) return;
    await recordRecentAlbumPlayback(ref, album.name);
    await _playSongIds(ids);
  }
}
