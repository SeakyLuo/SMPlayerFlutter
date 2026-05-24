part of 'recent_page.dart';

class _RecentSearchesPage extends ConsumerWidget {
  const _RecentSearchesPage({
    required this.entries,
    required this.i18n,
    required this.multiSelect,
    required this.selectedEntryIds,
    required this.routeForSearchHistory,
    required this.onToggleMultiSelect,
    required this.onClearSelection,
    required this.onToggleSelection,
    required this.onRemove,
  });

  final List<SearchHistoryEntry> entries;
  final SmPlayerI18n i18n;
  final bool multiSelect;
  final Set<int> selectedEntryIds;
  final String Function(SearchHistoryEntry entry) routeForSearchHistory;
  final VoidCallback onToggleMultiSelect;
  final VoidCallback onClearSelection;
  final ValueChanged<int> onToggleSelection;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      spacing: 4,
      children: [
        CommandBar(
          overflowLabel: i18n.t('player.more'),
          content: const _RecentCommandBarTimelineLabel(label: ''),
          children: [
            CommandBarButton(
              icon: FluentIcons.multiselect_ltr_20_regular,
              label: i18n.t('albums.multiSelect'),
              active: multiSelect,
              disabled: entries.isEmpty,
              onPressed: onToggleMultiSelect,
            ),
            CommandBarButton(
              icon: FluentIcons.dismiss_20_regular,
              label: i18n.t('recent.clearHistory'),
              disabled: entries.isEmpty,
              onPressed: () {
                unawaited(_confirmClearHistory(context, ref));
              },
            ),
          ],
        ),
        Expanded(
          child: RecentSearchList(
            entries: entries,
            i18n: i18n,
            multiSelect: multiSelect,
            selectedEntryIds: selectedEntryIds,
            onSearch: (entry) {
              context.go(routeForSearchHistory(entry));
            },
            onToggleSelection: onToggleSelection,
            onRemove: onRemove,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showPopupConfirmDialog(
      context: context,
      title: i18n.t('common.confirm'),
      message: i18n.t('recent.clearSearchesConfirm'),
      confirmLabel: i18n.t('common.confirm'),
      destructive: false,
    );
    if (!confirmed) {
      return;
    }
    await ref.read(libraryRepositoryProvider).clearRecentSearches();
    invalidateRecentSearchData(ref);
    onClearSelection();
  }
}
