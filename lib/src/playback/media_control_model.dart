import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

const defaultArtworkColorRgb = '91, 135, 182';
const previousTrackRestartThresholdSeconds = 5.0;
const volumePersistenceDebounce = Duration(milliseconds: 180);

enum PlaybackMode { once, repeat, repeatOne, shuffle }

enum PlaybackStallRecoveryAction { none, finishTrack, pauseAndRecover }

enum PlaybackStatus {
  idle,
  loading,
  ready,
  playing,
  paused,
  buffering,
  seeking,
}

enum PlaybackTransitionType {
  idle,
  loadTrack,
  ready,
  playRequested,
  playing,
  pause,
  paused,
  buffering,
  seeking,
  seeked,
  canPlay,
}

class PlaybackRuntimeSettings {
  const PlaybackRuntimeSettings({
    required this.volume,
    required this.isMuted,
    required this.mode,
  });

  final int volume;
  final bool isMuted;
  final PlaybackMode mode;
}

class PlaybackSettingsUpdate {
  const PlaybackSettingsUpdate({
    this.lastMusicIndex,
    this.volume,
    this.isMuted,
    this.mode,
    this.musicProgress,
  });

  final int? lastMusicIndex;
  final int? volume;
  final bool? isMuted;
  final PlaybackMode? mode;
  final double? musicProgress;
}

class MediaControlTrack {
  const MediaControlTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.isLoading,
    this.favorite = false,
  });

  const MediaControlTrack.empty()
    : id = null,
      title = '',
      artist = '',
      artworkUrl = '',
      isLoading = false,
      favorite = false;

  final int? id;
  final String title;
  final String artist;
  final String artworkUrl;
  final bool isLoading;
  final bool favorite;

  MediaControlTrack copyWith({
    int? id,
    String? title,
    String? artist,
    String? artworkUrl,
    bool? isLoading,
    bool? favorite,
  }) {
    return MediaControlTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      isLoading: isLoading ?? this.isLoading,
      favorite: favorite ?? this.favorite,
    );
  }
}

class MediaControlState {
  const MediaControlState({
    required this.track,
    required this.disabled,
    required this.isPlaying,
    this.playbackStatus = PlaybackStatus.idle,
    required this.volume,
    required this.isMuted,
    required this.mode,
    required this.progressSeconds,
    required this.durationSeconds,
    required this.isProgressSeeking,
    this.selectedQueueIndex,
    this.playbackNoticeKey,
  });

  const MediaControlState.empty()
    : track = const MediaControlTrack.empty(),
      selectedQueueIndex = null,
      playbackNoticeKey = null,
      disabled = true,
      isPlaying = false,
      playbackStatus = PlaybackStatus.idle,
      volume = 50,
      isMuted = false,
      mode = PlaybackMode.once,
      progressSeconds = 0,
      durationSeconds = 0,
      isProgressSeeking = false;

  final MediaControlTrack track;
  final int? selectedQueueIndex;
  final String? playbackNoticeKey;
  final bool disabled;
  final bool isPlaying;
  final PlaybackStatus playbackStatus;
  final int volume;
  final bool isMuted;
  final PlaybackMode mode;
  final double progressSeconds;
  final double durationSeconds;
  final bool isProgressSeeking;

  PlaybackRuntimeSettings get playbackRuntimeSettings {
    return PlaybackRuntimeSettings(
      volume: volume,
      isMuted: isMuted,
      mode: mode,
    );
  }

  MediaControlState copyWith({
    MediaControlTrack? track,
    int? selectedQueueIndex,
    bool clearSelectedQueueIndex = false,
    bool? disabled,
    bool? isPlaying,
    PlaybackStatus? playbackStatus,
    int? volume,
    bool? isMuted,
    PlaybackMode? mode,
    double? progressSeconds,
    double? durationSeconds,
    bool? isProgressSeeking,
    String? playbackNoticeKey,
    bool clearPlaybackNotice = false,
  }) {
    return MediaControlState(
      track: track ?? this.track,
      selectedQueueIndex:
          clearSelectedQueueIndex
              ? null
              : selectedQueueIndex ?? this.selectedQueueIndex,
      playbackNoticeKey:
          clearPlaybackNotice
              ? null
              : playbackNoticeKey ?? this.playbackNoticeKey,
      disabled: disabled ?? this.disabled,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackStatus: playbackStatus ?? this.playbackStatus,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      mode: mode ?? this.mode,
      progressSeconds: progressSeconds ?? this.progressSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isProgressSeeking: isProgressSeeking ?? this.isProgressSeeking,
    );
  }
}

class MediaControlController extends ChangeNotifier {
  MediaControlController([
    MediaControlState? initialState,
    ValueChanged<PlaybackSettingsUpdate>? onPlaybackSettingsUpdate,
  ]) : _state = initialState ?? const MediaControlState.empty(),
       _onPlaybackSettingsUpdate = onPlaybackSettingsUpdate;

  MediaControlState _state;
  final ValueChanged<PlaybackSettingsUpdate>? _onPlaybackSettingsUpdate;
  Timer? _volumePersistenceTimer;
  PlaybackSettingsUpdate? _pendingVolumePersistence;

  MediaControlState get state => _state;

  void _setState(MediaControlState state) {
    final status = state.playbackStatus;
    final isBackendLoading =
        status == PlaybackStatus.loading || status == PlaybackStatus.buffering;
    _state = state.copyWith(
      track: state.track.copyWith(isLoading: isBackendLoading),
    );
  }

  void applyPlaybackRuntimeSettings(PlaybackRuntimeSettings settings) {
    _state = _state.copyWith(
      volume: settings.volume,
      isMuted: settings.isMuted,
      mode: settings.mode,
    );
    notifyListeners();
  }

  void loadTrack(MediaControlTrack track, {double durationSeconds = 0}) {
    _setState(
      MediaControlState(
        track: track,
        selectedQueueIndex: null,
        disabled: track.id == null,
        isPlaying: false,
        playbackStatus:
            track.id == null ? PlaybackStatus.idle : PlaybackStatus.loading,
        progressSeconds: 0,
        durationSeconds: durationSeconds,
        isProgressSeeking: false,
        volume: _state.volume,
        isMuted: _state.isMuted,
        mode: _state.mode,
        playbackNoticeKey: null,
      ),
    );
    notifyListeners();
  }

  void playTrack(
    MediaControlTrack track, {
    required double durationSeconds,
    int? queueIndex,
    double progressSeconds = 0,
    bool autoplay = true,
  }) {
    final nextProgress = progressSeconds.clamp(0, durationSeconds).toDouble();
    _setState(
      MediaControlState(
        track: track,
        selectedQueueIndex: queueIndex,
        disabled: track.id == null,
        isPlaying: autoplay && track.id != null,
        playbackStatus:
            track.id == null ? PlaybackStatus.idle : PlaybackStatus.loading,
        progressSeconds: nextProgress,
        durationSeconds: durationSeconds,
        isProgressSeeking: false,
        volume: _state.volume,
        isMuted: _state.isMuted,
        mode: _state.mode,
        playbackNoticeKey: null,
      ),
    );
    notifyListeners();
  }

  void onTogglePlayPause() {
    if (_state.disabled) {
      return;
    }

    final nextPlaying = !_state.isPlaying;
    _setState(
      _state.copyWith(
        isPlaying: nextPlaying,
        playbackStatus: transitionPlaybackStatus(
          _state.playbackStatus,
          nextPlaying
              ? PlaybackTransitionType.playRequested
              : PlaybackTransitionType.pause,
        ),
      ),
    );
    notifyListeners();
  }

  void setPlaybackActive(bool isPlaying) {
    final nextStatus = transitionPlaybackStatus(
      _state.playbackStatus,
      isPlaying ? PlaybackTransitionType.playing : PlaybackTransitionType.pause,
    );
    if (_state.disabled ||
        (_state.isPlaying == isPlaying &&
            _state.playbackStatus == nextStatus)) {
      return;
    }

    _setState(
      _state.copyWith(
        isPlaying: isPlaying,
        playbackStatus: nextStatus,
        clearPlaybackNotice: true,
      ),
    );
    notifyListeners();
  }

  void setTrackLoading(bool isLoading, {bool buffering = false}) {
    final nextStatus =
        isLoading
            ? buffering
                ? PlaybackStatus.buffering
                : PlaybackStatus.loading
            : _state.isPlaying
            ? PlaybackStatus.playing
            : PlaybackStatus.ready;
    if (_state.disabled && nextStatus != PlaybackStatus.idle) {
      return;
    }
    if (_state.track.isLoading == isLoading &&
        _state.playbackStatus == nextStatus) {
      return;
    }

    _setState(
      _state.copyWith(
        playbackStatus: nextStatus,
        clearPlaybackNotice: isLoading,
      ),
    );
    notifyListeners();
  }

  void setPlaybackLoadFailed() {
    if (_state.disabled) {
      return;
    }

    _setState(
      _state.copyWith(
        track: _state.track.copyWith(isLoading: false),
        isPlaying: false,
        playbackStatus: PlaybackStatus.paused,
        clearPlaybackNotice: true,
      ),
    );
    notifyListeners();
  }

  void setPlaybackRuntimeFailed(double progressSeconds) {
    if (_state.disabled) {
      return;
    }

    final nextProgress =
        progressSeconds.clamp(0, _state.durationSeconds).toDouble();
    _setState(
      _state.copyWith(
        track: _state.track.copyWith(isLoading: false),
        isPlaying: false,
        playbackStatus: PlaybackStatus.paused,
        progressSeconds: nextProgress,
        clearPlaybackNotice: true,
      ),
    );
    notifyListeners();
    _onPlaybackSettingsUpdate?.call(
      PlaybackSettingsUpdate(musicProgress: nextProgress),
    );
  }

  void setPlaybackNotice(String noticeKey) {
    if (_state.disabled) {
      return;
    }

    _setState(_state.copyWith(playbackNoticeKey: noticeKey));
    notifyListeners();
  }

  void syncPlaybackProgress(double progressSeconds, {double? durationSeconds}) {
    final nextDuration = durationSeconds ?? _state.durationSeconds;
    final nextProgress = progressSeconds.clamp(0, nextDuration).toDouble();
    if (_state.progressSeconds == nextProgress &&
        _state.durationSeconds == nextDuration) {
      return;
    }

    _setState(
      _state.copyWith(
        progressSeconds: nextProgress,
        durationSeconds: nextDuration,
      ),
    );
    notifyListeners();
  }

  void completePlayback() {
    if (_state.disabled) {
      return;
    }

    _setState(
      _state.copyWith(
        isPlaying: false,
        playbackStatus: PlaybackStatus.paused,
        progressSeconds: _state.durationSeconds,
      ),
    );
    notifyListeners();
  }

  void onPrevious() {
    if (_state.disabled) {
      return;
    }

    _setState(_state.copyWith(progressSeconds: 0));
    notifyListeners();
  }

  void onNext() {
    if (_state.disabled) {
      return;
    }

    _setState(_state.copyWith(progressSeconds: 0));
    notifyListeners();
  }

  void onStop() {
    if (_state.disabled) {
      return;
    }

    _setState(
      _state.copyWith(isPlaying: false, playbackStatus: PlaybackStatus.paused),
    );
    notifyListeners();
    _onPlaybackSettingsUpdate?.call(
      PlaybackSettingsUpdate(musicProgress: _state.progressSeconds),
    );
  }

  void onSeek(double seconds) {
    final nextProgress = seconds.clamp(0, _state.durationSeconds).toDouble();
    _setState(
      _state.copyWith(
        progressSeconds: nextProgress,
        playbackStatus: PlaybackStatus.seeking,
      ),
    );
    notifyListeners();
    _onPlaybackSettingsUpdate?.call(
      PlaybackSettingsUpdate(musicProgress: nextProgress),
    );
  }

  void onBeginSeek() {
    _setState(
      _state.copyWith(
        isProgressSeeking: true,
        playbackStatus: PlaybackStatus.seeking,
      ),
    );
    notifyListeners();
  }

  void onEndSeek() {
    _setState(
      _state.copyWith(
        isProgressSeeking: false,
        playbackStatus: transitionPlaybackStatus(
          _state.playbackStatus,
          PlaybackTransitionType.seeked,
          paused: !_state.isPlaying,
        ),
      ),
    );
    notifyListeners();
  }

  void onVolumeChange(int volume) {
    final nextVolume = volume.clamp(0, 100);
    final nextMuted = nextVolume > 0 && _state.isMuted ? false : _state.isMuted;
    final mutedChanged = nextMuted != _state.isMuted;
    _state = _state.copyWith(volume: nextVolume, isMuted: nextMuted);
    notifyListeners();
    _scheduleVolumePersistence(
      PlaybackSettingsUpdate(
        volume: nextVolume,
        isMuted: mutedChanged ? nextMuted : null,
      ),
    );
  }

  void onToggleMute() {
    _flushVolumePersistence();
    final nextMuted = !_state.isMuted;
    _state = _state.copyWith(isMuted: nextMuted);
    notifyListeners();
    _onPlaybackSettingsUpdate?.call(PlaybackSettingsUpdate(isMuted: nextMuted));
  }

  void onToggleShuffle() {
    _flushVolumePersistence();
    final nextMode =
        _state.mode == PlaybackMode.shuffle
            ? PlaybackMode.once
            : PlaybackMode.shuffle;
    _state = _state.copyWith(mode: nextMode);
    notifyListeners();
    _onPlaybackSettingsUpdate?.call(PlaybackSettingsUpdate(mode: nextMode));
  }

  void setSelectedQueueIndex(int? queueIndex) {
    _state = _state.copyWith(
      selectedQueueIndex: queueIndex,
      clearSelectedQueueIndex: queueIndex == null,
    );
    notifyListeners();
  }

  void onToggleRepeat() {
    _flushVolumePersistence();
    final nextMode =
        _state.mode == PlaybackMode.repeat
            ? PlaybackMode.once
            : PlaybackMode.repeat;
    _state = _state.copyWith(mode: nextMode);
    notifyListeners();
    _onPlaybackSettingsUpdate?.call(PlaybackSettingsUpdate(mode: nextMode));
  }

  void onToggleRepeatOne() {
    _flushVolumePersistence();
    final nextMode =
        _state.mode == PlaybackMode.repeatOne
            ? PlaybackMode.once
            : PlaybackMode.repeatOne;
    _state = _state.copyWith(mode: nextMode);
    notifyListeners();
    _onPlaybackSettingsUpdate?.call(PlaybackSettingsUpdate(mode: nextMode));
  }

  void cyclePlaybackMode() {
    _flushVolumePersistence();
    final nextMode = getNextPlaybackMode(_state.mode);
    _state = _state.copyWith(mode: nextMode);
    notifyListeners();
    _onPlaybackSettingsUpdate?.call(PlaybackSettingsUpdate(mode: nextMode));
  }

  void cycleRepeatMode() {
    _flushVolumePersistence();
    final nextMode = getNextRepeatCycleMode(_state.mode);
    _state = _state.copyWith(mode: nextMode);
    notifyListeners();
    _onPlaybackSettingsUpdate?.call(PlaybackSettingsUpdate(mode: nextMode));
  }

  void _scheduleVolumePersistence(PlaybackSettingsUpdate update) {
    final pendingUpdate = _pendingVolumePersistence;
    _pendingVolumePersistence =
        pendingUpdate == null
            ? update
            : PlaybackSettingsUpdate(
              volume: update.volume ?? pendingUpdate.volume,
              isMuted: update.isMuted ?? pendingUpdate.isMuted,
            );
    _volumePersistenceTimer?.cancel();
    _volumePersistenceTimer = Timer(volumePersistenceDebounce, () {
      _flushVolumePersistence();
    });
  }

  void _flushVolumePersistence() {
    final update = _pendingVolumePersistence;
    if (update == null) {
      return;
    }
    _pendingVolumePersistence = null;
    _volumePersistenceTimer?.cancel();
    _volumePersistenceTimer = null;
    _onPlaybackSettingsUpdate?.call(update);
  }

  @override
  void dispose() {
    _flushVolumePersistence();
    super.dispose();
  }

  void onToggleFavorite() {
    if (_state.track.id == null) {
      return;
    }

    _state = _state.copyWith(
      track: _state.track.copyWith(favorite: !_state.track.favorite),
    );
    notifyListeners();
  }
}

PlaybackStatus transitionPlaybackStatus(
  PlaybackStatus currentStatus,
  PlaybackTransitionType transition, {
  bool paused = false,
  bool pendingAutoplay = false,
}) {
  return switch (transition) {
    PlaybackTransitionType.idle => PlaybackStatus.idle,
    PlaybackTransitionType.loadTrack => PlaybackStatus.loading,
    PlaybackTransitionType.ready => PlaybackStatus.ready,
    PlaybackTransitionType.playRequested => PlaybackStatus.loading,
    PlaybackTransitionType.playing => PlaybackStatus.playing,
    PlaybackTransitionType.pause =>
      currentStatus == PlaybackStatus.loading ||
              currentStatus == PlaybackStatus.seeking ||
              currentStatus == PlaybackStatus.buffering
          ? currentStatus
          : PlaybackStatus.paused,
    PlaybackTransitionType.paused => PlaybackStatus.paused,
    PlaybackTransitionType.buffering => PlaybackStatus.buffering,
    PlaybackTransitionType.seeking => PlaybackStatus.seeking,
    PlaybackTransitionType.seeked =>
      paused ? PlaybackStatus.paused : PlaybackStatus.playing,
    PlaybackTransitionType.canPlay =>
      pendingAutoplay
          ? currentStatus
          : paused
          ? PlaybackStatus.ready
          : PlaybackStatus.playing,
  };
}

PlaybackMode getNextPlaybackMode(PlaybackMode mode) {
  return switch (mode) {
    PlaybackMode.once => PlaybackMode.shuffle,
    PlaybackMode.shuffle => PlaybackMode.repeat,
    PlaybackMode.repeat => PlaybackMode.repeatOne,
    PlaybackMode.repeatOne => PlaybackMode.once,
  };
}

PlaybackMode getNextRepeatCycleMode(PlaybackMode mode) {
  return switch (mode) {
    PlaybackMode.once || PlaybackMode.shuffle => PlaybackMode.repeat,
    PlaybackMode.repeat => PlaybackMode.repeatOne,
    PlaybackMode.repeatOne => PlaybackMode.once,
  };
}

List<int> normalizePlaybackQueueSongIds(
  List<int> songIds,
  Iterable<int> librarySongIds,
) {
  final songIdsInLibrary = librarySongIds.toSet();
  return songIds.where(songIdsInLibrary.contains).toList();
}

List<int> removePlaybackQueueRange(
  List<int> songIds,
  int startIndex,
  int count,
) {
  return [...songIds.take(startIndex), ...songIds.skip(startIndex + count)];
}

int? nextQueueIndexForPlayback({
  required int queueLength,
  required int currentIndex,
  required PlaybackMode mode,
  required bool forward,
  required bool automatic,
}) {
  if (queueLength <= 0) {
    return null;
  }

  if (currentIndex < 0) {
    if (forward) {
      return 0;
    }
    if (mode == PlaybackMode.repeat || mode == PlaybackMode.shuffle) {
      return queueLength - 1;
    }
    return null;
  }

  final boundedCurrentIndex = currentIndex.clamp(0, queueLength - 1).toInt();
  if (mode == PlaybackMode.repeatOne && automatic) {
    return boundedCurrentIndex;
  }

  final nextIndex = boundedCurrentIndex + (forward ? 1 : -1);
  if (nextIndex >= 0 && nextIndex < queueLength) {
    return nextIndex;
  }

  if (mode == PlaybackMode.repeat || mode == PlaybackMode.shuffle) {
    return forward ? 0 : queueLength - 1;
  }

  return null;
}

bool shouldRestartCurrentTrackForPrevious({
  required double progressSeconds,
  required int queueLength,
  required bool restartAfterThresholdEnabled,
}) {
  if (!restartAfterThresholdEnabled) {
    return false;
  }
  return progressSeconds > previousTrackRestartThresholdSeconds ||
      queueLength == 1;
}

List<int> shuffleNextRoundSongIds(
  List<int> songIds,
  int? activeTrackId, [
  Random? random,
]) {
  final shuffledSongIds = songIds.toList()..shuffle(random);
  if (shuffledSongIds.length > 1 && shuffledSongIds.first == activeTrackId) {
    shuffledSongIds.add(shuffledSongIds.removeAt(0));
  }
  return shuffledSongIds;
}

List<int> shufflePlaybackQueueForCurrentTrack(
  List<int> songIds,
  int? activeTrackId, [
  Random? random,
]) {
  final activeIndex = currentPlaybackQueueIndex(songIds, activeTrackId);
  if (activeIndex == -1) {
    return songIds;
  }
  final activeSongId = songIds[activeIndex];
  final shuffledSongIds = songIds.toList()..shuffle(random);
  final shuffledActiveIndex = shuffledSongIds.indexOf(activeSongId);
  if (shuffledActiveIndex > -1) {
    shuffledSongIds.removeAt(shuffledActiveIndex);
    shuffledSongIds.insert(0, activeSongId);
  }
  return shuffledSongIds;
}

int? getNextRecoverableTrackId({
  required List<int> playbackSongIds,
  required int? activeTrackId,
  required int activeQueueIndex,
  required PlaybackMode mode,
  required Set<int> failedTrackIds,
}) {
  final activeIndex = currentPlaybackQueueIndex(
    playbackSongIds,
    activeTrackId,
    activeQueueIndex,
  );
  final shouldWrap =
      mode == PlaybackMode.repeat || mode == PlaybackMode.shuffle;
  final orderedSongIds =
      shouldWrap
          ? [
            ...playbackSongIds.skip(activeIndex + 1),
            ...playbackSongIds.take(activeIndex + 1),
          ]
          : playbackSongIds.skip(activeIndex + 1);
  for (final songId in orderedSongIds) {
    if (!failedTrackIds.contains(songId)) {
      return songId;
    }
  }
  return null;
}

int currentPlaybackQueueIndex(
  List<int> songIds,
  int? currentTrackId, [
  int currentTrackIndex = -1,
]) {
  if (currentTrackId == null) {
    return -1;
  }
  if (currentTrackIndex > -1 &&
      currentTrackIndex < songIds.length &&
      songIds[currentTrackIndex] == currentTrackId) {
    return currentTrackIndex;
  }
  return songIds.indexOf(currentTrackId);
}

PlaybackStallRecoveryAction stalledPlaybackRecoveryAction({
  required bool isPlaying,
  required bool isUserSeeking,
  required double currentProgressSeconds,
  required double lastProgressSeconds,
  required Duration stalledFor,
  required double durationSeconds,
  double progressEpsilonSeconds = 0.05,
  Duration stallTimeout = const Duration(seconds: 8),
  double finishThresholdSeconds = 0.5,
}) {
  if (!isPlaying || isUserSeeking) {
    return PlaybackStallRecoveryAction.none;
  }
  if ((currentProgressSeconds - lastProgressSeconds).abs() >
      progressEpsilonSeconds) {
    return PlaybackStallRecoveryAction.none;
  }
  if (stalledFor < stallTimeout) {
    return PlaybackStallRecoveryAction.none;
  }
  if (durationSeconds > 0 &&
      durationSeconds - currentProgressSeconds <= finishThresholdSeconds) {
    return PlaybackStallRecoveryAction.finishTrack;
  }
  return PlaybackStallRecoveryAction.pauseAndRecover;
}

String getPlaybackModeName(PlaybackMode mode) {
  return switch (mode) {
    PlaybackMode.shuffle => '随机',
    PlaybackMode.repeat => '循环',
    PlaybackMode.repeatOne => '单曲循环',
    PlaybackMode.once => '列表',
  };
}

String getShuffleTitle(PlaybackMode mode) {
  return mode == PlaybackMode.shuffle ? '随机播放：打开' : '随机播放：关闭';
}

String getRepeatTitle(PlaybackMode mode) {
  return mode == PlaybackMode.repeat ? '循环播放：打开' : '循环播放：关闭';
}

String getRepeatOneTitle(PlaybackMode mode) {
  return mode == PlaybackMode.repeatOne ? '单曲循环：打开' : '单曲循环：关闭';
}

String formatDuration(double seconds) {
  final duration = Duration(seconds: seconds.round());
  final minutes = duration.inMinutes.remainder(60).toString();
  final remainingSeconds = duration.inSeconds
      .remainder(60)
      .toString()
      .padLeft(2, '0');

  if (duration.inHours > 0) {
    return '${duration.inHours}:${minutes.padLeft(2, '0')}:$remainingSeconds';
  }

  return '$minutes:$remainingSeconds';
}
