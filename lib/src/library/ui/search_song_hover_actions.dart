part of 'search_page.dart';

extension _SearchSongHoverActions on _SearchResultSection {
  Future<void> _showSongAddToMenu(
    BuildContext context,
    LibrarySong song,
  ) async {
    final item = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: [song.id],
      playlists: playlists,
      includeNowPlaying: shouldShowNowPlayingAddToTarget(
        songIds: [song.id],
        nowPlayingSongIds: nowPlayingSongIds,
        isNowPlayingContext: false,
      ),
      includeFavorites: true,
      favoritesDisabled: song.favorite,
      favoritesSelected: song.favorite,
      onAddToNowPlaying: () async {
        await onAddSongsToNowPlaying([song.id]);
      },
      onToggleFavorite: () async {
        await onToggleSongsFavorite([song.id], true);
      },
      onCreatePlaylist: () {
        unawaited(onCreatePlaylist(song.title, [song.id]));
      },
      onAddToPlaylist: (playlistId) async {
        await onAddSongsToPlaylist(playlistId, [song.id]);
      },
    );
    await showMenuFlyout(context, items: item!.submenu);
  }
}
