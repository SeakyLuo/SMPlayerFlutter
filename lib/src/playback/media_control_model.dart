import 'package:flutter/foundation.dart';

const defaultArtworkColorRgb = '91, 135, 182';

enum PlaybackMode { once, repeat, repeatOne, shuffle }

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
    required this.volume,
    required this.isMuted,
    required this.mode,
    required this.progressSeconds,
    required this.durationSeconds,
    required this.isProgressSeeking,
    this.selectedQueueIndex,
  });

  const MediaControlState.empty()
    : track = const MediaControlTrack.empty(),
      selectedQueueIndex = null,
      disabled = true,
      isPlaying = false,
      volume = 50,
      isMuted = false,
      mode = PlaybackMode.once,
      progressSeconds = 0,
      durationSeconds = 0,
      isProgressSeeking = false;

  final MediaControlTrack track;
  final int? selectedQueueIndex;
  final bool disabled;
  final bool isPlaying;
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
    bool? disabled,
    bool? isPlaying,
    int? volume,
    bool? isMuted,
    PlaybackMode? mode,
    double? progressSeconds,
    double? durationSeconds,
    bool? isProgressSeeking,
  }) {
    return MediaControlState(
      track: track ?? this.track,
      selectedQueueIndex: selectedQueueIndex ?? this.selectedQueueIndex,
      disabled: disabled ?? this.disabled,
      isPlaying: isPlaying ?? this.isPlaying,
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

  MediaControlState get state => _state;

  void applyPlaybackRuntimeSettings(PlaybackRuntimeSettings settings) {
    _state = _state.copyWith(
      volume: settings.volume,
      isMuted: settings.isMuted,
      mode: settings.mode,
    );
    notifyListeners();
  }

  void loadTrack(MediaControlTrack track, {double durationSeconds = 0}) {
    _state = MediaControlState(
      track: track,
      selectedQueueIndex: null,
      disabled: track.id == null,
      isPlaying: false,
      progressSeconds: 0,
      durationSeconds: durationSeconds,
      isProgressSeeking: false,
      volume: _state.volume,
      isMuted: _state.isMuted,
      mode: _state.mode,
    );
    notifyListeners();
  }

  void playTrack(
    MediaControlTrack track, {
    required double durationSeconds,
    int? queueIndex,
  }) {
    _state = MediaControlState(
      track: track,
      selectedQueueIndex: queueIndex,
      disabled: track.id == null,
      isPlaying: track.id != null,
      progressSeconds: 0,
      durationSeconds: durationSeconds,
      isProgressSeeking: false,
      volume: _state.volume,
      isMuted: _state.isMuted,
      mode: _state.mode,
    );
    notifyListeners();
  }

  void onTogglePlayPause() {
    if (_state.disabled) {
      return;
    }

    _state = _state.copyWith(isPlaying: !_state.isPlaying);
    notifyListeners();
  }

  void onPrevious() {
    if (_state.disabled) {
      return;
    }

    _state = _state.copyWith(progressSeconds: 0);
    notifyListeners();
  }

  void onNext() {
    if (_state.disabled) {
      return;
    }

    _state = _state.copyWith(progressSeconds: 0);
    notifyListeners();
  }

  void onStop() {
    if (_state.disabled) {
      return;
    }

    _state = _state.copyWith(isPlaying: false, progressSeconds: 0);
    notifyListeners();
  }

  void onSeek(double seconds) {
    final nextProgress = seconds.clamp(0, _state.durationSeconds).toDouble();
    _state = _state.copyWith(progressSeconds: nextProgress);
    notifyListeners();
    _onPlaybackSettingsUpdate?.call(
      PlaybackSettingsUpdate(musicProgress: nextProgress),
    );
  }

  void onBeginSeek() {
    _state = _state.copyWith(isProgressSeeking: true);
    notifyListeners();
  }

  void onEndSeek() {
    _state = _state.copyWith(isProgressSeeking: false);
    notifyListeners();
  }

  void onVolumeChange(int volume) {
    final nextVolume = volume.clamp(0, 100);
    final nextMuted = nextVolume > 0 && _state.isMuted ? false : _state.isMuted;
    final mutedChanged = nextMuted != _state.isMuted;
    _state = _state.copyWith(volume: nextVolume, isMuted: nextMuted);
    notifyListeners();
    _onPlaybackSettingsUpdate?.call(
      PlaybackSettingsUpdate(
        volume: nextVolume,
        isMuted: mutedChanged ? nextMuted : null,
      ),
    );
  }

  void onToggleMute() {
    final nextMuted = !_state.isMuted;
    _state = _state.copyWith(isMuted: nextMuted);
    notifyListeners();
    _onPlaybackSettingsUpdate?.call(PlaybackSettingsUpdate(isMuted: nextMuted));
  }

  void onToggleShuffle() {
    final nextMode =
        _state.mode == PlaybackMode.shuffle
            ? PlaybackMode.once
            : PlaybackMode.shuffle;
    _state = _state.copyWith(mode: nextMode);
    notifyListeners();
    _onPlaybackSettingsUpdate?.call(PlaybackSettingsUpdate(mode: nextMode));
  }

  void onToggleRepeat() {
    final nextMode =
        _state.mode == PlaybackMode.repeat
            ? PlaybackMode.once
            : PlaybackMode.repeat;
    _state = _state.copyWith(mode: nextMode);
    notifyListeners();
    _onPlaybackSettingsUpdate?.call(PlaybackSettingsUpdate(mode: nextMode));
  }

  void onToggleRepeatOne() {
    final nextMode =
        _state.mode == PlaybackMode.repeatOne
            ? PlaybackMode.once
            : PlaybackMode.repeatOne;
    _state = _state.copyWith(mode: nextMode);
    notifyListeners();
    _onPlaybackSettingsUpdate?.call(PlaybackSettingsUpdate(mode: nextMode));
  }

  void cyclePlaybackMode() {
    final nextMode = getNextPlaybackMode(_state.mode);
    _state = _state.copyWith(mode: nextMode);
    notifyListeners();
    _onPlaybackSettingsUpdate?.call(PlaybackSettingsUpdate(mode: nextMode));
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

PlaybackMode getNextPlaybackMode(PlaybackMode mode) {
  return switch (mode) {
    PlaybackMode.once => PlaybackMode.shuffle,
    PlaybackMode.shuffle => PlaybackMode.repeat,
    PlaybackMode.repeat => PlaybackMode.repeatOne,
    PlaybackMode.repeatOne => PlaybackMode.once,
  };
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
