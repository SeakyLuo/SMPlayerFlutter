import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/album_artwork_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page_model.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_control.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_model.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart'
    as song_display;
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';

class AlbumDetailPage extends ConsumerStatefulWidget {
  const AlbumDetailPage({super.key, required this.albumName});

  final String albumName;

  @override
  ConsumerState<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends ConsumerState<AlbumDetailPage> {
  var _showArtworkDialog = false;

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(libraryContentDataProvider);

    if (i18nValue.isLoading || snapshotValue.isLoading) {
      return const _AlbumDetailPanel(child: SmPlayerLoadingState());
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const _AlbumDetailPanel(child: SizedBox.shrink());
    }

    return SmPlayerI18nScope(
      i18n: i18n,
      child: snapshotValue.when(
        loading: () => const _AlbumDetailPanel(child: SmPlayerLoadingState()),
        error:
            (_, _) => _AlbumDetailPanel(
              child: _AlbumDetailEmptyState(
                title: i18n.t('collection.albumNotFound'),
                message: i18n.t('collection.albumNotFoundCopy'),
              ),
            ),
        data: (snapshot) {
          final routeAlbumName = widget.albumName;
          final albumSongs =
              snapshot.songs
                  .where(
                    (song) =>
                        song_display.displayAlbum(song, i18n) == routeAlbumName,
                  )
                  .toList()
                ..sort(
                  (left, right) => compareArtistText(left.title, right.title),
                );

          if (routeAlbumName.isEmpty || albumSongs.isEmpty) {
            return _AlbumDetailPanel(
              child: _AlbumDetailEmptyState(
                title: i18n.t('collection.albumNotFound'),
                message: i18n.t('collection.albumNotFoundCopy'),
              ),
            );
          }

          final mediaControl = ref.watch(
            mediaControlControllerProvider.select(
              (controller) => (
                trackId: controller.state.track.id,
                isPlaying: controller.state.isPlaying,
              ),
            ),
          );
          final artworkSong =
              albumSongs
                  .where((song) => song.thumbnailPath.isNotEmpty)
                  .firstOrNull ??
              albumSongs.first;
          final artworkUrl = artworkSong.thumbnailPath;

          return Stack(
            children: [
              HeaderedPlaylistControl(
                type: HeaderedPlaylistType.album,
                routeLocation:
                    Uri(
                      path: '/albums',
                      queryParameters: {'album': routeAlbumName},
                    ).toString(),
                title: routeAlbumName,
                songs: albumSongs,
                selectedTrackId: mediaControl.trackId,
                isPlaying: mediaControl.isPlaying,
                playlists: snapshot.playlists,
                favoritePlaylistId: snapshot.favoritePlaylistId,
                artworkUrl: artworkUrl,
                showAlbum: false,
                canEditArtwork: true,
                canSetPreferred: true,
                preferenceType: 'album',
                preferenceItemId: routeAlbumName,
                onPlayTrack: (trackId, queueSongIds) {
                  _playTrack(ref, snapshot, i18n, trackId, queueSongIds);
                },
                onMoveToMusicOrPlay: (songId) {
                  _playTrack(
                    ref,
                    snapshot,
                    i18n,
                    songId,
                    albumSongs.map((song) => song.id).toList(),
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
                  ref.invalidate(libraryContentDataProvider);
                },
                onAddSongsToPlaylist: (playlistId, songIds) {
                  ref
                      .read(libraryRepositoryProvider)
                      .addSongsToPlaylist(playlistId, songIds);
                  ref.invalidate(libraryContentDataProvider);
                },
                onToggleFavorite: (songId, favorite) {
                  ref
                      .read(libraryRepositoryProvider)
                      .setSongFavorite(songId, favorite);
                  ref.invalidate(libraryContentDataProvider);
                },
                onRecordPlay: () {
                  ref
                      .read(libraryRepositoryProvider)
                      .recordAlbumPlayed(routeAlbumName);
                },
                onSetPreferred: (level) async {
                  await ref
                      .read(libraryRepositoryProvider)
                      .addPreferenceItem(
                        'album',
                        routeAlbumName,
                        getAlbumPreferenceDisplayName(
                          routeAlbumName,
                          albumSongs,
                          i18n,
                        ),
                        level,
                      );
                },
                onEditArtwork: () {
                  setState(() {
                    _showArtworkDialog = true;
                  });
                },
                onArtistClick: (artist) {
                  context.go(
                    '/artists?artist=${Uri.encodeQueryComponent(artist)}',
                  );
                },
                onAlbumClick: (album) {
                  context.go(
                    '/albums?album=${Uri.encodeQueryComponent(album)}',
                  );
                },
              ),
              if (_showArtworkDialog)
                AlbumArtworkDialog(
                  albumName: routeAlbumName,
                  artworkUrl: artworkUrl,
                  songId: artworkSong.id,
                  onClose: () {
                    setState(() {
                      _showArtworkDialog = false;
                    });
                  },
                  onSaved: () {
                    ref.invalidate(libraryContentDataProvider);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AlbumDetailPanel extends StatelessWidget {
  const _AlbumDetailPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SizedBox.expand(child: child),
    );
  }
}

class _AlbumDetailEmptyState extends StatelessWidget {
  const _AlbumDetailEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _AlbumDetailColors.emptyStateSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _AlbumDetailColors.emptyStateBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _AlbumDetailColors.textStrong,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Text(
                message,
                style: const TextStyle(
                  color: _AlbumDetailColors.textMuted,
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumDetailColors {
  const _AlbumDetailColors._();

  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const emptyStateSurface = Color(0x94ffffff);
  static const emptyStateBorder = Color(0x94ffffff);
}

void _playTrack(
  WidgetRef ref,
  LibraryContentData snapshot,
  SmPlayerI18n i18n,
  int trackId,
  List<int> queueSongIds,
) {
  final songsById = {for (final song in snapshot.songs) song.id: song};
  final song = songsById[trackId]!;
  unawaited(
    ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds),
  );
  ref
      .read(mediaControlControllerProvider)
      .playTrack(
        mediaControlTrackForSong(song, i18n),
        durationSeconds: song.duration.toDouble(),
        queueIndex: queueSongIds.indexOf(trackId),
      );
}

void _playNext(WidgetRef ref, LibraryContentData snapshot, int songId) {
  final queueSongIds = snapshot.nowPlaying.songIds.toList();
  final selectedQueueIndex =
      ref.read(mediaControlControllerProvider).state.selectedQueueIndex;
  final insertIndex =
      selectedQueueIndex != null && selectedQueueIndex < queueSongIds.length
          ? selectedQueueIndex + 1
          : queueSongIds.length;
  queueSongIds.insert(insertIndex, songId);
  ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
  ref.invalidate(libraryContentDataProvider);
}
