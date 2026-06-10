part of 'recent_page.dart';

class _RecentSongGrid extends StatelessWidget {
  const _RecentSongGrid({
    required this.songs,
    required this.queueSongIds,
    required this.selectedSongIds,
    required this.multiSelect,
    required this.mediaControlState,
    required this.getTimelineDate,
    required this.getDetailLabel,
    required this.onPlaySong,
    required this.onToggleSelection,
    required this.onOpenAddToMenu,
    required this.onOpenContextMenu,
    required this.onPlayNext,
    required this.onOpenMoreMenu,
    required this.onTimelineLabelChange,
  });

  final List<LibrarySong> songs;
  final List<int> queueSongIds;
  final Set<int> selectedSongIds;
  final bool multiSelect;
  final MediaControlState mediaControlState;
  final String Function(LibrarySong song) getTimelineDate;
  final String Function(LibrarySong song) getDetailLabel;
  final void Function(
    LibrarySong song,
    List<int> queueSongIds, [
    int? queueIndex,
  ])
  onPlaySong;
  final ValueChanged<int> onToggleSelection;
  final ValueChanged<String> onTimelineLabelChange;
  final void Function(Offset position, LibrarySong song) onOpenAddToMenu;
  final void Function(Offset position, LibrarySong song, List<int> queueSongIds)
  onOpenContextMenu;
  final ValueChanged<int> onPlayNext;
  final void Function(Offset position, LibrarySong song, List<int> queueSongIds)
  onOpenMoreMenu;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return _RecentEmptyState(
        title: context.smPlayerI18n.t('recent.empty'),
        message: '',
      );
    }

    final groups = _groupRecentItems(
      songs,
      getTimelineDate,
      context.smPlayerI18n,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth - _recentSongGridRowRightPadding;
        final metrics = _RecentSongTileMetrics.forWidth(
          gridWidth,
          viewportWidth: MediaQuery.sizeOf(context).width,
        );
        final columns = ((gridWidth + _recentSongTileColumnGap) /
                (_recentSongTileWidth + _recentSongTileColumnGap))
            .floor()
            .clamp(1, 8);
        return RecentScrollbar(
          builder:
              (controller) => _RecentTimelineScrollView(
                controller: controller,
                groups: groups,
                contentExtentForGroup:
                    (group) =>
                        ((group.items.length + columns - 1) ~/ columns) *
                        metrics.rowExtent,
                onTimelineLabelChange: onTimelineLabelChange,
                slivers: [
                  for (final group in groups) ...[
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: _recentSongGridTimeGroupHeaderExtent,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              height: 26,
                              child: Text(
                                group.label,
                                style: const TextStyle(
                                  color: _RecentColors.textMuted,
                                  fontSize: 13,
                                  height: 2,
                                  fontVariations: [FontVariation('wght', 720)],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.only(
                        right: _recentSongGridRowRightPadding,
                      ),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: metrics.rowExtent,
                          crossAxisSpacing: _recentSongTileColumnGap,
                          mainAxisSpacing: 0,
                        ),
                        itemCount: group.items.length,
                        itemBuilder: (context, index) {
                          final song = group.items[index];
                          return LayoutBuilder(
                            builder:
                                (context, constraints) => Align(
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    child: _GridViewMusicItemControl(
                                      song: song,
                                      detailLabel: getDetailLabel(song),
                                      selected: selectedSongIds.contains(
                                        song.id,
                                      ),
                                      current:
                                          song.id == mediaControlState.track.id,
                                      playing:
                                          song.id ==
                                              mediaControlState.track.id &&
                                          mediaControlState.isPlaying,
                                      multiSelect: multiSelect,
                                      metrics: metrics,
                                      onPlayTrack: () {
                                        onPlaySong(
                                          song,
                                          queueSongIds,
                                          queueSongIds.indexOf(song.id),
                                        );
                                      },
                                      onToggleSelection: () {
                                        onToggleSelection(song.id);
                                      },
                                      onOpenAddToMenu: (position) {
                                        onOpenAddToMenu(position, song);
                                      },
                                      onPlayNext: () {
                                        onPlayNext(song.id);
                                      },
                                      onOpenMoreMenu: (position) {
                                        onOpenMoreMenu(
                                          position,
                                          song,
                                          queueSongIds,
                                        );
                                      },
                                      onOpenContextMenu: (position) {
                                        onOpenContextMenu(
                                          position,
                                          song,
                                          queueSongIds,
                                        );
                                      },
                                    ),
                                  ),
                                ),
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

const _recentSongGridTimeGroupHeaderExtent = 36.0;
const _recentSongGridRowRightPadding = 8.0;

class _RecentSongTileMetrics {
  const _RecentSongTileMetrics({
    required this.rowExtent,
    required this.tileExtent,
    required this.artworkSize,
    required this.padding,
    required this.copyGap,
    required this.copyLineGap,
    required this.copyPadding,
  });

  final double rowExtent;
  final double tileExtent;
  final double artworkSize;
  final EdgeInsets padding;
  final double copyGap;
  final double copyLineGap;
  final EdgeInsets copyPadding;

  static _RecentSongTileMetrics forWidth(
    double width, {
    required double viewportWidth,
  }) {
    if (viewportWidth <= 520) {
      return const _RecentSongTileMetrics(
        rowExtent: 88,
        tileExtent: 78,
        artworkSize: 78,
        padding: EdgeInsets.zero,
        copyGap: 10,
        copyLineGap: 3,
        copyPadding: EdgeInsets.fromLTRB(0, 4, 0, 4),
      );
    }
    if (width <= 520) {
      return const _RecentSongTileMetrics(
        rowExtent: 104,
        tileExtent: 92,
        artworkSize: 92,
        padding: EdgeInsets.zero,
        copyGap: 10,
        copyLineGap: 3,
        copyPadding: EdgeInsets.fromLTRB(0, 4, 0, 4),
      );
    }
    if (width < _recentMinimalContentBreakpoint) {
      return const _RecentSongTileMetrics(
        rowExtent: 136,
        tileExtent: 92,
        artworkSize: 92,
        padding: EdgeInsets.zero,
        copyGap: 10,
        copyLineGap: 3,
        copyPadding: EdgeInsets.fromLTRB(0, 4, 0, 4),
      );
    }
    return const _RecentSongTileMetrics(
      rowExtent: 136,
      tileExtent: 116,
      artworkSize: 116,
      padding: EdgeInsets.zero,
      copyGap: 12,
      copyLineGap: 5,
      copyPadding: EdgeInsets.fromLTRB(0, 8, 0, 10),
    );
  }
}

class _RecentSongTileColors {
  const _RecentSongTileColors({
    required this.activeSurface,
    required this.inactiveSurface,
    required this.activeBorder,
    required this.activeShadow,
    required this.artworkSurface,
    required this.artworkShadow,
    required this.artworkIcon,
    required this.selectionMarkBorder,
    required this.selectionMarkShadow,
    required this.textStrong,
    required this.textMuted,
    required this.textSoft,
    required this.currentText,
    required this.currentMuted,
    required this.currentSoft,
  });

  final Color activeSurface;
  final Color inactiveSurface;
  final Color activeBorder;
  final List<BoxShadow> activeShadow;
  final Color artworkSurface;
  final List<BoxShadow> artworkShadow;
  final Color artworkIcon;
  final Color selectionMarkBorder;
  final List<BoxShadow> selectionMarkShadow;
  final Color textStrong;
  final Color textMuted;
  final Color textSoft;
  final Color currentText;
  final Color currentMuted;
  final Color currentSoft;

  static const light = _RecentSongTileColors(
    activeSurface: GlobalUI.hoverBgColorDay,
    inactiveSurface: Color(0x00eaf6ff),
    activeBorder: GlobalUI.hoverBorderColorDay,
    activeShadow: [GlobalUI.hoverShadowDay],
    artworkSurface: Color(0xc2ffffff),
    artworkShadow: [
      BoxShadow(color: Color(0x47202d3f), blurRadius: 10, offset: Offset(2, 2)),
    ],
    artworkIcon: Color(0xff0078d7),
    selectionMarkBorder: Color(0xebffffff),
    selectionMarkShadow: [
      BoxShadow(color: Color(0x471f56a8), blurRadius: 16, offset: Offset(0, 8)),
    ],
    textStrong: _RecentColors.textStrong,
    textMuted: _RecentColors.textMuted,
    textSoft: _RecentColors.textSoft,
    currentText: _RecentColors.accentStrong,
    currentMuted: Color(0xff226ba4),
    currentSoft: Color(0xff4f7fa7),
  );

  static const dark = _RecentSongTileColors(
    activeSurface: GlobalUI.hoverBgColorNight,
    inactiveSurface: Color(0x000078d7),
    activeBorder: GlobalUI.hoverBorderColorNight,
    activeShadow: [
      BoxShadow(color: Color(0x38000000), blurRadius: 18, offset: Offset(0, 8)),
      BoxShadow(color: Color(0x3d0078d7), spreadRadius: 1),
    ],
    artworkSurface: Color(0x14ffffff),
    artworkShadow: [
      BoxShadow(color: Color(0x38000000), blurRadius: 10, offset: Offset(2, 2)),
    ],
    artworkIcon: _RecentColors.nightAccentText,
    selectionMarkBorder: Color(0xb8f6f9fc),
    selectionMarkShadow: [
      BoxShadow(color: Color(0x57000000), blurRadius: 18, offset: Offset(0, 8)),
    ],
    textStrong: _RecentColors.nightText,
    textMuted: _RecentColors.nightMuted,
    textSoft: _RecentColors.nightSubtle,
    currentText: _RecentColors.nightAccentText,
    currentMuted: Color(0xc2459de2),
    currentSoft: Color(0x9e459de2),
  );

  static _RecentSongTileColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}
