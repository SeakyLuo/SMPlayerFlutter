import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';

List<int> currentNowPlayingSongIds(WidgetRef ref, LibraryContentData snapshot) {
  return effectiveNowPlayingSongIds(ref, snapshot.nowPlaying.songIds);
}

List<int> effectiveNowPlayingSongIds(
  WidgetRef ref,
  List<int> persistedSongIds,
) {
  return (ref.read(nowPlayingQueueOverrideProvider) ?? persistedSongIds)
      .toList();
}

Future<void> setNowPlayingQueue(WidgetRef ref, List<int> songIds) {
  final nextSongIds = songIds.toList();
  ref.read(nowPlayingQueueOverrideProvider.notifier).state = nextSongIds;
  return ref.read(libraryRepositoryProvider).replaceNowPlaying(nextSongIds);
}

Future<void> replaceNowPlayingQueueAndPlayIndex({
  required WidgetRef ref,
  required LibraryContentData snapshot,
  required SmPlayerI18n i18n,
  required List<int> songIds,
  required int queueIndex,
  MediaControlController? mediaController,
  double progressSeconds = 0,
  bool autoplay = true,
}) {
  final nextSongIds = songIds.toList();
  final persistQueue = setNowPlayingQueue(ref, nextSongIds);
  playQueueIndexFromSongs(
    ref: ref,
    songs: snapshot.songs,
    i18n: i18n,
    songIds: nextSongIds,
    queueIndex: queueIndex,
    mediaController: mediaController,
    progressSeconds: progressSeconds,
    autoplay: autoplay,
  );
  return persistQueue;
}

void playQueueIndex({
  required WidgetRef ref,
  required LibraryContentData snapshot,
  required SmPlayerI18n i18n,
  required List<int> songIds,
  required int queueIndex,
  MediaControlController? mediaController,
  double progressSeconds = 0,
  bool autoplay = true,
}) {
  playQueueIndexFromSongs(
    ref: ref,
    songs: snapshot.songs,
    i18n: i18n,
    songIds: songIds,
    queueIndex: queueIndex,
    mediaController: mediaController,
    progressSeconds: progressSeconds,
    autoplay: autoplay,
  );
}

void playQueueIndexFromSongs({
  required WidgetRef ref,
  required List<LibrarySong> songs,
  required SmPlayerI18n i18n,
  required List<int> songIds,
  required int queueIndex,
  MediaControlController? mediaController,
  double progressSeconds = 0,
  bool autoplay = true,
}) {
  final songsById = {for (final song in songs) song.id: song};
  final song = songsById[songIds[queueIndex]]!;
  final MediaControlController controller =
      mediaController ?? ref.read(mediaControlControllerProvider);
  controller.playTrack(
    mediaControlTrackForSong(song, i18n),
    durationSeconds: song.duration.toDouble(),
    queueIndex: queueIndex,
    progressSeconds: progressSeconds,
    autoplay: autoplay,
  );
}

int currentQueueIndexForPlaybackOccurrence(
  MediaControlState mediaState,
  List<int> songIds,
) {
  return currentPlaybackQueueIndex(
    songIds,
    mediaState.track.id,
    mediaState.selectedQueueIndex ?? -1,
  );
}

int insertIndexAfterCurrentOccurrence(
  MediaControlState mediaState,
  List<int> songIds,
) {
  final currentIndex = currentQueueIndexForPlaybackOccurrence(
    mediaState,
    songIds,
  );
  return currentIndex == -1 ? songIds.length : currentIndex + 1;
}
