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
      return _ArtistsLibraryData(
        snapshot: request.snapshot,
        artistGroups: [
          for (final item in request.snapshot.artistSummaries)
            ArtistGroup(
              name:
                  item.name.isEmpty
                      ? request.i18n.t('common.artistUnknown')
                      : item.name,
              sourceName: item.name,
              songs: const [],
              songCount: item.songCount,
              albumCount: item.albumCount,
              artworkSongId: item.artworkSongId,
              artworkPath: item.artworkPath,
            ),
        ],
        songsById: {for (final song in request.snapshot.songs) song.id: song},
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

extension _ArtistSummaryActions on _ArtistsPageState {
  Future<void> _selectArtistScope(
    ArtistGroup artist, {
    required bool reverse,
  }) => runMusicShareAction(context, () async {
    final source = ref.read(selectedLibraryDataSourceProvider);
    final ids = await source.resolveSongIds(
      LibraryDataQuery(LibraryQueryKind.artist, artists: [artist.sourceName]),
    );
    if (!mounted ||
        ref.read(selectedLibraryDataSourceProvider).source != source.source ||
        _detailArtistSource != artist.sourceName)
      return;
    _updateArtistsPageState(() {
      if (reverse) {
        _selection.reverseSelection(ids);
      } else {
        _selection.selectAll(ids);
      }
    });
  });

  Future<void> _playArtistSummary(ArtistGroup artist) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final songs = await container
        .read(selectedLibraryDataSourceProvider)
        .selectSongIds(
          LibrarySelectionRequest(
            LibrarySelectionKind.currentArtist,
            artists: [artist.sourceName],
          ),
        );
    if (!mounted) return;
    await recordRecentArtistPlayback(ref, artist.name);
    _playSongIds(songs);
  }

  Future<void> _showArtistSummaryMenu(
    Offset position,
    ArtistGroup artist,
  ) async {
    await _showGroupContextMenu(
      position: position,
      type: _ArtistGroupMenuType.artist,
      label: artist.name,
      songs: const [],
    );
  }
}
