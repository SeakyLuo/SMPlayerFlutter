part of 'music_library_page.dart';

class _CompactMusicLibraryRowActionOverlay extends StatelessWidget {
  const _CompactMusicLibraryRowActionOverlay({
    required this.visible,
    required this.maskColor,
    required this.actions,
  });

  final bool visible;
  final Color maskColor;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: visible ? 1 : 0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: 136,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [maskColor.withValues(alpha: 0), maskColor, maskColor],
                stops: const [0, 0.21, 1],
              ),
            ),
            child: Align(alignment: Alignment.centerRight, child: actions),
          ),
        ),
        builder:
            (context, progress, child) => IgnorePointer(
              ignoring: !visible,
              child: SizedBox(
                width: 136 * progress,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerRight,
                    minWidth: 136,
                    maxWidth: 136,
                    child: Opacity(
                      opacity: progress,
                      child: Transform.translate(
                        offset: Offset(10 * (1 - progress), 0),
                        child: child,
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
