part of 'artists_page.dart';

void _playSongIdsForArtistsPage(_ArtistsPageState state, List<int> songIds) {
  if (songIds.isEmpty) {
    return;
  }

  replaceNowPlayingQueueAndPlayIndex(
    ref: state.ref,
    snapshot: state.ref.read(libraryContentDataProvider).value!,
    i18n: state.context.smPlayerI18n,
    songIds: songIds,
    queueIndex: 0,
  );
}

Future<void> _playTrackInQueueForArtistsPage(
  _ArtistsPageState state,
  int songId,
  List<int> queueSongIds,
) async {
  queueSongIds = await state.ref
      .read(selectedLibraryDataSourceProvider)
      .resolveSongIds(
        LibraryDataQuery(
          LibraryQueryKind.artist,
          artists: [state._detailArtistSource!],
        ),
      );
  if (!state.mounted) return;
  final snapshot = state.ref.read(libraryContentDataProvider).value!;
  final mediaState = state.ref.read(mediaControlControllerProvider).state;
  final currentSongIds = currentNowPlayingSongIds(state.ref, snapshot);
  final queueChanged =
      !_sameSongIdsForArtistsPage(queueSongIds, currentSongIds);
  final resolvedQueueSongIds =
      queueChanged && mediaState.mode == PlaybackMode.shuffle
          ? shufflePlaybackQueueForCurrentTrack(queueSongIds, songId)
          : (queueChanged ? queueSongIds.toList() : currentSongIds.toList());
  final queueIndex = resolvedQueueSongIds.indexOf(songId);
  replaceNowPlayingQueueAndPlayIndex(
    ref: state.ref,
    snapshot: snapshot,
    i18n: state.context.smPlayerI18n,
    songIds: resolvedQueueSongIds,
    queueIndex: queueIndex,
  );
}

bool _sameSongIdsForArtistsPage(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

void _playNextForArtistsPage(_ArtistsPageState state, int songId) {
  final snapshot = state.ref.read(libraryContentDataProvider).value!;
  final previousSongIds = currentNowPlayingSongIds(state.ref, snapshot);
  final activeIndex = currentQueueIndexForPlaybackOccurrence(
    state.ref.read(mediaControlControllerProvider).state,
    previousSongIds,
  );
  final nextSongIds = previousSongIds.toList()..insert(activeIndex + 1, songId);
  setNowPlayingQueue(state.ref, nextSongIds);
  final songsById = {for (final song in snapshot.songs) song.id: song};
  showPlayNextUndoNotification(
    context: state.context,
    i18n: state.context.smPlayerI18n,
    songTitle: songsById[songId]!.title,
    onUndo: () {
      setNowPlayingQueue(state.ref, previousSongIds);
    },
  );
}

void _moveToMusicOrPlayForArtistsPage(_ArtistsPageState state, int songId) {
  final snapshot = state.ref.read(libraryContentDataProvider).value!;
  insertOrPlayNowPlayingSong(
    ref: state.ref,
    snapshot: snapshot,
    i18n: state.context.smPlayerI18n,
    songId: songId,
  );
}

void _playShuffledSongIdsForArtistsPage(
  _ArtistsPageState state,
  List<int> songIds, {
  String? artistName,
  String? albumName,
}) {
  if (artistName != null || albumName != null) {
    unawaited(
      runMusicShareAction(state.context, () async {
        final i18n = state.context.smPlayerI18n;
        final ids = await state.ref
            .read(selectedLibraryDataSourceProvider)
            .selectSongIds(
              LibrarySelectionRequest(
                artistName != null
                    ? LibrarySelectionKind.currentArtist
                    : LibrarySelectionKind.currentAlbum,
                artists:
                    artistName == null
                        ? const []
                        : [
                          artistName == i18n.t('common.artistUnknown')
                              ? ''
                              : artistName,
                        ],
                album:
                    albumName == i18n.t('common.albumUnknown')
                        ? ''
                        : albumName ?? '',
              ),
            );
        if (!state.mounted) return;
        if (artistName != null)
          await recordRecentArtistPlayback(state.ref, artistName);
        if (albumName != null)
          await recordRecentAlbumPlayback(state.ref, albumName);
        state._playSongIds(ids);
      }),
    );
    return;
  }
  unawaited(
    sourceShuffleSongIds(state.ref, songIds).then((ids) {
      if (state.mounted) state._playSongIds(ids);
    }),
  );
}
