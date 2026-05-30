import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
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
      'common.cancel': 'Cancel',
      'common.multiSelect': 'Multi Select',
      'common.myFavorites': 'My Favorites',
      'common.nowPlaying': 'Now Playing',
      'common.undo': 'Undo',
      'common.close': 'Close',
      'context.addToPlaylist': 'Add To',
      'context.seeAlbum': 'See Album',
      'context.seeAlbumArt': 'See Album Art',
      'context.seeArtist': 'See Artist',
      'context.seeLyrics': 'See Lyrics',
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
      'player.like': 'Like',
      'player.more': 'More',
      'player.next': 'Next',
      'player.pause': 'Pause',
      'player.play': 'Play',
      'player.playbackMode': 'Playback Mode',
      'player.playbackModeList': 'List',
      'player.playbackModeRepeat': 'Repeat',
      'player.playbackModeRepeatOne': 'Repeat One',
      'player.playbackModeShuffle': 'Shuffle',
      'player.previous': 'Previous',
      'player.unlike': 'Unlike',
      'player.volume': 'Volume',
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
      final queueCloseButton = tester.widget<TextButton>(
        find.descendant(
          of: find.byTooltip('Close'),
          matching: find.byType(TextButton),
        ),
      );
      expect(
        queueCloseButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        const Color(0x1a0078d7),
      );
      expect(
        queueCloseButton.style?.foregroundColor?.resolve(<WidgetState>{}),
        const Color(0xff0063b1),
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

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeNowPlayingRepository(_snapshot),
        mediaController: MediaControlController(),
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

    await tester.tap(find.text('Now Playing').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byType(PlaylistControlItem), findsWidgets);

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
    expect(tester.getSize(firstRowPlayNextAction), const Size.square(34));
    expect(tester.getSize(firstRowActions).width, 34);
    expect(tester.getSize(firstRowDuration).width, 20);
    expect(tester.getSize(find.text('2:00').first).height, lessThan(24));
    AnimatedOpacity hoverOpacityFor(Finder action) {
      return tester.widget<AnimatedOpacity>(
        find
            .ancestor(of: action.first, matching: find.byType(AnimatedOpacity))
            .first,
      );
    }

    expect(hoverOpacityFor(firstRowPlayNextAction).opacity, 0);
    expect(hoverOpacityFor(firstRowMoreAction).opacity, 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(firstRow));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(hoverOpacityFor(firstRowPlayNextAction).opacity, 1);
    expect(tester.getSize(firstRowActions).width, 68);
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

  testWidgets('NowPlayingFullPage shows playback error like Electron', (
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

    expect(find.text('Playback failed'), findsOneWidget);
  });

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
    mediaController.setTrackLoading(true);

    await tester.pumpWidget(
      _NowPlayingFullTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('MediaControl.ProgressLoading')),
      findsNothing,
    );
    expect(find.text('2:00'), findsOneWidget);
  });

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

    expect(find.byType(MediaControlPlayerFrame), findsOneWidget);
    expect(find.byType(MediaControlSurface), findsOneWidget);
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
      490,
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

    expect(exitDecoration().color, Colors.transparent);
    expect(exitDecoration().border?.top.color, Colors.transparent);
    expect(
      tester
          .widget<Icon>(find.byKey(const ValueKey('NowPlayingFull.ExitIcon')))
          .color,
      const Color(0xe6080c12),
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
  });

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
      expect(find.byTooltip('Like'), findsOneWidget);
      expect(
        tester.getSize(
          find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
        ),
        const Size(56, 56),
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('MediaControl.CompactModeButton')),
        ),
        const Size(36, 36),
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('NowPlayingFull.ExitArtworkShell')),
        ),
        const Size(72, 72),
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

    repository.completePreference(null);
    await tester.pumpAndSettle();
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

  testWidgets('NowPlayingFullPage more view opens dialog and closes menu', (
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
    await tester.tap(find.text('See Lyrics'));
    await tester.pump();

    expect(find.byType(MusicDialog), findsOneWidget);
    final dialog = tester.widget<MusicDialog>(find.byType(MusicDialog));
    expect(dialog.currentTrackId, 1);
    expect(dialog.isPlaying, isFalse);
    expect(dialog.queueSongIds, [1]);
    expect(find.text('View'), findsNothing);
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

      expect(_hasPlayerBarOpacity(tester, 0.24), isTrue);
    },
  );

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
  });

  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final _FakeNowPlayingRepository repository;
  final MediaControlController mediaController;
  final SettingsSnapshot themeSettings;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryRepositoryProvider.overrideWithValue(repository),
        mediaControlControllerProvider.overrideWith((ref) => mediaController),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: buildSmPlayerTheme(themeSettings),
          home: const Scaffold(body: NowPlayingFullPage()),
        ),
      ),
    );
  }
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
