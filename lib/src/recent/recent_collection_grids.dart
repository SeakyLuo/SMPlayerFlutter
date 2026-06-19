part of 'recent_page.dart';

class _RecentPlaylistGrid extends StatelessWidget {
  const _RecentPlaylistGrid({
    required this.playlists,
    required this.multiSelect,
    required this.selectedKeys,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSelection,
    required this.onTimelineLabelChange,
  });

  final List<RecentPlaylistView> playlists;
  final bool multiSelect;
  final Set<String> selectedKeys;
  final ValueChanged<int> onOpen;
  final ValueChanged<RecentPlaylistView> onPlay;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<String> onTimelineLabelChange;

  @override
  Widget build(BuildContext context) {
    return _RecentCollectionGrid<RecentPlaylistView>(
      items: playlists,
      playedAt: (playlist) => playlist.playedAt,
      onTimelineLabelChange: onTimelineLabelChange,
      itemBuilder: (context, playlist) {
        final key = 'playlists:${playlist.playlist.id}';
        return GridViewHolder(
          playlist: playlist.playlist,
          songs: playlist.songs,
          subtitle: formatRecentDateTime(playlist.playedAt),
          playTooltip: context.smPlayerI18n.t('context.play'),
          selected: selectedKeys.contains(key),
          selectionMode: multiSelect,
          showDragHandle: false,
          selectedMark:
              multiSelect || selectedKeys.contains(key)
                  ? GridViewSelectionMark(selected: selectedKeys.contains(key))
                  : null,
          onOpen: () {
            if (multiSelect) {
              onToggleSelection(key);
            } else {
              onOpen(playlist.playlist.id);
            }
          },
          onPlay: () => onPlay(playlist),
        );
      },
    );
  }
}

class _RecentAlbumGrid extends StatelessWidget {
  const _RecentAlbumGrid({
    required this.albums,
    required this.multiSelect,
    required this.selectedKeys,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSelection,
    required this.onTimelineLabelChange,
    required this.onOpenContextMenu,
  });

  final List<RecentAlbumView> albums;
  final bool multiSelect;
  final Set<String> selectedKeys;
  final ValueChanged<String> onOpen;
  final ValueChanged<RecentAlbumView> onPlay;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<String> onTimelineLabelChange;
  final void Function(Offset position, RecentAlbumView album) onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    return _RecentCollectionGrid<RecentAlbumView>(
      items: albums,
      playedAt: (album) => album.playedAt,
      onTimelineLabelChange: onTimelineLabelChange,
      itemBuilder: (context, album) {
        final key = 'albums:${album.name}';
        return _RecentAlbumCard(
          album: album,
          subtitle: formatRecentDateTime(album.playedAt),
          selected: selectedKeys.contains(key),
          selectionMode: multiSelect,
          onOpen: () {
            if (multiSelect) {
              onToggleSelection(key);
            } else {
              onOpen(album.name);
            }
          },
          onPlay: () => onPlay(album),
          onAdd: (position) {
            onOpenContextMenu(position, album);
          },
          onToggleSelection: () {
            onToggleSelection(key);
          },
          onOpenContextMenu: (position) {
            onOpenContextMenu(position, album);
          },
        );
      },
    );
  }
}

class _RecentAlbumCard extends StatefulWidget {
  const _RecentAlbumCard({
    required this.album,
    required this.subtitle,
    required this.selected,
    required this.selectionMode,
    required this.onOpen,
    required this.onPlay,
    required this.onAdd,
    required this.onToggleSelection,
    required this.onOpenContextMenu,
  });

  final RecentAlbumView album;
  final String subtitle;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final ValueChanged<Offset> onAdd;
  final VoidCallback onToggleSelection;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  State<_RecentAlbumCard> createState() => _RecentAlbumCardState();
}

class _RecentAlbumCardState extends State<_RecentAlbumCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colors = _RecentCollectionCardColors.forBrightness(brightness);
    final selectedStyle = SelectedCollectionCardStyle.forBrightness(brightness);
    final hoverStyle = SelectedCollectionCardStyle.hoverForBrightness(
      brightness,
    );
    final active = _hovered;
    final firstArtworkSong = getAlbumArtworkSong(widget.album.songs);
    final artworkUrls =
        firstArtworkSong.thumbnailPath.isEmpty
            ? const <String>[]
            : [firstArtworkSong.thumbnailPath];
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: Align(
        alignment: Alignment.topLeft,
        child: GestureDetector(
          onTap: widget.onOpen,
          onSecondaryTapDown: (details) {
            widget.onOpenContextMenu(details.globalPosition);
          },
          child: AnimatedContainer(
            key: const ValueKey('RecentAlbum.Card'),
            duration: const Duration(milliseconds: 120),
            width: gridViewHolderWidth,
            constraints: const BoxConstraints(minHeight: gridViewHolderHeight),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  widget.selected
                      ? selectedStyle.background
                      : active
                      ? hoverStyle.background
                      : hoverStyle.transparentBackground,
              borderRadius: BorderRadius.circular(12),
              boxShadow:
                  widget.selected || active
                      ? [
                        BoxShadow(
                          color:
                              widget.selected
                                  ? selectedStyle.shadow.color
                                  : hoverStyle.shadow.color,
                          blurRadius:
                              widget.selected
                                  ? selectedStyle.shadow.blurRadius
                                  : hoverStyle.shadow.blurRadius,
                          offset:
                              widget.selected
                                  ? selectedStyle.shadow.offset
                                  : hoverStyle.shadow.offset,
                        ),
                      ]
                      : null,
            ),
            foregroundDecoration:
                widget.selected || active
                    ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            widget.selected
                                ? selectedStyle.border
                                : hoverStyle.border,
                      ),
                    )
                    : null,
            child: GridArtworkCardContent(
              title: widget.album.name,
              subtitle: widget.subtitle,
              artworkUrls: artworkUrls,
              fallback: const DefaultAlbumArtwork(),
              selectedMark:
                  widget.selectionMode || widget.selected
                      ? GridViewSelectionMark(selected: widget.selected)
                      : null,
              showActions: !widget.selectionMode && _hovered,
              textStrongColor:
                  widget.selected
                      ? selectedStyle.foreground
                      : colors.textStrong,
              textMutedColor:
                  widget.selected ? selectedStyle.muted : colors.textMuted,
              artworkKey: const ValueKey('RecentAlbum.ArtworkSurface'),
              actions: [
                GridArtworkAction(
                  title: context.smPlayerI18n.t('detail.playAlbum'),
                  onPressed: widget.onPlay,
                ),
                GridArtworkAction(
                  title: context.smPlayerI18n.t('context.addToPlaylist'),
                  icon: const Icon(
                    FluentIcons.add_20_regular,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () {
                    final box = context.findRenderObject() as RenderBox;
                    widget.onAdd(
                      box.localToGlobal(
                        Offset(
                          gridViewHolderWidth / 2,
                          gridViewHolderHeight / 2,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentCollectionCardColors {
  const _RecentCollectionCardColors({
    required this.textStrong,
    required this.textMuted,
  });

  final Color textStrong;
  final Color textMuted;

  static _RecentCollectionCardColors forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  static const light = _RecentCollectionCardColors(
    textStrong: Color(0xff1f252b),
    textMuted: Color(0xff5f625f),
  );

  static const dark = _RecentCollectionCardColors(
    textStrong: Color(0xf0f6f9fc),
    textMuted: Color(0xadcbd5e1),
  );
}

class _RecentArtistList extends StatelessWidget {
  const _RecentArtistList({
    required this.artists,
    required this.multiSelect,
    required this.selectedKeys,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSelection,
    required this.onTimelineLabelChange,
    required this.onOpenContextMenu,
  });

  final List<RecentArtistView> artists;
  final bool multiSelect;
  final Set<String> selectedKeys;
  final ValueChanged<String> onOpen;
  final ValueChanged<RecentArtistView> onPlay;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<String> onTimelineLabelChange;
  final void Function(Offset position, RecentArtistView artist)
  onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return _RecentEmptyState(
        title: context.smPlayerI18n.t('recent.empty'),
        message: '',
      );
    }

    final groups = _groupRecentItems(
      artists,
      (artist) => artist.playedAt,
      context.smPlayerI18n,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _recentArtistColumnCount(constraints.maxWidth);
        return RecentScrollbar(
          trailingEdgeOffset: _recentWideScrollbarTrailingOffset,
          builder:
              (controller) => _RecentTimelineScrollView(
                controller: controller,
                groups: groups,
                contentExtentForGroup: (group) {
                  final rows = (group.items.length + columns - 1) ~/ columns;
                  return rows * _recentArtistRowHeight +
                      (rows > 0 ? rows - 1 : 0) * _recentArtistRowGap;
                },
                onTimelineLabelChange: onTimelineLabelChange,
                slivers: [
                  for (final group in groups) ...[
                    _RecentTimeGroupHeader(label: group.label),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        8,
                        0,
                        _recentCollectionGridRightPadding,
                        0,
                      ),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: _recentArtistRowHeight,
                          crossAxisSpacing: _recentArtistColumnGap,
                          mainAxisSpacing: _recentArtistRowGap,
                        ),
                        itemCount: group.items.length,
                        itemBuilder: (context, index) {
                          final artist = group.items[index];
                          final key = 'artists:${artist.name}';
                          return _ArtistRow(
                            artist: artist,
                            imagePath: artist.artworkUrl,
                            selected: selectedKeys.contains(key),
                            multiSelect: multiSelect,
                            onOpen: () {
                              if (multiSelect) {
                                onToggleSelection(key);
                              } else {
                                onOpen(artist.name);
                              }
                            },
                            onPlay: () => onPlay(artist),
                            onOpenContextMenu: (position) {
                              onOpenContextMenu(position, artist);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 92)),
                ],
              ),
        );
      },
    );
  }
}

class _RecentCollectionGrid<T> extends StatelessWidget {
  const _RecentCollectionGrid({
    required this.items,
    required this.playedAt,
    required this.onTimelineLabelChange,
    required this.itemBuilder,
  });

  final List<T> items;
  final String Function(T item) playedAt;
  final ValueChanged<String> onTimelineLabelChange;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _RecentEmptyState(
        title: context.smPlayerI18n.t('recent.empty'),
        message: '',
      );
    }

    final groups = _groupRecentItems(items, playedAt, context.smPlayerI18n);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _recentCollectionColumnCount(constraints.maxWidth);
        return RecentScrollbar(
          trailingEdgeOffset: _recentWideScrollbarTrailingOffset,
          builder:
              (controller) => _RecentTimelineScrollView(
                controller: controller,
                groups: groups,
                contentExtentForGroup:
                    (group) =>
                        ((group.items.length + columns - 1) ~/ columns) *
                            (_recentCollectionTileHeight +
                                _recentCollectionRowGap) +
                        22,
                onTimelineLabelChange: onTimelineLabelChange,
                slivers: [
                  for (final group in groups) ...[
                    _RecentTimeGroupHeader(label: group.label),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        8,
                        0,
                        _recentCollectionGridRightPadding,
                        22,
                      ),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: _recentCollectionTileHeight,
                          crossAxisSpacing: _recentCollectionColumnGap,
                          mainAxisSpacing: _recentCollectionRowGap,
                        ),
                        itemCount: group.items.length,
                        itemBuilder:
                            (context, index) =>
                                itemBuilder(context, group.items[index]),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 70)),
                ],
              ),
        );
      },
    );
  }
}

class _RecentTimeGroupHeader extends StatelessWidget {
  const _RecentTimeGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 0, 10),
        child: Text(
          label,
          style: const TextStyle(
            color: _RecentColors.textMuted,
            fontSize: 13,
            fontVariations: [FontVariation('wght', 720)],
          ),
        ),
      ),
    );
  }
}

class _ArtistRow extends StatelessWidget {
  const _ArtistRow({
    required this.artist,
    required this.imagePath,
    required this.selected,
    required this.multiSelect,
    required this.onOpen,
    required this.onPlay,
    required this.onOpenContextMenu,
  });

  final RecentArtistView artist;
  final String imagePath;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    final selectedStyle = SelectedCollectionCardStyle.forBrightness(
      Theme.of(context).brightness,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onSecondaryTapDown: (details) {
          onOpenContextMenu(details.globalPosition);
        },
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? selectedStyle.background : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: selectedStyle.border) : null,
            boxShadow: selected ? [selectedStyle.shadow] : null,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox.square(
                  dimension: 52,
                  child: SongArtwork(artworkPath: imagePath),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            selected
                                ? selectedStyle.foreground
                                : _RecentColors.textStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatRecentDateTime(artist.playedAt),
                      style: TextStyle(
                        color:
                            selected
                                ? selectedStyle.muted
                                : _RecentColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (multiSelect)
                Icon(
                  selected
                      ? FluentIcons.checkmark_circle_20_filled
                      : FluentIcons.circle_20_regular,
                  color:
                      selected ? _RecentColors.accent : _RecentColors.textMuted,
                )
              else
                IconButton(
                  tooltip: context.smPlayerI18n.t('nowPlaying.randomPlay'),
                  icon: const SmPlayerPlayIcon(),
                  onPressed: onPlay,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

int _recentCollectionColumnCount(double width) {
  final available = (width - 22).clamp(0.0, double.infinity);
  return ((available + _recentCollectionColumnGap) /
          (_recentCollectionTileWidth + _recentCollectionColumnGap))
      .floor()
      .clamp(1, 8);
}

int _recentArtistColumnCount(double width) {
  final available = (width - 22).clamp(0.0, double.infinity);
  return ((available + _recentArtistColumnGap) /
          (_recentArtistMinColumnWidth + _recentArtistColumnGap))
      .floor()
      .clamp(1, 8);
}

String _displayAlbum(LibrarySong song, SmPlayerI18n i18n) {
  return displayAlbum(song, i18n);
}
