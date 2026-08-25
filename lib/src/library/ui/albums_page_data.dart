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

final _albumsLibraryDataProvider = Provider.autoDispose
    .family<_AlbumsLibraryData, _AlbumsLibraryDataRequest>((ref, request) {
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
        albums: buildAlbumViews(snapshot.songs, request.i18n),
        songsById: {for (final song in snapshot.songs) song.id: song},
      );
    });

typedef _VisibleAlbumsRequest =
    ({
      List<AlbumView> albums,
      AlbumSortCriterion criterion,
      String searchQuery,
      bool reverse,
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
              ? sortAlbums(request.albums, request.criterion)
              : searchAlbums(request.albums, request.searchQuery);
      final albums =
          request.reverse ? baseAlbums.reversed.toList() : baseAlbums;
      return _VisibleAlbumsData(
        albums: albums,
        quickJumpMap: buildAlbumQuickJumpMap(albums),
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
