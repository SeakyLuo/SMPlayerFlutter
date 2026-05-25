part of 'main_navigation_view.dart';

class _HoverContainer extends StatefulWidget {
  const _HoverContainer({required this.borderRadius, required this.builder});

  final BorderRadius borderRadius;
  final Widget Function(BuildContext context, bool hovered) builder;

  @override
  State<_HoverContainer> createState() => _HoverContainerState();
}

class _HoverContainerState extends State<_HoverContainer> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
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
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: widget.builder(context, _hovered),
      ),
    );
  }
}

class _MainNavigationViewItemButton extends StatefulWidget {
  const _MainNavigationViewItemButton({
    super.key,
    required this.item,
    required this.label,
    required this.collapsed,
    required this.active,
    required this.onPressed,
    this.onTooltipRequested,
    this.onTooltipDismissed,
  });

  final MainNavigationViewItem item;
  final String label;
  final bool collapsed;
  final bool active;
  final VoidCallback onPressed;
  final _NavigationTooltipRequest? onTooltipRequested;
  final VoidCallback? onTooltipDismissed;

  @override
  State<_MainNavigationViewItemButton> createState() =>
      _MainNavigationViewItemButtonState();
}

class _MainNavigationViewItemButtonState
    extends State<_MainNavigationViewItemButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    final highlighted = widget.active || _hovered;
    final foreground = highlighted ? colors.highlightText : colors.textMuted;
    final background =
        highlighted
            ? widget.collapsed
                ? colors.collapsedHover
                : colors.accentHover
            : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
        _requestTooltip();
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
        widget.onTooltipDismissed?.call();
      },
      child: SizedBox(
        width: widget.collapsed ? 40 : double.infinity,
        height: 40,
        child: Semantics(
          button: true,
          selected: widget.active,
          label: widget.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: Container(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(16),
                border:
                    widget.active && !widget.collapsed
                        ? Border.all(color: colors.accentBorder)
                        : null,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (widget.collapsed || constraints.maxWidth <= 48) {
                    return Center(
                      child: _MainNavigationItemIcon(
                        item: widget.item,
                        color: foreground,
                      ),
                    );
                  }

                  return Row(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: _MainNavigationItemIcon(
                          item: widget.item,
                          color: foreground,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _requestTooltip() {
    final callback = widget.onTooltipRequested;
    final box = context.findRenderObject() as RenderBox?;
    if (callback == null || box == null) {
      return;
    }
    callback(widget.label, box.localToGlobal(Offset.zero) & box.size);
  }
}

class _MainNavigationItemIcon extends StatelessWidget {
  const _MainNavigationItemIcon({required this.item, required this.color});

  final MainNavigationViewItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (item.name == 'AlbumsItem') {
      return Center(
        child: Transform.translate(
          offset: const Offset(0, -1),
          child: SmPlayerAlbumIcon(
            key: const ValueKey('MainNavigationView.AlbumsConcentricIcon'),
            size: 21,
            color: color,
          ),
        ),
      );
    }
    if (item.name == 'PlaylistsItem') {
      return Center(
        child: SmPlayerPlaylistIcon(
          key: const ValueKey('MainNavigationView.PlaylistsMusicListIcon'),
          size: 21,
          color: color,
        ),
      );
    }
    return Icon(_navigationItemIcon(item), size: 21, color: color);
  }
}

IconData _navigationItemIcon(MainNavigationViewItem item) {
  return item.icon;
}

class _NavigationIconButton extends StatefulWidget {
  const _NavigationIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.collapsedContext = false,
    this.size = 40,
    this.iconSize = 20,
    this.borderRadius = 14,
    this.useMutedForeground = false,
    this.onTooltipRequested,
    this.onTooltipDismissed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool collapsedContext;
  final double size;
  final double iconSize;
  final double borderRadius;
  final bool useMutedForeground;
  final _NavigationTooltipRequest? onTooltipRequested;
  final VoidCallback? onTooltipDismissed;

  @override
  State<_NavigationIconButton> createState() => _NavigationIconButtonState();
}

class _NavigationIconButtonState extends State<_NavigationIconButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
        _requestTooltip();
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
        widget.onTooltipDismissed?.call();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color:
                _hovered
                    ? widget.collapsedContext
                        ? colors.collapsedHover
                        : colors.iconButtonHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color:
                _hovered
                    ? colors.highlightText
                    : widget.useMutedForeground
                    ? colors.textMuted
                    : colors.textStrong,
          ),
        ),
      ),
    );
  }

  void _requestTooltip() {
    final callback = widget.onTooltipRequested;
    final box = context.findRenderObject() as RenderBox?;
    if (callback == null || box == null) {
      return;
    }
    callback(widget.tooltip, box.localToGlobal(Offset.zero) & box.size);
  }
}

class _MainNavigationFloatingTooltip extends StatelessWidget {
  const _MainNavigationFloatingTooltip({required this.tooltip});

  final _NavigationFloatingTooltipState tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    return Positioned(
      left: tooltip.left,
      top: tooltip.top,
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -4,
                  top: 13,
                  child: Transform.rotate(
                    angle: 0.7853981633974483,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.dropdownSurface,
                        border: Border(
                          left: BorderSide(color: colors.searchBorder),
                          bottom: BorderSide(color: colors.searchBorder),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 220),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colors.dropdownSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.searchBorder),
                    boxShadow: [
                      BoxShadow(
                        color: colors.dropdownShadow,
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Text(
                    tooltip.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
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

class _MainNavigationViewSeparator extends StatelessWidget {
  const _MainNavigationViewSeparator();

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, thickness: 1, color: colors.sectionDivider),
    );
  }
}
