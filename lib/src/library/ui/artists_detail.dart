part of 'artists_page.dart';

class _ArtistsDetail extends StatelessWidget {
  const _ArtistsDetail({
    required this.selectedArtist,
    required this.scrollController,
    required this.multiSelect,
    required this.selectedSongIds,
    required this.i18n,
    required this.onPlaySongs,
    required this.onOpenArtistMenu,
    required this.onOpenAlbumMenu,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.onPlayTrack,
    required this.onPlaySong,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onOpenSongAddToMenu,
    required this.onToggleSongSelection,
    required this.onOpenSongContextMenu,
    required this.hasVisibleArtists,
    this.compact = false,
    this.compactHeaderInAppBar = false,
  });

  final ArtistGroup? selectedArtist;
  final ScrollController scrollController;
  final bool multiSelect;
  final Set<int> selectedSongIds;
  final SmPlayerI18n i18n;
  final void Function(
    List<int> songIds, {
    String? artistName,
    String? albumName,
  })
  onPlaySongs;
  final void Function(
    Offset position,
    ArtistGroup artist, {
    required bool showLocateArtist,
  })
  onOpenArtistMenu;
  final void Function(Offset position, AlbumGroup album) onOpenAlbumMenu;
  final int? selectedTrackId;
  final bool isPlaying;
  final void Function(int songId, List<int> queueSongIds) onPlayTrack;
  final ValueChanged<int> onPlaySong;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onPlayNext;
  final void Function(int songId, bool favorite) onToggleFavorite;
  final void Function(BuildContext context, LibrarySong song)
  onOpenSongAddToMenu;
  final ValueChanged<int> onToggleSongSelection;
  final void Function(Offset position, LibrarySong song) onOpenSongContextMenu;
  final bool hasVisibleArtists;
  final bool compact;
  final bool compactHeaderInAppBar;

  @override
  Widget build(BuildContext context) {
    final artist = selectedArtist;
    if (artist == null) {
      final brightness = Theme.of(context).brightness;
      return ColoredBox(
        key: const ValueKey('Artists.DetailSurface'),
        color: _ArtistsColors.detailBackground(brightness),
        child: _ArtistsEmptyState(
          title:
              hasVisibleArtists
                  ? i18n.t('artists.selectArtist')
                  : i18n.t('collection.noArtists'),
          message: hasVisibleArtists ? '' : i18n.t('artists.emptyCopy'),
          detail: true,
        ),
      );
    }

    final albums = buildAlbumGroups(artist.songs, i18n);
    final brightness = Theme.of(context).brightness;
    final responsive = MediaQuery.sizeOf(context).width <= 860;
    final albumListTopPadding = compact ? 14.0 : 22.0;
    final albumHeights =
        albums
            .map(
              (album) => getEstimatedArtistAlbumHeight(album, compact: compact),
            )
            .toList();
    final headerHeight = compact ? 40.0 : 108.0;
    final albumListOffsetTop =
        (compactHeaderInAppBar ? 0.0 : headerHeight) + albumListTopPadding;
    return ColoredBox(
      key: const ValueKey('Artists.DetailSurface'),
      color: _ArtistsColors.detailBackground(brightness),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return AnimatedBuilder(
                animation: scrollController,
                builder: (context, _) {
                  final scrollTop =
                      scrollController.hasClients
                          ? scrollController.offset
                          : 0.0;
                  final albumVirtualWindow = getArtistAlbumVirtualWindow(
                    albumHeights,
                    max(0, scrollTop - albumListOffsetTop).toDouble(),
                    constraints.maxHeight,
                  );
                  final renderedAlbums = albums.sublist(
                    albumVirtualWindow.startIndex,
                    albumVirtualWindow.endIndex,
                  );
                  final detailBottomPadding =
                      multiSelect
                          ? multiSelectCommandBarScrollSpacer
                          : responsive
                          ? 18.0
                          : 30.0;
                  return ScrollConfiguration(
                    key: const ValueKey('Artists.DetailScrollConfiguration'),
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        if (!compactHeaderInAppBar)
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _ArtistDetailHeaderDelegate(
                              height: headerHeight,
                              child: _ArtistDetailHeader(
                                artist: artist,
                                compact: compact,
                                responsive: responsive,
                                i18n: i18n,
                                onPlaySongs: () {
                                  onPlaySongs(
                                    artist.songs
                                        .map((song) => song.id)
                                        .toList(),
                                    artistName: artist.name,
                                  );
                                },
                                onOpenArtistMenu: (position) {
                                  onOpenArtistMenu(
                                    position,
                                    artist,
                                    showLocateArtist: true,
                                  );
                                },
                              ),
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            key: const ValueKey('Artists.AlbumList.TopPadding'),
                            height: albumListTopPadding,
                          ),
                        ),
                        if (albumVirtualWindow.topSpacerHeight > 0)
                          SliverToBoxAdapter(
                            child: SizedBox(
                              key: const ValueKey(
                                'Artists.AlbumVirtual.TopSpacer',
                              ),
                              height: albumVirtualWindow.topSpacerHeight,
                            ),
                          ),
                        for (final album in renderedAlbums)
                          _ArtistAlbumSliverSection(
                            album: album,
                            responsive: responsive,
                            multiSelect: multiSelect,
                            selectedSongIds: selectedSongIds,
                            i18n: i18n,
                            queueSongIds:
                                artist.songs.map((song) => song.id).toList(),
                            selectedTrackId: selectedTrackId,
                            isPlaying: isPlaying,
                            onPlaySongs: () {
                              onPlaySongs(
                                album.songs.map((song) => song.id).toList(),
                                albumName: album.name,
                              );
                            },
                            onOpenAlbumMenu: (position) {
                              onOpenAlbumMenu(position, album);
                            },
                            onPlayTrack: onPlayTrack,
                            onPlaySong: onPlaySong,
                            onTogglePlayPause: onTogglePlayPause,
                            onPlayNext: onPlayNext,
                            onToggleFavorite: onToggleFavorite,
                            onOpenSongAddToMenu: onOpenSongAddToMenu,
                            onToggleSongSelection: onToggleSongSelection,
                            onOpenSongContextMenu: onOpenSongContextMenu,
                          ),
                        if (albumVirtualWindow.bottomSpacerHeight > 0)
                          SliverToBoxAdapter(
                            child: SizedBox(
                              key: const ValueKey(
                                'Artists.AlbumVirtual.BottomSpacer',
                              ),
                              height: albumVirtualWindow.bottomSpacerHeight,
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            key: const ValueKey('Artists.Detail.BottomPadding'),
                            height: detailBottomPadding,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          _ArtistsCustomScrollbar(
            key: const ValueKey('Artists.DetailScrollbar'),
            positionKey: const ValueKey('Artists.DetailScrollbar.Position'),
            thumbKey: const ValueKey('Artists.DetailScrollbar.Thumb'),
            controller: scrollController,
            right: 4,
          ),
        ],
      ),
    );
  }
}
