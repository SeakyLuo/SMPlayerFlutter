import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/exit_fullscreen_icon.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/playback/hold_release_action.dart';
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
      'player.playbackMode': 'Playback Mode',
      'player.playbackModeList': 'List',
      'player.playbackModeRepeat': 'Repeat',
      'player.playbackModeRepeatOne': 'Repeat One',
      'player.playbackModeShuffle': 'Shuffle',
      'player.previous': 'Previous',
      'player.forcePrevious': 'Force Previous',
      'player.restartCurrentTrack': 'Restart current track',
      'player.restartCurrentTrackHoldPrevious':
          'Restart current track. Hold to force Previous.',
      'player.repeatDisabled': 'Repeat: Disabled',
      'player.repeatEnabled': 'Repeat: Enabled',
      'player.repeatOneDisabled': 'Repeat One: Disabled',
      'player.repeatOneEnabled': 'Repeat One: Enabled',
      'player.shuffleDisabled': 'Shuffle: Disabled',
      'player.shuffleEnabled': 'Shuffle: Enabled',
      'player.trackProgress': 'Track progress',
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
    expect(playerVolumeIcon(0, false), mediaControlVolumeOffIcon);
    expect(playerVolumeIcon(20, false), mediaControlVolumeLowIcon);
    expect(playerVolumeIcon(50, false), mediaControlVolumeMediumIcon);
    expect(playerVolumeIcon(80, false), mediaControlVolumeHighIcon);
    expect(playerVolumeIcon(80, true), mediaControlVolumeMutedIcon);
    expect(playerVolumeIcon(50, false), isNot(playerVolumeIcon(80, false)));
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

  testWidgets('MediaControl wide player uses one shared player frame', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 220);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _mediaControlTestTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              child: MediaControl(
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
      ),
    );

    expect(find.byType(MediaControlPlayerFrame), findsOneWidget);
    expect(find.byType(MediaControlSurfaceBar), findsOneWidget);
    expect(find.byType(MediaControlSurface), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('MediaControl.ProgressRow')))
          .width,
      closeTo((1200 - 32) * 10 / 28, 0.5),
    );
    final trackRect = tester.getRect(find.text('Song'));
    final progressRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.ProgressRow')),
    );
    expect(trackRect.right, lessThan(progressRect.left));
  });

  testWidgets('MediaControl compact player fits narrow shell width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(358, 220);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _mediaControlTestTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 358,
              child: MediaControl(
                track: const MediaControlTrack(
                  id: 1,
                  title: 'A very long song title that must not overflow',
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
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('MediaControl.PlayerCompactBaseGradient')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('MediaControl.PlayerCompactCoverGradient')),
      findsNothing,
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey('MediaControl.MoreButton')))
          .right,
      lessThanOrEqualTo(346),
    );
  });

  testWidgets(
    'MediaControl condensed utility fits Electron voice and More row',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 220);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: _mediaControlTestTheme(),
            home: Scaffold(
              body: SizedBox(
                width: 1000,
                child: MediaControl(
                  track: const MediaControlTrack(
                    id: 1,
                    title: 'Condensed utility song',
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
                  onOpenVoiceAssistant: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        findsOneWidget,
      );
      expect(find.byTooltip('Voice Assistant'), findsOneWidget);
      expect(find.byTooltip('More'), findsOneWidget);
      expect(
        tester.getRect(find.byTooltip('Voice Assistant')).left -
            tester
                .getRect(
                  find.byKey(const ValueKey('MediaControl.CompactModeButton')),
                )
                .right,
        8,
      );
      expect(
        tester
                .getRect(find.byKey(const ValueKey('MediaControl.MoreButton')))
                .left -
            tester.getRect(find.byTooltip('Voice Assistant')).right,
        8,
      );
    },
  );

  testWidgets('MediaControl previous tooltip reflects restart action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 220);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _mediaControlTestTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              child: MediaControl(
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
                progressSeconds: 6,
                durationSeconds: 180,
                previousButtonRestartsTrack: true,
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
      ),
    );

    expect(
      find.byTooltip('Restart current track. Hold to force Previous.'),
      findsOneWidget,
    );
  });

  testWidgets('MediaControl previous button long press forces previous', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 220);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var previousCount = 0;
    var forcePreviousCount = 0;
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _mediaControlTestTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              child: MediaControl(
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
                progressSeconds: 6,
                durationSeconds: 180,
                previousButtonRestartsTrack: true,
                onTogglePlayPause: () {},
                onPrevious: () {
                  previousCount += 1;
                },
                onForcePrevious: () {
                  forcePreviousCount += 1;
                },
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
      ),
    );
    await tester.pumpAndSettle();

    final button =
        find.byKey(const ValueKey('MediaControl.PreviousButton')).last;
    expect(
      find.descendant(
        of: button,
        matching: find.byKey(const ValueKey('MediaControl.LongPressProgress')),
      ),
      findsOneWidget,
    );
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 250));
    expect(forcePreviousCount, 0);
    expect(previousCount, 0);
    await gesture.up();
    await tester.pump();
    expect(forcePreviousCount, 1);
    expect(previousCount, 0);
  });

  testWidgets(
    'MediaControl previous long press cancels outside button circle',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 220);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var previousCount = 0;
      var forcePreviousCount = 0;
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: _mediaControlTestTheme(),
            home: Scaffold(
              body: SizedBox(
                width: 1200,
                child: MediaControl(
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
                  progressSeconds: 6,
                  durationSeconds: 180,
                  previousButtonRestartsTrack: true,
                  onTogglePlayPause: () {},
                  onPrevious: () {
                    previousCount += 1;
                  },
                  onForcePrevious: () {
                    forcePreviousCount += 1;
                  },
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
        ),
      );
      await tester.pumpAndSettle();

      final button =
          find.byKey(const ValueKey('MediaControl.PreviousButton')).last;
      final rect = tester.getRect(button);
      final gesture = await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 250));
      await gesture.moveTo(rect.centerRight + const Offset(20, 0));
      await gesture.up();
      await tester.pump();

      expect(forcePreviousCount, 0);
      expect(previousCount, 0);
    },
  );

  testWidgets('MediaControl uses Electron-style night player colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _mediaControlTestTheme(brightness: Brightness.dark),
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
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(title.style?.fontVariations, const [FontVariation.weight(650)]);
    expect(artist.style?.color, MediaControlColors.nightMuted);
    expect(artist.style?.fontWeight, FontWeight.w500);
    expect(artist.style?.fontVariations, const [FontVariation.weight(520)]);
  });

  test('MediaControl player background constants mirror Electron CSS', () {
    expect(MediaControlColors.playerSurfaceSolid, const Color(0xd1ffffff));
    expect(MediaControlColors.playerSurface, const Color(0xe0ffffff));
    expect(MediaControlColors.playerAccentWash, const Color(0x1aabd9ff));
    expect(MediaControlColors.emptyPlayerAccentWash, const Color(0x100078d7));
    expect(MediaControlColors.emptyPlayerLeftWash, const Color(0xe0ffffff));
    expect(MediaControlColors.emptyPlayerRightWash, const Color(0x1aebf6ff));
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
    expect(MediaControlColors.nightTransportHover, const Color(0x2e0078d7));
    expect(MediaControlColors.favorite, const Color(0xffff1d1d));
    expect(MediaControlColors.favoriteActiveHover, const Color(0x38ffffff));
    expect(
      MediaControlColors.nightFavoriteActiveHover,
      const Color(0x1fffffff),
    );
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

  testWidgets('MediaControl play button hover mirrors Electron player CSS', (
    tester,
  ) async {
    Future<Color?> pumpAndHoverPlayButton(Brightness brightness) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: _mediaControlTestTheme(brightness: brightness),
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

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(
        tester.getCenter(
          find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      await mouse.removePointer();

      final playButton = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final playSlide = tester.widget<AnimatedSlide>(
        find
            .descendant(
              of: find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
              matching: find.byType(AnimatedSlide),
            )
            .first,
      );
      expect(playButton.duration, const Duration(milliseconds: 140));
      expect(playButton.curve, Curves.ease);
      expect(playSlide.duration, const Duration(milliseconds: 140));
      expect(playSlide.curve, Curves.ease);
      final playDecoration = playButton.decoration! as BoxDecoration;
      return playDecoration.color;
    }

    expect(
      await pumpAndHoverPlayButton(Brightness.light),
      MediaControlColors.accentStrong,
    );
    expect(
      await pumpAndHoverPlayButton(Brightness.dark),
      MediaControlColors.nightTransportHover,
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
        theme: _mediaControlTestTheme(),
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

  testWidgets(
    'VolumeSlider keeps tooltip 650ms after drag release like Electron',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _mediaControlTestTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                child: VolumeSlider(
                  value: 37,
                  disabled: false,
                  onChange: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChangeStart!(37);
      slider.onChanged!(64);
      slider.onChangeEnd!(64);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('VolumeSlider.Tooltip')),
        findsOneWidget,
      );
      expect(find.text('64'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 649));
      expect(
        find.byKey(const ValueKey('VolumeSlider.Tooltip')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(const ValueKey('VolumeSlider.Tooltip')), findsNothing);
    },
  );

  testWidgets('VolumeSlider tooltip follows the horizontal thumb', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _mediaControlTestTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: VolumeSlider(
                value: 20,
                disabled: false,
                showTooltipOnMount: true,
                onChange: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final initialCenter = tester.getCenter(
      find.byKey(const ValueKey('VolumeSlider.Tooltip')),
    );
    tester.widget<Slider>(find.byType(Slider)).onChanged!(80);
    await tester.pump();
    final draggedCenter = tester.getCenter(
      find.byKey(const ValueKey('VolumeSlider.Tooltip')),
    );
    final tooltipRect = tester.getRect(
      find.byKey(const ValueKey('VolumeSlider.Tooltip')),
    );
    final sliderRect = tester.getRect(find.byType(Slider));

    expect(draggedCenter.dx, greaterThan(initialCenter.dx + 80));
    expect(
      tooltipRect.bottom,
      lessThan(sliderRect.center.dy - _testVolumeSliderThumbRadius),
    );
  });

  testWidgets('VolumeSlider tooltip follows the vertical thumb', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _mediaControlTestTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 80,
              child: VolumeSlider(
                value: 20,
                disabled: false,
                orientation: VolumeSliderOrientation.vertical,
                showTooltipOnMount: true,
                onChange: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final initialCenter = tester.getCenter(
      find.byKey(const ValueKey('VolumeSlider.Tooltip')),
    );
    tester.widget<Slider>(find.byType(Slider)).onChanged!(80);
    await tester.pump();
    final draggedCenter = tester.getCenter(
      find.byKey(const ValueKey('VolumeSlider.Tooltip')),
    );
    final tooltipRect = tester.getRect(
      find.byKey(const ValueKey('VolumeSlider.Tooltip')),
    );
    final sliderRect = tester.getRect(find.byType(Slider));

    expect(draggedCenter.dy, lessThan(initialCenter.dy - 50));
    expect(
      tooltipRect.left,
      greaterThan(sliderRect.center.dx + _testVolumeSliderThumbRadius),
    );
  });

  testWidgets('VolumeSlider rounds and de-dupes live changes', (tester) async {
    final changes = <int>[];

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _mediaControlTestTheme(),
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
      ),
    );

    var slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(72.3);
    await tester.pump();
    Semantics volumeSemantics() {
      return tester
          .widgetList<Semantics>(find.byType(Semantics))
          .singleWhere((semantics) => semantics.properties.label == 'Volume');
    }

    expect(volumeSemantics().properties.value, '72');

    slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(72.4);
    await tester.pump();
    slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(73.0);
    await tester.pump();

    expect(changes, [72, 73]);
    expect(volumeSemantics().properties.value, '73');
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
          theme: _mediaControlTestTheme(),
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
    expect(
      find.byKey(
        ValueKey(
          'MediaControl.VolumeIcon.${mediaControlVolumeHighIcon.codePoint}',
        ),
      ),
      findsWidgets,
    );
  });

  testWidgets(
    'MediaControl volume icon follows live slider value like Electron',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 420);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final emittedVolumes = <int>[];

      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: _mediaControlTestTheme(),
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
                volume: 20,
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
                onVolumeChange: emittedVolumes.add,
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

      SmPlayerVolumeIconKind? volumeButtonIcon() {
        return tester
            .widget<SmPlayerVolumeIcon>(
              find.descendant(
                of: find.byKey(const ValueKey('MediaControl.VolumeButton')),
                matching: find.byType(SmPlayerVolumeIcon),
              ),
            )
            .kind;
      }

      expect(volumeButtonIcon(), SmPlayerVolumeIconKind.low);

      final volumeSlider = tester.widget<Slider>(
        find.descendant(
          of: find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
          matching: find.byType(Slider),
        ),
      );
      volumeSlider.onChanged!(50);
      await tester.pump();

      expect(emittedVolumes, [50]);
      expect(volumeButtonIcon(), SmPlayerVolumeIconKind.medium);
    },
  );

  testWidgets('MediaControl disables main volume slider when player is empty', (
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
          theme: _mediaControlTestTheme(),
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
    expect(volumeSlider.value, 0);
    expect(volumeSlider.onChanged, isNull);
  });

  testWidgets(
    'MediaControl disables transport and main volume when track is empty',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 420);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var playToggled = false;
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: _mediaControlTestTheme(),
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
      expect(playDecoration.color, MediaControlColors.disabledButtonSurface);
      expect(playDecoration.boxShadow, const [
        BoxShadow(
          color: MediaControlColors.accentShadow,
          offset: Offset(0, 12),
          blurRadius: 24,
        ),
      ]);
      expect(
        playDecoration.border,
        Border.all(color: MediaControlColors.accentBorder),
      );

      final volumeSlider = tester.widget<Slider>(
        find.descendant(
          of: find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
          matching: find.byType(Slider),
        ),
      );
      expect(volumeSlider.value, 0);
      expect(volumeSlider.onChanged, isNull);
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
            theme: _mediaControlTestTheme(),
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
      expect(
        find.byKey(const ValueKey('MediaControl.FavoriteOutlineIcon')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
      );
      await tester.pump();
      expect(controller.state.isPlaying, isTrue);

      await tester.tap(find.byKey(const ValueKey('MediaControl.NextButton')));
      await tester.pump();
      expect(controller.state.progressSeconds, 0);

      await tester.tap(find.byTooltip('Add to My Favorites'));
      await tester.pump();
      expect(controller.state.track.favorite, isTrue);
      expect(
        find.byKey(const ValueKey('MediaControl.FavoriteFilledIcon')),
        findsOneWidget,
      );
      var favoriteButton = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('MediaControl.FavoriteButton')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        (favoriteButton.decoration! as BoxDecoration).color,
        Colors.transparent,
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(
        tester.getCenter(
          find.byKey(const ValueKey('MediaControl.FavoriteButton')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      favoriteButton = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('MediaControl.FavoriteButton')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        (favoriteButton.decoration! as BoxDecoration).color,
        MediaControlColors.favoriteActiveHover,
      );
      await mouse.removePointer();
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
              theme: _mediaControlTestTheme(),
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

    final title =
        'A very long song title that should not push the player controls away';
    final artist =
        'A very long artist name that should stay inside the Electron width cap';

    Future<void> pumpTrack({
      required String title,
      required String artist,
    }) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: _mediaControlTestTheme(),
            home: Scaffold(
              body: MediaControl(
                track: MediaControlTrack(
                  id: 1,
                  title: title,
                  artist: artist,
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

    await pumpTrack(title: title, artist: artist);

    final titleText = tester.widget<Text>(find.text(title));
    final artistText = tester.widget<Text>(find.text(artist));
    expect(titleText.style?.fontWeight, FontWeight.w600);
    expect(titleText.style?.fontVariations, const [FontVariation.weight(650)]);
    expect(artistText.style?.fontWeight, FontWeight.w500);
    expect(artistText.style?.fontVariations, const [FontVariation.weight(520)]);

    final trackButton = find.ancestor(
      of: find.text(title),
      matching: find.byType(TextButton),
    );
    expect(tester.getSize(trackButton).width, lessThanOrEqualTo(414));
    final trackButtonStyle = tester.widget<TextButton>(trackButton).style!;
    expect(
      trackButtonStyle.backgroundColor?.resolve({WidgetState.hovered}),
      const Color(0x1f212b3a),
    );
    expect(
      trackButtonStyle.side?.resolve({WidgetState.hovered})?.color,
      const Color(0x14212b3a),
    );
    final expectedWideTrackColumn = (1280 - 32) * 9 / 28;
    final expectedWideTrackCopy = expectedWideTrackColumn - 72 - 14 - 12;
    expect(
      tester
          .getSize(find.byKey(const ValueKey('MediaControl.TrackCopy')))
          .width,
      closeTo(expectedWideTrackCopy, 0.1),
    );

    await pumpTrack(title: 'Song', artist: 'Artist');
    final shortTrackButton = find.ancestor(
      of: find.text('Song'),
      matching: find.byType(TextButton),
    );
    expect(tester.getSize(shortTrackButton).width, closeTo(218, 1));
    expect(tester.getSize(shortTrackButton).height, closeTo(96, 1));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('MediaControl.TrackCopy')))
          .width,
      120,
    );
  });

  testWidgets('MediaControl progress uses current song duration fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _mediaControlTestTheme(),
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
    'MediaControl keeps playback load failure out of the compact bar',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: _mediaControlTestTheme(),
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
                playbackNoticeKey: 'notification.playbackStalled',
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

      expect(find.text('Playback stalled.'), findsNothing);
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
          theme: _mediaControlTestTheme(),
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
    final lyrics = tester.widget<Text>(
      find.byKey(const ValueKey('MediaControl.CurrentLyricsLine')),
    );
    expect(lyrics.style?.color, MediaControlColors.textMuted);
    expect(lyrics.style?.fontWeight, FontWeight.w500);
    expect(lyrics.style?.fontVariations, const [FontVariation.weight(560)]);
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('MediaControl.CurrentLyricsContainer')),
        matching: find.byType(FractionalTranslation),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'MediaControl artwork overlay mirrors Electron hover affordance',
    (tester) async {
      var nowPlayingOpened = 0;
      var fullScreenToggled = 0;
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: _mediaControlTestTheme(),
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
                onOpenNowPlaying: () {
                  nowPlayingOpened += 1;
                },
                onToggleWindowFullScreen: () {
                  fullScreenToggled += 1;
                },
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
      expect(find.byType(SmPlayerFullscreenIcon), findsOneWidget);
      expect(
        tester.widget<SmPlayerFullscreenIcon>(
          find.byType(SmPlayerFullscreenIcon),
        ),
        isA<SmPlayerFullscreenIcon>()
            .having((icon) => icon.size, 'size', 36)
            .having((icon) => icon.strokeWidth, 'strokeWidth', 2),
      );

      await tester.tap(overlayFinder);
      await tester.pump();
      expect(nowPlayingOpened, 1);
      expect(fullScreenToggled, 0);
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
          theme: _mediaControlTestTheme(),
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
          theme: _mediaControlTestTheme(),
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
    expect(
      find.byKey(const ValueKey('MediaControl.ProgressSlider')),
      findsNothing,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('MediaControl.ProgressLoadingTrack')),
          )
          .height,
      2,
    );
    final loadingAnimation =
        tester
            .widget<AnimatedBuilder>(
              find.byKey(
                const ValueKey('MediaControl.ProgressLoadingAnimation'),
              ),
            )
            .animation;
    expect(loadingAnimation, isA<CurvedAnimation>());
    final curvedLoadingAnimation = loadingAnimation as CurvedAnimation;
    expect(curvedLoadingAnimation.curve, Curves.easeInOut);
    expect(
      (curvedLoadingAnimation.parent as AnimationController).duration,
      const Duration(milliseconds: 1200),
    );
    expect(mediaProgressLoadingSegmentWidthFactor, 0.35);
    expect(mediaProgressLoadingTravelWidthFactor, 0.35 * 3.85);
    expect(
      tester.getSize(find.byKey(const ValueKey('MediaControl.LoadingSpinner'))),
      const Size(22, 22),
    );
    final spinnerAnimation =
        tester
            .widget<AnimatedBuilder>(
              find.byKey(
                const ValueKey('MediaControl.LoadingSpinnerAnimation'),
              ),
            )
            .animation;
    expect(
      (spinnerAnimation as AnimationController).duration,
      mediaControlLoadingSpinnerDuration,
    );
    expect(mediaControlLoadingSpinnerSize, 22);
    expect(mediaControlLoadingSpinnerStrokeWidth, 2);
    expect(mediaControlLoadingSpinnerTrackColor, const Color(0x61ffffff));
    expect(mediaControlLoadingSpinnerTopColor, Colors.white);
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
          theme: _mediaControlTestTheme(),
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
    final moreButtonTop =
        tester
            .getTopLeft(find.byKey(const ValueKey('MediaControl.MoreButton')))
            .dy;
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
              theme: _mediaControlTestTheme(),
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
          theme: _mediaControlTestTheme(),
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
              onCreatePlaylist: (_) {},
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
    final moreButtonTop =
        tester
            .getTopLeft(find.byKey(const ValueKey('MediaControl.MoreButton')))
            .dy;
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
          theme: _mediaControlTestTheme(),
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
          theme: _mediaControlTestTheme(),
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
              onCreatePlaylist: (_) {},
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
    'wide MediaControl More exposes Electron view and window actions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 420);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var fullScreenToggled = 0;
      var miniModeEntered = 0;
      var lyricsOpened = 0;

      Future<void> pumpPlayer({required bool isWindowFullScreen}) {
        return tester.pumpWidget(
          SmPlayerI18nScope(
            i18n: i18n,
            child: MaterialApp(
              theme: _mediaControlTestTheme(),
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
                  onToggleWindowFullScreen: () {
                    fullScreenToggled += 1;
                  },
                  isWindowFullScreen: isWindowFullScreen,
                  onEnterMiniMode: () {
                    miniModeEntered += 1;
                  },
                  onSeeArtist: () {},
                  onSeeAlbum: () {},
                  onSeeMusicInfo: () {},
                  onSeeLyrics: () {
                    lyricsOpened += 1;
                  },
                  onSeeAlbumArt: () {},
                  onSeeLocal: () {},
                ),
              ),
            ),
          ),
        );
      }

      await pumpPlayer(isWindowFullScreen: false);
      await tester.tap(find.byTooltip('More').last);
      await tester.pumpAndSettle();

      expect(find.text('Quick Play'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Full Screen'), findsOneWidget);
      expect(find.byType(SmPlayerFullscreenIcon), findsWidgets);
      expect(find.text('Mini Mode'), findsOneWidget);

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text('See Artist'), findsOneWidget);
      expect(find.text('See Album'), findsOneWidget);
      expect(find.text('See Music Info'), findsOneWidget);
      expect(find.text('See Lyrics'), findsOneWidget);
      expect(find.text('See Album Art'), findsOneWidget);
      expect(find.text('See Local File'), findsOneWidget);

      await tester.tap(find.text('See Lyrics'));
      await tester.pumpAndSettle();
      expect(lyricsOpened, 1);

      await tester.tap(find.text('Mini Mode'));
      await tester.pumpAndSettle();
      expect(miniModeEntered, 1);

      await tester.tap(find.byTooltip('More').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Full Screen'));
      await tester.pumpAndSettle();
      expect(fullScreenToggled, 1);

      await pumpPlayer(isWindowFullScreen: true);
      await tester.tap(find.byTooltip('More').last);
      await tester.pumpAndSettle();
      expect(find.text('Exit Full Screen'), findsOneWidget);
      expect(find.byType(ExitFullscreenIcon), findsOneWidget);
    },
  );

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
              theme: _mediaControlTestTheme(),
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

      final modeButton = find.byTooltip('Playback Mode: List').last;
      final modeHoldAction = tester.widget<HoldReleaseAction>(
        find
            .ancestor(of: modeButton, matching: find.byType(HoldReleaseAction))
            .first,
      );
      expect(modeHoldAction.holdDuration, const Duration(milliseconds: 520));
      expect(modeHoldAction.triggerHoldOnReady, isTrue);

      await tester.tap(modeButton, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(controller.state.mode, PlaybackMode.once);
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      final modeHold = await tester.startGesture(
        tester.getCenter(modeButton),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Shuffle'), findsNothing);
      await tester.pump(const Duration(milliseconds: 120));
      await modeHold.up();
      expect(
        find.byKey(const ValueKey('MediaControl.LongPressProgress')),
        findsNothing,
      );
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
      final repeatModeButton = find.byTooltip('Playback Mode: Repeat').last;
      final repeatModeHold = await tester.startGesture(
        tester.getCenter(repeatModeButton),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 520));
      await repeatModeHold.up();
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
            theme: _mediaControlTestTheme(),
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

  testWidgets('compact MediaControl keeps artwork left aligned', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 420);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _mediaControlTestTheme(),
          home: Scaffold(
            body: MediaControl(
              track: const MediaControlTrack(
                id: 1,
                title: 'kpop4',
                artist: '未知歌手',
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

    final trackButton = find.ancestor(
      of: find.text('kpop4'),
      matching: find.byType(TextButton),
    );
    final overlay = find.byKey(const ValueKey('MediaControl.ArtworkOverlay'));
    expect(
      tester.getTopLeft(overlay).dx - tester.getTopLeft(trackButton).dx,
      closeTo(0, 1),
    );
  });

  testWidgets('compact MediaControl utility buttons fit near minimum width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Future<void> pumpAtWidth({
      required double width,
      required bool voiceAssistant,
    }) {
      tester.view.physicalSize = Size(width, 420);
      return tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: _mediaControlTestTheme(),
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
                onOpenVoiceAssistant: voiceAssistant ? () {} : null,
              ),
            ),
          ),
        ),
      );
    }

    for (final voiceAssistant in [false, true]) {
      await pumpAtWidth(width: 500, voiceAssistant: voiceAssistant);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'minimal MediaControl utility keeps only voice and More like Electron',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: _mediaControlTestTheme(),
            home: Scaffold(
              body: Center(
                child: MediaControlUtilityRows(
                  trackId: 1,
                  favorite: false,
                  disabled: false,
                  volumeValue: 50,
                  isMuted: false,
                  mode: PlaybackMode.once,
                  onVolumeChange: (_) {},
                  onToggleMute: () {},
                  onToggleShuffle: () {},
                  onToggleRepeat: () {},
                  onToggleRepeatOne: () {},
                  onToggleFavorite: () {},
                  onOpenVoiceAssistant: () {},
                  condensed: true,
                  minimal: true,
                  width: 80,
                  onMoreClick: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        findsNothing,
      );
      expect(find.byTooltip('Voice Assistant'), findsOneWidget);
      expect(find.byTooltip('More'), findsOneWidget);
    },
  );

  testWidgets('condensed MediaControl utility reserves Electron voice width', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _mediaControlTestTheme(),
          home: Scaffold(
            body: Center(
              child: MediaControlUtilityRows(
                trackId: 1,
                favorite: false,
                disabled: false,
                volumeValue: 50,
                isMuted: false,
                mode: PlaybackMode.once,
                onVolumeChange: (_) {},
                onToggleMute: () {},
                onToggleShuffle: () {},
                onToggleRepeat: () {},
                onToggleRepeatOne: () {},
                onToggleFavorite: () {},
                onOpenVoiceAssistant: () {},
                condensed: true,
                width: 132,
                onMoreClick: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(MediaControlUtilityRows)).width, 140);
    expect(
      find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      findsOneWidget,
    );
    expect(find.byTooltip('Voice Assistant'), findsOneWidget);
    expect(find.byTooltip('More'), findsOneWidget);
  });

  testWidgets(
    'MediaControlSurfaceBar reserves Electron utility slot with voice',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: _mediaControlTestTheme(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 500,
                  height: 120,
                  child: MediaControlSurfaceBar(
                    artworkPath: null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leadingWidth: 100,
                    leading: const SizedBox.shrink(),
                    utilityWidth: 132,
                    surfaceFlex: 1,
                    trackId: 1,
                    isLoading: false,
                    favorite: false,
                    disabled: false,
                    isPlaying: false,
                    volume: 50,
                    isMuted: false,
                    mode: PlaybackMode.once,
                    progressSeconds: 0,
                    durationSeconds: 120,
                    previousButtonRestartsTrack: false,
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
                    onOpenVoiceAssistant: () {},
                    utilityCondensed: true,
                    onMoreClick: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(MediaControlUtilityRows)).width, 140);
      expect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        findsOneWidget,
      );
      expect(find.byTooltip('Voice Assistant'), findsOneWidget);
      expect(find.byTooltip('More'), findsOneWidget);
    },
  );

  testWidgets(
    'minimal MediaControl utility allows Electron 68px centered overhang',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: _mediaControlTestTheme(),
            home: Scaffold(
              body: Center(
                child: MediaControlUtilityRows(
                  trackId: 1,
                  favorite: false,
                  disabled: false,
                  volumeValue: 50,
                  isMuted: false,
                  mode: PlaybackMode.once,
                  onVolumeChange: (_) {},
                  onToggleMute: () {},
                  onToggleShuffle: () {},
                  onToggleRepeat: () {},
                  onToggleRepeatOne: () {},
                  onToggleFavorite: () {},
                  condensed: true,
                  minimal: true,
                  width: 68,
                  onMoreClick: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final utilityRect = tester.getRect(find.byType(MediaControlUtilityRows));
      final modeRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      );
      final moreRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.MoreButton')),
      );

      expect(modeRect.size, const Size(34, 34));
      expect(moreRect.size, const Size(34, 34));
      expect(moreRect.left - modeRect.right, 6);
      expect(modeRect.left, utilityRect.left - 3);
      expect(moreRect.right, utilityRect.right + 3);
    },
  );

  testWidgets('MediaControl keeps play button centered across player widths', (
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
            theme: _mediaControlTestTheme(),
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

    for (final width in [1200.0, 700.0, 500.0]) {
      await pumpAtWidth(width);
      await tester.pumpAndSettle();

      final playFinder = find.byKey(
        const ValueKey('MediaControl.PlayPauseButton'),
      );
      final playCenter = tester.getCenter(playFinder);
      final previousCenter = tester.getCenter(
        find.byKey(const ValueKey('MediaControl.PreviousButton')),
      );
      final nextCenter = tester.getCenter(
        find.byKey(const ValueKey('MediaControl.NextButton')),
      );
      final playContainer = tester.widget<AnimatedContainer>(
        find.descendant(
          of: playFinder,
          matching: find.byType(AnimatedContainer),
        ),
      );

      expect(
        playCenter.dx,
        closeTo((previousCenter.dx + nextCenter.dx) / 2, 0.01),
        reason: 'play button should be centered between skip buttons at $width',
      );
      expect(
        playContainer.alignment,
        Alignment.center,
        reason:
            'play icon should be centered by the button container at $width',
      );
    }
  });

  testWidgets('medium MediaControl exposes compact volume button', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 420);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _mediaControlTestTheme(),
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
    expect(find.byKey(const ValueKey('VolumeSlider.Tooltip')), findsOneWidget);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('MediaControl.CompactVolumePopover')),
      ),
      const Size(48, 116),
    );
    final compactVolumeButtonRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
    );
    final compactVolumePopoverRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.CompactVolumePopover')),
    );
    expect(compactVolumePopoverRect.right, compactVolumeButtonRect.right + 6);
    expect(compactVolumePopoverRect.bottom, compactVolumeButtonRect.top - 8);
    final compactVolumePopover = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('MediaControl.CompactVolumePopover')),
    );
    final compactVolumeDecoration =
        compactVolumePopover.decoration as BoxDecoration;
    expect(compactVolumeDecoration.color, const Color(0xf5222222));
    expect(
      compactVolumeDecoration.border,
      Border.all(color: const Color(0x2effffff)),
    );
    expect(compactVolumeDecoration.borderRadius, BorderRadius.circular(8));
    expect(compactVolumeDecoration.boxShadow, const [
      BoxShadow(
        color: Color(0x6b000000),
        offset: Offset(0, 16),
        blurRadius: 36,
      ),
    ]);
    expect(
      find.descendant(
        of: find.byType(MediaControlPlayerFrame),
        matching: find.byKey(
          const ValueKey('MediaControl.CompactVolumePopover'),
        ),
      ),
      findsNothing,
    );

    tester.widget<Slider>(find.byType(Slider).last).onChangeStart!(50);
    await tester.pump();
    expect(find.byKey(const ValueKey('VolumeSlider.Tooltip')), findsOneWidget);
    final compactVolumeTooltipArrow = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('VolumeSlider.TooltipArrow')),
    );
    final compactVolumeTooltipArrowBorder =
        (compactVolumeTooltipArrow.decoration as BoxDecoration).border!
            as Border;
    expect(compactVolumeTooltipArrowBorder.top.color, const Color(0x2effffff));
    expect(
      compactVolumeTooltipArrowBorder.right.color,
      const Color(0x2effffff),
    );
    expect(compactVolumeTooltipArrowBorder.bottom, BorderSide.none);
    expect(compactVolumeTooltipArrowBorder.left, BorderSide.none);
  });

  testWidgets('compact mode menu closes compact volume like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 420);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _mediaControlTestTheme(),
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

    await tester.tap(
      find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('MediaControl.CompactVolumePopover')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('MediaControl.CompactVolumePopover')),
      findsNothing,
    );
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Repeat'), findsOneWidget);
    expect(find.text('Repeat One'), findsOneWidget);
  });

  testWidgets('compact volume button is active only while popover is open', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _mediaControlTestTheme(),
          home: Scaffold(
            body: Center(
              child: MediaControlUtilityRows(
                trackId: 1,
                favorite: false,
                disabled: false,
                volumeValue: 0,
                isMuted: true,
                mode: PlaybackMode.once,
                onVolumeChange: (_) {},
                onToggleMute: () {},
                onToggleShuffle: () {},
                onToggleRepeat: () {},
                onToggleRepeatOne: () {},
                onToggleFavorite: () {},
                condensed: true,
                onMoreClick: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    BoxDecoration compactVolumeDecoration() {
      final buttonContainer = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byKey(
                const ValueKey('MediaControl.CompactVolumeButton'),
              ),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      return buttonContainer.decoration! as BoxDecoration;
    }

    expect(
      compactVolumeDecoration().color,
      MediaControlThemeColors.light.buttonActiveBackground.withValues(alpha: 0),
    );

    await tester.tap(
      find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
    );
    await tester.pump();

    expect(
      compactVolumeDecoration().color,
      MediaControlThemeColors.light.buttonActiveBackground,
    );
  });

  testWidgets('compact volume popover rebuilds after volume update', (
    tester,
  ) async {
    late StateSetter setHostState;
    var volume = 50;

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _mediaControlTestTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setHostState = setState;
                return Center(
                  child: MediaControlUtilityRows(
                    trackId: 1,
                    favorite: false,
                    disabled: false,
                    volumeValue: volume,
                    isMuted: false,
                    mode: PlaybackMode.once,
                    onVolumeChange: (value) {
                      setState(() {
                        volume = value;
                      });
                    },
                    onToggleMute: () {},
                    onToggleShuffle: () {},
                    onToggleRepeat: () {},
                    onToggleRepeatOne: () {},
                    onToggleFavorite: () {},
                    condensed: true,
                    onMoreClick: (_) {},
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('MediaControl.CompactVolumePopover')),
      findsOneWidget,
    );

    setHostState(() {
      volume = 68;
    });
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('MediaControl.CompactVolumePopover')),
      findsOneWidget,
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
      var favoriteToggled = false;
      var changedVolume = 0;

      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: _mediaControlTestTheme(),
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
                onToggleFavorite: () {
                  favoriteToggled = true;
                },
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
        MediaControlColors.disabledButtonSurface,
      );
      expect(disabledPlayButtonDecoration.boxShadow, const [
        BoxShadow(
          color: MediaControlColors.accentShadow,
          offset: Offset(0, 12),
          blurRadius: 24,
        ),
      ]);
      expect(
        disabledPlayButtonDecoration.border,
        Border.all(color: MediaControlColors.accentBorder),
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
        ),
        const Size(52, 52),
      );
      expect(
        tester
            .widgetList<Padding>(
              find.descendant(
                of: find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
                matching: find.byType(Padding),
              ),
            )
            .any((padding) => padding.padding == const EdgeInsets.all(13)),
        isTrue,
      );
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
        MediaControlColors.accent.withValues(
          alpha:
              mediaSliderDisabledInputOpacity * mediaSliderDisabledThumbOpacity,
        ),
      );
      expect(
        disabledProgressTheme.data.disabledActiveTrackColor,
        MediaControlColors.accent.withValues(
          alpha: mediaSliderDisabledInputOpacity,
        ),
      );
      expect(
        disabledProgressTheme.data.disabledInactiveTrackColor,
        MediaControlColors.sliderInactive.withValues(
          alpha:
              MediaControlColors.sliderInactive.a *
              mediaSliderDisabledInputOpacity,
        ),
      );
      expect(disabledProgressTheme.data.trackHeight, 2);
      final disabledProgressThumb =
          disabledProgressTheme.data.thumbShape! as RoundSliderThumbShape;
      expect(disabledProgressThumb.enabledThumbRadius, 9);
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
      expect(find.text('Add to My Favorites'), findsOneWidget);

      final volumeSlider = tester.widget<Slider>(find.byType(Slider).last);
      expect(volumeSlider.value, 73);
      expect(volumeSlider.onChanged, isNotNull);
      volumeSlider.onChanged!(64);
      await tester.pump();
      expect(changedVolume, 64);

      await tester.tap(find.text('Add to My Favorites'));
      await tester.pumpAndSettle();
      expect(favoriteToggled, isFalse);
    },
  );

  testWidgets('PlayerVolumeMenuItem suppresses Material hover overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _mediaControlTestTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: PlayerVolumeMenuItem(
              label: 'Volume',
              muted: false,
              volumeValue: 50,
              disabled: false,
              onToggleMute: () {},
              onVolumeChange: (_) {},
            ),
          ),
        ),
      ),
    );

    final volumeMenuIconButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('MediaControl.VolumeMenuItem')),
        matching: find.byType(IconButton),
      ),
    );
    expect(
      volumeMenuIconButton.style?.overlayColor?.resolve({WidgetState.hovered}),
      Colors.transparent,
    );
    expect(
      volumeMenuIconButton.style?.overlayColor?.resolve({WidgetState.pressed}),
      Colors.transparent,
    );
  });

  testWidgets(
    'MediaControl hover background animates from transparent target color',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: _mediaControlTestTheme(),
            home: Scaffold(
              body: Center(
                child: MediaControlUtilityRows(
                  trackId: 1,
                  favorite: false,
                  disabled: false,
                  volumeValue: 50,
                  isMuted: false,
                  mode: PlaybackMode.once,
                  onVolumeChange: (_) {},
                  onToggleMute: () {},
                  onToggleShuffle: () {},
                  onToggleRepeat: () {},
                  onToggleRepeatOne: () {},
                  onToggleFavorite: () {},
                  condensed: true,
                  onMoreClick: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      BoxDecoration moreDecoration() {
        return tester
                .widget<AnimatedContainer>(
                  find
                      .descendant(
                        of: find.byKey(
                          const ValueKey('MediaControl.MoreButton'),
                        ),
                        matching: find.byType(AnimatedContainer),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;
      }

      expect(
        moreDecoration().color,
        MediaControlThemeColors.light.buttonActiveBackground.withValues(
          alpha: 0,
        ),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('MediaControl.MoreButton'))),
      );
      await tester.pump(const Duration(milliseconds: 140));

      expect(
        moreDecoration().color,
        MediaControlThemeColors.light.buttonActiveBackground,
      );
      await mouse.removePointer();
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
          theme: _mediaControlTestTheme(),
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
          theme: _mediaControlTestTheme(),
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
            theme: _mediaControlTestTheme(),
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

const double _testVolumeSliderThumbRadius = 9;

ThemeData _mediaControlTestTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    brightness: brightness,
    extensions: [
      isDark
          ? DefaultAlbumArtworkThemeColors.dark
          : DefaultAlbumArtworkThemeColors.light,
      isDark ? MediaControlThemeColors.dark : MediaControlThemeColors.light,
    ],
  );
}
