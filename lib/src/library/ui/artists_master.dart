part of 'artists_page.dart';

class _ArtistsMaster extends StatelessWidget {
  const _ArtistsMaster({
    required this.artistSearch,
    required this.visibleArtists,
    required this.sortCriterion,
    required this.artistQuickJumpKeys,
    required this.selectedArtistName,
    required this.artistQuickJumpMap,
    required this.activeArtistQuickJumpKey,
    required this.locatedArtistName,
    required this.locateArtistPulse,
    required this.scrollController,
    required this.i18n,
    required this.showSearch,
    required this.searchFocused,
    required this.searchSuggestions,
    required this.searchHistoryEntries,
    required this.onSearchChanged,
    required this.onSearchFocusChanged,
    required this.onSearchSubmitted,
    required this.onSelectSearchSuggestion,
    required this.onRemoveRecentSearch,
    required this.onClearRecentSearches,
    required this.onChangeArtistSort,
    required this.onOpenArtistDetail,
    required this.onPlayArtist,
    required this.onOpenArtistMenu,
    required this.onJumpToArtistKey,
  });

  final String artistSearch;
  final List<ArtistGroup> visibleArtists;
  final ArtistSortCriterion sortCriterion;
  final List<String> artistQuickJumpKeys;
  final String selectedArtistName;
  final Map<String, int> artistQuickJumpMap;
  final String activeArtistQuickJumpKey;
  final String? locatedArtistName;
  final int locateArtistPulse;
  final ScrollController scrollController;
  final SmPlayerI18n i18n;
  final bool showSearch;
  final bool searchFocused;
  final List<String> searchSuggestions;
  final List<SearchHistoryEntry> searchHistoryEntries;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onSearchFocusChanged;
  final VoidCallback onSearchSubmitted;
  final ValueChanged<String> onSelectSearchSuggestion;
  final ValueChanged<int> onRemoveRecentSearch;
  final VoidCallback onClearRecentSearches;
  final ValueChanged<ArtistSortCriterion> onChangeArtistSort;
  final ValueChanged<String> onOpenArtistDetail;
  final ValueChanged<ArtistGroup> onPlayArtist;
  final void Function(Offset position, ArtistGroup artist) onOpenArtistMenu;
  final void Function(Map<String, int> artistQuickJumpMap, String key)
  onJumpToArtistKey;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final navMinimal = !showSearch;
    return SizedBox(
      width: 300,
      child: DecoratedBox(
        key: const ValueKey('Artists.MasterPanel'),
        decoration: BoxDecoration(
          color:
              navMinimal
                  ? Colors.transparent
                  : _ArtistsColors.masterBackground(brightness),
          border:
              navMinimal
                  ? null
                  : Border(
                    right: BorderSide(
                      color: _ArtistsColors.masterBorder(brightness),
                    ),
                  ),
        ),
        child: Padding(
          key: const ValueKey('Artists.MasterPanel.Padding'),
          padding:
              navMinimal
                  ? const EdgeInsets.fromLTRB(14, 8, 14, 26)
                  : const EdgeInsets.fromLTRB(
                    14,
                    16,
                    14,
                    8 + _artistsMasterPlayerSafeBottom,
                  ),
          child: Column(
            children: [
              if (showSearch) ...[
                Row(
                  children: [
                    Expanded(
                      child: _ArtistsSearchBox(
                        artistSearch: artistSearch,
                        i18n: i18n,
                        searchFocused: searchFocused,
                        searchSuggestions: searchSuggestions,
                        searchHistoryEntries: searchHistoryEntries,
                        onChanged: onSearchChanged,
                        onFocusChanged: onSearchFocusChanged,
                        onSubmitted: onSearchSubmitted,
                        onSelectSearchSuggestion: onSelectSearchSuggestion,
                        onRemoveRecentSearch: onRemoveRecentSearch,
                        onClearRecentSearches: onClearRecentSearches,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ArtistsSortButton(
                      i18n: i18n,
                      sortCriterion: sortCriterion,
                      onChangeArtistSort: onChangeArtistSort,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      children: [
                        _ArtistQuickJump(
                          activeKey: activeArtistQuickJumpKey,
                          keys: artistQuickJumpKeys,
                          enabledKeys: artistQuickJumpMap.keys.toSet(),
                          i18n: i18n,
                          onJump: (key) {
                            onJumpToArtistKey(artistQuickJumpMap, key);
                          },
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                right: 0,
                                child: ListView.builder(
                                  key: const ValueKey('Artists.Master.List'),
                                  controller: scrollController,
                                  itemExtent: artistRowHeight,
                                  clipBehavior: Clip.none,
                                  scrollCacheExtent: ScrollCacheExtent.pixels(
                                    artistRowHeight * artistOverscanRows,
                                  ),
                                  padding: const EdgeInsets.only(
                                    bottom: _artistsMasterPlayerSafeBottom,
                                  ),
                                  itemCount: visibleArtists.length,
                                  itemBuilder: (context, index) {
                                    final artist = visibleArtists[index];
                                    return _ArtistListItem(
                                      artist: artist,
                                      active: artist.name == selectedArtistName,
                                      i18n: i18n,
                                      locateHighlighted:
                                          artist.name == locatedArtistName,
                                      locatePulse: locateArtistPulse,
                                      onPressed: () {
                                        onOpenArtistDetail(artist.name);
                                      },
                                      onPlay: () {
                                        onPlayArtist(artist);
                                      },
                                      onOpenContextMenu: (position) {
                                        onOpenArtistMenu(position, artist);
                                      },
                                    );
                                  },
                                ),
                              ),
                              _ArtistsCustomScrollbar(
                                key: const ValueKey('Artists.MasterScrollbar'),
                                positionKey: const ValueKey(
                                  'Artists.MasterScrollbar.Position',
                                ),
                                thumbKey: const ValueKey(
                                  'Artists.MasterScrollbar.Thumb',
                                ),
                                controller: scrollController,
                                right: 0,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistsSortButton extends StatelessWidget {
  const _ArtistsSortButton({
    required this.i18n,
    required this.sortCriterion,
    required this.onChangeArtistSort,
  });

  final SmPlayerI18n i18n;
  final ArtistSortCriterion sortCriterion;
  final ValueChanged<ArtistSortCriterion> onChangeArtistSort;

  @override
  Widget build(BuildContext context) {
    final sortItems = artistSortMenuItems(
      i18n,
      sortCriterion,
      onChangeArtistSort,
    );
    return CommandBarButton(
      key: const ValueKey('Artists.SortButton'),
      icon: FluentIcons.arrow_sort_24_regular,
      label: artistSortLabel(i18n, sortCriterion),
      showLabel: false,
      canOverflow: false,
      onPressedWithContext: (buttonContext) {
        showMenuFlyout(buttonContext, items: sortItems);
      },
    );
  }
}
