part of 'menu_flyout.dart';

class _MenuFlyoutItemWidget extends StatefulWidget {
  const _MenuFlyoutItemWidget({
    super.key,
    required this.item,
    required this.itemIndex,
    required this.depth,
    required this.showLeadingIconSpace,
    required this.activeItemIndexListenable,
    required this.anchorContext,
    required this.positionContext,
    required this.metrics,
    required this.onClose,
    required this.onItemEntered,
    required this.onItemExited,
    required this.onPassiveItemEntered,
    required this.onSubmenuEntered,
  });

  final MenuFlyoutItem item;
  final int itemIndex;
  final int depth;
  final bool showLeadingIconSpace;
  final ValueListenable<int?> activeItemIndexListenable;
  final BuildContext anchorContext;
  final BuildContext positionContext;
  final _MenuFlyoutMetrics metrics;
  final VoidCallback onClose;
  final ValueChanged<int> onItemEntered;
  final ValueChanged<int> onItemExited;
  final VoidCallback onPassiveItemEntered;
  final void Function({
    required int itemIndex,
    required Rect triggerRect,
    required List<MenuFlyoutItem> items,
  })
  onSubmenuEntered;

  @override
  State<_MenuFlyoutItemWidget> createState() => _MenuFlyoutItemWidgetState();
}

class _MenuFlyoutItemWidgetState extends State<_MenuFlyoutItemWidget> {
  late bool _active;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _active = widget.activeItemIndexListenable.value == widget.itemIndex;
    widget.activeItemIndexListenable.addListener(_handleActiveItemChanged);
  }

  @override
  void didUpdateWidget(_MenuFlyoutItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeItemIndexListenable !=
        widget.activeItemIndexListenable) {
      oldWidget.activeItemIndexListenable.removeListener(
        _handleActiveItemChanged,
      );
      widget.activeItemIndexListenable.addListener(_handleActiveItemChanged);
    }
    final active = widget.activeItemIndexListenable.value == widget.itemIndex;
    if (_active != active) {
      _active = active;
    }
  }

  @override
  void dispose() {
    widget.activeItemIndexListenable.removeListener(_handleActiveItemChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (item.separator) {
      return MouseRegion(
        onEnter: (_) => widget.onPassiveItemEntered(),
        child: SizedBox(
          height: widget.metrics.separatorHeight,
          child: Center(
            child: Divider(
              height: 1,
              thickness: 1,
              indent: 8,
              endIndent: 8,
              color: MenuFlyoutThemeColors.of(context).separator,
            ),
          ),
        ),
      );
    }
    if (item.content != null) {
      return MouseRegion(
        onEnter: (_) => widget.onPassiveItemEntered(),
        child: SizedBox(
          height: widget.metrics.contentHeight(item),
          child: item.content,
        ),
      );
    }

    final colors = MenuFlyoutThemeColors.of(context);
    final hasSubmenu =
        (item.submenu.isNotEmpty || item.loadSubmenu != null) && !item.disabled;
    final checkedTrailing =
        item.checked && _menuFlyoutItemHasOwnLeadingIcon(item);
    final active = _active && !item.disabled && !_busy;
    final foreground =
        item.disabled
            ? colors.disabledText
            : active
            ? colors.hoverText
            : colors.text;
    Widget itemContent = MouseRegion(
      cursor:
          item.disabled || _busy
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
      onEnter: (_) {
        if (hasSubmenu) {
          _openSubmenu(item);
        } else {
          widget.onItemEntered(widget.itemIndex);
        }
      },
      onExit: (_) {
        if (!hasSubmenu) {
          widget.onItemExited(widget.itemIndex);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown:
            item.onSecondaryTapDown == null
                ? null
                : (details) {
                  _closeOpenMenuFlyouts();
                  item.onSecondaryTapDown!(details.globalPosition);
                },
        onTap:
            item.disabled || _busy
                ? null
                : () async {
                  if (hasSubmenu) {
                    _openSubmenu(item);
                    return;
                  }
                  if (!item.keepOpen) {
                    _closeOpenMenuFlyouts();
                    final result =
                        item.onPressedWithContext?.call(widget.anchorContext) ??
                        item.onPressed?.call();
                    if (result is Future<void>) {
                      unawaited(result);
                    }
                    return;
                  }
                  final result =
                      item.onPressedWithContext?.call(widget.anchorContext) ??
                      item.onPressed?.call();
                  if (result is Future<void>) {
                    setState(() {
                      _busy = true;
                    });
                    try {
                      await result;
                    } finally {
                      if (mounted) {
                        setState(() {
                          _busy = false;
                        });
                      }
                    }
                    return;
                  }
                },
        child: Semantics(
          button: true,
          enabled: !item.disabled && !_busy,
          checked: item.checked,
          child: Container(
            height: widget.metrics.itemHeight,
            padding: EdgeInsets.symmetric(
              horizontal: widget.metrics.horizontalPadding,
            ),
            decoration: BoxDecoration(
              color: active ? colors.hoverSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                if (widget.showLeadingIconSpace) ...[
                  SizedBox(
                    width: widget.metrics.leadingWidth,
                    child: _buildLeadingIcon(item, foreground),
                  ),
                  SizedBox(width: widget.metrics.contentGap),
                ],
                Expanded(
                  child: Text(
                    _busy ? item.pendingText ?? item.text : item.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: widget.metrics.fontSize,
                      height: 1,
                    ),
                  ),
                ),
                if (checkedTrailing) ...[
                  SizedBox(width: widget.metrics.contentGap),
                  Icon(
                    FluentIcons.checkmark_20_regular,
                    size: widget.metrics.trailingIconSize,
                    color: colors.checked,
                  ),
                ] else if (hasSubmenu) ...[
                  SizedBox(width: widget.metrics.contentGap),
                  Icon(
                    FluentIcons.chevron_right_20_regular,
                    size: widget.metrics.trailingIconSize,
                    color: foreground,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (item.tooltip != null) {
      itemContent = Tooltip(message: item.tooltip!, child: itemContent);
    }
    if (item.onAcceptDrop == null) {
      return itemContent;
    }
    return DragTarget<Object>(
      onWillAcceptWithDetails:
          item.onWillAcceptDrop == null
              ? null
              : (details) => item.onWillAcceptDrop!(details.data),
      onAcceptWithDetails: (details) {
        _closeOpenMenuFlyouts();
        item.onAcceptDrop!(details.data);
      },
      builder: (context, candidateData, rejectedData) => itemContent,
    );
  }

  Widget? _buildLeadingIcon(MenuFlyoutItem item, Color foreground) {
    if (item.checked && !_menuFlyoutItemHasOwnLeadingIcon(item)) {
      return Icon(
        FluentIcons.checkmark_20_regular,
        size: widget.metrics.trailingIconSize,
        color: MenuFlyoutThemeColors.of(context).checked,
      );
    }
    final color = item.disabled ? foreground : item.iconColor ?? foreground;
    final iconSize = widget.metrics.iconSize;
    if (item.icon == FluentIcons.play_20_regular) {
      return Center(
        child: SizedBox.square(
          dimension: iconSize,
          child: SmPlayerPlayIcon(size: iconSize, color: color),
        ),
      );
    }
    if (item.useAlbumIcon) {
      return Center(
        child: SizedBox.square(
          dimension: iconSize,
          child: SmPlayerAlbumIcon(size: iconSize, color: color),
        ),
      );
    }
    if (item.usePlaylistIcon) {
      return Center(
        child: SizedBox.square(
          dimension: iconSize,
          child: SmPlayerPlaylistIcon(size: iconSize, color: color),
        ),
      );
    }
    if (item.usePlayNextIcon) {
      return Center(
        child: SizedBox.square(
          dimension: iconSize,
          child: SmPlayerPlayNextIcon(size: iconSize, color: color),
        ),
      );
    }
    if (item.useShuffleIcon) {
      return Center(
        child: SizedBox.square(
          dimension: iconSize,
          child: Center(child: ShuffleIcon(size: iconSize * 0.8, color: color)),
        ),
      );
    }
    if (item.useFullscreenIcon) {
      return Center(
        child: SizedBox.square(
          dimension: iconSize,
          child: SmPlayerFullscreenIcon(size: iconSize, color: color),
        ),
      );
    }
    if (item.useExitFullscreenIcon) {
      return Center(
        child: SizedBox.square(
          dimension: iconSize,
          child: ExitFullscreenIcon(size: iconSize, color: color),
        ),
      );
    }
    if (item.iconWidget != null) {
      return Center(
        child: SizedBox.square(
          dimension: iconSize,
          child: IconTheme(
            data: IconThemeData(color: color, size: iconSize),
            child: item.iconWidget!,
          ),
        ),
      );
    }
    if (item.icon == null) {
      return null;
    }
    if (isMultiSelectIcon(item.icon!)) {
      return Center(
        child: SizedBox.square(
          dimension: iconSize,
          child: UniformMultiSelectIcon(
            size: iconSize,
            color: color,
            strokeWidth: 1.35,
          ),
        ),
      );
    }
    return Icon(item.icon, size: iconSize, color: color);
  }

  bool _loadingSubmenu = false;
  List<MenuFlyoutItem>? _loadedSubmenu;

  void _openSubmenu(MenuFlyoutItem item) {
    if (item.loadSubmenu != null && _loadedSubmenu == null) {
      if (!_loadingSubmenu) unawaited(_loadSubmenu(item));
      return;
    }
    _showSubmenuItems(_loadedSubmenu ?? item.submenu);
  }

  Future<void> _loadSubmenu(MenuFlyoutItem item) async {
    _loadingSubmenu = true;
    widget.onItemEntered(widget.itemIndex);
    try {
      final items = await item.loadSubmenu!(context);
      if (!mounted) return;
      _loadedSubmenu = items;
      if (widget.activeItemIndexListenable.value == widget.itemIndex &&
          items.isNotEmpty) {
        _showSubmenuItems(items);
      }
    } catch (error) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t(
            error is MusicShareException
                ? error.messageKey
                : 'song.updateFailed',
          ),
        );
      }
    } finally {
      _loadingSubmenu = false;
    }
  }

  void _showSubmenuItems(List<MenuFlyoutItem> items) {
    final box = context.findRenderObject() as RenderBox;
    final positionBox = widget.positionContext.findRenderObject() as RenderBox;
    widget.onSubmenuEntered(
      itemIndex: widget.itemIndex,
      triggerRect:
          box.localToGlobal(Offset.zero, ancestor: positionBox) & box.size,
      items: items,
    );
  }

  void _handleActiveItemChanged() {
    final active = widget.activeItemIndexListenable.value == widget.itemIndex;
    if (_active == active) {
      return;
    }
    setState(() {
      _active = active;
    });
  }
}

double _menuFlyoutItemsHeight(
  List<MenuFlyoutItem> items,
  _MenuFlyoutMetrics metrics,
) {
  return (metrics.padding + _menuFlyoutBorderWidth) * 2 +
      _menuFlyoutItemsContentHeight(items, metrics);
}

double _menuFlyoutPanelWidth(
  BuildContext context,
  List<MenuFlyoutItem> items,
  _MenuFlyoutMetrics metrics,
) {
  final textDirection = Directionality.of(context);
  final textScaler = MediaQuery.textScalerOf(context);
  final hasLeadingIconSpace = items.any(_menuFlyoutItemHasLeadingIcon);
  var width = metrics.minWidth;
  for (final item in items) {
    if (item.separator || item.content != null) {
      continue;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: item.pendingText ?? item.text,
        style: TextStyle(fontSize: metrics.fontSize, height: 1),
      ),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    final hasTrailingIcon =
        (item.submenu.isNotEmpty && !item.disabled) ||
        (item.checked && _menuFlyoutItemHasOwnLeadingIcon(item));
    final leadingWidth =
        hasLeadingIconSpace ? metrics.leadingWidth + metrics.contentGap : 0.0;
    final trailingWidth =
        hasTrailingIcon ? metrics.contentGap + metrics.trailingIconSize : 0.0;
    final itemWidth =
        (metrics.padding + _menuFlyoutBorderWidth) * 2 +
        metrics.horizontalPadding * 2 +
        leadingWidth +
        painter.width +
        trailingWidth +
        metrics.textWidthSlack;
    width = math.max(width, itemWidth);
  }
  return width.clamp(metrics.minWidth, metrics.maxWidth).toDouble();
}

bool _menuFlyoutItemHasLeadingIcon(MenuFlyoutItem item) {
  return item.checked || _menuFlyoutItemHasOwnLeadingIcon(item);
}

bool _menuFlyoutItemHasOwnLeadingIcon(MenuFlyoutItem item) {
  return item.icon != null ||
      item.iconWidget != null ||
      item.useAlbumIcon ||
      item.usePlaylistIcon ||
      item.usePlayNextIcon ||
      item.useShuffleIcon ||
      item.useFullscreenIcon ||
      item.useExitFullscreenIcon;
}

double _menuFlyoutItemsContentHeight(
  List<MenuFlyoutItem> items,
  _MenuFlyoutMetrics metrics,
) {
  return items.fold<double>(0, (height, item) {
    if (item.separator) {
      return height + metrics.separatorHeight;
    }
    if (item.content != null) {
      return height + metrics.contentHeight(item);
    }
    return height + metrics.itemHeight;
  });
}
