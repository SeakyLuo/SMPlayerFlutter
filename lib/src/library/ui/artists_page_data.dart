part of 'artists_page.dart';

typedef _ArtistsLibraryDataRequest =
    ({
      LibraryContentData snapshot,
      Map<int, LibrarySong> songOverrides,
      SmPlayerI18n i18n,
    });

class _ArtistsLibraryData {
  const _ArtistsLibraryData({
    required this.snapshot,
    required this.artistGroups,
    required this.songsById,
  });

  final LibraryContentData snapshot;
  final List<ArtistGroup> artistGroups;
  final Map<int, LibrarySong> songsById;
}

final _artistsLibraryDataProvider = Provider.autoDispose
    .family<_ArtistsLibraryData, _ArtistsLibraryDataRequest>((ref, request) {
      final snapshot = applyLibraryFavoriteOverrides(
        request.snapshot,
        const {},
        request.songOverrides,
        ref.watch(libraryPlaylistOverridesProvider),
        ref.watch(libraryDeletedPlaylistIdsProvider),
        ref.watch(libraryPlaylistOrderProvider),
      );
      return _ArtistsLibraryData(
        snapshot: snapshot,
        artistGroups: buildArtistGroups(snapshot.songs, request.i18n),
        songsById: {for (final song in snapshot.songs) song.id: song},
      );
    });

typedef _SortedArtistGroupsRequest =
    ({List<ArtistGroup> artistGroups, ArtistSortCriterion criterion});

final _sortedArtistGroupsProvider = Provider.autoDispose
    .family<List<ArtistGroup>, _SortedArtistGroupsRequest>((ref, request) {
      return sortArtists(request.artistGroups, request.criterion);
    });

extension _ArtistsLibraryDataAccess on _ArtistsPageState {
  List<ArtistGroup> _readArtistGroups(
    LibraryContentData snapshot,
    SmPlayerI18n i18n,
  ) {
    return ref
        .read(
          _artistsLibraryDataProvider((
            snapshot: snapshot,
            songOverrides: ref.read(librarySongOverridesProvider),
            i18n: i18n,
          )),
        )
        .artistGroups;
  }
}
