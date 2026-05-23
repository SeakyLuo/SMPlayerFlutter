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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
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

class _SearchCommitButton extends StatefulWidget {
  const _SearchCommitButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_SearchCommitButton> createState() => _SearchCommitButtonState();
}

class _SearchCommitButtonState extends State<_SearchCommitButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: MouseRegion(
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Icon(
            FluentIcons.search_24_regular,
            size: 18,
            color: _hovered ? colors.accentStrong : colors.textMuted,
          ),
        ),
      ),
    );
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
          child: SizedBox.square(
            dimension: 19,
            child: CustomPaint(
              key: const ValueKey('MainNavigationView.AlbumsConcentricIcon'),
              painter: _AlbumNavigationIconPainter(color),
            ),
          ),
        ),
      );
    }
    if (item.name == 'PlaylistsItem') {
      return Center(
        child: SizedBox.square(
          dimension: 19,
          child: CustomPaint(
            key: const ValueKey('MainNavigationView.PlaylistsMusicListIcon'),
            painter: _PlaylistNavigationIconPainter(color),
          ),
        ),
      );
    }
    return Icon(item.icon, size: 19, color: color);
  }
}

class _AlbumNavigationIconPainter extends CustomPainter {
  const _AlbumNavigationIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final center = Offset(size.width / 2, size.height / 2);
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.45 * scale;
    canvas.drawCircle(center, 8 * scale, paint);
    canvas.drawCircle(center, 3 * scale, paint);
    canvas.drawCircle(
      center,
      1 * scale,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _AlbumNavigationIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PlaylistNavigationIconPainter extends CustomPainter {
  const _PlaylistNavigationIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(
      Offset(4 * scale, 6 * scale),
      Offset(14 * scale, 6 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(4 * scale, 12 * scale),
      Offset(13 * scale, 12 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(4 * scale, 18 * scale),
      Offset(10 * scale, 18 * scale),
      paint,
    );

    final notePath =
        Path()
          ..moveTo(17 * scale, 8 * scale)
          ..lineTo(17 * scale, 17 * scale);
    canvas.drawPath(notePath, paint);

    final flagPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.35 * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(17 * scale, 8 * scale)
        ..quadraticBezierTo(20.5 * scale, 9 * scale, 21 * scale, 6.5 * scale),
      flagPaint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(15.4 * scale, 18.1 * scale),
        width: 5.1 * scale,
        height: 4.1 * scale,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PlaylistNavigationIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _NavigationIconButton extends StatefulWidget {
  const _NavigationIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.collapsedContext = false,
    this.onTooltipRequested,
    this.onTooltipDismissed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool collapsedContext;
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                _hovered
                    ? widget.collapsedContext
                        ? colors.collapsedHover
                        : colors.iconButtonHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: _hovered ? colors.highlightText : colors.textStrong,
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
