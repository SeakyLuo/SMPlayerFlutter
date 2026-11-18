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
    required this.sortCriterion,
    required this.onChangeArtistSort,
  });

  final bool showSearch;
  final String artistSearch;
  final ScrollController scrollController;
  final SmPlayerI18n i18n;
  final bool searchFocused;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onFocusChanged;
  final VoidCallback onSubmitted;
  final ArtistSortCriterion sortCriterion;
  final ValueChanged<ArtistSortCriterion> onChangeArtistSort;

  @override
  Widget build(BuildContext context) {
    return _ArtistsMasterFrame(
      showSearch: showSearch,
      fixedWidth: false,
      child: Column(
        children: [
          if (showSearch)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
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
                trailing: _ArtistsSortButton(
                  i18n: i18n,
                  sortCriterion: sortCriterion,
                  onChangeArtistSort: onChangeArtistSort,
                ),
              ),
            ),
          Expanded(
            child: Row(
              children: [
                const SizedBox(width: 24),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: (MediaQuery.sizeOf(context).height /
                            artistRowHeight)
                        .ceil()
                        .clamp(1, 40),
                    itemExtent: artistRowHeight,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder:
                        (context, index) => Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: showSearch ? 9 : 8,
                            vertical: 9,
                          ),
                          child: Row(
                            children: [
                              const SmPlayerSkeletonBlock(
                                width: 48,
                                height: 48,
                                radius: 8,
                              ),
                              SizedBox(width: showSearch ? 12 : 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FractionallySizedBox(
                                      widthFactor: index.isEven ? .75 : .55,
                                      child: const SmPlayerSkeletonBlock(
                                        height: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const SmPlayerSkeletonBlock(
                                      width: 80,
                                      height: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistsMasterFrame extends StatelessWidget {
  const _ArtistsMasterFrame({
    required this.showSearch,
    required this.child,
    this.fixedWidth = true,
  });
  final bool fixedWidth;
  final bool showSearch;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      width: fixedWidth ? 300 : null,
      child: DecoratedBox(
        key: const ValueKey('Artists.MasterPanel'),
        decoration: BoxDecoration(
          color:
              showSearch
                  ? _ArtistsColors.masterBackground(brightness)
                  : Colors.transparent,
          border:
              showSearch
                  ? Border(
                    right: BorderSide(
                      color: _ArtistsColors.masterBorder(brightness),
                    ),
                  )
                  : null,
        ),
        child: Padding(
          key: const ValueKey('Artists.MasterPanel.Padding'),
          padding:
              showSearch
                  ? const EdgeInsets.fromLTRB(
                    14,
                    16,
                    14,
                    8 + _artistsMasterPlayerSafeBottom,
                  )
                  : const EdgeInsets.fromLTRB(14, 8, 14, 26),
          child: child,
        ),
      ),
    );
  }
}
