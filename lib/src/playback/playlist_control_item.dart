import 'package:flutter/gestures.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_floating_action_button.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart'
    show formatDuration;

enum PlaylistControlItemVariant { standard, headeredPlaylist, compact }

enum PlaylistControlDropPosition { before, after }

const _queueItemSwipeLimit = 108.0;
const _queueItemSwipeOpenTrigger = 58.0;

class PlaylistControlItem extends StatefulWidget {
  const PlaylistControlItem({
    super.key,
    required this.song,
    required this.current,
    required this.playing,
    required this.selected,
    required this.selectionMode,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onToggleSelection,
    required this.onPlayNextClick,
    this.onRemoveFromListClick,
    this.showAlbum = true,
    this.playNextLabel,
    this.removeLabel,
    this.addToPlaylistLabel,
    this.favoriteLabel,
    this.moreLabel,
    this.onToggleFavoriteClick,
    this.onAddToPlaylistClick,
    this.onSeeAlbum,
    this.onSeeArtist,
    this.onOpenContextMenu,
    this.dropPosition,
    this.variant = PlaylistControlItemVariant.standard,
  });

  final LibrarySong song;
  final bool current;
  final bool playing;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleSelection;
  final VoidCallback onPlayNextClick;
  final VoidCallback? onRemoveFromListClick;
  final bool showAlbum;
  final String? playNextLabel;
  final String? removeLabel;
  final String? addToPlaylistLabel;
  final String? favoriteLabel;
  final String? moreLabel;
  final VoidCallback? onToggleFavoriteClick;
  final ValueChanged<BuildContext>? onAddToPlaylistClick;
  final VoidCallback? onSeeAlbum;
  final ValueChanged<String>? onSeeArtist;
  final ValueChanged<Offset>? onOpenContextMenu;
  final PlaylistControlDropPosition? dropPosition;
  final PlaylistControlItemVariant variant;

  @override
  State<PlaylistControlItem> createState() => _PlaylistControlItemState();
}

class _PlaylistControlItemState extends State<PlaylistControlItem> {
  final _focusNode = FocusNode(debugLabel: 'PlaylistControlItem');
  var _hovered = false;
  var _focused = false;
  var _swipeOffset = 0.0;
  PointerDeviceKind? _pointerKind;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _focused = _focusNode.hasFocus;
    });
  }

  void _resetSwipe() {
    setState(() {
      _swipeOffset = 0;
    });
  }

  void _activateRow() {
    if (widget.selectionMode) {
      widget.onToggleSelection();
      return;
    }
    if (_swipeOffset != 0) {
      _resetSwipe();
      return;
    }
    widget.onPlayTrack();
  }

  void _activateRowFromKeyboard() {
    if (widget.selectionMode) {
      widget.onToggleSelection();
      return;
    }
    widget.onPlayTrack();
  }

  bool get _swipeEnabled =>
      widget.onRemoveFromListClick != null &&
      !widget.selectionMode &&
      _pointerKind == PointerDeviceKind.touch;

  void _updateSwipe(DragUpdateDetails details) {
    if (!_swipeEnabled) {
      return;
    }
    final nextOffset = (_swipeOffset + details.delta.dx).clamp(
      -_queueItemSwipeLimit,
      0.0,
    );
    setState(() {
      _swipeOffset = nextOffset;
    });
  }

  void _settleSwipe() {
    if (!_swipeEnabled) {
      return;
    }
    setState(() {
      _swipeOffset =
          _swipeOffset <= -_queueItemSwipeOpenTrigger
              ? -_queueItemSwipeLimit
              : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final hasAlbumColumn = widget.showAlbum;
    final headeredPlaylist =
        widget.variant == PlaylistControlItemVariant.headeredPlaylist;
    final compactVariant = widget.variant == PlaylistControlItemVariant.compact;
    final viewportCompact = MediaQuery.sizeOf(context).width <= 720;
    final rowHeight =
        compactVariant
            ? 78.0
            : headeredPlaylist
            ? (viewportCompact ? 86.0 : 88.0)
            : 82.0;
    final rowPadding =
        compactVariant
            ? const EdgeInsets.fromLTRB(10, 10, 12, 10)
            : headeredPlaylist
            ? viewportCompact
                ? const EdgeInsets.fromLTRB(10, 10, 12, 10)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
            : const EdgeInsets.fromLTRB(18, 10, 22, 10);
    final artworkGap =
        compactVariant
            ? 12.0
            : headeredPlaylist && !viewportCompact
            ? 22.0
            : 14.0;
    final dropPosition = widget.dropPosition;
    final content = InkWell(
      onTap: _activateRow,
      onSecondaryTapDown: (details) {
        widget.onOpenContextMenu?.call(details.globalPosition);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: rowHeight,
        margin: EdgeInsets.zero,
        padding: rowPadding,
        decoration: BoxDecoration(
          color:
              widget.current
                  ? _PlaylistControlItemColors.current
                  : widget.selected || _hovered
                  ? _PlaylistControlItemColors.hover
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            bottom: BorderSide(color: _PlaylistControlItemColors.border),
          ),
          boxShadow:
              widget.selected
                  ? const [
                    BoxShadow(
                      color: _PlaylistControlItemColors.selectedInset,
                      offset: Offset(3, 0),
                    ),
                  ]
                  : null,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = compactVariant || constraints.maxWidth <= 720;
            return Row(
              children: [
                _QueueArtwork(
                  song: widget.song,
                  current: widget.current,
                  playing: widget.playing,
                  hovered: _hovered,
                  selectionMode: widget.selectionMode,
                  selected: widget.selected,
                  onPlayTrack: widget.onPlayTrack,
                  onTogglePlayPause: widget.onTogglePlayPause,
                ),
                SizedBox(width: artworkGap),
                Expanded(
                  flex: compact ? 1 : 12,
                  child: _QueueCopy(
                    song: widget.song,
                    current: widget.current,
                    showAlbum: widget.showAlbum,
                    onSeeAlbum: widget.onSeeAlbum,
                    onSeeArtist: widget.onSeeArtist,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 170),
                    child: Center(
                      child: _QueueActions(
                        favorite: widget.song.favorite,
                        compact: compact,
                        playNextLabel: widget.playNextLabel,
                        removeLabel: widget.removeLabel,
                        addToPlaylistLabel: widget.addToPlaylistLabel,
                        favoriteLabel: widget.favoriteLabel,
                        moreLabel: widget.moreLabel,
                        compactVariant: compactVariant,
                        showHoverActions:
                            !compactVariant || _hovered || _focused,
                        onToggleFavoriteClick: widget.onToggleFavoriteClick,
                        onAddToPlaylistClick: widget.onAddToPlaylistClick,
                        onPlayNextClick: widget.onPlayNextClick,
                        onRemoveFromListClick: widget.onRemoveFromListClick,
                        onOpenContextMenu: widget.onOpenContextMenu,
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 14),
                  _QueueActions(
                    favorite: widget.song.favorite,
                    compact: compact,
                    playNextLabel: widget.playNextLabel,
                    removeLabel: widget.removeLabel,
                    addToPlaylistLabel: widget.addToPlaylistLabel,
                    favoriteLabel: widget.favoriteLabel,
                    moreLabel: widget.moreLabel,
                    compactVariant: compactVariant,
                    showHoverActions: !compactVariant || _hovered || _focused,
                    onToggleFavoriteClick: widget.onToggleFavoriteClick,
                    onAddToPlaylistClick: widget.onAddToPlaylistClick,
                    onPlayNextClick: widget.onPlayNextClick,
                    onRemoveFromListClick: widget.onRemoveFromListClick,
                    onOpenContextMenu: widget.onOpenContextMenu,
                  ),
                ],
                if (!compact && hasAlbumColumn) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 7,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: widget.onSeeAlbum,
                      child: Text(
                        displayAlbum(widget.song, i18n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              widget.current
                                  ? _PlaylistControlItemColors.accentStrong
                                  : _PlaylistControlItemColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(width: compactVariant ? 12 : 18),
                SizedBox(
                  width:
                      compactVariant
                          ? 20
                          : headeredPlaylist && !compact
                          ? 74
                          : 42,
                  child: Text(
                    formatDuration(widget.song.duration.toDouble()),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color:
                          widget.current
                              ? _PlaylistControlItemColors.accentStrong
                              : _PlaylistControlItemColors.textStrong,
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    final row = MouseRegion(
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
      child: Listener(
        onPointerDown: (event) {
          _pointerKind = event.kind;
          _focusNode.requestFocus();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (details) {
            _pointerKind = details.kind;
          },
          onHorizontalDragUpdate: _updateSwipe,
          onHorizontalDragEnd: (_) {
            _settleSwipe();
          },
          onHorizontalDragCancel: _resetSwipe,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: rowHeight,
              child: Stack(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: _swipeOffset),
                    duration:
                        _swipeOffset == -_queueItemSwipeLimit ||
                                _swipeOffset == 0
                            ? const Duration(milliseconds: 170)
                            : Duration.zero,
                    curve: Curves.easeOut,
                    builder:
                        (context, offset, child) => Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        ),
                    child: content,
                  ),
                  if (widget.onRemoveFromListClick != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: _swipeOffset == 0,
                        child: AnimatedOpacity(
                          opacity: _swipeOffset == 0 ? 0 : 1,
                          duration: const Duration(milliseconds: 90),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _QueueSwipeRemoveAction(
                              label:
                                  widget.removeLabel ??
                                  context.smPlayerI18n.t('nowPlaying.remove'),
                              onPressed: () {
                                _resetSwipe();
                                widget.onRemoveFromListClick!();
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (dropPosition != null)
                    Positioned(
                      left: 8,
                      right: 10,
                      top:
                          dropPosition == PlaylistControlDropPosition.before
                              ? 0
                              : null,
                      bottom:
                          dropPosition == PlaylistControlDropPosition.after
                              ? 0
                              : null,
                      child: const _QueueDropIndicator(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      child: FocusableActionDetector(
        focusNode: _focusNode,
        mouseCursor: SystemMouseCursors.click,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activateRowFromKeyboard();
              return null;
            },
          ),
        },
        child: row,
      ),
    );
  }
}

class _QueueDropIndicator extends StatelessWidget {
  const _QueueDropIndicator();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('PlaylistControlItem.DropIndicator'),
      decoration: BoxDecoration(
        color: _PlaylistControlItemColors.accentStrong,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: _PlaylistControlItemColors.accentStrong.withValues(
              alpha: 0.14,
            ),
            spreadRadius: 3,
          ),
        ],
      ),
      child: const SizedBox(height: 3),
    );
  }
}

class _QueueSwipeRemoveAction extends StatelessWidget {
  const _QueueSwipeRemoveAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _queueItemSwipeLimit,
      height: double.infinity,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: _PlaylistControlItemColors.destructive,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: const RoundedRectangleBorder(),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
        icon: const Icon(FluentIcons.dismiss_20_regular, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _QueueArtwork extends StatelessWidget {
  const _QueueArtwork({
    required this.song,
    required this.current,
    required this.playing,
    required this.hovered,
    required this.selectionMode,
    required this.selected,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
  });

  final LibrarySong song;
  final bool current;
  final bool playing;
  final bool hovered;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onPlayTrack;
  final VoidCallback onTogglePlayPause;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox.square(
            dimension: 56,
            child: SongArtwork(artworkPath: song.thumbnailPath),
          ),
        ),
        if (selectionMode)
          Positioned(
            top: -5,
            right: -5,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: _PlaylistControlItemColors.accentStrong,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 24,
                child:
                    selected
                        ? const Icon(
                          FluentIcons.checkmark_16_regular,
                          color: Colors.white,
                          size: 14,
                        )
                        : null,
              ),
            ),
          )
        else if (current && !hovered)
          const Positioned.fill(
            key: ValueKey('PlaylistControlItem.PlayingOverlay'),
            child: _QueuePlayingOverlay(),
          )
        else if (hovered)
          Positioned.fill(
            child: Center(
              child: ArtworkFloatingActionButton(
                tooltip:
                    current && playing
                        ? context.smPlayerI18n.t('player.pause')
                        : context.smPlayerI18n.t('context.play'),
                size: 38,
                iconSize: 17,
                icon:
                    current && playing
                        ? const Icon(
                          FluentIcons.pause_20_filled,
                          size: 17,
                          color: Colors.white,
                        )
                        : const SmPlayerPlayIcon(size: 17, color: Colors.white),
                onPressed: current && playing ? onTogglePlayPause : onPlayTrack,
              ),
            ),
          ),
      ],
    );
  }
}

class _QueuePlayingOverlay extends StatelessWidget {
  const _QueuePlayingOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _PlaylistControlItemColors.overlay,
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: 38,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _PlayingBar(height: 7),
              _PlayingBar(height: 12),
              _PlayingBar(height: 15),
              _PlayingBar(height: 9),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayingBar extends StatelessWidget {
  const _PlayingBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _QueueCopy extends StatelessWidget {
  const _QueueCopy({
    required this.song,
    required this.current,
    required this.showAlbum,
    required this.onSeeAlbum,
    required this.onSeeArtist,
  });

  final LibrarySong song;
  final bool current;
  final bool showAlbum;
  final VoidCallback? onSeeAlbum;
  final ValueChanged<String>? onSeeArtist;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: const ValueKey('PlaylistControlItem.Title'),
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color:
                current
                    ? _PlaylistControlItemColors.accentStrong
                    : _PlaylistControlItemColors.textStrong,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        _QueueMetadata(
          song: song,
          current: current,
          showAlbum: showAlbum,
          onSeeAlbum: onSeeAlbum,
          onSeeArtist: onSeeArtist,
        ),
      ],
    );
  }
}

class _QueueMetadata extends StatelessWidget {
  const _QueueMetadata({
    required this.song,
    required this.current,
    required this.showAlbum,
    required this.onSeeAlbum,
    required this.onSeeArtist,
  });

  final LibrarySong song;
  final bool current;
  final bool showAlbum;
  final VoidCallback? onSeeAlbum;
  final ValueChanged<String>? onSeeArtist;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final color =
        current
            ? _PlaylistControlItemColors.accentStrong
            : _PlaylistControlItemColors.textMuted;
    final artistNames = songArtists(song);
    final effectiveArtistNames =
        artistNames.isEmpty ? [i18n.t('common.artistUnknown')] : artistNames;
    final children = <Widget>[];
    for (var index = 0; index < effectiveArtistNames.length; index += 1) {
      final artist = effectiveArtistNames[index];
      if (index > 0) {
        children.add(Text(' / ', style: TextStyle(color: color, fontSize: 13)));
      }
      children.add(
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap:
              onSeeArtist == null
                  ? null
                  : () {
                    onSeeArtist!(artist);
                  },
          child: Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 13),
          ),
        ),
      );
    }

    if (showAlbum) {
      children
        ..add(Text(' - ', style: TextStyle(color: color, fontSize: 13)))
        ..add(
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: onSeeAlbum,
            child: Text(
              displayAlbum(song, i18n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        );
    }

    return SizedBox(
      height: 18,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(children: children),
      ),
    );
  }
}

class _QueueActions extends StatelessWidget {
  const _QueueActions({
    required this.favorite,
    required this.compact,
    required this.compactVariant,
    required this.showHoverActions,
    this.playNextLabel,
    this.removeLabel,
    this.addToPlaylistLabel,
    this.favoriteLabel,
    this.moreLabel,
    this.onToggleFavoriteClick,
    this.onAddToPlaylistClick,
    required this.onPlayNextClick,
    this.onRemoveFromListClick,
    this.onOpenContextMenu,
  });

  final bool favorite;
  final bool compact;
  final bool compactVariant;
  final bool showHoverActions;
  final String? playNextLabel;
  final String? removeLabel;
  final String? addToPlaylistLabel;
  final String? favoriteLabel;
  final String? moreLabel;
  final VoidCallback? onToggleFavoriteClick;
  final ValueChanged<BuildContext>? onAddToPlaylistClick;
  final VoidCallback onPlayNextClick;
  final VoidCallback? onRemoveFromListClick;
  final ValueChanged<Offset>? onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    final iconButtonStyle =
        compactVariant
            ? IconButton.styleFrom(
              minimumSize: const Size.square(34),
              fixedSize: const Size.square(34),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            )
            : null;
    final iconButtonConstraints =
        compactVariant
            ? const BoxConstraints.tightFor(width: 34, height: 34)
            : null;
    Widget hoverAction(Widget child) {
      if (!compactVariant) {
        return child;
      }
      return IgnorePointer(
        ignoring: !showHoverActions,
        child: AnimatedOpacity(
          opacity: showHoverActions ? 1 : 0,
          duration: const Duration(milliseconds: 120),
          child: child,
        ),
      );
    }

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compactVariant && !compact && onToggleFavoriteClick != null)
          IconButton(
            key: const ValueKey('PlaylistControlItem.FavoriteAction'),
            tooltip: favoriteLabel,
            icon: Icon(
              favorite
                  ? FluentIcons.heart_20_filled
                  : FluentIcons.heart_20_regular,
              size: 18,
            ),
            color:
                favorite
                    ? _PlaylistControlItemColors.favorite
                    : _PlaylistControlItemColors.textMuted,
            onPressed: onToggleFavoriteClick,
          ),
        if (!compactVariant &&
            !compact &&
            onToggleFavoriteClick == null &&
            favorite)
          const Icon(
            FluentIcons.heart_20_filled,
            size: 18,
            color: _PlaylistControlItemColors.favorite,
          ),
        if (!compactVariant && !compact) const SizedBox(width: 4),
        if (!compactVariant && onAddToPlaylistClick != null)
          Builder(
            builder:
                (buttonContext) => IconButton(
                  key: const ValueKey('PlaylistControlItem.AddToAction'),
                  tooltip: addToPlaylistLabel,
                  icon: const Icon(FluentIcons.add_20_regular, size: 18),
                  color: _PlaylistControlItemColors.textMuted,
                  onPressed: () {
                    onAddToPlaylistClick!(buttonContext);
                  },
                ),
          ),
        hoverAction(
          IconButton(
            key: const ValueKey('PlaylistControlItem.PlayNextAction'),
            tooltip: playNextLabel,
            icon: const Icon(FluentIcons.next_20_regular, size: 18),
            color: _PlaylistControlItemColors.textMuted,
            style: iconButtonStyle,
            constraints: iconButtonConstraints,
            onPressed: onPlayNextClick,
          ),
        ),
        if (!compactVariant && onRemoveFromListClick != null)
          IconButton(
            key: const ValueKey('PlaylistControlItem.RemoveAction'),
            tooltip: removeLabel,
            icon: const Icon(FluentIcons.dismiss_20_regular, size: 18),
            color: _PlaylistControlItemColors.textMuted,
            onPressed: onRemoveFromListClick,
          ),
        if (onOpenContextMenu != null)
          Builder(
            builder:
                (buttonContext) => hoverAction(
                  IconButton(
                    key: const ValueKey('PlaylistControlItem.MoreAction'),
                    tooltip: moreLabel,
                    icon: const Icon(
                      FluentIcons.more_horizontal_20_regular,
                      size: 18,
                    ),
                    color: _PlaylistControlItemColors.textMuted,
                    style: iconButtonStyle,
                    constraints: iconButtonConstraints,
                    onPressed: () {
                      final box = buttonContext.findRenderObject() as RenderBox;
                      final offset = box.localToGlobal(
                        Offset(0, box.size.height + 8),
                      );
                      onOpenContextMenu!(offset);
                    },
                  ),
                ),
          ),
      ],
    );
    if (!compactVariant) {
      return actions;
    }
    return AnimatedContainer(
      key: const ValueKey('PlaylistControlItem.Actions'),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      width: showHoverActions ? 68 : 34,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: OverflowBox(
        alignment: Alignment.centerRight,
        minWidth: 68,
        maxWidth: 68,
        child: actions,
      ),
    );
  }
}

class _PlaylistControlItemColors {
  const _PlaylistControlItemColors._();

  static const border = Color(0x297e8b9a);
  static const hover = SmPlayerInteractionColors.hoverSurface;
  static const current = Color(0x1f0078d7);
  static const selectedInset = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const favorite = Color(0xffd13438);
  static const destructive = Color(0xffc42b1c);
  static const overlay = Color(0xb81e2228);
}
