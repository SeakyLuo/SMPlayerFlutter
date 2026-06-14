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
    final brightness = Theme.of(context).brightness;
    final navMinimal = !showSearch;
    return SizedBox(
      width: 300,
      child: DecoratedBox(
        key: const ValueKey('Artists.LoadingMasterPanel'),
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
          key: const ValueKey('Artists.LoadingMasterPanel.Padding'),
          padding:
              navMinimal
                  ? const EdgeInsets.fromLTRB(14, 8, 14, 26)
                  : const EdgeInsets.fromLTRB(14, 16, 14, 8),
          child: Column(
            children: [
              if (showSearch)
                _ArtistsSearchBox(
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
              const SizedBox(height: 8),
              _ArtistsProgress(
                key: const ValueKey('Artists.Progress'),
                label: i18n.t('nowPlaying.loading'),
              ),
              SizedBox(height: showSearch ? 14 : 0),
              Expanded(
                child: Row(
                  key: const ValueKey('Artists.LoadingMaster.ListShell'),
                  children: [
                    _ArtistQuickJump(
                      activeKey: '',
                      keys: artistQuickJumpKeys,
                      enabledKeys: const {},
                      i18n: i18n,
                      onJump: (_) {},
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            right: 12,
                            child: ListView(
                              key: const ValueKey('Artists.LoadingMaster.List'),
                              controller: scrollController,
                              clipBehavior: Clip.none,
                              padding: EdgeInsets.zero,
                              children: const [],
                            ),
                          ),
                          _ArtistsCustomScrollbar(
                            key: const ValueKey(
                              'Artists.LoadingMasterScrollbar',
                            ),
                            positionKey: const ValueKey(
                              'Artists.LoadingMasterScrollbar.Position',
                            ),
                            thumbKey: const ValueKey(
                              'Artists.LoadingMasterScrollbar.Thumb',
                            ),
                            controller: scrollController,
                            right: 0,
                          ),
                        ],
                      ),
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
