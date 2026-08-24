part of 'albums_page.dart';

extension _AlbumsPageMenuActions on _AlbumsPageState {
  Future<void> _showAlbumContextMenu(
    Offset position,
    AlbumView album,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) async {
    final i18n = context.smPlayerI18n;
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final preferenceLevel = await ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('album', album.name);
    if (!mounted) {
      return;
    }
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: album.songIds,
      playlists: playlists,
      includeNowPlaying: shouldShowNowPlayingAddToTarget(
        songIds: album.songIds,
        nowPlayingSongIds: snapshot.nowPlaying.songIds,
        isNowPlayingContext: false,
      ),
      includeFavorites: album.songs.any((song) => !song.favorite),
      onAddToNowPlaying: () {
        _addSongsToNowPlayingWithUndo(album.songIds);
      },
      onToggleFavorite:
          album.songs.any((song) => !song.favorite)
              ? () {
                _setSongsFavoriteWithUndo(
                  album.songs
                      .where((song) => !song.favorite)
                      .map((song) => song.id)
                      .toList(),
                  true,
                );
              }
              : null,
      onCreatePlaylist: () async {
        await createPlaylistWithSongs(
          context: context,
          ref: ref,
          i18n: i18n,
          playlists: snapshot.playlists,
          defaultName: getNextPlaylistName(album.name, snapshot.playlists),
          songIds: album.songIds,
        );
      },
      onAddToPlaylist: (playlistId) {
        _addSongsToPlaylistWithUndo(playlistId, album.songIds);
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
          onPressed: () async {
            await recordRecentAlbumPlayback(ref, album.name);
            await _playSongIds(album.songIds, shuffle: true);
          },
        ),
        if (addToItem != null) addToItem,
        MenuFlyoutItem(
          key: 'select',
          text: i18n.t('context.select'),
          icon: FluentIcons.multiselect_ltr_20_regular,
          onPressed: () {
            _updateState(() {
              _selection.enterMultiSelect();
              _selection.selectSingle(album.name);
            });
          },
        ),
        _buildAlbumPreferenceMenuItem(i18n, album, preferenceLevel),
        MenuFlyoutItem(
          key: 'see-album-art',
          text: i18n.t('context.seeAlbumArt'),
          icon: FluentIcons.image_20_regular,
          onPressed: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              _updateState(() {
                _albumArtPreview = album;
              });
            });
          },
        ),
      ],
    );
  }

  MenuFlyoutItem _buildAlbumPreferenceMenuItem(
    SmPlayerI18n i18n,
    AlbumView album,
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
                ref
                    .read(libraryRepositoryProvider)
                    .removePreferenceItem('album', album.name);
              },
      onSetPreference: (level) {
        ref
            .read(libraryRepositoryProvider)
            .addPreferenceItem('album', album.name, album.name, level);
      },
    );
  }

  void _showAlbumAddToMenu(
    Offset position,
    AlbumView album,
    List<MultiSelectCommandBarPlaylist> playlists,
    LibraryContentData snapshot,
    SmPlayerI18n i18n,
  ) {
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: album.songIds,
      playlists: playlists,
      includeNowPlaying: shouldShowNowPlayingAddToTarget(
        songIds: album.songIds,
        nowPlayingSongIds: snapshot.nowPlaying.songIds,
        isNowPlayingContext: false,
      ),
      includeFavorites: album.songs.any((song) => !song.favorite),
      onAddToNowPlaying: () {
        _addSongsToNowPlayingWithUndo(album.songIds);
      },
      onToggleFavorite:
          album.songs.any((song) => !song.favorite)
              ? () {
                _setSongsFavoriteWithUndo(
                  album.songs
                      .where((song) => !song.favorite)
                      .map((song) => song.id)
                      .toList(),
                  true,
                );
              }
              : null,
      onCreatePlaylist: () {
        createPlaylistWithSongs(
          context: context,
          ref: ref,
          i18n: i18n,
          playlists: snapshot.playlists,
          defaultName: getNextPlaylistName(album.name, snapshot.playlists),
          songIds: album.songIds,
        );
      },
      onAddToPlaylist: (playlistId) {
        _addSongsToPlaylistWithUndo(playlistId, album.songIds);
      },
    );
    if (addToItem == null) {
      return;
    }

    showMenuFlyout(context, position: position, items: addToItem.submenu);
  }
}
