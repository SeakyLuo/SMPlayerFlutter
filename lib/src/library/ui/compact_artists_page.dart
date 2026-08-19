part of 'artists_page.dart';

class _CompactArtistsPage extends StatelessWidget {
  const _CompactArtistsPage({
    required this.artistSearch,
    required this.selectedArtist,
    required this.visibleArtists,
    required this.sortCriterion,
    required this.artistQuickJumpKeys,
    required this.artistQuickJumpMap,
    required this.activeArtistQuickJumpKey,
    required this.locatedArtistName,
    required this.locateArtistPulse,
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
    required this.onChangeArtistSort,
    required this.onOpenArtistDetail,
    required this.onPlayArtist,
    required this.onOpenArtistMenu,
    required this.onOpenArtistDetailMenu,
    required this.onOpenAlbumMenu,
    required this.onJumpToArtistKey,
    required this.onPlaySongs,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.onPlayTrack,
    required this.onPlaySong,
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
  final ArtistSortCriterion sortCriterion;
  final List<String> artistQuickJumpKeys;
  final Map<String, int> artistQuickJumpMap;
  final String activeArtistQuickJumpKey;
  final String? locatedArtistName;
  final int locateArtistPulse;
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
  final ValueChanged<ArtistSortCriterion> onChangeArtistSort;
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
  final void Function(
    List<int> songIds, {
    String? artistName,
    String? albumName,
  })
  onPlaySongs;
  final int? selectedTrackId;
  final bool isPlaying;
  final void Function(int songId, List<int> queueSongIds) onPlayTrack;
  final ValueChanged<int> onPlaySong;
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
        onPlaySong: onPlaySong,
        onTogglePlayPause: onTogglePlayPause,
        onPlayNext: onPlayNext,
        onToggleFavorite: onToggleFavorite,
        onOpenSongAddToMenu: onOpenSongAddToMenu,
        onToggleSongSelection: onToggleSongSelection,
        onOpenSongContextMenu: onOpenSongContextMenu,
        hasVisibleArtists: visibleArtists.isNotEmpty,
      );
    }

    return Column(
      children: [
        if (showSearch)
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
                        keys: artistQuickJumpKeys,
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
                              child: ScrollConfiguration(
                                key: const ValueKey(
                                  'Artists.CompactMasterScrollConfiguration',
                                ),
                                behavior: ScrollConfiguration.of(
                                  context,
                                ).copyWith(scrollbars: false),
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
                                      locateHighlighted:
                                          artist.name == locatedArtistName,
                                      locatePulse: locateArtistPulse,
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
