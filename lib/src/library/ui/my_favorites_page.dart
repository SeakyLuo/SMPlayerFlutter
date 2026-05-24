import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';

class MyFavoritesPage extends ConsumerWidget {
  const MyFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(libraryViewDataProvider);

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
      data: (snapshot) {
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
        final mediaControl = ref.watch(mediaControlControllerProvider).state;
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
            selectedTrackId: mediaControl.track.id,
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
              _playTrack(
                ref,
                snapshot,
                i18n,
                songId,
                songs.map((song) => song.id).toList(),
              );
            },
            onPlayNext: (songId) {
              _playNext(ref, snapshot, songId);
            },
            onTogglePlayPause:
                ref.read(mediaControlControllerProvider).onTogglePlayPause,
            onAddSongToPlaylist: (playlistId, songId) {
              ref
                  .read(libraryRepositoryProvider)
                  .addSongToPlaylist(playlistId, songId);
              ref.invalidate(libraryViewDataProvider);
            },
            onAddSongsToPlaylist: (playlistId, songIds) {
              ref
                  .read(libraryRepositoryProvider)
                  .addSongsToPlaylist(playlistId, songIds);
              ref.invalidate(libraryViewDataProvider);
            },
            onRemoveSongs: (songIds) async {
              await ref
                  .read(libraryRepositoryProvider)
                  .setSongsFavorite(songIds, false);
              ref.invalidate(libraryViewDataProvider);
            },
            onClear: () {
              final songIds = songs.map((song) => song.id).toList();
              ref
                  .read(libraryRepositoryProvider)
                  .setSongsFavorite(songIds, false);
              ref.invalidate(libraryViewDataProvider);
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
              ref.invalidate(libraryViewDataProvider);
            },
            onSortSongs: (songIds, sortCriterion) {
              ref
                  .read(libraryRepositoryProvider)
                  .reorderPlaylistSongs(
                    snapshot.favoritePlaylistId,
                    songIds,
                    sortCriterion,
                  );
              ref.invalidate(libraryViewDataProvider);
            },
            onArtistClick: (artist) {
              context.go('/artists?artist=${Uri.encodeQueryComponent(artist)}');
            },
            onAlbumClick: (album) {
              context.go('/albums?album=${Uri.encodeQueryComponent(album)}');
            },
            onToggleFavorite: (songId, favorite) {
              ref
                  .read(libraryRepositoryProvider)
                  .setSongFavorite(songId, favorite);
              ref.invalidate(libraryViewDataProvider);
            },
          ),
        );
      },
    );
  }
}

void _playTrack(
  WidgetRef ref,
  LibraryViewData snapshot,
  SmPlayerI18n i18n,
  int trackId,
  List<int> queueSongIds,
) {
  final songsById = {for (final song in snapshot.songs) song.id: song};
  final song = songsById[trackId]!;
  ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
  ref
      .read(mediaControlControllerProvider)
      .playTrack(
        mediaControlTrackForSong(song, i18n),
        durationSeconds: song.duration.toDouble(),
        queueIndex: queueSongIds.indexOf(trackId),
      );
  ref.invalidate(libraryViewDataProvider);
}

void _playNext(WidgetRef ref, LibraryViewData snapshot, int songId) {
  final queueSongIds = snapshot.nowPlaying.songIds.toList();
  final currentTrackId =
      ref.read(mediaControlControllerProvider).state.track.id;
  final currentIndex =
      currentTrackId == null ? -1 : queueSongIds.indexOf(currentTrackId);
  queueSongIds.insert(currentIndex < 0 ? 0 : currentIndex + 1, songId);
  ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
  ref.invalidate(libraryViewDataProvider);
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
