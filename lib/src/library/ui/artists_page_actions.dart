part of 'artists_page.dart';

extension _ArtistsPageActions on _ArtistsPageState {
  void _changeArtistSort(ArtistSortCriterion criterion) {
    _updateArtistsPageState(() {
      if (criterion == ArtistSortCriterion.reverse) {
        _reverseArtistDisplayOrder = !_reverseArtistDisplayOrder;
      } else {
        _reverseArtistDisplayOrder = false;
        _artistSortCriterion = criterion;
      }
      _artistQuickJumpPinnedKey = null;
    });
    if (_artistListController.hasClients) {
      _artistListController.jumpTo(0);
    }
  }

  void _recordLoadingArtistSearch() {
    _recordLoadingArtistSearchForArtistsPage(this);
  }

  void _selectArtistSearchQuery(String query) {
    FocusManager.instance.primaryFocus?.unfocus();
    _updateArtistsPageState(() {
      _artistSearch = query;
      _artistSearchFocused = false;
    });
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final i18n = ref.read(smPlayerI18nProvider).valueOrNull!;
    final artistGroups = _readArtistGroups(snapshot, i18n);
    final exactMatches =
        artistGroups.where((artist) => artist.name == query).toList();
    final suggestions = searchArtists(artistGroups, query);
    final targetArtist =
        exactMatches.isNotEmpty
            ? exactMatches.first
            : (suggestions.isEmpty ? null : suggestions.first);
    if (targetArtist != null) {
      _openArtistDetail(targetArtist.name);
    }
  }

  void _changeArtistSearchFocus(bool focused) {
    _changeArtistSearchFocusForArtistsPage(this, focused);
  }

  void _removeArtistRecentSearch(int entryId) {
    _removeArtistRecentSearchForArtistsPage(this, entryId);
  }

  void _clearArtistRecentSearches() {
    _clearArtistRecentSearchesForArtistsPage(this);
  }

  void _jumpToArtistKey(Map<String, int> artistQuickJumpMap, String key) {
    _jumpToArtistKeyForArtistsPage(this, artistQuickJumpMap, key);
  }

  void _scrollToArtist(String artistName) {
    _scrollToArtistForArtistsPage(this, artistName);
  }

  void _locateArtist(String artistName) {
    _locateArtistForArtistsPage(this, artistName);
  }

  void _handleArtistListScroll() {
    _handleArtistListScrollForArtistsPage(this);
  }

  String _getActiveArtistQuickJumpKey(
    List<ArtistGroup> visibleArtists,
    ArtistSortCriterion sortCriterion,
  ) {
    return _getActiveArtistQuickJumpKeyForArtistsPage(
      this,
      visibleArtists,
      sortCriterion,
    );
  }

  void _toggleSongSelection(int songId) {
    _updateArtistsPageState(() {
      _selection.toggle(songId);
    });
  }

  void _playSongIds(List<int> songIds) {
    _playSongIdsForArtistsPage(this, songIds);
  }

  void _playTrackInQueue(int songId, List<int> queueSongIds) {
    _playTrackInQueueForArtistsPage(this, songId, queueSongIds);
  }

  void _playNext(int songId) {
    _playNextForArtistsPage(this, songId);
  }

  void _moveToMusicOrPlay(int songId) {
    _moveToMusicOrPlayForArtistsPage(this, songId);
  }

  void _playShuffledSongIds(
    List<int> songIds, {
    String? artistName,
    String? albumName,
  }) {
    _playShuffledSongIdsForArtistsPage(
      this,
      songIds,
      artistName: artistName,
      albumName: albumName,
    );
  }

  Future<void> _showGroupContextMenu({
    required Offset position,
    required _ArtistGroupMenuType type,
    required String label,
    required List<LibrarySong> songs,
    bool showLocateArtist = false,
  }) {
    return _showGroupContextMenuForArtistsPage(
      this,
      position: position,
      type: type,
      label: label,
      songs: songs,
      showLocateArtist: showLocateArtist,
    );
  }

  MenuFlyoutItem _buildGroupPreferenceMenuItem(
    SmPlayerI18n i18n,
    _ArtistGroupMenuType type,
    String label,
    String? preferenceLevel,
  ) {
    return _buildGroupPreferenceMenuItemForArtistsPage(
      this,
      i18n,
      type,
      label,
      preferenceLevel,
    );
  }

  Future<void> _showSongContextMenu(
    Offset position,
    LibrarySong song,
    List<int> queueSongIds,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) {
    return _showSongContextMenuForArtistsPage(
      this,
      position,
      song,
      queueSongIds,
      playlists,
    );
  }

  void _openMusicDialog(
    LibrarySong song,
    SongDialogMode mode,
    List<int> queueSongIds,
  ) {
    _updateArtistsPageState(() {
      _musicDialog = (song: song, mode: mode, queueSongIds: queueSongIds);
    });
  }

  Future<void> _showSongAddToMenu(
    BuildContext buttonContext,
    LibrarySong song,
  ) {
    return _showSongAddToMenuForArtistsPage(this, buttonContext, song);
  }

  String _allArtistsTitle(
    LibraryContentData snapshot,
    List<ArtistGroup> artistGroups,
    SmPlayerI18n i18n,
  ) {
    return snapshot.showCount
        ? i18n.t('library.allArtistsWithCount', {'count': artistGroups.length})
        : i18n.t('library.allArtists');
  }
}
