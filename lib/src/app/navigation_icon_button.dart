import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';

class SmPlayerNavigationIconButton extends StatefulWidget {
  const SmPlayerNavigationIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.foreground,
    required this.mutedForeground,
    required this.hoverForeground,
    required this.hoverColor,
    required this.collapsedHoverColor,
    this.collapsedContext = false,
    this.size = SmPlayerShellMetrics.navigationButtonSize,
    this.collapsedSize,
    this.iconSize = SmPlayerShellMetrics.navigationIconSize,
    this.borderRadius = SmPlayerShellMetrics.navigationButtonRadius,
    this.useMutedForeground = false,
    this.onTooltipRequested,
    this.onTooltipDismissed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color foreground;
  final Color mutedForeground;
  final Color hoverForeground;
  final Color hoverColor;
  final Color collapsedHoverColor;
  final bool collapsedContext;
  final double size;
  final double? collapsedSize;
  final double iconSize;
  final double borderRadius;
  final bool useMutedForeground;
  final void Function(String label, Rect target)? onTooltipRequested;
  final VoidCallback? onTooltipDismissed;

  @override
  State<SmPlayerNavigationIconButton> createState() =>
      _SmPlayerNavigationIconButtonState();
}

class _SmPlayerNavigationIconButtonState
    extends State<SmPlayerNavigationIconButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final size =
        widget.collapsedContext
            ? widget.collapsedSize ??
                SmPlayerShellMetrics.navigationCollapsedButtonSize
            : widget.size;
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
          width: size,
          height: size,
          decoration: BoxDecoration(
            color:
                _hovered
                    ? widget.collapsedContext
                        ? widget.collapsedHoverColor
                        : widget.hoverColor
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color:
                _hovered
                    ? widget.hoverForeground
                    : widget.useMutedForeground
                    ? widget.mutedForeground
                    : widget.foreground,
          ),
        ),
      ),
    );
  }

  void _requestTooltip() {
    final callback = widget.onTooltipRequested;
    if (callback == null) {
      return;
    }
    final box = context.findRenderObject() as RenderBox;
    callback(widget.tooltip, box.localToGlobal(Offset.zero) & box.size);
  }
}
