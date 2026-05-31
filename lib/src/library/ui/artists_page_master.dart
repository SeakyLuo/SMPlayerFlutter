part of 'artists_page.dart';

const _artistsMasterPlayerSafeBottom = 20.0;

class _CompactArtistsPage extends StatelessWidget {
  const _CompactArtistsPage({
    required this.artistSearch,
    required this.selectedArtist,
    required this.visibleArtists,
    required this.artistQuickJumpMap,
    required this.activeArtistQuickJumpKey,
    required this.scrollController,
    required this.detailScrollController,
    required this.multiSelect,
    required this.selectedSongIds,
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
    required this.onOpenArtistDetail,
    required this.onPlayArtist,
    required this.onOpenArtistMenu,
    required this.onOpenArtistDetailMenu,
    required this.onOpenAlbumMenu,
    required this.onJumpToArtistKey,
    required this.onReturnToArtistList,
    required this.onPlaySongs,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onOpenSongAddToMenu,
    required this.onToggleSongSelection,
    required this.onOpenSongContextMenu,
  });

  final String artistSearch;
  final ArtistGroup? selectedArtist;
  final List<ArtistGroup> visibleArtists;
  final Map<String, int> artistQuickJumpMap;
  final String activeArtistQuickJumpKey;
  final ScrollController scrollController;
  final ScrollController detailScrollController;
  final bool multiSelect;
  final Set<int> selectedSongIds;
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
  final ValueChanged<String> onOpenArtistDetail;
  final ValueChanged<ArtistGroup> onPlayArtist;
  final void Function(Offset position, ArtistGroup artist) onOpenArtistMenu;
  final void Function({
    required Offset position,
    required ArtistGroup artist,
    required bool showLocateArtist,
  })
  onOpenArtistDetailMenu;
  final void Function(Offset position, AlbumGroup album) onOpenAlbumMenu;
  final void Function(Map<String, int> artistQuickJumpMap, String key)
  onJumpToArtistKey;
  final VoidCallback onReturnToArtistList;
  final void Function(
    List<int> songIds, {
    String? artistName,
    String? albumName,
  })
  onPlaySongs;
  final int? selectedTrackId;
  final bool isPlaying;
  final void Function(int songId, List<int> queueSongIds) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onPlayNext;
  final void Function(int songId, bool favorite) onToggleFavorite;
  final void Function(BuildContext context, LibrarySong song)
  onOpenSongAddToMenu;
  final ValueChanged<int> onToggleSongSelection;
  final void Function(Offset position, LibrarySong song) onOpenSongContextMenu;

  @override
  Widget build(BuildContext context) {
    final navMinimal = !showSearch;
    if (selectedArtist != null) {
      return _ArtistsDetail(
        selectedArtist: selectedArtist,
        scrollController: detailScrollController,
        multiSelect: multiSelect,
        selectedSongIds: selectedSongIds,
        compact: true,
        compactHeaderInAppBar: navMinimal,
        i18n: i18n,
        onPlaySongs: onPlaySongs,
        onOpenArtistMenu: (position, artist, {required showLocateArtist}) {
          onOpenArtistDetailMenu(
            position: position,
            artist: artist,
            showLocateArtist: showLocateArtist,
          );
        },
        onOpenAlbumMenu: (position, album) {
          onOpenAlbumMenu(position, album);
        },
        selectedTrackId: selectedTrackId,
        isPlaying: isPlaying,
        onPlayTrack: onPlayTrack,
        onTogglePlayPause: onTogglePlayPause,
        onPlayNext: onPlayNext,
        onToggleFavorite: onToggleFavorite,
        onOpenSongAddToMenu: onOpenSongAddToMenu,
        onToggleSongSelection: onToggleSongSelection,
        onOpenSongContextMenu: onOpenSongContextMenu,
        hasVisibleArtists: visibleArtists.isNotEmpty,
        onReturnToArtistList: onReturnToArtistList,
      );
    }

    return Column(
      children: [
        if (showSearch)
          _ArtistsSearchBox(
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
        Expanded(
          child: Padding(
            key: const ValueKey('Artists.CompactMaster.Padding'),
            padding:
                navMinimal
                    ? const EdgeInsets.symmetric(horizontal: 12)
                    : const EdgeInsets.only(
                      bottom: _artistsMasterPlayerSafeBottom,
                    ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  children: [
                    Padding(
                      key: const ValueKey('Artists.CompactQuickJump.Padding'),
                      padding:
                          navMinimal
                              ? const EdgeInsets.only(
                                top: 2,
                                bottom: _artistsMasterPlayerSafeBottom,
                              )
                              : const EdgeInsets.only(
                                bottom: _artistsMasterPlayerSafeBottom,
                              ),
                      child: _ArtistQuickJump(
                        activeKey: activeArtistQuickJumpKey,
                        enabledKeys: artistQuickJumpMap.keys.toSet(),
                        i18n: i18n,
                        onJump: (key) {
                          onJumpToArtistKey(artistQuickJumpMap, key);
                        },
                      ),
                    ),
                    SizedBox(width: navMinimal ? 2 : 4),
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (visibleArtists.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _ArtistsEmptyState(
                                title: i18n.t('collection.noArtists'),
                                message: i18n.t('artists.emptyCopy'),
                              ),
                            )
                          else ...[
                            Positioned.fill(
                              right: 0,
                              child: ListView.builder(
                                key: const ValueKey(
                                  'Artists.CompactMaster.List',
                                ),
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
                                    active: false,
                                    i18n: i18n,
                                    compactNavMinimal: navMinimal,
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
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtistsMaster extends StatelessWidget {
  const _ArtistsMaster({
    required this.artistSearch,
    required this.visibleArtists,
    required this.selectedArtistName,
    required this.artistQuickJumpMap,
    required this.activeArtistQuickJumpKey,
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
    required this.onOpenArtistDetail,
    required this.onPlayArtist,
    required this.onOpenArtistMenu,
    required this.onJumpToArtistKey,
  });

  final String artistSearch;
  final List<ArtistGroup> visibleArtists;
  final String selectedArtistName;
  final Map<String, int> artistQuickJumpMap;
  final String activeArtistQuickJumpKey;
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
                _ArtistsSearchBox(
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

class _ArtistQuickJump extends StatelessWidget {
  const _ArtistQuickJump({
    required this.activeKey,
    required this.enabledKeys,
    required this.i18n,
    required this.onJump,
  });

  final String activeKey;
  final Set<String> enabledKeys;
  final SmPlayerI18n i18n;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      width: 22,
      child: Column(
        children:
            artistQuickJumpKeys.map((key) {
              final enabled = enabledKeys.contains(key);
              final active = activeKey == key;
              return Expanded(
                child: Opacity(
                  key: ValueKey('Artists.QuickJump.Opacity.$key'),
                  opacity: enabled ? 1 : 0.62,
                  child: Tooltip(
                    message: getQuickJumpTooltip(
                      key: key,
                      enabled: enabled,
                      targetName: i18n.t('common.artists'),
                      basisName: i18n.t('common.artist'),
                      i18n: i18n,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 20,
                        height: double.infinity,
                        child: TextButton(
                          key: ValueKey('Artists.QuickJump.$key'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(20, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ).copyWith(
                            foregroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (!enabled ||
                                  states.contains(WidgetState.disabled)) {
                                return _ArtistsColors.quickJumpDisabled(
                                  brightness,
                                );
                              }
                              if (active ||
                                  states.contains(WidgetState.hovered)) {
                                return _ArtistsColors.quickJumpActiveForeground(
                                  brightness,
                                );
                              }
                              return _ArtistsColors.quickJumpForeground(
                                brightness,
                              );
                            }),
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (!enabled ||
                                  states.contains(WidgetState.disabled)) {
                                return Colors.transparent;
                              }
                              if (active ||
                                  states.contains(WidgetState.hovered)) {
                                return _ArtistsColors.quickJumpActiveBackground(
                                  brightness,
                                );
                              }
                              return Colors.transparent;
                            }),
                          ),
                          onPressed:
                              enabled
                                  ? () {
                                    onJump(key);
                                  }
                                  : null,
                          child: Text(
                            key,
                            style: const TextStyle(
                              fontSize: 10,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              fontVariations: [FontVariation.weight(650)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}
