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
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onOpenSongAddToMenu,
    required this.onToggleSongSelection,
    required this.onOpenSongContextMenu,
    required this.hasVisibleArtists,
    this.compact = false,
    this.compactHeaderInAppBar = false,
    this.onReturnToArtistList,
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
  final VoidCallback? onReturnToArtistList;

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
                  final detailBottomPadding = responsive ? 18.0 : 30.0;
                  return CustomScrollView(
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
                              onReturnToArtistList: onReturnToArtistList,
                              onPlaySongs: () {
                                onPlaySongs(
                                  artist.songs.map((song) => song.id).toList(),
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

class _ArtistDetailHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ArtistDetailHeaderDelegate({
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_ArtistDetailHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

class _ArtistDetailHeader extends StatelessWidget {
  const _ArtistDetailHeader({
    required this.artist,
    required this.compact,
    required this.responsive,
    required this.i18n,
    required this.onReturnToArtistList,
    required this.onPlaySongs,
    required this.onOpenArtistMenu,
  });

  final ArtistGroup artist;
  final bool compact;
  final bool responsive;
  final SmPlayerI18n i18n;
  final VoidCallback? onReturnToArtistList;
  final VoidCallback onPlaySongs;
  final ValueChanged<Offset> onOpenArtistMenu;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (compact) {
      return DecoratedBox(
        key: const ValueKey('Artists.DetailHeader'),
        decoration: _ArtistsColors.compactDetailHeaderDecoration(brightness),
        child: _ArtistDetailCompactCommandRow(
          artist: artist,
          i18n: i18n,
          onReturnToArtistList: onReturnToArtistList,
          onPlaySongs: onPlaySongs,
          onOpenArtistMenu: onOpenArtistMenu,
        ),
      );
    }

    return DecoratedBox(
      key: const ValueKey('Artists.DetailHeader'),
      decoration: _ArtistsColors.detailHeaderDecoration(brightness),
      child: ClipRect(
        child: BackdropFilter(
          key: const ValueKey('Artists.DetailHeader.Blur'),
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: ColorFiltered(
            key: const ValueKey('Artists.DetailHeader.Saturate120'),
            colorFilter: _artistsBackdropSaturate120,
            child: Padding(
              key: const ValueKey('Artists.DetailHeader.Padding'),
              padding:
                  responsive
                      ? const EdgeInsets.all(18)
                      : const EdgeInsets.fromLTRB(28, 22, 28, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              key: const ValueKey('Artists.DetailHeader.Title'),
                              artist.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _ArtistsColors.textStrongFor(brightness),
                                fontSize: 28,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                fontVariations: const [
                                  FontVariation.weight(650),
                                ],
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              key: const ValueKey(
                                'Artists.DetailHeader.Summary',
                              ),
                              _formatArtistSummary(
                                i18n,
                                artist.albumCount,
                                artist.songs.length,
                              ),
                              style: TextStyle(
                                color: _ArtistsColors.detailSummaryFor(
                                  brightness,
                                ),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('Artists.DetailHeader.Shuffle'),
                        tooltip: i18n.t('nowPlaying.randomPlay'),
                        icon: const ShuffleIcon(size: 20),
                        constraints: const BoxConstraints.tightFor(
                          width: 38,
                          height: 38,
                        ),
                        style: _artistHeaderActionButtonStyle(38, brightness),
                        onPressed: onPlaySongs,
                      ),
                      const SizedBox(width: 6),
                      Builder(
                        builder: (buttonContext) {
                          return GestureDetector(
                            onSecondaryTapDown: (details) {
                              onOpenArtistMenu(details.globalPosition);
                            },
                            child: IconButton(
                              key: const ValueKey('Artists.DetailHeader.More'),
                              tooltip: i18n.t('player.more'),
                              icon: const SmPlayerMoreHorizontalIcon(size: 20),
                              constraints: const BoxConstraints.tightFor(
                                width: 38,
                                height: 38,
                              ),
                              style: _artistHeaderActionButtonStyle(
                                38,
                                brightness,
                              ),
                              onPressed: () {
                                final button =
                                    buttonContext.findRenderObject()!
                                        as RenderBox;
                                onOpenArtistMenu(
                                  button.localToGlobal(
                                    Offset(0, button.size.height + 4),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtistDetailCompactCommandRow extends StatelessWidget {
  const _ArtistDetailCompactCommandRow({
    required this.artist,
    required this.i18n,
    required this.onReturnToArtistList,
    required this.onPlaySongs,
    required this.onOpenArtistMenu,
  });

  final ArtistGroup artist;
  final SmPlayerI18n i18n;
  final VoidCallback? onReturnToArtistList;
  final VoidCallback onPlaySongs;
  final ValueChanged<Offset> onOpenArtistMenu;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('Artists.DetailHeader.Back'),
            tooltip: i18n.t('sidebar.back'),
            icon: const Icon(FluentIcons.arrow_left_20_regular, size: 17),
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            style: _artistHeaderActionButtonStyle(32, brightness),
            onPressed: onReturnToArtistList,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 32,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  key: const ValueKey('Artists.DetailHeader.Summary'),
                  _formatArtistSummary(
                    i18n,
                    artist.albumCount,
                    artist.songs.length,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ArtistsColors.textMutedFor(brightness),
                    fontSize: 14,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            key: ValueKey('Artists.DetailHeader.CompactCommandGap'),
            width: 6,
          ),
          IconButton(
            key: const ValueKey('Artists.DetailHeader.Shuffle'),
            tooltip: i18n.t('nowPlaying.randomPlay'),
            icon: const ShuffleIcon(size: 17),
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            style: _artistHeaderActionButtonStyle(32, brightness),
            onPressed: onPlaySongs,
          ),
          const SizedBox(width: 4),
          Builder(
            builder: (buttonContext) {
              return GestureDetector(
                onSecondaryTapDown: (details) {
                  onOpenArtistMenu(details.globalPosition);
                },
                child: IconButton(
                  key: const ValueKey('Artists.DetailHeader.More'),
                  tooltip: i18n.t('player.more'),
                  icon: const SmPlayerMoreHorizontalIcon(size: 17),
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  style: _artistHeaderActionButtonStyle(32, brightness),
                  onPressed: () {
                    final button =
                        buttonContext.findRenderObject()! as RenderBox;
                    onOpenArtistMenu(
                      button.localToGlobal(Offset(0, button.size.height + 4)),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

ButtonStyle _artistHeaderActionButtonStyle(double size, Brightness brightness) {
  final foreground = _ArtistsColors.headerActionForeground(brightness);
  return IconButton.styleFrom(
    fixedSize: Size.square(size),
    minimumSize: Size.square(size),
    maximumSize: Size.square(size),
    padding: EdgeInsets.zero,
    shape: const CircleBorder(),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  ).copyWith(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      return foreground;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return _ArtistsColors.headerActionHoverBackground(brightness);
      }
      return Colors.transparent;
    }),
  );
}

class _ArtistAlbumSliverSection extends StatelessWidget {
  const _ArtistAlbumSliverSection({
    required this.album,
    required this.responsive,
    required this.multiSelect,
    required this.selectedSongIds,
    required this.i18n,
    required this.queueSongIds,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.onPlaySongs,
    required this.onOpenAlbumMenu,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onOpenSongAddToMenu,
    required this.onToggleSongSelection,
    required this.onOpenSongContextMenu,
  });

  final AlbumGroup album;
  final bool responsive;
  final bool multiSelect;
  final Set<int> selectedSongIds;
  final SmPlayerI18n i18n;
  final List<int> queueSongIds;
  final int? selectedTrackId;
  final bool isPlaying;
  final VoidCallback onPlaySongs;
  final ValueChanged<Offset> onOpenAlbumMenu;
  final void Function(int songId, List<int> queueSongIds) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onPlayNext;
  final void Function(int songId, bool favorite) onToggleFavorite;
  final void Function(BuildContext context, LibrarySong song)
  onOpenSongAddToMenu;
  final ValueChanged<int> onToggleSongSelection;
  final void Function(Offset position, LibrarySong song) onOpenSongContextMenu;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final narrowSongRows = MediaQuery.sizeOf(context).width <= 1120;
    final hideFavoriteAction = MediaQuery.sizeOf(context).width <= 800;
    final songRowColors = _ArtistsColors.artistSongRowColors(brightness);
    final sectionRadius = compact ? 8.0 : 10.0;
    final horizontalPadding = 18.0;
    final bottomPadding = compact ? 12.0 : 22.0;
    final songRowTrailingPadding = compact ? 22.0 : 28.0;
    final sectionColor = _ArtistsColors.albumSection(brightness);
    final sectionBorder = _ArtistsColors.panelBorder(brightness);
    final songListBorder = _ArtistsColors.artistSongListBorder(brightness);
    final sectionShadow = BoxShadow(
      color: _ArtistsColors.albumShadow(brightness),
      offset: Offset(0, 16),
      blurRadius: 38,
    );

    return SliverPadding(
      key: ValueKey('Artists.AlbumSection.Padding.${album.name}'),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        0,
        horizontalPadding,
        bottomPadding,
      ),
      sliver: DecoratedSliver(
        key: ValueKey('Artists.AlbumSection.Shadow.${album.name}'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(sectionRadius),
          boxShadow: [sectionShadow],
        ),
        sliver: SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: DecoratedBox(
                key: ValueKey('Artists.AlbumSection.${album.name}'),
                decoration: BoxDecoration(
                  color: sectionColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(sectionRadius),
                  ),
                  border: Border(
                    top: BorderSide(color: sectionBorder),
                    left: BorderSide(color: sectionBorder),
                    right: BorderSide(color: sectionBorder),
                  ),
                ),
                child: ClipRRect(
                  key: ValueKey('Artists.AlbumSection.Clip.${album.name}'),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(sectionRadius),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: _ArtistAlbumHeader(
                    album: album,
                    responsive: responsive,
                    i18n: i18n,
                    onPlaySongs: onPlaySongs,
                    onOpenAlbumMenu: onOpenAlbumMenu,
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: album.songs.length,
              itemBuilder: (context, index) {
                final song = album.songs[index];
                final first = index == 0;
                final last = index == album.songs.length - 1;
                return _ArtistAlbumSongRowShell(
                  key:
                      first ? ValueKey('Artists.SongList.${album.name}') : null,
                  sectionColor: sectionColor,
                  sectionBorder: sectionBorder,
                  songListBorder: songListBorder,
                  first: first,
                  last: last,
                  radius: sectionRadius,
                  child: PlaylistControlItem(
                    key: ValueKey('artist-song-${song.id}'),
                    song: song,
                    current: song.id == selectedTrackId,
                    playing: song.id == selectedTrackId && isPlaying,
                    selected: selectedSongIds.contains(song.id),
                    selectionMode: multiSelect,
                    showAlbum: false,
                    variant: PlaylistControlItemVariant.compact,
                    colors: songRowColors,
                    showCompactPrimaryActions: true,
                    collapseCompactPrimaryActions: narrowSongRows,
                    compactDurationWidth: narrowSongRows ? 20 : 50,
                    compactTrailingPadding: songRowTrailingPadding,
                    showFavoriteAction: !hideFavoriteAction,
                    playNextLabel: i18n.t('context.playNext'),
                    addToPlaylistLabel: i18n.t('context.addToPlaylist'),
                    favoriteLabel: i18n.t('common.favorite'),
                    moreLabel: i18n.t('player.more'),
                    onPlayTrack: () {
                      onPlayTrack(song.id, queueSongIds);
                    },
                    onTogglePlayPause: onTogglePlayPause,
                    onToggleSelection: () {
                      onToggleSongSelection(song.id);
                    },
                    onToggleFavoriteClick: () {
                      onToggleFavorite(song.id, !song.favorite);
                    },
                    onAddToPlaylistClick: (buttonContext) {
                      onOpenSongAddToMenu(buttonContext, song);
                    },
                    onPlayNextClick: () {
                      onPlayNext(song.id);
                    },
                    onOpenContextMenu: (position) {
                      onOpenSongContextMenu(position, song);
                    },
                    onSeeArtist: (artistName) {
                      context.go(
                        '/artists?artist=${Uri.encodeQueryComponent(artistName)}',
                      );
                    },
                    onSeeAlbum: () {
                      context.go(
                        '/albums?album=${Uri.encodeQueryComponent(displayAlbum(song, i18n))}',
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistAlbumSongRowShell extends StatelessWidget {
  const _ArtistAlbumSongRowShell({
    super.key,
    required this.sectionColor,
    required this.sectionBorder,
    required this.songListBorder,
    required this.first,
    required this.last,
    required this.radius,
    required this.child,
  });

  final Color sectionColor;
  final Color sectionBorder;
  final Color songListBorder;
  final bool first;
  final bool last;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (last) {
      final roundedChild = DecoratedBox(
        decoration: BoxDecoration(
          color: sectionColor,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
          border: Border.all(color: sectionBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
          clipBehavior: Clip.hardEdge,
          child: CustomPaint(
            foregroundPainter:
                first
                    ? _ArtistAlbumSongListTopBorderPainter(songListBorder)
                    : null,
            child: child,
          ),
        ),
      );
      return roundedChild;
    }

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: sectionColor,
        border: Border(
          top: first ? BorderSide(color: songListBorder) : BorderSide.none,
          left: BorderSide(color: sectionBorder),
          right: BorderSide(color: sectionBorder),
        ),
      ),
      child: child,
    );

    return content;
  }
}

class _ArtistAlbumSongListTopBorderPainter extends CustomPainter {
  const _ArtistAlbumSongListTopBorderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 0.5), Offset(size.width, 0.5), paint);
  }

  @override
  bool shouldRepaint(_ArtistAlbumSongListTopBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ArtistAlbumHeader extends StatelessWidget {
  const _ArtistAlbumHeader({
    required this.album,
    required this.responsive,
    required this.i18n,
    required this.onPlaySongs,
    required this.onOpenAlbumMenu,
  });

  final AlbumGroup album;
  final bool responsive;
  final SmPlayerI18n i18n;
  final VoidCallback onPlaySongs;
  final ValueChanged<Offset> onOpenAlbumMenu;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final headerMinHeight = compact ? 88.0 : 112.0;
    final headerPadding =
        compact
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 18, vertical: 16);
    final headerGap = compact ? 14.0 : 16.0;
    final actionWidth =
        compact
            ? 72.0
            : responsive
            ? 36.0
            : 84.0;
    final actionButtonSize = compact ? 32.0 : 38.0;
    final actionIconSize = compact ? 17.0 : 20.0;
    return ConstrainedBox(
      key: ValueKey('Artists.AlbumHeader.${album.name}'),
      constraints: BoxConstraints(minHeight: headerMinHeight),
      child: Padding(
        key: ValueKey('Artists.AlbumHeader.Padding.${album.name}'),
        padding: headerPadding,
        child: Row(
          children: [
            AlbumArtwork(album: album, dimension: responsive ? 64 : 80),
            SizedBox(width: headerGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ArtistAlbumTitleLink(
                    albumName: album.name,
                    brightness: brightness,
                    compact: compact,
                  ),
                  SizedBox(
                    key: ValueKey('Artists.AlbumSummary.Gap.${album.name}'),
                    height: compact ? 6 : 8,
                  ),
                  Text(
                    key: ValueKey('Artists.AlbumSummary.${album.name}'),
                    i18n.t('artists.albumSummary', {
                      'songs': album.songs.length,
                      'duration': formatDuration(album.duration),
                    }),
                    style: TextStyle(
                      color: _ArtistsColors.textMutedFor(brightness),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              key: ValueKey('Artists.AlbumActions.${album.name}'),
              width: actionWidth,
              height: actionButtonSize,
              child: OverflowBox(
                minWidth: 0,
                maxWidth: 84,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      key: ValueKey('Artists.AlbumShuffle.${album.name}'),
                      tooltip: i18n.t('nowPlaying.randomPlay'),
                      icon: ShuffleIcon(size: actionIconSize),
                      constraints: BoxConstraints.tightFor(
                        width: actionButtonSize,
                        height: actionButtonSize,
                      ),
                      style: _artistHeaderActionButtonStyle(
                        actionButtonSize,
                        brightness,
                      ),
                      onPressed: onPlaySongs,
                    ),
                    SizedBox(width: compact ? 4 : 6),
                    Builder(
                      builder: (buttonContext) {
                        return GestureDetector(
                          onSecondaryTapDown: (details) {
                            onOpenAlbumMenu(details.globalPosition);
                          },
                          child: IconButton(
                            key: ValueKey('Artists.AlbumMore.${album.name}'),
                            tooltip: i18n.t('player.more'),
                            icon: SmPlayerMoreHorizontalIcon(
                              size: actionIconSize,
                            ),
                            constraints: BoxConstraints.tightFor(
                              width: actionButtonSize,
                              height: actionButtonSize,
                            ),
                            style: _artistHeaderActionButtonStyle(
                              actionButtonSize,
                              brightness,
                            ),
                            onPressed: () {
                              final button =
                                  buttonContext.findRenderObject()!
                                      as RenderBox;
                              onOpenAlbumMenu(
                                button.localToGlobal(
                                  Offset(0, button.size.height + 4),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistAlbumTitleLink extends StatefulWidget {
  const _ArtistAlbumTitleLink({
    required this.albumName,
    required this.brightness,
    required this.compact,
  });

  final String albumName;
  final Brightness brightness;
  final bool compact;

  @override
  State<_ArtistAlbumTitleLink> createState() => _ArtistAlbumTitleLinkState();
}

class _ArtistAlbumTitleLinkState extends State<_ArtistAlbumTitleLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color =
        _hovered
            ? _ArtistsColors.albumTitleHoverForeground(widget.brightness)
            : _ArtistsColors.textStrongFor(widget.brightness);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      onHover: (hovered) {
        if (_hovered == hovered) {
          return;
        }
        setState(() {
          _hovered = hovered;
        });
      },
      onTap: () {
        context.go(
          '/albums?album=${Uri.encodeQueryComponent(widget.albumName)}',
        );
      },
      child: Text(
        key: ValueKey('Artists.AlbumTitle.${widget.albumName}'),
        widget.albumName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: widget.compact ? 17 : 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AlbumArtwork extends StatelessWidget {
  const AlbumArtwork({super.key, required this.album, required this.dimension});

  final AlbumGroup album;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    final firstSong = getAlbumArtworkSong(album.songs);
    final brightness = Theme.of(context).brightness;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox.square(
        key: ValueKey('Artists.AlbumArtwork.${album.name}'),
        dimension: dimension,
        child: DecoratedBox(
          key: ValueKey('Artists.AlbumArtwork.Background.${album.name}'),
          decoration: BoxDecoration(
            color: _ArtistsColors.albumArtworkBackground(brightness),
          ),
          child: SongArtwork(artworkPath: firstSong.thumbnailPath),
        ),
      ),
    );
  }
}
