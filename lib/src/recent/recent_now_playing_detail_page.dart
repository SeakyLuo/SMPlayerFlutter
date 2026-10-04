part of 'recent_page.dart';

class RecentNowPlayingDetailPage extends ConsumerWidget {
  const RecentNowPlayingDetailPage({super.key, required this.recordId});

  final int recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(recentPageDataProvider);
    if (i18nValue.isLoading || snapshotValue.isLoading) {
      return const _RecentPagePanel(child: SmPlayerLoadingState());
    }

    final i18n = i18nValue.value!;
    return SmPlayerI18nScope(
      i18n: i18n,
      child: snapshotValue.when(
        loading: () => const _RecentPagePanel(child: SmPlayerLoadingState()),
        error:
            (_, _) => _RecentPagePanel(
              child: _RecentEmptyState(
                title: i18n.t('recent.empty'),
                message: '',
              ),
            ),
        data: (snapshot) {
          final entry = buildRecentNowPlayingViews(
            snapshot.recentNowPlaying,
            snapshot.songs,
          ).singleWhere((entry) => entry.id == recordId);
          final mediaControl = ref.watch(
            mediaControlControllerProvider.select(
              (controller) => (
                trackId: controller.state.track.id,
                isPlaying: controller.state.isPlaying,
              ),
            ),
          );
          final artworkUrl =
              entry.songs
                  .where((song) => song.thumbnailPath.isNotEmpty)
                  .map((song) => song.thumbnailPath)
                  .firstOrNull ??
              '';
          final title = recentNowPlayingTitle(i18n, entry);
          final historyPlaylist = LibraryPlaylist(
            id: entry.playlistId,
            name: title,
            priority: 0,
            songCount: entry.songs.length,
            songIds: entry.songIds,
            sortCriterion: PlaylistSortCriterion.title,
            isBuiltIn: true,
          );

          return HeaderedPlaylistControl(
            key: ValueKey('RecentNowPlayingDetail.$recordId'),
            playlistId: historyPlaylist.id,
            routeLocation: GoRouterState.of(context).uri.toString(),
            type: HeaderedPlaylistType.playlist,
            title: title,
            headerSongs: entry.songs,
            songs: entry.songs,
            selectedTrackId: mediaControl.trackId,
            isPlaying: mediaControl.isPlaying,
            playlists: [historyPlaylist, ...snapshot.playlists],
            favoritePlaylistId: snapshot.favoritePlaylistId,
            artworkUrl: artworkUrl,
            showAlbum: true,
            preferenceType: 'recent-now-playing',
            preferenceItemId: recordId.toString(),
            onPlayTrack: (trackId, queueSongIds) {
              replaceNowPlayingQueueAndPlayIndexFromSongs(
                ref: ref,
                songs: snapshot.songs,
                persistedSongIds: snapshot.nowPlaying.songIds,
                i18n: i18n,
                songIds: queueSongIds,
                queueIndex: queueSongIds.indexOf(trackId),
              );
              ref.invalidate(recentPageDataProvider);
            },
            onTogglePlayPause:
                ref.read(mediaControlControllerProvider).onTogglePlayPause,
            onAddSongToPlaylist: (playlistId, songId) {
              unawaited(addSongsToPlaylist(ref, playlistId, [songId]));
            },
            onAddSongsToPlaylist: (playlistId, songIds) {
              unawaited(addSongsToPlaylist(ref, playlistId, songIds));
            },
            onToggleFavorite: (songId, favorite) {
              unawaited(setSongsFavorite(ref, [songId], favorite));
            },
            onMoveToMusicOrPlay: (songId) {
              _insertOrPlayRecentNowPlayingSong(ref, snapshot, i18n, songId);
            },
            onPlayNext: (songId) {
              _playRecentNowPlayingNext(context, ref, snapshot, i18n, songId);
            },
            onArtistClick: (artist) {
              context.go('/artists?artist=${Uri.encodeQueryComponent(artist)}');
            },
            onAlbumClick: (album) {
              context.go('/albums?album=${Uri.encodeQueryComponent(album)}');
            },
          );
        },
      ),
    );
  }
}

void _insertOrPlayRecentNowPlayingSong(
  WidgetRef ref,
  RecentPageData snapshot,
  SmPlayerI18n i18n,
  int songId,
) {
  final mediaState = ref.read(mediaControlControllerProvider).state;
  final queueSongIds =
      effectiveNowPlayingSongIds(ref, snapshot.nowPlaying.songIds).toList();
  var queueIndex = queueSongIds.indexOf(songId);
  if (queueIndex == -1) {
    queueIndex = insertIndexAfterCurrentOccurrence(mediaState, queueSongIds);
    queueSongIds.insert(queueIndex, songId);
  }
  replaceNowPlayingQueueAndPlayIndexFromSongs(
    ref: ref,
    songs: snapshot.songs,
    persistedSongIds: snapshot.nowPlaying.songIds,
    i18n: i18n,
    songIds: queueSongIds,
    queueIndex: queueIndex,
    showQueueUpdatedNotification: false,
  );
  ref.invalidate(recentPageDataProvider);
}

void _playRecentNowPlayingNext(
  BuildContext context,
  WidgetRef ref,
  RecentPageData snapshot,
  SmPlayerI18n i18n,
  int songId,
) {
  final previousSongIds = effectiveNowPlayingSongIds(
    ref,
    snapshot.nowPlaying.songIds,
  );
  final queueSongIds = previousSongIds.toList();
  final insertIndex = insertIndexAfterCurrentOccurrence(
    ref.read(mediaControlControllerProvider).state,
    queueSongIds,
  );
  queueSongIds.insert(insertIndex, songId);
  setNowPlayingQueue(ref, queueSongIds);
  ref.invalidate(recentPageDataProvider);
  final song = snapshot.songs.singleWhere((song) => song.id == songId);
  showPlayNextUndoNotification(
    context: context,
    i18n: i18n,
    songTitle: song.title,
    onUndo: () {
      setNowPlayingQueue(ref, previousSongIds);
      ref.invalidate(recentPageDataProvider);
    },
  );
}
