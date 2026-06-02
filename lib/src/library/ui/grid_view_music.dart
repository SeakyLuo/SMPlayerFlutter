import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../app/smplayer_vector_icons.dart';
import '../../i18n/app_i18n.dart';
import '../../playback/playlist_control_item.dart';
import '../../playback/playing_wave.dart';
import '../data/library_models.dart';
import 'artwork_floating_action_button.dart';
import 'local_folder_model.dart';
import 'local_view_shared.dart';
import 'hover_region.dart';
import 'local_page_model.dart';
import 'local_page_quick_jump.dart';
import 'quick_jump_rail.dart';
import 'song_artwork.dart';

class LocalGridViewMusic extends StatelessWidget {
  const LocalGridViewMusic({
    super.key,
    required this.currentSongs,
    required this.selectedSongIds,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.multiSelect,
    required this.isCompactLayout,
    required this.showSongQuickJump,
    required this.reserveSongQuickJumpSpace,
    required this.songQuickJumpBasisName,
    required this.songQuickJumpMap,
    required this.sortMode,
    required this.currentSortMode,
    required this.queueSongIds,
    required this.folderQueueSongIds,
    required this.i18n,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onToggleSongSelection,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onAddSong,
    required this.onOpenSongMenu,
    required this.onJumpToSongKey,
    this.scrollController,
  });

  final List<LibrarySong> currentSongs;
  final Set<int> selectedSongIds;
  final int? selectedTrackId;
  final bool isPlaying;
  final bool multiSelect;
  final bool isCompactLayout;
  final bool showSongQuickJump;
  final bool reserveSongQuickJumpSpace;
  final String songQuickJumpBasisName;
  final Map<String, int> songQuickJumpMap;
  final LocalSortMode sortMode;
  final LocalSortMode currentSortMode;
  final List<int> queueSongIds;
  final List<int> folderQueueSongIds;
  final SmPlayerI18n i18n;
  final void Function(int trackId, List<int> queueSongIds) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onToggleSongSelection;
  final ValueChanged<int> onPlayNext;
  final void Function(int songId, bool favorite) onToggleFavorite;
  final void Function(LibrarySong song, Offset position) onAddSong;
  final void Function(LibrarySong song, Offset position) onOpenSongMenu;
  final ValueChanged<String> onJumpToSongKey;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final visibleSongIds = currentSongs.map((song) => song.id).toSet();
    final effectiveSelectedSongIds =
        selectedSongIds.where(visibleSongIds.contains).toList();
    final songGrid =
        isCompactLayout
            ? LocalCompactListPanel(
              child: Column(
                children: [
                  for (var index = 0; index < currentSongs.length; index += 1)
                    LocalCompactPanelRow(
                      key: ValueKey(
                        'LocalCompactSongRow.${currentSongs[index].id}',
                      ),
                      last: index == currentSongs.length - 1,
                      reserveSeparatorSpace: true,
                      child: DraggableLocalSong(
                        key: GlobalObjectKey(currentSongs[index]),
                        payload: _songDragPayload(
                          currentSongs[index],
                          effectiveSelectedSongIds,
                        ),
                        feedbackWidth: 420,
                        child: CompactLocalSongRow(
                          song: currentSongs[index],
                          selected: selectedSongIds.contains(
                            currentSongs[index].id,
                          ),
                          current: currentSongs[index].id == selectedTrackId,
                          playing:
                              currentSongs[index].id == selectedTrackId &&
                              isPlaying,
                          selectionMode: multiSelect,
                          i18n: i18n,
                          onPlay:
                              () => onPlayTrack(
                                currentSongs[index].id,
                                folderQueueSongIds,
                              ),
                          onTogglePlayPause: onTogglePlayPause,
                          onToggleSelection:
                              () =>
                                  onToggleSongSelection(currentSongs[index].id),
                          onPlayNext: () => onPlayNext(currentSongs[index].id),
                          onToggleFavorite:
                              () => onToggleFavorite(
                                currentSongs[index].id,
                                !currentSongs[index].favorite,
                              ),
                          onAddSong:
                              (position) =>
                                  onAddSong(currentSongs[index], position),
                          onOpenMenu:
                              (position) =>
                                  onOpenSongMenu(currentSongs[index], position),
                        ),
                      ),
                    ),
                ],
              ),
            )
            : Wrap(
              spacing: 30,
              runSpacing: 26,
              children: [
                for (final song in currentSongs)
                  DraggableLocalSong(
                    key: GlobalObjectKey(song),
                    payload: _songDragPayload(song, effectiveSelectedSongIds),
                    feedbackWidth: 180,
                    child: LocalSongGridItem(
                      song: song,
                      selected: selectedSongIds.contains(song.id),
                      current: song.id == selectedTrackId,
                      playing: song.id == selectedTrackId && isPlaying,
                      multiSelect: multiSelect,
                      detailLabel: getLocalSongDetailLabel(
                        song,
                        sortMode,
                        currentSortMode,
                        i18n,
                      ),
                      i18n: i18n,
                      onPlay: () => onPlayTrack(song.id, folderQueueSongIds),
                      onTogglePlayPause: onTogglePlayPause,
                      onToggleSelection: () => onToggleSongSelection(song.id),
                      onAddSong: (position) => onAddSong(song, position),
                      onOpenMenu: (position) => onOpenSongMenu(song, position),
                    ),
                  ),
              ],
            );

    if (!reserveSongQuickJumpSpace && !showSongQuickJump) {
      return songGrid;
    }

    final railWidth = isCompactLayout ? 22.0 : 30.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSongQuickJump)
          QuickJumpRail(
            scrollController: scrollController,
            height: isCompactLayout ? 380 : 420,
            keyPrefix: 'LocalSongQuickJump',
            child: LocalSongQuickJump(
              basisName: songQuickJumpBasisName,
              enabledKeys: songQuickJumpMap,
              i18n: i18n,
              visible: showSongQuickJump,
              onJump: onJumpToSongKey,
              compact: isCompactLayout,
            ),
          )
        else
          SizedBox(
            key: const ValueKey('LocalSongQuickJump.ReservedRail'),
            width: railWidth,
          ),
        SizedBox(width: isCompactLayout ? 10 : 12),
        Expanded(child: songGrid),
      ],
    );
  }

  LocalItemsDragPayload _songDragPayload(
    LibrarySong song,
    List<int> effectiveSelectedSongIds,
  ) {
    final songIds =
        selectedSongIds.contains(song.id) && effectiveSelectedSongIds.isNotEmpty
            ? effectiveSelectedSongIds
            : [song.id];
    return LocalItemsDragPayload(songIds: songIds, folderPaths: const []);
  }
}

class DraggableLocalSong extends StatelessWidget {
  const DraggableLocalSong({
    super.key,
    required this.payload,
    required this.feedbackWidth,
    required this.child,
  });

  final LocalItemsDragPayload payload;
  final double feedbackWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Draggable<LocalItemsDragPayload>(
      data: payload,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.85,
          child: SizedBox(width: feedbackWidth, child: child),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.55, child: child),
      child: child,
    );
  }
}

class LocalSongGridItem extends StatefulWidget {
  const LocalSongGridItem({
    super.key,
    required this.song,
    required this.selected,
    required this.current,
    required this.playing,
    required this.multiSelect,
    required this.detailLabel,
    required this.i18n,
    required this.onPlay,
    required this.onTogglePlayPause,
    required this.onToggleSelection,
    required this.onAddSong,
    required this.onOpenMenu,
  });

  final LibrarySong song;
  final bool selected;
  final bool current;
  final bool playing;
  final bool multiSelect;
  final String? detailLabel;
  final SmPlayerI18n i18n;
  final VoidCallback onPlay;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleSelection;
  final ValueChanged<Offset> onAddSong;
  final ValueChanged<Offset> onOpenMenu;

  @override
  State<LocalSongGridItem> createState() => LocalSongGridItemState();
}

class LocalSongGridItemState extends State<LocalSongGridItem> {
  @override
  Widget build(BuildContext context) {
    final colors = LocalGridSongCardColors.of(context);
    final localColors = LocalPageColors.of(context);
    final subtitle =
        widget.detailLabel ?? getLocalDisplayArtists(widget.song, widget.i18n);
    return LocalHoverRegion(
      builder: (context, hovered, focused) {
        final actionsVisible = !widget.multiSelect && (hovered || focused);
        final surfaceActive =
            hovered || focused || (widget.multiSelect && widget.selected);
        return GestureDetector(
          onSecondaryTapDown:
              (details) => widget.onOpenMenu(details.globalPosition),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            onTap:
                widget.multiSelect ? widget.onToggleSelection : widget.onPlay,
            child: Container(
              width: 180,
              constraints: const BoxConstraints(minHeight: 232),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    surfaceActive
                        ? colors.hoverSurface
                        : localColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                boxShadow:
                    surfaceActive
                        ? [
                          BoxShadow(
                            color: colors.shadow,
                            offset: const Offset(0, 12),
                            blurRadius: 26,
                          ),
                        ]
                        : const [],
              ),
              foregroundDecoration:
                  surfaceActive
                      ? BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.inset),
                      )
                      : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AnimatedContainer(
                        key: ValueKey('LocalGridSong.Cover.${widget.song.id}'),
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: localColors.artworkShadow,
                              offset: const Offset(0, 12),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox.square(
                            dimension: 160,
                            child: SongArtwork(
                              artworkPath: widget.song.thumbnailPath,
                            ),
                          ),
                        ),
                      ),
                      if (widget.multiSelect)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: LocalCheckMark(selected: widget.selected),
                        ),
                      if (widget.current && !hovered && !focused)
                        Positioned.fill(
                          child: SmPlayerPlayingWaveGlass(
                            playing: widget.playing,
                            dimension: 48,
                            keyPrefix:
                                'LocalGridSong.Playing.${widget.song.id}',
                          ),
                        ),
                      if (actionsVisible)
                        Positioned.fill(
                          child: Center(
                            child: Row(
                              key: ValueKey(
                                'LocalGridSong.Actions.${widget.song.id}',
                              ),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RoundSongAction(
                                  tooltip:
                                      widget.current && widget.playing
                                          ? widget.i18n.t('context.pause')
                                          : widget.i18n.t('context.play'),
                                  icon:
                                      widget.current && widget.playing
                                          ? const SmPlayerPauseIcon(
                                            size: 20,
                                            color: Colors.white,
                                          )
                                          : const SmPlayerPlayIcon(
                                            size: 20,
                                            color: Colors.white,
                                          ),
                                  onPressed:
                                      widget.current
                                          ? widget.onTogglePlayPause
                                          : widget.onPlay,
                                ),
                                const SizedBox(width: 10),
                                RoundSongAction(
                                  tooltip: widget.i18n.t(
                                    'context.addToPlaylist',
                                  ),
                                  icon: const Icon(FluentIcons.add_20_regular),
                                  onPressedAt: widget.onAddSong,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                widget.current
                                    ? localColors.accentStrong
                                    : localColors.textStrong,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          widget.current
                              ? localColors.accentStrong
                              : localColors.textMuted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CompactLocalSongRow extends StatelessWidget {
  const CompactLocalSongRow({
    super.key,
    required this.song,
    required this.selected,
    required this.current,
    required this.playing,
    required this.selectionMode,
    required this.i18n,
    required this.onPlay,
    required this.onTogglePlayPause,
    required this.onToggleSelection,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onAddSong,
    required this.onOpenMenu,
  });

  final LibrarySong song;
  final bool selected;
  final bool current;
  final bool playing;
  final bool selectionMode;
  final SmPlayerI18n i18n;
  final VoidCallback onPlay;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleSelection;
  final VoidCallback onPlayNext;
  final VoidCallback onToggleFavorite;
  final ValueChanged<Offset> onAddSong;
  final ValueChanged<Offset> onOpenMenu;

  @override
  Widget build(BuildContext context) {
    return PlaylistControlItem(
      song: song,
      current: current,
      playing: playing,
      selected: selected,
      selectionMode: selectionMode,
      showAlbum: true,
      variant: PlaylistControlItemVariant.compact,
      collapseCompactPrimaryActions: true,
      playNextLabel: i18n.t('context.playNext'),
      addToPlaylistLabel: i18n.t('context.addToPlaylist'),
      favoriteLabel:
          song.favorite
              ? i18n.t('context.removeFavorite')
              : i18n.t('context.addFavorite'),
      moreLabel: i18n.t('player.more'),
      onPlayTrack: onPlay,
      onTogglePlayPause: onTogglePlayPause,
      onToggleSelection: onToggleSelection,
      onPlayNextClick: onPlayNext,
      onToggleFavoriteClick: onToggleFavorite,
      onAddToPlaylistClick: (buttonContext) {
        invokeAtButtonBottom(buttonContext, onAddSong);
      },
      onOpenContextMenu: onOpenMenu,
    );
  }
}

class RoundSongAction extends StatelessWidget {
  const RoundSongAction({
    super.key,
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.onPressedAt,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final ValueChanged<Offset>? onPressedAt;

  @override
  Widget build(BuildContext context) {
    return ArtworkFloatingActionButton(
      tooltip: tooltip,
      icon: icon,
      onPressed:
          onPressedAt == null
              ? onPressed
              : () => invokeAtButtonBottom(context, onPressedAt!),
    );
  }
}

class LocalGridSongCardColors {
  const LocalGridSongCardColors({
    required this.hoverSurface,
    required this.shadow,
    required this.inset,
  });

  final Color hoverSurface;
  final Color shadow;
  final Color inset;

  static LocalGridSongCardColors of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? const LocalGridSongCardColors(
          hoverSurface: Color(0x240078d7),
          shadow: Color(0x3d000000),
          inset: Color(0x380078d7),
        )
        : const LocalGridSongCardColors(
          hoverSurface: Color(0x140078d7),
          shadow: Color(0x000078d7),
          inset: Color(0x260078d7),
        );
  }
}

void invokeAtButtonBottom(BuildContext context, ValueChanged<Offset> action) {
  final box = context.findRenderObject() as RenderBox;
  action(box.localToGlobal(Offset(0, box.size.height + 6)));
}
