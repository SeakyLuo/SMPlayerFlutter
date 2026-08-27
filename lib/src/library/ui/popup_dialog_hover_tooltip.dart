part of 'popup_dialog.dart';

class PopupDialogHoverTooltip extends StatefulWidget {
  const PopupDialogHoverTooltip({
    super.key,
    required this.message,
    required this.child,
  });

  final String message;
  final Widget child;

  @override
  State<PopupDialogHoverTooltip> createState() =>
      _PopupDialogHoverTooltipState();
}

class _PopupDialogHoverTooltipState extends State<PopupDialogHoverTooltip> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void didUpdateWidget(PopupDialogHoverTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _hideTooltip();
    }
  }

  @override
  void dispose() {
    _hideTooltip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showTooltip(),
      onExit: (_) => _hideTooltip(),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Semantics(tooltip: widget.message, child: widget.child),
      ),
    );
  }

  void _showTooltip() {
    if (_overlayEntry != null) {
      return;
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder:
          (context) => Positioned.fill(
            child: IgnorePointer(
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.topCenter,
                followerAnchor: Alignment.bottomCenter,
                offset: const Offset(0, -8),
                child: UnconstrainedBox(
                  child: _PopupDialogTooltipBubble(message: widget.message),
                ),
              ),
            ),
          ),
    );
    _overlayEntry = entry;
    overlay.insert(entry);
  }

  void _hideTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _PopupDialogTooltipBubble extends StatelessWidget {
  const _PopupDialogTooltipBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tooltipTheme = TooltipTheme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320, minHeight: 24),
        child: DecoratedBox(
          decoration:
              tooltipTheme.decoration ??
              BoxDecoration(
                color:
                    dark
                        ? Colors.white.withValues(alpha: 0.94)
                        : Colors.grey.shade700.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(4),
              ),
          child: Padding(
            padding:
                tooltipTheme.padding ??
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              message,
              textAlign: tooltipTheme.textAlign ?? TextAlign.start,
              style:
                  tooltipTheme.textStyle ??
                  theme.textTheme.bodyMedium!.copyWith(
                    color: dark ? Colors.black : Colors.white,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
