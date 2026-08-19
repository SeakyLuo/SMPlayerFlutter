import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page_model.dart'
    as artists_model;
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart'
    as song_display;
import 'package:smplayer_flutter/src/playback/immersive_mode_constants.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_model.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_theme.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';

const _nowPlayingQueueCompactTrailingPadding = 10.0;
const _nowPlayingQueueCompactDurationWidth = 50.0;

List<int> _moveQueueSongIds(
  List<int> queueSongIds,
  int draggedIndex,
  int targetIndex,
  bool insertAfter,
) {
  if (draggedIndex == targetIndex) {
    return queueSongIds;
  }
  final nextSongIds = queueSongIds.toList();
  final songId = nextSongIds.removeAt(draggedIndex);
  final targetInsertIndex = targetIndex + (insertAfter ? 1 : 0);
  final adjustedTargetIndex =
      draggedIndex < targetInsertIndex
          ? targetInsertIndex - 1
          : targetInsertIndex;
  nextSongIds.insert(adjustedTargetIndex, songId);
  return nextSongIds;
}

String _primaryArtist(LibrarySong song, SmPlayerI18n i18n) {
  final artists = artists_model.getSongArtists(song);
  return artists.isEmpty ? i18n.t('common.artistUnknown') : artists.first;
}

String _displayAlbum(LibrarySong song, SmPlayerI18n i18n) {
  return song_display.displayAlbum(song, i18n);
}

class _ImmersiveModeQueuePanelStyle {
  const _ImmersiveModeQueuePanelStyle({
    required this.color,
    required this.borderColor,
    required this.shadowColor,
    required this.isNight,
  });

  final Color color;
  final Color borderColor;
  final Color shadowColor;
  final bool isNight;

  static const day = _ImmersiveModeQueuePanelStyle(
    color: Color(0xd1ffffff),
    borderColor: Color(0xc2ccd5e0),
    shadowColor: Color(0x2e445870),
    isNight: false,
  );

  static const nightMode = _ImmersiveModeQueuePanelStyle(
    color: Color(0xdb12100e),
    borderColor: Color(0x2effffff),
    shadowColor: Color(0x61000000),
    isNight: true,
  );

  static _ImmersiveModeQueuePanelStyle forNight(bool night) {
    return switch (night) {
      true => _ImmersiveModeQueuePanelStyle.nightMode,
      false => day,
    };
  }

  Gradient gradientFor(Color coverColor) {
    return switch (isNight) {
      true => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x70775b20), Color(0x2e14120e), Colors.transparent],
        stops: [0, 0.38, 0.64],
      ),
      false => RadialGradient(
        center: const Alignment(-0.6, -0.56),
        radius: 0.84,
        colors: [coverColor.withValues(alpha: 0.24), Colors.transparent],
        stops: const [0, 1],
      ),
    };
  }
}

class ImmersiveModeQueuePopoverHost extends StatefulWidget {
  const ImmersiveModeQueuePopoverHost({
    super.key,
    required this.open,
    required this.fullScreen,
    required this.child,
  });

  final bool open;
  final bool fullScreen;
  final Widget child;

  @override
  State<ImmersiveModeQueuePopoverHost> createState() =>
      ImmersiveModeQueuePopoverHostState();
}

class ImmersiveModeQueuePopoverHostState
    extends State<ImmersiveModeQueuePopoverHost> {
  var _mountedForAnimation = false;
  var _visibleForAnimation = false;

  @override
  void initState() {
    super.initState();
    _mountedForAnimation = widget.open;
    _visibleForAnimation = widget.open;
  }

  @override
  void didUpdateWidget(ImmersiveModeQueuePopoverHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !_mountedForAnimation) {
      setState(() {
        _mountedForAnimation = true;
        _visibleForAnimation = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.open) {
          setState(() {
            _visibleForAnimation = true;
          });
        }
      });
      return;
    }
    if (widget.open != oldWidget.open) {
      setState(() {
        _visibleForAnimation = widget.open;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_mountedForAnimation) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      ignoring: !widget.open,
      child: ExcludeSemantics(
        excluding: !widget.open,
        child: AnimatedOpacity(
          key: const ValueKey('ImmersiveMode.QueuePopoverOpacity'),
          duration: const Duration(milliseconds: 180),
          opacity: _visibleForAnimation ? 1 : 0,
          child: AnimatedSlide(
            key: const ValueKey('ImmersiveMode.QueuePopoverSlide'),
            duration: const Duration(milliseconds: 260),
            curve: const Cubic(0.22, 1, 0.36, 1),
            offset:
                _visibleForAnimation
                    ? Offset.zero
                    : widget.fullScreen
                    ? const Offset(0, 1)
                    : const Offset(1.08, 0),
            onEnd: () {
              if (!widget.open && mounted) {
                setState(() {
                  _mountedForAnimation = false;
                });
              }
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class ImmersiveModePlaylist extends StatefulWidget {
  const ImmersiveModePlaylist({
    super.key,
    required this.open,
    required this.i18n,
    required this.songs,
    required this.songIds,
    required this.currentTrackId,
    required this.selectedQueueIndex,
    required this.isPlaying,
    required this.loading,
    required this.selection,
    required this.scrollController,
    required this.playlists,
    required this.playlistSnapshots,
    required this.folders,
    required this.onClose,
    required this.onReorder,
    required this.onReplaceQueue,
    required this.currentQueueSongIds,
    required this.onPlaySongs,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onRemove,
    required this.onSelectionChanged,
    required this.onAddToPlaylist,
    required this.onToggleFavorite,
    required this.onCreatePlaylist,
    required this.onClearNowPlaying,
    required this.onQuickPlay,
    required this.onRandomPlay,
    required this.onAddToNowPlaying,
    required this.onGetPreferenceLevel,
    required this.onUndoPreference,
    required this.onSetPreference,
    required this.onDeleteSongFromDisk,
    required this.onMoveSongToFolder,
    required this.onOpenSongDialog,
    required this.onRevealSong,
    required this.fullScreen,
    required this.coverColor,
  });

  final bool open;
  final SmPlayerI18n i18n;
  final List<LibrarySong> songs;
  final List<int> songIds;
  final int? currentTrackId;
  final int? selectedQueueIndex;
  final bool isPlaying;
  final bool loading;
  final PageSelectionController<int> selection;
  final ScrollController scrollController;
  final List<MultiSelectCommandBarPlaylist> playlists;
  final List<LibraryPlaylist> playlistSnapshots;
  final List<LibraryFolder> folders;
  final VoidCallback onClose;
  final void Function(List<int>, int, int) onReorder;
  final ValueChanged<List<int>> onReplaceQueue;
  final List<int> Function() currentQueueSongIds;
  final ValueChanged<List<int>> onPlaySongs;
  final void Function(LibrarySong, List<int>, int) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final void Function(List<int>, int) onPlayNext;
  final void Function(List<int>, int) onRemove;
  final VoidCallback onSelectionChanged;
  final Future<void> Function(int, List<int>) onAddToPlaylist;
  final Future<void> Function(List<int>, bool) onToggleFavorite;
  final Future<void> Function(String, List<int>) onCreatePlaylist;
  final VoidCallback onClearNowPlaying;
  final VoidCallback onQuickPlay;
  final VoidCallback onRandomPlay;
  final ValueChanged<LibrarySong> onAddToNowPlaying;
  final Future<String?> Function(int) onGetPreferenceLevel;
  final Future<void> Function(int) onUndoPreference;
  final Future<void> Function(int, String, String) onSetPreference;
  final Future<void> Function(LibrarySong) onDeleteSongFromDisk;
  final Future<void> Function(LibrarySong, String) onMoveSongToFolder;
  final ValueChanged<SongDialogMode> onOpenSongDialog;
  final ValueChanged<String> onRevealSong;
  final bool fullScreen;
  final Color coverColor;

  @override
  State<ImmersiveModePlaylist> createState() => ImmersiveModePlaylistState();
}

class ImmersiveModePlaylistState extends State<ImmersiveModePlaylist> {
  ({int queueIndex, PlaylistControlDropPosition position})? _dropIndicator;
  int? _draggedQueueIndex;

  SmPlayerI18n get i18n => widget.i18n;
  List<LibrarySong> get songs => widget.songs;
  List<int> get songIds => widget.songIds;
  int? get currentTrackId => widget.currentTrackId;
  int? get selectedQueueIndex => widget.selectedQueueIndex;
  bool get isPlaying => widget.isPlaying;
  bool get loading => widget.loading;
  PageSelectionController<int> get selection => widget.selection;
  ScrollController get scrollController => widget.scrollController;
  List<MultiSelectCommandBarPlaylist> get playlists => widget.playlists;
  List<LibraryPlaylist> get playlistSnapshots => widget.playlistSnapshots;
  List<LibraryFolder> get folders => widget.folders;
  VoidCallback get onClose => widget.onClose;
  void Function(List<int>, int, int) get onReorder => widget.onReorder;
  ValueChanged<List<int>> get onReplaceQueue => widget.onReplaceQueue;
  List<int> Function() get currentQueueSongIds => widget.currentQueueSongIds;
  ValueChanged<List<int>> get onPlaySongs => widget.onPlaySongs;
  void Function(LibrarySong, List<int>, int) get onPlayTrack =>
      widget.onPlayTrack;
  VoidCallback get onTogglePlayPause => widget.onTogglePlayPause;
  void Function(List<int>, int) get onPlayNext => widget.onPlayNext;
  void Function(List<int>, int) get onRemove => widget.onRemove;
  VoidCallback get onSelectionChanged => widget.onSelectionChanged;
  Future<void> Function(int, List<int>) get onAddToPlaylist =>
      widget.onAddToPlaylist;
  Future<void> Function(List<int>, bool) get onToggleFavorite =>
      widget.onToggleFavorite;
  Future<void> Function(String, List<int>) get onCreatePlaylist =>
      widget.onCreatePlaylist;
  VoidCallback get onClearNowPlaying => widget.onClearNowPlaying;
  VoidCallback get onQuickPlay => widget.onQuickPlay;
  VoidCallback get onRandomPlay => widget.onRandomPlay;
  ValueChanged<LibrarySong> get onAddToNowPlaying => widget.onAddToNowPlaying;
  Future<String?> Function(int) get onGetPreferenceLevel =>
      widget.onGetPreferenceLevel;
  Future<void> Function(int) get onUndoPreference => widget.onUndoPreference;
  Future<void> Function(int, String, String) get onSetPreference =>
      widget.onSetPreference;
  Future<void> Function(LibrarySong) get onDeleteSongFromDisk =>
      widget.onDeleteSongFromDisk;
  Future<void> Function(LibrarySong, String) get onMoveSongToFolder =>
      widget.onMoveSongToFolder;
  ValueChanged<SongDialogMode> get onOpenSongDialog => widget.onOpenSongDialog;
  ValueChanged<String> get onRevealSong => widget.onRevealSong;
  bool get fullScreen => widget.fullScreen;
  Color get coverColor => widget.coverColor;

  @override
  void initState() {
    super.initState();
    _pruneSelection();
    if (widget.open) {
      _scrollCurrentRowIntoView();
    }
  }

  @override
  void didUpdateWidget(ImmersiveModePlaylist oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songs.length != widget.songs.length) {
      _pruneSelection();
    }
    if (widget.open && !oldWidget.open) {
      _scrollCurrentRowIntoView();
    }
  }

  int? _currentQueueIndex() {
    final selectedQueueIndex = this.selectedQueueIndex;
    if (selectedQueueIndex != null &&
        selectedQueueIndex >= 0 &&
        selectedQueueIndex < songs.length) {
      return selectedQueueIndex;
    }
    final trackId = currentTrackId;
    final trackIndex = songs.indexWhere((song) => song.id == trackId);
    return trackIndex == -1 ? null : trackIndex;
  }

  void _scrollCurrentRowIntoView([int attempt = 0]) {
    if (!widget.open) {
      return;
    }
    final currentIndex = _currentQueueIndex();
    if (currentIndex == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!scrollController.hasClients) {
        if (attempt < 3) {
          _scrollCurrentRowIntoView(attempt + 1);
        }
        return;
      }
      final position = scrollController.position;
      if (position.maxScrollExtent == position.minScrollExtent &&
          songs.length * immersiveModeQueueRowHeight >
              position.viewportDimension) {
        if (attempt < 3) {
          _scrollCurrentRowIntoView(attempt + 1);
        }
        return;
      }
      final topPadding = _listPadding().top;
      final target =
          topPadding +
          currentIndex * immersiveModeQueueRowHeight +
          immersiveModeQueueRowHeight / 2 -
          position.viewportDimension / 2;
      scrollController.jumpTo(
        target
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
    });
  }

  void _pruneSelection() {
    final nextSelected = {
      for (final index in widget.selection.selectedItems)
        if (index >= 0 && index < widget.songs.length) index,
    };
    if (nextSelected.length == widget.selection.selectedItems.length) {
      return;
    }
    widget.selection.replaceSelection(nextSelected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onSelectionChanged();
      }
    });
  }

  void _moveQueueSongToDropTarget(
    List<int> queueSongIds,
    int draggedIndex,
    int targetIndex,
    PlaylistControlDropPosition position,
  ) {
    onReplaceQueue(
      _moveQueueSongIds(
        queueSongIds,
        draggedIndex,
        targetIndex,
        position == PlaylistControlDropPosition.after,
      ),
    );
  }

  PlaylistControlDropPosition _dropPositionFor(
    BuildContext context,
    Offset globalPosition,
  ) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(globalPosition);
    return local.dy > box.size.height / 2
        ? PlaylistControlDropPosition.after
        : PlaylistControlDropPosition.before;
  }

  void _clearQueueDrop() {
    setState(() {
      _dropIndicator = null;
      _draggedQueueIndex = null;
    });
  }

  Future<void> _saveQueueAsPlaylist(BuildContext context) async {
    final name = await requestPlaylistName(
      context: context,
      i18n: i18n,
      playlists: playlistSnapshots,
      defaultName: getDefaultNewPlaylistName(i18n, playlistSnapshots),
    );
    if (name != null) {
      await onCreatePlaylist(name, songIds);
    }
  }

  Future<void> _confirmClearNowPlaying(BuildContext context) async {
    final confirmed = await showPopupConfirmDialog(
      context: context,
      title: i18n.t('nowPlaying.clearNowPlaying'),
      message: i18n.t('nowPlaying.clearNowPlayingConfirm'),
      confirmLabel: i18n.t('common.clear'),
      i18n: i18n,
    );
    if (confirmed) {
      onClearNowPlaying();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ImmersiveModeThemeColors.of(context);
    final night = colors.artworkShadowOpacity > 0.3;
    final panelStyle = _ImmersiveModeQueuePanelStyle.forNight(night);
    final panelGradient = panelStyle.gradientFor(coverColor);
    final decoration = BoxDecoration(
      color: panelStyle.color,
      gradient: panelGradient,
      borderRadius: BorderRadius.circular(fullScreen ? 0 : 18),
      border: Border.all(color: panelStyle.borderColor),
      boxShadow: [
        BoxShadow(
          color: panelStyle.shadowColor,
          blurRadius: 76,
          offset: const Offset(0, 28),
        ),
      ],
    );
    final backgroundDecoration = BoxDecoration(
      color: panelStyle.color,
      gradient: panelGradient,
    );
    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(fullScreen ? 0 : 18),
        child: GlassContainer(
          key: const ValueKey('ImmersiveMode.QueuePanelGlass'),
          useOwnLayer: true,
          quality: GlassQuality.minimal,
          shape: LiquidRoundedRectangle(borderRadius: fullScreen ? 0 : 18),
          settings: LiquidGlassSettings(
            blur: 46,
            thickness: 20,
            refractiveIndex: 1.06,
            saturation: 1.65,
            chromaticAberration: 0,
            lightIntensity: 0.1,
            ambientStrength: 0.08,
            glowIntensity: 0.04,
            glassColor: panelStyle.color,
            standardOpacityMultiplier: 0.35,
          ),
          clipBehavior: Clip.hardEdge,
          allowElevation: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  key: const ValueKey('ImmersiveMode.QueuePanelBackground'),
                  decoration: backgroundDecoration,
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding:
                        fullScreen
                            ? const EdgeInsets.fromLTRB(20, 26, 20, 14)
                            : const EdgeInsets.fromLTRB(30, 26, 20, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                i18n.t('common.nowPlaying'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.text,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                i18n.t('playlists.songCount', {
                                  'count': songs.length,
                                }),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      night
                                          ? const Color(0xb8ffffff)
                                          : colors.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (songs.isNotEmpty) ...[
                          ImmersiveModeQueueHeaderActionButton(
                            key: const ValueKey(
                              'ImmersiveMode.QueueSavePlaylistButton',
                            ),
                            tooltip: i18n.t('nowPlaying.savePlaylist'),
                            icon: FluentIcons.add_20_regular,
                            onPressed: () {
                              unawaited(_saveQueueAsPlaylist(context));
                            },
                          ),
                          const SizedBox(width: 8),
                          ImmersiveModeQueueHeaderActionButton(
                            key: const ValueKey(
                              'ImmersiveMode.QueueClearNowPlayingButton',
                            ),
                            tooltip: i18n.t('nowPlaying.clearNowPlaying'),
                            icon: FluentIcons.broom_20_regular,
                            onPressed: () {
                              unawaited(_confirmClearNowPlaying(context));
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                        ImmersiveModeQueueCloseButton(
                          tooltip: i18n.t('common.close'),
                          onPressed: onClose,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        songs.isEmpty
                            ? ImmersiveModeQueueEmptyState(
                              i18n: i18n,
                              loading: loading,
                              onQuickPlay: onQuickPlay,
                              onRandomPlay: onRandomPlay,
                            )
                            : _buildQueueList(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueueList(BuildContext context) {
    final list = ListView.builder(
      key: const ValueKey('ImmersiveMode.QueueList'),
      controller: scrollController,
      padding: _listPadding(),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final current =
            selectedQueueIndex == null
                ? song.id == currentTrackId
                : index == selectedQueueIndex;
        final dropPosition =
            _dropIndicator?.queueIndex == index
                ? _dropIndicator?.position
                : null;
        final item = PlaylistControlItem(
          key: ValueKey('now-playing-full-row-${song.id}-$index'),
          song: song,
          current: current,
          playing: current && isPlaying,
          selected: selection.isSelected(index),
          selectionMode: selection.multiSelect,
          dropPosition: dropPosition,
          variant: PlaylistControlItemVariant.compact,
          collapseCompactPrimaryActions: true,
          compactDurationWidth: _nowPlayingQueueCompactDurationWidth,
          compactTrailingPadding: _nowPlayingQueueCompactTrailingPadding,
          playNextLabel: i18n.t('context.playNext'),
          removeLabel: i18n.t('nowPlaying.remove'),
          onPlayTrack: () {
            onPlayTrack(song, songIds, index);
          },
          onTogglePlayPause: onTogglePlayPause,
          onToggleSelection: () {
            selection.toggle(index);
            onSelectionChanged();
          },
          onRemoveFromListClick: () {
            onRemove(songIds, index);
            showUndoableNotification(
              context: context,
              i18n: i18n,
              message: i18n.t('notification.removedFrom', {
                'title': song.title,
                'target': i18n.t('common.nowPlaying'),
              }),
              onUndo:
                  () => onReplaceQueue(
                    insertImmersiveModeQueueSongs(
                      currentQueueSongIds(),
                      index,
                      [song.id],
                    ),
                  ),
            );
          },
          onToggleFavoriteClick: () {
            onToggleFavorite([song.id], !song.favorite);
          },
          onAddToPlaylistClick: (buttonContext) {
            _showAddToPlaylistMenu(buttonContext, song);
          },
          onSeeAlbum: () {
            context.go(
              '/albums?album=${Uri.encodeComponent(_displayAlbum(song, i18n))}',
            );
            onClose();
          },
          onSeeArtist: (artist) {
            context.go('/artists?artist=${Uri.encodeComponent(artist)}');
            onClose();
          },
          onOpenContextMenu: (position) {
            _showQueueContextMenu(context, position, song, index);
          },
        );
        final rowItem =
            fullScreen
                ? Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: item,
                )
                : item;
        return DragTarget<int>(
          key: ValueKey('now-playing-full-target-${song.id}-$index'),
          onMove: (details) {
            final position = _dropPositionFor(context, details.offset);
            setState(() {
              _dropIndicator = (queueIndex: index, position: position);
            });
          },
          onLeave: (_) {
            if (_dropIndicator?.queueIndex == index) {
              setState(() {
                _dropIndicator = null;
              });
            }
          },
          onAcceptWithDetails: (details) {
            final draggedIndex = _draggedQueueIndex ?? details.data;
            final position =
                _dropIndicator?.queueIndex == index
                    ? _dropIndicator!.position
                    : _dropPositionFor(context, details.offset);
            _clearQueueDrop();
            _moveQueueSongToDropTarget(songIds, draggedIndex, index, position);
          },
          builder: (context, _, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return Draggable<int>(
                  data: index,
                  axis: Axis.vertical,
                  affinity: Axis.vertical,
                  feedback: SizedBox(
                    width: constraints.maxWidth,
                    child: Material(
                      color: Colors.transparent,
                      child: Opacity(opacity: 0.92, child: rowItem),
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.42, child: rowItem),
                  onDragStarted: () {
                    setState(() {
                      _draggedQueueIndex = index;
                      _dropIndicator = null;
                    });
                  },
                  onDraggableCanceled: (_, _) {
                    _clearQueueDrop();
                  },
                  onDragEnd: (_) {
                    _clearQueueDrop();
                  },
                  child: rowItem,
                );
              },
            );
          },
        );
      },
    );
    return Scrollbar(
      key: const ValueKey('ImmersiveMode.QueueScrollbar'),
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: list,
      ),
    );
  }

  EdgeInsets _listPadding() {
    if (selection.multiSelect) {
      return EdgeInsets.fromLTRB(
        fullScreen ? 10 : 16,
        fullScreen ? 0 : 4,
        fullScreen ? 0 : 8,
        multiSelectCommandBarScrollSpacer,
      );
    }
    return fullScreen
        ? const EdgeInsets.fromLTRB(10, 0, 0, 2)
        : const EdgeInsets.fromLTRB(16, 4, 8, 22);
  }

  Future<void> _showAddToPlaylistMenu(
    BuildContext buttonContext,
    LibrarySong song,
  ) async {
    final item = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: [song.id],
      playlists: playlists,
      currentPlaylistName: i18n.t('common.nowPlaying'),
      includeFavorites: !song.favorite,
      defaultPlaylistName: _nextPlaylistName(song.title),
      onToggleFavorite: () {
        onToggleFavorite([song.id], true);
        showUndoableNotification(
          context: buttonContext,
          i18n: i18n,
          message: i18n.t('notification.songAddedTo', {
            'title': song.title,
            'target': i18n.t('common.myFavorites'),
          }),
          onUndo: () => onToggleFavorite([song.id], false),
        );
      },
      onCreatePlaylistWithName: (name) {
        onCreatePlaylist(name, [song.id]);
      },
      onAddToPlaylist: (playlistId) {
        onAddToPlaylist(playlistId, [song.id]);
      },
    );
    if (item == null) {
      return;
    }
    await showMenuFlyout(
      buttonContext,
      avoidPlayerBar: false,
      items: item.submenu,
    );
  }

  String _nextPlaylistName(String name) {
    final playlistNames = playlists.map((playlist) => playlist.name).toSet();
    final siblingCount =
        playlists.where((playlist) => playlist.name.startsWith(name)).length;
    for (var index = 1; index <= siblingCount; index += 1) {
      final nextName = '$name ($index)';
      if (!playlistNames.contains(nextName)) {
        return nextName;
      }
    }
    return name;
  }

  Future<void> _showQueueContextMenu(
    BuildContext context,
    Offset position,
    LibrarySong song,
    int queueIndex,
  ) async {
    final currentTrackId = this.currentTrackId;
    final menuFolders =
        folders
            .map(
              (folder) => MenuFlyoutFolder(
                id: folder.id,
                name: displayImmersiveModeFolderName(folder.path),
                path: folder.path,
                parentId: folder.parentId,
              ),
            )
            .toList();
    List<MenuFlyoutItem> buildItems(String? preferenceLevel) {
      return buildMusicMenuFlyoutItems(
        i18n: i18n,
        songId: song.id,
        isFavorite: song.favorite,
        isCurrentTrack: song.id == currentTrackId,
        isPlaying: isPlaying,
        currentTrackId: currentTrackId,
        nowPlayingSongIds: songIds,
        currentPlaylistName: i18n.t('common.nowPlaying'),
        excludePlaylistName: '',
        defaultPlaylistName: song.title,
        songPath: song.path,
        playlists: playlists,
        folders: menuFolders,
        showRemove: true,
        showSeeAlbum: false,
        keepViewActionsOpen: false,
        preferenceLevel: preferenceLevel,
        onUndoPreference:
            preferenceLevel == null
                ? null
                : () {
                  onUndoPreference(song.id);
                },
        onPlay: () {
          onPlayTrack(song, songIds, queueIndex);
        },
        onTogglePlayPause: onTogglePlayPause,
        onPlayNext: null,
        onAddToNowPlaying: () {
          onAddToNowPlaying(song);
        },
        onCreatePlaylist: () {
          onCreatePlaylist(_nextPlaylistName(song.title), [song.id]);
        },
        onCreatePlaylistWithName: (name) {
          onCreatePlaylist(name, [song.id]);
        },
        onAddToPlaylist: (playlistId) {
          onAddToPlaylist(playlistId, [song.id]);
        },
        onRemove: () {
          onRemove(songIds, queueIndex);
          showUndoableNotification(
            context: context,
            i18n: i18n,
            message: i18n.t('notification.removedFrom', {
              'title': song.title,
              'target': i18n.t('common.nowPlaying'),
            }),
            onUndo:
                () => onReplaceQueue(
                  insertImmersiveModeQueueSongs(
                    currentQueueSongIds(),
                    queueIndex,
                    [song.id],
                  ),
                ),
          );
        },
        onSelect: () {
          selection.replaceSelection({queueIndex});
          onSelectionChanged();
        },
        onToggleFavorite: () {
          final nextFavorite = !song.favorite;
          onToggleFavorite([song.id], nextFavorite);
          showUndoableNotification(
            context: context,
            i18n: i18n,
            message: i18n.t(
              nextFavorite
                  ? 'notification.songAddedTo'
                  : 'notification.removedFrom',
              {'title': song.title, 'target': i18n.t('common.myFavorites')},
            ),
            onUndo: () => onToggleFavorite([song.id], song.favorite),
          );
        },
        onSetPreference: (level) {
          onSetPreference(song.id, song.title, level);
        },
        onDelete: () {
          onDeleteSongFromDisk(song);
        },
        onMoveToFolder: (folderPath) {
          onMoveSongToFolder(song, folderPath);
        },
        onSeeArtist: () {
          context.go(
            '/artists?artist=${Uri.encodeComponent(_primaryArtist(song, i18n))}',
          );
          onClose();
        },
        onSeeAlbum: () {
          context.go(
            '/albums?album=${Uri.encodeComponent(_displayAlbum(song, i18n))}',
          );
          onClose();
        },
        onSeeMusicInfo: () {
          onOpenSongDialog(SongDialogMode.properties);
        },
        onSeeLyrics: () {
          onOpenSongDialog(SongDialogMode.lyrics);
        },
        onSeeAlbumArt: () {
          onOpenSongDialog(SongDialogMode.albumArt);
        },
        onSeeLocal: () {
          onRevealSong(song.path);
        },
      );
    }

    final itemsNotifier = ValueNotifier<List<MenuFlyoutItem>>(buildItems(null));
    var menuClosed = false;
    unawaited(
      onGetPreferenceLevel(song.id).then((preferenceLevel) {
        if (!menuClosed) {
          itemsNotifier.value = buildItems(preferenceLevel);
        }
      }),
    );
    await showMenuFlyout(
      context,
      position: position,
      avoidPlayerBar: false,
      items: itemsNotifier.value,
      itemsListenable: itemsNotifier,
    );
    menuClosed = true;
    itemsNotifier.dispose();
  }
}

class ImmersiveModeQueueHeaderActionButton extends StatelessWidget {
  const ImmersiveModeQueueHeaderActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SmPlayerTextIconButton(
      tooltip: tooltip,
      label: tooltip,
      showLabel: false,
      onPressed: onPressed,
      iconWidget: Icon(icon),
    );
  }
}

class ImmersiveModeQueueCloseButton extends StatelessWidget {
  const ImmersiveModeQueueCloseButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ImmersiveModeQueueHeaderActionButton(
      key: const ValueKey('ImmersiveMode.QueueCloseButton'),
      tooltip: tooltip,
      icon: FluentIcons.dismiss_20_regular,
      onPressed: onPressed,
    );
  }
}

String displayImmersiveModeFolderName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index >= 0 ? normalized.substring(index + 1) : normalized;
}

List<int> insertImmersiveModeQueueSongs(
  List<int> queueSongIds,
  int insertIndex,
  List<int> insertedSongIds,
) {
  final index =
      insertIndex < 0
          ? 0
          : insertIndex > queueSongIds.length
          ? queueSongIds.length
          : insertIndex;
  return [
    ...queueSongIds.take(index),
    ...insertedSongIds,
    ...queueSongIds.skip(index),
  ];
}

class ImmersiveModeQueueEmptyState extends StatelessWidget {
  const ImmersiveModeQueueEmptyState({
    super.key,
    required this.i18n,
    required this.loading,
    required this.onQuickPlay,
    required this.onRandomPlay,
  });

  final SmPlayerI18n i18n;
  final bool loading;
  final VoidCallback onQuickPlay;
  final VoidCallback onRandomPlay;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SmPlayerLoadingState(compact: true);
    }
    final colors = ImmersiveModeThemeColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              i18n.t('nowPlaying.queueEmpty'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                SmPlayerTextIconButton(
                  key: const ValueKey(
                    'ImmersiveMode.QueueEmptyQuickPlayButton',
                  ),
                  label: i18n.t('nowPlaying.quickPlay'),
                  icon: FluentIcons.play_20_regular,
                  onPressed: onQuickPlay,
                  minWidth: 118,
                  height: 42,
                  horizontalPadding: 16,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  borderRadius: 10,
                ),
                SmPlayerTextIconButton(
                  key: const ValueKey(
                    'ImmersiveMode.QueueEmptyRandomPlayButton',
                  ),
                  label: i18n.t('nowPlaying.randomPlay'),
                  iconWidget: const ShuffleIcon(),
                  onPressed: onRandomPlay,
                  minWidth: 118,
                  height: 42,
                  horizontalPadding: 16,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  borderRadius: 10,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
