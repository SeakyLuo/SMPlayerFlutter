part of 'search_page.dart';

class _SearchFilterTabs extends StatelessWidget {
  const _SearchFilterTabs({
    required this.i18n,
    required this.activeFilter,
    required this.results,
    required this.onChanged,
  });

  final SmPlayerI18n i18n;
  final SearchFilterKey activeFilter;
  final SearchResults results;
  final ValueChanged<SearchFilterKey> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = <({SearchFilterKey key, String label, int count, int order})>[
      (
        key: SearchFilterKey.all,
        label: i18n.t('common.all'),
        count:
            results.artists.length +
            results.albums.length +
            results.songs.length +
            results.playlists.length +
            results.folders.length,
        order: 0,
      ),
      (
        key: SearchFilterKey.artists,
        label: i18n.t('common.artists'),
        count: results.artists.length,
        order: 1,
      ),
      (
        key: SearchFilterKey.albums,
        label: i18n.t('common.albums'),
        count: results.albums.length,
        order: 2,
      ),
      (
        key: SearchFilterKey.songs,
        label: i18n.t('common.songs'),
        count: results.songs.length,
        order: 3,
      ),
      (
        key: SearchFilterKey.playlists,
        label: i18n.t('common.playlists'),
        count: results.playlists.length,
        order: 4,
      ),
      (
        key: SearchFilterKey.folders,
        label: i18n.t('common.folders'),
        count: results.folders.length,
        order: 5,
      ),
    ];
    final orderedTabs = [
      tabs.first,
      ...tabs.skip(1).toList()..sort((left, right) {
        final leftEmpty = left.count == 0;
        final rightEmpty = right.count == 0;
        if (leftEmpty != rightEmpty) {
          return leftEmpty ? 1 : -1;
        }
        return left.order.compareTo(right.order);
      }),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 3, 0, 3),
          child: Row(
            children: [
              for (final tab in orderedTabs) ...[
                _SearchFilterTab(
                  label: tab.label,
                  count: tab.count,
                  selected: tab.key == activeFilter,
                  enabled: tab.key == SearchFilterKey.all || tab.count > 0,
                  onPressed: () {
                    onChanged(tab.key);
                  },
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchFilterTab extends StatelessWidget {
  const _SearchFilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final int count;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    final foreground =
        selected
            ? colors.appBarTabActiveText
            : enabled
            ? colors.appBarTabText
            : colors.appBarTabText.withValues(alpha: 0.46);

    return Opacity(
      opacity: enabled ? 1 : 0.46,
      child: SizedBox(
        height: 34,
        child: TextButton(
          style: _searchFilterTabButtonStyle(
            foregroundColor: foreground,
            hoverForegroundColor:
                selected
                    ? colors.appBarTabActiveText
                    : colors.appBarTabHoverText,
            backgroundColor:
                selected
                    ? colors.appBarTabActiveSurface
                    : colors.appBarTabSurface,
            hoverBackgroundColor:
                selected
                    ? colors.appBarTabActiveSurface
                    : colors.appBarTabHoverSurface,
            borderColor:
                selected
                    ? colors.appBarTabActiveBorder
                    : colors.appBarTabBorder,
            hoverBorderColor:
                selected
                    ? colors.appBarTabActiveBorder
                    : colors.appBarTabHoverBorder,
          ),
          onPressed: enabled ? onPressed : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '$count',
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

ButtonStyle _searchFilterTabButtonStyle({
  required Color foregroundColor,
  required Color hoverForegroundColor,
  required Color backgroundColor,
  required Color hoverBackgroundColor,
  required Color borderColor,
  required Color hoverBorderColor,
}) {
  const height = 34.0;
  const radius = 10.0;
  const padding = EdgeInsets.symmetric(horizontal: 12);

  Color resolveColor(Set<WidgetState> states, Color regular, Color hovered) {
    return _searchFilterTabHovered(states) ? hovered : regular;
  }

  BorderSide resolveSide(Set<WidgetState> states) {
    return BorderSide(
      color: resolveColor(states, borderColor, hoverBorderColor),
    );
  }

  RoundedRectangleBorder resolveShape(Set<WidgetState> states) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: resolveSide(states),
    );
  }

  return TextButton.styleFrom(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    minimumSize: const Size(0, height),
    maximumSize: const Size(double.infinity, height),
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
    minimumSize: const WidgetStatePropertyAll(Size(0, height)),
    maximumSize: const WidgetStatePropertyAll(Size(double.infinity, height)),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => resolveColor(states, foregroundColor, hoverForegroundColor),
    ),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => resolveColor(states, backgroundColor, hoverBackgroundColor),
    ),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    side: WidgetStateProperty.resolveWith(resolveSide),
    shape: WidgetStateProperty.resolveWith(resolveShape),
  );
}

bool _searchFilterTabHovered(Set<WidgetState> states) {
  return states.contains(WidgetState.hovered) ||
      states.contains(WidgetState.focused) ||
      states.contains(WidgetState.pressed);
}
