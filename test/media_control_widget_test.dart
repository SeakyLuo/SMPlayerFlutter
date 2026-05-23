import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'common.nowPlaying': 'Now Playing',
      'common.myFavorites': 'My Favorites',
      'context.addToPlaylist': 'Add To',
      'context.seeArtist': 'See Artist',
      'context.seeAlbum': 'See Album',
      'context.seeAlbumArt': 'See Album Art',
      'context.seeLyrics': 'See Lyrics',
      'context.seeLocalFile': 'See Local File',
      'context.seeMusicInfo': 'See Music Info',
      'context.view': 'View',
      'nowPlaying.exitFullScreenItem': 'Exit Full Screen',
      'nowPlaying.fullScreen': 'Full Screen',
      'nowPlaying.quickPlay': 'Quick Play',
      'player.enterMiniMode': 'Enter Mini Mode',
      'player.like': 'Add to My Favorites',
      'player.miniMode': 'Mini Mode',
      'player.more': 'More',
      'player.mute': 'Mute',
      'player.next': 'Next',
      'player.pause': 'Pause',
      'player.play': 'Play',
      'player.playbackLoadFailed': 'Could not play this song.',
      'player.playbackMode': 'Playback Mode',
      'player.playbackModeList': 'List',
      'player.playbackModeRepeat': 'Repeat',
      'player.playbackModeRepeatOne': 'Repeat One',
      'player.playbackModeShuffle': 'Shuffle',
      'player.previous': 'Previous',
      'player.repeatDisabled': 'Repeat: Disabled',
      'player.repeatEnabled': 'Repeat: Enabled',
      'player.repeatOneDisabled': 'Repeat One: Disabled',
      'player.repeatOneEnabled': 'Repeat One: Enabled',
      'player.shuffleDisabled': 'Shuffle: Disabled',
      'player.shuffleEnabled': 'Shuffle: Enabled',
      'player.unlike': 'Remove from My Favorites',
      'player.unmute': 'Unmute',
      'player.voiceAssistant': 'Voice Assistant',
      'player.volume': 'Volume',
      'playlists.newPlaylist': 'New Playlist',
      'preferences.level.dislike': 'Dislike',
      'preferences.level.do-not-appear': 'Do not appear',
      'preferences.level.high': 'High',
      'preferences.level.higher': 'Higher',
      'preferences.level.normal': 'Normal',
      'preferences.level.very-high': 'Very High',
      'preferences.undoPrefer': 'Undo Preference',
      'settings.preferenceSettings': 'Preference Settings',
    },
  );

  test('clampVolumeValue mirrors Electron volume bounds', () {
    expect(clampVolumeValue(-12), 0);
    expect(clampVolumeValue(42.4), 42);
    expect(clampVolumeValue(42.6), 43);
    expect(clampVolumeValue(150), 100);
  });

  test('playerVolumeIcon mirrors Electron volume icon thresholds', () {
    expect(playerVolumeIcon(0, false), FluentIcons.speaker_off_20_regular);
    expect(playerVolumeIcon(20, false), FluentIcons.speaker_1_20_regular);
    expect(playerVolumeIcon(50, false), FluentIcons.speaker_1_20_regular);
    expect(playerVolumeIcon(80, false), FluentIcons.speaker_2_20_regular);
    expect(playerVolumeIcon(80, true), FluentIcons.speaker_mute_20_regular);
  });

  test(
    'resolvePlayerDurationSeconds falls back to current song like Electron',
    () {
      expect(resolvePlayerDurationSeconds(12, _song), 12);
      expect(resolvePlayerDurationSeconds(0, _song), 180);
      expect(resolvePlayerDurationSeconds(0, null), 0);
    },
  );

  test(
    'selectPlayerArtworkAccentColorFromRgba mirrors Electron grid picker',
    () {
      const width = 16;
      const height = 16;
      final pixels = Uint8List(width * height * 4);

      void setPixel(int x, int y, int red, int green, int blue, int alpha) {
        final offset = (y * width + x) * 4;
        pixels[offset] = red;
        pixels[offset + 1] = green;
        pixels[offset + 2] = blue;
        pixels[offset + 3] = alpha;
      }

      setPixel(1, 1, 20, 20, 20, 255);
      setPixel(2, 2, 250, 80, 80, 255);
      setPixel(3, 3, 160, 140, 120, 255);
      setPixel(4, 4, 200, 10, 10, 0);

      expect(
        selectPlayerArtworkAccentColorFromRgba(pixels, width, height),
        const Color(0xffa08c78),
      );
    },
  );

  testWidgets('MediaControl uses Electron-style night player colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: MediaControl(
              track: const MediaControlTrack(
                id: 1,
                title: 'Song',
                artist: 'Artist',
                artworkUrl: '',
                isLoading: false,
              ),
              currentSong: _song,
              disabled: false,
              isPlaying: false,
              volume: 50,
              isMuted: false,
              mode: PlaybackMode.once,
              progressSeconds: 12,
              durationSeconds: 180,
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeek: (_) {},
              onBeginSeek: () {},
              onEndSeek: () {},
              onVolumeChange: (_) {},
              onToggleMute: () {},
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleFavorite: () {},
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {},
            ),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Song').first);
    final artist = tester.widget<Text>(find.text('Artist').first);

    expect(title.style?.color, MediaControlColors.nightText);
    expect(artist.style?.color, MediaControlColors.nightMuted);
  });

  test('MediaControl player background constants mirror Electron CSS', () {
    expect(MediaControlColors.playerSurfaceSolid, const Color(0xd1ffffff));
    expect(MediaControlColors.playerSurface, const Color(0xe0ffffff));
    expect(MediaControlColors.playerAccentWash, const Color(0x1a0078d7));
    expect(MediaControlColors.emptyPlayerAccentWash, const Color(0x100078d7));
    expect(MediaControlColors.emptyPlayerLeftWash, const Color(0xe0ffffff));
    expect(MediaControlColors.emptyPlayerRightWash, const Color(0x1a0078d7));
    expect(MediaControlColors.compactPlayerBorder, const Color(0x9effffff));
    expect(MediaControlColors.compactPlayerSurface, const Color(0xd1f8fbfe));
    expect(MediaControlColors.compactPlayerTop, const Color(0xbdffffff));
    expect(MediaControlColors.compactPlayerBottom, const Color(0xb3f6fafe));
    expect(MediaControlColors.compactPlayerWash, const Color(0xa8ffffff));
    expect(MediaControlColors.emptyCompactPlayerWash, const Color(0xccffffff));
    expect(
      MediaControlColors.compactPlayerInsetHighlight,
      const Color(0xd1ffffff),
    );
    expect(MediaControlColors.nightPlayerSurface, const Color(0xe611161c));
    expect(MediaControlColors.nightPlayerHighlight, const Color(0x0effffff));
    expect(MediaControlColors.nightPlayerAccentWash, const Color(0x1f0078d7));
    expect(
      MediaControlColors.nightEmptyPlayerAccentWash,
      const Color(0x120078d7),
    );
    expect(
      MediaControlColors.nightEmptyPlayerRightWash,
      const Color(0x18162028),
    );
    expect(
      MediaControlColors.nightEmptyCompactPlayerWash,
      const Color(0xd611161c),
    );
  });

  test('resolvePlayerArtworkPath uses current song artwork like Electron', () {
    expect(
      resolvePlayerArtworkPath(
        const MediaControlTrack(
          id: 1,
          title: 'Song',
          artist: 'Artist',
          artworkUrl: '',
          isLoading: false,
        ),
        const LibrarySong(
          id: 1,
          path: r'C:\Music\song.mp3',
          title: 'Song',
          artist: 'Artist',
          artists: ['Artist'],
          album: 'Album',
          duration: 180,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '2026-05-20T00:00:00',
          favorite: false,
          thumbnailPath: r'C:\Music\thumb.png',
        ),
      ),
      r'C:\Music\thumb.png',
    );
    expect(
      resolvePlayerArtworkPath(
        const MediaControlTrack(
          id: 1,
          title: 'Song',
          artist: 'Artist',
          artworkUrl: r'C:\Music\track-thumb.png',
          isLoading: false,
        ),
        null,
      ),
      r'C:\Music\track-thumb.png',
    );
  });

  testWidgets('VolumeSlider shows transient Electron-style value tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: VolumeSlider(
                value: 37,
                disabled: false,
                showTooltipOnMount: true,
                onChange: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('VolumeSlider.Tooltip')), findsOneWidget);
    expect(find.text('37'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 901));

    expect(find.byKey(const ValueKey('VolumeSlider.Tooltip')), findsNothing);
  });

  testWidgets('VolumeSlider rounds and de-dupes live changes', (tester) async {
    final changes = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: VolumeSlider(
                value: 20,
                disabled: false,
                onChange: changes.add,
              ),
            ),
          ),
        ),
      ),
    );

    var slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(72.3);
    await tester.pump();
    slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(72.4);
    await tester.pump();
    slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(73.0);
    await tester.pump();

    expect(changes, [72, 73]);
  });

  testWidgets('MediaControl clamps volume display like Electron surface', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 420);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: MediaControl(
              track: const MediaControlTrack(
                id: 1,
                title: 'Song',
                artist: 'Artist',
                artworkUrl: '',
                isLoading: false,
                favorite: false,
              ),
              disabled: false,
              isPlaying: false,
              volume: 150,
              isMuted: false,
              mode: PlaybackMode.once,
              progressSeconds: 0,
              durationSeconds: 180,
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeek: (_) {},
              onBeginSeek: () {},
              onEndSeek: () {},
              onVolumeChange: (_) {},
              onToggleMute: () {},
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleFavorite: () {},
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {},
            ),
          ),
        ),
      ),
    );

    final volumeSlider = tester.widget<Slider>(
      find.descendant(
        of: find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
        matching: find.byType(Slider),
      ),
    );
    expect(volumeSlider.value, 100);
    expect(find.byIcon(FluentIcons.speaker_2_20_regular), findsWidgets);
  });

  testWidgets('MediaControl keeps volume slider enabled when player is empty', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 420);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var changedVolume = 0;

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: MediaControl(
              track: const MediaControlTrack.empty(),
              disabled: true,
              isPlaying: false,
              volume: 73,
              isMuted: false,
              mode: PlaybackMode.once,
              progressSeconds: 0,
              durationSeconds: 0,
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeek: (_) {},
              onBeginSeek: () {},
              onEndSeek: () {},
              onVolumeChange: (volume) {
                changedVolume = volume;
              },
              onToggleMute: () {},
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleFavorite: () {},
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {},
            ),
          ),
        ),
      ),
    );

    final volumeSlider = tester.widget<Slider>(
      find.descendant(
        of: find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
        matching: find.byType(Slider),
      ),
    );
    expect(volumeSlider.value, 73);
    expect(volumeSlider.onChanged, isNotNull);

    volumeSlider.onChanged!(64);
    await tester.pump();

    expect(changedVolume, 64);
  });

  testWidgets(
    'MediaControl disables transport when track is empty but keeps volume live',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 420);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var playToggled = false;
      var changedVolume = 0;

      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            home: Scaffold(
              body: MediaControl(
                track: const MediaControlTrack.empty(),
                disabled: false,
                isPlaying: false,
                volume: 73,
                isMuted: false,
                mode: PlaybackMode.once,
                progressSeconds: 0,
                durationSeconds: 0,
                onTogglePlayPause: () {
                  playToggled = true;
                },
                onPrevious: () {},
                onNext: () {},
                onSeek: (_) {},
                onBeginSeek: () {},
                onEndSeek: () {},
                onVolumeChange: (volume) {
                  changedVolume = volume;
                },
                onToggleMute: () {},
                onToggleShuffle: () {},
                onToggleRepeat: () {},
                onToggleRepeatOne: () {},
                onToggleFavorite: () {},
                onQuickPlay: () {},
                onOpenNowPlaying: () {},
                onToggleWindowFullScreen: () {},
                isWindowFullScreen: false,
                onEnterMiniMode: () {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
      );
      await tester.pump();
      expect(playToggled, isFalse);

      final playButton = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final playDecoration = playButton.decoration! as BoxDecoration;
      expect(
        playDecoration.color,
        MediaControlColors.disabledPrimaryButtonSurface,
      );
      expect(playDecoration.boxShadow, const [
        BoxShadow(
          color: MediaControlColors.disabledPrimaryButtonShadow,
          offset: Offset(0, 8),
          blurRadius: 18,
        ),
      ]);
      expect(
        playDecoration.border,
        Border.all(
          color: MediaControlColors.disabledPrimaryButtonBorderFor(
            tester.element(
              find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
            ),
          ),
        ),
      );

      final volumeSlider = tester.widget<Slider>(
        find.descendant(
          of: find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
          matching: find.byType(Slider),
        ),
      );
      expect(volumeSlider.value, 73);
      expect(volumeSlider.onChanged, isNotNull);
      volumeSlider.onChanged!(64);
      await tester.pump();
      expect(changedVolume, 64);
    },
  );

  testWidgets(
    'MediaControl renders Electron player actions and updates state',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 120);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = MediaControlController(
        const MediaControlState(
          track: MediaControlTrack(
            id: 1,
            title: 'Song',
            artist: 'Artist',
            artworkUrl: '',
            isLoading: false,
            favorite: false,
          ),
          disabled: false,
          isPlaying: false,
          volume: 50,
          isMuted: false,
          mode: PlaybackMode.once,
          progressSeconds: 0,
          durationSeconds: 180,
          isProgressSeeking: false,
        ),
      );

      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            home: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final state = controller.state;
                  return MediaControl(
                    track: state.track,
                    disabled: state.disabled,
                    isPlaying: state.isPlaying,
                    volume: state.volume,
                    isMuted: state.isMuted,
                    mode: state.mode,
                    progressSeconds: state.progressSeconds,
                    durationSeconds: state.durationSeconds,
                    playbackNoticeKey: state.playbackNoticeKey,
                    onTogglePlayPause: controller.onTogglePlayPause,
                    onPrevious: controller.onPrevious,
                    onNext: controller.onNext,
                    onSeek: controller.onSeek,
                    onBeginSeek: controller.onBeginSeek,
                    onEndSeek: controller.onEndSeek,
                    onVolumeChange: controller.onVolumeChange,
                    onToggleMute: controller.onToggleMute,
                    onToggleShuffle: controller.onToggleShuffle,
                    onToggleRepeat: controller.onToggleRepeat,
                    onToggleRepeatOne: controller.onToggleRepeatOne,
                    onToggleFavorite: controller.onToggleFavorite,
                    onQuickPlay: () {},
                    onOpenNowPlaying: () {},
                    onToggleWindowFullScreen: () {},
                    isWindowFullScreen: false,
                    onEnterMiniMode: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Song'), findsOneWidget);
      expect(find.text('Artist'), findsOneWidget);
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('3:00'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
      );
      await tester.pump();
      expect(controller.state.isPlaying, isTrue);

      await tester.tap(find.byKey(const ValueKey('MediaControl.NextButton')));
      await tester.pump();
      expect(controller.state.progressSeconds, 0);
    },
  );

  testWidgets(
    'medium MediaControl condenses utility controls like Electron responsive player',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 160);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = MediaControlController(
        const MediaControlState(
          track: MediaControlTrack(
            id: 1,
            title: 'Song',
            artist: 'Artist',
            artworkUrl: '',
            isLoading: false,
            favorite: false,
          ),
          disabled: false,
          isPlaying: false,
          volume: 50,
          isMuted: false,
          mode: PlaybackMode.once,
          progressSeconds: 0,
          durationSeconds: 180,
          isProgressSeeking: false,
        ),
      );

      Future<void> pumpMediaControl() {
        return tester.pumpWidget(
          SmPlayerI18nScope(
            i18n: i18n,
            child: MaterialApp(
              home: Scaffold(
                body: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final state = controller.state;
                    return MediaControl(
                      track: state.track,
                      disabled: state.disabled,
                      isPlaying: state.isPlaying,
                      volume: state.volume,
                      isMuted: state.isMuted,
                      mode: state.mode,
                      progressSeconds: state.progressSeconds,
                      durationSeconds: state.durationSeconds,
                      onTogglePlayPause: controller.onTogglePlayPause,
                      onPrevious: controller.onPrevious,
                      onNext: controller.onNext,
                      onSeek: controller.onSeek,
                      onBeginSeek: controller.onBeginSeek,
                      onEndSeek: controller.onEndSeek,
                      onVolumeChange: controller.onVolumeChange,
                      onToggleMute: controller.onToggleMute,
                      onToggleShuffle: controller.onToggleShuffle,
                      onToggleRepeat: controller.onToggleRepeat,
                      onToggleRepeatOne: controller.onToggleRepeatOne,
                      onToggleFavorite: controller.onToggleFavorite,
                      onQuickPlay: () {},
                      onOpenNowPlaying: () {},
                      onToggleWindowFullScreen: () {},
                      isWindowFullScreen: false,
                      onEnterMiniMode: () {},
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }

      await pumpMediaControl();

      expect(find.text('Song'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      );
      await tester.pump();
      expect(controller.state.mode, PlaybackMode.shuffle);

      await tester.tap(
        find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('MediaControl.CompactVolumePopover')),
        findsOneWidget,
      );
      final verticalSlider = tester.widget<RotatedBox>(find.byType(RotatedBox));
      expect(verticalSlider.quarterTurns, -1);

      await tester.tap(find.text('Song'));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('MediaControl.CompactVolumePopover')),
        findsNothing,
      );
    },
  );

  testWidgets('wide MediaControl caps track copy width like Electron CSS', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 420);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: MediaControl(
              track: const MediaControlTrack(
                id: 1,
                title:
                    'A very long song title that should not push the player controls away',
                artist:
                    'A very long artist name that should stay inside the Electron width cap',
                artworkUrl: '',
                isLoading: false,
                favorite: false,
              ),
              disabled: false,
              isPlaying: false,
              volume: 50,
              isMuted: false,
              mode: PlaybackMode.once,
              progressSeconds: 0,
              durationSeconds: 180,
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeek: (_) {},
              onBeginSeek: () {},
              onEndSeek: () {},
              onVolumeChange: (_) {},
              onToggleMute: () {},
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleFavorite: () {},
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester
          .getSize(find.byKey(const ValueKey('MediaControl.TrackCopy')))
          .width,
      closeTo(1280 * 0.24, 0.1),
    );
  });

  testWidgets('MediaControl progress uses current song duration fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: MediaControl(
              track: const MediaControlTrack(
                id: 1,
                title: 'Song',
                artist: 'Artist',
                artworkUrl: '',
                isLoading: false,
              ),
              currentSong: _song,
              disabled: false,
              isPlaying: false,
              volume: 50,
              isMuted: false,
              mode: PlaybackMode.once,
              progressSeconds: 12,
              durationSeconds: 0,
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeek: (_) {},
              onBeginSeek: () {},
              onEndSeek: () {},
              onVolumeChange: (_) {},
              onToggleMute: () {},
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleFavorite: () {},
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('0:12'), findsOneWidget);
    expect(find.text('3:00'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNotNull);
  });

  testWidgets(
    'MediaControl renders playback load failure without file details',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            home: Scaffold(
              body: MediaControl(
                track: const MediaControlTrack(
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
                durationSeconds: 180,
                playbackNoticeKey: 'player.playbackLoadFailed',
                onTogglePlayPause: () {},
                onPrevious: () {},
                onNext: () {},
                onSeek: (_) {},
                onBeginSeek: () {},
                onEndSeek: () {},
                onVolumeChange: (_) {},
                onToggleMute: () {},
                onToggleShuffle: () {},
                onToggleRepeat: () {},
                onToggleRepeatOne: () {},
                onToggleFavorite: () {},
                onQuickPlay: () {},
                onOpenNowPlaying: () {},
                onToggleWindowFullScreen: () {},
                isWindowFullScreen: false,
                onEnterMiniMode: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Could not play this song.'), findsOneWidget);
      expect(find.textContaining('/'), findsNothing);
    },
  );

  testWidgets('MediaControl renders Electron-style current lyrics line', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: MediaControl(
              track: const MediaControlTrack(
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
              progressSeconds: 12,
              durationSeconds: 180,
              currentLyricsLine: 'Current lyric',
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeek: (_) {},
              onBeginSeek: () {},
              onEndSeek: () {},
              onVolumeChange: (_) {},
              onToggleMute: () {},
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleFavorite: () {},
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Current lyric'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('MediaControl.CurrentLyricsContainer')),
      findsOneWidget,
    );
    expect(find.byType(AnimatedSwitcher), findsOneWidget);
    expect(find.byType(SlideTransition), findsWidgets);
  });

  testWidgets(
    'MediaControl artwork overlay mirrors Electron hover affordance',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            home: Scaffold(
              body: MediaControl(
                track: const MediaControlTrack(
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
                progressSeconds: 12,
                durationSeconds: 180,
                onTogglePlayPause: () {},
                onPrevious: () {},
                onNext: () {},
                onSeek: (_) {},
                onBeginSeek: () {},
                onEndSeek: () {},
                onVolumeChange: (_) {},
                onToggleMute: () {},
                onToggleShuffle: () {},
                onToggleRepeat: () {},
                onToggleRepeatOne: () {},
                onToggleFavorite: () {},
                onQuickPlay: () {},
                onOpenNowPlaying: () {},
                onToggleWindowFullScreen: () {},
                isWindowFullScreen: false,
                onEnterMiniMode: () {},
              ),
            ),
          ),
        ),
      );

      final overlayFinder = find.byKey(
        const ValueKey('MediaControl.ArtworkOverlay'),
      );
      expect(tester.widget<AnimatedOpacity>(overlayFinder).opacity, 0);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(find.text('Song')));
      await tester.pump();

      expect(tester.widget<AnimatedOpacity>(overlayFinder).opacity, 1);
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    },
  );

  test(
    'extractPlayerArtworkAccentColor falls back when artwork cannot decode',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'smplayer-artwork-',
      );
      addTearDown(() {
        tempDir.deleteSync(recursive: true);
      });
      final artworkFile = File('${tempDir.path}/broken-artwork.bin');
      artworkFile.writeAsStringSync('not an image');

      expect(
        await extractPlayerArtworkAccentColor(artworkFile.path),
        const Color(0xff5b87b6),
      );
    },
  );

  testWidgets('MediaControl notifies artwork decode errors like Electron', (
    tester,
  ) async {
    final badArtwork = File(
      '${Directory.systemTemp.path}/smplayer_bad_artwork_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    badArtwork.writeAsStringSync('not an image');
    addTearDown(() {
      if (badArtwork.existsSync()) {
        badArtwork.deleteSync();
      }
    });
    var artworkErrorCount = 0;

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: MediaControl(
              track: MediaControlTrack(
                id: 1,
                title: 'Song',
                artist: 'Artist',
                artworkUrl: badArtwork.path,
                isLoading: false,
                favorite: false,
              ),
              currentSong: LibrarySong(
                id: 1,
                path: '/tmp/song.mp3',
                title: 'Song',
                artist: 'Artist',
                artists: const ['Artist'],
                album: 'Album',
                duration: 180,
                playCount: 0,
                lyricsOffsetMs: 0,
                dateAdded: '',
                favorite: false,
                thumbnailPath: badArtwork.path,
              ),
              disabled: false,
              isPlaying: false,
              volume: 50,
              isMuted: false,
              mode: PlaybackMode.once,
              progressSeconds: 0,
              durationSeconds: 180,
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeek: (_) {},
              onBeginSeek: () {},
              onEndSeek: () {},
              onVolumeChange: (_) {},
              onToggleMute: () {},
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleFavorite: () {},
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {},
              onArtworkError: () {
                artworkErrorCount += 1;
              },
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image).first);
    image.errorBuilder!(
      tester.element(find.byType(Image).first),
      StateError('bad image'),
      StackTrace.current,
    );

    expect(artworkErrorCount, 1);
  });

  testWidgets('MediaControl shows Electron-style loading progress bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: MediaControl(
              track: const MediaControlTrack(
                id: 1,
                title: 'Song',
                artist: 'Artist',
                artworkUrl: '',
                isLoading: true,
              ),
              disabled: false,
              isPlaying: false,
              volume: 50,
              isMuted: false,
              mode: PlaybackMode.once,
              progressSeconds: 0,
              durationSeconds: 180,
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeek: (_) {},
              onBeginSeek: () {},
              onEndSeek: () {},
              onVolumeChange: (_) {},
              onToggleMute: () {},
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleFavorite: () {},
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('MediaControl.ProgressLoading')),
      findsOneWidget,
    );
  });

  testWidgets('MediaControl More menu mirrors Electron empty player flyout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 420);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = MediaControlController(
      const MediaControlState(
        track: MediaControlTrack(
          id: 1,
          title: 'Song',
          artist: 'Artist',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        disabled: false,
        isPlaying: false,
        volume: 50,
        isMuted: false,
        mode: PlaybackMode.once,
        progressSeconds: 0,
        durationSeconds: 180,
        isProgressSeeking: false,
      ),
    );

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: MediaControl(
              track: controller.state.track,
              disabled: controller.state.disabled,
              isPlaying: controller.state.isPlaying,
              volume: controller.state.volume,
              isMuted: controller.state.isMuted,
              mode: controller.state.mode,
              progressSeconds: controller.state.progressSeconds,
              durationSeconds: controller.state.durationSeconds,
              onTogglePlayPause: controller.onTogglePlayPause,
              onPrevious: controller.onPrevious,
              onNext: controller.onNext,
              onSeek: controller.onSeek,
              onBeginSeek: controller.onBeginSeek,
              onEndSeek: controller.onEndSeek,
              onVolumeChange: controller.onVolumeChange,
              onToggleMute: controller.onToggleMute,
              onToggleShuffle: controller.onToggleShuffle,
              onToggleRepeat: controller.onToggleRepeat,
              onToggleRepeatOne: controller.onToggleRepeatOne,
              onToggleFavorite: controller.onToggleFavorite,
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('More').last);
    await tester.pumpAndSettle();

    expect(find.text('Quick Play'), findsOneWidget);
    final moreButtonCenter = tester.getCenter(
      find.byKey(const ValueKey('MediaControl.MoreButton')),
    );
    final quickPlayLeft = tester.getTopLeft(find.text('Quick Play')).dx;
    final quickPlayBottom = tester.getBottomLeft(find.text('Quick Play')).dy;
    final moreButtonTop = tester.getTopLeft(
      find.byKey(const ValueKey('MediaControl.MoreButton')),
    ).dy;
    expect(moreButtonCenter.dx, greaterThan(1100));
    expect(quickPlayLeft, greaterThan(900));
    expect(moreButtonCenter.dx - quickPlayLeft, lessThan(260));
    expect(quickPlayBottom, lessThan(moreButtonTop));
    expect(find.text('Playback Mode: List'), findsNothing);
    expect(find.text('View'), findsNothing);
    expect(find.text('Full Screen'), findsNothing);
    expect(find.text('Mini Mode'), findsNothing);
  });

  testWidgets(
    'MediaControl voice assistant stays available when player empty',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 420);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var voiceOpened = false;

      Future<void> pumpPlayer() {
        return tester.pumpWidget(
          SmPlayerI18nScope(
            i18n: i18n,
            child: MaterialApp(
              home: Scaffold(
                body: MediaControl(
                  track: const MediaControlTrack.empty(),
                  disabled: true,
                  isPlaying: false,
                  volume: 50,
                  isMuted: false,
                  mode: PlaybackMode.once,
                  progressSeconds: 0,
                  durationSeconds: 0,
                  onTogglePlayPause: () {},
                  onPrevious: () {},
                  onNext: () {},
                  onSeek: (_) {},
                  onBeginSeek: () {},
                  onEndSeek: () {},
                  onVolumeChange: (_) {},
                  onToggleMute: () {},
                  onToggleShuffle: () {},
                  onToggleRepeat: () {},
                  onToggleRepeatOne: () {},
                  onToggleFavorite: () {},
                  onQuickPlay: () {},
                  onOpenNowPlaying: () {},
                  onToggleWindowFullScreen: () {},
                  isWindowFullScreen: false,
                  onEnterMiniMode: () {},
                  onOpenVoiceAssistant: () {
                    voiceOpened = true;
                  },
                ),
              ),
            ),
          ),
        );
      }

      await pumpPlayer();
      await tester.tap(find.byTooltip('Voice Assistant'));
      await tester.pump();

      expect(voiceOpened, isTrue);

      tester.view.physicalSize = const Size(700, 420);
      voiceOpened = false;
      await pumpPlayer();
      await tester.tap(find.byTooltip('Voice Assistant'));
      await tester.pump();

      expect(voiceOpened, isTrue);
    },
  );

  testWidgets('compact MediaControl More menu exposes current song actions', (
    tester,
  ) async {
    int? addedPlaylistId;
    int? changedVolume;
    var favoriteToggled = false;
    var localOpened = false;
    var voiceOpened = false;

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: MediaControl(
              track: const MediaControlTrack(
                id: 1,
                title: 'Song',
                artist: 'Artist',
                artworkUrl: '',
                isLoading: false,
                favorite: false,
              ),
              currentSong: _song,
              playlists: const [
                LibraryPlaylist(
                  id: 3,
                  name: 'Built in',
                  priority: 0,
                  songCount: 0,
                  songIds: [],
                  sortCriterion: PlaylistSortCriterion.title,
                  isBuiltIn: true,
                ),
                LibraryPlaylist(
                  id: 10,
                  name: 'Mix',
                  priority: 1,
                  songCount: 0,
                  songIds: [],
                  sortCriterion: PlaylistSortCriterion.title,
                  isBuiltIn: false,
                ),
              ],
              disabled: false,
              isPlaying: false,
              volume: 50,
              isMuted: false,
              mode: PlaybackMode.once,
              progressSeconds: 0,
              durationSeconds: 180,
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeek: (_) {},
              onBeginSeek: () {},
              onEndSeek: () {},
              onVolumeChange: (volume) {
                changedVolume = volume;
              },
              onToggleMute: () {},
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleFavorite: () {
                favoriteToggled = true;
              },
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {},
              onOpenVoiceAssistant: () {
                voiceOpened = true;
              },
              onAddToPlaylist: (playlistId) {
                addedPlaylistId = playlistId;
              },
              onCreatePlaylist: () {},
              onSetPreference: (level) {},
              onSeeLocal: () {
                localOpened = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
      findsNothing,
    );
    expect(find.byTooltip('Playback Mode: List'), findsNothing);

    await tester.tap(find.byTooltip('Voice Assistant'));
    await tester.pump();
    expect(voiceOpened, isTrue);

    await tester.tap(find.byTooltip('More').last);
    await tester.pumpAndSettle();

    expect(find.text('Add To'), findsOneWidget);
    final moreButtonCenter = tester.getCenter(
      find.byKey(const ValueKey('MediaControl.MoreButton')),
    );
    final addToLeft = tester.getTopLeft(find.text('Add To')).dx;
    final addToBottom = tester.getBottomLeft(find.text('Add To')).dy;
    final moreButtonTop = tester.getTopLeft(
      find.byKey(const ValueKey('MediaControl.MoreButton')),
    ).dy;
    expect(moreButtonCenter.dx, greaterThan(720));
    expect(addToLeft, greaterThan(480));
    expect(moreButtonCenter.dx - addToLeft, lessThan(260));
    expect(addToBottom, lessThan(moreButtonTop));
    expect(find.text('Preference Settings'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('MediaControl.VolumeMenuItem')),
      findsOneWidget,
    );
    expect(find.text('Built in'), findsNothing);
    expect(find.text('Voice Assistant'), findsNothing);

    final volumeSlider = tester.widget<Slider>(find.byType(Slider).last);
    volumeSlider.onChanged!(72);
    await tester.pump();
    expect(changedVolume, 72);

    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();
    expect(find.text('My Favorites'), findsNothing);
    expect(find.text('New Playlist'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);

    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();
    expect(addedPlaylistId, 10);

    await tester.tap(find.byTooltip('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See Local File'));
    expect(localOpened, isTrue);

    expect(favoriteToggled, isFalse);
  });

  testWidgets('MediaControl resolves preference state when More menu opens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 420);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var resolveCount = 0;
    var undoCalled = false;
    String? selectedLevel;

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: MediaControl(
              track: const MediaControlTrack(
                id: 1,
                title: 'Song',
                artist: 'Artist',
                artworkUrl: '',
                isLoading: false,
                favorite: false,
              ),
              currentSong: _song,
              disabled: false,
              isPlaying: false,
              volume: 50,
              isMuted: false,
              mode: PlaybackMode.once,
              progressSeconds: 0,
              durationSeconds: 180,
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeek: (_) {},
              onBeginSeek: () {},
              onEndSeek: () {},
              onVolumeChange: (_) {},
              onToggleMute: () {},
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleFavorite: () {},
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {},
              onResolvePreferenceLevel: () async {
                resolveCount += 1;
                return 'higher';
              },
              onUndoPreference: () {
                undoCalled = true;
              },
              onSetPreference: (level) {
                selectedLevel = level;
              },
              onSeeArtist: () {},
              onSeeAlbum: () {},
              onSeeMusicInfo: () {},
              onSeeLyrics: () {},
              onSeeAlbumArt: () {},
              onSeeLocal: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('More').last);
    await tester.pumpAndSettle();

    expect(resolveCount, 1);

    await tester.tap(find.text('Preference Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Undo Preference'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byIcon(FluentIcons.checkmark_20_regular), findsOneWidget);

    await tester.tap(find.text('Undo Preference'));
    await tester.pumpAndSettle();
    expect(undoCalled, isTrue);

    await tester.tap(find.byTooltip('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preference Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High'));
    expect(selectedLevel, 'high');
  });

  testWidgets('wide MediaControl Add To includes favorites like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 420);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: MediaControl(
              track: const MediaControlTrack(
                id: 1,
                title: 'Song',
                artist: 'Artist',
                artworkUrl: '',
                isLoading: false,
                favorite: false,
              ),
              currentSong: _song,
              disabled: false,
              isPlaying: false,
              volume: 50,
              isMuted: false,
              mode: PlaybackMode.once,
              progressSeconds: 0,
              durationSeconds: 180,
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeek: (_) {},
              onBeginSeek: () {},
              onEndSeek: () {},
              onVolumeChange: (_) {},
              onToggleMute: () {},
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleFavorite: () {},
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {},
              onCreatePlaylist: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();

    expect(find.text('My Favorites'), findsOneWidget);
  });

  testWidgets(
    'compact playback mode button opens Electron-style long press menu',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(700, 420);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = MediaControlController(
        const MediaControlState(
          track: MediaControlTrack(
            id: 1,
            title: 'Song',
            artist: 'Artist',
            artworkUrl: '',
            isLoading: false,
            favorite: false,
          ),
          disabled: false,
          isPlaying: false,
          volume: 50,
          isMuted: false,
          mode: PlaybackMode.once,
          progressSeconds: 0,
          durationSeconds: 180,
          isProgressSeeking: false,
        ),
      );

      Future<void> pumpMediaControl() {
        return tester.pumpWidget(
          SmPlayerI18nScope(
            i18n: i18n,
            child: MaterialApp(
              home: Scaffold(
                body: MediaControl(
                  track: controller.state.track,
                  disabled: controller.state.disabled,
                  isPlaying: controller.state.isPlaying,
                  volume: controller.state.volume,
                  isMuted: controller.state.isMuted,
                  mode: controller.state.mode,
                  progressSeconds: controller.state.progressSeconds,
                  durationSeconds: controller.state.durationSeconds,
                  onTogglePlayPause: controller.onTogglePlayPause,
                  onPrevious: controller.onPrevious,
                  onNext: controller.onNext,
                  onSeek: controller.onSeek,
                  onBeginSeek: controller.onBeginSeek,
                  onEndSeek: controller.onEndSeek,
                  onVolumeChange: controller.onVolumeChange,
                  onToggleMute: controller.onToggleMute,
                  onToggleShuffle: controller.onToggleShuffle,
                  onToggleRepeat: controller.onToggleRepeat,
                  onToggleRepeatOne: controller.onToggleRepeatOne,
                  onToggleFavorite: controller.onToggleFavorite,
                  onQuickPlay: () {},
                  onOpenNowPlaying: () {},
                  onToggleWindowFullScreen: () {},
                  isWindowFullScreen: false,
                  onEnterMiniMode: () {},
                ),
              ),
            ),
          ),
        );
      }

      await pumpMediaControl();

      await tester.longPress(find.byTooltip('Playback Mode: List').last);
      await tester.pumpAndSettle();

      expect(find.text('List'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.text('Repeat'), findsOneWidget);
      expect(find.text('Repeat One'), findsOneWidget);

      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();

      expect(controller.state.mode, PlaybackMode.repeat);

      await pumpMediaControl();
      await tester.pumpAndSettle();
      await tester.longPress(find.byTooltip('Playback Mode: Repeat').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();

      expect(controller.state.mode, PlaybackMode.repeat);
    },
  );

  testWidgets('compact MediaControl narrows buttons at Electron 520px rule', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Future<void> pumpAtWidth(double width) {
      tester.view.physicalSize = Size(width, 420);
      return tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            home: Scaffold(
              body: MediaControl(
                track: const MediaControlTrack(
                  id: 1,
                  title: 'Song',
                  artist: 'Artist',
                  artworkUrl: '',
                  isLoading: false,
                  favorite: false,
                ),
                disabled: false,
                isPlaying: false,
                volume: 50,
                isMuted: false,
                mode: PlaybackMode.once,
                progressSeconds: 0,
                durationSeconds: 180,
                onTogglePlayPause: () {},
                onPrevious: () {},
                onNext: () {},
                onSeek: (_) {},
                onBeginSeek: () {},
                onEndSeek: () {},
                onVolumeChange: (_) {},
                onToggleMute: () {},
                onToggleShuffle: () {},
                onToggleRepeat: () {},
                onToggleRepeatOne: () {},
                onToggleFavorite: () {},
                onQuickPlay: () {},
                onOpenNowPlaying: () {},
                onToggleWindowFullScreen: () {},
                isWindowFullScreen: false,
                onEnterMiniMode: () {},
              ),
            ),
          ),
        ),
      );
    }

    await pumpAtWidth(700);
    await tester.pumpAndSettle();

    expect(
      tester.getSize(
        find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
      ),
      const Size(52, 52),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      ),
      const Size(36, 36),
    );

    await pumpAtWidth(500);
    await tester.pumpAndSettle();

    expect(
      tester.getSize(
        find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
      ),
      const Size(48, 48),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      ),
      const Size(34, 34),
    );
  });

  testWidgets('medium MediaControl volume opens Electron vertical popover', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 420);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var changedVolume = 0;

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: MediaControl(
              track: const MediaControlTrack(
                id: 1,
                title: 'Song',
                artist: 'Artist',
                artworkUrl: '',
                isLoading: false,
                favorite: false,
              ),
              disabled: false,
              isPlaying: false,
              volume: 50,
              isMuted: false,
              mode: PlaybackMode.once,
              progressSeconds: 0,
              durationSeconds: 180,
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeek: (_) {},
              onBeginSeek: () {},
              onEndSeek: () {},
              onVolumeChange: (volume) {
                changedVolume = volume;
              },
              onToggleMute: () {},
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleFavorite: () {},
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
      findsNothing,
    );

    expect(
      find.byKey(const ValueKey('MediaControl.CompactVolumePopover')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('MediaControl.CompactVolumePopover')),
      findsOneWidget,
    );
    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, -1);

    final volumeSlider = tester.widget<Slider>(find.byType(Slider).last);
    volumeSlider.onChanged!(64);
    await tester.pump();

    expect(changedVolume, 64);

    await tester.tap(find.text('Song'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('MediaControl.CompactVolumePopover')),
      findsNothing,
    );
  });

  testWidgets(
    'compact MediaControl keeps More mode and volume available when empty like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(700, 420);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var shuffleToggled = false;
      var changedVolume = 0;

      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            home: Scaffold(
              body: MediaControl(
                track: const MediaControlTrack.empty(),
                disabled: true,
                isPlaying: false,
                volume: 73,
                isMuted: false,
                mode: PlaybackMode.once,
                progressSeconds: 0,
                durationSeconds: 0,
                onTogglePlayPause: () {},
                onPrevious: () {},
                onNext: () {},
                onSeek: (_) {},
                onBeginSeek: () {},
                onEndSeek: () {},
                onVolumeChange: (volume) {
                  changedVolume = volume;
                },
                onToggleMute: () {},
                onToggleShuffle: () {
                  shuffleToggled = true;
                },
                onToggleRepeat: () {},
                onToggleRepeatOne: () {},
                onToggleFavorite: () {},
                onQuickPlay: () {},
                onOpenNowPlaying: () {},
                onToggleWindowFullScreen: () {},
                isWindowFullScreen: false,
                onEnterMiniMode: () {},
              ),
            ),
          ),
        ),
      );

      final disabledPlayButton = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final disabledPlayButtonDecoration =
          disabledPlayButton.decoration! as BoxDecoration;
      expect(
        disabledPlayButtonDecoration.color,
        MediaControlColors.disabledPrimaryButtonSurface,
      );
      expect(disabledPlayButtonDecoration.boxShadow, const [
        BoxShadow(
          color: MediaControlColors.disabledPrimaryButtonShadow,
          offset: Offset(0, 8),
          blurRadius: 18,
        ),
      ]);
      expect(
        disabledPlayButtonDecoration.border,
        Border.all(
          color: MediaControlColors.disabledPrimaryButtonBorderFor(
            tester.element(
              find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
        ),
        const Size(52, 52),
      );
      expect(disabledPlayButton.padding, const EdgeInsets.all(13));
      final disabledProgressTheme = tester.widget<SliderTheme>(
        find
            .ancestor(
              of: find.byType(Slider).first,
              matching: find.byType(SliderTheme),
            )
            .first,
      );
      expect(
        disabledProgressTheme.data.disabledThumbColor,
        MediaControlColors.accent.withValues(alpha: 0.8),
      );
      expect(disabledProgressTheme.data.trackHeight, 2);
      final progressSlider = tester.widget<Slider>(find.byType(Slider).first);
      expect(progressSlider.onChanged, isNull);
      final defaultArtwork = tester.widget<Image>(find.byType(Image).first);
      final defaultArtworkProvider = defaultArtwork.image as AssetImage;
      expect(defaultArtworkProvider.assetName, 'assets/branding/app-icon.png');

      await tester.tap(find.byTooltip('Playback Mode: List').last);
      await tester.pump();
      expect(shuffleToggled, isFalse);

      await tester.tap(find.byTooltip('More').last);
      await tester.pumpAndSettle();

      expect(find.text('Playback Mode: List'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeMenuItem')),
        findsOneWidget,
      );

      final volumeSlider = tester.widget<Slider>(find.byType(Slider).last);
      expect(volumeSlider.value, 73);
      expect(volumeSlider.onChanged, isNotNull);
      volumeSlider.onChanged!(64);
      await tester.pump();
      expect(changedVolume, 64);
    },
  );

  testWidgets('compact progress seek commits once on release like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 420);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final seeked = <double>[];
    var beginSeekCount = 0;
    var endSeekCount = 0;

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: MediaControl(
              track: const MediaControlTrack(
                id: 1,
                title: 'Song',
                artist: 'Artist',
                artworkUrl: '',
                isLoading: false,
                favorite: false,
              ),
              disabled: false,
              isPlaying: false,
              volume: 50,
              isMuted: false,
              mode: PlaybackMode.once,
              progressSeconds: 10,
              durationSeconds: 180,
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeek: seeked.add,
              onBeginSeek: () {
                beginSeekCount += 1;
              },
              onEndSeek: () {
                endSeekCount += 1;
              },
              onVolumeChange: (_) {},
              onToggleMute: () {},
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleFavorite: () {},
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {},
            ),
          ),
        ),
      ),
    );

    final progressSlider =
        tester.widgetList<Slider>(find.byType(Slider)).single;
    progressSlider.onChangeStart!(10);
    await tester.pump();
    progressSlider.onChanged!(42);
    await tester.pump();

    expect(beginSeekCount, 1);
    expect(seeked, isEmpty);
    expect(find.text('0:42'), findsOneWidget);

    progressSlider.onChangeEnd!(42);
    await tester.pump();

    expect(seeked, [42]);
    expect(endSeekCount, 1);
  });

  testWidgets('MediaControl ignores seek release without begin like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 420);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final seeked = <double>[];
    var endSeekCount = 0;

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: MediaControl(
              track: const MediaControlTrack(
                id: 1,
                title: 'Song',
                artist: 'Artist',
                artworkUrl: '',
                isLoading: false,
                favorite: false,
              ),
              disabled: false,
              isPlaying: false,
              volume: 50,
              isMuted: false,
              mode: PlaybackMode.once,
              progressSeconds: 10,
              durationSeconds: 180,
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeek: seeked.add,
              onBeginSeek: () {},
              onEndSeek: () {
                endSeekCount += 1;
              },
              onVolumeChange: (_) {},
              onToggleMute: () {},
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleFavorite: () {},
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {},
            ),
          ),
        ),
      ),
    );

    final progressSlider = tester.widgetList<Slider>(find.byType(Slider)).first;
    progressSlider.onChangeEnd!(42);
    await tester.pump();

    expect(seeked, isEmpty);
    expect(endSeekCount, 0);
  });

  testWidgets(
    'compact MediaControl ignores seek release without begin like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(700, 420);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final seeked = <double>[];
      var endSeekCount = 0;

      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            home: Scaffold(
              body: MediaControl(
                track: const MediaControlTrack(
                  id: 1,
                  title: 'Song',
                  artist: 'Artist',
                  artworkUrl: '',
                  isLoading: false,
                  favorite: false,
                ),
                disabled: false,
                isPlaying: false,
                volume: 50,
                isMuted: false,
                mode: PlaybackMode.once,
                progressSeconds: 10,
                durationSeconds: 180,
                onTogglePlayPause: () {},
                onPrevious: () {},
                onNext: () {},
                onSeek: seeked.add,
                onBeginSeek: () {},
                onEndSeek: () {
                  endSeekCount += 1;
                },
                onVolumeChange: (_) {},
                onToggleMute: () {},
                onToggleShuffle: () {},
                onToggleRepeat: () {},
                onToggleRepeatOne: () {},
                onToggleFavorite: () {},
                onQuickPlay: () {},
                onOpenNowPlaying: () {},
                onToggleWindowFullScreen: () {},
                isWindowFullScreen: false,
                onEnterMiniMode: () {},
              ),
            ),
          ),
        ),
      );

      final progressSlider =
          tester.widgetList<Slider>(find.byType(Slider)).single;
      progressSlider.onChangeEnd!(42);
      await tester.pump();

      expect(seeked, isEmpty);
      expect(endSeekCount, 0);
    },
  );
}

const _song = LibrarySong(
  id: 1,
  path: r'C:\Music\song.mp3',
  title: 'Song',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 180,
  playCount: 0,
  lyricsOffsetMs: 0,
  dateAdded: '2026-05-20T00:00:00',
  favorite: false,
  thumbnailPath: '',
);
