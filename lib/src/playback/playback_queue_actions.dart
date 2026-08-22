import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';

var _replaceQueueRevision = 0;

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

void syncMediaControlForQueueChange({
  required MediaControlController mediaController,
  required List<int> currentSongIds,
  required List<int> nextSongIds,
}) {
  final mediaState = mediaController.state;
  final trackId = mediaState.track.id;
  if (trackId == null) {
    return;
  }

  final currentIndex =
      mediaState.selectedQueueIndex ??
      currentSongIds.indexWhere((songId) => songId == trackId);
  if (currentIndex < 0 || currentIndex >= currentSongIds.length) {
    final nextIndex = nextSongIds.indexWhere((songId) => songId == trackId);
    if (nextIndex > -1) {
      mediaController.setSelectedQueueIndex(nextIndex);
    } else {
      mediaController.clearTrack();
    }
    return;
  }

  final nextIndex = matchingQueueIndexByOccurrence(
    trackId,
    currentSongIds,
    currentIndex,
    nextSongIds,
  );
  if (nextIndex == null) {
    mediaController.clearTrack();
    return;
  }
  if (mediaState.selectedQueueIndex != nextIndex) {
    mediaController.setSelectedQueueIndex(nextIndex);
  }
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
}) async {
  await replaceNowPlayingQueueAndPlayIndexFromSongs(
    ref: ref,
    songs: snapshot.songs,
    persistedSongIds: snapshot.nowPlaying.songIds,
    i18n: i18n,
    songIds: songIds,
    queueIndex: queueIndex,
    mediaController: mediaController,
    progressSeconds: progressSeconds,
    autoplay: autoplay,
  );
}

Future<void> replaceNowPlayingQueueAndPlayIndexFromSongs({
  required WidgetRef ref,
  required List<LibrarySong> songs,
  required List<int> persistedSongIds,
  required SmPlayerI18n i18n,
  required List<int> songIds,
  required int queueIndex,
  MediaControlController? mediaController,
  double progressSeconds = 0,
  bool autoplay = true,
}) async {
  final previousSongIds = effectiveNowPlayingSongIds(ref, persistedSongIds);
  final MediaControlController controller =
      mediaController ?? ref.read(mediaControlControllerProvider);
  final previousMediaState = controller.state;
  final queueOverrideController = ref.read(
    nowPlayingQueueOverrideProvider.notifier,
  );
  final repository = ref.read(libraryRepositoryProvider);
  final nextSongIds = songIds.toList();
  final queueChanged = !listEquals(previousSongIds, nextSongIds);
  final replaceRevision = queueChanged ? ++_replaceQueueRevision : 0;
  if (queueChanged) {
    hideAppNotification();
  }
  queueOverrideController.state = nextSongIds;
  final persistQueue = repository.replaceNowPlaying(nextSongIds);
  playQueueIndexFromSongs(
    ref: ref,
    songs: songs,
    i18n: i18n,
    songIds: nextSongIds,
    queueIndex: queueIndex,
    mediaController: controller,
    progressSeconds: progressSeconds,
    autoplay: autoplay,
  );
  await persistQueue;
  if (!queueChanged ||
      replaceRevision != _replaceQueueRevision ||
      !listEquals(queueOverrideController.state, nextSongIds)) {
    return;
  }

  showUndoableAppNotification(
    i18n: i18n,
    message: i18n.t('notification.nowPlayingUpdated'),
    onUndo: () async {
      queueOverrideController.state = previousSongIds;
      final restoreQueue = repository.replaceNowPlaying(previousSongIds);
      if (previousMediaState.track.id == null) {
        controller.clearTrack();
      } else {
        controller.playTrack(
          previousMediaState.track,
          durationSeconds: previousMediaState.durationSeconds,
          queueIndex: previousMediaState.selectedQueueIndex,
          progressSeconds: previousMediaState.progressSeconds,
          autoplay: previousMediaState.isPlaying,
        );
      }
      await restoreQueue;
    },
  );
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

int? matchingQueueIndexByOccurrence(
  int trackId,
  List<int> currentSongIds,
  int currentIndex,
  List<int> nextSongIds,
) {
  var occurrence = 0;
  for (var index = 0; index <= currentIndex; index += 1) {
    if (currentSongIds[index] == trackId) {
      occurrence += 1;
    }
  }
  if (occurrence == 0) {
    return null;
  }
  var nextOccurrence = 0;
  for (var index = 0; index < nextSongIds.length; index += 1) {
    if (nextSongIds[index] != trackId) {
      continue;
    }
    nextOccurrence += 1;
    if (nextOccurrence == occurrence) {
      return index;
    }
  }
  return null;
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

void insertOrPlayNowPlayingSong({
  required WidgetRef ref,
  required LibraryContentData snapshot,
  required SmPlayerI18n i18n,
  required int songId,
}) {
  final mediaState = ref.read(mediaControlControllerProvider).state;
  final queueSongIds = currentNowPlayingSongIds(ref, snapshot);
  var queueIndex = queueSongIds.indexOf(songId);
  if (queueIndex == -1) {
    queueIndex = insertIndexAfterCurrentOccurrence(mediaState, queueSongIds);
    queueSongIds.insert(queueIndex, songId);
  }
  replaceNowPlayingQueueAndPlayIndex(
    ref: ref,
    snapshot: snapshot,
    i18n: i18n,
    songIds: queueSongIds,
    queueIndex: queueIndex,
  );
}
