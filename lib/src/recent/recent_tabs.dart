part of 'recent_page.dart';

class _RecentTabs extends StatelessWidget {
  const _RecentTabs({
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
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: SizedBox(
        width: double.infinity,
        height: colors.tabsHeight,
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: EdgeInsets.zero,
          labelPadding: EdgeInsets.only(right: colors.tabsSpacing),
          dividerHeight: 0,
          indicatorSize: TabBarIndicatorSize.label,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: _RecentColors.accent, width: 3),
            borderRadius: BorderRadius.all(Radius.circular(999)),
            insets: EdgeInsets.only(left: 6, right: 6, bottom: 5),
          ),
          labelColor: colors.primaryTabActiveText,
          unselectedLabelColor: colors.primaryTabText,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          onTap: (index) {
            onChanged(RecentTab.values[index]);
          },
          tabs: [
            Tab(
              key: const ValueKey('RecentPage.Tab.added'),
              height: 54,
              child: _RecentPrimaryTabContent(
                label: i18n.t('recent.added'),
                count: addedCount,
                showCount: showCount,
              ),
            ),
            Tab(
              key: const ValueKey('RecentPage.Tab.played'),
              height: 54,
              child: _RecentPrimaryTabContent(
                label: i18n.t('recent.played'),
                count: playedCount,
                showCount: showCount,
              ),
            ),
            Tab(
              key: const ValueKey('RecentPage.Tab.searches'),
              height: 54,
              child: _RecentPrimaryTabContent(
                label: i18n.t('recent.searches'),
                count: searchesCount,
                showCount: showCount,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentPrimaryTabContent extends StatelessWidget {
  const _RecentPrimaryTabContent({
    required this.label,
    required this.count,
    required this.showCount,
  });

  final String label;
  final int count;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    return _RecentTabContent(
      label: label,
      count: count,
      showCount: showCount,
      labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      countStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    );
  }
}

SmPlayerTextIconButtonColors _recentTabButtonColors({
  required Color commandText,
  required Color commandTextHover,
  required Color control,
  required Color controlHover,
  required Color controlBorder,
  required Color controlHoverBorder,
  required Color controlActive,
  required Color accentStrong,
}) {
  return SmPlayerTextIconButtonColors(
    commandText: commandText,
    commandTextHover: commandTextHover,
    control: control,
    controlHover: controlHover,
    controlHoverBorder: controlHoverBorder,
    controlActive: controlActive,
    controlBorder: controlBorder,
    accentStrong: accentStrong,
  );
}

class _RecentTabContent extends StatelessWidget {
  const _RecentTabContent({
    required this.label,
    required this.count,
    required this.showCount,
    required this.labelStyle,
    required this.countStyle,
  });

  final String label;
  final int count;
  final bool showCount;
  final TextStyle labelStyle;
  final TextStyle countStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 7,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        if (showCount)
          Text(
            count.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: countStyle,
          ),
      ],
    );
  }
}
