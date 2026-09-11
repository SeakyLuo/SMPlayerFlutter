import 'dart:async';
import 'dart:math' show max, min;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
part 'playlist_control_item_layout.dart';
part 'playlist_control_item_content.dart';
part 'playlist_control_item_metadata_row.dart';
part 'playlist_control_item_actions.dart';

enum PlaylistControlItemVariant { standard, headeredPlaylist, compact }

abstract final class PlaylistControlItemMetrics {
  static double rowHeight(double windowWidth) => windowWidth <= 720 ? 78 : 82;

  static bool isCompactRow(double rowWidth) => rowWidth <= 800 + 18 + 22;

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
    return LayoutBuilder(builder: _buildRow);
  }

  void _setHovered(bool hovered) {
    setState(() {
      _hovered = hovered;
    });
  }
}
