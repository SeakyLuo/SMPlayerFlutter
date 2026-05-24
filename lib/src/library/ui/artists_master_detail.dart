part of 'artists_page.dart';

class _ArtistsMasterDetail extends StatelessWidget {
  const _ArtistsMasterDetail({
    required this.compact,
    required this.artistSearch,
    required this.compactSelectedArtist,
    required this.wideSelectedArtist,
    required this.visibleArtists,
    required this.artistQuickJumpMap,
    required this.activeArtistQuickJumpKey,
    required this.artistListController,
    required this.artistDetailController,
    required this.multiSelect,
    required this.selectedSongIds,
    required this.i18n,
    required this.showSearch,
    required this.searchFocused,
    required this.searchSuggestions,
    required this.searchHistoryEntries,
    required this.selectedArtistSongIds,
    required this.customPlaylists,
    required this.selectedTrackId,
    required this.isPlaying,
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
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onOpenSongAddToMenu,
    required this.onToggleSongSelection,
    required this.onOpenSongContextMenu,
  });

  final bool compact;
  final String artistSearch;
  final ArtistGroup? compactSelectedArtist;
  final ArtistGroup? wideSelectedArtist;
  final List<ArtistGroup> visibleArtists;
  final Map<String, int> artistQuickJumpMap;
  final String activeArtistQuickJumpKey;
  final ScrollController artistListController;
  final ScrollController artistDetailController;
  final bool multiSelect;
  final Set<int> selectedSongIds;
  final SmPlayerI18n i18n;
  final bool showSearch;
  final bool searchFocused;
  final List<String> searchSuggestions;
  final List<SearchHistoryEntry> searchHistoryEntries;
  final List<int> selectedArtistSongIds;
  final List<MultiSelectCommandBarPlaylist> customPlaylists;
  final int? selectedTrackId;
  final bool isPlaying;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onSearchFocusChanged;
  final VoidCallback onSearchSubmitted;
  final ValueChanged<String> onSelectSearchSuggestion;
  final ValueChanged<int> onRemoveRecentSearch;
  final VoidCallback onClearRecentSearches;
  final ValueChanged<String> onOpenArtistDetail;
  final ValueChanged<ArtistGroup> onPlayArtist;
  final void Function({required Offset position, required ArtistGroup artist})
  onOpenArtistMenu;
  final void Function({
    required Offset position,
    required ArtistGroup artist,
    required bool showLocateArtist,
  })
  onOpenArtistDetailMenu;
  final void Function({required Offset position, required AlbumGroup album})
  onOpenAlbumMenu;
  final void Function(Map<String, int> artistQuickJumpMap, String key)
  onJumpToArtistKey;
  final VoidCallback onReturnToArtistList;
  final void Function(
    List<int> songIds, {
    String? albumName,
    String? artistName,
  })
  onPlaySongs;
  final void Function(int songId, List<int> queueSongIds) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onPlayNext;
  final void Function(int songId, bool favorite) onToggleFavorite;
  final void Function(BuildContext buttonContext, LibrarySong song)
  onOpenSongAddToMenu;
  final ValueChanged<int> onToggleSongSelection;
  final void Function(Offset position, LibrarySong song) onOpenSongContextMenu;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactArtistsPage(
        artistSearch: artistSearch,
        selectedArtist: compactSelectedArtist,
        visibleArtists: visibleArtists,
        artistQuickJumpMap: artistQuickJumpMap,
        activeArtistQuickJumpKey: activeArtistQuickJumpKey,
        scrollController: artistListController,
        multiSelect: multiSelect,
        selectedSongIds: selectedSongIds,
        i18n: i18n,
        showSearch: showSearch,
        searchFocused: searchFocused,
        searchSuggestions: searchSuggestions,
        searchHistoryEntries: searchHistoryEntries,
        onSearchChanged: onSearchChanged,
        onSearchFocusChanged: onSearchFocusChanged,
        onSearchSubmitted: onSearchSubmitted,
        onSelectSearchSuggestion: onSelectSearchSuggestion,
        onRemoveRecentSearch: onRemoveRecentSearch,
        onClearRecentSearches: onClearRecentSearches,
        onOpenArtistDetail: onOpenArtistDetail,
        onPlayArtist: onPlayArtist,
        onOpenArtistMenu: (position, artist) {
          onOpenArtistMenu(position: position, artist: artist);
        },
        onOpenAlbumMenu: (position, album) {
          onOpenAlbumMenu(position: position, album: album);
        },
        onJumpToArtistKey: onJumpToArtistKey,
        onReturnToArtistList: onReturnToArtistList,
        onPlaySongs: onPlaySongs,
        selectedTrackId: selectedTrackId,
        isPlaying: isPlaying,
        onPlayTrack: onPlayTrack,
        onTogglePlayPause: onTogglePlayPause,
        onPlayNext: onPlayNext,
        onToggleFavorite: onToggleFavorite,
        onOpenSongAddToMenu: onOpenSongAddToMenu,
        onToggleSongSelection: onToggleSongSelection,
        onOpenSongContextMenu: onOpenSongContextMenu,
      );
    }

    return Row(
      children: [
        _ArtistsMaster(
          artistSearch: artistSearch,
          visibleArtists: visibleArtists,
          selectedArtistName: wideSelectedArtist?.name ?? '',
          artistQuickJumpMap: artistQuickJumpMap,
          activeArtistQuickJumpKey: activeArtistQuickJumpKey,
          scrollController: artistListController,
          i18n: i18n,
          showSearch: showSearch,
          searchFocused: searchFocused,
          searchSuggestions: searchSuggestions,
          searchHistoryEntries: searchHistoryEntries,
          onSearchChanged: onSearchChanged,
          onSearchFocusChanged: onSearchFocusChanged,
          onSearchSubmitted: onSearchSubmitted,
          onSelectSearchSuggestion: onSelectSearchSuggestion,
          onRemoveRecentSearch: onRemoveRecentSearch,
          onClearRecentSearches: onClearRecentSearches,
          onOpenArtistDetail: onOpenArtistDetail,
          onPlayArtist: onPlayArtist,
          onOpenArtistMenu: (position, artist) {
            onOpenArtistMenu(position: position, artist: artist);
          },
          onJumpToArtistKey: onJumpToArtistKey,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ArtistsDetail(
            selectedArtist: wideSelectedArtist,
            scrollController: artistDetailController,
            multiSelect: multiSelect,
            selectedSongIds: selectedSongIds,
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
              onOpenAlbumMenu(position: position, album: album);
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
          ),
        ),
      ],
    );
  }
}
