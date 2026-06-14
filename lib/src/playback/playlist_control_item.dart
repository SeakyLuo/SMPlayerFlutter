import 'dart:math' show max;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_floating_action_button.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_overlay_glass.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart'
    show formatDuration;
import 'package:smplayer_flutter/src/playback/playing_wave.dart';

part 'playlist_control_item_overlays.dart';

enum PlaylistControlItemVariant { standard, headeredPlaylist, compact }

enum PlaylistControlDropPosition { before, after }

class PlaylistControlItemColors {
  const PlaylistControlItemColors({
    required this.border,
    required this.hover,
    required this.hoverBorder,
    required this.current,
    required this.currentForeground,
    required this.currentMuted,
    required this.textStrong,
    required this.textMuted,
    required this.artworkBackground,
    required this.actionForeground,
    required this.actionHover,
  });

  final Color border;
  final Color hover;
  final Color hoverBorder;
  final Color current;
  final Color currentForeground;
  final Color currentMuted;
  final Color textStrong;
  final Color textMuted;
  final Color artworkBackground;
  final Color actionForeground;
  final Color actionHover;
}

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
    this.onPlayNextClick,
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
    required this.onOpenContextMenu,
    this.dropPosition,
    this.variant = PlaylistControlItemVariant.standard,
    this.colors,
    this.showCompactPrimaryActions = false,
    this.collapseCompactPrimaryActions = false,
    this.compactDurationWidth,
    this.compactTrailingPadding,
    this.showFavoriteAction = true,
    this.favoriteAsHoverAction = false,
    this.favoriteLoading = false,
  });

  final LibrarySong song;
  final bool current;
  final bool playing;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleSelection;
  final VoidCallback? onPlayNextClick;
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
  final ValueChanged<Offset> onOpenContextMenu;
  final PlaylistControlDropPosition? dropPosition;
  final PlaylistControlItemVariant variant;
  final PlaylistControlItemColors? colors;
  final bool showCompactPrimaryActions;
  final bool collapseCompactPrimaryActions;
  final double? compactDurationWidth;
  final double? compactTrailingPadding;
  final bool showFavoriteAction;
  final bool favoriteAsHoverAction;
  final bool favoriteLoading;

  @override
  State<PlaylistControlItem> createState() => _PlaylistControlItemState();
}

class _PlaylistControlItemState extends State<PlaylistControlItem> {
  var _hovered = false;
  var _swipeOffset = 0.0;
  PointerDeviceKind? _pointerKind;

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
    if (widget.current) {
      widget.onTogglePlayPause();
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
    final defaultColors = widget.colors == null;
    final colors = widget.colors ?? _PlaylistControlItemColors.resolve(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final viewportCompact = viewportWidth <= 720;
    final hoverActionsVisible = _hovered;
    final showActionSlot = !widget.selectionMode || hoverActionsVisible;
    final multiSelectSelected = widget.selectionMode && widget.selected;
    final transparentHover = colors.hover.withValues(alpha: 0);
    final rowHovered = _hovered;
    final rowBackgroundColor =
        multiSelectSelected || widget.selected
            ? colors.hover
            : rowHovered
            ? colors.hover
            : transparentHover;
    final rowHeight =
        compactVariant
            ? 78.0
            : headeredPlaylist
            ? (viewportCompact ? 86.0 : 88.0)
            : 82.0;
    final artworkGap =
        compactVariant
            ? 12.0
            : headeredPlaylist && !viewportCompact
            ? 22.0
            : 14.0;
    final dropPosition = widget.dropPosition;
    final content = InkWell(
      key: const ValueKey('PlaylistControlItem.Row'),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      onTap: _activateRow,
      onSecondaryTapDown: (details) {
        widget.onOpenContextMenu(details.globalPosition);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: rowHeight,
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: rowBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border(bottom: BorderSide(color: colors.border)),
          boxShadow:
              defaultColors
                  ? widget.selected || _hovered
                      ? [
                        if (widget.selected && !multiSelectSelected)
                          const BoxShadow(
                            color: _PlaylistControlItemColors.selectedInset,
                            offset: Offset(3, 0),
                          ),
                        if (colors.hoverBorder != Colors.transparent)
                          BoxShadow(color: colors.hoverBorder, spreadRadius: 1),
                      ]
                      : null
                  : widget.selected || _hovered
                  ? [BoxShadow(color: colors.hoverBorder, spreadRadius: 1)]
                  : null,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final baseRowPadding =
                compactVariant
                    ? EdgeInsets.fromLTRB(
                      10,
                      10,
                      widget.compactTrailingPadding ?? 20,
                      10,
                    )
                    : headeredPlaylist
                    ? viewportCompact
                        ? const EdgeInsets.fromLTRB(10, 10, 12, 10)
                        : const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        )
                    : const EdgeInsets.fromLTRB(18, 10, 22, 10);
            final contentWidth = max(
              0.0,
              constraints.maxWidth - baseRowPadding.horizontal,
            );
            final compact =
                compactVariant ||
                (headeredPlaylist ? contentWidth <= 1120 : contentWidth <= 800);
            final compactNarrow = compactVariant && contentWidth <= 1120;
            final actionCompactLayout =
                compactVariant || (headeredPlaylist && compact);
            final actionCompactCollapsed =
                widget.collapseCompactPrimaryActions ||
                (compactVariant &&
                    !widget.showCompactPrimaryActions &&
                    compactNarrow) ||
                (headeredPlaylist && compact);
            final hideFavoriteForCompact =
                compact &&
                (compactVariant
                    ? constraints.maxWidth <= 800
                    : constraints.maxWidth <= 720);
            final hideDurationForNarrowHover =
                actionCompactCollapsed && hoverActionsVisible;
            final durationWidth =
                compactVariant
                    ? widget.compactDurationWidth ??
                        (compactNarrow ? 20.0 : 50.0)
                    : headeredPlaylist && compact
                    ? 20.0
                    : headeredPlaylist && !compact
                    ? 74.0
                    : compact
                    ? 20.0
                    : 74.0;
            final artwork = _QueueArtwork(
              song: widget.song,
              current: widget.current,
              playing: widget.playing,
              hovered: _hovered,
              selectionMode: widget.selectionMode,
              selected: widget.selected,
              onPlayTrack: widget.onPlayTrack,
              onTogglePlayPause: widget.onTogglePlayPause,
              colors: colors,
            );
            final rowPadding =
                hideDurationForNarrowHover
                    ? EdgeInsets.fromLTRB(
                      baseRowPadding.left,
                      baseRowPadding.top,
                      6,
                      baseRowPadding.bottom,
                    )
                    : baseRowPadding;
            return Padding(
              padding: rowPadding,
              child: Row(
                children: [
                  compactVariant
                      ? SizedBox(
                        width: 58,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: artwork,
                        ),
                      )
                      : artwork,
                  SizedBox(width: artworkGap),
                  Expanded(
                    flex: compact ? 1 : 12,
                    child: Transform.translate(
                      offset:
                          compactVariant ? const Offset(0, 0.83) : Offset.zero,
                      child: _QueueCopy(
                        song: widget.song,
                        current: widget.current,
                        showAlbum: widget.showAlbum && compact,
                        compactVariant: compactVariant,
                        onSeeAlbum: widget.onSeeAlbum,
                        onSeeArtist: widget.onSeeArtist,
                        colors: colors,
                      ),
                    ),
                  ),
                  if (showActionSlot && !compact) ...[
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
                          compactVariant: actionCompactLayout,
                          showHoverActions: hoverActionsVisible,
                          onToggleFavoriteClick: widget.onToggleFavoriteClick,
                          showFavoriteAction:
                              widget.showFavoriteAction &&
                              !hideFavoriteForCompact,
                          favoriteAsHoverAction: widget.favoriteAsHoverAction,
                          favoriteLoading: widget.favoriteLoading,
                          favoriteHoverVisible: hoverActionsVisible,
                          onAddToPlaylistClick: widget.onAddToPlaylistClick,
                          onPlayNextClick: widget.onPlayNextClick,
                          onRemoveFromListClick: widget.onRemoveFromListClick,
                          onOpenContextMenu: widget.onOpenContextMenu,
                          colors: colors,
                          customColors: widget.colors != null,
                          compactCollapsed: false,
                          showCompactPrimaryActions:
                              widget.showCompactPrimaryActions,
                        ),
                      ),
                    ),
                  ] else if (showActionSlot) ...[
                    const SizedBox(width: 12),
                    _QueueActions(
                      favorite: widget.song.favorite,
                      compact: compact,
                      playNextLabel: widget.playNextLabel,
                      removeLabel: widget.removeLabel,
                      addToPlaylistLabel: widget.addToPlaylistLabel,
                      favoriteLabel: widget.favoriteLabel,
                      moreLabel: widget.moreLabel,
                      compactVariant: actionCompactLayout,
                      showHoverActions: hoverActionsVisible,
                      onToggleFavoriteClick: widget.onToggleFavoriteClick,
                      showFavoriteAction:
                          widget.showFavoriteAction && !hideFavoriteForCompact,
                      favoriteAsHoverAction: widget.favoriteAsHoverAction,
                      favoriteLoading: widget.favoriteLoading,
                      favoriteHoverVisible: hoverActionsVisible,
                      onAddToPlaylistClick: widget.onAddToPlaylistClick,
                      onPlayNextClick: widget.onPlayNextClick,
                      onRemoveFromListClick: widget.onRemoveFromListClick,
                      onOpenContextMenu: widget.onOpenContextMenu,
                      colors: colors,
                      customColors: widget.colors != null,
                      compactCollapsed: actionCompactCollapsed,
                      showCompactPrimaryActions:
                          widget.showCompactPrimaryActions,
                    ),
                  ],
                  if (!compact && hasAlbumColumn) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 7,
                      child: _QueueMetadataLink(
                        key: const ValueKey('PlaylistControlItem.AlbumColumn'),
                        text: displayAlbum(widget.song, i18n),
                        foregroundColor:
                            widget.current
                                ? colors.currentMuted
                                : colors.textMuted,
                        hoverColor: colors.currentForeground,
                        onTap: widget.onSeeAlbum,
                      ),
                    ),
                  ],
                  if (!hideDurationForNarrowHover) ...[
                    SizedBox(width: compactVariant ? 12 : 18),
                    SizedBox(
                      key: const ValueKey('PlaylistControlItem.Duration'),
                      width: durationWidth,
                      child:
                          compactVariant
                              ? Text(
                                formatDuration(widget.song.duration.toDouble()),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  color:
                                      widget.current
                                          ? colors.currentForeground
                                          : colors.textStrong,
                                  fontSize: 14,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              )
                              : OverflowBox(
                                alignment: Alignment.centerRight,
                                minWidth: 0,
                                maxWidth: max(durationWidth, 50),
                                child: SizedBox(
                                  width: max(durationWidth, 50),
                                  child: Text(
                                    formatDuration(
                                      widget.song.duration.toDouble(),
                                    ),
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.visible,
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      color:
                                          widget.current
                                              ? colors.currentForeground
                                              : colors.textStrong,
                                      fontSize: 13,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
    final row = MouseRegion(
      opaque: false,
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
                      left: compactVariant || viewportCompact ? 8 : 18,
                      right: compactVariant || viewportCompact ? 10 : 22,
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
      child: MouseRegion(
        opaque: false,
        cursor: SystemMouseCursors.click,
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
    required this.colors,
  });

  final LibrarySong song;
  final bool current;
  final bool playing;
  final bool hovered;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final PlaylistControlItemColors colors;

  @override
  Widget build(BuildContext context) {
    final artworkShadowVisible = hovered;
    final artworkShadow = BoxShadow(
      color: const Color(0xff202d3f).withValues(alpha: 0.24),
      offset: const Offset(0, 8),
      blurRadius: 18,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          key: const ValueKey('PlaylistControlItem.ArtworkShadow'),
          duration: const Duration(milliseconds: 140),
          curve: Curves.ease,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: artworkShadowVisible ? [artworkShadow] : const [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox.square(
              dimension: 56,
              child: ColoredBox(
                color: colors.artworkBackground,
                child: SongArtwork(artworkPath: song.thumbnailPath),
              ),
            ),
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
        else if (current)
          Positioned.fill(
            key: const ValueKey('PlaylistControlItem.PlayingOverlay'),
            child: _QueuePlayingOverlay(playing: playing),
          ),
        if (!selectionMode && hovered)
          Positioned.fill(
            child: Center(
              child: _QueuePlayOverlayButton(
                tooltip:
                    current && playing
                        ? context.smPlayerI18n.t('player.pause')
                        : context.smPlayerI18n.t('context.play'),
                icon:
                    current && playing
                        ? const SmPlayerPauseIcon(size: 17, color: Colors.white)
                        : const SmPlayerPlayIcon(size: 17, color: Colors.white),
                onPressed: current && playing ? onTogglePlayPause : onPlayTrack,
              ),
            ),
          ),
      ],
    );
  }
}

class _QueueCopy extends StatelessWidget {
  const _QueueCopy({
    required this.song,
    required this.current,
    required this.showAlbum,
    required this.compactVariant,
    required this.onSeeAlbum,
    required this.onSeeArtist,
    required this.colors,
  });

  final LibrarySong song;
  final bool current;
  final bool showAlbum;
  final bool compactVariant;
  final VoidCallback? onSeeAlbum;
  final ValueChanged<String>? onSeeArtist;
  final PlaylistControlItemColors colors;

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
            color: current ? colors.currentForeground : colors.textStrong,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontVariations: [FontVariation.weight(compactVariant ? 760 : 720)],
            height: 1.3,
          ),
        ),
        const SizedBox(height: 5),
        _QueueMetadata(
          song: song,
          current: current,
          showAlbum: showAlbum,
          onSeeAlbum: onSeeAlbum,
          onSeeArtist: onSeeArtist,
          colors: colors,
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
    required this.colors,
  });

  final LibrarySong song;
  final bool current;
  final bool showAlbum;
  final VoidCallback? onSeeAlbum;
  final ValueChanged<String>? onSeeArtist;
  final PlaylistControlItemColors colors;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final color = current ? colors.currentMuted : colors.textMuted;
    final hoverColor = colors.currentForeground;
    final artistNames = songArtists(song);
    final effectiveArtistNames =
        artistNames.isEmpty ? [i18n.t('common.artistUnknown')] : artistNames;
    final children = <Widget>[];
    for (var index = 0; index < effectiveArtistNames.length; index += 1) {
      final artist = effectiveArtistNames[index];
      if (index > 0) {
        children.add(
          Text(
            i18n.t('common.artistSeparator'),
            style: TextStyle(color: color, fontSize: 13),
          ),
        );
      }
      children.add(
        _QueueMetadataLink(
          text: artist,
          foregroundColor: color,
          hoverColor: hoverColor,
          onTap:
              onSeeArtist == null
                  ? null
                  : () {
                    onSeeArtist!(artist);
                  },
        ),
      );
    }

    if (showAlbum) {
      children
        ..add(Text(' · ', style: TextStyle(color: color, fontSize: 13)))
        ..add(
          _QueueMetadataLink(
            key: const ValueKey('PlaylistControlItem.InlineAlbum'),
            text: displayAlbum(song, i18n),
            foregroundColor: color,
            hoverColor: hoverColor,
            onTap: onSeeAlbum,
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

class _QueueMetadataLink extends StatefulWidget {
  const _QueueMetadataLink({
    super.key,
    required this.text,
    required this.foregroundColor,
    required this.hoverColor,
    required this.onTap,
  });

  final String text;
  final Color foregroundColor;
  final Color hoverColor;
  final VoidCallback? onTap;

  @override
  State<_QueueMetadataLink> createState() => _QueueMetadataLinkState();
}

class _QueueMetadataLinkState extends State<_QueueMetadataLink> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final color =
        interactive && _hovered ? widget.hoverColor : widget.foregroundColor;
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) {
        if (interactive) {
          setState(() {
            _hovered = true;
          });
        }
      },
      onHover: (_) {
        if (interactive && !_hovered) {
          setState(() {
            _hovered = true;
          });
        }
      },
      onExit: (_) {
        if (interactive) {
          setState(() {
            _hovered = false;
          });
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: interactive ? widget.onTap : null,
        child: ColoredBox(
          color: Colors.transparent,
          child: Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 13),
          ),
        ),
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
    required this.showFavoriteAction,
    required this.favoriteAsHoverAction,
    required this.favoriteLoading,
    required this.favoriteHoverVisible,
    this.onAddToPlaylistClick,
    this.onPlayNextClick,
    this.onRemoveFromListClick,
    required this.onOpenContextMenu,
    required this.colors,
    required this.customColors,
    required this.compactCollapsed,
    required this.showCompactPrimaryActions,
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
  final bool showFavoriteAction;
  final bool favoriteAsHoverAction;
  final bool favoriteLoading;
  final bool favoriteHoverVisible;
  final ValueChanged<BuildContext>? onAddToPlaylistClick;
  final VoidCallback? onPlayNextClick;
  final VoidCallback? onRemoveFromListClick;
  final ValueChanged<Offset> onOpenContextMenu;
  final PlaylistControlItemColors colors;
  final bool customColors;
  final bool compactCollapsed;
  final bool showCompactPrimaryActions;

  @override
  Widget build(BuildContext context) {
    final actionSize = compactVariant ? 34.0 : 32.0;
    final actionRadius = compactVariant ? 8.0 : 10.0;
    final showPrimaryActions = !compactVariant || showCompactPrimaryActions;
    final compactEssentialActionsOnly = compactVariant && compactCollapsed;
    Widget hoverAction(Widget child, {bool? visible}) {
      final actionVisible = visible ?? showHoverActions;
      return IgnorePointer(
        ignoring: !actionVisible,
        child: AnimatedSlide(
          offset: actionVisible ? Offset.zero : const Offset(0.36, 0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: actionVisible ? 1 : 0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: child,
          ),
        ),
      );
    }

    final actionChildren = [
      if (showFavoriteAction &&
          showPrimaryActions &&
          !compactEssentialActionsOnly &&
          onToggleFavoriteClick != null)
        if (favoriteAsHoverAction)
          hoverAction(
            _QueueActionButton(
              key: const ValueKey('PlaylistControlItem.FavoriteAction'),
              tooltip: favoriteLabel,
              icon:
                  favoriteLoading
                      ? const _QueueActionSpinner()
                      : Icon(
                        favorite
                            ? FluentIcons.heart_20_filled
                            : FluentIcons.heart_20_regular,
                        size: 18,
                      ),
              foregroundColor:
                  favoriteLoading || favorite
                      ? _PlaylistControlItemColors.favorite
                      : colors.actionForeground,
              hoverForegroundColor:
                  favoriteLoading || favorite
                      ? _PlaylistControlItemColors.favorite
                      : colors.currentForeground,
              hoverBackgroundColor: colors.actionHover,
              size: actionSize,
              radius: actionRadius,
              onPressed: favoriteLoading ? null : onToggleFavoriteClick,
            ),
            visible: favoriteHoverVisible,
          )
        else
          _QueueActionButton(
            key: const ValueKey('PlaylistControlItem.FavoriteAction'),
            tooltip: favoriteLabel,
            icon:
                favoriteLoading
                    ? const _QueueActionSpinner()
                    : Icon(
                      favorite
                          ? FluentIcons.heart_20_filled
                          : FluentIcons.heart_20_regular,
                      size: 18,
                    ),
            foregroundColor:
                favoriteLoading || favorite
                    ? _PlaylistControlItemColors.favorite
                    : colors.actionForeground,
            hoverForegroundColor:
                favoriteLoading || favorite
                    ? _PlaylistControlItemColors.favorite
                    : colors.currentForeground,
            hoverBackgroundColor: colors.actionHover,
            size: actionSize,
            radius: actionRadius,
            onPressed: favoriteLoading ? null : onToggleFavoriteClick,
          ),
      if (showPrimaryActions &&
          !compactEssentialActionsOnly &&
          onAddToPlaylistClick != null)
        Builder(
          builder:
              (buttonContext) => hoverAction(
                _QueueActionButton(
                  key: const ValueKey('PlaylistControlItem.AddToAction'),
                  tooltip: addToPlaylistLabel,
                  icon: const Icon(FluentIcons.add_20_regular, size: 18),
                  foregroundColor: colors.actionForeground,
                  hoverForegroundColor: colors.currentForeground,
                  hoverBackgroundColor: colors.actionHover,
                  size: actionSize,
                  radius: actionRadius,
                  onPressed: () {
                    onAddToPlaylistClick!(buttonContext);
                  },
                ),
              ),
        ),
      if (onPlayNextClick != null)
        hoverAction(
          _QueueActionButton(
            key: const ValueKey('PlaylistControlItem.PlayNextAction'),
            tooltip: playNextLabel,
            icon: const SmPlayerPlayNextIcon(size: 18),
            foregroundColor: colors.actionForeground,
            hoverForegroundColor: colors.currentForeground,
            hoverBackgroundColor: colors.actionHover,
            size: actionSize,
            radius: actionRadius,
            onPressed: onPlayNextClick,
          ),
        ),
      if (onRemoveFromListClick != null)
        hoverAction(
          _QueueActionButton(
            key: const ValueKey('PlaylistControlItem.RemoveAction'),
            tooltip: removeLabel,
            icon: const Icon(FluentIcons.dismiss_20_regular, size: 18),
            foregroundColor: colors.actionForeground,
            hoverForegroundColor: colors.currentForeground,
            hoverBackgroundColor: colors.actionHover,
            size: actionSize,
            radius: actionRadius,
            onPressed: onRemoveFromListClick,
          ),
        ),
      Builder(
        builder:
            (buttonContext) => hoverAction(
              _QueueActionButton(
                key: const ValueKey('PlaylistControlItem.MoreAction'),
                tooltip: moreLabel,
                icon: const SmPlayerMoreHorizontalIcon(size: 18),
                foregroundColor: colors.actionForeground,
                hoverForegroundColor: colors.currentForeground,
                hoverBackgroundColor: colors.actionHover,
                size: actionSize,
                radius: actionRadius,
                onPressed: () {
                  final box = buttonContext.findRenderObject() as RenderBox;
                  final offset = box.localToGlobal(
                    Offset(0, box.size.height + 8),
                  );
                  onOpenContextMenu(offset);
                },
              ),
            ),
      ),
    ];
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          compactVariant && !showCompactPrimaryActions && !compactCollapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
      children:
          compactVariant
              ? actionChildren
              : [
                for (var index = 0; index < actionChildren.length; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  actionChildren[index],
                ],
              ],
    );
    if (!compactVariant) {
      return KeyedSubtree(
        key: const ValueKey('PlaylistControlItem.Actions'),
        child: actions,
      );
    }
    final compactCollapsedActionCount =
        1 +
        (onPlayNextClick == null ? 0 : 1) +
        (onRemoveFromListClick == null ? 0 : 1);
    final expandedWidth =
        compactCollapsed
            ? 34.0 * compactCollapsedActionCount
            : showCompactPrimaryActions
            ? 136.0
            : 76.0;
    final collapsedWidth = compactCollapsed ? 34.0 : expandedWidth;
    final actionsWidth = showHoverActions ? expandedWidth : collapsedWidth;
    return Transform.translate(
      offset: const Offset(0, 0.5),
      child: SizedBox(
        key: const ValueKey('PlaylistControlItem.Actions'),
        width: actionsWidth,
        child: ClipRect(
          child: OverflowBox(
            alignment:
                showCompactPrimaryActions
                    ? Alignment.centerLeft
                    : compactCollapsed
                    ? Alignment.centerRight
                    : Alignment.center,
            minWidth: expandedWidth,
            maxWidth: expandedWidth,
            child: actions,
          ),
        ),
      ),
    );
  }
}

class _QueueActionButton extends StatefulWidget {
  const _QueueActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.foregroundColor,
    required this.hoverForegroundColor,
    required this.hoverBackgroundColor,
    required this.size,
    required this.radius,
    required this.onPressed,
  });

  final String? tooltip;
  final Widget icon;
  final Color foregroundColor;
  final Color hoverForegroundColor;
  final Color hoverBackgroundColor;
  final double size;
  final double radius;
  final VoidCallback? onPressed;

  @override
  State<_QueueActionButton> createState() => _QueueActionButtonState();
}

class _QueueActionButtonState extends State<_QueueActionButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        _hovered ? widget.hoverBackgroundColor : Colors.transparent;
    final foregroundColor =
        _hovered ? widget.hoverForegroundColor : widget.foregroundColor;
    return MouseRegion(
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
      child: AnimatedSlide(
        offset: Offset(0, _hovered ? -1 / widget.size : 0),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
          child: IconButton(
            tooltip: widget.tooltip,
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
              width: widget.size,
              height: widget.size,
            ),
            style: IconButton.styleFrom(
              minimumSize: Size.square(widget.size),
              fixedSize: Size.square(widget.size),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: Colors.transparent,
              foregroundColor: foregroundColor,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              disabledForegroundColor: foregroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(widget.radius),
              ),
            ),
            onPressed: widget.onPressed,
            icon: IconTheme(
              data: IconThemeData(color: foregroundColor, size: 18),
              child: widget.icon,
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueActionSpinner extends StatelessWidget {
  const _QueueActionSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _PlaylistControlItemColors {
  const _PlaylistControlItemColors._();

  static const standard = PlaylistControlItemColors(
    border: border,
    hover: hover,
    hoverBorder: Colors.transparent,
    current: current,
    currentForeground: accentStrong,
    currentMuted: currentMuted,
    textStrong: textStrong,
    textMuted: textMuted,
    artworkBackground: Colors.transparent,
    actionForeground: actionForeground,
    actionHover: actionHover,
  );

  static const night = PlaylistControlItemColors(
    border: nightBorder,
    hover: nightHover,
    hoverBorder: nightHoverBorder,
    current: nightCurrent,
    currentForeground: nightCurrentForeground,
    currentMuted: nightCurrentMuted,
    textStrong: nightTextStrong,
    textMuted: nightTextMuted,
    artworkBackground: nightArtworkBackground,
    actionForeground: nightTextMuted,
    actionHover: nightActionHover,
  );

  static PlaylistControlItemColors resolve(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? night : standard;
  }

  static const border = Color(0x297e8b9a);
  static const hover = SmPlayerInteractionColors.hoverSurface;
  static const current = Color(0x1f0078d7);
  static const selectedInset = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const currentMuted = Color(0xff0063b1);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const actionForeground = Color(0xb8586474);
  static const actionHover = Color(0x9effffff);
  static const nightBorder = Color(0x1fd6e0ec);
  static const nightHover = GlobalUI.hoverBgColorNight;
  static const nightHoverBorder = GlobalUI.hoverBorderColorNight;
  static const nightCurrent = Color(0x2e0078d7);
  static const nightCurrentForeground = Color(0xff459de2);
  static const nightCurrentMuted = Color(0xc276b5dc);
  static const nightTextStrong = Color(0xf0f6f9fc);
  static const nightTextMuted = Color(0xadcbd5e1);
  static const nightArtworkBackground = Color(0x14ffffff);
  static const nightActionHover = Color(0x17ffffff);
  static const favorite = Color(0xffd13438);
  static const destructive = Color(0xffc42b1c);
  static const playingOverlay = artworkOverlayGlassColor;
  static const playingOverlayShadow = Color(0x420e1620);
}
