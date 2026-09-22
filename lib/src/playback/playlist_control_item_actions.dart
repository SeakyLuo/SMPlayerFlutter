part of 'playlist_control_item.dart';

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
