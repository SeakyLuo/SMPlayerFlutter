part of 'playlists_page.dart';

extension _PlaylistsPageSearchActions on _PlaylistsPageState {
  void _submitSearch({bool closeAppBar = false}) {
    final query = _searchDraft.trim();
    // ignore: invalid_use_of_protected_member
    setState(() {
      _searchDraft = query;
      _searchQuery = query;
      _searchFocused = false;
      if (closeAppBar) {
        _appBarSearchOpen = false;
      }
    });
    _recordPlaylistSearch(query);
  }

  void _selectSearchQuery(String query) {
    FocusManager.instance.primaryFocus?.unfocus();
    // ignore: invalid_use_of_protected_member
    setState(() {
      _searchDraft = query;
      _searchQuery = query;
      _searchFocused = false;
      _appBarSearchOpen = false;
    });
  }

  void _clearSearch() {
    // ignore: invalid_use_of_protected_member
    setState(() {
      _searchDraft = '';
      _searchQuery = '';
    });
    if (widget.searchQuery.isNotEmpty) {
      context.go('/playlists');
    }
  }

  void _changeSearchFocus(bool focused) {
    // ignore: invalid_use_of_protected_member
    setState(() {
      _searchFocused = focused;
    });
  }

  void _removeRecentSearch(int entryId) {
    unawaited(
      ref.read(libraryRepositoryProvider).removeRecentSearches([entryId]).then((
        _,
      ) {
        invalidateRecentSearchData(ref);
      }),
    );
  }

  void _clearRecentSearches() {
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final entryIds =
        latestSearchHistoryEntries(
          snapshot.recentSearches,
          SearchHistoryType.playlists,
        ).map((entry) => entry.id).toList();
    unawaited(
      ref.read(libraryRepositoryProvider).removeRecentSearches(entryIds).then((
        _,
      ) {
        invalidateRecentSearchData(ref);
      }),
    );
  }

  void _recordPlaylistSearch(String query) {
    if (query.isEmpty) {
      return;
    }
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .addRecentSearch(query, SearchHistoryType.playlists)
          .then((_) {
            invalidateRecentSearchData(ref);
          }),
    );
  }

  List<String> _playlistSearchSuggestions(
    List<LibraryPlaylist> playlists,
    Map<int, LibrarySong> songsById,
  ) {
    final query = _searchDraft.trim();
    final seen = <String>{};
    final suggestions = <String>[];
    for (final playlist in _searchPlaylists(playlists, songsById, query)) {
      final key = playlist.name.toLowerCase();
      if (seen.add(key)) {
        suggestions.add(playlist.name);
      }
      if (suggestions.length == 8) {
        break;
      }
    }
    return suggestions;
  }

  List<LibraryPlaylist> _searchPlaylists(
    List<LibraryPlaylist> playlists,
    Map<int, LibrarySong> songsById,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return playlists;
    }
    return playlists.where((playlist) {
      if (playlist.name.toLowerCase().contains(normalizedQuery)) {
        return true;
      }
      return playlist.songIds.any((songId) {
        final song = songsById[songId]!;
        return song_display
            .searchableSongText(song)
            .toLowerCase()
            .contains(normalizedQuery);
      });
    }).toList();
  }
}
