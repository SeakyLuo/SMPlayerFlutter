part of 'albums_page.dart';

extension _AlbumsPageSearchActions on _AlbumsPageState {
  void _submitSearch({bool closeAppBar = false}) {
    final query = _searchDraft.trim();
    _showProcessing();
    setState(() {
      _searchDraft = query;
      _searchQuery = _searchDraft;
      _searchFocused = false;
      if (closeAppBar) {
        _appBarSearchOpen = false;
      }
    });
    if (query.isNotEmpty) {
      unawaited(
        ref
            .read(libraryRepositoryProvider)
            .addRecentSearch(query, SearchHistoryType.albums)
            .then((_) {
              invalidateRecentSearchData(ref);
            }),
      );
    }
    _scrollAlbumsToTop();
  }

  void _selectSearchQuery(String query) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _searchDraft = query;
      _searchQuery = query;
      _searchFocused = false;
      _appBarSearchOpen = false;
    });
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .addRecentSearch(query, SearchHistoryType.albums)
          .then((_) {
            invalidateRecentSearchData(ref);
          }),
    );
    _scrollAlbumsToTop();
  }

  void _clearSearch() {
    setState(() {
      _searchDraft = '';
      _searchQuery = '';
    });
    if (widget.targetAlbumName != null) {
      context.go('/albums');
    }
    _scrollAlbumsToTop();
  }

  void _changeSearchFocus(bool focused) {
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
          SearchHistoryType.albums,
        ).map((entry) => entry.id).toList();
    unawaited(
      ref.read(libraryRepositoryProvider).removeRecentSearches(entryIds).then((
        _,
      ) {
        invalidateRecentSearchData(ref);
      }),
    );
  }
}
