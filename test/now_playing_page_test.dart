import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/exit_fullscreen_icon.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
import 'package:smplayer_flutter/src/app/shell_actions.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';
import 'package:smplayer_flutter/src/playback/hold_release_action.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_page.dart';
import 'package:smplayer_flutter/src/playback/now_playing_page.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LyricsRequestMode, NightMode, SettingsSnapshot;

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'albums.addSelectedTo': 'Add To',
      'albums.clearSelection': 'Clear Selection',
      'albums.playSelected': 'Play Selected',
      'albums.reverseSelection': 'Reverse Selection',
      'albums.selectAll': 'Select All',
      'albums.selectedCount': '{count} selected',
      'common.albumUnknown': 'Unknown Album',
      'common.artistUnknown': 'Unknown Artist',
      'common.album': 'Album',
      'common.artist': 'Artist',
      'common.cancel': 'Cancel',
      'common.multiSelect': 'Multi Select',
      'common.myFavorites': 'My Favorites',
      'common.nowPlaying': 'Now Playing',
      'common.playlist': 'Playlist',
      'common.undo': 'Undo',
      'common.close': 'Close',
      'context.addToPlaylist': 'Add To',
      'context.seeAlbum': 'See Album',
      'context.seeAlbumArt': 'See Album Art',
      'context.seeArtist': 'See Artist',
      'context.seeLyrics': 'See Lyrics',
      'context.seeLocalFile': 'See Local File',
      'context.seeMusicInfo': 'See Music Info',
      'context.view': 'View',
      'context.hideFile': 'Hide File',
      'context.moveToFolder': 'Move To Folder',
      'context.play': 'Play',
      'context.playNext': 'Play Next',
      'context.removeFromList': 'Remove',
      'context.select': 'Select',
      'detail.playAlbum': 'Play Album',
      'detail.playArtist': 'Play Artist',
      'notification.hiddenStorageItem': 'Hidden "{name}"',
      'notification.movedSong': 'Moved "{title}"',
      'notification.songAddedTo': 'Added {title} to {target}',
      'notification.songsAddedTo': 'Added {count} songs to {target}',
      'nowPlaying.clearNowPlaying': 'Clear Now Playing',
      'nowPlaying.clearQueue': 'Clear Queue',
      'nowPlaying.exitImmersiveMode': 'Exit immersive mode',
      'nowPlaying.exitFullScreenItem': 'Exit Full Screen',
      'nowPlaying.fullScreen': 'Full Screen',
      'nowPlaying.locateCurrent': 'Locate Current',
      'nowPlaying.loading': 'Loading',
      'nowPlaying.loadingLyrics': 'Loading Lyrics',
      'nowPlaying.lyricsCopy': 'Lyrics are unavailable.',
      'nowPlaying.noActiveTrack': 'No active track',
      'nowPlaying.noActiveTrackCopy': 'Choose music first.',
      'nowPlaying.noLyrics': 'No Lyrics',
      'nowPlaying.noQueueMatch': 'No match for {query}',
      'nowPlaying.playMode': 'Immersive mode',
      'nowPlaying.playlist': 'Playlist',
      'nowPlaying.quickPlay': 'Quick Play',
      'nowPlaying.queueEmpty': 'No songs',
      'nowPlaying.queueEmptyHelp': 'Queue songs first.',
      'nowPlaying.queueSearchHelp': 'Try another search.',
      'nowPlaying.randomPlay': 'Shuffle',
      'nowPlaying.remove': 'Remove',
      'nowPlaying.savePlaylist': 'Save Playlist',
      'playlists.newPlaylist': 'New Playlist',
      'playlists.create': 'Create',
      'playlists.createNew': 'Create New Playlist',
      'playlists.namePlaceholder': 'Playlist name',
      'playlists.nameDuplicate': 'Playlist already exists',
      'playlists.songCount': '{count} songs',
      'random.localFolder': 'Local Folder',
      'random.musicLibrary': 'Music Library',
      'preferences.level.dislike': 'Dislike',
      'preferences.level.do-not-appear': 'Do Not Appear',
      'preferences.level.high': 'High',
      'preferences.level.higher': 'Higher',
      'preferences.level.normal': 'Normal',
      'preferences.level.very-high': 'Very High',
      'preferences.undoPrefer': 'Undo Preference',
      'player.like': 'Like',
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
      'player.trackProgress': 'Track progress',
      'player.previous': 'Previous',
      'player.unlike': 'Unlike',
      'player.unmute': 'Unmute',
      'player.voiceAssistant': 'Voice Assistant',
      'player.volume': 'Volume',
      'settings.preferenceSettings': 'Preference Settings',
      'sidebar.back': 'Back',
    },
  );

  testWidgets('NowPlayingPage command bar uses Electron Add To submenu', (
    tester,
  ) async {
    await tester.pumpWidget(
      _NowPlayingTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeNowPlayingRepository(_snapshot),
      ),
    );
    await tester.pumpAndSettle();

    await _openAddToMenu(tester);

    expect(find.text('My Favorites'), findsOneWidget);
    expect(find.text('New Playlist'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);
    expect(find.text('Built in'), findsNothing);
  });

  testWidgets('NowPlayingPage hides queue commands when queue is empty', (
    tester,
  ) async {
    final snapshot = _snapshotWithSongs(
      _snapshot,
      _snapshot.songs,
      nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
    );

    await tester.pumpWidget(_NowPlayingTestApp(snapshot: snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(find.text('Quick Play'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Locate Current'), findsNothing);
    expect(find.text('Add To').hitTestable(), findsNothing);
    expect(find.text('Clear Queue'), findsNothing);
    expect(find.text('Immersive mode'), findsNothing);
    expect(find.text('Multi Select'), findsNothing);
  });

  testWidgets('NowPlayingPage aligns queue rows to the command bar edge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1012, 760);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _NowPlayingTestApp(snapshot: _snapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    final commandBarRight = tester.getRect(find.byType(CommandBar)).right;
    final rowRight =
        tester.getRect(find.byKey(const ValueKey('now-playing-1-0'))).right;

    expect(rowRight, commandBarRight);
  });

  testWidgets('NowPlayingPage keeps queue body empty when queue is empty', (
    tester,
  ) async {
    final snapshot = _snapshotWithSongs(
      _snapshot,
      _snapshot.songs,
      nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
    );

    await tester.pumpWidget(_NowPlayingTestApp(snapshot: snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(find.text('No active track'), findsNothing);
    expect(find.text('Choose music first.'), findsNothing);
    expect(find.byKey(const ValueKey('now-playing-1-0')), findsNothing);
  });

  testWidgets(
    'NowPlayingPage queue menu omits Add To in current compact menu',
    (tester) async {
      await tester.pumpWidget(
        _NowPlayingTestApp(snapshot: _snapshot, i18n: i18n),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Add To'), findsNothing);
      expect(find.text('Mix'), findsNothing);
      expect(find.text('Built in'), findsNothing);
    },
  );

  testWidgets('NowPlayingPage Add To favorites updates repository with undo', (
    tester,
  ) async {
    final repository = _FakeNowPlayingRepository(_snapshot);
    await tester.pumpWidget(
      _NowPlayingTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await _openAddToMenu(tester);
    await tester.tap(find.text('My Favorites'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.snapshot.songs.single.favorite, isTrue);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, isEmpty);
    expect(repository.snapshot.songs.single.favorite, isFalse);
  });

  testWidgets('NowPlayingPage Add To playlist writes selected target', (
    tester,
  ) async {
    final repository = _LongLyricsRepository(_snapshot);
    await tester.pumpWidget(
      _NowPlayingTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await _openAddToMenu(tester);
    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();

    expect(repository.playlistSongIds[10], [1]);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'NowPlayingPage queue menu hides file-management actions like Electron',
    (tester) async {
      final repository = _FakeNowPlayingRepository(_snapshot);
      await tester.pumpWidget(
        _NowPlayingTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Move To Folder'), findsNothing);
      expect(find.text('Hide File'), findsNothing);
    },
  );

  testWidgets('NowPlayingPage filters queue like Electron search', (
    tester,
  ) async {
    await tester.pumpWidget(
      _NowPlayingTestApp(
        snapshot: _searchSnapshot,
        i18n: i18n,
        searchQuery: 'red',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Red Song'), findsOneWidget);
    expect(find.text('Blue Song'), findsNothing);
  });

  testWidgets(
    'NowPlayingFullPage shows immersive lyrics and Electron fallback',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
      );
      mediaController.syncPlaybackProgress(12, durationSeconds: 120);

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DefaultAlbumArtwork), findsOneWidget);
      expect(find.text('Blue Song'), findsWidgets);
      expect(find.text('Artist A'), findsOneWidget);
      expect(find.text('Blue Hour'), findsOneWidget);
      expect(find.text('Current lyric', skipOffstage: false), findsOneWidget);

      await tester.tap(find.text('Now Playing').first);
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.getRect(
          find.byKey(const ValueKey('NowPlayingFull.QueuePopoverHost')),
        ),
        const Rect.fromLTWH(856, 56, 520, 712),
      );
      expect(find.text('Now Playing'), findsWidgets);
      expect(find.text('1 songs'), findsOneWidget);
      expect(tester.getSize(find.byTooltip('Close')), const Size(42, 42));
      final closeHover = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await closeHover.addPointer();
      await closeHover.moveTo(tester.getCenter(find.byTooltip('Close')));
      await tester.pump();
      final queueCloseGlass = tester.widget<GlassContainer>(
        find.byKey(const ValueKey('NowPlayingFull.QueueCloseButton')),
      );
      expect(queueCloseGlass.width, 42);
      expect(queueCloseGlass.height, 42);
      expect(queueCloseGlass.useOwnLayer, isTrue);
      expect(queueCloseGlass.shape, isA<LiquidRoundedRectangle>());
      final queueCloseButton = tester.widget<TextButton>(
        find.descendant(
          of: find.byKey(const ValueKey('NowPlayingFull.QueueCloseButton')),
          matching: find.byType(TextButton),
        ),
      );
      expect(
        queueCloseButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        Colors.transparent,
      );
      expect(
        queueCloseButton.style?.foregroundColor?.resolve(<WidgetState>{}),
        const Color(0xff101828),
      );
      final queueTitle = tester
          .widgetList<Text>(find.text('Now Playing'))
          .singleWhere((widget) => widget.style?.fontSize == 26);
      expect(queueTitle.style?.fontWeight, FontWeight.w800);
      final queueCount = tester.widget<Text>(find.text('1 songs'));
      expect(queueCount.style?.fontSize, 13);
      expect(queueCount.style?.fontWeight, FontWeight.w700);
      final queueButton = tester.widget<TextButton>(
        find.ancestor(
          of: find.byKey(const ValueKey('NowPlayingFull.QueueLabel')),
          matching: find.byType(TextButton),
        ),
      );
      expect(
        queueButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        const Color(0xdbffffff),
      );
    },
  );

  testWidgets('NowPlayingFullPage no active track labels match Electron', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeNowPlayingRepository(_snapshot),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pump();

    expect(find.text('No active track'), findsOneWidget);
    expect(find.text('No Lyrics'), findsOneWidget);
    expect(find.text('Unknown Artist'), findsOneWidget);
    expect(find.text('Unknown Album'), findsOneWidget);
  });

  testWidgets(
    'NowPlayingFullPage no active track disables full footer volume like Electron',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });

      final settings = const SettingsSnapshot.defaults().copyWith(
        nightMode: NightMode.never,
      );
      final wideController = MediaControlController();
      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: _FakeNowPlayingRepository(_snapshot),
          mediaController: wideController,
          themeSettings: settings,
        ),
      );
      await tester.pump();

      BoxDecoration buttonDecoration(ValueKey<String> key) {
        return tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byKey(key),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;
      }

      AnimatedSlide buttonSlide(ValueKey<String> key) {
        return tester.widget<AnimatedSlide>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(AnimatedSlide),
          ),
        );
      }

      expect(
        buttonDecoration(const ValueKey('MediaControl.PlayPauseButton')).color,
        MediaControlColors.accent,
      );
      expect(
        buttonDecoration(const ValueKey('MediaControl.PlayPauseButton')).border,
        Border.all(color: Colors.transparent),
      );
      expect(
        buttonDecoration(
          const ValueKey('MediaControl.PlayPauseButton'),
        ).boxShadow,
        const [
          BoxShadow(
            color: MediaControlColors.accentShadow,
            offset: Offset(0, 12),
            blurRadius: 26,
          ),
        ],
      );
      expect(
        tester
            .widgetList<Opacity>(
              find.descendant(
                of: find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
                matching: find.byType(Opacity),
              ),
            )
            .any((opacity) => opacity.opacity == 0.65),
        isTrue,
      );
      expect(
        buttonDecoration(const ValueKey('MediaControl.PreviousButton')).color,
        MediaControlColors.disabledButtonSurface,
      );
      expect(
        tester
            .widgetList<Opacity>(
              find.descendant(
                of: find.byKey(const ValueKey('MediaControl.PreviousButton')),
                matching: find.byType(Opacity),
              ),
            )
            .any((opacity) => opacity.opacity == 0.65),
        isTrue,
      );
      final previousHover = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await previousHover.addPointer();
      await tester.pump();
      await previousHover.moveTo(
        tester.getCenter(
          find.byKey(const ValueKey('MediaControl.PreviousButton')),
        ),
      );
      await tester.pump();
      expect(
        buttonSlide(const ValueKey('MediaControl.PreviousButton')).offset,
        Offset.zero,
      );
      await previousHover.removePointer();
      expect(
        buttonDecoration(const ValueKey('MediaControl.NextButton')).color,
        MediaControlColors.disabledButtonSurface,
      );
      expect(
        tester
            .widgetList<Opacity>(
              find.descendant(
                of: find.byKey(const ValueKey('MediaControl.NextButton')),
                matching: find.byType(Opacity),
              ),
            )
            .any((opacity) => opacity.opacity == 0.65),
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.FavoriteButton')),
        findsNothing,
      );
      for (final key in [
        const ValueKey('MediaControl.ShuffleButton'),
        const ValueKey('MediaControl.RepeatButton'),
        const ValueKey('MediaControl.RepeatOneButton'),
      ]) {
        expect(
          buttonDecoration(key).color,
          MediaControlColors.disabledButtonSurface,
        );
        expect(
          tester
              .widgetList<Opacity>(
                find.descendant(
                  of: find.byKey(key),
                  matching: find.byType(Opacity),
                ),
              )
              .any((opacity) => opacity.opacity == 0.65),
          isTrue,
        );
      }
      await tester.tap(find.byKey(const ValueKey('MediaControl.RepeatButton')));
      await tester.pumpAndSettle();
      expect(wideController.state.mode, PlaybackMode.once);
      await tester.tap(find.byKey(const ValueKey('MediaControl.MoreButton')));
      await tester.pumpAndSettle();
      expect(find.text('Quick Play'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.text('Save Playlist'), findsOneWidget);
      expect(find.text('Clear Now Playing'), findsOneWidget);
      expect(find.text('Add To'), findsNothing);
      expect(find.text('Play Artist'), findsNothing);
      expect(find.text('Play Album'), findsNothing);
      expect(find.text('View'), findsNothing);
      await tester.tapAt(const Offset(40, 40));
      await tester.pumpAndSettle();

      final progressSlider = tester.widget<Slider>(
        find.byKey(const ValueKey('MediaControl.ProgressSlider')),
      );
      expect(progressSlider.value, 0);
      expect(progressSlider.onChanged, isNull);
      final progressTheme = tester.widget<SliderTheme>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('MediaControl.ProgressSlider')),
              matching: find.byType(SliderTheme),
            )
            .first,
      );
      expect(
        progressTheme.data.disabledThumbColor,
        Colors.white.withValues(
          alpha:
              mediaSliderDisabledInputOpacity * mediaSliderDisabledThumbOpacity,
        ),
      );
      expect(
        progressTheme.data.disabledActiveTrackColor,
        const Color(
          0xc25b697a,
        ).withValues(alpha: 0xc2 / 0xff * mediaSliderDisabledInputOpacity),
      );
      expect(
        progressTheme.data.disabledInactiveTrackColor,
        const Color(
          0x2e5b697a,
        ).withValues(alpha: 0x2e / 0xff * mediaSliderDisabledInputOpacity),
      );

      final volumeSlider = tester.widget<Slider>(
        find.descendant(
          of: find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
          matching: find.byType(Slider),
        ),
      );
      expect(volumeSlider.value, 0);
      expect(volumeSlider.onChanged, isNull);

      tester.view.physicalSize = const Size(1000, 760);
      final compactController = MediaControlController();
      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: _FakeNowPlayingRepository(_snapshot),
          mediaController: compactController,
          themeSettings: settings,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.FavoriteButton')),
        findsNothing,
      );
      expect(
        tester
            .widgetList<Opacity>(
              find.descendant(
                of: find.byKey(
                  const ValueKey('MediaControl.CompactVolumeButton'),
                ),
                matching: find.byType(Opacity),
              ),
            )
            .any((opacity) => opacity.opacity == 0.65),
        isTrue,
      );
      final compactVolumeHover = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await compactVolumeHover.addPointer();
      await tester.pump();
      await compactVolumeHover.moveTo(
        tester.getCenter(
          find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
        ),
      );
      await tester.pump();
      expect(
        buttonSlide(const ValueKey('MediaControl.CompactVolumeButton')).offset,
        Offset.zero,
      );
      await compactVolumeHover.removePointer();
      expect(
        tester
            .widgetList<Opacity>(
              find.descendant(
                of: find.byKey(
                  const ValueKey('MediaControl.CompactModeButton'),
                ),
                matching: find.byType(Opacity),
              ),
            )
            .any((opacity) => opacity.opacity == 0.65),
        isTrue,
      );
      await tester.tap(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      );
      await tester.pumpAndSettle();
      expect(compactController.state.mode, PlaybackMode.once);
      expect(find.text('Shuffle'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('MediaControl.CompactVolumePopover')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('MediaControl.MoreButton')));
      await tester.pumpAndSettle();
      expect(find.text('Quick Play'), findsOneWidget);
      expect(find.text('Playback Mode: List'), findsNothing);
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeMenuItem')),
        findsNothing,
      );
      expect(find.text('Like'), findsNothing);
      expect(find.text('Save Playlist'), findsOneWidget);
      expect(find.text('Clear Now Playing'), findsOneWidget);
      expect(find.text('Add To'), findsNothing);
      expect(find.text('Play Artist'), findsNothing);
      expect(find.text('Play Album'), findsNothing);
      expect(find.text('View'), findsNothing);
      await tester.tapAt(const Offset(40, 40));
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(760, 760);
      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: _FakeNowPlayingRepository(_snapshot),
          mediaController: compactController,
          themeSettings: settings,
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('MediaControl.MoreButton')));
      await tester.pumpAndSettle();
      expect(find.text('Quick Play'), findsOneWidget);
      expect(find.text('Playback Mode: List'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeMenuItem')),
        findsOneWidget,
      );
      final moreVolumeSlider = tester.widget<Slider>(
        find.descendant(
          of: find.byKey(const ValueKey('MediaControl.VolumeMenuItem')),
          matching: find.byType(Slider),
        ),
      );
      expect(moreVolumeSlider.value, compactController.state.volume);
      expect(moreVolumeSlider.onChanged, isNotNull);
      expect(find.text('Like'), findsOneWidget);
      expect(find.text('Save Playlist'), findsOneWidget);
      expect(find.text('Clear Now Playing'), findsOneWidget);
      expect(find.text('Add To'), findsNothing);
      expect(find.text('Play Artist'), findsNothing);
      expect(find.text('Play Album'), findsNothing);
      expect(find.text('View'), findsNothing);
    },
  );

  testWidgets(
    'NowPlayingFullPage disabled night buttons keep Electron full-page foreground',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      final settings = const SettingsSnapshot.defaults().copyWith(
        nightMode: NightMode.onMode,
      );
      setSmPlayerGlobalSettingsSnapshot(settings);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: _FakeNowPlayingRepository(_snapshot),
          mediaController: MediaControlController(),
          themeSettings: settings,
        ),
      );
      await tester.pump();

      final disabledVolumeIcon = tester.widget<SmPlayerVolumeIcon>(
        find
            .descendant(
              of: find.byKey(const ValueKey('MediaControl.VolumeButton')),
              matching: find.byType(SmPlayerVolumeIcon),
            )
            .first,
      );
      expect(disabledVolumeIcon.color, const Color(0xf0f6f9fc));
      expect(
        tester
            .widgetList<Opacity>(
              find.descendant(
                of: find.byKey(const ValueKey('MediaControl.VolumeButton')),
                matching: find.byType(Opacity),
              ),
            )
            .any((opacity) => opacity.opacity == 0.65),
        isTrue,
      );
    },
  );

  testWidgets(
    'NowPlayingFullPage previous button has no Electron extra hold UI',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(
          nightMode: NightMode.never,
          previousButtonRestartsTrack: true,
        ),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        progressSeconds: 12,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _searchSnapshot,
          i18n: i18n,
          repository: _FakeNowPlayingRepository(_searchSnapshot),
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      expect(find.byTooltip('Previous'), findsOneWidget);
      final previousHoldAction = tester.widget<HoldReleaseAction>(
        find.descendant(
          of: find.byKey(const ValueKey('MediaControl.PreviousButton')),
          matching: find.byType(HoldReleaseAction),
        ),
      );
      expect(previousHoldAction.onHoldRelease, isNull);
      expect(previousHoldAction.holdTooltip, isNull);
    },
  );

  testWidgets('NowPlayingFullPage scopes controls to immersive night mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.onMode),
    );
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      resetSmPlayerGlobalSettingsSnapshot();
    });

    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
      progressSeconds: 72,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeNowPlayingRepository(_snapshot),
        mediaController: mediaController,
        themeSettings: const SettingsSnapshot.defaults(),
      ),
    );
    await tester.pump();

    final queueButton = tester.widget<TextButton>(
      find.ancestor(
        of: find.byKey(const ValueKey('NowPlayingFull.QueueLabel')),
        matching: find.byType(TextButton),
      ),
    );

    expect(
      queueButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      NowPlayingFullThemeColors.dark.topButtonBackground,
    );
    final nightPlayButton = tester.widget<AnimatedContainer>(
      find
          .descendant(
            of: find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final nightPlayDecoration = nightPlayButton.decoration! as BoxDecoration;
    expect(
      nightPlayDecoration.border,
      Border.all(color: const Color(0x6b0078d7)),
    );
    expect(nightPlayDecoration.boxShadow, const [
      BoxShadow(
        color: Color(0x52000000),
        offset: Offset(0, 12),
        blurRadius: 26,
      ),
    ]);
    final playMouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await playMouse.addPointer(
      location: tester.getCenter(
        find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final hoveredNightPlayButton = tester.widget<AnimatedContainer>(
      find
          .descendant(
            of: find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(
      (hoveredNightPlayButton.decoration! as BoxDecoration).color,
      MediaControlColors.accentStrong,
    );
    await playMouse.removePointer();
    expect(
      tester
          .widget<SmPlayerMoreHorizontalIcon>(
            find.descendant(
              of: find.byKey(const ValueKey('MediaControl.MoreButton')),
              matching: find.byType(SmPlayerMoreHorizontalIcon),
            ),
          )
          .color,
      const Color(0xdbffffff),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(
        find.byKey(const ValueKey('MediaControl.MoreButton')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final hoveredMoreButton = tester.widget<AnimatedContainer>(
      find
          .descendant(
            of: find.byKey(const ValueKey('MediaControl.MoreButton')),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(
      (hoveredMoreButton.decoration! as BoxDecoration).color,
      const Color(0x2e0078d7),
    );
    expect(
      tester
          .widget<SmPlayerMoreHorizontalIcon>(
            find.descendant(
              of: find.byKey(const ValueKey('MediaControl.MoreButton')),
              matching: find.byType(SmPlayerMoreHorizontalIcon),
            ),
          )
          .color,
      Colors.white,
    );
    await mouse.removePointer();
    final nightProgressElapsed = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('MediaControl.ProgressElapsedColumn')),
        matching: find.byType(Text),
      ),
    );
    expect(nightProgressElapsed.style?.color, const Color(0xa8ffffff));
    final nightProgressDuration = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('MediaControl.ProgressDurationColumn')),
        matching: find.byType(Text),
      ),
    );
    expect(nightProgressDuration.style?.color, const Color(0xa8ffffff));
    final nightProgressTheme = tester.widget<SliderTheme>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('MediaControl.ProgressSlider')),
            matching: find.byType(SliderTheme),
          )
          .first,
    );
    expect(nightProgressTheme.data.activeTrackColor, const Color(0xdbffffff));
    expect(nightProgressTheme.data.inactiveTrackColor, const Color(0x33ffffff));
    expect(nightProgressTheme.data.thumbColor, Colors.white);
    final nightProgressThumb =
        nightProgressTheme.data.thumbShape! as MediaSliderThumbShape;
    expect(
      nightProgressThumb.shadow,
      const BoxShadow(
        color: Color(0x61000000),
        offset: Offset(0, 1),
        blurRadius: 8,
      ),
    );
    final nightVolumeTheme = tester.widget<SliderTheme>(
      find
          .descendant(
            of: find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
            matching: find.byType(SliderTheme),
          )
          .first,
    );
    final nightVolumeThumb =
        nightVolumeTheme.data.thumbShape! as MediaSliderThumbShape;
    expect(nightVolumeTheme.data.activeTrackColor, const Color(0xf20078d7));
    expect(nightVolumeTheme.data.inactiveTrackColor, const Color(0x2ecbd5e1));
    expect(nightVolumeTheme.data.thumbColor, MediaControlColors.accent);
    expect(
      nightVolumeThumb.shadow,
      const BoxShadow(
        color: Color(0x47000000),
        offset: Offset(0, 1),
        blurRadius: 4,
      ),
    );
    final nightVolumeSemantics = tester
        .widgetList<Semantics>(
          find.descendant(
            of: find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
            matching: find.byType(Semantics),
          ),
        )
        .singleWhere((semantics) => semantics.properties.label == 'Volume');
    expect(nightVolumeSemantics.properties.value, '50');
    final volumeMouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await volumeMouse.addPointer(
      location: tester.getCenter(
        find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
      ),
    );
    await tester.pump();
    final nightVolumeSliderRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
    );
    final nightVolumeTooltipRect = tester.getRect(
      find.byKey(const ValueKey('VolumeSlider.Tooltip')),
    );
    expect(nightVolumeSliderRect.top - nightVolumeTooltipRect.bottom, 8);
    final nightVolumeTooltip = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('VolumeSlider.Tooltip')),
    );
    final nightVolumeTooltipDecoration =
        nightVolumeTooltip.decoration as BoxDecoration;
    expect(nightVolumeTooltipDecoration.color, const Color(0xe014181e));
    expect(
      nightVolumeTooltipDecoration.border,
      Border.all(color: const Color(0x2effffff)),
    );
    expect(nightVolumeTooltipDecoration.boxShadow, const [
      BoxShadow(
        color: Color(0x57000000),
        offset: Offset(0, 10),
        blurRadius: 24,
      ),
    ]);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('VolumeSlider.Tooltip')),
              matching: find.byType(Text),
            ),
          )
          .style
          ?.color,
      Colors.white,
    );
    final nightVolumeTooltipArrow = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('VolumeSlider.TooltipArrow')),
    );
    final nightVolumeTooltipArrowBorder =
        (nightVolumeTooltipArrow.decoration as BoxDecoration).border! as Border;
    expect(nightVolumeTooltipArrowBorder.right.color, const Color(0x2effffff));
    expect(nightVolumeTooltipArrowBorder.bottom.color, const Color(0x2effffff));
    expect(nightVolumeTooltipArrowBorder.top, BorderSide.none);
    expect(nightVolumeTooltipArrowBorder.left, BorderSide.none);
    await volumeMouse.removePointer();

    await tester.tap(find.text('Now Playing').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byType(PlaylistControlItem), findsWidgets);

    final queuePanelBackground = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('NowPlayingFull.QueuePanelBackground')),
    );
    final queuePanelDecoration =
        queuePanelBackground.decoration as BoxDecoration;
    expect(queuePanelDecoration.color, const Color(0xdb12100e));
    expect(queuePanelDecoration.gradient, isA<LinearGradient>());
    expect(
      find.byKey(const ValueKey('NowPlayingFull.QueuePanelGlass')),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.text('1 songs')).style?.color,
      const Color(0xb8ffffff),
    );
  });

  testWidgets('NowPlayingFullPage queue rows use Electron compact layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeNowPlayingRepository(_searchSnapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _searchSnapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Now Playing').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final firstRow = find.byType(PlaylistControlItem).first;
    final firstRowPlayNextAction = find.descendant(
      of: firstRow,
      matching: find.byKey(
        const ValueKey('PlaylistControlItem.PlayNextAction'),
      ),
    );
    final firstRowMoreAction = find.descendant(
      of: firstRow,
      matching: find.byKey(const ValueKey('PlaylistControlItem.MoreAction')),
    );
    final firstRowActions = find.descendant(
      of: firstRow,
      matching: find.byKey(const ValueKey('PlaylistControlItem.Actions')),
    );
    final firstRowDuration = find.descendant(
      of: firstRow,
      matching: find.byKey(const ValueKey('PlaylistControlItem.Duration')),
    );
    expect(tester.getSize(firstRow).height, 78);
    expect(
      tester.widget<PlaylistControlItem>(firstRow).variant,
      PlaylistControlItemVariant.compact,
    );
    expect(
      tester
              .getTopLeft(
                find.byKey(const ValueKey('PlaylistControlItem.Title')).first,
              )
              .dx -
          tester.getTopLeft(firstRow).dx,
      78,
    );
    expect(firstRowPlayNextAction, findsNothing);
    expect(tester.getSize(firstRowActions).width, 34);
    expect(tester.getSize(firstRowDuration).width, 20);
    expect(
      tester.getRect(firstRow).right - tester.getRect(firstRowDuration).right,
      12,
    );
    expect(
      tester
          .getSize(
            find.descendant(of: firstRowDuration, matching: find.text('2:00')),
          )
          .height,
      lessThan(24),
    );
    AnimatedOpacity hoverOpacityFor(Finder action) {
      return tester.widget<AnimatedOpacity>(
        find
            .ancestor(of: action.first, matching: find.byType(AnimatedOpacity))
            .first,
      );
    }

    expect(hoverOpacityFor(firstRowMoreAction).opacity, 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(firstRow));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(firstRowPlayNextAction, findsNothing);
    expect(tester.getSize(firstRowActions).width, 34);
    expect(hoverOpacityFor(firstRowMoreAction).opacity, 1);
    expect(tester.getSize(firstRowMoreAction), const Size.square(34));
    expect(
      find.byKey(const ValueKey('PlaylistControlItem.AddToAction')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('PlaylistControlItem.RemoveAction')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('PlaylistControlItem.FavoriteAction')),
      findsNothing,
    );
  });

  testWidgets(
    'NowPlayingFullPage omits playback load failure banner like Electron',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        autoplay: false,
      );
      mediaController.setPlaybackLoadFailed();

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      expect(find.text('Playback failed'), findsNothing);
    },
  );

  testWidgets('NowPlayingFullPage keeps full player surface out of loading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 0,
      queueIndex: 0,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    final baselineTransportRowRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.TransportRow')),
    );
    final baselineProgressRowRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.ProgressRow')),
    );
    final baselineProgressSliderRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.ProgressSlider')),
    );

    mediaController.setTrackLoading(true);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('MediaControl.ProgressLoading')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('MediaControl.ProgressSlider')),
      findsOneWidget,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
      ),
      const Size(56, 56),
    );
    final transportRowRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.TransportRow')),
    );
    final progressRowRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.ProgressRow')),
    );
    final progressSliderRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.ProgressSlider')),
    );
    expect(transportRowRect, baselineTransportRowRect);
    expect(progressRowRect, baselineProgressRowRect);
    expect(progressSliderRect, baselineProgressSliderRect);
    expect(transportRowRect.left, closeTo(420.71, 0.1));
    expect(transportRowRect.width, closeTo(558.57, 0.1));
    expect(transportRowRect.height, 52);
    expect(progressRowRect.left, closeTo(420.71, 0.1));
    expect(progressRowRect.width, closeTo(558.57, 0.1));
    expect(progressRowRect.height, 36);
    expect(progressSliderRect.left, closeTo(476.71, 0.1));
    expect(progressSliderRect.right, closeTo(923.29, 0.1));
    final progressSlider = tester.widget<Slider>(
      find.byKey(const ValueKey('MediaControl.ProgressSlider')),
    );
    expect(progressSlider.max, 120);
    expect(find.text('2:00'), findsOneWidget);

    tester.view.physicalSize = const Size(500, 760);
    final compactController = MediaControlController();
    compactController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 0,
      queueIndex: 0,
    );
    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeNowPlayingRepository(_snapshot),
        mediaController: compactController,
      ),
    );
    await tester.pump();

    final compactBaselineTransportRowRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.TransportRow')),
    );
    final compactBaselineProgressRowRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.ProgressRow')),
    );
    final compactBaselineProgressSliderRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.ProgressSlider')),
    );

    compactController.setTrackLoading(true);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('MediaControl.ProgressLoading')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('MediaControl.ProgressSlider')),
      findsOneWidget,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
      ),
      const Size(48, 48),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('MediaControl.TransportRow'))),
      compactBaselineTransportRowRect,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('MediaControl.ProgressRow'))),
      compactBaselineProgressRowRect,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('MediaControl.ProgressSlider'))),
      compactBaselineProgressSliderRect,
    );
    expect(
      compactBaselineTransportRowRect,
      const Rect.fromLTWH(88, 657, 324, 56),
    );
    expect(
      compactBaselineProgressRowRect,
      const Rect.fromLTWH(88, 721, 324, 28),
    );
    final compactProgressSlider = tester.widget<Slider>(
      find.byKey(const ValueKey('MediaControl.ProgressSlider')),
    );
    expect(compactProgressSlider.max, 120);
    expect(find.text('2:00'), findsOneWidget);
  });

  testWidgets(
    'NowPlayingFullPage progress seek commits on release like Electron',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        progressSeconds: 12,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: _FakeNowPlayingRepository(_snapshot),
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      var progressSlider = tester.widget<Slider>(
        find.byKey(const ValueKey('MediaControl.ProgressSlider')),
      );
      progressSlider.onChangeEnd!(84);
      await tester.pump();
      expect(mediaController.state.isProgressSeeking, isFalse);
      expect(mediaController.state.progressSeconds, 12);

      progressSlider = tester.widget<Slider>(
        find.byKey(const ValueKey('MediaControl.ProgressSlider')),
      );
      progressSlider.onChangeStart!(12);
      await tester.pump();
      expect(mediaController.state.isProgressSeeking, isTrue);

      progressSlider = tester.widget<Slider>(
        find.byKey(const ValueKey('MediaControl.ProgressSlider')),
      );
      progressSlider.onChanged!(42);
      await tester.pump();

      expect(mediaController.state.progressSeconds, 12);
      expect(find.text('0:42'), findsOneWidget);

      progressSlider = tester.widget<Slider>(
        find.byKey(const ValueKey('MediaControl.ProgressSlider')),
      );
      progressSlider.onChangeEnd!(42);
      await tester.pump();

      expect(mediaController.state.isProgressSeeking, isFalse);
      expect(mediaController.state.progressSeconds, 42);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.physicalSize = const Size(500, 760);
      final compactController = MediaControlController();
      compactController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        progressSeconds: 12,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: _FakeNowPlayingRepository(_snapshot),
          mediaController: compactController,
        ),
      );
      await tester.pump();

      final compactProgressRowRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.ProgressRow')),
      );
      expect(compactProgressRowRect, const Rect.fromLTWH(88, 721, 324, 28));

      progressSlider = tester.widget<Slider>(
        find.byKey(const ValueKey('MediaControl.ProgressSlider')),
      );
      progressSlider.onChangeStart!(12);
      await tester.pump();
      expect(compactController.state.isProgressSeeking, isTrue);

      progressSlider = tester.widget<Slider>(
        find.byKey(const ValueKey('MediaControl.ProgressSlider')),
      );
      progressSlider.onChanged!(54);
      await tester.pump();

      expect(compactController.state.progressSeconds, 12);
      expect(find.text('0:54'), findsOneWidget);

      progressSlider = tester.widget<Slider>(
        find.byKey(const ValueKey('MediaControl.ProgressSlider')),
      );
      progressSlider.onChangeEnd!(54);
      await tester.pump();

      expect(compactController.state.isProgressSeeking, isFalse);
      expect(compactController.state.progressSeconds, 54);
    },
  );

  testWidgets('NowPlayingFullPage compact footer reuses nav-minimal surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 760);
    tester.view.devicePixelRatio = 1;
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
    );
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      resetSmPlayerGlobalSettingsSnapshot();
    });
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
      progressSeconds: 72,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(MediaControlPlayerFrame), findsOneWidget);
    expect(find.byType(MediaControlSurface), findsOneWidget);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
      ),
      const Size(48, 48),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('MediaControl.PreviousButton'))),
      const Size(36, 36),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('MediaControl.NextButton'))),
      const Size(36, 36),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      ),
      const Size(34, 34),
    );
    expect(find.byTooltip('Voice Assistant'), findsNothing);
    final compactModeRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.CompactModeButton')),
    );
    final moreRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.MoreButton')),
    );
    expect(compactModeRect.size, const Size(34, 34));
    expect(moreRect.size, const Size(34, 34));
    expect(moreRect.left - compactModeRect.right, 6);
    expect(
      tester
          .getCenter(find.byKey(const ValueKey('MediaControl.PlayPauseButton')))
          .dx,
      250,
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey('MediaControl.MoreButton')))
          .right,
      491,
    );
    expect(
      tester
          .widget<Icon>(find.byKey(const ValueKey('NowPlayingFull.BackIcon')))
          .size,
      16,
    );
    expect(
      tester
          .widget<Icon>(find.byKey(const ValueKey('NowPlayingFull.QueueIcon')))
          .size,
      16,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('NowPlayingFull.QueueLabel')))
          .style
          ?.fontSize,
      13,
    );
    BoxDecoration exitDecoration() =>
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
                )
                .decoration!
            as BoxDecoration;

    expect(
      tester.getSize(
        find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
      ),
      const Size(68, 68),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
        matching: find.byKey(const ValueKey('NowPlayingFull.ExitAlbumSwatch')),
      ),
      findsNothing,
    );
    expect(exitDecoration().color, Colors.transparent);
    expect(exitDecoration().border?.top.color, Colors.transparent);
    expect(exitDecoration().gradient, isNull);
    expect(exitDecoration().boxShadow, isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
        matching: find.byKey(
          const ValueKey('NowPlayingFull.ExitArtworkBackdrop'),
        ),
      ),
      findsNothing,
    );
    expect(
      tester.widget<ExitFullscreenIcon>(
        find.byKey(const ValueKey('NowPlayingFull.ExitIcon')),
      ),
      isA<ExitFullscreenIcon>()
          .having((icon) => icon.size, 'size', 36)
          .having((icon) => icon.strokeWidth, 'strokeWidth', 2)
          .having((icon) => icon.color, 'color', const Color(0xe6080c12))
          .having((icon) => icon.shadows, 'shadows', isEmpty),
    );

    final exitHover = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await exitHover.addPointer();
    await tester.pump();
    await exitHover.moveTo(
      tester.getCenter(
        find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
      ),
    );
    await tester.pumpAndSettle();

    expect(exitDecoration().color, const Color(0x1f212b3a));
    expect(exitDecoration().border?.top.color, const Color(0x14212b3a));
    expect(exitDecoration().gradient, isNull);
    expect(exitDecoration().boxShadow, isNull);
    await exitHover.removePointer();

    final compactTitle = tester
        .widgetList<Text>(find.text('Blue Song'))
        .singleWhere((widget) => widget.style?.fontSize == 28.48);
    expect(compactTitle.style?.fontWeight, const FontWeight(760));
    expect(compactTitle.style?.height, 1.14);

    await tester.pump();

    final activeLyricStyle =
        tester
            .widget<AnimatedDefaultTextStyle>(
              find
                  .ancestor(
                    of: find.text('Current lyric'),
                    matching: find.byType(AnimatedDefaultTextStyle),
                  )
                  .first,
            )
            .style;
    expect(activeLyricStyle.fontSize, 22);
    expect(activeLyricStyle.color, const Color(0xff101828));
    expect(activeLyricStyle.fontWeight, const FontWeight(760));
    expect(activeLyricStyle.height, 1.34);

    final inactiveLyricStyle =
        tester
            .widget<AnimatedDefaultTextStyle>(
              find
                  .ancestor(
                    of: find.text('Opening lyric'),
                    matching: find.byType(AnimatedDefaultTextStyle),
                  )
                  .first,
            )
            .style;
    expect(inactiveLyricStyle.fontSize, 18);
    expect(inactiveLyricStyle.color, const Color(0x425b697a));
    expect(inactiveLyricStyle.fontWeight, const FontWeight(620));
    expect(inactiveLyricStyle.height, 1.44);

    final queueButtonFinder = find.ancestor(
      of: find.byKey(const ValueKey('NowPlayingFull.QueueLabel')),
      matching: find.byType(TextButton),
    );
    await tester.tap(queueButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final compactQueueList = tester.widget<ListView>(
      find.byKey(const ValueKey('NowPlayingFull.QueueList')),
    );
    expect(compactQueueList.padding, const EdgeInsets.fromLTRB(10, 0, 0, 2));
    expect(
      tester
              .getRect(find.byKey(const ValueKey('NowPlayingFull.QueueList')))
              .right -
          tester.getRect(find.byType(PlaylistControlItem).first).right,
      10,
    );
  });

  testWidgets('writes NowPlayingFullPage top liquid glass buttons screenshot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(956, 1520);
    tester.view.devicePixelRatio = 2;
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.onMode),
    );
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      resetSmPlayerGlobalSettingsSnapshot();
    });

    final repaintKey = GlobalKey();
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );

    await tester.pumpWidget(
      RepaintBoundary(
        key: repaintKey,
        child: _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
          themeSettings: const SettingsSnapshot.defaults(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('NowPlayingFull.BackIcon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('NowPlayingFull.QueueLabel')),
      findsOneWidget,
    );
    await _writeNowPlayingBoundaryPng(
      tester,
      repaintKey,
      'build/now_playing_full_top_glass_buttons_verify.png',
      pixelRatio: 2,
    );
  });

  testWidgets('writes NowPlayingFullPage MediaControl footer screenshot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 760);
    tester.view.devicePixelRatio = 1;
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
    );
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      resetSmPlayerGlobalSettingsSnapshot();
    });

    final repaintKey = GlobalKey();
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
      progressSeconds: 72,
    );

    await tester.pumpWidget(
      RepaintBoundary(
        key: repaintKey,
        child: _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
          themeSettings: const SettingsSnapshot.defaults(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MediaControlSurface), findsOneWidget);
    expect(
      find.byKey(const ValueKey('MediaControl.ProgressSlider')),
      findsOneWidget,
    );
    await _writeNowPlayingBoundaryPng(
      tester,
      repaintKey,
      'build/now_playing_full_media_control_footer_verify.png',
      pixelRatio: 2,
    );
  });

  testWidgets(
    'NowPlayingFullPage compact footer matches Electron column geometry',
    (tester) async {
      tester.view.physicalSize = const Size(500, 760);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        progressSeconds: 72,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      final exitRect = tester.getRect(
        find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
      );
      final playRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
      );
      final previousRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.PreviousButton')),
      );
      final nextRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.NextButton')),
      );
      final moreRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.MoreButton')),
      );
      final elapsedRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.ProgressElapsedColumn')),
      );
      final progressSliderRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.ProgressSlider')),
      );
      final durationRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.ProgressDurationColumn')),
      );
      final transportRowRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.TransportRow')),
      );
      final progressRowRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.ProgressRow')),
      );
      final compactFrameClip = tester.widget<ClipRRect>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
              matching: find.byType(ClipRRect),
            )
            .first,
      );

      expect(exitRect.left, 12);
      expect(exitRect.top, 651);
      expect(exitRect.size, const Size(68, 68));
      expect(
        compactFrameClip.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(18)),
      );
      expect(previousRect.size, const Size(36, 36));
      expect(playRect.size, const Size(48, 48));
      expect(nextRect.size, const Size(36, 36));
      expect(transportRowRect.left, 88);
      expect(transportRowRect.top, 657);
      expect(transportRowRect.width, 324);
      expect(transportRowRect.height, 56);
      expect(playRect.left - previousRect.right, 16);
      expect(nextRect.left - playRect.right, 16);
      expect(playRect.top, 661);
      expect(playRect.center.dx, 250);
      expect(moreRect.top, 668);
      expect(moreRect.right, 491);
      expect(progressRowRect.left, 88);
      expect(progressRowRect.top, 721);
      expect(progressRowRect.width, 324);
      expect(progressRowRect.height, 28);
      expect(elapsedRect.left, 21);
      expect(elapsedRect.top, 721);
      expect(elapsedRect.width, 42);
      expect(progressSliderRect.left, 71);
      expect(progressSliderRect.right, 429);
      expect(progressSliderRect.height, 18);
      expect(progressSliderRect.center.dy, progressRowRect.center.dy);
      expect(durationRect.right, 479);
      expect(durationRect.width, 42);
    },
  );

  testWidgets(
    'NowPlayingFullPage compact footer keeps voice and More inside utility',
    (tester) async {
      tester.view.physicalSize = const Size(500, 760);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      var voiceCalls = 0;
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        progressSeconds: 72,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
          shellActions: SmPlayerShellActions(
            onOpenVoiceAssistant: () {
              voiceCalls += 1;
            },
            onExitWindowFullScreen: () async {},
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        findsNothing,
      );
      expect(find.byTooltip('Voice Assistant'), findsOneWidget);
      expect(find.byTooltip('More'), findsOneWidget);
      expect(
        tester
            .getCenter(
              find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
            )
            .dx,
        250,
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('MediaControl.MoreButton')))
            .right,
        491,
      );
      expect(
        tester
                .getRect(find.byKey(const ValueKey('MediaControl.MoreButton')))
                .left -
            tester.getRect(find.byTooltip('Voice Assistant')).right,
        6,
      );

      await tester.tap(find.byTooltip('Voice Assistant'));
      await tester.pump();

      expect(voiceCalls, 1);
      expect(find.byTooltip('More'), findsOneWidget);
    },
  );

  testWidgets(
    'NowPlayingFullPage nav-minimal footer keeps voice and More in 80px utility',
    (tester) async {
      tester.view.physicalSize = const Size(800, 760);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        progressSeconds: 72,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
          shellActions: SmPlayerShellActions(
            onOpenVoiceAssistant: () {},
            onExitWindowFullScreen: () async {},
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('MediaControl.VolumeRow')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        findsNothing,
      );
      expect(find.byTooltip('Voice Assistant'), findsOneWidget);
      expect(find.byTooltip('More'), findsOneWidget);

      final voiceRect = tester.getRect(find.byTooltip('Voice Assistant'));
      final moreRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.MoreButton')),
      );
      expect(voiceRect.size, const Size(36, 36));
      expect(moreRect.size, const Size(36, 36));
      expect(voiceRect.left, 705);
      expect(moreRect.left - voiceRect.right, 6);
      expect(moreRect.right, 783);
      expect(voiceRect.top, 667);
      expect(moreRect.top, 667);
      expect(
        tester.getRect(find.byKey(const ValueKey('MediaControl.TransportRow'))),
        const Rect.fromLTWH(106, 657, 588, 56),
      );
    },
  );

  testWidgets(
    'NowPlayingFullPage switches compact columns at Electron 520px breakpoint',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });

      Future<void> pumpAtWidth(double width) async {
        tester.view.physicalSize = Size(width, 760);
        final repository = _FakeNowPlayingRepository(_snapshot);
        final mediaController = MediaControlController();
        mediaController.playTrack(
          const MediaControlTrack(
            id: 1,
            title: 'Blue Song',
            artist: 'Artist A',
            artworkUrl: '',
            isLoading: false,
            favorite: false,
          ),
          durationSeconds: 120,
          queueIndex: 0,
          progressSeconds: 72,
        );

        await tester.pumpWidget(
          _NowPlayingFullTestApp(
            snapshot: _snapshot,
            i18n: i18n,
            repository: repository,
            mediaController: mediaController,
          ),
        );
        await tester.pump();
      }

      await pumpAtWidth(520);
      expect(
        tester.getRect(
          find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
        ),
        const Rect.fromLTWH(12, 651, 68, 68),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('MediaControl.TransportRow'))),
        const Rect.fromLTWH(88, 657, 344, 56),
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
        ),
        const Size(48, 48),
      );
      final compactModeRect520 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      );
      final moreRect520 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.MoreButton')),
      );
      expect(compactModeRect520.size, const Size(34, 34));
      expect(moreRect520.size, const Size(34, 34));
      expect(compactModeRect520.left, 437);
      expect(moreRect520.left - compactModeRect520.right, 6);
      expect(moreRect520.right, 511);
      expect(
        tester.getRect(find.byKey(const ValueKey('MediaControl.ProgressRow'))),
        const Rect.fromLTWH(88, 721, 344, 28),
      );

      await pumpAtWidth(521);
      expect(
        tester.getRect(
          find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
        ),
        const Rect.fromLTWH(16, 651, 68, 68),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('MediaControl.TransportRow'))),
        const Rect.fromLTWH(106, 657, 309, 56),
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
        ),
        const Size(52, 52),
      );
      final compactModeRect521 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      );
      final moreRect521 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.MoreButton')),
      );
      expect(compactModeRect521.size, const Size(36, 36));
      expect(moreRect521.size, const Size(36, 36));
      expect(compactModeRect521.left, 426);
      expect(moreRect521.left - compactModeRect521.right, 6);
      expect(moreRect521.right, 504);
      expect(
        tester.getRect(find.byKey(const ValueKey('MediaControl.ProgressRow'))),
        const Rect.fromLTWH(106, 722, 309, 28),
      );
    },
  );

  testWidgets(
    'NowPlayingFullPage mid-width footer uses compact utility like Electron',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 760);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        progressSeconds: 72,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      expect(find.byType(MediaControlPlayerFrame), findsOneWidget);
      expect(find.byType(MediaControlSurface), findsOneWidget);
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeRow')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeButton')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.ShuffleButton')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.RepeatButton')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.RepeatOneButton')),
        findsNothing,
      );
      expect(find.byTooltip('Like'), findsOneWidget);
      final volumeRowRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.VolumeRow')),
      );
      final compactVolumeRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
      );
      final favoriteRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.FavoriteButton')),
      );
      expect(volumeRowRect.width, closeTo(252.29, 0.1));
      expect(volumeRowRect.height, 44);
      expect(compactVolumeRect.size, const Size(36, 36));
      expect(favoriteRect.size, const Size(36, 36));
      expect(favoriteRect.left - compactVolumeRect.right, 8);
      expect(favoriteRect.right, closeTo(976, 0.1));
      expect(
        tester.getSize(
          find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
        ),
        const Size(56, 56),
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('MediaControl.PlayPauseButton')))
            .top,
        652,
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        ),
        const Size(36, 36),
      );
      expect(
        tester
                .getRect(find.byKey(const ValueKey('MediaControl.MoreButton')))
                .left -
            tester
                .getRect(
                  find.byKey(const ValueKey('MediaControl.CompactModeButton')),
                )
                .right,
        8,
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
        ),
        const Size(72, 72),
      );
      expect(
        tester.widget<ExitFullscreenIcon>(
          find.byKey(const ValueKey('NowPlayingFull.ExitIcon')),
        ),
        isA<ExitFullscreenIcon>()
            .having((icon) => icon.size, 'size', 36)
            .having((icon) => icon.strokeWidth, 'strokeWidth', 2),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('MediaControl.ModeRow')))
            .width,
        closeTo(252.29, 0.1),
      );
      final transportRowRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.TransportRow')),
      );
      final progressRowRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.ProgressRow')),
      );
      expect(transportRowRect.width, closeTo(431.43, 0.1));
      expect(transportRowRect.height, 52);
      expect(progressRowRect.width, closeTo(431.43, 0.1));
      expect(progressRowRect.height, 36);
      expect(progressRowRect.top - transportRowRect.bottom, 4);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('MediaControl.MoreButton')))
            .right,
        closeTo(976, 0.1),
      );
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('MediaControl.ProgressElapsedColumn')),
            )
            .left,
        closeTo(284.29, 0.1),
      );
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('MediaControl.ProgressElapsedColumn')),
            )
            .top,
        710,
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('MediaControl.ProgressSlider')))
            .left,
        closeTo(340.29, 0.1),
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('MediaControl.ProgressSlider')))
            .right,
        closeTo(659.71, 0.1),
      );
      final progressSliderTheme = tester.widget<SliderTheme>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('MediaControl.ProgressSlider')),
              matching: find.byType(SliderTheme),
            )
            .first,
      );
      expect(
        progressSliderTheme.data.activeTrackColor,
        const Color(0xc25b697a),
      );
      expect(
        progressSliderTheme.data.inactiveTrackColor,
        const Color(0x2e5b697a),
      );
      expect(progressSliderTheme.data.thumbColor, Colors.white);
      expect(progressSliderTheme.data.trackHeight, 2);
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('MediaControl.ProgressDurationColumn')),
            )
            .right,
        closeTo(715.71, 0.1),
      );
      expect(
        tester
            .getCenter(
              find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
            )
            .dx,
        500,
      );
    },
  );

  testWidgets(
    'NowPlayingFullPage compact volume popover overlays from Electron anchor',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 760);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        progressSeconds: 72,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      final frameRectBefore = tester.getRect(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
      );
      final compactVolumeButtonRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
      );
      expect(find.byTooltip('Mute'), findsOneWidget);
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
      final compactVolumePopoverRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.CompactVolumePopover')),
      );
      expect(compactVolumePopoverRect.size, const Size(48, 116));
      expect(compactVolumePopoverRect.right, compactVolumeButtonRect.right + 6);
      expect(compactVolumePopoverRect.bottom, compactVolumeButtonRect.top - 8);
      final compactVolumePopover = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.CompactVolumePopover')),
      );
      final compactVolumePopoverDecoration =
          compactVolumePopover.decoration as BoxDecoration;
      expect(compactVolumePopoverDecoration.color, const Color(0xf5222222));
      expect(
        compactVolumePopoverDecoration.border,
        Border.all(color: const Color(0x2effffff)),
      );
      expect(
        compactVolumePopoverDecoration.borderRadius,
        BorderRadius.circular(8),
      );
      expect(compactVolumePopoverDecoration.boxShadow, const [
        BoxShadow(
          color: Color(0x6b000000),
          offset: Offset(0, 16),
          blurRadius: 36,
        ),
      ]);
      final compactVolumeSliderTheme = tester.widget<SliderTheme>(
        find
            .ancestor(
              of: find.descendant(
                of: find.byKey(
                  const ValueKey('MediaControl.CompactVolumePopover'),
                ),
                matching: find.byType(Slider),
              ),
              matching: find.byType(SliderTheme),
            )
            .first,
      );
      expect(
        compactVolumeSliderTheme.data.thumbShape,
        isA<RoundSliderThumbShape>()
            .having(
              (shape) => shape.enabledThumbRadius,
              'enabledThumbRadius',
              6,
            )
            .having((shape) => shape.elevation, 'elevation', 0)
            .having((shape) => shape.pressedElevation, 'pressedElevation', 0),
      );
      expect(
        compactVolumeSliderTheme.data.thumbShape,
        isNot(isA<MediaSliderThumbShape>()),
      );
      final compactVolumeTooltip = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('VolumeSlider.Tooltip')),
      );
      final compactVolumeSemantics = tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byKey(
                const ValueKey('MediaControl.CompactVolumePopover'),
              ),
              matching: find.byType(Semantics),
            ),
          )
          .singleWhere((semantics) => semantics.properties.label == 'Volume');
      expect(compactVolumeSemantics.properties.value, '50');
      final compactVolumeTooltipRect = tester.getRect(
        find.byKey(const ValueKey('VolumeSlider.Tooltip')),
      );
      expect(compactVolumePopoverRect.left - compactVolumeTooltipRect.right, 8);
      final compactVolumeTooltipDecoration =
          compactVolumeTooltip.decoration as BoxDecoration;
      expect(compactVolumeTooltipDecoration.color, const Color(0xf5222222));
      expect(
        compactVolumeTooltipDecoration.border,
        Border.all(color: const Color(0x2effffff)),
      );
      expect(compactVolumeTooltipDecoration.boxShadow, const [
        BoxShadow(
          color: Color(0x57000000),
          offset: Offset(0, 8),
          blurRadius: 18,
        ),
      ]);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('VolumeSlider.Tooltip')),
                matching: find.byType(Text),
              ),
            )
            .style
            ?.color,
        Colors.white,
      );
      final compactVolumeTooltipArrow = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('VolumeSlider.TooltipArrow')),
      );
      final compactVolumeTooltipArrowBorder =
          (compactVolumeTooltipArrow.decoration as BoxDecoration).border!
              as Border;
      expect(
        compactVolumeTooltipArrowBorder.top.color,
        const Color(0x2effffff),
      );
      expect(
        compactVolumeTooltipArrowBorder.right.color,
        const Color(0x2effffff),
      );
      expect(compactVolumeTooltipArrowBorder.bottom, BorderSide.none);
      expect(compactVolumeTooltipArrowBorder.left, BorderSide.none);
      expect(
        find.descendant(
          of: find.byType(MediaControlPlayerFrame),
          matching: find.byKey(
            const ValueKey('MediaControl.CompactVolumePopover'),
          ),
        ),
        findsNothing,
      );
      expect(
        tester.getRect(
          find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
        ),
        frameRectBefore,
      );
      await tester.pump(const Duration(milliseconds: 899));
      expect(
        find.byKey(const ValueKey('VolumeSlider.Tooltip')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(const ValueKey('VolumeSlider.Tooltip')), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MediaControl.CompactVolumePopover')),
        findsNothing,
      );
      final modeButtonRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      );
      final modeMenuRect = tester.getRect(
        find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
      );
      expect(modeButtonRect.top - modeMenuRect.bottom, 8);
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.text('Repeat'), findsOneWidget);
      expect(find.text('Repeat One'), findsOneWidget);
    },
  );

  testWidgets(
    'NowPlayingFullPage utility switches at Electron 1200px breakpoint',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });

      Future<void> pumpAtWidth(double width) async {
        tester.view.physicalSize = Size(width, 760);
        final repository = _FakeNowPlayingRepository(_snapshot);
        final mediaController = MediaControlController();
        mediaController.playTrack(
          const MediaControlTrack(
            id: 1,
            title: 'Blue Song',
            artist: 'Artist A',
            artworkUrl: '',
            isLoading: false,
            favorite: false,
          ),
          durationSeconds: 120,
          queueIndex: 0,
          progressSeconds: 72,
        );

        await tester.pumpWidget(
          _NowPlayingFullTestApp(
            snapshot: _snapshot,
            i18n: i18n,
            repository: repository,
            mediaController: mediaController,
          ),
        );
        await tester.pump();
      }

      await pumpAtWidth(1200);
      expect(
        find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.ShuffleButton')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.RepeatButton')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.RepeatOneButton')),
        findsNothing,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('MediaControl.TransportRow'))),
        isA<Size>()
            .having((size) => size.width, 'width', closeTo(487.14, 0.1))
            .having((size) => size.height, 'height', 52),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('MediaControl.ProgressRow'))),
        isA<Size>()
            .having((size) => size.width, 'width', closeTo(487.14, 0.1))
            .having((size) => size.height, 'height', 36),
      );
      final compactVolumeRect1200 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
      );
      final favoriteRect1200 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.FavoriteButton')),
      );
      final compactModeRect1200 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      );
      final moreRect1200 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.MoreButton')),
      );
      expect(favoriteRect1200.left - compactVolumeRect1200.right, 8);
      expect(favoriteRect1200.right, closeTo(1176, 0.1));
      expect(moreRect1200.left - compactModeRect1200.right, 8);
      expect(moreRect1200.right, closeTo(1176, 0.1));

      await pumpAtWidth(1201);
      expect(
        find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.ShuffleButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.RepeatButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.RepeatOneButton')),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('MediaControl.TransportRow'))),
        isA<Size>()
            .having((size) => size.width, 'width', closeTo(487.5, 0.1))
            .having((size) => size.height, 'height', 52),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('MediaControl.ProgressRow'))),
        isA<Size>()
            .having((size) => size.width, 'width', closeTo(487.5, 0.1))
            .having((size) => size.height, 'height', 36),
      );
      final volumeButtonRect1201 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.VolumeButton')),
      );
      final volumeSliderRect1201 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
      );
      final favoriteRect1201 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.FavoriteButton')),
      );
      final shuffleRect1201 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.ShuffleButton')),
      );
      final repeatRect1201 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.RepeatButton')),
      );
      final repeatOneRect1201 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.RepeatOneButton')),
      );
      final moreRect1201 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.MoreButton')),
      );
      expect(volumeSliderRect1201.size, const Size(148, 22));
      expect(volumeSliderRect1201.left - volumeButtonRect1201.right, 14);
      expect(favoriteRect1201.left - volumeSliderRect1201.right, 14);
      expect(favoriteRect1201.right, closeTo(1169, 0.1));
      expect(repeatRect1201.left - shuffleRect1201.right, 14);
      expect(repeatOneRect1201.left - repeatRect1201.right, 14);
      expect(moreRect1201.right, closeTo(1169, 0.1));
    },
  );

  testWidgets(
    'NowPlayingFullPage switches nav-minimal layout at Electron 800px breakpoint',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });

      Future<void> pumpAtWidth(double width) async {
        tester.view.physicalSize = Size(width, 760);
        final repository = _FakeNowPlayingRepository(_snapshot);
        final mediaController = MediaControlController();
        mediaController.playTrack(
          const MediaControlTrack(
            id: 1,
            title: 'Blue Song',
            artist: 'Artist A',
            artworkUrl: '',
            isLoading: false,
            favorite: false,
          ),
          durationSeconds: 120,
          queueIndex: 0,
          progressSeconds: 72,
        );

        await tester.pumpWidget(
          _NowPlayingFullTestApp(
            snapshot: _snapshot,
            i18n: i18n,
            repository: repository,
            mediaController: mediaController,
          ),
        );
        await tester.pump();
      }

      await pumpAtWidth(800);
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeRow')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        findsOneWidget,
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
        ),
        const Size(52, 52),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('MediaControl.TransportRow'))),
        const Rect.fromLTWH(106, 657, 588, 56),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('MediaControl.ProgressRow'))),
        const Rect.fromLTWH(106, 722, 588, 28),
      );
      final compactFrameGlass = tester.widget<GlassContainer>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
              matching: find.byType(GlassContainer),
            )
            .first,
      );
      expect(compactFrameGlass.settings?.blur, 18);
      expect(compactFrameGlass.settings?.saturation, 1.4);
      final compactFrameBorderDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
      );
      final compactFrameBorder =
          (compactFrameBorderDecoration.decoration as BoxDecoration).border!
              as Border;
      expect(compactFrameBorder.top.color, const Color(0xb8ccd5e0));
      expect(compactFrameBorder.right, BorderSide.none);
      expect(compactFrameBorder.bottom, BorderSide.none);
      expect(compactFrameBorder.left, BorderSide.none);
      final compactFrameShadowDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameShadow')),
      );
      expect(
        (compactFrameShadowDecoration.decoration as BoxDecoration).boxShadow,
        const [
          BoxShadow(
            color: Color(0x24445870),
            offset: Offset(0, -18),
            blurRadius: 56,
          ),
        ],
      );
      final compactFrameBackgroundDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBackground')),
      );
      final compactFrameBackground =
          compactFrameBackgroundDecoration.decoration as BoxDecoration;
      expect(compactFrameBackground.color, const Color(0xc7ffffff));
      final compactFrameGradient =
          compactFrameBackground.gradient! as RadialGradient;
      expect(compactFrameGradient.center, const Alignment(-0.6, -0.56));
      expect(compactFrameGradient.radius, 0.42);
      expect(compactFrameGradient.colors, const [
        Color.fromRGBO(91, 135, 182, 0.24),
        Colors.transparent,
      ]);
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('MediaControl.ProgressElapsedColumn')),
            )
            .left,
        25,
      );
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('MediaControl.ProgressDurationColumn')),
            )
            .right,
        775,
      );
      await tester.tap(find.byKey(const ValueKey('MediaControl.MoreButton')));
      await tester.pumpAndSettle();
      expect(find.text('Playback Mode: List'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeMenuItem')),
        findsOneWidget,
      );
      expect(find.text('Like'), findsOneWidget);
      await tester.tapAt(const Offset(40, 40));
      await tester.pumpAndSettle();

      await pumpAtWidth(801);
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeRow')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
        findsNothing,
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
        ),
        const Size(56, 56),
      );
      final transportRowSize801 = tester.getSize(
        find.byKey(const ValueKey('MediaControl.TransportRow')),
      );
      final progressRowSize801 = tester.getSize(
        find.byKey(const ValueKey('MediaControl.ProgressRow')),
      );
      expect(transportRowSize801.width, closeTo(337.76, 0.1));
      expect(transportRowSize801.height, 52);
      expect(progressRowSize801.width, closeTo(337.76, 0.1));
      expect(progressRowSize801.height, 36);
      expect(tester.takeException(), isNull);
      final compactVolumeRect801 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.CompactVolumeButton')),
      );
      final favoriteRect801 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.FavoriteButton')),
      );
      final compactModeRect801 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      );
      final moreRect801 = tester.getRect(
        find.byKey(const ValueKey('MediaControl.MoreButton')),
      );
      expect(compactVolumeRect801.left, closeTo(697, 0.1));
      expect(favoriteRect801.left - compactVolumeRect801.right, 8);
      expect(favoriteRect801.right, closeTo(777, 0.1));
      expect(compactModeRect801.left, closeTo(697, 0.1));
      expect(moreRect801.left - compactModeRect801.right, 8);
      expect(moreRect801.right, closeTo(777, 0.1));
      final wideFrameGlass = tester.widget<GlassContainer>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
              matching: find.byType(GlassContainer),
            )
            .first,
      );
      expect(wideFrameGlass.settings?.blur, 18);
      expect(wideFrameGlass.settings?.saturation, 1.4);
      final wideFrameBorderDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
      );
      final wideFrameBorder =
          (wideFrameBorderDecoration.decoration as BoxDecoration).border!
              as Border;
      expect(wideFrameBorder.top.color, const Color(0xb8ccd5e0));
      expect(wideFrameBorder.right, wideFrameBorder.top);
      expect(wideFrameBorder.bottom, wideFrameBorder.top);
      expect(wideFrameBorder.left, wideFrameBorder.top);
      final wideFrameShadowDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameShadow')),
      );
      expect(
        (wideFrameShadowDecoration.decoration as BoxDecoration).boxShadow,
        const [
          BoxShadow(
            color: Color(0x24445870),
            offset: Offset(0, -18),
            blurRadius: 56,
          ),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('MediaControl.MoreButton')));
      await tester.pumpAndSettle();
      expect(find.text('Playback Mode: List'), findsNothing);
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeMenuItem')),
        findsNothing,
      );
      expect(find.text('Like'), findsNothing);
    },
  );

  testWidgets(
    'NowPlayingFullPage keeps nav-minimal columns across Electron 721px lower bound',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });

      Future<void> pumpAtWidth(double width) async {
        tester.view.physicalSize = Size(width, 760);
        final repository = _FakeNowPlayingRepository(_snapshot);
        final mediaController = MediaControlController();
        mediaController.playTrack(
          const MediaControlTrack(
            id: 1,
            title: 'Blue Song',
            artist: 'Artist A',
            artworkUrl: '',
            isLoading: false,
            favorite: false,
          ),
          durationSeconds: 120,
          queueIndex: 0,
          progressSeconds: 72,
        );

        await tester.pumpWidget(
          _NowPlayingFullTestApp(
            snapshot: _snapshot,
            i18n: i18n,
            repository: repository,
            mediaController: mediaController,
          ),
        );
        await tester.pump();
      }

      await pumpAtWidth(721);
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeRow')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        findsOneWidget,
      );
      expect(
        tester.getRect(
          find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
        ),
        const Rect.fromLTWH(16, 651, 68, 68),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('MediaControl.TransportRow'))),
        const Rect.fromLTWH(106, 657, 509, 56),
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
        ),
        const Size(52, 52),
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('MediaControl.MoreButton')))
            .right,
        704,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('MediaControl.ProgressRow'))),
        const Rect.fromLTWH(106, 722, 509, 28),
      );
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('MediaControl.ProgressElapsedColumn')),
            )
            .left,
        25,
      );
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('MediaControl.ProgressDurationColumn')),
            )
            .right,
        696,
      );

      await pumpAtWidth(720);
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeRow')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        findsOneWidget,
      );
      expect(
        tester.getRect(
          find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
        ),
        const Rect.fromLTWH(16, 651, 68, 68),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('MediaControl.TransportRow'))),
        const Rect.fromLTWH(106, 657, 508, 56),
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
        ),
        const Size(52, 52),
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('MediaControl.MoreButton')))
            .right,
        703,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('MediaControl.ProgressRow'))),
        const Rect.fromLTWH(106, 722, 508, 28),
      );
    },
  );

  testWidgets('NowPlayingFullPage wide mode row keeps Electron active state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
    );
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      resetSmPlayerGlobalSettingsSnapshot();
    });
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
      progressSeconds: 72,
    );
    mediaController.onToggleRepeat();

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    BoxDecoration buttonDecoration(ValueKey<String> key) {
      return tester
              .widget<AnimatedContainer>(
                find.descendant(
                  of: find.byKey(key),
                  matching: find.byType(AnimatedContainer),
                ),
              )
              .decoration!
          as BoxDecoration;
    }

    expect(
      find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      findsNothing,
    );
    expect(
      buttonDecoration(const ValueKey('MediaControl.ShuffleButton')).color,
      Colors.transparent,
    );
    expect(
      buttonDecoration(const ValueKey('MediaControl.RepeatButton')).color,
      const Color(0x1a0078d7),
    );
    expect(
      buttonDecoration(const ValueKey('MediaControl.RepeatOneButton')).color,
      Colors.transparent,
    );

    await tester.tap(find.byKey(const ValueKey('MediaControl.RepeatButton')));
    await tester.pump();

    expect(mediaController.state.mode, PlaybackMode.once);
    expect(
      buttonDecoration(const ValueKey('MediaControl.RepeatButton')).color,
      Colors.transparent,
    );
  });

  testWidgets(
    'NowPlayingFullPage night utility active state follows Electron cascade',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.onMode),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        progressSeconds: 72,
      );
      mediaController.onToggleRepeat();

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      BoxDecoration repeatDecoration() {
        return tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byKey(const ValueKey('MediaControl.RepeatButton')),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;
      }

      expect(repeatDecoration().color, const Color(0x380078d7));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(
          find.byKey(const ValueKey('MediaControl.RepeatButton')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(repeatDecoration().color, const Color(0x380078d7));
      await mouse.removePointer();
    },
  );

  testWidgets(
    'NowPlayingFullPage primary and utility hover follow Electron cascade',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });

      Future<void> pumpFullPage({required bool night}) async {
        final settings = const SettingsSnapshot.defaults().copyWith(
          nightMode: night ? NightMode.onMode : NightMode.never,
        );
        setSmPlayerGlobalSettingsSnapshot(settings);
        final repository = _FakeNowPlayingRepository(_snapshot);
        final mediaController = MediaControlController();
        mediaController.playTrack(
          const MediaControlTrack(
            id: 1,
            title: 'Blue Song',
            artist: 'Artist A',
            artworkUrl: '',
            isLoading: false,
            favorite: false,
          ),
          durationSeconds: 120,
          queueIndex: 0,
          progressSeconds: 72,
        );

        await tester.pumpWidget(
          _NowPlayingFullTestApp(
            snapshot: _snapshot,
            i18n: i18n,
            repository: repository,
            mediaController: mediaController,
            themeSettings: settings,
          ),
        );
        await tester.pump();
      }

      BoxDecoration moreDecoration() {
        return tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byKey(const ValueKey('MediaControl.MoreButton')),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;
      }

      BoxDecoration playDecoration() {
        return tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byKey(
                      const ValueKey('MediaControl.PlayPauseButton'),
                    ),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;
      }

      Future<void> verifyMoreHover(Color expectedHoverColor) async {
        expect(moreDecoration().color, Colors.transparent);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        await tester.pump();
        await mouse.moveTo(
          tester.getCenter(
            find.byKey(const ValueKey('MediaControl.MoreButton')),
          ),
        );
        await tester.pump(const Duration(milliseconds: 140));
        expect(moreDecoration().color, expectedHoverColor);
        await mouse.removePointer();
        await tester.pump();
      }

      Future<void> verifyPrimaryHover() async {
        expect(playDecoration().color, MediaControlColors.accent);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        await tester.pump();
        await mouse.moveTo(
          tester.getCenter(
            find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
          ),
        );
        await tester.pump(const Duration(milliseconds: 140));
        expect(playDecoration().color, MediaControlColors.accentStrong);
        await mouse.removePointer();
        await tester.pump();
      }

      await pumpFullPage(night: false);
      await verifyPrimaryHover();
      await verifyMoreHover(const Color(0x1a0078d7));

      await pumpFullPage(night: true);
      await verifyPrimaryHover();
      await verifyMoreHover(const Color(0x2e0078d7));
    },
  );

  testWidgets('NowPlayingFullPage wide mode row keeps Electron voice slot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
    );
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      resetSmPlayerGlobalSettingsSnapshot();
    });
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    var voiceCalls = 0;
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
      progressSeconds: 72,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
        shellActions: SmPlayerShellActions(
          onOpenVoiceAssistant: () {
            voiceCalls += 1;
          },
          onExitWindowFullScreen: () async {},
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      findsNothing,
    );
    final shuffleRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.ShuffleButton')),
    );
    final repeatRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.RepeatButton')),
    );
    final repeatOneRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.RepeatOneButton')),
    );
    final voiceRect = tester.getRect(find.byTooltip('Voice Assistant'));
    final moreRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.MoreButton')),
    );

    expect(shuffleRect.size, const Size(36, 36));
    expect(repeatRect.size, const Size(36, 36));
    expect(repeatOneRect.size, const Size(36, 36));
    expect(voiceRect.size, const Size(36, 36));
    expect(moreRect.size, const Size(36, 36));
    expect(shuffleRect.left, closeTo(1132, 0.1));
    expect(repeatRect.left - shuffleRect.right, 14);
    expect(repeatOneRect.left - repeatRect.right, 14);
    expect(voiceRect.left - repeatOneRect.right, 14);
    expect(moreRect.left - voiceRect.right, 14);
    expect(moreRect.right, closeTo(1368, 0.1));

    await tester.tap(find.byTooltip('Voice Assistant'));
    await tester.pump();
    expect(voiceCalls, 1);
  });

  testWidgets(
    'NowPlayingFullPage wide mute keeps Electron active volume button',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        progressSeconds: 72,
      );
      mediaController.onToggleMute();

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      BoxDecoration volumeDecoration() {
        return tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byKey(const ValueKey('MediaControl.VolumeButton')),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;
      }

      expect(find.byTooltip('Unmute'), findsOneWidget);
      expect(volumeDecoration().color, const Color(0x1a0078d7));
      expect(
        tester.getSize(find.byKey(const ValueKey('MediaControl.VolumeButton'))),
        const Size(36, 36),
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
        ),
        const Size(148, 22),
      );
      final mutedVolumeSlider = tester.widget<Slider>(
        find.descendant(
          of: find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
          matching: find.byType(Slider),
        ),
      );
      expect(mutedVolumeSlider.value, 50);

      await tester.tap(find.byKey(const ValueKey('MediaControl.VolumeButton')));
      await tester.pump();

      expect(mediaController.state.isMuted, isFalse);
      expect(find.byTooltip('Mute'), findsOneWidget);
      expect(volumeDecoration().color, Colors.transparent);
    },
  );

  testWidgets(
    'NowPlayingFullPage wide footer uses Electron 0.9fr side columns',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        progressSeconds: 72,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      final playerBarPosition = tester.widget<Positioned>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('NowPlayingFull.PlayerBarOpacity')),
              matching: find.byType(Positioned),
            )
            .first,
      );
      expect(playerBarPosition.left, 0);
      expect(playerBarPosition.right, 0);
      expect(playerBarPosition.bottom, 0);
      expect(playerBarPosition.height, 120);
      final playerBarOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('NowPlayingFull.PlayerBarOpacity')),
      );
      expect(playerBarOpacity.opacity, 1);
      expect(playerBarOpacity.duration, const Duration(milliseconds: 180));
      expect(playerBarOpacity.curve, Curves.ease);
      final playerBarSlide = tester.widget<AnimatedSlide>(
        find.byKey(const ValueKey('NowPlayingFull.PlayerBarSlide')),
      );
      expect(playerBarSlide.offset, Offset.zero);
      expect(playerBarSlide.duration, const Duration(milliseconds: 260));
      expect(playerBarSlide.curve, const Cubic(0.2, 0, 0, 1));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('MediaControl.ModeRow')))
            .width,
        closeTo(376.71, 0.1),
      );
      final transportRowRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.TransportRow')),
      );
      final progressRowRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.ProgressRow')),
      );
      expect(transportRowRect.width, closeTo(558.57, 0.1));
      expect(transportRowRect.height, 52);
      expect(progressRowRect.width, closeTo(558.57, 0.1));
      expect(progressRowRect.height, 36);
      expect(progressRowRect.top - transportRowRect.bottom, 4);
      final progressElapsedRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.ProgressElapsedColumn')),
      );
      final progressSliderRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.ProgressSlider')),
      );
      final progressDurationRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.ProgressDurationColumn')),
      );
      expect(progressElapsedRect.left, closeTo(420.71, 0.1));
      expect(progressElapsedRect.width, 44);
      expect(progressSliderRect.left - progressElapsedRect.right, 12);
      expect(progressSliderRect.left, closeTo(476.71, 0.1));
      expect(progressSliderRect.right, closeTo(923.29, 0.1));
      expect(progressSliderRect.height, 18);
      expect(progressSliderRect.center.dy, progressRowRect.center.dy);
      expect(progressDurationRect.left - progressSliderRect.right, 12);
      expect(progressDurationRect.width, 44);
      expect(progressDurationRect.right, closeTo(979.29, 0.1));
      final wideProgressElapsedText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('MediaControl.ProgressElapsedColumn')),
          matching: find.byType(Text),
        ),
      );
      final wideProgressDurationText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('MediaControl.ProgressDurationColumn')),
          matching: find.byType(Text),
        ),
      );
      expect(wideProgressElapsedText.style?.fontSize, 13);
      expect(wideProgressDurationText.style?.fontSize, 13);
      final progressSemantics = tester
          .widgetList<Semantics>(
            find.ancestor(
              of: find.byKey(const ValueKey('MediaControl.ProgressSlider')),
              matching: find.byType(Semantics),
            ),
          )
          .singleWhere(
            (semantics) => semantics.properties.label == 'Track progress',
          );
      expect(progressSemantics.properties.value, '1:12');
      final volumeRowRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.VolumeRow')),
      );
      final volumeButtonRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.VolumeButton')),
      );
      final volumeSliderRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
      );
      final favoriteRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.FavoriteButton')),
      );
      expect(volumeRowRect.width, closeTo(376.71, 0.1));
      expect(volumeRowRect.height, 44);
      expect(volumeButtonRect.size, const Size(36, 36));
      expect(volumeSliderRect.size, const Size(148, 22));
      expect(favoriteRect.size, const Size(36, 36));
      expect(volumeSliderRect.left - volumeButtonRect.right, 14);
      expect(favoriteRect.left - volumeSliderRect.right, 14);
      expect(favoriteRect.right, 1368);
      final shuffleRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.ShuffleButton')),
      );
      final repeatRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.RepeatButton')),
      );
      final repeatOneRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.RepeatOneButton')),
      );
      final moreRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.MoreButton')),
      );
      expect(shuffleRect.size, const Size(36, 36));
      expect(repeatRect.size, const Size(36, 36));
      expect(repeatOneRect.size, const Size(36, 36));
      expect(moreRect.size, const Size(36, 36));
      expect(repeatRect.left - shuffleRect.right, 14);
      expect(repeatOneRect.left - repeatRect.right, 14);
      expect(moreRect.left - repeatOneRect.right, 14);
      final previousRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.PreviousButton')),
      );
      final playRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
      );
      final nextRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.NextButton')),
      );
      expect(previousRect.size, const Size(36, 36));
      expect(playRect.size, const Size(56, 56));
      expect(nextRect.size, const Size(36, 36));
      expect(playRect.left - previousRect.right, 26);
      expect(nextRect.left - playRect.right, 26);
      expect(
        tester
            .getCenter(
              find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
            )
            .dx,
        700,
      );
      expect(moreRect.right, 1368);
      final frameBorderDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
      );
      final frameBorder =
          (frameBorderDecoration.decoration as BoxDecoration).border! as Border;
      final frameClip = tester.widget<ClipRRect>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      expect(
        frameClip.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(18)),
      );
      final frameGlass = tester.widget<GlassContainer>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
              matching: find.byType(GlassContainer),
            )
            .first,
      );
      expect(frameGlass.settings?.blur, 18);
      expect(frameGlass.settings?.saturation, 1.4);
      expect(frameBorder.top, isNot(BorderSide.none));
      expect(frameBorder.top.color, const Color(0xb8ccd5e0));
      expect(frameBorder.right, frameBorder.top);
      expect(frameBorder.bottom, frameBorder.top);
      expect(frameBorder.left, frameBorder.top);
      final frameShadowDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameShadow')),
      );
      expect(
        (frameShadowDecoration.decoration as BoxDecoration).boxShadow,
        const [
          BoxShadow(
            color: Color(0x24445870),
            offset: Offset(0, -18),
            blurRadius: 56,
          ),
        ],
      );
      final frameBackgroundDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBackground')),
      );
      final frameBackground =
          frameBackgroundDecoration.decoration as BoxDecoration;
      expect(frameBackground.color, const Color(0xc7ffffff));
      final frameBackgroundGradient =
          frameBackground.gradient! as RadialGradient;
      expect(frameBackgroundGradient.center, const Alignment(-0.6, -0.56));
      expect(frameBackgroundGradient.radius, 0.42);
      expect(frameBackgroundGradient.colors, const [
        Color.fromRGBO(91, 135, 182, 0.24),
        Colors.transparent,
      ]);
      final frameInsetHighlight = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameInsetHighlight')),
      );
      expect(frameInsetHighlight.color, const Color(0xc7ffffff));
      final playButton = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final playDecoration = playButton.decoration! as BoxDecoration;
      expect(playDecoration.border, Border.all(color: Colors.transparent));
      expect(playDecoration.boxShadow, const [
        BoxShadow(
          color: MediaControlColors.accentShadow,
          offset: Offset(0, 12),
          blurRadius: 26,
        ),
      ]);
      expect(
        tester
            .widget<SmPlayerMoreHorizontalIcon>(
              find.descendant(
                of: find.byKey(const ValueKey('MediaControl.MoreButton')),
                matching: find.byType(SmPlayerMoreHorizontalIcon),
              ),
            )
            .color,
        MediaControlColors.textStrong,
      );
      final moreSlide = tester.widget<AnimatedSlide>(
        find
            .descendant(
              of: find.byKey(const ValueKey('MediaControl.MoreButton')),
              matching: find.byType(AnimatedSlide),
            )
            .first,
      );
      expect(moreSlide.duration, const Duration(milliseconds: 140));
      expect(moreSlide.curve, Curves.ease);
      final moreContainer = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byKey(const ValueKey('MediaControl.MoreButton')),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(moreContainer.duration, const Duration(milliseconds: 140));
      expect(moreContainer.curve, Curves.ease);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(
          find.byKey(const ValueKey('MediaControl.MoreButton')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final hoveredMoreButton = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byKey(const ValueKey('MediaControl.MoreButton')),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(
        (hoveredMoreButton.decoration! as BoxDecoration).color,
        const Color(0x1a0078d7),
      );
      expect(
        tester
            .widget<SmPlayerMoreHorizontalIcon>(
              find.descendant(
                of: find.byKey(const ValueKey('MediaControl.MoreButton')),
                matching: find.byType(SmPlayerMoreHorizontalIcon),
              ),
            )
            .color,
        MediaControlColors.accentStrong,
      );
      await mouse.removePointer();
      final progressElapsed = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('MediaControl.ProgressElapsedColumn')),
          matching: find.byType(Text),
        ),
      );
      expect(progressElapsed.style?.color, MediaControlColors.textMuted);
      final progressDuration = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('MediaControl.ProgressDurationColumn')),
          matching: find.byType(Text),
        ),
      );
      expect(progressDuration.style?.color, MediaControlColors.textMuted);
      final progressTheme = tester.widget<SliderTheme>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('MediaControl.ProgressSlider')),
              matching: find.byType(SliderTheme),
            )
            .first,
      );
      expect(progressTheme.data.activeTrackColor, const Color(0xc25b697a));
      expect(progressTheme.data.inactiveTrackColor, const Color(0x2e5b697a));
      expect(progressTheme.data.thumbColor, Colors.white);
      final progressThumb =
          progressTheme.data.thumbShape! as MediaSliderThumbShape;
      expect(
        progressThumb.shadow,
        const BoxShadow(
          color: Color(0x52445870),
          offset: Offset(0, 1),
          blurRadius: 8,
        ),
      );
      final volumeTheme = tester.widget<SliderTheme>(
        find
            .descendant(
              of: find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
              matching: find.byType(SliderTheme),
            )
            .first,
      );
      final volumeThumb = volumeTheme.data.thumbShape! as MediaSliderThumbShape;
      expect(volumeTheme.data.activeTrackColor, const Color(0xeb0078d7));
      expect(volumeTheme.data.inactiveTrackColor, const Color(0x2e323e4e));
      expect(volumeTheme.data.thumbColor, MediaControlColors.accent);
      expect(
        volumeThumb.shadow,
        const BoxShadow(
          color: Color(0x47000000),
          offset: Offset(0, 1),
          blurRadius: 4,
        ),
      );
      final volumeMouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await volumeMouse.addPointer(
        location: tester.getCenter(
          find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
        ),
      );
      await tester.pump();
      final volumeTooltip = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('VolumeSlider.Tooltip')),
      );
      final volumeTooltipRect = tester.getRect(
        find.byKey(const ValueKey('VolumeSlider.Tooltip')),
      );
      final hoveredVolumeSliderRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.WideVolumeSlider')),
      );
      expect(volumeTooltipRect.bottom, hoveredVolumeSliderRect.top - 8);
      final volumeTooltipDecoration = volumeTooltip.decoration as BoxDecoration;
      expect(volumeTooltipDecoration.color, const Color(0xe014181e));
      expect(
        volumeTooltipDecoration.border,
        Border.all(color: const Color(0x2effffff)),
      );
      expect(volumeTooltipDecoration.boxShadow, const [
        BoxShadow(
          color: Color(0x57000000),
          offset: Offset(0, 10),
          blurRadius: 24,
        ),
      ]);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('VolumeSlider.Tooltip')),
                matching: find.byType(Text),
              ),
            )
            .style
            ?.color,
        Colors.white,
      );
      final volumeTooltipArrow = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('VolumeSlider.TooltipArrow')),
      );
      final volumeTooltipArrowBorder =
          (volumeTooltipArrow.decoration as BoxDecoration).border! as Border;
      expect(volumeTooltipArrowBorder.right.color, const Color(0x2effffff));
      expect(volumeTooltipArrowBorder.bottom.color, const Color(0x2effffff));
      expect(volumeTooltipArrowBorder.top, BorderSide.none);
      expect(volumeTooltipArrowBorder.left, BorderSide.none);
      await volumeMouse.removePointer();
    },
  );

  testWidgets(
    'NowPlayingFullPage night footer uses Electron full-page frame colors',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.onMode),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        progressSeconds: 72,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
          themeSettings: const SettingsSnapshot.defaults().copyWith(
            nightMode: NightMode.onMode,
          ),
        ),
      );
      await tester.pump();

      final frameGlass = tester.widget<GlassContainer>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
              matching: find.byType(GlassContainer),
            )
            .first,
      );
      expect(frameGlass.settings?.blur, 28);
      expect(frameGlass.settings?.saturation, 1);

      final frameBorderDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
      );
      final frameBorder =
          (frameBorderDecoration.decoration as BoxDecoration).border! as Border;
      expect(frameBorder.top.color, const Color(0x1fd6e0ec));
      expect(frameBorder.right, frameBorder.top);
      expect(frameBorder.bottom, frameBorder.top);
      expect(frameBorder.left, frameBorder.top);

      final frameShadowDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameShadow')),
      );
      expect(
        (frameShadowDecoration.decoration as BoxDecoration).boxShadow,
        const [
          BoxShadow(
            color: Color(0x57000000),
            offset: Offset(0, -18),
            blurRadius: 48,
          ),
        ],
      );

      final frameBackgroundDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBackground')),
      );
      final frameInsetHighlight = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameInsetHighlight')),
      );
      expect(frameInsetHighlight.color, const Color(0x0cffffff));
      final frameBackground =
          frameBackgroundDecoration.decoration as BoxDecoration;
      expect(frameBackground.color, const Color(0xe611161c));
      final coverWashDecoration = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byKey(
                const ValueKey('MediaControl.PlayerFrameBackground'),
              ),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .firstWhere(
            (decoration) =>
                decoration.gradient is LinearGradient &&
                (decoration.gradient! as LinearGradient).begin ==
                    Alignment.centerLeft,
          );
      final coverWashGradient = coverWashDecoration.gradient! as LinearGradient;
      expect(coverWashGradient.begin, Alignment.centerLeft);
      expect(coverWashGradient.end, Alignment.centerRight);
      expect(coverWashGradient.colors, const [
        Color.fromRGBO(91, 135, 182, 0.22),
        Colors.transparent,
      ]);
      expect(coverWashGradient.stops, const [0, 0.46]);
      final highlightDecoration = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byKey(
                const ValueKey('MediaControl.PlayerFrameBackground'),
              ),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .firstWhere(
            (decoration) =>
                decoration.gradient is LinearGradient &&
                (decoration.gradient! as LinearGradient).begin ==
                    Alignment.topLeft,
          );
      final highlightGradient = highlightDecoration.gradient! as LinearGradient;
      expect(highlightGradient.begin, Alignment.topLeft);
      expect(highlightGradient.end, Alignment.bottomRight);
      expect(highlightGradient.colors, const [
        Color(0x0effffff),
        Color(0x1f0078d7),
      ]);
      expect(highlightGradient.stops, isNull);
    },
  );

  testWidgets(
    'NowPlayingFullPage favorite active style follows Electron day and night',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });

      final favoriteSnapshot = _snapshotWithSongs(_snapshot, [
        _songWithFavorite(_snapshot.songs.single, true),
      ]);

      Future<void> pumpFullPage({required bool night}) async {
        final settings = const SettingsSnapshot.defaults().copyWith(
          nightMode: night ? NightMode.onMode : NightMode.never,
        );
        setSmPlayerGlobalSettingsSnapshot(settings);
        final repository = _FakeNowPlayingRepository(favoriteSnapshot);
        final mediaController = MediaControlController();
        mediaController.playTrack(
          const MediaControlTrack(
            id: 1,
            title: 'Blue Song',
            artist: 'Artist A',
            artworkUrl: '',
            isLoading: false,
            favorite: true,
          ),
          durationSeconds: 120,
          queueIndex: 0,
          progressSeconds: 72,
        );

        await tester.pumpWidget(
          _NowPlayingFullTestApp(
            snapshot: favoriteSnapshot,
            i18n: i18n,
            repository: repository,
            mediaController: mediaController,
            themeSettings: settings,
          ),
        );
        await tester.pump();
      }

      BoxDecoration favoriteDecoration() {
        return tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byKey(
                      const ValueKey('MediaControl.FavoriteButton'),
                    ),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;
      }

      Future<void> verifyHover(Color expectedHoverColor) async {
        expect(
          find.byKey(const ValueKey('MediaControl.FavoriteFilledIcon')),
          findsOneWidget,
        );
        expect(favoriteDecoration().color, Colors.transparent);

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        await mouse.moveTo(
          tester.getCenter(
            find.byKey(const ValueKey('MediaControl.FavoriteButton')),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 140));
        expect(favoriteDecoration().color, expectedHoverColor);
        await mouse.removePointer();
        await tester.pump();
      }

      await pumpFullPage(night: false);
      await verifyHover(const Color(0x1a0078d7));

      await pumpFullPage(night: true);
      await verifyHover(const Color(0x38ffffff));
    },
  );

  testWidgets(
    'NowPlayingFullPage night exit overlay stays visible on hover like Electron',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.onMode),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
          themeSettings: const SettingsSnapshot.defaults().copyWith(
            nightMode: NightMode.onMode,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
          matching: find.byKey(
            const ValueKey('NowPlayingFull.ExitAlbumSwatch'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
          matching: find.byType(SongArtwork),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
          matching: find.text('Blue Song'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
          matching: find.text('Artist A'),
        ),
        findsNothing,
      );
      BoxDecoration exitShellDecoration() =>
          tester
                  .widget<AnimatedContainer>(
                    find.byKey(
                      const ValueKey('NowPlayingFull.ExitArtworkShell'),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      BoxDecoration exitOverlayDecoration() =>
          tester
                  .widget<DecoratedBox>(
                    find.byKey(
                      const ValueKey('NowPlayingFull.ExitArtworkOverlay'),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      AnimatedContainer exitShell() => tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
      );

      expect(exitOverlayDecoration().color, const Color(0x6b080c12));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
          matching: find.byKey(
            const ValueKey('NowPlayingFull.ExitArtworkBackdrop'),
          ),
        ),
        findsOneWidget,
      );
      expect(exitShellDecoration().color, const Color(0x14ffffff));
      expect(exitShellDecoration().border?.top.color, const Color(0x1fffffff));
      expect(
        exitShellDecoration().gradient,
        isA<LinearGradient>()
            .having((gradient) => gradient.begin, 'begin', Alignment.topLeft)
            .having((gradient) => gradient.end, 'end', Alignment.bottomRight)
            .having((gradient) => gradient.colors, 'colors', const [
              Color(0x1fffffff),
              Color(0x0affffff),
            ]),
      );
      expect(exitShellDecoration().boxShadow, const [
        BoxShadow(
          color: Color(0x57000000),
          offset: Offset(0, 12),
          blurRadius: 28,
        ),
      ]);
      expect(exitShell().duration, const Duration(milliseconds: 140));
      expect(exitShell().curve, Curves.ease);
      expect(
        tester.widget<ExitFullscreenIcon>(
          find.byKey(const ValueKey('NowPlayingFull.ExitIcon')),
        ),
        isA<ExitFullscreenIcon>()
            .having((icon) => icon.shadows, 'shadows', const [
              Shadow(
                color: Color(0x57000000),
                offset: Offset(0, 2),
                blurRadius: 6,
              ),
            ])
            .having((icon) => icon.strokeWidth, 'strokeWidth', 2)
            .having((icon) => icon.size, 'size', 36),
      );

      final exitHover = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await exitHover.addPointer();
      await tester.pump();
      await exitHover.moveTo(
        tester.getCenter(
          find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
        ),
      );
      await tester.pumpAndSettle();

      expect(exitOverlayDecoration().color, const Color(0x6b080c12));
      expect(exitShellDecoration().color, const Color(0x24ffffff));
      expect(exitShellDecoration().border?.top.color, const Color(0x2effffff));
      expect(exitShellDecoration().gradient, isNull);
      expect(exitShellDecoration().boxShadow, const [
        BoxShadow(
          color: Color(0x4d000000),
          offset: Offset(0, 12),
          blurRadius: 30,
        ),
      ]);
      await exitHover.removePointer();
    },
  );

  testWidgets(
    'NowPlayingFullPage keeps wide layout with compact menu at 780px',
    (tester) async {
      tester.view.physicalSize = const Size(780, 760);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
      );
      mediaController.syncPlaybackProgress(12, durationSeconds: 120);

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      final wideTitle = tester
          .widgetList<Text>(find.text('Blue Song'))
          .singleWhere((widget) => widget.style?.fontSize == 24.8);
      expect(wideTitle.style?.height, 1.16);
      expect(
        find.byKey(const ValueKey('NowPlayingFull.BackIcon')),
        findsNothing,
      );
      expect(
        tester
            .widget<Icon>(
              find.byKey(const ValueKey('NowPlayingFull.QueueIcon')),
            )
            .size,
        18,
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        ),
        const Size(36, 36),
      );
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeRow')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeButton')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.FavoriteButton')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.ShuffleButton')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.RepeatButton')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.RepeatOneButton')),
        findsNothing,
      );
      final compactModeRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      );
      final moreRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.MoreButton')),
      );
      expect(compactModeRect.left, 685);
      expect(moreRect.left - compactModeRect.right, 6);
      expect(moreRect.right, 763);
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
            )
            .top,
        651,
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('MediaControl.PlayPauseButton')))
            .top,
        659,
      );
      final transportRowRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.TransportRow')),
      );
      final progressRowRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.ProgressRow')),
      );
      expect(transportRowRect.top, 657);
      expect(transportRowRect.height, 56);
      expect(transportRowRect.width, 568);
      expect(progressRowRect.top, 722);
      expect(progressRowRect.height, 28);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('MediaControl.MoreButton')))
            .top,
        667,
      );
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('MediaControl.ProgressElapsedColumn')),
            )
            .top,
        722,
      );
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('MediaControl.ProgressElapsedColumn')),
            )
            .left,
        25,
      );
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('MediaControl.ProgressElapsedColumn')),
            )
            .width,
        42,
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('MediaControl.ProgressSlider')))
            .left,
        75,
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('MediaControl.ProgressSlider')))
            .right,
        705,
      );
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('MediaControl.ProgressDurationColumn')),
            )
            .right,
        755,
      );
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('MediaControl.ProgressDurationColumn')),
            )
            .width,
        42,
      );
      final frameBorderDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
      );
      final frameBorder =
          (frameBorderDecoration.decoration as BoxDecoration).border! as Border;
      expect(frameBorder.top.color, const Color(0xb8ccd5e0));
      expect(frameBorder.right, BorderSide.none);
      expect(frameBorder.bottom, BorderSide.none);
      expect(frameBorder.left, BorderSide.none);
      final frameShadowDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameShadow')),
      );
      expect(
        (frameShadowDecoration.decoration as BoxDecoration).boxShadow,
        const [
          BoxShadow(
            color: Color(0x24445870),
            offset: Offset(0, -18),
            blurRadius: 56,
          ),
        ],
      );
      final frameBackgroundDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBackground')),
      );
      final frameBackground =
          frameBackgroundDecoration.decoration as BoxDecoration;
      expect(frameBackground.color, const Color(0xc7ffffff));
      final frameBackgroundGradient =
          frameBackground.gradient! as RadialGradient;
      expect(frameBackgroundGradient.center, const Alignment(-0.6, -0.56));
      expect(frameBackgroundGradient.radius, 0.42);
      expect(frameBackgroundGradient.colors, const [
        Color.fromRGBO(91, 135, 182, 0.24),
        Colors.transparent,
      ]);
      final frameInsetHighlight = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameInsetHighlight')),
      );
      expect(frameInsetHighlight.color, const Color(0xc7ffffff));
      final queueButtonFinder = find.ancestor(
        of: find.byKey(const ValueKey('NowPlayingFull.QueueLabel')),
        matching: find.byType(TextButton),
      );
      TextButton queueButton() => tester.widget<TextButton>(queueButtonFinder);
      final inactiveQueueShape =
          queueButton().style?.shape?.resolve(<WidgetState>{})
              as RoundedRectangleBorder?;
      expect(inactiveQueueShape?.side.color, const Color(0x337e8b9a));

      await tester.tap(queueButtonFinder);
      await tester.pump();
      expect(
        queueButton().style?.foregroundColor?.resolve(<WidgetState>{}),
        const Color(0xff0063b1),
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();

      await tester.drag(
        find.byKey(const ValueKey('NowPlayingFull.LyricsStage')),
        const Offset(0, -90),
      );
      await tester.pump();
      final lyricStageRect = tester.getRect(
        find.byKey(const ValueKey('NowPlayingFull.LyricsStage')),
      );
      final seekButtonRect = tester.getRect(
        find.byKey(const ValueKey('NowPlayingFull.LyricSeekButton')),
      );
      expect(
        seekButtonRect.center.dy,
        closeTo(lyricStageRect.top + lyricStageRect.height / 2, 1),
      );

      await tester.tap(find.byKey(const ValueKey('MediaControl.MoreButton')));
      await tester.pumpAndSettle();

      expect(find.text('Playback Mode: List'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeMenuItem')),
        findsOneWidget,
      );
      expect(find.text('Like'), findsOneWidget);
    },
  );

  testWidgets(
    'NowPlayingFullPage night compact footer follows Electron nav-minimal cascade',
    (tester) async {
      tester.view.physicalSize = const Size(780, 760);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.onMode),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
          themeSettings: const SettingsSnapshot.defaults().copyWith(
            nightMode: NightMode.onMode,
          ),
        ),
      );
      await tester.pump();

      final frameGlass = tester.widget<GlassContainer>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
              matching: find.byType(GlassContainer),
            )
            .first,
      );
      expect(frameGlass.settings?.blur, 28);
      expect(frameGlass.settings?.saturation, 1.45);

      final frameBorderDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
      );
      final frameBorder =
          (frameBorderDecoration.decoration as BoxDecoration).border! as Border;
      expect(frameBorder.top.color, const Color(0x1fd6e0ec));
      expect(frameBorder.right, BorderSide.none);
      expect(frameBorder.bottom, BorderSide.none);
      expect(frameBorder.left, BorderSide.none);

      final frameShadowDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameShadow')),
      );
      expect(
        (frameShadowDecoration.decoration as BoxDecoration).boxShadow,
        const [
          BoxShadow(
            color: Color(0x57000000),
            offset: Offset(0, -12),
            blurRadius: 36,
          ),
        ],
      );

      final frameBackgroundDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBackground')),
      );
      final frameBackground =
          frameBackgroundDecoration.decoration as BoxDecoration;
      expect(frameBackground.color, const Color(0xeb101419));

      final compactBaseGradientDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerCompactBaseGradient')),
      );
      final compactBaseGradient =
          (compactBaseGradientDecoration.decoration as BoxDecoration).gradient!
              as LinearGradient;
      expect(compactBaseGradient.begin, Alignment.topCenter);
      expect(compactBaseGradient.end, Alignment.bottomCenter);
      expect(compactBaseGradient.colors, const [
        Color(0xe01d232b),
        Color(0xe0101419),
      ]);

      final compactCoverGradientDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerCompactCoverGradient')),
      );
      final compactCoverGradient =
          (compactCoverGradientDecoration.decoration as BoxDecoration).gradient!
              as LinearGradient;
      expect(compactCoverGradient.begin, Alignment.topLeft);
      expect(compactCoverGradient.end, Alignment.bottomRight);
      expect(compactCoverGradient.colors, const [
        Color.fromRGBO(91, 135, 182, 0.2),
        Color(0xc711161c),
      ]);
      expect(compactCoverGradient.stops, const [0, 0.56]);

      final frameInsetHighlight = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameInsetHighlight')),
      );
      expect(frameInsetHighlight.color, const Color(0x0cffffff));
    },
  );

  testWidgets('NowPlayingFullPage favorite button updates current song', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Like'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.snapshot.songs.single.favorite, isTrue);
    expect(mediaController.state.track.favorite, isTrue);
  });

  testWidgets('NowPlayingFullPage more menu opens before preference refresh', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _DelayedPreferenceRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('More'));
    await tester.pump();

    expect(repository.preferenceRequested, isTrue);
    expect(find.text('Quick Play'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Preference Settings'), findsOneWidget);
    expect(find.text('Undo Preference'), findsNothing);

    repository.completePreference('high');
    await tester.pumpAndSettle();

    expect(find.text('Quick Play'), findsOneWidget);
    await tester.tap(find.text('Preference Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Undo Preference'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(of: find.text('High'), matching: find.byType(Row)),
        matching: find.byIcon(FluentIcons.checkmark_20_regular),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'NowPlayingFullPage wide More matches Electron queue and current song items',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();

      expect(find.text('Quick Play'), findsOneWidget);
      expect(find.text('Shuffle'), findsWidgets);
      final shuffleEnabled = tester
          .widgetList<Semantics>(
            find.ancestor(
              of: find.text('Shuffle'),
              matching: find.byType(Semantics),
            ),
          )
          .any((semantics) => semantics.properties.enabled == true);
      expect(shuffleEnabled, isTrue);
      expect(find.text('Save Playlist'), findsOneWidget);
      expect(find.text('Clear Now Playing'), findsOneWidget);
      expect(find.text('Add To'), findsOneWidget);
      expect(find.text('Play Artist'), findsOneWidget);
      expect(find.text('Play Album'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Full Screen'), findsNothing);
      expect(find.text('Exit Full Screen'), findsNothing);
      expect(find.text('Mini Mode'), findsNothing);
      expect(find.text('Playback Mode: List'), findsNothing);
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeMenuItem')),
        findsNothing,
      );

      await tester.tap(find.text('Shuffle'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
        findsNWidgets(2),
      );
      expect(find.text('Quick Play'), findsNWidgets(2));
      expect(find.text('Shuffle'), findsWidgets);
      expect(find.text('Now Playing'), findsWidgets);
      expect(find.text('Music Library'), findsOneWidget);
      expect(find.text('Artist'), findsOneWidget);
      expect(find.text('Album'), findsOneWidget);
      expect(find.text('Save Playlist'), findsOneWidget);
      expect(find.text('Clear Now Playing'), findsOneWidget);

      await tester.tap(find.text('Add To'));
      await tester.pumpAndSettle();

      expect(find.text('My Favorites'), findsOneWidget);
      expect(find.text('New Playlist'), findsOneWidget);
      expect(find.text('Mix'), findsOneWidget);
      expect(find.text('Built in'), findsNothing);
    },
  );

  testWidgets('NowPlayingFullPage More Play Artist and Album replace queue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final songs = [
      ..._snapshot.songs,
      const LibrarySong(
        id: 2,
        path: r'C:\Music\green.mp3',
        title: 'Green Song',
        artist: 'Artist A',
        artists: ['Artist A'],
        album: 'Green Hour',
        duration: 130,
        playCount: 0,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-21T00:00:00',
        favorite: false,
        thumbnailPath: '',
      ),
      const LibrarySong(
        id: 3,
        path: r'C:\Music\duo.mp3',
        title: 'Duo Song',
        artist: 'Artist B',
        artists: ['Artist B', 'Artist A'],
        album: 'Blue Hour',
        duration: 140,
        playCount: 0,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-22T00:00:00',
        favorite: false,
        thumbnailPath: '',
      ),
      const LibrarySong(
        id: 4,
        path: r'C:\Music\gold.mp3',
        title: 'Gold Song',
        artist: 'Artist C',
        artists: ['Artist C'],
        album: 'Blue Hour',
        duration: 150,
        playCount: 0,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-23T00:00:00',
        favorite: false,
        thumbnailPath: '',
      ),
    ];
    final snapshot = _snapshotWithSongs(
      _snapshot,
      songs,
      nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: [1]),
    );
    final repository = _FakeNowPlayingRepository(snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play Artist'));
    await tester.pumpAndSettle();

    expect(repository.snapshot.nowPlaying.songIds, unorderedEquals([1, 2, 3]));
    expect(mediaController.state.selectedQueueIndex, 0);
    expect(mediaController.state.track.id, isIn([1, 2, 3]));
    expect(
      repository.snapshot.nowPlaying.songIds.first,
      mediaController.state.track.id,
    );

    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );
    await tester.pump();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play Album'));
    await tester.pumpAndSettle();

    expect(repository.snapshot.nowPlaying.songIds, unorderedEquals([1, 3, 4]));
    expect(mediaController.state.selectedQueueIndex, 0);
    expect(mediaController.state.track.id, isIn([1, 3, 4]));
    expect(
      repository.snapshot.nowPlaying.songIds.first,
      mediaController.state.track.id,
    );
  });

  testWidgets(
    'NowPlayingFullPage Add To Now Playing undo removes inserted range',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final snapshot = _snapshotWithSongs(
        _snapshot,
        [
          ..._snapshot.songs,
          const LibrarySong(
            id: 2,
            path: r'C:\Music\red.mp3',
            title: 'Red Song',
            artist: 'Artist B',
            artists: ['Artist B'],
            album: 'Red Hour',
            duration: 130,
            playCount: 0,
            lyricsOffsetMs: 0,
            dateAdded: '2026-05-21T00:00:00',
            favorite: false,
            thumbnailPath: '',
          ),
        ],
        nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: [1, 2, 1]),
      );
      final repository = _FakeNowPlayingRepository(snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add To'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Now Playing').last);
      await tester.pumpAndSettle();

      expect(repository.snapshot.nowPlaying.songIds, [1, 2, 1, 1]);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(repository.snapshot.nowPlaying.songIds, [1, 2, 1]);
    },
  );

  testWidgets(
    'NowPlayingFullPage More disables Random Play when queue and library are empty',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
      });
      final emptySnapshot = _snapshotWithSongs(
        _snapshot,
        const [],
        nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: emptySnapshot,
          i18n: i18n,
          repository: _FakeNowPlayingRepository(emptySnapshot),
          mediaController: MediaControlController(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();

      final shuffleText = tester.widget<Text>(find.text('Shuffle'));
      expect(shuffleText.style?.color, const Color(0x751f252b));
      final shuffleDisabled = tester
          .widgetList<Semantics>(
            find.ancestor(
              of: find.text('Shuffle'),
              matching: find.byType(Semantics),
            ),
          )
          .any((semantics) => semantics.properties.enabled == false);
      expect(shuffleDisabled, isTrue);
      expect(
        find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
        findsOneWidget,
      );

      await tester.tap(find.text('Shuffle'));
      await tester.pumpAndSettle();

      expect(find.text('Quick Play'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'NowPlayingFullPage compact More includes Electron utility substitutes',
    (tester) async {
      tester.view.physicalSize = const Size(500, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      final frameRectBefore = tester.getRect(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
      );
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();

      final moreMenuRect = tester.getRect(
        find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
      );
      expect(moreMenuRect.right, 492);
      expect(moreMenuRect.bottom, 752);
      expect(
        tester.getRect(
          find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
        ),
        frameRectBefore,
      );
      expect(find.text('Playback Mode: List'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeMenuItem')),
        findsOneWidget,
      );
      expect(find.text('Like'), findsOneWidget);
      expect(find.text('Add To'), findsOneWidget);
      expect(find.text('Save Playlist'), findsOneWidget);
      expect(find.text('Clear Now Playing'), findsOneWidget);

      SmPlayerVolumeIconKind volumeMenuIcon() {
        return tester
            .widget<SmPlayerVolumeIcon>(
              find.descendant(
                of: find.byKey(const ValueKey('MediaControl.VolumeMenuItem')),
                matching: find.byType(SmPlayerVolumeIcon),
              ),
            )
            .kind;
      }

      expect(volumeMenuIcon(), SmPlayerVolumeIconKind.medium);
      final volumeMenuSlider = tester.widget<Slider>(
        find.descendant(
          of: find.byKey(const ValueKey('MediaControl.VolumeMenuItem')),
          matching: find.byType(Slider),
        ),
      );
      volumeMenuSlider.onChanged!(20);
      await tester.pump();

      expect(volumeMenuIcon(), SmPlayerVolumeIconKind.low);

      final shuffleEnabled = tester
          .widgetList<Semantics>(
            find.ancestor(
              of: find.text('Shuffle'),
              matching: find.byType(Semantics),
            ),
          )
          .any((semantics) => semantics.properties.enabled == true);
      expect(shuffleEnabled, isTrue);

      await tester.tap(find.text('Shuffle'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
        findsNWidgets(2),
      );
      expect(find.text('Playback Mode: List'), findsOneWidget);
      expect(find.text('Quick Play'), findsNWidgets(2));
      expect(find.text('Now Playing'), findsWidgets);
      expect(find.text('Music Library'), findsOneWidget);
      expect(find.text('Artist'), findsOneWidget);
      expect(find.text('Album'), findsOneWidget);

      await tester.tapAt(const Offset(40, 40));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Playback Mode: List'));
      await tester.pumpAndSettle();

      bool checkedFor(String text) {
        return tester
            .widgetList<Semantics>(
              find.ancestor(
                of: find.text(text),
                matching: find.byType(Semantics),
              ),
            )
            .any((semantics) => semantics.properties.checked ?? false);
      }

      expect(checkedFor('List'), isTrue);
      expect(checkedFor('Shuffle'), isFalse);
      expect(checkedFor('Repeat'), isFalse);
      expect(checkedFor('Repeat One'), isFalse);

      await tester.tap(find.text('Add To'));
      await tester.pumpAndSettle();

      expect(find.text('My Favorites'), findsNothing);
      expect(find.text('New Playlist'), findsOneWidget);
      expect(find.text('Mix'), findsOneWidget);
      expect(find.text('Built in'), findsNothing);
    },
  );

  testWidgets(
    'NowPlayingFullPage compact mode context menu opens like Electron',
    (tester) async {
      tester.view.physicalSize = const Size(500, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();

      final modeButtonRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      );
      final modeMenuRect = tester.getRect(
        find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
      );
      expect(modeButtonRect.top - modeMenuRect.bottom, 8);
      expect(mediaController.state.mode, PlaybackMode.once);
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.text('Repeat'), findsOneWidget);
      expect(find.text('Repeat One'), findsOneWidget);
    },
  );

  testWidgets('NowPlayingFullPage compact mode cycles in Electron order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    Future<void> tapCompactMode() async {
      await tester.tap(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      );
      await tester.pump();
    }

    expect(mediaController.state.mode, PlaybackMode.once);
    await tapCompactMode();
    expect(mediaController.state.mode, PlaybackMode.shuffle);
    await tapCompactMode();
    expect(mediaController.state.mode, PlaybackMode.repeat);
    await tapCompactMode();
    expect(mediaController.state.mode, PlaybackMode.repeatOne);
    await tapCompactMode();
    expect(mediaController.state.mode, PlaybackMode.once);
  });

  testWidgets(
    'NowPlayingFullPage compact mode menu checks current Electron item',
    (tester) async {
      tester.view.physicalSize = const Size(500, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
      );
      await tester.pump();
      expect(mediaController.state.mode, PlaybackMode.repeat);

      await tester.tap(
        find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();

      bool checkedFor(String text) {
        return tester
            .widgetList<Semantics>(
              find.ancestor(
                of: find.text(text),
                matching: find.byType(Semantics),
              ),
            )
            .any((semantics) => semantics.properties.checked ?? false);
      }

      expect(checkedFor('List'), isFalse);
      expect(checkedFor('Shuffle'), isFalse);
      expect(checkedFor('Repeat'), isTrue);
      expect(checkedFor('Repeat One'), isFalse);
      expect(find.byIcon(FluentIcons.checkmark_20_regular), findsOneWidget);
    },
  );

  testWidgets(
    'NowPlayingFullPage compact mode long press opens Electron menu',
    (tester) async {
      tester.view.physicalSize = const Size(500, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      final modeButton = find.byKey(
        const ValueKey('MediaControl.CompactModeButton'),
      );
      final modeTooltip = find.byTooltip('Playback Mode: List').last;
      final modeHoldAction = tester.widget<HoldReleaseAction>(
        find.ancestor(
          of: modeTooltip,
          matching: find.byType(HoldReleaseAction),
        ),
      );
      expect(modeHoldAction.holdDuration, const Duration(milliseconds: 520));
      expect(modeHoldAction.triggerHoldOnReady, isTrue);

      final modeHold = await tester.startGesture(
        tester.getCenter(modeButton),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Shuffle'), findsNothing);
      expect(mediaController.state.mode, PlaybackMode.once);
      await tester.pump(const Duration(milliseconds: 120));
      await modeHold.up();
      await tester.pumpAndSettle();

      expect(mediaController.state.mode, PlaybackMode.once);
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.text('Repeat'), findsOneWidget);
      expect(find.text('Repeat One'), findsOneWidget);
    },
  );

  testWidgets(
    'NowPlayingFullPage compact More disables Favorite without current song',
    (tester) async {
      tester.view.physicalSize = const Size(500, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: MediaControlController(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();

      expect(find.text('Quick Play'), findsOneWidget);
      expect(find.text('Playback Mode: List'), findsOneWidget);
      expect(find.text('Like'), findsOneWidget);
      expect(find.text('Add To'), findsNothing);

      final likeDisabled = tester
          .widgetList<Semantics>(
            find.ancestor(
              of: find.text('Like'),
              matching: find.byType(Semantics),
            ),
          )
          .any((semantics) => semantics.properties.enabled == false);
      expect(likeDisabled, isTrue);

      await tester.tap(find.text('Like'));
      await tester.pumpAndSettle();

      expect(repository.favoriteSongIds, isEmpty);
    },
  );

  testWidgets(
    'NowPlayingFullPage Clear Now Playing exits fullscreen and clears queue',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      var exitCalls = 0;
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
          useRouter: true,
          shellActions: SmPlayerShellActions(
            onOpenVoiceAssistant: () {},
            onExitWindowFullScreen: () async {
              exitCalls += 1;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear Now Playing'));
      await tester.pump();

      expect(exitCalls, 1);
      expect(repository.snapshot.nowPlaying.songIds, isEmpty);
    },
  );

  testWidgets('NowPlayingFullPage exit button follows Electron close action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    var exitCalls = 0;
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
        useRouter: true,
        shellActions: SmPlayerShellActions(
          onOpenVoiceAssistant: () {},
          onExitWindowFullScreen: () async {
            exitCalls += 1;
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Exit immersive mode'), findsOneWidget);
    expect(find.byTooltip('Blue Song'), findsNothing);

    await tester.tap(find.byTooltip('Exit immersive mode'));
    await tester.pumpAndSettle();

    expect(exitCalls, 1);
    expect(find.byType(NowPlayingFullPage), findsNothing);
    expect(find.byTooltip('Exit immersive mode'), findsNothing);
  });

  testWidgets(
    'NowPlayingFullPage queue context menu opens before preference refresh',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _DelayedPreferenceRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        autoplay: false,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Now Playing').first);
      await tester.pump(const Duration(milliseconds: 300));
      final queueTitle = find.descendant(
        of: find.byType(PlaylistControlItem),
        matching: find.text('Blue Song'),
      );

      await tester.tap(queueTitle.first, buttons: kSecondaryMouseButton);
      await tester.pump();

      expect(repository.preferenceRequested, isTrue);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Add To'), findsOneWidget);

      repository.completePreference(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'NowPlayingFullPage queue context Add To keeps Now Playing playlist target',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final snapshot = _snapshotWithPlaylists(_snapshot, [
        _snapshot.playlists.first,
        const LibraryPlaylist(
          id: 10,
          name: 'Now Playing',
          priority: 1,
          songCount: 0,
          songIds: [],
          sortCriterion: PlaylistSortCriterion.title,
          isBuiltIn: false,
        ),
      ]);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        autoplay: false,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: snapshot,
          i18n: i18n,
          repository: _FakeNowPlayingRepository(snapshot),
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Now Playing').first);
      await tester.pump(const Duration(milliseconds: 300));
      final nowPlayingTextCountBeforeMenu =
          find.text('Now Playing').evaluate().length;
      final queueTitle = find.descendant(
        of: find.byType(PlaylistControlItem),
        matching: find.text('Blue Song'),
      );

      await tester.tap(queueTitle.first, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add To'));
      await tester.pumpAndSettle();

      expect(
        find.text('Now Playing').evaluate().length,
        nowPlayingTextCountBeforeMenu + 1,
      );
    },
  );

  testWidgets('NowPlayingFullPage more view dialog pins player bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
      autoplay: false,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeNowPlayingRepository(_snapshot),
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(find.text('See Music Info'), findsOneWidget);
    expect(find.text('See Lyrics'), findsOneWidget);
    expect(find.text('See Album Art'), findsOneWidget);
    expect(find.text('See Artist'), findsNothing);
    expect(find.text('See Album'), findsNothing);
    expect(find.text('See Local File'), findsNothing);

    await tester.tap(find.text('See Lyrics'));
    await tester.pump();

    expect(find.byType(MusicDialog), findsOneWidget);
    final dialog = tester.widget<MusicDialog>(find.byType(MusicDialog));
    expect(dialog.currentTrackId, 1);
    expect(dialog.isPlaying, isFalse);
    expect(dialog.queueSongIds, [1]);
    expect(find.text('View'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    expect(_hasPlayerBarOpacity(tester, 1), isTrue);

    await tester.tap(find.byKey(const ValueKey('popup-dialog-close-button')));
    await tester.pumpAndSettle();
    expect(find.byType(MusicDialog), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 260));

    expect(_hasPlayerBarOpacity(tester, 0.24), isTrue);
  });

  testWidgets('NowPlayingFullPage queue view opens dialog and closes panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
      autoplay: false,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Now Playing').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1 songs'), findsOneWidget);
    final queueTitle = find.descendant(
      of: find.byType(PlaylistControlItem),
      matching: find.text('Blue Song'),
    );

    await tester.tap(queueTitle.first, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See Lyrics'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.byType(MusicDialog), findsOneWidget);
    expect(find.text('1 songs'), findsNothing);
    expect(find.text('View'), findsNothing);
  });

  testWidgets('NowPlayingFullPage multi-select play preserves queue order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeNowPlayingRepository(_searchSnapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
      autoplay: false,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _searchSnapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Now Playing').first);
    await tester.pump(const Duration(milliseconds: 300));
    final blueRow = find.descendant(
      of: find.byType(PlaylistControlItem),
      matching: find.text('Blue Song'),
    );
    final redRow = find.descendant(
      of: find.byType(PlaylistControlItem),
      matching: find.text('Red Song'),
    );

    await tester.tap(blueRow.first, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(redRow.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play Selected'));
    await tester.pumpAndSettle();

    expect(repository.snapshot.nowPlaying.songIds, [1, 2]);
    expect(mediaController.state.track.id, 1);
    expect(mediaController.state.selectedQueueIndex, 0);
  });

  testWidgets('NowPlayingFullPage context Select resets selection to row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      PageSelectionController.clearStoredStates();
    });
    final repository = _FakeNowPlayingRepository(_searchSnapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
      autoplay: false,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _searchSnapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Now Playing').first);
    await tester.pump(const Duration(milliseconds: 300));
    final blueRow = find.descendant(
      of: find.byType(PlaylistControlItem),
      matching: find.text('Blue Song'),
    );
    final redRow = find.descendant(
      of: find.byType(PlaylistControlItem),
      matching: find.text('Red Song'),
    );

    await tester.tap(blueRow.first, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(redRow.first);
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(blueRow.first, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('2 selected'), findsNothing);
  });

  testWidgets('NowPlayingFullPage current queue row tap keeps playing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeNowPlayingRepository(_searchSnapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _searchSnapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Now Playing').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.descendant(
        of: find.byType(PlaylistControlItem),
        matching: find.text('Blue Song'),
      ),
    );
    await tester.pump();

    expect(mediaController.state.track.id, 1);
    expect(mediaController.state.selectedQueueIndex, 0);
    expect(mediaController.state.isPlaying, isTrue);
  });

  testWidgets('NowPlayingFullPage multi-select remove clears selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      PageSelectionController.clearStoredStates();
    });
    final snapshot = _snapshotWithHideAfterOperation(_searchSnapshot, false);
    final repository = _FakeNowPlayingRepository(snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
      autoplay: false,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Now Playing').first);
    await tester.pump(const Duration(milliseconds: 300));
    final blueRow = find.descendant(
      of: find.byType(PlaylistControlItem),
      matching: find.text('Blue Song'),
    );

    await tester.tap(blueRow.first, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.ensureVisible(find.text('Remove').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();

    expect(repository.snapshot.nowPlaying.songIds, [2]);
    expect(
      find.descendant(
        of: find.byType(PlaylistControlItem),
        matching: find.text('Red Song'),
      ),
      findsOneWidget,
    );
    expect(find.text('1 selected'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets(
    'NowPlayingFullPage multi-select favorites respects hide preference',
    (tester) async {
      tester.view.physicalSize = const Size(2200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        PageSelectionController.clearStoredStates();
      });
      final snapshot = _snapshotWithHideAfterOperation(_searchSnapshot, false);
      final repository = _FakeNowPlayingRepository(snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        autoplay: false,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Now Playing').first);
      await tester.pump(const Duration(milliseconds: 300));
      final blueRow = find.descendant(
        of: find.byType(PlaylistControlItem),
        matching: find.text('Blue Song'),
      );

      await tester.tap(blueRow.first, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.ensureVisible(find.text('Add To').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add To').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Favorites'));
      await tester.pumpAndSettle();

      expect(repository.favoriteSongIds, [1]);
      expect(find.text('1 selected'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'NowPlayingFullPage queue panel does not raise or pin player bar',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Now Playing').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 300));

      RenderBox positionedLayerOf(Finder finder) {
        return tester.renderObject<RenderBox>(
          find.ancestor(of: finder, matching: find.byType(Positioned)).first,
        );
      }

      int stackPaintIndex(RenderStack stack, RenderBox target) {
        var index = 0;
        RenderBox? child = stack.firstChild;
        while (child != null) {
          if (identical(child, target)) {
            return index;
          }
          final parentData = child.parentData! as StackParentData;
          child = parentData.nextSibling;
          index += 1;
        }
        return -1;
      }

      final queueLayer = positionedLayerOf(
        find.byKey(const ValueKey('NowPlayingFull.QueuePopoverHost')),
      );
      final playerBarLayer = positionedLayerOf(
        find.byKey(const ValueKey('NowPlayingFull.PlayerBarOpacity')),
      );
      expect(queueLayer.parent, same(playerBarLayer.parent));
      final stack = queueLayer.parent! as RenderStack;
      expect(
        stackPaintIndex(stack, playerBarLayer),
        greaterThan(stackPaintIndex(stack, queueLayer)),
      );
      expect(_hasPlayerBarOpacity(tester, 0.24), isTrue);
      final playerBarOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('NowPlayingFull.PlayerBarOpacity')),
      );
      expect(playerBarOpacity.duration, const Duration(milliseconds: 180));
      expect(playerBarOpacity.curve, Curves.ease);
      final playerBarSlide = tester.widget<AnimatedSlide>(
        find.byKey(const ValueKey('NowPlayingFull.PlayerBarSlide')),
      );
      expect(playerBarSlide.duration, const Duration(milliseconds: 260));
      expect(playerBarSlide.curve, const Cubic(0.2, 0, 0, 1));
      expect(playerBarSlide.offset, const Offset(0, 110 / 120));
      final idleFrameRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
      );
      expect(idleFrameRect.top, 890);
      expect(idleFrameRect.bottom, 1010);
    },
  );

  testWidgets(
    'NowPlayingFullPage compact queue follows Electron z-index above footer',
    (tester) async {
      tester.view.physicalSize = const Size(780, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Now Playing').first);
      await tester.pump(const Duration(milliseconds: 300));

      RenderBox positionedLayerOf(Finder finder) {
        return tester.renderObject<RenderBox>(
          find.ancestor(of: finder, matching: find.byType(Positioned)).first,
        );
      }

      int stackPaintIndex(RenderStack stack, RenderBox target) {
        var index = 0;
        RenderBox? child = stack.firstChild;
        while (child != null) {
          if (identical(child, target)) {
            return index;
          }
          final parentData = child.parentData! as StackParentData;
          child = parentData.nextSibling;
          index += 1;
        }
        return -1;
      }

      final queueLayer = positionedLayerOf(
        find.byKey(const ValueKey('NowPlayingFull.QueuePopoverHost')),
      );
      final playerBarLayer = positionedLayerOf(
        find.byKey(const ValueKey('NowPlayingFull.PlayerBarOpacity')),
      );
      expect(queueLayer.parent, same(playerBarLayer.parent));
      final stack = queueLayer.parent! as RenderStack;
      expect(
        stackPaintIndex(stack, queueLayer),
        greaterThan(stackPaintIndex(stack, playerBarLayer)),
      );
    },
  );

  testWidgets('NowPlayingFullPage More pins player bar while menu is open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
      autoplay: false,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeNowPlayingRepository(_snapshot),
        mediaController: mediaController,
      ),
    );
    await tester.pump();
    expect(_hasPlayerBarOpacity(tester, 1), isTrue);

    final moreButtonRect = tester.getRect(
      find.byKey(const ValueKey('MediaControl.MoreButton')),
    );
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));

    expect(find.text('Quick Play'), findsOneWidget);
    final moreMenuRect = tester.getRect(
      find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
    );
    expect(moreMenuRect.top, lessThan(moreButtonRect.top));
    expect(moreMenuRect.bottom, 892);
    expect(moreMenuRect.right, 1392);
    expect(_hasPlayerBarOpacity(tester, 1), isTrue);

    await tester.tapAt(const Offset(40, 40));
    await tester.pumpAndSettle();
    expect(find.text('Quick Play'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 260));

    expect(_hasPlayerBarOpacity(tester, 0.24), isTrue);
  });

  testWidgets(
    'NowPlayingFullPage keeps player bar raised while pointer stays',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 0,
        autoplay: false,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: _FakeNowPlayingRepository(_snapshot),
          mediaController: mediaController,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 260));
      expect(_hasPlayerBarOpacity(tester, 0.24), isTrue);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(-10, -10));
      await tester.pump();
      await gesture.moveTo(const Offset(100, 100));
      await tester.pump();
      await gesture.moveTo(const Offset(120, 120));
      await tester.pump();
      expect(_hasPlayerBarOpacity(tester, 1), isTrue);

      await tester.pump(const Duration(seconds: 6));
      expect(_hasPlayerBarOpacity(tester, 1), isTrue);

      await gesture.removePointer();
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'NowPlayingFullPage empty queue panel omits header like Electron',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final snapshot = _snapshotWithSongs(
        _snapshot,
        _snapshot.songs,
        nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
      );
      final repository = _FakeNowPlayingRepository(snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: null,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Now Playing').first);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('0 songs'), findsNothing);
      expect(find.byTooltip('Close'), findsNothing);
    },
  );

  testWidgets('NowPlayingFullPage empty loading queue shows compact loading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final snapshot = _snapshotWithSongs(
      _snapshot,
      _snapshot.songs,
      nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: []),
    );
    final repository = _FakeNowPlayingRepository(snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: true,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: null,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Now Playing').first);
    await tester.pump(const Duration(milliseconds: 300));

    final loading = tester.widget<SmPlayerLoadingState>(
      find.byType(SmPlayerLoadingState),
    );
    expect(loading.compact, isTrue);
  });

  testWidgets('NowPlayingFullPage queue rows reuse default artwork fallback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Now Playing').first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.descendant(
        of: find.byType(PlaylistControlItem),
        matching: find.byType(DefaultAlbumArtwork),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('PlaylistControlItem.PlayingOverlay')),
      findsOneWidget,
    );
  });

  testWidgets(
    'NowPlayingFullPage displays current track instead of selected queue index',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeNowPlayingRepository(_searchSnapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 120,
        queueIndex: 1,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: _searchSnapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      final displayTitle = tester
          .widgetList<Text>(find.text('Blue Song'))
          .singleWhere(
            (widget) => widget.style?.fontWeight == const FontWeight(760),
          );
      expect(displayTitle.style?.height, 1.16);
      expect(
        tester
            .widgetList<Text>(find.text('Red Song'))
            .where(
              (widget) => widget.style?.fontWeight == const FontWeight(760),
            ),
        isEmpty,
      );
    },
  );

  testWidgets('NowPlayingFullPage falls back to playback track like Electron', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 99,
        title: 'Loose Track',
        artist: 'Loose Artist',
        artworkUrl: '',
        isLoading: false,
        favorite: true,
      ),
      durationSeconds: 245,
      queueIndex: null,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    final displayTitle = tester
        .widgetList<Text>(find.text('Loose Track'))
        .singleWhere(
          (widget) => widget.style?.fontWeight == const FontWeight(760),
        );
    expect(displayTitle.style?.height, 1.16);
    expect(find.text('Loose Artist'), findsWidgets);
    expect(find.text('No active track'), findsNothing);
  });

  testWidgets('NowPlayingFullPage opens queue centered on current row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final songs = List.generate(
      40,
      (index) => LibrarySong(
        id: index + 1,
        path: r'C:\Music\song.mp3',
        title: 'Queue Song ${index + 1}',
        artist: 'Artist',
        artists: const ['Artist'],
        album: 'Album',
        duration: 120,
        playCount: 0,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-20T00:00:00',
        favorite: false,
        thumbnailPath: '',
      ),
    );
    final snapshot = _snapshotWithSongs(
      _snapshot,
      songs,
      nowPlaying: NowPlayingSnapshot(
        playlistId: 0,
        songIds: songs.map((song) => song.id).toList(),
      ),
    );
    final repository = _FakeNowPlayingRepository(snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 31,
        title: 'Queue Song 31',
        artist: 'Artist',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 30,
    );

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Now Playing').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final queueLists = tester.widgetList<ListView>(
      find.byKey(const ValueKey('NowPlayingFull.QueueList')),
    );
    expect(
      queueLists.any((list) => (list.controller?.offset ?? 0) > 1500),
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('now-playing-full-row-31-30')),
      findsOneWidget,
    );
  });

  test('NowPlayingFullPage reorders queue downward like Electron', () {
    expect(reorderNowPlayingFullQueueSongIds(const [1, 2, 3], 0, 2), [2, 1, 3]);
    expect(reorderNowPlayingFullQueueSongIds(const [1, 2, 3], 2, 0), [3, 1, 2]);
    expect(moveNowPlayingFullQueueSongIds(const [1, 2, 3, 4], 0, 2, true), [
      2,
      3,
      1,
      4,
    ]);
    expect(moveNowPlayingFullQueueSongIds(const [1, 2, 3, 4], 3, 1, false), [
      1,
      4,
      2,
      3,
    ]);
  });

  test('NowPlayingFullPage play next queue matches Electron helper', () {
    expect(playNextNowPlayingFullQueueSongIds(const [1, 2, 3], 9, 2, -1, 1), [
      1,
      2,
      9,
      3,
    ]);
    expect(playNextNowPlayingFullQueueSongIds(const [1, 2, 3, 4], 2, 4, 1, 3), [
      1,
      3,
      4,
      2,
    ]);
    expect(playNextNowPlayingFullQueueSongIds(const [1, 2, 3, 4], 4, 2, 3, 1), [
      1,
      2,
      4,
      3,
    ]);
    expect(
      playNextNowPlayingFullQueueSongIds(const [1, 2, 3, 4], 1, 3, 0, null),
      [2, 3, 1, 4],
    );
    expect(playNextNowPlayingFullQueueSongIds(const [1, 2, 3], 2, 2, 1, 1), [
      1,
      3,
      2,
    ]);
  });

  test('NowPlayingFullPage lyric seek time matches Electron formatter', () {
    expect(formatNowPlayingFullLyricSeekTime(65), '1:05');
    expect(formatNowPlayingFullLyricSeekTime(3661), '1:01:01');
  });

  testWidgets('NowPlayingFullPage scrolls to active lyric after loading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _LongLyricsRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );
    mediaController.syncPlaybackProgress(72, durationSeconds: 120);

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final lyricsList = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('NowPlayingFull.LyricsList')),
    );
    expect(find.text('Lyric line 8'), findsOneWidget);
    expect(lyricsList.controller?.offset, greaterThan(180));
  });

  testWidgets(
    'NowPlayingFullPage plain lyrics stay on first line without duration',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final zeroDurationSong = LibrarySong(
        id: 1,
        path: r'C:\Music\blue.mp3',
        title: 'Blue Song',
        artist: 'Artist A',
        artists: const ['Artist A'],
        album: 'Blue Hour',
        duration: 0,
        playCount: 0,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-20T00:00:00',
        favorite: false,
        thumbnailPath: '',
      );
      final snapshot = _snapshotWithSongs(_snapshot, [
        zeroDurationSong,
      ], nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: [1]));
      final repository = _PlainLyricsRepository(snapshot);
      final mediaController = MediaControlController();
      mediaController.playTrack(
        const MediaControlTrack(
          id: 1,
          title: 'Blue Song',
          artist: 'Artist A',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 0,
        queueIndex: 0,
        progressSeconds: 10,
      );

      await tester.pumpWidget(
        _NowPlayingFullTestApp(
          snapshot: snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      TextStyle lyricStyle(String text) {
        return tester
            .widget<AnimatedDefaultTextStyle>(
              find
                  .ancestor(
                    of: find.text(text),
                    matching: find.byType(AnimatedDefaultTextStyle),
                  )
                  .first,
            )
            .style;
      }

      expect(lyricStyle('First plain lyric').fontSize, 26.56);
      expect(lyricStyle('Third plain lyric').fontSize, 19.84);
    },
  );

  testWidgets('NowPlayingFullPage lyric rows do not seek on tap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
    );
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      resetSmPlayerGlobalSettingsSnapshot();
    });
    final repository = _FakeNowPlayingRepository(_snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Blue Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );
    mediaController.syncPlaybackProgress(12, durationSeconds: 120);

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.drag(find.text('Current lyric'), const Offset(0, -90));
    await tester.pump();

    final seekButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('NowPlayingFull.LyricSeekButton')),
    );
    expect(
      seekButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      const Color(0xff0063b1),
    );
    expect(
      seekButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xb8ffffff),
    );
    final seekButtonShape =
        seekButton.style?.shape?.resolve(<WidgetState>{})
            as RoundedRectangleBorder?;
    expect(seekButtonShape?.side.color, const Color(0x337e8b9a));

    await tester.tap(find.text('Opening lyric'));
    await tester.pump();

    expect(mediaController.state.progressSeconds, 12);
  });
}

class _NowPlayingTestApp extends StatelessWidget {
  const _NowPlayingTestApp({
    required this.snapshot,
    required this.i18n,
    this.repository,
    this.searchQuery = '',
  });

  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final _FakeNowPlayingRepository? repository;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        if (repository == null)
          libraryContentDataProvider.overrideWith((ref) async => snapshot)
        else
          libraryRepositoryProvider.overrideWithValue(repository!),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: buildSmPlayerTheme(const SettingsSnapshot.defaults()),
          home: Scaffold(body: NowPlayingPage(searchQuery: searchQuery)),
        ),
      ),
    );
  }
}

class _NowPlayingFullTestApp extends StatelessWidget {
  const _NowPlayingFullTestApp({
    required this.snapshot,
    required this.i18n,
    required this.repository,
    required this.mediaController,
    this.themeSettings = const SettingsSnapshot.defaults(),
    this.shellActions,
    this.useRouter = false,
  });

  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final _FakeNowPlayingRepository repository;
  final MediaControlController mediaController;
  final SettingsSnapshot themeSettings;
  final SmPlayerShellActions? shellActions;
  final bool useRouter;

  @override
  Widget build(BuildContext context) {
    final app =
        useRouter
            ? MaterialApp.router(
              theme: buildSmPlayerTheme(themeSettings),
              routerConfig: GoRouter(
                initialLocation: '/now-playing/full?from=/now-playing',
                routes: [
                  GoRoute(
                    path: '/now-playing/full',
                    builder:
                        (context, state) =>
                            const Scaffold(body: NowPlayingFullPage()),
                  ),
                  GoRoute(
                    path: '/now-playing',
                    builder:
                        (context, state) =>
                            const Scaffold(body: SizedBox.shrink()),
                  ),
                ],
              ),
            )
            : MaterialApp(
              theme: buildSmPlayerTheme(themeSettings),
              home: const Scaffold(body: NowPlayingFullPage()),
            );
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryRepositoryProvider.overrideWithValue(repository),
        mediaControlControllerProvider.overrideWith((ref) => mediaController),
        smPlayerShellActionsProvider.overrideWithValue(shellActions),
      ],
      child: SmPlayerI18nScope(i18n: i18n, child: app),
    );
  }
}

Future<void> _writeNowPlayingBoundaryPng(
  WidgetTester tester,
  GlobalKey key,
  String path, {
  double pixelRatio = 1,
}) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

class _FakeNowPlayingRepository extends LibraryRepository {
  _FakeNowPlayingRepository(this.snapshot);

  LibraryContentData snapshot;
  final favoriteSongIds = <int>[];
  final playlistSongIds = <int, List<int>>{};
  int? hiddenSongId;
  int? movedSongId;
  String? movedFolderPath;

  @override
  Future<LibraryContentData> getLibraryContentData() async => snapshot;

  @override
  Future<String?> getPreferenceLevel(String type, String itemId) async {
    return null;
  }

  @override
  Future<void> setSongsFavorite(List<int> songIds, bool favorite) async {
    if (favorite) {
      favoriteSongIds.addAll(
        songIds.where((songId) => !favoriteSongIds.contains(songId)),
      );
    } else {
      favoriteSongIds.removeWhere(songIds.contains);
    }
    snapshot = _snapshotWithSongs(
      snapshot,
      snapshot.songs
          .map(
            (song) =>
                songIds.contains(song.id)
                    ? _songWithFavorite(song, favorite)
                    : song,
          )
          .toList(),
    );
  }

  @override
  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    playlistSongIds[playlistId] = [
      ...(playlistSongIds[playlistId] ?? const <int>[]),
      ...songIds,
    ];
  }

  @override
  Future<void> removeSongsFromPlaylist(
    int playlistId,
    List<int> songIds,
  ) async {
    playlistSongIds[playlistId] = [
      for (final songId in playlistSongIds[playlistId] ?? const <int>[])
        if (!songIds.contains(songId)) songId,
    ];
  }

  @override
  Future<void> hideSong(int songId) async {
    hiddenSongId = songId;
  }

  @override
  Future<void> unhideSong(int songId) async {
    hiddenSongId = null;
  }

  @override
  Future<LocalItemsMoveResult> moveSongToFolder(
    int songId,
    String folderPath, {
    LocalMoveConflictResolver? resolveConflict,
  }) async {
    movedSongId = songId;
    movedFolderPath = folderPath;
    return LocalItemsMoveResult(
      songs: [
        LocalSongMove(
          id: songId,
          oldPath: r'C:\Music\blue.mp3',
          newPath: r'C:\Target\blue.mp3',
        ),
      ],
      folders: const [],
    );
  }

  @override
  Future<void> undoMoveLocalItems(LocalItemsMoveResult result) async {
    movedSongId = null;
    movedFolderPath = null;
  }

  @override
  Future<void> replaceNowPlaying(List<int> songIds) async {
    snapshot = _snapshotWithSongs(
      snapshot,
      snapshot.songs,
      nowPlaying: NowPlayingSnapshot(
        playlistId: snapshot.nowPlaying.playlistId,
        songIds: songIds,
      ),
    );
  }

  @override
  Future<LyricsSnapshot> getSongLyrics(
    int songId, {
    LyricsRequestMode mode = LyricsRequestMode.auto,
  }) async {
    return const LyricsSnapshot(
      source: LyricsSource.musicFile,
      isSynced: true,
      rawText: '[00:00.00]Opening lyric\n[00:10.00]Current lyric',
      lines: [
        LyricsLine(id: 1, timestampMs: 0, text: 'Opening lyric'),
        LyricsLine(id: 2, timestampMs: 10000, text: 'Current lyric'),
      ],
    );
  }

  @override
  Future<SongPropertiesSnapshot> getSongProperties(int songId) async {
    return const SongPropertiesSnapshot(
      songId: 1,
      path: r'C:\Music\blue.mp3',
      title: 'Blue Song',
      subtitle: '',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Blue Hour',
      albumArtist: '',
      publisher: '',
      trackNumber: 0,
      year: 0,
      genre: '',
      composers: '',
      duration: 120,
      bitrate: 0,
      fileSize: 1024,
      dateCreated: '2026-05-20T00:00:00Z',
      dateModified: '2026-05-20T00:00:00Z',
      fileType: 'MP3',
      playCount: 0,
    );
  }

  @override
  Future<SongArtworkSnapshot> getSongArtworkSnapshot(int songId) async {
    return const SongArtworkSnapshot(
      songId: 1,
      artworkUrl: '',
      sourceUrl: '',
      sourcePath: '',
      source: SongArtworkSource.none,
    );
  }
}

class _DelayedPreferenceRepository extends _FakeNowPlayingRepository {
  _DelayedPreferenceRepository(super.snapshot);

  final _preferenceCompleter = Completer<String?>();
  bool preferenceRequested = false;

  @override
  Future<String?> getPreferenceLevel(String type, String itemId) {
    preferenceRequested = true;
    return _preferenceCompleter.future;
  }

  void completePreference(String? level) {
    _preferenceCompleter.complete(level);
  }
}

class _LongLyricsRepository extends _FakeNowPlayingRepository {
  _LongLyricsRepository(super.snapshot);

  @override
  Future<LyricsSnapshot> getSongLyrics(
    int songId, {
    LyricsRequestMode mode = LyricsRequestMode.auto,
  }) async {
    return LyricsSnapshot(
      source: LyricsSource.musicFile,
      isSynced: true,
      rawText: '',
      lines: [
        for (var index = 0; index < 12; index += 1)
          LyricsLine(
            id: index + 1,
            timestampMs: index * 10000,
            text: 'Lyric line ${index + 1}',
          ),
      ],
    );
  }
}

class _PlainLyricsRepository extends _FakeNowPlayingRepository {
  _PlainLyricsRepository(super.snapshot);

  @override
  Future<LyricsSnapshot> getSongLyrics(
    int songId, {
    LyricsRequestMode mode = LyricsRequestMode.auto,
  }) async {
    return const LyricsSnapshot(
      source: LyricsSource.musicFile,
      isSynced: false,
      rawText: 'First plain lyric\nSecond plain lyric\nThird plain lyric',
      lines: [
        LyricsLine(id: 1, timestampMs: null, text: 'First plain lyric'),
        LyricsLine(id: 2, timestampMs: null, text: 'Second plain lyric'),
        LyricsLine(id: 3, timestampMs: null, text: 'Third plain lyric'),
      ],
    );
  }
}

const _snapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\blue.mp3',
      title: 'Blue Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Blue Hour',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
  ],
  recentSongs: [],
  recentPlaylists: [],
  recentAlbums: [],
  recentArtists: [],
  recentSearches: [],
  playlists: [
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
  folders: [
    LibraryFolder(id: 20, path: r'C:\Target', parentId: 0, criterion: 0),
  ],
  favoritePlaylistId: 3,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: [1]),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

final _searchSnapshot = _snapshotWithSongs(_snapshot, [
  ..._snapshot.songs,
  const LibrarySong(
    id: 2,
    path: r'C:\Music\red.mp3',
    title: 'Red Song',
    artist: 'Artist B',
    artists: ['Artist B'],
    album: 'Red Hour',
    duration: 130,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  ),
], nowPlaying: const NowPlayingSnapshot(playlistId: 0, songIds: [1, 2]));

LibraryContentData _snapshotWithSongs(
  LibraryContentData snapshot,
  List<LibrarySong> songs, {
  NowPlayingSnapshot? nowPlaying,
}) {
  return LibraryContentData(
    songs: songs,
    recentSongs: snapshot.recentSongs,
    recentPlaylists: snapshot.recentPlaylists,
    recentAlbums: snapshot.recentAlbums,
    recentArtists: snapshot.recentArtists,
    recentSearches: snapshot.recentSearches,
    playlists: snapshot.playlists,
    folders: snapshot.folders,
    favoritePlaylistId: snapshot.favoritePlaylistId,
    nowPlaying: nowPlaying ?? snapshot.nowPlaying,
    hasLibrary: snapshot.hasLibrary,
    sortCriterion: snapshot.sortCriterion,
    albumsSort: snapshot.albumsSort,
    showCount: snapshot.showCount,
    hideMultiSelectCommandBarAfterOperation:
        snapshot.hideMultiSelectCommandBarAfterOperation,
    rootPath: snapshot.rootPath,
    databasePath: snapshot.databasePath,
  );
}

LibraryContentData _snapshotWithPlaylists(
  LibraryContentData snapshot,
  List<LibraryPlaylist> playlists,
) {
  return LibraryContentData(
    songs: snapshot.songs,
    recentSongs: snapshot.recentSongs,
    recentPlaylists: snapshot.recentPlaylists,
    recentAlbums: snapshot.recentAlbums,
    recentArtists: snapshot.recentArtists,
    recentSearches: snapshot.recentSearches,
    playlists: playlists,
    folders: snapshot.folders,
    favoritePlaylistId: snapshot.favoritePlaylistId,
    nowPlaying: snapshot.nowPlaying,
    hasLibrary: snapshot.hasLibrary,
    sortCriterion: snapshot.sortCriterion,
    albumsSort: snapshot.albumsSort,
    showCount: snapshot.showCount,
    hideMultiSelectCommandBarAfterOperation:
        snapshot.hideMultiSelectCommandBarAfterOperation,
    rootPath: snapshot.rootPath,
    databasePath: snapshot.databasePath,
  );
}

LibraryContentData _snapshotWithHideAfterOperation(
  LibraryContentData snapshot,
  bool hideAfterOperation,
) {
  return LibraryContentData(
    songs: snapshot.songs,
    recentSongs: snapshot.recentSongs,
    recentPlaylists: snapshot.recentPlaylists,
    recentAlbums: snapshot.recentAlbums,
    recentArtists: snapshot.recentArtists,
    recentSearches: snapshot.recentSearches,
    playlists: snapshot.playlists,
    folders: snapshot.folders,
    favoritePlaylistId: snapshot.favoritePlaylistId,
    nowPlaying: snapshot.nowPlaying,
    hasLibrary: snapshot.hasLibrary,
    sortCriterion: snapshot.sortCriterion,
    albumsSort: snapshot.albumsSort,
    showCount: snapshot.showCount,
    hideMultiSelectCommandBarAfterOperation: hideAfterOperation,
    rootPath: snapshot.rootPath,
    databasePath: snapshot.databasePath,
  );
}

LibrarySong _songWithFavorite(LibrarySong song, bool favorite) {
  return LibrarySong(
    id: song.id,
    path: song.path,
    title: song.title,
    artist: song.artist,
    artists: song.artists,
    album: song.album,
    duration: song.duration,
    playCount: song.playCount,
    lyricsOffsetMs: song.lyricsOffsetMs,
    dateAdded: song.dateAdded,
    favorite: favorite,
    thumbnailPath: song.thumbnailPath,
  );
}

Future<void> _openAddToMenu(WidgetTester tester) async {
  final inlineAddTo = find.text('Add To');
  if (inlineAddTo.evaluate().isNotEmpty) {
    await tester.tap(inlineAddTo.first);
    await tester.pumpAndSettle();
    return;
  }

  await tester.tap(find.byTooltip('More').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add To').first);
  await tester.pumpAndSettle();
}

bool _hasPlayerBarOpacity(WidgetTester tester, double opacity) {
  return tester
      .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
      .any((widget) => widget.opacity == opacity);
}
