part of 'multi_select_command_bar.dart';

enum MultiSelectCommandBarAddToMenuPosition { aboveButton, pointer }

bool _hasAddToTargets({
  required SmPlayerI18n i18n,
  required List<int> songIds,
  required List<int> nowPlayingSongIds,
  required List<MultiSelectCommandBarPlaylist> playlists,
  required bool includeNowPlaying,
  required bool includeFavorites,
  required String? currentPlaylistName,
  required String? excludePlaylistName,
  required FutureOr<void> Function()? onAddToNowPlaying,
  required FutureOr<void> Function()? onToggleFavorite,
  required FutureOr<void> Function()? onCreatePlaylist,
  required FutureOr<void> Function(int)? onAddToPlaylist,
}) {
  if (includeNowPlaying &&
      onAddToNowPlaying != null &&
      shouldShowNowPlayingAddToTarget(
        songIds: songIds,
        nowPlayingSongIds: nowPlayingSongIds,
        isNowPlayingContext: currentPlaylistName == i18n.t('common.nowPlaying'),
      )) {
    return true;
  }
  if (includeFavorites && onToggleFavorite != null) {
    return true;
  }
  if (onCreatePlaylist != null) {
    return true;
  }
  if (onAddToPlaylist == null) {
    return false;
  }
  return playlists.any((playlist) {
    if (playlist.name == (excludePlaylistName ?? currentPlaylistName)) {
      return false;
    }
    if (songIds.length != 1) {
      return true;
    }
    return !playlist.songIds.contains(songIds.first);
  });
}

class MultiSelectCommandBarExtraAction {
  const MultiSelectCommandBarExtraAction({
    required this.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.onPressedWithContext,
    this.disabled = false,
    this.hideAfterClick = false,
  });

  final String key;
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final FutureOr<void> Function(BuildContext context)? onPressedWithContext;
  final bool disabled;
  final bool hideAfterClick;
}

class _MultiSelectAction extends StatelessWidget {
  const _MultiSelectAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.style,
    this.disabled = false,
    this.hideLabel = false,
    this.minWidth = 72,
    this.maxWidth,
    this.preserveLabel = false,
    this.horizontalPadding = 12,
    this.actionHeight = 36,
    this.iconSize = 16,
  });

  final IconData icon;
  final String label;
  final bool disabled;
  final bool hideLabel;
  final double minWidth;
  final double? maxWidth;
  final bool preserveLabel;
  final double horizontalPadding;
  final double actionHeight;
  final double iconSize;
  final _MultiSelectCommandBarStyle style;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final showLabel = !hideLabel;
    return Opacity(
      opacity: disabled ? 0.46 : 1,
      child: _MultiSelectActionShadow(
        style: style,
        disabled: disabled,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final canShowLabel = showLabel && constraints.maxWidth >= 40;
            final resolvedMaxWidth =
                canShowLabel ? maxWidth ?? double.infinity : minWidth;
            final controlWidthLimit = math.min(
              constraints.maxWidth,
              resolvedMaxWidth,
            );
            final reservedWidth = horizontalPadding * 2 + iconSize + 7;
            final labelPainter = TextPainter(
              text: TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontVariations: [FontVariation.weight(640)],
                ),
              ),
              maxLines: 1,
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              locale: Localizations.maybeLocaleOf(context),
            )..layout();
            final labelTruncated =
                canShowLabel &&
                controlWidthLimit.isFinite &&
                labelPainter.width >
                    math.max(0, controlWidthLimit - reservedWidth);
            return SmPlayerTextIconButtonTheme(
              colors: _multiSelectTextIconButtonColors(style),
              child: SmPlayerTextIconButton(
                label: label,
                tooltip: labelTruncated ? label : null,
                iconWidget: _multiSelectActionIcon(icon, iconSize),
                showLabel: canShowLabel,
                disabled: disabled,
                onPressed: onPressed,
                minWidth: minWidth,
                maxWidth: hideLabel ? minWidth : resolvedMaxWidth,
                height: actionHeight,
                horizontalPadding: canShowLabel ? horizontalPadding : 0,
                iconSize: iconSize,
                iconGap: 7,
                opacityWhenDisabled: 1,
                borderRadius: 8,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation.weight(640)],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MultiSelectActionShadow extends StatefulWidget {
  const _MultiSelectActionShadow({
    required this.style,
    required this.child,
    this.disabled = false,
  });

  final _MultiSelectCommandBarStyle style;
  final Widget child;
  final bool disabled;

  @override
  State<_MultiSelectActionShadow> createState() =>
      _MultiSelectActionShadowState();
}

class _MultiSelectActionShadowState extends State<_MultiSelectActionShadow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final shadow =
        widget.disabled
            ? widget.style.actionDisabledShadow
            : _hovered
            ? widget.style.actionHoverShadow
            : widget.style.actionShadow;

    return MouseRegion(
      onEnter: (_) {
        if (!_hovered) {
          setState(() {
            _hovered = true;
          });
        }
      },
      onExit: (_) {
        if (_hovered) {
          setState(() {
            _hovered = false;
          });
        }
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: shadow,
        ),
        child: widget.child,
      ),
    );
  }
}

SmPlayerTextIconButtonColors _multiSelectTextIconButtonColors(
  _MultiSelectCommandBarStyle style,
) {
  return SmPlayerTextIconButtonColors(
    commandText: style.actionForeground,
    commandTextHover: style.actionHoverForeground,
    control: style.actionSurface,
    controlHover: style.actionHoverSurface,
    controlHoverBorder: style.actionHoverBorder,
    controlActive: style.actionHoverSurface,
    controlBorder: style.actionBorder,
    accentStrong: style.accent,
  );
}

class _MultiSelectAddToAction extends StatefulWidget {
  const _MultiSelectAddToAction({
    required this.enabled,
    required this.compactSelection,
    required this.compactPhone,
    required this.compactActionSize,
    required this.compactWideActionWidth,
    required this.actionHeight,
    required this.iconSize,
    required this.style,
    required this.songIds,
    required this.nowPlayingSongIds,
    required this.defaultPlaylistName,
    required this.playlists,
    required this.includeNowPlaying,
    required this.includeFavorites,
    required this.currentPlaylistName,
    required this.excludePlaylistName,
    required this.menuPosition,
    required this.onAddToNowPlaying,
    required this.onToggleFavorite,
    required this.onCreatePlaylist,
    required this.onAddToPlaylist,
    required this.onMenuItemSelected,
  });

  final bool enabled;
  final bool compactSelection;
  final bool compactPhone;
  final double compactActionSize;
  final double compactWideActionWidth;
  final double actionHeight;
  final double iconSize;
  final _MultiSelectCommandBarStyle style;
  final List<int> songIds;
  final List<int> nowPlayingSongIds;
  final String? defaultPlaylistName;
  final List<MultiSelectCommandBarPlaylist> playlists;
  final bool includeNowPlaying;
  final bool includeFavorites;
  final String? currentPlaylistName;
  final String? excludePlaylistName;
  final MultiSelectCommandBarAddToMenuPosition menuPosition;
  final FutureOr<void> Function()? onAddToNowPlaying;
  final FutureOr<void> Function()? onToggleFavorite;
  final FutureOr<void> Function()? onCreatePlaylist;
  final FutureOr<void> Function(int)? onAddToPlaylist;
  final VoidCallback onMenuItemSelected;

  @override
  State<_MultiSelectAddToAction> createState() =>
      _MultiSelectAddToActionState();
}

class _MultiSelectAddToActionState extends State<_MultiSelectAddToAction> {
  Offset? _lastPointerDownPosition;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return Builder(
      builder: (buttonContext) {
        return Listener(
          onPointerDown: (event) {
            _lastPointerDownPosition = event.position;
          },
          child: _MultiSelectAction(
            icon: FluentIcons.add_20_regular,
            label: i18n.t('albums.addSelectedTo'),
            disabled: !widget.enabled,
            minWidth: widget.compactPhone ? widget.compactActionSize : 92,
            maxWidth:
                widget.compactPhone ? widget.compactWideActionWidth : null,
            actionHeight: widget.actionHeight,
            iconSize: widget.iconSize,
            preserveLabel: !widget.compactSelection,
            horizontalPadding: widget.compactPhone ? 12 : 9,
            style: widget.style,
            onPressed: () {
              final menuSongIds =
                  widget.songIds.isEmpty && widget.enabled
                      ? const [-1]
                      : widget.songIds;
              final addToItem = buildAddToPlaylistMenuFlyoutItem(
                i18n: i18n,
                songIds: menuSongIds,
                playlists: widget.playlists,
                defaultPlaylistName: widget.defaultPlaylistName,
                currentPlaylistName: widget.currentPlaylistName,
                excludePlaylistName: widget.excludePlaylistName,
                includeNowPlaying:
                    widget.includeNowPlaying &&
                    shouldShowNowPlayingAddToTarget(
                      songIds: menuSongIds,
                      nowPlayingSongIds: widget.nowPlayingSongIds,
                      isNowPlayingContext:
                          widget.currentPlaylistName ==
                          i18n.t('common.nowPlaying'),
                    ),
                includeFavorites: widget.includeFavorites,
                onAddToNowPlaying:
                    widget.onAddToNowPlaying == null
                        ? null
                        : () {
                          widget.onAddToNowPlaying?.call();
                          widget.onMenuItemSelected();
                        },
                onToggleFavorite:
                    widget.onToggleFavorite == null
                        ? null
                        : () {
                          widget.onToggleFavorite?.call();
                          widget.onMenuItemSelected();
                        },
                onCreatePlaylist:
                    widget.onCreatePlaylist == null
                        ? null
                        : () {
                          widget.onCreatePlaylist?.call();
                          widget.onMenuItemSelected();
                        },
                onAddToPlaylist: (playlistId) {
                  widget.onAddToPlaylist?.call(playlistId);
                  widget.onMenuItemSelected();
                },
              );
              if (addToItem == null) {
                return;
              }

              showMenuFlyout(
                buttonContext,
                position: _addToMenuFlyoutPosition(),
                anchorPlacement: MenuFlyoutAnchorPlacement.above,
                anchorAlignment:
                    widget.menuPosition ==
                            MultiSelectCommandBarAddToMenuPosition.pointer
                        ? MenuFlyoutAnchorAlignment.start
                        : MenuFlyoutAnchorAlignment.end,
                avoidPlayerBar: false,
                items: addToItem.submenu,
              );
            },
          ),
        );
      },
    );
  }

  Offset? _addToMenuFlyoutPosition() {
    if (widget.menuPosition == MultiSelectCommandBarAddToMenuPosition.pointer) {
      final pointerPosition = _lastPointerDownPosition;
      _lastPointerDownPosition = null;
      return pointerPosition;
    }
    return null;
  }
}

Widget _multiSelectActionIcon(IconData icon, double size) {
  return SizedBox.square(
    dimension: size,
    child: Center(child: Icon(icon, size: size)),
  );
}

class _MultiSelectSeparator extends StatelessWidget {
  const _MultiSelectSeparator({required this.style, this.height = 28});

  final _MultiSelectCommandBarStyle style;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: height, color: style.separator);
  }
}

double _multiSelectActionNaturalWidth(
  BuildContext context,
  String label, {
  double minWidth = 72,
  double horizontalPadding = 12,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        fontVariations: [FontVariation.weight(640)],
      ),
    ),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
  )..layout();
  return math.max(minWidth, horizontalPadding * 2 + 16 + 7 + painter.width);
}

double _multiSelectActionsWidth(List<double> widths, double gap) {
  return widths.reduce((sum, width) => sum + width) + gap * (widths.length - 1);
}

List<Widget> _withGaps(
  List<Widget> children,
  double gap, {
  required bool flexible,
}) {
  if (children.length < 2) {
    return children;
  }
  return [
    for (var index = 0; index < children.length; index += 1) ...[
      if (index > 0) SizedBox(width: gap),
      flexible ? _flexibleActionChild(children[index]) : children[index],
    ],
  ];
}

Widget _flexibleActionChild(Widget child) {
  if (child is _MultiSelectSeparator) {
    return child;
  }
  if (child is _MultiSelectAction && child.preserveLabel) {
    return child;
  }
  if (child is _MultiSelectAddToAction && !child.compactSelection) {
    return child;
  }
  return Flexible(fit: FlexFit.loose, child: child);
}
