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
    return SearchHistoryPanel<SearchHistoryEntry>(
      backdropKey: const ValueKey('MainNavigationView.SearchHistoryBackdrop'),
      panelKey: const ValueKey('MainNavigationView.SearchHistoryPanel'),
      headerKey: const ValueKey('MainNavigationView.SearchHistoryHeader'),
      listKey: const ValueKey('MainNavigationView.SearchHistoryList'),
      title: i18n.t('sidebar.recentSearches'),
      clearLabel: i18n.t('common.clear'),
      items: [
        for (final entry in entries)
          SearchHistoryPanelItem(
            key: entry.id.toString(),
            label: entry.query,
            value: entry,
          ),
      ],
      onClear: onClear,
      onSelect: (item) {
        onSearchSelected(item.value);
      },
      onRemove:
          onSearchRemoved == null
              ? null
              : (item) {
                onSearchRemoved!(item.value.id);
              },
      getRemoveLabel:
          (item) =>
              i18n.t('sidebar.removeRecentSearch', {'query': item.value.query}),
      itemKeyBuilder:
          (item) =>
              ValueKey('MainNavigationView.SearchHistoryItem.${item.key}'),
      selectKeyBuilder:
          (item) =>
              ValueKey('MainNavigationView.SearchHistorySelect.${item.key}'),
      removeKeyBuilder:
          (item) =>
              ValueKey('MainNavigationView.SearchHistoryRemove.${item.key}'),
    );
  }
}
