part of 'recent_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _RecentPageSelection on _RecentPageState {
  void _toggleSongSelection(int songId) {
    setState(() {
      if (_selectedSongIds.contains(songId)) {
        _selectedSongIds.remove(songId);
      } else {
        _selectedSongIds.add(songId);
      }
    });
  }

  void _toggleSearchSelection(int entryId) {
    setState(() {
      if (_selectedSearchIds.contains(entryId)) {
        _selectedSearchIds.remove(entryId);
      } else {
        _selectedSearchIds.add(entryId);
      }
    });
  }

  void _toggleBrowseSelection(int entryId) {
    setState(() {
      if (_selectedBrowseIds.contains(entryId)) {
        _selectedBrowseIds.remove(entryId);
      } else {
        _selectedBrowseIds.add(entryId);
      }
    });
  }

  void _toggleCollectionSelection(String key) {
    setState(() {
      if (_selectedCollectionKeys.contains(key)) {
        _selectedCollectionKeys.remove(key);
      } else {
        _selectedCollectionKeys.add(key);
      }
    });
  }

  void _clearSelection() {
    _selectedSongIds.clear();
    _selectedCollectionKeys.clear();
    _selectedBrowseIds.clear();
    _selectedSearchIds.clear();
  }

  void _selectAll(
    List<SearchHistoryEntry> recentSearches,
    List<LibrarySong> visibleSongs,
    List<RecentPlaylistView> playlists,
    List<RecentAlbumView> albums,
    List<RecentArtistView> artists,
    List<RecentBrowseView> browses,
  ) {
    if (_activeTab == RecentTab.browsed) {
      _selectedBrowseIds
        ..clear()
        ..addAll(browses.map((view) => view.entry.id));
      return;
    }
    if (_activeTab == RecentTab.searches) {
      _selectedSearchIds
        ..clear()
        ..addAll(recentSearches.map((entry) => entry.id));
      return;
    }
    if (_activeTab == RecentTab.played &&
        _activePlayedFilter != RecentPlayedFilter.songs) {
      _selectedCollectionKeys
        ..clear()
        ..addAll(_visibleCollectionKeys(playlists, albums, artists));
      return;
    }
    _selectedSongIds
      ..clear()
      ..addAll(visibleSongs.map((song) => song.id));
  }

  void _reverseSelection(
    List<SearchHistoryEntry> recentSearches,
    List<LibrarySong> visibleSongs,
    List<RecentPlaylistView> playlists,
    List<RecentAlbumView> albums,
    List<RecentArtistView> artists,
    List<RecentBrowseView> browses,
  ) {
    if (_activeTab == RecentTab.browsed) {
      final current = _selectedBrowseIds.toSet();
      _selectedBrowseIds
        ..clear()
        ..addAll(
          browses
              .where((view) => !current.contains(view.entry.id))
              .map((view) => view.entry.id),
        );
      return;
    }
    if (_activeTab == RecentTab.searches) {
      final current = _selectedSearchIds.toSet();
      _selectedSearchIds
        ..clear()
        ..addAll(
          recentSearches
              .where((entry) => !current.contains(entry.id))
              .map((entry) => entry.id),
        );
      return;
    }
    if (_activeTab == RecentTab.played &&
        _activePlayedFilter != RecentPlayedFilter.songs) {
      final current = _selectedCollectionKeys.toSet();
      _selectedCollectionKeys
        ..clear()
        ..addAll(
          _visibleCollectionKeys(
            playlists,
            albums,
            artists,
          ).where((key) => !current.contains(key)),
        );
      return;
    }
    final current = _selectedSongIds.toSet();
    _selectedSongIds
      ..clear()
      ..addAll(
        visibleSongs
            .where((song) => !current.contains(song.id))
            .map((song) => song.id),
      );
  }

  List<String> _visibleCollectionKeys(
    List<RecentPlaylistView> playlists,
    List<RecentAlbumView> albums,
    List<RecentArtistView> artists,
  ) {
    return switch (_activePlayedFilter) {
      RecentPlayedFilter.playlists =>
        playlists.map((item) => 'playlists:${item.playlist.id}').toList(),
      RecentPlayedFilter.albums =>
        albums.map((item) => 'albums:${item.name}').toList(),
      RecentPlayedFilter.artists =>
        artists.map((item) => 'artists:${item.name}').toList(),
      RecentPlayedFilter.songs => const <String>[],
    };
  }

  List<int> _selectedCollectionSongIds(
    List<RecentPlaylistView> playlists,
    List<RecentAlbumView> albums,
    List<RecentArtistView> artists,
  ) {
    final songIds = <int>[];
    for (final playlist in playlists) {
      if (_selectedCollectionKeys.contains(
        'playlists:${playlist.playlist.id}',
      )) {
        songIds.addAll(playlist.songs.map((song) => song.id));
      }
    }
    for (final album in albums) {
      if (_selectedCollectionKeys.contains('albums:${album.name}')) {
        songIds.addAll(album.songIds);
      }
    }
    for (final artist in artists) {
      if (_selectedCollectionKeys.contains('artists:${artist.name}')) {
        songIds.addAll(artist.songs.map((song) => song.id));
      }
    }
    return songIds.toSet().toList();
  }

  String _selectedPlaylistDefaultName(
    SmPlayerI18n i18n,
    List<LibraryPlaylist> allPlaylists,
    List<RecentPlaylistView> playlists,
    List<RecentAlbumView> albums,
    List<RecentArtistView> artists,
  ) {
    if (_activeTab != RecentTab.played ||
        _activePlayedFilter == RecentPlayedFilter.songs ||
        _selectedCollectionKeys.length != 1) {
      return getNextPlaylistName(i18n.t('common.songs'), allPlaylists);
    }

    final key = _selectedCollectionKeys.first;
    if (_activePlayedFilter == RecentPlayedFilter.playlists) {
      return playlists
          .firstWhere((playlist) => key == 'playlists:${playlist.playlist.id}')
          .playlist
          .name;
    }
    if (_activePlayedFilter == RecentPlayedFilter.albums) {
      return albums.firstWhere((album) => key == 'albums:${album.name}').name;
    }
    return artists.firstWhere((artist) => key == 'artists:${artist.name}').name;
  }

  void _hideAfterOperation(bool hideMultiSelectCommandBarAfterOperation) {
    _clearSelection();
    if (hideMultiSelectCommandBarAfterOperation) {
      _multiSelect = false;
    }
  }

  void _setRecentAddedTimelineLabel(String label) {
    if (_recentAddedTimelineLabel == label) {
      return;
    }
    setState(() {
      _recentAddedTimelineLabel = label;
    });
  }

  void _setRecentPlayedTimelineLabel(String label) {
    if (_recentPlayedTimelineLabel == label) {
      return;
    }
    setState(() {
      _recentPlayedTimelineLabel = label;
    });
  }
}
