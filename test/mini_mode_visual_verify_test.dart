import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/mini_mode_surface.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'common.artistUnknown': 'Unknown Artist',
      'nowPlaying.noActiveTrack': 'No active track',
      'nowPlaying.quickPlay': 'Quick Play',
      'player.exitMiniMode': 'Exit Mini Mode',
      'player.forcePrevious': 'Previous track',
      'player.like': 'Add to My Favorites',
      'player.mute': 'Mute',
      'player.next': 'Next',
      'player.pause': 'Pause',
      'player.play': 'Play',
      'player.playbackModeRepeat': 'Repeat',
      'player.playbackModeRepeatOne': 'Repeat One',
      'player.playbackMode': 'Playback Mode',
      'player.playbackModeList': 'List',
      'player.playbackModeShuffle': 'Shuffle',
      'player.previous': 'Previous',
      'player.restartCurrentTrackHoldPrevious': 'Restart current track',
      'player.unlike': 'Remove from My Favorites',
      'player.unmute': 'Unmute',
      'player.voiceAssistant': 'Voice Assistant',
    },
  );

  testWidgets('writes mini mode Electron parity screenshots', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 360);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repaintKey = GlobalKey();
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.dark],
          ),
          home: Material(
            child: RepaintBoundary(
              key: repaintKey,
              child: MiniModeSurface(
                state: const MediaControlState(
                  track: MediaControlTrack(
                    id: 10,
                    title: 'First Song',
                    artist: 'First Artist',
                    artworkUrl: '',
                    isLoading: false,
                    favorite: true,
                  ),
                  disabled: false,
                  isPlaying: false,
                  volume: 50,
                  isMuted: false,
                  mode: PlaybackMode.once,
                  progressSeconds: 42,
                  durationSeconds: 180,
                  isProgressSeeking: false,
                ),
                i18n: i18n,
                currentSong: const LibrarySong(
                  id: 10,
                  path: '/tmp/first.mp3',
                  title: 'First Song',
                  artist: 'First Artist',
                  artists: ['First Artist'],
                  album: 'First Album',
                  duration: 180,
                  playCount: 0,
                  lyricsOffsetMs: 0,
                  dateAdded: '',
                  favorite: true,
                  thumbnailPath: '',
                ),
                repository: const _MiniModeVisualRepository(),
                playerLyricsSource: LyricsRequestMode.auto,
                lyricsRefreshRevision: 0,
                previousButtonRestartsTrack: false,
                onExit: () {},
                onTogglePlayPause: () {},
                onPrevious: () {},
                onForcePrevious: () {},
                onNext: () {},
                onSeek: (_) {},
                onBeginSeek: () {},
                onEndSeek: () {},
                onToggleFavorite: () {},
                onQuickPlay: () {},
                onCyclePlaybackMode: () {},
                onToggleShuffle: () {},
                onToggleRepeat: () {},
                onToggleRepeatOne: () {},
                onToggleMute: () {},
                onVolumeChange: (_) {},
                onOpenVoiceAssistant: () {},
                onWindowDragStart: () {},
                onWindowDragEnd: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await _writeScreenshot(
      tester,
      repaintKey,
      '/tmp/smplayer_mini_mode_hidden_verify.png',
    );

    final gesture = await tester.createGesture(
      kind: ui.PointerDeviceKind.mouse,
    );
    await gesture.addPointer(location: const Offset(12, 12));
    await tester.pump();
    await gesture.moveTo(const Offset(180, 180));
    await tester.pump(const Duration(milliseconds: 220));
    await _writeScreenshot(
      tester,
      repaintKey,
      '/tmp/smplayer_mini_mode_controls_verify.png',
    );
  });

  testWidgets('mini mode refreshes lyrics after MusicDialog save event', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 360);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _RefreshingMiniModeRepository();

    Widget buildMiniMode(int revision) {
      return SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.dark],
          ),
          home: Material(
            child: MiniModeSurface(
              state: const MediaControlState(
                track: MediaControlTrack(
                  id: 10,
                  title: 'First Song',
                  artist: 'First Artist',
                  artworkUrl: '',
                  isLoading: false,
                  favorite: false,
                ),
                disabled: false,
                isPlaying: false,
                volume: 50,
                isMuted: false,
                mode: PlaybackMode.once,
                progressSeconds: 42,
                durationSeconds: 180,
                isProgressSeeking: false,
              ),
              i18n: i18n,
              currentSong: const LibrarySong(
                id: 10,
                path: '/tmp/first.mp3',
                title: 'First Song',
                artist: 'First Artist',
                artists: ['First Artist'],
                album: 'First Album',
                duration: 180,
                playCount: 0,
                lyricsOffsetMs: 0,
                dateAdded: '2026-01-01T00:00:00Z',
                favorite: false,
                thumbnailPath: '',
              ),
              repository: repository,
              playerLyricsSource: LyricsRequestMode.auto,
              lyricsRefreshRevision: revision,
              previousButtonRestartsTrack: false,
              onExit: () {},
              onTogglePlayPause: () {},
              onPrevious: () {},
              onForcePrevious: () {},
              onNext: () {},
              onSeek: (_) {},
              onBeginSeek: () {},
              onEndSeek: () {},
              onToggleFavorite: () {},
              onQuickPlay: () {},
              onCyclePlaybackMode: () {},
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleMute: () {},
              onVolumeChange: (_) {},
              onOpenVoiceAssistant: null,
              onWindowDragStart: null,
              onWindowDragEnd: null,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildMiniMode(0));
    await tester.pumpAndSettle();
    expect(repository.requests, 1);
    expect(find.text('First refreshed lyric'), findsWidgets);

    await tester.pumpWidget(buildMiniMode(1));
    await tester.pumpAndSettle();
    expect(repository.requests, 2);
    expect(find.text('Second refreshed lyric'), findsWidgets);
    expect(find.text('First refreshed lyric'), findsNothing);
  });

  testWidgets('mini mode playback mode button follows compact cycle surface', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 360);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var cycleCount = 0;
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.dark],
          ),
          home: Material(
            child: MiniModeSurface(
              state: const MediaControlState(
                track: MediaControlTrack(
                  id: 10,
                  title: 'First Song',
                  artist: 'First Artist',
                  artworkUrl: '',
                  isLoading: false,
                  favorite: false,
                ),
                disabled: false,
                isPlaying: false,
                volume: 50,
                isMuted: false,
                mode: PlaybackMode.shuffle,
                progressSeconds: 42,
                durationSeconds: 180,
                isProgressSeeking: false,
              ),
              i18n: i18n,
              currentSong: const LibrarySong(
                id: 10,
                path: '/tmp/first.mp3',
                title: 'First Song',
                artist: 'First Artist',
                artists: ['First Artist'],
                album: 'First Album',
                duration: 180,
                playCount: 0,
                lyricsOffsetMs: 0,
                dateAdded: '',
                favorite: false,
                thumbnailPath: '',
              ),
              repository: const _MiniModeVisualRepository(),
              playerLyricsSource: LyricsRequestMode.auto,
              lyricsRefreshRevision: 0,
              previousButtonRestartsTrack: false,
              onExit: () {},
              onTogglePlayPause: () {},
              onPrevious: () {},
              onForcePrevious: () {},
              onNext: () {},
              onSeek: (_) {},
              onBeginSeek: () {},
              onEndSeek: () {},
              onToggleFavorite: () {},
              onQuickPlay: () {},
              onCyclePlaybackMode: () {
                cycleCount += 1;
              },
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleMute: () {},
              onVolumeChange: (_) {},
              onOpenVoiceAssistant: () {},
              onWindowDragStart: () {},
              onWindowDragEnd: () {},
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.createGesture(
      kind: ui.PointerDeviceKind.mouse,
    );
    await gesture.addPointer(location: const Offset(12, 12));
    await tester.pump();
    await gesture.moveTo(const Offset(180, 180));
    await tester.pump(const Duration(milliseconds: 220));

    final modeIcon = find.byKey(const ValueKey('MiniMode.Icon.shuffle'));
    expect(modeIcon, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('MiniMode.PlaybackModeButton')));
    expect(cycleCount, 1);

    await tester.longPress(
      find.byKey(const ValueKey('MiniMode.PlaybackModeButton')),
    );
    await tester.pumpAndSettle();
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Repeat'), findsOneWidget);
  });

  testWidgets('mini mode volume popover accepts vertical drag', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 360);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int? changedVolume;
    final repaintKey = GlobalKey();
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.dark],
          ),
          home: Material(
            child: RepaintBoundary(
              key: repaintKey,
              child: MiniModeSurface(
                state: const MediaControlState(
                  track: MediaControlTrack(
                    id: 10,
                    title: 'First Song',
                    artist: 'First Artist',
                    artworkUrl: '',
                    isLoading: false,
                    favorite: false,
                  ),
                  disabled: false,
                  isPlaying: false,
                  volume: 50,
                  isMuted: false,
                  mode: PlaybackMode.once,
                  progressSeconds: 42,
                  durationSeconds: 180,
                  isProgressSeeking: false,
                ),
                i18n: i18n,
                currentSong: const LibrarySong(
                  id: 10,
                  path: '/tmp/first.mp3',
                  title: 'First Song',
                  artist: 'First Artist',
                  artists: ['First Artist'],
                  album: 'First Album',
                  duration: 180,
                  playCount: 0,
                  lyricsOffsetMs: 0,
                  dateAdded: '',
                  favorite: false,
                  thumbnailPath: '',
                ),
                repository: const _MiniModeVisualRepository(),
                playerLyricsSource: LyricsRequestMode.auto,
                lyricsRefreshRevision: 0,
                previousButtonRestartsTrack: false,
                onExit: () {},
                onTogglePlayPause: () {},
                onPrevious: () {},
                onForcePrevious: () {},
                onNext: () {},
                onSeek: (_) {},
                onBeginSeek: () {},
                onEndSeek: () {},
                onToggleFavorite: () {},
                onQuickPlay: () {},
                onCyclePlaybackMode: () {},
                onToggleShuffle: () {},
                onToggleRepeat: () {},
                onToggleRepeatOne: () {},
                onToggleMute: () {},
                onVolumeChange: (value) {
                  changedVolume = value;
                },
                onOpenVoiceAssistant: () {},
                onWindowDragStart: () {},
                onWindowDragEnd: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.createGesture(
      kind: ui.PointerDeviceKind.mouse,
    );
    await gesture.addPointer(location: const Offset(12, 12));
    await tester.pump();
    await gesture.moveTo(const Offset(180, 180));
    await tester.pump(const Duration(milliseconds: 220));

    await tester.tap(find.byKey(const ValueKey('MiniMode.VolumeButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('MiniMode.VolumeSlider')), findsOneWidget);
    expect(find.byKey(const ValueKey('VolumeSlider.Tooltip')), findsNothing);
    await _writeScreenshot(
      tester,
      repaintKey,
      '/tmp/smplayer_mini_mode_volume_verify.png',
    );
    await tester.drag(
      find.byKey(const ValueKey('MiniMode.VolumeSlider')),
      const Offset(0, -42),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('VolumeSlider.Tooltip')), findsOneWidget);
    final sliderRect = tester.getRect(
      find.byKey(const ValueKey('MiniMode.VolumeSlider')),
    );
    final tooltipRect = tester.getRect(
      find.byKey(const ValueKey('VolumeSlider.Tooltip')),
    );
    expect(tooltipRect.right, lessThan(sliderRect.left));
    await _writeScreenshot(
      tester,
      repaintKey,
      '/tmp/smplayer_mini_mode_volume_tooltip_verify.png',
    );
    expect(changedVolume, isNotNull);
  });
}

Future<void> _writeScreenshot(
  WidgetTester tester,
  GlobalKey repaintKey,
  String path,
) async {
  await tester.runAsync(() async {
    final boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

class _MiniModeVisualRepository extends LibraryRepository {
  const _MiniModeVisualRepository();

  @override
  Future<LyricsSnapshot> getSongLyrics(
    int songId, {
    LyricsRequestMode mode = LyricsRequestMode.auto,
  }) async {
    return const LyricsSnapshot(
      source: LyricsSource.textFile,
      isSynced: true,
      rawText: 'This is the current lyric line',
      lines: [
        LyricsLine(
          id: 1,
          timestampMs: 0,
          text: 'This is the current lyric line',
        ),
      ],
    );
  }
}

class _RefreshingMiniModeRepository extends LibraryRepository {
  int requests = 0;

  @override
  Future<LyricsSnapshot> getSongLyrics(
    int songId, {
    LyricsRequestMode mode = LyricsRequestMode.auto,
  }) async {
    requests += 1;
    final text =
        requests == 1 ? 'First refreshed lyric' : 'Second refreshed lyric';
    return LyricsSnapshot(
      source: LyricsSource.textFile,
      isSynced: true,
      rawText: text,
      lines: [LyricsLine(id: requests, timestampMs: 0, text: text)],
    );
  }
}
