part of 'playlists_page.dart';

extension _PlaylistsPageLoading on _PlaylistsPageState {
  Widget _buildGridToolbar(
    SmPlayerI18n i18n,
    List<String> searchSuggestions,
    List<SearchHistoryEntry> searchHistoryEntries,
    VoidCallback? onCreatePlaylist,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
    child: _PlaylistsToolbar(
      searchDraft: _searchDraft,
      searchHasText: _searchDraft.isNotEmpty || _searchQuery.isNotEmpty,
      i18n: i18n,
      searchFocused: _searchFocused,
      searchSuggestions: searchSuggestions,
      searchHistoryEntries: searchHistoryEntries,
      onSearchChanged: (value) {
        _updateState(() {
          _searchDraft = value;
        });
      },
      onSearchFocusChanged: _changeSearchFocus,
      onSearchSubmitted: _submitSearch,
      onClearSearch: _clearSearch,
      onSelectSearchSuggestion: _selectSearchQuery,
      onRemoveRecentSearch: _removeRecentSearch,
      onClearRecentSearches: _clearRecentSearches,
      onCreatePlaylist: onCreatePlaylist,
    ),
  );

  Widget _buildLoading(BuildContext context, SmPlayerI18n i18n) {
    if (widget.selectedPlaylistId != null) {
      _clearAppBarPortalOwner();
      return const HeaderedPlaylistLoadingState(
        type: HeaderedPlaylistType.playlist,
      );
    }
    final useWorkspaceAppBar = WorkspaceNavigationAppBarScope.of(context);
    _syncAppBarPortal(
      showPortal: true,
      routePath: '/playlists',
      title: i18n.t('common.playlists'),
      i18n: i18n,
      searchSuggestions: const [],
      searchHistoryEntries: const [],
      onCreatePlaylist: null,
    );
    return Column(
      children: [
        if (!useWorkspaceAppBar) ...[
          _buildGridToolbar(i18n, const [], const [], null),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: _PlaylistGridLoadingState(
            useWorkspaceAppBar: useWorkspaceAppBar,
          ),
        ),
      ],
    );
  }
}
