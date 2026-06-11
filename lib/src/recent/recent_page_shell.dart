part of 'recent_page.dart';

class _RecentPagePanel extends StatelessWidget {
  const _RecentPagePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimal = constraints.maxWidth < _recentMinimalContentBreakpoint;
        return Padding(
          padding:
              minimal
                  ? const EdgeInsets.fromLTRB(
                    _recentMinimalPageHorizontalPadding,
                    6,
                    _recentMinimalPageHorizontalPadding,
                    0,
                  )
                  : const EdgeInsets.fromLTRB(24, 24, 18, 0),
          child: SizedBox.expand(child: child),
        );
      },
    );
  }
}

class _RecentCommandBarTimelineLabel extends StatelessWidget {
  const _RecentCommandBarTimelineLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final minimal =
        MediaQuery.sizeOf(context).width < _recentMinimalContentBreakpoint;
    final color =
        Theme.of(context).brightness == Brightness.dark
            ? _RecentColors.nightText
            : _RecentColors.textStrong;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: SizedBox(
        height: minimal ? 24 : 29,
        child:
            label.isEmpty
                ? const SizedBox.shrink()
                : Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: minimal ? 18 : 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
      ),
    );
  }
}

class _RecentEmptyState extends StatelessWidget {
  const _RecentEmptyState({required String title, required String message});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
