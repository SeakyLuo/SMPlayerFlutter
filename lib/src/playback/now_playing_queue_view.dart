import 'package:flutter/material.dart';

import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';
import 'package:smplayer_flutter/src/playback/playlist_control.dart';

class NowPlayingQueueView extends StatelessWidget {
  const NowPlayingQueueView({
    super.key,
    required this.queueSongs,
    required this.visibleEntries,
    required this.searchQuery,
    required this.scrollController,
    required this.selectedQueueIndex,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.selectionMode,
    required this.isSelected,
    required this.onReorderVisible,
    required this.onPlayQueueTrack,
    required this.onTogglePlayPause,
    required this.onToggleQueueSelection,
    required this.onToggleFavorite,
    required this.onOpenAddToPlaylist,
    required this.onRemoveQueueIndex,
    required this.onOpenContextMenu,
  });

  final List<LibrarySong> queueSongs;
  final List<(int, LibrarySong)> visibleEntries;
  final String searchQuery;
  final ScrollController scrollController;
  final int? selectedQueueIndex;
  final int? selectedTrackId;
  final bool isPlaying;
  final bool selectionMode;
  final bool Function(int queueIndex) isSelected;
  final void Function(int oldVisibleIndex, int newVisibleIndex)
  onReorderVisible;
  final void Function(LibrarySong song, int queueIndex) onPlayQueueTrack;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onToggleQueueSelection;
  final ValueChanged<LibrarySong> onToggleFavorite;
  final void Function(BuildContext buttonContext, LibrarySong song)
  onOpenAddToPlaylist;
  final void Function(int queueIndex, LibrarySong song) onRemoveQueueIndex;
  final void Function(Offset position, LibrarySong song, int queueIndex)
  onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    if (queueSongs.isEmpty) {
      return const SizedBox.shrink();
    }
    if (visibleEntries.isEmpty) {
      return NowPlayingEmptyState(
        title: i18n.t('nowPlaying.noQueueMatch', {'query': searchQuery}),
        message: i18n.t('nowPlaying.queueSearchHelp'),
      );
    }

    final compactQueueLayout = MediaQuery.sizeOf(context).width <= 720;
    final entries = [
      for (final entry in visibleEntries)
        _entryFor(
          queueIndex: entry.$1,
          song: entry.$2,
          selectedQueueIndex: selectedQueueIndex,
          i18n: i18n,
          compactQueueLayout: compactQueueLayout,
        ),
    ];
    return Scrollbar(
      controller: scrollController,
      child: PlaylistControl.reorderable(
        entries: entries,
        scrollController: scrollController,
        padding: EdgeInsets.fromLTRB(
          0,
          0,
          0,
          selectionMode
              ? multiSelectCommandBarScrollSpacer
              : compactQueueLayout
              ? 2
              : 18,
        ),
        onReorder: onReorderVisible,
      ),
    );
  }

  PlaylistControlEntry _entryFor({
    required int queueIndex,
    required LibrarySong song,
    required int? selectedQueueIndex,
    required SmPlayerI18n i18n,
    required bool compactQueueLayout,
  }) {
    final current =
        selectedQueueIndex == null
            ? song.id == selectedTrackId
            : queueIndex == selectedQueueIndex;
    return PlaylistControlEntry(
      key: ValueKey('now-playing-${song.id}-$queueIndex'),
      logicalIndex: queueIndex,
      song: song,
      current: current,
      playing: current && isPlaying,
      selected: isSelected(queueIndex),
      selectionMode: selectionMode,
      variant:
          compactQueueLayout
              ? PlaylistControlItemVariant.compact
              : PlaylistControlItemVariant.standard,
      collapseCompactPrimaryActions: compactQueueLayout,
      compactTrailingPadding: compactQueueLayout ? 20 : null,
      favoriteLabel: i18n.t('common.favorite'),
      addToPlaylistLabel: i18n.t('context.addToPlaylist'),
      removeLabel: i18n.t('nowPlaying.remove'),
      moreLabel: i18n.t('player.more'),
      onPlayTrack: () {
        onPlayQueueTrack(song, queueIndex);
      },
      onTogglePlayPause: onTogglePlayPause,
      onToggleSelection: () {
        onToggleQueueSelection(queueIndex);
      },
      onToggleFavoriteClick: () {
        onToggleFavorite(song);
      },
      onAddToPlaylistClick: (buttonContext) {
        onOpenAddToPlaylist(buttonContext, song);
      },
      onRemoveFromListClick: () {
        onRemoveQueueIndex(queueIndex, song);
      },
      onOpenContextMenu: (position) {
        onOpenContextMenu(position, song, queueIndex);
      },
    );
  }
}

class NowPlayingEmptyState extends StatelessWidget {
  const NowPlayingEmptyState({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: NowPlayingColors.emptyStateSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NowPlayingColors.emptyStateBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: NowPlayingColors.textStrong,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: NowPlayingColors.textMuted,
                    fontSize: 14,
                    height: 1.65,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NowPlayingColors {
  const NowPlayingColors._();

  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const emptyStateSurface = Color(0x94ffffff);
  static const emptyStateBorder = Color(0x94ffffff);
}
