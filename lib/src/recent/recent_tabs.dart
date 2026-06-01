part of 'recent_page.dart';

class _RecentTabs extends StatelessWidget {
  const _RecentTabs({
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
    final colors = RecentThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 18),
      child: SizedBox(
        width: double.infinity,
        height: colors.tabsHeight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: colors.tabsSpacing,
            children: [
              _RecentTabButton(
                active: activeTab == RecentTab.added,
                label: i18n.t('recent.added'),
                count: addedCount,
                showCount: showCount,
                onPressed: () => onChanged(RecentTab.added),
              ),
              _RecentTabButton(
                active: activeTab == RecentTab.played,
                label: i18n.t('recent.played'),
                count: playedCount,
                showCount: showCount,
                onPressed: () => onChanged(RecentTab.played),
              ),
              _RecentTabButton(
                active: activeTab == RecentTab.searches,
                label: i18n.t('recent.searches'),
                count: searchesCount,
                showCount: showCount,
                onPressed: () => onChanged(RecentTab.searches),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTabButton extends StatelessWidget {
  const _RecentTabButton({
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
    if (colors.primaryTabsUsePillStyle) {
      return TextButton(
        style: _recentTextButtonStyle(
          foregroundColor:
              active ? colors.primaryTabActiveText : colors.primaryTabText,
          backgroundColor:
              active
                  ? colors.primaryTabActiveSurface
                  : colors.primaryTabSurface,
          borderColor:
              active ? colors.primaryTabActiveBorder : colors.primaryTabBorder,
          minHeight: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          radius: colors.primaryTabRadius,
        ),
        onPressed: onPressed,
        child: _RecentTabContent(
          label: label,
          count: count,
          showCount: showCount,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          countStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return TextButton(
      style: _recentTextButtonStyle(
        foregroundColor:
            active ? colors.primaryTabActiveText : colors.primaryTabText,
        backgroundColor: Colors.transparent,
        borderColor: Colors.transparent,
        minHeight: 54,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        radius: 0,
      ),
      onPressed: onPressed,
      child: SizedBox(
        height: 54,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            _RecentTabContent(
              label: label,
              count: count,
              showCount: showCount,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              countStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Positioned(
              left: -8,
              right: -8,
              bottom: 5,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: active ? _RecentColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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

ButtonStyle _recentTextButtonStyle({
  required Color foregroundColor,
  required Color backgroundColor,
  required Color borderColor,
  required double minHeight,
  required EdgeInsets padding,
  required double radius,
}) {
  return TextButton.styleFrom(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    minimumSize: Size(0, minHeight),
    maximumSize: Size(double.infinity, minHeight),
    padding: padding,
    foregroundColor: foregroundColor,
    backgroundColor: backgroundColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor),
    ),
    shadowColor: Colors.transparent,
  ).copyWith(
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    minimumSize: WidgetStatePropertyAll(Size(0, minHeight)),
    maximumSize: WidgetStatePropertyAll(Size(double.infinity, minHeight)),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    side: WidgetStatePropertyAll(BorderSide(color: borderColor)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor),
      ),
    ),
  );
}
