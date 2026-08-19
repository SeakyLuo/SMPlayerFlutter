part of 'recent_page.dart';

class _RecentAppBarTabs extends StatelessWidget {
  const _RecentAppBarTabs({
    required this.controller,
    required this.i18n,
    required this.addedCount,
    required this.playedCount,
    required this.searchesCount,
    required this.showCount,
    required this.onChanged,
  });

  final TabController controller;
  final SmPlayerI18n i18n;
  final int addedCount;
  final int playedCount;
  final int searchesCount;
  final bool showCount;
  final ValueChanged<RecentTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = RecentThemeColors.of(context);
    return LayoutBuilder(
      key: const ValueKey('Recent.AppBarTabs'),
      builder: (context, constraints) {
        final hideCount =
            constraints.maxWidth <= 520 ||
            MediaQuery.sizeOf(context).width <= 520;
        return SizedBox(
          height: 40,
          child: TabBar(
            controller: controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.only(right: 24),
            dividerHeight: 0,
            indicatorSize: TabBarIndicatorSize.label,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: _RecentColors.accent, width: 3),
              borderRadius: BorderRadius.all(Radius.circular(999)),
              insets: EdgeInsets.only(left: 6, right: 6, bottom: 1),
            ),
            labelColor: colors.appBarTabActiveText,
            unselectedLabelColor: colors.appBarTabText,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            onTap: (index) => onChanged(RecentTab.values[index]),
            tabs: [
              _RecentAppBarTab(
                key: const ValueKey('RecentPage.AppBarTab.added'),
                label: i18n.t('recent.added'),
                count: addedCount,
                showCount: showCount && !hideCount,
              ),
              _RecentAppBarTab(
                key: const ValueKey('RecentPage.AppBarTab.played'),
                label: i18n.t('recent.played'),
                count: playedCount,
                showCount: showCount && !hideCount,
              ),
              _RecentAppBarTab(
                key: const ValueKey('RecentPage.AppBarTab.searches'),
                label: i18n.t('recent.searches'),
                count: searchesCount,
                showCount: showCount && !hideCount,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentAppBarTab extends StatelessWidget {
  const _RecentAppBarTab({
    super.key,
    required this.label,
    required this.count,
    required this.showCount,
  });

  final String label;
  final int count;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 40,
      child: _RecentTabContent(
        label: label,
        count: count,
        showCount: showCount,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        countStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
