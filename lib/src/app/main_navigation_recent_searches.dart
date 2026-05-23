part of 'main_navigation_view.dart';

class _MainNavigationRecentSearches extends StatelessWidget {
  const _MainNavigationRecentSearches({
    required this.entries,
    required this.i18n,
    required this.onSearchSelected,
    required this.onSearchRemoved,
    required this.onClear,
  });

  final List<SearchHistoryEntry> entries;
  final SmPlayerI18n i18n;
  final ValueChanged<SearchHistoryEntry> onSearchSelected;
  final ValueChanged<int>? onSearchRemoved;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.dropdownSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.searchBorder),
          boxShadow: [
            BoxShadow(
              color: colors.dropdownShadow,
              blurRadius: 36,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        i18n.t('sidebar.recentSearches'),
                        style: TextStyle(
                          color: colors.sectionLabel,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: onClear,
                      child: Text(i18n.t('common.clear')),
                    ),
                  ],
                ),
              ),
              ...entries.map(
                (entry) => _MainNavigationRecentSearchItem(
                  entry: entry,
                  removeLabel: i18n.t('sidebar.removeRecentSearch', {
                    'query': entry.query,
                  }),
                  onPressed: () {
                    onSearchSelected(entry);
                  },
                  onRemove:
                      onSearchRemoved == null
                          ? null
                          : () {
                            onSearchRemoved!(entry.id);
                          },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainNavigationRecentSearchItem extends StatelessWidget {
  const _MainNavigationRecentSearchItem({
    required this.entry,
    required this.removeLabel,
    required this.onPressed,
    required this.onRemove,
  });

  final SearchHistoryEntry entry;
  final String removeLabel;
  final VoidCallback onPressed;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    return SizedBox(
      height: 38,
      child: _HoverContainer(
        borderRadius: BorderRadius.circular(10),
        builder: (context, hovered) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: hovered ? colors.accentHover : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      foregroundColor: colors.textStrong,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(FluentIcons.search_20_regular, size: 16),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        entry.query,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onPressed: onPressed,
                  ),
                ),
                IconButton(
                  tooltip: removeLabel,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 30,
                  ),
                  icon: const Icon(FluentIcons.dismiss_16_regular, size: 14),
                  color: colors.textMuted,
                  onPressed: onRemove,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
