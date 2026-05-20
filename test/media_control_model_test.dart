import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';

void main() {
  test('playback mode cycle follows Electron MediaControl order', () {
    expect(getNextPlaybackMode(PlaybackMode.once), PlaybackMode.shuffle);
    expect(getNextPlaybackMode(PlaybackMode.shuffle), PlaybackMode.repeat);
    expect(getNextPlaybackMode(PlaybackMode.repeat), PlaybackMode.repeatOne);
    expect(getNextPlaybackMode(PlaybackMode.repeatOne), PlaybackMode.once);
  });

  test('playback mode titles match Electron mediaControlModel labels', () {
    expect(getShuffleTitle(PlaybackMode.once), '随机播放：关闭');
    expect(getShuffleTitle(PlaybackMode.shuffle), '随机播放：打开');
    expect(getRepeatTitle(PlaybackMode.repeat), '循环播放：打开');
    expect(getRepeatOneTitle(PlaybackMode.repeatOne), '单曲循环：打开');
    expect(getPlaybackModeName(PlaybackMode.once), '列表');
    expect(getPlaybackModeName(PlaybackMode.repeatOne), '单曲循环');
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

    controller.onTogglePlayPause();
    expect(controller.state.isPlaying, isTrue);
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

    controller.onVolumeChange(130);
    expect(controller.state.volume, 100);
    expect(controller.state.isMuted, isFalse);
    expect(persistedUpdates.last.volume, 100);
    expect(persistedUpdates.last.isMuted, isFalse);

    controller.onToggleMute();
    expect(controller.state.isMuted, isTrue);
    expect(persistedUpdates.last.isMuted, isTrue);

    controller.onToggleShuffle();
    expect(controller.state.mode, PlaybackMode.shuffle);
    expect(persistedUpdates.last.mode, PlaybackMode.shuffle);

    controller.onToggleRepeat();
    expect(controller.state.mode, PlaybackMode.repeat);
    expect(persistedUpdates.last.mode, PlaybackMode.repeat);

    controller.onToggleRepeatOne();
    expect(controller.state.mode, PlaybackMode.repeatOne);
    expect(persistedUpdates.last.mode, PlaybackMode.repeatOne);

    controller.onToggleFavorite();
    expect(controller.state.track.favorite, isTrue);
  });

  test('formatDuration matches Electron player duration display', () {
    expect(formatDuration(0), '0:00');
    expect(formatDuration(65), '1:05');
    expect(formatDuration(3661), '1:01:01');
  });
}
