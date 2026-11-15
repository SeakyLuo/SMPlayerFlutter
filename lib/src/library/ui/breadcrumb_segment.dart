import 'package:flutter/material.dart';

import 'local_page_quick_jump.dart';

class BreadcrumbSegmentSurface extends StatefulWidget {
  const BreadcrumbSegmentSurface({
    super.key,
    required this.child,
    this.active = false,
    this.onHoverChanged,
  });

  final Widget child;
  final bool active;
  final ValueChanged<bool>? onHoverChanged;

  @override
  State<BreadcrumbSegmentSurface> createState() =>
      _BreadcrumbSegmentSurfaceState();
}

class _BreadcrumbSegmentSurfaceState extends State<BreadcrumbSegmentSurface> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:
              widget.active || _hovered
                  ? colors.surfaceControlHover
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: widget.child,
      ),
    );
  }

  void _setHovered(bool value) {
    setState(() => _hovered = value);
    widget.onHoverChanged?.call(value);
  }
}

class BreadcrumbLabel extends StatelessWidget {
  const BreadcrumbLabel({
    super.key,
    required this.label,
    required this.compact,
    this.labelKey,
  });

  final String label;
  final bool compact;
  final Key? labelKey;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: compact ? 36 : 32),
    child: Padding(
      padding:
          compact
              ? const EdgeInsets.symmetric(horizontal: 6)
              : const EdgeInsets.fromLTRB(10, 0, 8, 0),
      child: Align(
        alignment: Alignment.center,
        child: Text(
          label,
          key: labelKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: LocalPageColors.of(context).textStrong,
            fontSize: compact ? 14 : 13,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    ),
  );
}
