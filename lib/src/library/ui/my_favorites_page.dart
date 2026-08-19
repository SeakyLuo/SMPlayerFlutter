import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_control.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/playback_queue_actions.dart';

class MyFavoritesPage extends ConsumerWidget {
  const MyFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(libraryContentDataProvider);
    final favoriteOverrides = ref.watch(libraryFavoriteOverridesProvider);
    final songOverrides = ref.watch(librarySongOverridesProvider);

    if (i18nValue.isLoading || snapshotValue.isLoading) {
      return const _FavoritesPagePanel(child: SmPlayerLoadingState());
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const _FavoritesPagePanel(child: SizedBox.shrink());
    }

    return snapshotValue.when(
      loading: () => const _FavoritesPagePanel(child: SmPlayerLoadingState()),
      error:
          (_, _) => _FavoritesPagePanel(
            child: Text(
              i18n.t('collection.noFavorites'),
              style: const TextStyle(color: _FavoritesColors.textMuted),
            ),
          ),
      data: (rawSnapshot) {
        final snapshot = applyLibraryFavoriteOverrides(
          rawSnapshot,
          favoriteOverrides,
          songOverrides,
        );
        final favoritesPlaylist =
            snapshot.playlists
                .where((playlist) => playlist.id == snapshot.favoritePlaylistId)
                .firstOrNull;
        final favoriteSongIdSet =
            favoritesPlaylist?.songIds.toSet() ??
            snapshot.songs
                .where((song) => song.favorite)
                .map((song) => song.id)
                .toSet();
        final songsById = {for (final song in snapshot.songs) song.id: song};
        final songs =
            favoriteSongIdSet
                .map((songId) => songsById[songId])
                .whereType<LibrarySong>()
                .toList();
        final mediaControl = ref.watch(
          mediaControlControllerProvider.select(
            (controller) => (
              trackId: controller.state.track.id,
              isPlaying: controller.state.isPlaying,
            ),
          ),
        );
        final artworkUrl =
            songs
                .where((song) => song.thumbnailPath.isNotEmpty)
                .map((song) => song.thumbnailPath)
                .firstOrNull ??
            '';

        return SmPlayerI18nScope(
          i18n: i18n,
          child: HeaderedPlaylistControl(
            key: const ValueKey('HeaderedPlaylist.Favorites'),
            type: HeaderedPlaylistType.favorites,
            routeLocation: '/favorites',
            title: i18n.t('common.myFavorites'),
            songs: songs,
            selectedTrackId: mediaControl.trackId,
            isPlaying: mediaControl.isPlaying,
            playlists: snapshot.playlists,
            favoritePlaylistId: snapshot.favoritePlaylistId,
            artworkUrl: artworkUrl,
            removable: true,
            showAlbum: true,
            canClear: songs.isNotEmpty,
            canSetPreferred: true,
            sortCriterion:
                favoritesPlaylist?.sortCriterion ?? PlaylistSortCriterion.title,
            preferenceType: 'my-favorites',
            preferenceItemId: '6',
            onPlayTrack: (trackId, queueSongIds) {
              _playTrack(ref, snapshot, i18n, trackId, queueSongIds);
            },
            onMoveToMusicOrPlay: (songId) {
              insertOrPlayNowPlayingSong(
                ref: ref,
                snapshot: snapshot,
                i18n: i18n,
                songId: songId,
              );
            },
            onPlayNext: (songId) {
              _playNext(context, ref, snapshot, songId);
            },
            onTogglePlayPause:
                ref.read(mediaControlControllerProvider).onTogglePlayPause,
            onAddSongToPlaylist: (playlistId, songId) {
              unawaited(addSongsToPlaylist(ref, playlistId, [songId]));
            },
            onAddSongsToPlaylist: (playlistId, songIds) {
              unawaited(addSongsToPlaylist(ref, playlistId, songIds));
            },
            onRemoveSongs: (songIds) async {
              await setSongsFavorite(ref, songIds, false);
            },
            onClear: () async {
              final songIds = songs.map((song) => song.id).toList();
              await setSongsFavorite(ref, songIds, false);
            },
            onSetPreferred: (level) async {
              await ref
                  .read(libraryRepositoryProvider)
                  .addPreferenceItem(
                    'my-favorites',
                    '6',
                    i18n.t('common.myFavorites'),
                    level,
                  );
            },
            onSortSongs: (songIds, sortCriterion) {
              unawaited(
                ref
                    .read(libraryRepositoryProvider)
                    .reorderPlaylistSongs(
                      snapshot.favoritePlaylistId,
                      songIds,
                      sortCriterion,
                    ),
              );
            },
            onArtistClick: (artist) {
              context.go('/artists?artist=${Uri.encodeQueryComponent(artist)}');
            },
            onAlbumClick: (album) {
              context.go('/albums?album=${Uri.encodeQueryComponent(album)}');
            },
            onToggleFavorite: (songId, favorite) {
              unawaited(setSongsFavorite(ref, [songId], favorite));
            },
          ),
        );
      },
    );
  }
}

void _playTrack(
  WidgetRef ref,
  LibraryContentData snapshot,
  SmPlayerI18n i18n,
  int trackId,
  List<int> queueSongIds,
) {
  replaceNowPlayingQueueAndPlayIndex(
    ref: ref,
    snapshot: snapshot,
    i18n: i18n,
    songIds: queueSongIds,
    queueIndex: queueSongIds.indexOf(trackId),
  );
}

void _playNext(
  BuildContext context,
  WidgetRef ref,
  LibraryContentData snapshot,
  int songId,
) {
  final previousSongIds = currentNowPlayingSongIds(ref, snapshot);
  final queueSongIds = previousSongIds.toList();
  final currentIndex = currentQueueIndexForPlaybackOccurrence(
    ref.read(mediaControlControllerProvider).state,
    queueSongIds,
  );
  queueSongIds.insert(currentIndex < 0 ? 0 : currentIndex + 1, songId);
  setNowPlayingQueue(ref, queueSongIds);
  final songsById = {for (final song in snapshot.songs) song.id: song};
  showPlayNextUndoNotification(
    context: context,
    i18n: context.smPlayerI18n,
    songTitle: songsById[songId]!.title,
    onUndo: () {
      setNowPlayingQueue(ref, previousSongIds);
    },
  );
}

class _FavoritesPagePanel extends StatelessWidget {
  const _FavoritesPagePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(child: child);
  }
}

class _FavoritesColors {
  const _FavoritesColors._();

  static const textMuted = Color(0xff607085);
}
