import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';

import '../data/library_models.dart';
import '../../i18n/app_i18n.dart';
import 'grid_view_music.dart';
import 'local_folder_model.dart';
import 'local_page_model.dart';
import 'local_view_shared.dart';

class LocalDemandSong extends StatelessWidget {
  const LocalDemandSong({
    super.key,
    required this.song,
    required this.compact,
    required this.selectedIds,
    required this.trackId,
    required this.playing,
    required this.multiSelect,
    required this.located,
    required this.sortMode,
    required this.currentSortMode,
    required this.i18n,
    required this.onPlay,
    required this.onPlayButton,
    required this.onTogglePlayPause,
    required this.onSelect,
    required this.onPlayNext,
    required this.onFavorite,
    required this.onAdd,
    required this.onMenu,
    this.last = false,
  });
  final LibrarySong song;
  final bool compact, playing, multiSelect, located, last;
  final Set<int> selectedIds;
  final int? trackId;
  final LocalSortMode sortMode, currentSortMode;
  final SmPlayerI18n i18n;
  final VoidCallback onPlay,
      onPlayButton,
      onTogglePlayPause,
      onSelect,
      onPlayNext,
      onFavorite;
  final ValueChanged<Offset> onAdd, onMenu;

  @override
  Widget build(BuildContext context) {
    final row = DraggableLocalSong(
      key: GlobalObjectKey(song),
      payload: LocalItemsDragPayload(
        songIds:
            selectedIds.contains(song.id) ? selectedIds.toList() : [song.id],
        folderPaths: const [],
      ),
      feedbackWidth: compact ? 420 : 180,
      located: located,
      child:
          compact
              ? CompactLocalSongRow(
                song: song,
                selected: selectedIds.contains(song.id),
                current: song.id == trackId,
                playing: song.id == trackId && playing,
                selectionMode: multiSelect,
                i18n: i18n,
                onPlay: onPlay,
                onPlayButton: onPlayButton,
                onTogglePlayPause: onTogglePlayPause,
                onToggleSelection: onSelect,
                onPlayNext: onPlayNext,
                onToggleFavorite: onFavorite,
                onAddSong: onAdd,
                onOpenMenu: onMenu,
              )
              : LocalSongGridItem(
                song: song,
                selected: selectedIds.contains(song.id),
                current: song.id == trackId,
                playing: song.id == trackId && playing,
                multiSelect: multiSelect,
                detailLabel: getLocalSongDetailLabel(
                  song,
                  sortMode,
                  currentSortMode,
                  i18n,
                ),
                i18n: i18n,
                onPlay: onPlay,
                onPlayButton: onPlayButton,
                onTogglePlayPause: onTogglePlayPause,
                onToggleSelection: onSelect,
                onAddSong: onAdd,
                onOpenMenu: onMenu,
              ),
    );
    return compact
        ? LocalCompactPanelRow(
          last: last,
          reserveSeparatorSpace: true,
          child: row,
        )
        : row;
  }
}

class LocalSongGridDelegate extends SliverGridDelegate {
  const LocalSongGridDelegate();
  @override
  SliverGridLayout getLayout(SliverConstraints constraints) =>
      SliverGridRegularTileLayout(
        crossAxisCount: math.max(
          1,
          ((constraints.crossAxisExtent + 30) / 210).floor(),
        ),
        mainAxisStride: 276,
        crossAxisStride: 210,
        childMainAxisExtent: 250,
        childCrossAxisExtent: 180,
        reverseCrossAxis: axisDirectionIsReversed(
          constraints.crossAxisDirection,
        ),
      );
  @override
  bool shouldRelayout(covariant LocalSongGridDelegate oldDelegate) => false;
}
