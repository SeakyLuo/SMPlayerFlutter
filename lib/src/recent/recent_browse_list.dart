part of 'recent_page.dart';

class _RecentBrowseList extends StatelessWidget {
  const _RecentBrowseList({
    required this.entries,
    required this.i18n,
    required this.multiSelect,
    required this.selectedEntryIds,
    required this.onOpen,
    required this.onToggleSelection,
    required this.onRemove,
  });

  final List<RecentBrowseView> entries;
  final SmPlayerI18n i18n;
  final bool multiSelect;
  final Set<int> selectedEntryIds;
  final ValueChanged<RecentBrowseView> onOpen;
  final ValueChanged<int> onToggleSelection;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final entriesById = {for (final view in entries) view.entry.id: view};
    return RecentSearchList(
      entries: [
        for (final view in entries)
          SearchHistoryEntry(
            id: view.entry.id,
            query: view.title,
            type: _searchTypeForBrowse(view.entry.type),
            searchedAt: view.entry.browsedAt,
          ),
      ],
      i18n: i18n,
      multiSelect: multiSelect,
      selectedEntryIds: selectedEntryIds,
      onSearch: (entry) {
        onOpen(entriesById[entry.id]!);
      },
      onToggleSelection: onToggleSelection,
      onRemove: onRemove,
      removeTooltip:
          (entry) => i18n.t('recent.removeBrowse', {'name': entry.query}),
      typeTooltip: (entry) => i18n.t(_browseTypeLabelKey(entry.type)),
    );
  }
}

String _browseTypeLabelKey(SearchHistoryType type) {
  return switch (type) {
    SearchHistoryType.songs => 'common.songs',
    SearchHistoryType.artists => 'common.artists',
    SearchHistoryType.albums => 'common.albums',
    SearchHistoryType.playlists => 'common.playlists',
    SearchHistoryType.sidebar || SearchHistoryType.folders => 'common.songs',
  };
}

SearchHistoryType _searchTypeForBrowse(RecentBrowseType type) {
  return switch (type) {
    RecentBrowseType.song => SearchHistoryType.songs,
    RecentBrowseType.artist => SearchHistoryType.artists,
    RecentBrowseType.album => SearchHistoryType.albums,
    RecentBrowseType.playlist => SearchHistoryType.playlists,
  };
}
