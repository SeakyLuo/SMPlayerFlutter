part of 'page_search_history_panel.dart';

class PageSearchHistoryPanel extends StatelessWidget {
  const PageSearchHistoryPanel({
    super.key,
    required this.entries,
    required this.i18n,
    required this.onSelect,
    required this.onRemove,
    required this.onClear,
  });

  final List<SearchHistoryEntry> entries;
  final SmPlayerI18n i18n;
  final ValueChanged<String> onSelect;
  final ValueChanged<int> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SearchHistoryPanel<SearchHistoryEntry>(
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
        onSelect(item.value.query);
      },
      onRemove: (item) {
        onRemove(item.value.id);
      },
      getRemoveLabel:
          (item) =>
              i18n.t('sidebar.removeRecentSearch', {'query': item.value.query}),
    );
  }
}

class PageSearchSuggestionPanel extends StatelessWidget {
  const PageSearchSuggestionPanel({
    super.key,
    required this.labels,
    required this.onSelect,
  });

  final List<String> labels;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SearchHistoryPanel<String>(
      title: '',
      items: [
        for (final label in labels)
          SearchHistoryPanelItem(key: label, label: label, value: label),
      ],
      onSelect: (item) {
        onSelect(item.value);
      },
    );
  }
}
