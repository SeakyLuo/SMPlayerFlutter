import 'package:flutter/material.dart';

import 'package:smplayer_flutter/src/library/data/library_models.dart';

import 'playlist_control_item.dart';

export 'playlist_control_item.dart';

class PlaylistControlEntry {
  const PlaylistControlEntry({
    required this.key,
    required this.song,
    required this.current,
    required this.playing,
    required this.selected,
    required this.selectionMode,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onToggleSelection,
    required this.onOpenContextMenu,
    this.logicalIndex,
    this.showAlbum = false,
    this.variant = PlaylistControlItemVariant.standard,
    this.colors,
    this.showCompactPrimaryActions = false,
    this.collapseCompactPrimaryActions = false,
    this.compactDurationWidth,
    this.compactTrailingPadding,
    this.showFavoriteAction = true,
    this.playNextLabel,
    this.removeLabel,
    this.addToPlaylistLabel,
    this.favoriteLabel,
    this.moreLabel,
    this.onToggleFavoriteClick,
    this.onAddToPlaylistClick,
    this.onPlayNextClick,
    this.onRemoveFromListClick,
    this.onSeeArtist,
    this.onSeeAlbum,
  });

  final Key key;
  final LibrarySong song;
  final int? logicalIndex;
  final bool current;
  final bool playing;
  final bool selected;
  final bool selectionMode;
  final bool showAlbum;
  final PlaylistControlItemVariant variant;
  final PlaylistControlItemColors? colors;
  final bool showCompactPrimaryActions;
  final bool collapseCompactPrimaryActions;
  final double? compactDurationWidth;
  final double? compactTrailingPadding;
  final bool showFavoriteAction;
  final String? playNextLabel;
  final String? removeLabel;
  final String? addToPlaylistLabel;
  final String? favoriteLabel;
  final String? moreLabel;
  final VoidCallback onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleSelection;
  final VoidCallback? onToggleFavoriteClick;
  final ValueChanged<BuildContext>? onAddToPlaylistClick;
  final VoidCallback? onPlayNextClick;
  final VoidCallback? onRemoveFromListClick;
  final ValueChanged<Offset> onOpenContextMenu;
  final ValueChanged<String>? onSeeArtist;
  final VoidCallback? onSeeAlbum;
}

class PlaylistControl extends StatelessWidget {
  const PlaylistControl({
    super.key,
    required this.entries,
    this.padding = EdgeInsets.zero,
    this.itemShellBuilder,
  }) : scrollController = null,
       onReorder = null;

  const PlaylistControl.sliver({
    super.key,
    required this.entries,
    this.itemShellBuilder,
  }) : padding = EdgeInsets.zero,
       scrollController = null,
       onReorder = null;

  const PlaylistControl.reorderable({
    super.key,
    required this.entries,
    required this.scrollController,
    required this.onReorder,
    this.padding = EdgeInsets.zero,
    this.itemShellBuilder,
  });

  final List<PlaylistControlEntry> entries;
  final EdgeInsets padding;
  final ScrollController? scrollController;
  final ReorderCallback? onReorder;
  final Widget Function(BuildContext context, int index, Widget child)?
  itemShellBuilder;

  @override
  Widget build(BuildContext context) {
    if (onReorder != null) {
      return ReorderableListView.builder(
        scrollController: scrollController,
        padding: padding,
        buildDefaultDragHandles: false,
        itemCount: entries.length,
        onReorderItem: onReorder!,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return ReorderableDragStartListener(
            key: entry.key,
            index: index,
            child: _buildEntry(context, index, entry),
          );
        },
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: padding,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _buildEntry(context, index, entries[index]);
      },
    );
  }

  Widget buildSliver(BuildContext context) {
    return SliverList.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _buildEntry(context, index, entries[index]);
      },
    );
  }

  Widget _buildEntry(
    BuildContext context,
    int index,
    PlaylistControlEntry entry,
  ) {
    final item = PlaylistControlItem(
      key: entry.key,
      song: entry.song,
      current: entry.current,
      playing: entry.playing,
      selected: entry.selected,
      selectionMode: entry.selectionMode,
      showAlbum: entry.showAlbum,
      variant: entry.variant,
      colors: entry.colors,
      showCompactPrimaryActions: entry.showCompactPrimaryActions,
      collapseCompactPrimaryActions: entry.collapseCompactPrimaryActions,
      compactDurationWidth: entry.compactDurationWidth,
      compactTrailingPadding: entry.compactTrailingPadding,
      showFavoriteAction: entry.showFavoriteAction,
      playNextLabel: entry.playNextLabel,
      removeLabel: entry.removeLabel,
      addToPlaylistLabel: entry.addToPlaylistLabel,
      favoriteLabel: entry.favoriteLabel,
      moreLabel: entry.moreLabel,
      onPlayTrack: entry.onPlayTrack,
      onTogglePlayPause: entry.onTogglePlayPause,
      onToggleSelection: entry.onToggleSelection,
      onToggleFavoriteClick: entry.onToggleFavoriteClick,
      onAddToPlaylistClick: entry.onAddToPlaylistClick,
      onPlayNextClick: entry.onPlayNextClick,
      onRemoveFromListClick: entry.onRemoveFromListClick,
      onOpenContextMenu: entry.onOpenContextMenu,
      onSeeArtist: entry.onSeeArtist,
      onSeeAlbum: entry.onSeeAlbum,
    );
    return itemShellBuilder?.call(context, index, item) ?? item;
  }
}

class PlaylistControlSliver extends StatelessWidget {
  const PlaylistControlSliver({
    super.key,
    required this.entries,
    this.itemShellBuilder,
  });

  final List<PlaylistControlEntry> entries;
  final Widget Function(BuildContext context, int index, Widget child)?
  itemShellBuilder;

  @override
  Widget build(BuildContext context) {
    return PlaylistControl.sliver(
      entries: entries,
      itemShellBuilder: itemShellBuilder,
    ).buildSliver(context);
  }
}
