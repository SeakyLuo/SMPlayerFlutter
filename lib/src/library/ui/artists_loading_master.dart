part of 'artists_page.dart';

class _ArtistsLoadingMaster extends StatelessWidget {
  const _ArtistsLoadingMaster({
    required this.showSearch,
    required this.artistSearch,
    required this.scrollController,
    required this.i18n,
    required this.searchFocused,
    required this.onChanged,
    required this.onFocusChanged,
    required this.onSubmitted,
  });

  final bool showSearch;
  final String artistSearch;
  final ScrollController scrollController;
  final SmPlayerI18n i18n;
  final bool searchFocused;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onFocusChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: _ArtistsSearchBox(
              artistSearch: artistSearch,
              i18n: i18n,
              searchFocused: searchFocused,
              searchSuggestions: const [],
              searchHistoryEntries: const [],
              onChanged: onChanged,
              onFocusChanged: onFocusChanged,
              onSubmitted: onSubmitted,
              onSelectSearchSuggestion: onChanged,
              onRemoveRecentSearch: (_) {},
              onClearRecentSearches: () {},
            ),
          ),
        const Expanded(child: SmPlayerLoadingState()),
      ],
    );
  }
}
