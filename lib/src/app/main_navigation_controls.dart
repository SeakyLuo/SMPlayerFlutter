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
        width:
            widget.collapsed
                ? SmPlayerShellMetrics.navigationCollapsedButtonSize
                : double.infinity,
        height: SmPlayerShellMetrics.navigationButtonSize,
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
                borderRadius: BorderRadius.circular(
                  SmPlayerShellMetrics.navigationButtonRadius,
                ),
                border:
                    widget.collapsed
                        ? null
                        : Border.all(
                          color:
                              widget.active
                                  ? colors.accentBorder
                                  : Colors.transparent,
                        ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (widget.collapsed || constraints.maxWidth <= 48) {
                    return Center(
                      child: _MainNavigationItemIcon(
                        item: widget.item,
                        color: foreground,
                        size: 21,
                      ),
                    );
                  }

                  return Row(
                    children: [
                      SizedBox(
                        width: SmPlayerShellMetrics.navigationButtonSize,
                        height: SmPlayerShellMetrics.navigationButtonSize,
                        child: _MainNavigationItemIcon(
                          item: widget.item,
                          color: foreground,
                          size: 21,
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
  const _MainNavigationItemIcon({
    required this.item,
    required this.color,
    required this.size,
  });

  final MainNavigationViewItem item;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (item.name == 'AlbumsItem') {
      return Center(
        child: Transform.translate(
          offset: const Offset(0, -1),
          child: SmPlayerAlbumIcon(
            key: const ValueKey('MainNavigationView.AlbumsConcentricIcon'),
            size: size,
            color: color,
          ),
        ),
      );
    }
    if (item.name == 'PlaylistsItem') {
      return Center(
        child: SmPlayerPlaylistIcon(
          key: const ValueKey('MainNavigationView.PlaylistsMusicListIcon'),
          size: size,
          color: color,
        ),
      );
    }
    return Icon(_navigationItemIcon(item), size: size, color: color);
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
    this.size = SmPlayerShellMetrics.navigationButtonSize,
    this.iconSize = SmPlayerShellMetrics.navigationIconSize,
    this.borderRadius = SmPlayerShellMetrics.navigationButtonRadius,
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
  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    return SmPlayerNavigationIconButton(
      icon: widget.icon,
      tooltip: widget.tooltip,
      onPressed: widget.onPressed,
      foreground: colors.textStrong,
      mutedForeground: colors.textMuted,
      hoverForeground: colors.highlightText,
      hoverColor: colors.iconButtonHover,
      collapsedHoverColor: colors.collapsedHover,
      collapsedContext: widget.collapsedContext,
      size: widget.size,
      iconSize: widget.iconSize,
      borderRadius: widget.borderRadius,
      useMutedForeground: widget.useMutedForeground,
      onTooltipRequested: widget.onTooltipRequested,
      onTooltipDismissed: widget.onTooltipDismissed,
    );
  }
}

class _MainNavigationFloatingTooltip extends StatelessWidget {
  const _MainNavigationFloatingTooltip({required this.tooltip});

  final _NavigationFloatingTooltipState tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    const arrowWidth = 6.0;
    const arrowHeight = 12.0;
    const borderRadius = 6.0;
    return Positioned(
      left: tooltip.left,
      top: tooltip.top,
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: CustomPaint(
              key: const ValueKey('MainNavigationView.FloatingTooltipBubble'),
              painter: _MainNavigationFloatingTooltipPainter(
                backgroundColor: colors.dropdownSurface,
                borderColor: colors.searchBorder,
                shadowColor: colors.dropdownShadow,
                shadowBlurRadius: 24,
                shadowOffset: const Offset(0, 10),
                borderRadius: borderRadius,
                arrowWidth: arrowWidth,
                arrowHeight: arrowHeight,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainNavigationFloatingTooltipPainter extends CustomPainter {
  const _MainNavigationFloatingTooltipPainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
    required this.shadowBlurRadius,
    required this.shadowOffset,
    required this.borderRadius,
    required this.arrowWidth,
    required this.arrowHeight,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final double shadowBlurRadius;
  final Offset shadowOffset;
  final double borderRadius;
  final double arrowWidth;
  final double arrowHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyRect = Offset.zero & size;
    final path = _outlinePath(bodyRect);
    final shadowPaint =
        Paint()
          ..color = shadowColor
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlurRadius);
    canvas.drawPath(path.shift(shadowOffset), shadowPaint);
    canvas.drawPath(path, Paint()..color = backgroundColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  Path _outlinePath(Rect bodyRect) {
    final r = borderRadius;
    final arrowTop = bodyRect.center.dy - arrowHeight / 2;
    final arrowBottom = bodyRect.center.dy + arrowHeight / 2;
    return Path()
      ..moveTo(bodyRect.left + r, bodyRect.top)
      ..lineTo(bodyRect.right - r, bodyRect.top)
      ..quadraticBezierTo(
        bodyRect.right,
        bodyRect.top,
        bodyRect.right,
        bodyRect.top + r,
      )
      ..lineTo(bodyRect.right, bodyRect.bottom - r)
      ..quadraticBezierTo(
        bodyRect.right,
        bodyRect.bottom,
        bodyRect.right - r,
        bodyRect.bottom,
      )
      ..lineTo(bodyRect.left + r, bodyRect.bottom)
      ..quadraticBezierTo(
        bodyRect.left,
        bodyRect.bottom,
        bodyRect.left,
        bodyRect.bottom - r,
      )
      ..lineTo(bodyRect.left, arrowBottom)
      ..lineTo(bodyRect.left - arrowWidth, bodyRect.center.dy)
      ..lineTo(bodyRect.left, arrowTop)
      ..lineTo(bodyRect.left, bodyRect.top + r)
      ..quadraticBezierTo(
        bodyRect.left,
        bodyRect.top,
        bodyRect.left + r,
        bodyRect.top,
      )
      ..close();
  }

  @override
  bool shouldRepaint(
    covariant _MainNavigationFloatingTooltipPainter oldDelegate,
  ) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.shadowBlurRadius != shadowBlurRadius ||
        oldDelegate.shadowOffset != shadowOffset ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.arrowWidth != arrowWidth ||
        oldDelegate.arrowHeight != arrowHeight;
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
