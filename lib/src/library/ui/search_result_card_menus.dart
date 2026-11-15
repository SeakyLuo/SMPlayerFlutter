part of 'search_page.dart';

extension _SearchCardMenus on _SearchResultSection {
  Future<void> _showCardContextMenu(
    BuildContext context,
    Offset position,
    SearchResult card,
  ) async {
    if (card.scope case final scope?) {
      final container = ProviderScope.containerOf(context, listen: false);
      final ids = await container
          .read(selectedLibraryDataSourceProvider)
          .resolveSongIds(scope);
      if (!context.mounted) return;
      card = card.withIds(ids);
    }

    final cardKey = getSearchResultCardKey(section.type, card);
    final preferenceLevel = await onGetPreferenceLevel(section.type, card);
    if (!context.mounted) {
      return;
    }
    final favoriteSongIds = [
      for (final songId in card.songIds)
        if (songsById[songId]?.favorite != true) songId,
    ];
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: card.songIds,
      playlists: playlists,
      includeNowPlaying: shouldShowNowPlayingAddToTarget(
        songIds: card.songIds,
        nowPlayingSongIds: nowPlayingSongIds,
        isNowPlayingContext: false,
      ),
      includeFavorites: favoriteSongIds.isNotEmpty,
      onAddToNowPlaying: () {
        onAddSongsToNowPlaying(card.songIds);
      },
      onToggleFavorite: () {
        onToggleSongsFavorite(favoriteSongIds, true);
      },
      onCreatePlaylist: () {
        onCreatePlaylist(card.title, card.songIds);
      },
      onAddToPlaylist: (playlistId) {
        onAddCardSongsToPlaylist(playlistId, card.songIds);
      },
    );

    await showMenuFlyout(
      context,
      position: position,
      items: [
        MenuFlyoutItem(
          key: 'shuffle',
          text: i18n.t('nowPlaying.randomPlay'),
          useShuffleIcon: true,
          onPressed: () {
            onPlayCard(card);
          },
        ),
        if (addToItem != null) addToItem,
        MenuFlyoutItem(
          key: 'select',
          text: i18n.t('context.select'),
          icon: FluentIcons.multiselect_ltr_20_regular,
          onPressed: () {
            selection.enterMultiSelect();
            selection.replaceSelection([
              for (final key in selection.selectedItems)
                if (_isSearchSongSelectionKey(key)) key,
              cardKey,
            ], selectionAnchor: cardKey);
            onSelectionChanged();
          },
        ),
        if (_searchResultPreferenceType(section.type) != null)
          _buildSearchResultPreferenceMenuItem(card, preferenceLevel),
        if (section.type == SearchResultType.albums)
          MenuFlyoutItem(
            key: 'see-album-art',
            text: i18n.t('context.seeAlbumArt'),
            icon: FluentIcons.image_20_regular,
            onPressed: () {
              onPreviewAlbumArt(card);
            },
          ),
        if (section.type == SearchResultType.folders) ...[
          MenuFlyoutItem(
            key: 'show-in-explorer',
            text: i18n.t('context.reveal'),
            pendingText: i18n.t('context.openingLocal'),
            icon: FluentIcons.folder_open_20_regular,
            onPressed: () => onRevealCard(card),
          ),
          MenuFlyoutItem(
            key: 'search-directory',
            text: i18n.t('local.searchDirectory'),
            icon: FluentIcons.search_20_regular,
            onPressed: () {
              onSearchDirectory(card);
            },
          ),
        ],
      ],
    );
  }

  Future<void> _showCardAddToMenu(
    BuildContext context,
    Offset position,
    SearchResult card,
  ) async {
    if (card.scope case final scope?) {
      final container = ProviderScope.containerOf(context, listen: false);
      final ids = await container
          .read(selectedLibraryDataSourceProvider)
          .resolveSongIds(scope);
      if (!context.mounted) return;
      card = card.withIds(ids);
    }

    final favoriteSongIds = [
      for (final songId in card.songIds)
        if (songsById[songId]?.favorite != true) songId,
    ];
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: card.songIds,
      playlists: playlists,
      includeNowPlaying: shouldShowNowPlayingAddToTarget(
        songIds: card.songIds,
        nowPlayingSongIds: nowPlayingSongIds,
        isNowPlayingContext: false,
      ),
      includeFavorites: favoriteSongIds.isNotEmpty,
      onAddToNowPlaying: () {
        onAddSongsToNowPlaying(card.songIds);
      },
      onToggleFavorite: () {
        onToggleSongsFavorite(favoriteSongIds, true);
      },
      onCreatePlaylist: () {
        onCreatePlaylist(card.title, card.songIds);
      },
      onAddToPlaylist: (playlistId) {
        onAddSongsToPlaylist(playlistId, card.songIds);
      },
    );
    if (addToItem == null) {
      return;
    }

    showMenuFlyout(context, position: position, items: addToItem.submenu);
  }

  MenuFlyoutItem _buildSearchResultPreferenceMenuItem(
    SearchResult card,
    String? preferenceLevel,
  ) {
    return buildPreferenceMenuFlyoutItem(
      i18n: i18n,
      key: 'preference',
      preferenceLevel: preferenceLevel,
      onUndoPreference:
          preferenceLevel == null
              ? null
              : () {
                onUndoPreference(section.type, card);
              },
      onSetPreference: (level) {
        onSetPreference(section.type, card, level);
      },
    );
  }
}

class _SearchSectionActionButton extends StatelessWidget {
  const _SearchSectionActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SmPlayerTextIconButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
    );
  }
}

String? _searchResultPreferenceType(SearchResultType type) {
  return switch (type) {
    SearchResultType.artists => 'artist',
    SearchResultType.albums => 'album',
    SearchResultType.playlists => 'playlist',
    SearchResultType.folders => 'folder',
    SearchResultType.songs => null,
    SearchResultType.lyrics => null,
  };
}

String _searchResultPreferenceId(String preferenceType, SearchResult card) {
  return preferenceType == 'folder' || preferenceType == 'playlist'
      ? card.sourceId!
      : card.title;
}

SearchFilterKey _filterForSection(SearchResultType type) {
  return switch (type) {
    SearchResultType.artists => SearchFilterKey.artists,
    SearchResultType.albums => SearchFilterKey.albums,
    SearchResultType.songs => SearchFilterKey.songs,
    SearchResultType.lyrics => SearchFilterKey.lyrics,
    SearchResultType.playlists => SearchFilterKey.playlists,
    SearchResultType.folders => SearchFilterKey.folders,
  };
}

String _songSelectionKey(LibrarySong song) {
  return 'songs:${song.id}';
}

bool _isSearchSongSelectionKey(String key) {
  return key.startsWith('songs:');
}
