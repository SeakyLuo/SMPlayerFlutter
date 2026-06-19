part of 'albums_page.dart';

extension _AlbumsPagePlaybackActions on _AlbumsPageState {
  Future<void> _playSongIds(List<int> songIds, {bool shuffle = false}) async {
    if (songIds.isEmpty) {
      return;
    }

    final queueSongIds = songIds.toList();
    if (shuffle) {
      queueSongIds.shuffle(Random());
    }
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final i18n = context.smPlayerI18n;
    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: snapshot,
      i18n: i18n,
      songIds: queueSongIds,
      queueIndex: 0,
    );
  }

  Future<void> _addSongsToNowPlayingWithUndo(List<int> songIds) async {
    if (songIds.isEmpty) {
      return;
    }

    final snapshot = ref.read(libraryContentDataProvider).value!;
    final currentSongIds = currentNowPlayingSongIds(ref, snapshot);
    final insertedIndex = currentSongIds.length;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final i18n = context.smPlayerI18n;
    final queueAfterAdd = [...currentSongIds, ...songIds];
    setNowPlayingQueue(ref, queueAfterAdd);
    _showUndoNotification(
      songIds.length == 1
          ? i18n.t('notification.songAddedTo', {
            'title': songsById[songIds.first]!.title,
            'target': i18n.t('common.nowPlaying'),
          })
          : i18n.t('notification.songsAddedTo', {
            'count': songIds.length,
            'target': i18n.t('common.nowPlaying'),
          }),
      () async {
        final currentSongIds =
            ref.read(nowPlayingQueueOverrideProvider) ?? queueAfterAdd;
        final restoredSongIds =
            currentSongIds.toList()..removeRange(
              insertedIndex,
              min(insertedIndex + songIds.length, currentSongIds.length),
            );
        setNowPlayingQueue(ref, restoredSongIds);
      },
    );
  }

  Future<void> _addSongsToPlaylistWithUndo(
    int playlistId,
    List<int> songIds,
  ) async {
    if (songIds.isEmpty) {
      return;
    }

    final snapshot = ref.read(libraryContentDataProvider).value!;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final targetPlaylist = snapshot.playlists.firstWhere(
      (playlist) => playlist.id == playlistId,
    );
    final i18n = context.smPlayerI18n;
    await ref
        .read(libraryRepositoryProvider)
        .addSongsToPlaylist(playlistId, songIds);
    _showUndoNotification(
      songIds.length == 1
          ? i18n.t('notification.songAddedTo', {
            'title': songsById[songIds.first]!.title,
            'target': targetPlaylist.name,
          })
          : i18n.t('notification.songsAddedTo', {
            'count': songIds.length,
            'target': targetPlaylist.name,
          }),
      () async {
        await ref
            .read(libraryRepositoryProvider)
            .removeSongsFromPlaylist(playlistId, songIds);
      },
    );
  }

  Future<void> _setSongsFavoriteWithUndo(
    List<int> songIds,
    bool favorite,
  ) async {
    if (songIds.isEmpty) {
      return;
    }

    final snapshot = ref.read(libraryContentDataProvider).value!;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final i18n = context.smPlayerI18n;
    await setSongsFavorite(ref, songIds, favorite);
    _showUndoNotification(
      songIds.length == 1
          ? i18n.t('notification.songAddedTo', {
            'title': songsById[songIds.first]!.title,
            'target': i18n.t('common.myFavorites'),
          })
          : i18n.t('notification.songsAddedTo', {
            'count': songIds.length,
            'target': i18n.t('common.myFavorites'),
          }),
      () async {
        await setSongsFavorite(ref, songIds, !favorite);
      },
    );
  }

  void _showUndoNotification(String message, FutureOr<void> Function() onUndo) {
    showUndoableNotification(
      context: context,
      i18n: context.smPlayerI18n,
      message: message,
      onUndo: onUndo,
    );
  }
}
