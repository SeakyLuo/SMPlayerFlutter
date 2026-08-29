import 'dart:async';
import 'dart:math' show max, min;
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
import 'package:smplayer_flutter/src/library/ui/search_match_text.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart'
    show formatDuration;
import 'package:smplayer_flutter/src/playback/playing_wave.dart';

part 'playlist_control_item_overlays.dart';

enum PlaylistControlItemVariant { standard, headeredPlaylist, compact }

abstract final class PlaylistControlItemMetrics {
  static const nowPlayingCompactDurationWidth = 50.0;
  static const nowPlayingCompactTrailingInset = 10.0;
}

enum _PlaylistControlMenuPin { none, addTo, more, contextMenu }

typedef PlaylistControlMenuHandler = FutureOr<void> Function(BuildContext);
typedef PlaylistControlContextMenuHandler = FutureOr<void> Function(Offset);

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

const _queueSwipeActionWidth = 64.0;
const _queueSwipeMinimumContentWidth = 56.0;
const _queueActionSize = 32.0;
const _queueActionGap = 8.0;
final _openPlaylistSwipeOwner = ValueNotifier<Object?>(null);

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
    this.onActivateRow,
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
    this.overlayCompactActions = false,
    this.compactDurationWidth,
    this.compactTrailingPadding,
    this.showFavoriteAction = true,
    this.favoriteAsHoverAction = false,
    this.keepFavoriteActionInCompact = false,
    this.keepAddToActionInCompact = false,
    this.favoriteLoading = false,
    this.swipeEnabled = true,
    this.favoriteSwipeEnabled = true,
    this.searchQuery = '',
    this.showBottomBorder = true,
  });

  final LibrarySong song;
  final bool current;
  final bool playing;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onPlayTrack;
  final VoidCallback? onActivateRow;
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
  final PlaylistControlMenuHandler? onAddToPlaylistClick;
  final VoidCallback? onSeeAlbum;
  final ValueChanged<String>? onSeeArtist;
  final PlaylistControlContextMenuHandler onOpenContextMenu;
  final PlaylistControlDropPosition? dropPosition;
  final PlaylistControlItemVariant variant;
  final PlaylistControlItemColors? colors;
  final bool showCompactPrimaryActions;
  final bool collapseCompactPrimaryActions;
  final bool overlayCompactActions;
  final double? compactDurationWidth;
  final double? compactTrailingPadding;
  final bool showFavoriteAction;
  final bool favoriteAsHoverAction;
  final bool keepFavoriteActionInCompact;
  final bool keepAddToActionInCompact;
  final bool favoriteLoading;
  final bool swipeEnabled;
  final bool favoriteSwipeEnabled;
  final String searchQuery;
  final bool showBottomBorder;

  @override
  State<PlaylistControlItem> createState() => _PlaylistControlItemState();
}

class _PlaylistControlItemState extends State<PlaylistControlItem> {
  var _hovered = false;
  var _menuPin = _PlaylistControlMenuPin.none;
  var _swipeOffset = 0.0;
  var _swipeDragDirection = 0;
  var _swipeLayoutWidth = 0.0;
  PointerDeviceKind? _pointerKind;
  final _swipeOwner = Object();

  @override
  void initState() {
    super.initState();
    _openPlaylistSwipeOwner.addListener(_handleOpenSwipeOwnerChanged);
  }

  @override
  void dispose() {
    _openPlaylistSwipeOwner.removeListener(_handleOpenSwipeOwnerChanged);
    if (identical(_openPlaylistSwipeOwner.value, _swipeOwner)) {
      _openPlaylistSwipeOwner.value = null;
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlaylistControlItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.song.id != oldWidget.song.id ||
        widget.selectionMode ||
        !widget.swipeEnabled ||
        widget.favoriteLoading) {
      _swipeOffset = 0;
      if (identical(_openPlaylistSwipeOwner.value, _swipeOwner)) {
        _openPlaylistSwipeOwner.value = null;
      }
    }
  }

  void _handleOpenSwipeOwnerChanged() {
    if (!identical(_openPlaylistSwipeOwner.value, _swipeOwner) &&
        _swipeOffset != 0) {
      setState(() {
        _swipeOffset = 0;
      });
    }
  }

  bool get _hoverActive => _hovered || _menuPin != _PlaylistControlMenuPin.none;

  Future<void> _openPinnedMenu(
    _PlaylistControlMenuPin pin,
    FutureOr<void> Function() open,
  ) async {
    setState(() {
      _menuPin = pin;
    });
    try {
      await open();
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _menuPin != pin) {
          return;
        }
        setState(() {
          _menuPin = _PlaylistControlMenuPin.none;
        });
      });
    }
  }

  void _resetSwipe() {
    setState(() {
      _swipeOffset = 0;
      _swipeDragDirection = 0;
    });
    if (identical(_openPlaylistSwipeOwner.value, _swipeOwner)) {
      _openPlaylistSwipeOwner.value = null;
    }
  }

  bool get _showFavoriteSwipeAction =>
      widget.showFavoriteAction &&
      widget.favoriteSwipeEnabled &&
      widget.onToggleFavoriteClick != null;

  int get _startSwipeActionCount =>
      (_showFavoriteSwipeAction ? 1 : 0) +
      (widget.onAddToPlaylistClick == null ? 0 : 1);

  int get _endSwipeActionCount =>
      1 +
      (widget.onPlayNextClick == null ? 0 : 1) +
      (widget.onRemoveFromListClick == null ? 0 : 1);

  double _swipeExtent(int actionCount) {
    return min(
      actionCount * _queueSwipeActionWidth,
      max(0, _swipeLayoutWidth - _queueSwipeMinimumContentWidth),
    );
  }

  double get _startSwipeExtent => _swipeExtent(_startSwipeActionCount);

  double get _endSwipeExtent => _swipeExtent(_endSwipeActionCount);

  double _swipeOpenTrigger(double extent) {
    return (extent * 0.45).clamp(36.0, 72.0);
  }

  Future<void> _openSwipePinnedMenu(
    _PlaylistControlMenuPin pin,
    FutureOr<void> Function() open,
  ) async {
    await _openPinnedMenu(pin, open);
    if (mounted) {
      _resetSwipe();
    }
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
    if (widget.onActivateRow case final onActivateRow?) {
      onActivateRow();
      return;
    }
    if (widget.current) {
      widget.onTogglePlayPause();
      return;
    }
    widget.onPlayTrack();
  }

  bool get _swipeConfigured =>
      widget.swipeEnabled &&
      !widget.selectionMode &&
      widget.dropPosition == null &&
      _menuPin == _PlaylistControlMenuPin.none &&
      !widget.favoriteLoading;

  bool get _swipeEnabled =>
      _swipeConfigured && _pointerKind == PointerDeviceKind.touch;

  double get _physicalSwipeDirection =>
      Directionality.of(context) == TextDirection.ltr ? 1 : -1;

  void _updateSwipe(DragUpdateDetails details) {
    if (!_swipeEnabled) {
      return;
    }
    final logicalDelta = details.delta.dx * _physicalSwipeDirection;
    _swipeDragDirection = switch (_swipeDragDirection) {
      0 when logicalDelta < 0 => -1,
      0 when logicalDelta > 0 => 1,
      _ => _swipeDragDirection,
    };
    final minimum = _swipeDragDirection > 0 ? 0.0 : -_endSwipeExtent;
    final maximum = _swipeDragDirection < 0 ? 0.0 : _startSwipeExtent;
    final nextOffset = (_swipeOffset + logicalDelta).clamp(minimum, maximum);
    setState(() {
      _swipeOffset = nextOffset;
    });
  }

  void _settleSwipe() {
    if (!_swipeEnabled) {
      return;
    }
    setState(() {
      _swipeOffset = switch (_swipeOffset) {
        final offset when offset <= -_swipeOpenTrigger(_endSwipeExtent) =>
          -_endSwipeExtent,
        final offset when offset >= _swipeOpenTrigger(_startSwipeExtent) =>
          _startSwipeExtent,
        _ => 0,
      };
    });
    if (_swipeOffset == 0) {
      if (identical(_openPlaylistSwipeOwner.value, _swipeOwner)) {
        _openPlaylistSwipeOwner.value = null;
      }
    } else {
      _openPlaylistSwipeOwner.value = _swipeOwner;
    }
    _swipeDragDirection = 0;
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
    final hoverActionsVisible = _hoverActive;
    final showActionSlot = !widget.selectionMode;
    final multiSelectSelected = widget.selectionMode && widget.selected;
    final transparentHover = colors.hover.withValues(alpha: 0);
    final rowHovered = _hoverActive;
    final opaqueHover = Color.alphaBlend(
      colors.hover,
      Theme.of(context).scaffoldBackgroundColor,
    );
    final rowBackgroundColor =
        multiSelectSelected
            ? opaqueHover
            : widget.current
            ? colors.current
            : widget.selected
            ? opaqueHover
            : rowHovered
            ? opaqueHover
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
        unawaited(
          _openPinnedMenu(
            _PlaylistControlMenuPin.contextMenu,
            () => widget.onOpenContextMenu(details.globalPosition),
          ),
        );
      },
      child: Container(
        height: rowHeight,
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: rowBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border:
              widget.showBottomBorder
                  ? Border(bottom: BorderSide(color: colors.border))
                  : null,
          boxShadow:
              defaultColors
                  ? widget.selected || _hoverActive
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
                  : widget.selected || _hoverActive
                  ? [BoxShadow(color: colors.hoverBorder, spreadRadius: 1)]
                  : null,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _swipeLayoutWidth = constraints.maxWidth;
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
            final standardCompact =
                compact && !compactVariant && !headeredPlaylist;
            final compactNarrow = compactVariant && contentWidth <= 1120;
            final actionCompactLayout =
                compactVariant ||
                headeredPlaylist && compact ||
                standardCompact;
            final actionCompactCollapsed =
                widget.collapseCompactPrimaryActions ||
                (compactVariant &&
                    !widget.showCompactPrimaryActions &&
                    compactNarrow) ||
                (headeredPlaylist && compact) ||
                standardCompact;
            final hideFavoriteForCompact =
                !widget.keepFavoriteActionInCompact &&
                !widget.overlayCompactActions &&
                compact &&
                (compactVariant
                    ? constraints.maxWidth <= 800
                    : constraints.maxWidth <= 720);
            final overlayCompactActions =
                widget.overlayCompactActions && compactVariant;
            final hideDurationForNarrowHover =
                (actionCompactCollapsed || standardCompact) &&
                hoverActionsVisible &&
                !overlayCompactActions;
            final showInlineActions = showActionSlot;
            final stableCompactTrailing =
                compact && actionCompactCollapsed && !overlayCompactActions;
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
            final compactCollapsedActionCount =
                1 +
                (widget.keepFavoriteActionInCompact &&
                        widget.showFavoriteAction &&
                        widget.onToggleFavoriteClick != null
                    ? 1
                    : 0) +
                (widget.keepAddToActionInCompact &&
                        widget.onAddToPlaylistClick != null
                    ? 1
                    : 0) +
                (widget.onPlayNextClick == null ? 0 : 1) +
                (widget.onRemoveFromListClick == null ? 0 : 1);
            final compactCollapsedActionsWidth =
                _queueActionSize * compactCollapsedActionCount +
                _queueActionGap * (compactCollapsedActionCount - 1);
            final stableCompactTrailingWidth = max(
              12.0 + compactCollapsedActionsWidth,
              (compactVariant ? 12.0 : 18.0) + durationWidth,
            );
            final overlayActionCount =
                1 +
                (widget.showFavoriteAction &&
                        !hideFavoriteForCompact &&
                        widget.onToggleFavoriteClick != null
                    ? 1
                    : 0) +
                (widget.onAddToPlaylistClick == null ? 0 : 1) +
                (widget.onPlayNextClick == null ? 0 : 1) +
                (widget.onRemoveFromListClick == null ? 0 : 1);
            final overlayActionsWidth =
                _queueActionSize * overlayActionCount +
                _queueActionGap * (overlayActionCount - 1);
            final artwork = _QueueArtwork(
              song: widget.song,
              current: widget.current,
              playing: widget.playing,
              hovered: _hoverActive,
              selectionMode: widget.selectionMode,
              selected: widget.selected,
              onPlayTrack: widget.onPlayTrack,
              onTogglePlayPause: widget.onTogglePlayPause,
              colors: colors,
            );
            final rowPadding = baseRowPadding;
            Widget queueActions({required bool compactCollapsed}) {
              return _QueueActions(
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
                keepFavoriteActionInCompact: widget.keepFavoriteActionInCompact,
                keepAddToActionInCompact: widget.keepAddToActionInCompact,
                favoriteLoading: widget.favoriteLoading,
                favoriteHoverVisible: hoverActionsVisible,
                addMenuActive: _menuPin == _PlaylistControlMenuPin.addTo,
                moreMenuActive: _menuPin == _PlaylistControlMenuPin.more,
                onAddToPlaylistClick:
                    widget.onAddToPlaylistClick == null
                        ? null
                        : (buttonContext) {
                          unawaited(
                            _openPinnedMenu(
                              _PlaylistControlMenuPin.addTo,
                              () => widget.onAddToPlaylistClick!(buttonContext),
                            ),
                          );
                        },
                onPlayNextClick: widget.onPlayNextClick,
                onRemoveFromListClick: widget.onRemoveFromListClick,
                onOpenContextMenu: (position) {
                  unawaited(
                    _openPinnedMenu(
                      _PlaylistControlMenuPin.more,
                      () => widget.onOpenContextMenu(position),
                    ),
                  );
                },
                colors: colors,
                customColors: widget.colors != null,
                compactCollapsed: compactCollapsed,
                showCompactPrimaryActions: widget.showCompactPrimaryActions,
              );
            }

            Widget duration() {
              return _QueueDuration(
                song: widget.song,
                current: widget.current,
                compactVariant: compactVariant,
                width: durationWidth,
                colors: colors,
              );
            }

            final rowContent = Padding(
              padding: rowPadding,
              child: Row(
                children: [
                  if (compactVariant)
                    SizedBox(
                      width: 58,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: artwork,
                      ),
                    )
                  else
                    artwork,
                  SizedBox(width: artworkGap),
                  Expanded(
                    flex: compact ? 1 : 12,
                    child: Transform.translate(
                      offset:
                          compactVariant ? const Offset(0, 0.83) : Offset.zero,
                      child: _QueueCopy(
                        song: widget.song,
                        searchQuery: widget.searchQuery,
                        current: widget.current,
                        showAlbum: widget.showAlbum && compact,
                        compactVariant: compactVariant,
                        onSeeAlbum: widget.onSeeAlbum,
                        onSeeArtist: widget.onSeeArtist,
                        colors: colors,
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 170),
                      child:
                          showInlineActions
                              ? Center(
                                child: queueActions(compactCollapsed: false),
                              )
                              : null,
                    ),
                  ] else if (stableCompactTrailing) ...[
                    SizedBox(
                      width: stableCompactTrailingWidth,
                      height: _queueActionSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (showInlineActions)
                            Positioned(
                              top: 0,
                              right: 0,
                              bottom: 0,
                              child: queueActions(
                                compactCollapsed: actionCompactCollapsed,
                              ),
                            ),
                          if (!hideDurationForNarrowHover)
                            Positioned(
                              top: 0,
                              right: 0,
                              bottom: 0,
                              child: duration(),
                            ),
                        ],
                      ),
                    ),
                  ] else if (showInlineActions && !overlayCompactActions) ...[
                    const SizedBox(width: 12),
                    queueActions(compactCollapsed: actionCompactCollapsed),
                  ],
                  if (!compact && hasAlbumColumn) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 7,
                      child: _QueueMetadataLink(
                        key: const ValueKey('PlaylistControlItem.AlbumColumn'),
                        text: displayAlbum(widget.song, i18n),
                        searchQuery: widget.searchQuery,
                        foregroundColor:
                            widget.current
                                ? colors.currentMuted
                                : colors.textMuted,
                        hoverColor: colors.currentForeground,
                        onTap: widget.onSeeAlbum,
                      ),
                    ),
                  ],
                  if (!stableCompactTrailing &&
                      !hideDurationForNarrowHover) ...[
                    SizedBox(width: compactVariant ? 12 : 18),
                    duration(),
                  ],
                ],
              ),
            );
            if (!overlayCompactActions) {
              return rowContent;
            }
            final overlayMaskColor = Color.alphaBlend(
              rowBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor,
            );
            return Stack(
              children: [
                rowContent,
                Positioned(
                  top: baseRowPadding.top,
                  right: baseRowPadding.right,
                  bottom: baseRowPadding.bottom,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      end: hoverActionsVisible ? overlayActionsWidth : 0,
                    ),
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: SizedBox(
                      width: overlayActionsWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              overlayMaskColor.withValues(alpha: 0),
                              overlayMaskColor,
                              overlayMaskColor,
                            ],
                            stops: [0, 28 / overlayActionsWidth, 1],
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: queueActions(compactCollapsed: false),
                        ),
                      ),
                    ),
                    builder:
                        (context, width, child) => IgnorePointer(
                          ignoring: !hoverActionsVisible,
                          child: SizedBox(
                            width: width,
                            child: ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.centerRight,
                                minWidth: overlayActionsWidth,
                                maxWidth: overlayActionsWidth,
                                child: child,
                              ),
                            ),
                          ),
                        ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final neutralSwipeBackground =
        dark ? const Color(0xff26384a) : const Color(0xffdbe8f2);
    final alternateSwipeBackground =
        dark ? const Color(0xff1f2f40) : const Color(0xffcdddea);
    final neutralSwipeForeground =
        dark
            ? const Color(0xfff4f8fc)
            : _PlaylistControlItemColors.accentStrong;
    final favoriteSwipeLabel = i18n.t(
      widget.song.favorite ? 'context.removeFavorite' : 'context.addFavorite',
    );
    final addToLabel =
        widget.addToPlaylistLabel ?? i18n.t('context.addToPlaylist');
    final playNextLabel = widget.playNextLabel ?? i18n.t('context.playNext');
    final removeLabel = widget.removeLabel ?? i18n.t('nowPlaying.remove');
    final moreLabel = widget.moreLabel ?? i18n.t('player.more');
    final startSwipeActions = <Widget>[
      if (_showFavoriteSwipeAction)
        _QueueSwipeAction(
          label: favoriteSwipeLabel,
          icon: Icon(
            widget.song.favorite
                ? FluentIcons.heart_20_filled
                : FluentIcons.heart_20_regular,
            size: 19,
          ),
          foregroundColor: Colors.white,
          backgroundColor: _PlaylistControlItemColors.favorite,
          toggled: widget.song.favorite,
          onPressed: () {
            _resetSwipe();
            widget.onToggleFavoriteClick!();
          },
        ),
      if (widget.onAddToPlaylistClick != null)
        Builder(
          builder:
              (buttonContext) => _QueueSwipeAction(
                label: addToLabel,
                icon: const Icon(FluentIcons.add_20_regular, size: 20),
                foregroundColor: neutralSwipeForeground,
                backgroundColor: neutralSwipeBackground,
                active: _menuPin == _PlaylistControlMenuPin.addTo,
                onPressed: () {
                  unawaited(
                    _openSwipePinnedMenu(
                      _PlaylistControlMenuPin.addTo,
                      () => widget.onAddToPlaylistClick!(buttonContext),
                    ),
                  );
                },
              ),
        ),
    ];
    final endSwipeActions = <Widget>[
      if (widget.onPlayNextClick != null)
        _QueueSwipeAction(
          label: playNextLabel,
          icon: const SmPlayerPlayNextIcon(size: 19),
          foregroundColor: neutralSwipeForeground,
          backgroundColor: neutralSwipeBackground,
          onPressed: () {
            _resetSwipe();
            widget.onPlayNextClick!();
          },
        ),
      Builder(
        builder:
            (buttonContext) => _QueueSwipeAction(
              label: moreLabel,
              icon: const SmPlayerMoreHorizontalIcon(size: 20),
              foregroundColor: neutralSwipeForeground,
              backgroundColor: alternateSwipeBackground,
              active: _menuPin == _PlaylistControlMenuPin.more,
              onPressed: () {
                final box = buttonContext.findRenderObject() as RenderBox;
                final offset = box.localToGlobal(
                  Offset(0, box.size.height + 8),
                );
                unawaited(
                  _openSwipePinnedMenu(
                    _PlaylistControlMenuPin.more,
                    () => widget.onOpenContextMenu(offset),
                  ),
                );
              },
            ),
      ),
      if (widget.onRemoveFromListClick != null)
        _QueueSwipeAction(
          label: removeLabel,
          icon: const Icon(FluentIcons.dismiss_20_regular, size: 20),
          foregroundColor: Colors.white,
          backgroundColor: _PlaylistControlItemColors.destructive,
          onPressed: () {
            _resetSwipe();
            widget.onRemoveFromListClick!();
          },
        ),
    ];
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
          if (!identical(_openPlaylistSwipeOwner.value, _swipeOwner)) {
            _openPlaylistSwipeOwner.value = null;
          }
          _pointerKind = event.kind;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart:
              _swipeConfigured
                  ? (details) {
                    _pointerKind = details.kind;
                    _swipeDragDirection = _swipeOffset.sign.toInt();
                  }
                  : null,
          onHorizontalDragUpdate: _swipeConfigured ? _updateSwipe : null,
          onHorizontalDragEnd:
              _swipeConfigured
                  ? (_) {
                    _settleSwipe();
                  }
                  : null,
          onHorizontalDragCancel: _swipeConfigured ? _resetSwipe : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: rowHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: _swipeOffset >= 0,
                      child: AnimatedOpacity(
                        opacity: _swipeOffset < 0 ? 1 : 0,
                        duration:
                            disableAnimations
                                ? Duration.zero
                                : const Duration(milliseconds: 90),
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: _QueueSwipeActionRail(
                            width: _endSwipeExtent,
                            actions: endSwipeActions,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: _swipeOffset <= 0,
                      child: AnimatedOpacity(
                        opacity: _swipeOffset > 0 ? 1 : 0,
                        duration:
                            disableAnimations
                                ? Duration.zero
                                : const Duration(milliseconds: 90),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _QueueSwipeActionRail(
                            width: _startSwipeExtent,
                            actions: startSwipeActions,
                          ),
                        ),
                      ),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: _swipeOffset),
                    duration:
                        disableAnimations
                            ? Duration.zero
                            : _swipeDragDirection == 0
                            ? const Duration(milliseconds: 170)
                            : Duration.zero,
                    curve: Curves.easeOut,
                    builder:
                        (context, offset, child) => Transform.translate(
                          offset: Offset(offset * _physicalSwipeDirection, 0),
                          child: child,
                        ),
                    child: content,
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

class _QueueSwipeActionRail extends StatelessWidget {
  const _QueueSwipeActionRail({required this.width, required this.actions});

  final double width;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: double.infinity,
      child: Row(
        children: [for (final action in actions) Expanded(child: action)],
      ),
    );
  }
}

class _QueueSwipeAction extends StatelessWidget {
  const _QueueSwipeAction({
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onPressed,
    this.active = false,
    this.toggled,
  });

  final String label;
  final Widget icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback onPressed;
  final bool active;
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final effectiveBackground =
        active
            ? Color.alphaBlend(
              Colors.white.withValues(alpha: 0.16),
              backgroundColor,
            )
            : backgroundColor;
    return Semantics(
      excludeSemantics: true,
      button: true,
      label: label,
      toggled: toggled,
      child: Material(
        color: effectiveBackground,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconTheme(
                  data: IconThemeData(color: foregroundColor, size: 20),
                  child: SizedBox(height: 22, child: Center(child: icon)),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueDuration extends StatelessWidget {
  const _QueueDuration({
    required this.song,
    required this.current,
    required this.compactVariant,
    required this.width,
    required this.colors,
  });

  final LibrarySong song;
  final bool current;
  final bool compactVariant;
  final double width;
  final PlaylistControlItemColors colors;

  @override
  Widget build(BuildContext context) {
    final color = current ? colors.currentForeground : colors.textStrong;
    if (compactVariant) {
      return SizedBox(
        key: const ValueKey('PlaylistControlItem.Duration'),
        width: width,
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            formatDuration(song.duration.toDouble()),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }
    return SizedBox(
      key: const ValueKey('PlaylistControlItem.Duration'),
      width: width,
      child: Align(
        alignment: Alignment.centerRight,
        child: OverflowBox(
          alignment: Alignment.centerRight,
          minWidth: 0,
          maxWidth: max(width, 50),
          child: SizedBox(
            width: max(width, 50),
            child: Text(
              formatDuration(song.duration.toDouble()),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
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
                onPressed: current ? onTogglePlayPause : onPlayTrack,
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
    required this.searchQuery,
    required this.current,
    required this.showAlbum,
    required this.compactVariant,
    required this.onSeeAlbum,
    required this.onSeeArtist,
    required this.colors,
  });

  final LibrarySong song;
  final String searchQuery;
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
        SearchMatchText(
          key: const ValueKey('PlaylistControlItem.Title'),
          text: song.title,
          query: searchQuery,
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
          searchQuery: searchQuery,
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
    required this.searchQuery,
    required this.current,
    required this.showAlbum,
    required this.onSeeAlbum,
    required this.onSeeArtist,
    required this.colors,
  });

  final LibrarySong song;
  final String searchQuery;
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
        Flexible(
          child: _QueueMetadataLink(
            text: artist,
            searchQuery: searchQuery,
            foregroundColor: color,
            hoverColor: hoverColor,
            onTap:
                onSeeArtist == null
                    ? null
                    : () {
                      onSeeArtist!(artist);
                    },
          ),
        ),
      );
    }

    if (showAlbum) {
      children
        ..add(Text(' · ', style: TextStyle(color: color, fontSize: 13)))
        ..add(
          Flexible(
            child: _QueueMetadataLink(
              key: const ValueKey('PlaylistControlItem.InlineAlbum'),
              text: displayAlbum(song, i18n),
              searchQuery: searchQuery,
              foregroundColor: color,
              hoverColor: hoverColor,
              onTap: onSeeAlbum,
            ),
          ),
        );
    }

    return SizedBox(
      key: const ValueKey('PlaylistControlItem.Metadata'),
      height: 18,
      child: Row(children: children),
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
    this.searchQuery = '',
  });

  final String text;
  final Color foregroundColor;
  final Color hoverColor;
  final VoidCallback? onTap;
  final String searchQuery;

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
          child: SearchMatchText(
            text: widget.text,
            query: widget.searchQuery,
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
    required this.keepFavoriteActionInCompact,
    required this.keepAddToActionInCompact,
    required this.favoriteLoading,
    required this.favoriteHoverVisible,
    required this.addMenuActive,
    required this.moreMenuActive,
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
  final bool keepFavoriteActionInCompact;
  final bool keepAddToActionInCompact;
  final bool favoriteLoading;
  final bool favoriteHoverVisible;
  final bool addMenuActive;
  final bool moreMenuActive;
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
    const actionSize = _queueActionSize;
    const actionRadius = 10.0;
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
          (!compactEssentialActionsOnly || keepFavoriteActionInCompact) &&
          onToggleFavoriteClick != null)
        if (favoriteAsHoverAction)
          hoverAction(
            _QueueActionButton(
              key: const ValueKey('PlaylistControlItem.FavoriteAction'),
              tooltip: favoriteLabel,
              icon:
                  favoriteLoading
                      ? const _QueueActionSpinner()
                      : SmPlayerFavoriteIcon(favorite: favorite, size: 18),
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
                    : SmPlayerFavoriteIcon(favorite: favorite, size: 18),
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
          (!compactEssentialActionsOnly || keepAddToActionInCompact) &&
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
                  active: addMenuActive,
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
                active: moreMenuActive,
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
      children: [
        for (var index = 0; index < actionChildren.length; index++) ...[
          if (index > 0) const SizedBox(width: _queueActionGap),
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
    final actionCount = actionChildren.length;
    final expandedWidth =
        _queueActionSize * actionCount + _queueActionGap * (actionCount - 1);
    final collapsedWidth = compactCollapsed ? _queueActionSize : expandedWidth;
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
    this.active = false,
  });

  final String? tooltip;
  final Widget icon;
  final Color foregroundColor;
  final Color hoverForegroundColor;
  final Color hoverBackgroundColor;
  final double size;
  final double radius;
  final VoidCallback? onPressed;
  final bool active;

  @override
  State<_QueueActionButton> createState() => _QueueActionButtonState();
}

class _QueueActionButtonState extends State<_QueueActionButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _hovered || widget.active;
    final backgroundColor =
        highlighted ? widget.hoverBackgroundColor : Colors.transparent;
    final foregroundColor =
        highlighted ? widget.hoverForegroundColor : widget.foregroundColor;
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
  static const current = Color(0xffe1effa);
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
  static const nightCurrent = Color(0xff142f46);
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
