part of 'recent_page.dart';

class _RecentAppBarTabs extends StatelessWidget {
  const _RecentAppBarTabs({
    required this.i18n,
    required this.activeTab,
    required this.addedCount,
    required this.playedCount,
    required this.searchesCount,
    required this.showCount,
    required this.onChanged,
  });

  final SmPlayerI18n i18n;
  final RecentTab activeTab;
  final int addedCount;
  final int playedCount;
  final int searchesCount;
  final bool showCount;
  final ValueChanged<RecentTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('Recent.AppBarTabs'),
      builder: (context, constraints) {
        final hideCount =
            constraints.maxWidth <= 520 ||
            MediaQuery.sizeOf(context).width <= 520;
        return SizedBox(
          height: 40,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _RecentAppBarTabButton(
                  active: activeTab == RecentTab.added,
                  label: i18n.t('recent.added'),
                  count: addedCount,
                  showCount: showCount && !hideCount,
                  onPressed: () => onChanged(RecentTab.added),
                ),
                _RecentAppBarTabButton(
                  active: activeTab == RecentTab.played,
                  label: i18n.t('recent.played'),
                  count: playedCount,
                  showCount: showCount && !hideCount,
                  onPressed: () => onChanged(RecentTab.played),
                ),
                _RecentAppBarTabButton(
                  active: activeTab == RecentTab.searches,
                  label: i18n.t('recent.searches'),
                  count: searchesCount,
                  showCount: showCount && !hideCount,
                  onPressed: () => onChanged(RecentTab.searches),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecentAppBarTabButton extends StatelessWidget {
  const _RecentAppBarTabButton({
    required this.active,
    required this.label,
    required this.count,
    required this.showCount,
    required this.onPressed,
  });

  final bool active;
  final String label;
  final int count;
  final bool showCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = RecentThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: SmPlayerTextIconButtonTheme(
        colors: _recentTabButtonColors(
          commandText:
              active ? colors.appBarTabActiveText : colors.appBarTabText,
          commandTextHover:
              active ? colors.appBarTabActiveText : colors.appBarTabHoverText,
          control:
              active ? colors.appBarTabActiveSurface : colors.appBarTabSurface,
          controlHover:
              active
                  ? colors.appBarTabActiveSurface
                  : colors.appBarTabHoverSurface,
          controlBorder:
              active ? colors.appBarTabActiveBorder : colors.appBarTabBorder,
          controlHoverBorder:
              active
                  ? colors.appBarTabActiveBorder
                  : colors.appBarTabHoverBorder,
          controlActive: colors.appBarTabActiveSurface,
          accentStrong: colors.appBarTabActiveText,
        ),
        child: SmPlayerTextIconButton(
          label: label,
          active: active,
          activeHoverSurface:
              active
                  ? _recentActiveTabHoverSurface(
                    context,
                    colors.appBarTabActiveSurface,
                  )
                  : null,
          onPressed: onPressed,
          minWidth: 0,
          height: 34,
          horizontalPadding: 12,
          borderRadius: colors.appBarTabRadius,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          child: _RecentTabContent(
            label: label,
            count: count,
            showCount: showCount,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            countStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
