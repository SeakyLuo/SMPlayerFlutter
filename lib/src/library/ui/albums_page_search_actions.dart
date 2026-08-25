part of 'albums_page.dart';

extension _AlbumsPageSearchActions on _AlbumsPageState {
  void _submitSearch({bool closeAppBar = false}) {
    final query = _searchDraft.trim();
    _showProcessing();
    _updateState(() {
      _searchDraft = query;
      _searchQuery = _searchDraft;
      _searchFocused = false;
      if (closeAppBar) {
        _appBarSearchOpen = false;
      }
    });
    if (query.isNotEmpty) {
      final recentSearches = ref.read(recentSearchesProvider.notifier);
      unawaited(
        ref
            .read(libraryRepositoryProvider)
            .addRecentSearch(query, SearchHistoryType.albums)
            .then((entry) {
              if (entry != null) {
                return recentSearches.record(entry);
              }
            }),
      );
    }
    _scrollAlbumsToTop();
  }

  void _selectSearchQuery(String query) {
    FocusManager.instance.primaryFocus?.unfocus();
    _updateState(() {
      _searchDraft = query;
      _searchQuery = query;
      _searchFocused = false;
      _appBarSearchOpen = false;
    });
    _scrollAlbumsToTop();
  }

  void _clearSearch() {
    _updateState(() {
      _searchDraft = '';
      _searchQuery = '';
    });
    if (widget.targetAlbumName != null) {
      context.go('/albums');
    }
    _scrollAlbumsToTop();
  }

  void _changeSearchFocus(bool focused) {
    _updateState(() {
      _searchFocused = focused;
    });
  }

  void _removeRecentSearch(int entryId) {
    final recentSearches = ref.read(recentSearchesProvider.notifier);
    unawaited(
      ref.read(libraryRepositoryProvider).removeRecentSearches([entryId]).then((
        _,
      ) {
        return recentSearches.remove([entryId]);
      }),
    );
  }

  void _clearRecentSearches() {
    final entryIds =
        latestSearchHistoryEntries(
          ref.read(recentSearchesProvider).value!,
          SearchHistoryType.albums,
        ).map((entry) => entry.id).toList();
    final recentSearches = ref.read(recentSearchesProvider.notifier);
    unawaited(
      ref.read(libraryRepositoryProvider).removeRecentSearches(entryIds).then((
        _,
      ) {
        return recentSearches.remove(entryIds);
      }),
    );
  }
}
