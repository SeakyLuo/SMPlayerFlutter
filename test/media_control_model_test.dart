import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';

void main() {
  test('playback mode cycle follows Electron MediaControl order', () {
    expect(getNextPlaybackMode(PlaybackMode.once), PlaybackMode.shuffle);
    expect(getNextPlaybackMode(PlaybackMode.shuffle), PlaybackMode.repeat);
    expect(getNextPlaybackMode(PlaybackMode.repeat), PlaybackMode.repeatOne);
    expect(getNextPlaybackMode(PlaybackMode.repeatOne), PlaybackMode.once);
  });

  test('repeat cycle follows Electron mini mode order', () {
    expect(getNextRepeatCycleMode(PlaybackMode.once), PlaybackMode.repeat);
    expect(getNextRepeatCycleMode(PlaybackMode.shuffle), PlaybackMode.repeat);
    expect(getNextRepeatCycleMode(PlaybackMode.repeat), PlaybackMode.repeatOne);
    expect(getNextRepeatCycleMode(PlaybackMode.repeatOne), PlaybackMode.once);
  });

  test('normalizePlaybackQueueSongIds mirrors Electron active-song filter', () {
    expect(
      normalizePlaybackQueueSongIds(const [4, 2, 9, 2], const [1, 2, 3, 4]),
      [4, 2, 2],
    );
  });

  test('removePlaybackQueueRange mirrors Electron queue undo helper', () {
    expect(removePlaybackQueueRange(const [1, 2, 3, 4], 2, 1), [1, 2, 4]);
    expect(removePlaybackQueueRange(const [1, 2, 3, 4], 1, 2), [1, 4]);
  });

  test('shuffleNextRoundSongIds avoids repeating active track first', () {
    final shuffled = shuffleNextRoundSongIds(
      const [1, 2, 3, 4],
      4,
      _FixedRandom([0, 2, 1]),
    );

    expect(shuffled, [2, 3, 1, 4]);
  });

  test(
    'shufflePlaybackQueueForCurrentTrack mirrors Electron shuffle enable',
    () {
      final shuffled = shufflePlaybackQueueForCurrentTrack(
        const [1, 2, 3, 4],
        3,
        _FixedRandom([0, 2, 1]),
      );

      expect(shuffled.first, 3);
      expect(shuffled.toSet(), {1, 2, 3, 4});
      expect(shufflePlaybackQueueForCurrentTrack(const [1, 2, 3], 9), [
        1,
        2,
        3,
      ]);
    },
  );

  test('previous command restart threshold mirrors Electron playback', () {
    expect(
      shouldRestartCurrentTrackForPrevious(
        progressSeconds: 5.01,
        queueLength: 3,
        restartAfterThresholdEnabled: true,
      ),
      isTrue,
    );
    expect(
      shouldRestartCurrentTrackForPrevious(
        progressSeconds: 5,
        queueLength: 3,
        restartAfterThresholdEnabled: true,
      ),
      isFalse,
    );
    expect(
      shouldRestartCurrentTrackForPrevious(
        progressSeconds: 0,
        queueLength: 1,
        restartAfterThresholdEnabled: true,
      ),
      isTrue,
    );
    expect(
      shouldRestartCurrentTrackForPrevious(
        progressSeconds: 5.01,
        queueLength: 3,
        restartAfterThresholdEnabled: false,
      ),
      isFalse,
    );
  });

  test('playback mode titles match Electron mediaControlModel labels', () {
    expect(getShuffleTitle(PlaybackMode.once), '随机播放：关闭');
    expect(getShuffleTitle(PlaybackMode.shuffle), '随机播放：打开');
    expect(getRepeatTitle(PlaybackMode.repeat), '循环播放：打开');
    expect(getRepeatOneTitle(PlaybackMode.repeatOne), '单曲循环：打开');
    expect(getPlaybackModeName(PlaybackMode.once), '列表');
    expect(getPlaybackModeName(PlaybackMode.repeatOne), '单曲循环');
  });

  test('playback status transitions mirror Electron playbackStateMachine', () {
    expect(
      transitionPlaybackStatus(
        PlaybackStatus.idle,
        PlaybackTransitionType.loadTrack,
      ),
      PlaybackStatus.loading,
    );
    expect(
      transitionPlaybackStatus(
        PlaybackStatus.loading,
        PlaybackTransitionType.pause,
      ),
      PlaybackStatus.loading,
    );
    expect(
      transitionPlaybackStatus(
        PlaybackStatus.buffering,
        PlaybackTransitionType.pause,
      ),
      PlaybackStatus.buffering,
    );
    expect(
      transitionPlaybackStatus(
        PlaybackStatus.seeking,
        PlaybackTransitionType.seeked,
        paused: true,
      ),
      PlaybackStatus.paused,
    );
    expect(
      transitionPlaybackStatus(
        PlaybackStatus.seeking,
        PlaybackTransitionType.seeked,
      ),
      PlaybackStatus.playing,
    );
    expect(
      transitionPlaybackStatus(
        PlaybackStatus.loading,
        PlaybackTransitionType.canPlay,
        paused: true,
      ),
      PlaybackStatus.ready,
    );
    expect(
      transitionPlaybackStatus(
        PlaybackStatus.loading,
        PlaybackTransitionType.canPlay,
        pendingAutoplay: true,
      ),
      PlaybackStatus.loading,
    );
  });

  test('MediaControlController mirrors disabled and loaded track behavior', () {
    final controller = MediaControlController();

    controller.onTogglePlayPause();
    expect(controller.state.isPlaying, isFalse);

    controller.loadTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Song',
        artist: 'Artist',
        artworkUrl: '',
        isLoading: false,
      ),
      durationSeconds: 180,
    );
    expect(controller.state.disabled, isFalse);
    expect(controller.state.durationSeconds, 180);
    expect(controller.state.playbackStatus, PlaybackStatus.loading);

    controller.onTogglePlayPause();
    expect(controller.state.isPlaying, isTrue);
    expect(controller.state.playbackStatus, PlaybackStatus.loading);

    controller.setTrackLoading(false);
    expect(controller.state.playbackStatus, PlaybackStatus.playing);
    controller.onTogglePlayPause();
    expect(controller.state.isPlaying, isFalse);
    expect(controller.state.playbackStatus, PlaybackStatus.paused);
    expect(controller.state.track.isLoading, isFalse);
    controller.onTogglePlayPause();
    expect(controller.state.isPlaying, isTrue);
    expect(controller.state.playbackStatus, PlaybackStatus.playing);
    expect(controller.state.track.isLoading, isFalse);

    controller.playTrack(
      const MediaControlTrack(
        id: 2,
        title: 'Restored',
        artist: 'Artist',
        artworkUrl: '',
        isLoading: false,
      ),
      durationSeconds: 200,
      queueIndex: 1,
      progressSeconds: 42,
      autoplay: false,
    );
    expect(controller.state.selectedQueueIndex, 1);
    expect(controller.state.progressSeconds, 42);
    expect(controller.state.isPlaying, isFalse);
    expect(controller.state.playbackStatus, PlaybackStatus.loading);
  });

  test('MediaControlController updates playback runtime state', () {
    final persistedUpdates = <PlaybackSettingsUpdate>[];
    final controller = MediaControlController(
      const MediaControlState(
        track: MediaControlTrack(
          id: 1,
          title: 'Song',
          artist: 'Artist',
          artworkUrl: '',
          isLoading: false,
        ),
        disabled: false,
        isPlaying: false,
        volume: 50,
        isMuted: false,
        mode: PlaybackMode.once,
        progressSeconds: 0,
        durationSeconds: 100,
        isProgressSeeking: false,
      ),
      persistedUpdates.add,
    );

    controller.applyPlaybackRuntimeSettings(
      const PlaybackRuntimeSettings(
        volume: 32,
        isMuted: true,
        mode: PlaybackMode.repeat,
      ),
    );
    expect(controller.state.volume, 32);
    expect(controller.state.isMuted, isTrue);
    expect(controller.state.mode, PlaybackMode.repeat);

    controller.onSeek(140);
    expect(controller.state.progressSeconds, 100);
    expect(persistedUpdates.last.musicProgress, 100);

    fakeAsync((async) {
      controller.onVolumeChange(60);
      controller.onVolumeChange(130);
      expect(controller.state.volume, 100);
      expect(controller.state.isMuted, isFalse);
      expect(persistedUpdates.last.musicProgress, 100);

      async.elapse(volumePersistenceDebounce - const Duration(milliseconds: 1));
      expect(persistedUpdates.last.musicProgress, 100);

      async.elapse(const Duration(milliseconds: 1));
      expect(persistedUpdates.last.volume, 100);
      expect(persistedUpdates.last.isMuted, isFalse);
    });

    controller.onToggleMute();
    expect(controller.state.isMuted, isTrue);
    expect(persistedUpdates.last.isMuted, isTrue);

    controller.onToggleShuffle();
    expect(controller.state.mode, PlaybackMode.shuffle);
    expect(persistedUpdates.last.mode, PlaybackMode.shuffle);

    controller.setSelectedQueueIndex(3);
    expect(controller.state.selectedQueueIndex, 3);

    controller.setSelectedQueueIndex(null);
    expect(controller.state.selectedQueueIndex, isNull);

    controller.onToggleRepeat();
    expect(controller.state.mode, PlaybackMode.repeat);
    expect(persistedUpdates.last.mode, PlaybackMode.repeat);

    controller.onToggleRepeatOne();
    expect(controller.state.mode, PlaybackMode.repeatOne);
    expect(persistedUpdates.last.mode, PlaybackMode.repeatOne);

    controller.onToggleFavorite();
    expect(controller.state.track.favorite, isTrue);

    controller.onStop();
    expect(controller.state.isPlaying, isFalse);
    expect(controller.state.progressSeconds, 100);
    expect(persistedUpdates.last.musicProgress, 100);
  });

  test('MediaControlController accepts playback backend state updates', () {
    final controller = MediaControlController(
      const MediaControlState(
        track: MediaControlTrack(
          id: 1,
          title: 'Song',
          artist: 'Artist',
          artworkUrl: '',
          isLoading: false,
        ),
        disabled: false,
        isPlaying: false,
        volume: 50,
        isMuted: false,
        mode: PlaybackMode.once,
        progressSeconds: 0,
        durationSeconds: 100,
        isProgressSeeking: false,
      ),
    );

    controller.setPlaybackActive(true);
    expect(controller.state.isPlaying, isTrue);
    expect(controller.state.playbackStatus, PlaybackStatus.playing);

    controller.setTrackLoading(true, buffering: true);
    expect(controller.state.playbackStatus, PlaybackStatus.buffering);
    expect(controller.state.track.isLoading, isTrue);

    controller.setPlaybackActive(false);
    expect(controller.state.playbackStatus, PlaybackStatus.buffering);
    controller.setTrackLoading(false);
    expect(controller.state.isPlaying, isFalse);
    expect(controller.state.playbackStatus, PlaybackStatus.ready);

    controller.syncPlaybackProgress(140, durationSeconds: 180);
    expect(controller.state.progressSeconds, 140);
    expect(controller.state.durationSeconds, 180);

    controller.syncPlaybackProgress(220);
    expect(controller.state.progressSeconds, 180);

    controller.completePlayback();
    expect(controller.state.isPlaying, isFalse);
    expect(controller.state.progressSeconds, 180);
  });

  test('getNextRecoverableTrackId mirrors Electron shared recovery helper', () {
    expect(
      getNextRecoverableTrackId(
        playbackSongIds: const [1, 2, 3, 4],
        activeTrackId: 2,
        activeQueueIndex: 1,
        mode: PlaybackMode.once,
        failedTrackIds: {2, 3},
      ),
      4,
    );
    expect(
      getNextRecoverableTrackId(
        playbackSongIds: const [1, 2, 3],
        activeTrackId: 3,
        activeQueueIndex: 2,
        mode: PlaybackMode.repeat,
        failedTrackIds: {3},
      ),
      1,
    );
    expect(
      getNextRecoverableTrackId(
        playbackSongIds: const [1, 2, 3],
        activeTrackId: 3,
        activeQueueIndex: 2,
        mode: PlaybackMode.once,
        failedTrackIds: {3},
      ),
      isNull,
    );
    expect(
      getNextRecoverableTrackId(
        playbackSongIds: const [1, 2, 3],
        activeTrackId: 2,
        activeQueueIndex: 0,
        mode: PlaybackMode.shuffle,
        failedTrackIds: {1, 2, 3},
      ),
      isNull,
    );
  });

  test('stalledPlaybackRecoveryAction mirrors Electron stall recovery', () {
    expect(
      stalledPlaybackRecoveryAction(
        isPlaying: true,
        isUserSeeking: false,
        currentProgressSeconds: 10.3,
        lastProgressSeconds: 10,
        stalledFor: const Duration(seconds: 9),
        durationSeconds: 100,
      ),
      PlaybackStallRecoveryAction.none,
    );
    expect(
      stalledPlaybackRecoveryAction(
        isPlaying: true,
        isUserSeeking: false,
        currentProgressSeconds: 40.04,
        lastProgressSeconds: 40,
        stalledFor: const Duration(seconds: 8),
        durationSeconds: 100,
      ),
      PlaybackStallRecoveryAction.pauseAndRecover,
    );
    expect(
      stalledPlaybackRecoveryAction(
        isPlaying: true,
        isUserSeeking: false,
        currentProgressSeconds: 10.1,
        lastProgressSeconds: 10,
        stalledFor: const Duration(seconds: 7, milliseconds: 999),
        durationSeconds: 100,
      ),
      PlaybackStallRecoveryAction.none,
    );
    expect(
      stalledPlaybackRecoveryAction(
        isPlaying: true,
        isUserSeeking: true,
        currentProgressSeconds: 10,
        lastProgressSeconds: 10,
        stalledFor: const Duration(seconds: 9),
        durationSeconds: 100,
      ),
      PlaybackStallRecoveryAction.none,
    );
    expect(
      stalledPlaybackRecoveryAction(
        isPlaying: true,
        isUserSeeking: false,
        currentProgressSeconds: 99.6,
        lastProgressSeconds: 99.6,
        stalledFor: const Duration(seconds: 8),
        durationSeconds: 100,
      ),
      PlaybackStallRecoveryAction.finishTrack,
    );
    expect(
      stalledPlaybackRecoveryAction(
        isPlaying: true,
        isUserSeeking: false,
        currentProgressSeconds: 40,
        lastProgressSeconds: 40,
        stalledFor: const Duration(seconds: 8),
        durationSeconds: 100,
      ),
      PlaybackStallRecoveryAction.pauseAndRecover,
    );
  });

  test(
    'MediaControlController exposes backend loading and load failure state',
    () {
      final controller = MediaControlController(
        const MediaControlState(
          track: MediaControlTrack(
            id: 1,
            title: 'Song',
            artist: 'Artist',
            artworkUrl: '',
            isLoading: false,
          ),
          disabled: false,
          isPlaying: true,
          volume: 50,
          isMuted: false,
          mode: PlaybackMode.once,
          progressSeconds: 0,
          durationSeconds: 100,
          isProgressSeeking: false,
        ),
      );

      controller.setTrackLoading(true);
      expect(controller.state.track.isLoading, isTrue);
      expect(controller.state.playbackStatus, PlaybackStatus.loading);
      expect(controller.state.playbackNoticeKey, isNull);

      controller.setTrackLoading(true, buffering: true);
      expect(controller.state.track.isLoading, isTrue);
      expect(controller.state.playbackStatus, PlaybackStatus.buffering);

      controller.setPlaybackActive(false);
      expect(controller.state.isPlaying, isFalse);
      expect(controller.state.playbackStatus, PlaybackStatus.buffering);

      controller.setPlaybackLoadFailed();
      expect(controller.state.isPlaying, isFalse);
      expect(controller.state.track.isLoading, isFalse);
      expect(controller.state.playbackStatus, PlaybackStatus.paused);
      expect(controller.state.playbackNoticeKey, isNull);

      controller.setPlaybackNotice('notification.playbackStalled');
      expect(
        controller.state.playbackNoticeKey,
        'notification.playbackStalled',
      );

      controller.setTrackLoading(true);
      expect(controller.state.playbackNoticeKey, isNull);
    },
  );

  test(
    'MediaControlController mirrors Electron runtime playback error recovery',
    () {
      final persistedUpdates = <PlaybackSettingsUpdate>[];
      final controller = MediaControlController(
        const MediaControlState(
          track: MediaControlTrack(
            id: 1,
            title: 'Song',
            artist: 'Artist',
            artworkUrl: '',
            isLoading: false,
          ),
          disabled: false,
          isPlaying: true,
          volume: 50,
          isMuted: false,
          mode: PlaybackMode.once,
          progressSeconds: 42,
          durationSeconds: 100,
          isProgressSeeking: false,
          playbackStatus: PlaybackStatus.playing,
        ),
        persistedUpdates.add,
      );

      controller.setTrackLoading(true, buffering: true);
      controller.setPlaybackRuntimeFailed(64);

      expect(controller.state.isPlaying, isFalse);
      expect(controller.state.track.isLoading, isFalse);
      expect(controller.state.playbackStatus, PlaybackStatus.paused);
      expect(controller.state.progressSeconds, 64);
      expect(controller.state.playbackNoticeKey, isNull);
      expect(persistedUpdates.last.musicProgress, 64);

      controller.setPlaybackRuntimeFailed(140);
      expect(controller.state.progressSeconds, 100);
      expect(persistedUpdates.last.musicProgress, 100);
    },
  );

  test('formatDuration matches Electron player duration display', () {
    expect(formatDuration(0), '0:00');
    expect(formatDuration(65), '1:05');
    expect(formatDuration(3661), '1:01:01');
  });
}

class _FixedRandom implements Random {
  _FixedRandom(this._values);

  final List<int> _values;
  var _index = 0;

  @override
  bool nextBool() {
    return nextInt(2) == 1;
  }

  @override
  double nextDouble() {
    return nextInt(1000) / 1000;
  }

  @override
  int nextInt(int max) {
    final value = _values[_index];
    _index += 1;
    return value % max;
  }
}
