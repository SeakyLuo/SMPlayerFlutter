part of 'search_page.dart';

class _SearchPageSurface extends StatelessWidget {
  const _SearchPageSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shellColors = ShellThemeColors.of(context);
    return ColoredBox(
      color: shellColors.workspaceSolidSurface,
      child: SizedBox.expand(child: child),
    );
  }
}

class _SearchResultToolbarDelegate extends SliverPersistentHeaderDelegate {
  const _SearchResultToolbarDelegate({required this.child});

  static const _height = 48.0;

  final Widget child;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = SearchPageThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.78, 1],
          colors: colors.resultToolbarGradient,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _searchPageHorizontalInset,
          0,
          _searchPageHorizontalInset,
          8,
        ),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SearchResultToolbarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _SearchLoadingState extends StatelessWidget {
  const _SearchLoadingState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _searchPageHorizontalInset,
          6,
          _searchPageHorizontalInset,
          22,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _SearchColors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              message,
              style: TextStyle(color: colors.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.emptyStateSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.emptyStateBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Text(
            message,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 26,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
