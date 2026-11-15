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

class _SearchHeaderSurface extends StatelessWidget {
  const _SearchHeaderSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ShellThemeColors.of(context).workspaceSolidSurface,
      child: child,
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
    return _SearchHeaderSurface(
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 48,
            child: LinearProgressIndicator(minHeight: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: SearchPageThemeColors.of(context).textMuted,
              ),
            ),
          ),
        ],
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
