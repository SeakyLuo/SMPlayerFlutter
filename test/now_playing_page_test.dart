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
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';
import 'package:smplayer_flutter/src/playback/hold_release_action.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_constants.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_page.dart';
import 'package:smplayer_flutter/src/playback/now_playing_page.dart';
import 'package:smplayer_flutter/src/playback/now_playing_queue_view.dart';
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
      'common.favorite': 'Favorite',
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
      _NowPlayingTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeNowPlayingRepository(_snapshot),
      ),
    );
    await tester.pumpAndSettle();

    final commandBarRight = tester.getRect(find.byType(CommandBar)).right;
    final firstRow = find.byType(PlaylistControlItem).first;
    final rowLeft = tester.getRect(firstRow).left;
    final rowRight = tester.getRect(firstRow).right;

    expect(rowLeft, 14);
    expect(rowRight, commandBarRight);
    expect(1012 - rowRight, 14);
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byKey(
          const ValueKey('PlaylistControlItem.FavoriteAction'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byKey(const ValueKey('PlaylistControlItem.AddToAction')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byKey(
          const ValueKey('PlaylistControlItem.PlayNextAction'),
        ),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byKey(
          const ValueKey('PlaylistControlItem.RemoveAction'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byKey(const ValueKey('PlaylistControlItem.MoreAction')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('NowPlayingPage compact width mirrors Electron queue layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 760);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _NowPlayingTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeNowPlayingRepository(_snapshot),
      ),
    );
    await tester.pumpAndSettle();

    final firstRow = find.byWidgetPredicate(
      (widget) =>
          widget is PlaylistControlItem &&
          widget.key == const ValueKey('now-playing-1-0'),
    );
    final rowRect = tester.getRect(firstRow);
    final durationRect = tester.getRect(
      find.descendant(
        of: firstRow,
        matching: find.byKey(const ValueKey('PlaylistControlItem.Duration')),
      ),
    );
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );

    expect(rowRect.left, 8);
    expect(rowRect.right, 692);
    expect(rowRect.height, 78);
    expect(durationRect.right, 672);
    expect(rowRect.right - durationRect.right, 20);
    expect(list.padding, const EdgeInsets.fromLTRB(0, 0, 0, 28));
    expect(
      tester
          .getRect(find.byKey(const ValueKey('NowPlayingQueue.Scrollbar')))
          .right,
      700,
    );
    expect(
      tester.widget<PlaylistControlItem>(firstRow).variant,
      PlaylistControlItemVariant.compact,
    );
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byKey(
          const ValueKey('PlaylistControlItem.FavoriteAction'),
        ),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byKey(const ValueKey('PlaylistControlItem.AddToAction')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byKey(
          const ValueKey('PlaylistControlItem.RemoveAction'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byKey(const ValueKey('PlaylistControlItem.MoreAction')),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'NowPlayingPage remove paused current queue item does not play next song',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1012, 760);
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
        _NowPlayingTestApp(
          snapshot: _searchSnapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      final firstRow = find.byWidgetPredicate(
        (widget) =>
            widget is PlaylistControlItem &&
            widget.key == const ValueKey('now-playing-1-0'),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(firstRow));
      addTearDown(mouse.removePointer);
      await tester.pump(const Duration(milliseconds: 160));

      await tester.tap(
        find.descendant(
          of: firstRow,
          matching: find.byKey(
            const ValueKey('PlaylistControlItem.RemoveAction'),
          ),
        ),
      );
      await tester.pump();

      expect(repository.snapshot.nowPlaying.songIds, [2]);
      expect(mediaController.state.track.id, 1);
      expect(mediaController.state.selectedQueueIndex, isNull);
      expect(mediaController.state.isPlaying, isFalse);
      await tester.tap(find.text('Undo'));
      await tester.pump();

      expect(repository.snapshot.nowPlaying.songIds, [1, 2]);
      expect(mediaController.state.track.id, 1);
      expect(mediaController.state.selectedQueueIndex, 0);
      expect(mediaController.state.isPlaying, isFalse);
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'NowPlayingPage remove current playing queue item plays next song',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1012, 760);
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
        _NowPlayingTestApp(
          snapshot: _searchSnapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      final firstRow = find.byWidgetPredicate(
        (widget) =>
            widget is PlaylistControlItem &&
            widget.key == const ValueKey('now-playing-1-0'),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(firstRow));
      addTearDown(mouse.removePointer);
      await tester.pump(const Duration(milliseconds: 160));

      await tester.tap(
        find.descendant(
          of: firstRow,
          matching: find.byKey(
            const ValueKey('PlaylistControlItem.RemoveAction'),
          ),
        ),
      );
      await tester.pump();

      expect(repository.snapshot.nowPlaying.songIds, [2]);
      expect(mediaController.state.track.id, 2);
      expect(mediaController.state.selectedQueueIndex, 0);
      expect(mediaController.state.isPlaying, isTrue);
      await tester.tap(find.text('Undo'));
      await tester.pump();

      expect(repository.snapshot.nowPlaying.songIds, [1, 2]);
      expect(mediaController.state.track.id, 2);
      expect(mediaController.state.selectedQueueIndex, 1);
      expect(mediaController.state.isPlaying, isTrue);
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets('NowPlayingPage queue song click keeps scroll position', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1012, 760);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final songs = List.generate(
      30,
      (index) => LibrarySong(
        id: index + 1,
        path:
            r'C:\Music\queue-'
            '${index + 1}.mp3',
        title: 'Queue Song ${index + 1}',
        artist: 'Artist A',
        artists: const ['Artist A'],
        album: 'Queue Album',
        duration: 120 + index,
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
        songIds: [for (final song in songs) song.id],
      ),
    );
    final repository = _FakeNowPlayingRepository(snapshot);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Queue Song 1',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );

    await tester.pumpWidget(
      _NowPlayingTestApp(
        snapshot: snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(NowPlayingQueueView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scrollable.position.jumpTo(560);
    await tester.pump();
    final beforeOffset = scrollable.position.pixels;

    await tester.tap(find.text('Queue Song 10'));
    await tester.pump();

    expect(mediaController.state.track.id, 10);
    expect(mediaController.state.selectedQueueIndex, 9);
    expect(scrollable.position.pixels, beforeOffset);
    await tester.pump();
    expect(scrollable.position.pixels, beforeOffset);
    expect(repository.replaceNowPlayingCount, 0);
  });

  testWidgets('NowPlayingPage queue row favorite toggles like Electron', (
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

    final firstRow = find.byWidgetPredicate(
      (widget) =>
          widget is PlaylistControlItem &&
          widget.key == const ValueKey('now-playing-1-0'),
    );
    await tester.tap(
      find.descendant(
        of: firstRow,
        matching: find.byKey(
          const ValueKey('PlaylistControlItem.FavoriteAction'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.snapshot.songs.single.favorite, isTrue);
  });

  testWidgets(
    'NowPlayingPage multi-select bar overlays outside panel padding',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 1300);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _NowPlayingTestApp(snapshot: _snapshot, i18n: i18n),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Multi Select').hitTestable().first);
      await tester.pumpAndSettle();

      final surfaceRect = tester.getRect(
        find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
      );
      expect(surfaceRect.left, 0);
      expect(surfaceRect.right, 1400);
      expect(surfaceRect.width, 1400);
      expect(surfaceRect.height, 64 + multiSelectCommandBarShellBottomInset);
      expect(surfaceRect.bottom, 900);
    },
  );

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

  testWidgets('NowPlayingPage queue menu keeps Add To but omits Play Next', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      _NowPlayingTestApp(snapshot: _snapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('Add To'), findsWidgets);
    expect(find.text('Play Next'), findsNothing);
    expect(find.text('Mix'), findsNothing);
    expect(find.text('Built in'), findsNothing);
  });

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
    'NowPlayingPage multi-select Add To respects Electron hide preference',
    (tester) async {
      final snapshot = _snapshotWithHideAfterOperation(_snapshot, false);
      final repository = _FakeNowPlayingRepository(snapshot);
      await tester.pumpWidget(
        _NowPlayingTestApp(
          snapshot: snapshot,
          i18n: i18n,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await _selectBlueSongInNowPlayingMultiSelect(tester);
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Add To').hitTestable().last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Favorites'));
      await tester.pumpAndSettle();

      expect(repository.favoriteSongIds, [1]);
      expect(find.text('1 selected'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'NowPlayingPage multi-select Play Selected respects Electron hide preference',
    (tester) async {
      final snapshot = _snapshotWithHideAfterOperation(_snapshot, false);
      final repository = _FakeNowPlayingRepository(snapshot);
      await tester.pumpWidget(
        _NowPlayingTestApp(
          snapshot: snapshot,
          i18n: i18n,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await _selectBlueSongInNowPlayingMultiSelect(tester);
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Play Selected'));
      await tester.pumpAndSettle();

      expect(repository.snapshot.nowPlaying.songIds, [1]);
      expect(find.text('1 selected'), findsOneWidget);
    },
  );

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
    'ImmersiveModePage shows immersive lyrics and Electron fallback',
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
        _ImmersiveModeTestApp(
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
          find.byKey(const ValueKey('ImmersiveMode.QueuePopoverHost')),
        ),
        const Rect.fromLTWH(856, 56, 520, 712),
      );
      expect(find.text('Now Playing'), findsWidgets);
      expect(find.text('1 songs'), findsOneWidget);
      expect(tester.getSize(find.byTooltip('Close')), const Size(40, 40));
      final closeHover = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await closeHover.addPointer();
      await closeHover.moveTo(tester.getCenter(find.byTooltip('Close')));
      await tester.pump();
      final queueCloseButton = tester.widget<SmPlayerTextIconButton>(
        find.byKey(const ValueKey('ImmersiveMode.QueueCloseButton')),
      );
      expect(queueCloseButton.showLabel, isFalse);
      expect(queueCloseButton.tooltipEnabled, isTrue);
      expect(queueCloseButton.height, 40);
      expect(queueCloseButton.borderRadius, 8);
      expect(queueCloseButton.iconSize, 18);
      final queueCloseIcon = find.descendant(
        of: find.byKey(const ValueKey('ImmersiveMode.QueueCloseButton')),
        matching: find.byType(Icon),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('ImmersiveMode.QueueCloseButton')),
          matching: find.byIcon(FluentIcons.chevron_right_20_regular),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<Icon>(queueCloseIcon).icon,
        FluentIcons.chevron_right_20_regular,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('ImmersiveMode.QueueCloseButton')),
          matching: find.byType(GlassContainer),
        ),
        findsNothing,
      );
      final queueTitle = tester
          .widgetList<Text>(find.text('Now Playing'))
          .singleWhere((widget) => widget.style?.fontSize == 26);
      expect(queueTitle.style?.fontWeight, FontWeight.w800);
      final queueCount = tester.widget<Text>(find.text('1 songs'));
      expect(queueCount.style?.fontSize, 13);
      expect(queueCount.style?.fontWeight, FontWeight.w700);
      final queueButton = tester.widget<SmPlayerTextIconButton>(
        find.ancestor(
          of: find.byKey(const ValueKey('ImmersiveMode.QueueLabel')),
          matching: find.byType(SmPlayerTextIconButton),
        ),
      );
      expect(queueButton.active, isTrue);
      expect(queueButton.height, 40);
      expect(queueButton.borderRadius, 12);
      expect(queueButton.iconSize, 18);
      expect(queueButton.fontSize, 14);
      final queueButtonGlass = tester.widget<GlassContainer>(
        find.descendant(
          of: find.byWidget(queueButton),
          matching: find.byType(GlassContainer),
        ),
      );
      expect(queueButtonGlass.settings?.blur, 46);
      expect(queueButtonGlass.shape, isA<LiquidRoundedRectangle>());
    },
  );

  testWidgets(
    'ImmersiveModePage lyric stage keeps compact height below desktop stage',
    (tester) async {
      tester.view.physicalSize = const Size(900, 760);
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

      await tester.pumpWidget(
        _ImmersiveModeTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byKey(const ValueKey('ImmersiveMode.LyricsStage'))),
        const Size(382, 384),
      );

      tester.view.physicalSize = const Size(500, 760);
      await tester.pumpWidget(
        _ImmersiveModeTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      final compactLyricStageRect = tester.getRect(
        find.byKey(const ValueKey('ImmersiveMode.LyricsStage')),
      );
      final compactPlayerFrameRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
      );
      final compactLyricsList = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('ImmersiveMode.LyricsList')),
      );
      expect(compactLyricStageRect.width, 360);
      expect(compactLyricStageRect.height, lessThan(320));
      expect((compactLyricsList.padding! as EdgeInsets).bottom, 0);
      expect(
        compactLyricStageRect.bottom,
        lessThanOrEqualTo(compactPlayerFrameRect.top),
      );
      expect(
        compactPlayerFrameRect.top - compactLyricStageRect.bottom,
        lessThanOrEqualTo(12),
      );
    },
  );

  testWidgets(
    'ImmersiveModePage compact stage does not overflow short windows',
    (tester) async {
      tester.view.physicalSize = const Size(500, 600);
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

      await tester.pumpWidget(
        _ImmersiveModeTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final compactLyricStageRect = tester.getRect(
        find.byKey(const ValueKey('ImmersiveMode.LyricsStage')),
      );
      final compactPlayerFrameRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
      );
      expect(compactLyricStageRect.height, greaterThan(0));
      expect(
        compactLyricStageRect.bottom,
        lessThanOrEqualTo(compactPlayerFrameRect.top),
      );
      expect(
        compactPlayerFrameRect.top - compactLyricStageRect.bottom,
        lessThanOrEqualTo(12),
      );
    },
  );

  testWidgets('ImmersiveModePage no active track labels match Electron', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _ImmersiveModeTestApp(
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
    'ImmersiveModePage no active track disables full footer volume like Electron',
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
        _ImmersiveModeTestApp(
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
      final wideMoreMenu = find.byKey(const ValueKey('MenuFlyoutPanel.0.4'));
      expect(find.text('Quick Play'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.text('Save Playlist'), findsNothing);
      expect(find.text('Clear Now Playing'), findsNothing);
      expect(
        find.descendant(of: wideMoreMenu, matching: find.text('Add To')),
        findsNothing,
      );
      expect(
        find.descendant(of: wideMoreMenu, matching: find.text('Play Artist')),
        findsNothing,
      );
      expect(
        find.descendant(of: wideMoreMenu, matching: find.text('Play Album')),
        findsNothing,
      );
      expect(
        find.descendant(of: wideMoreMenu, matching: find.text('View')),
        findsNothing,
      );
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
        _ImmersiveModeTestApp(
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
      final compactWideMoreMenu = find.byKey(
        const ValueKey('MenuFlyoutPanel.0.4'),
      );
      expect(find.text('Quick Play'), findsOneWidget);
      expect(find.text('Playback Mode: List'), findsNothing);
      expect(
        find.byKey(const ValueKey('MediaControl.VolumeMenuItem')),
        findsNothing,
      );
      expect(find.text('Like'), findsNothing);
      expect(find.text('Save Playlist'), findsNothing);
      expect(find.text('Clear Now Playing'), findsNothing);
      expect(
        find.descendant(of: compactWideMoreMenu, matching: find.text('Add To')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: compactWideMoreMenu,
          matching: find.text('Play Artist'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: compactWideMoreMenu,
          matching: find.text('Play Album'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: compactWideMoreMenu, matching: find.text('View')),
        findsNothing,
      );
      await tester.tapAt(const Offset(40, 40));
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(760, 760);
      await tester.pumpWidget(
        _ImmersiveModeTestApp(
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
      final compactMoreMenu = find.byKey(const ValueKey('MenuFlyoutPanel.0.7'));
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
      expect(find.text('Save Playlist'), findsNothing);
      expect(find.text('Clear Now Playing'), findsNothing);
      expect(
        find.descendant(of: compactMoreMenu, matching: find.text('Add To')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: compactMoreMenu,
          matching: find.text('Play Artist'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: compactMoreMenu, matching: find.text('Play Album')),
        findsNothing,
      );
      expect(
        find.descendant(of: compactMoreMenu, matching: find.text('View')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'ImmersiveModePage disabled night buttons keep Electron full-page foreground',
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
        _ImmersiveModeTestApp(
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
    'ImmersiveModePage previous button has no Electron extra hold UI',
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
        _ImmersiveModeTestApp(
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

  testWidgets('ImmersiveModePage scopes controls to immersive night mode', (
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
      _ImmersiveModeTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeNowPlayingRepository(_snapshot),
        mediaController: mediaController,
        themeSettings: const SettingsSnapshot.defaults(),
      ),
    );
    await tester.pump();

    final queueButtonFinder = find.ancestor(
      of: find.byKey(const ValueKey('ImmersiveMode.QueueLabel')),
      matching: find.byType(SmPlayerTextIconButton),
    );
    final queueButton = tester.widget<SmPlayerTextIconButton>(
      queueButtonFinder,
    );

    expect(queueButton.active, isFalse);
    expect(queueButton.height, 40);
    expect(queueButton.borderRadius, 12);
    expect(queueButton.glassSettings, immersiveModeTopButtonNightGlassSettings);
    final queueButtonDecorations =
        tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: queueButtonFinder,
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .toList();
    expect(
      queueButtonDecorations.any(
        (decoration) => decoration.color == const Color(0x14ffffff),
      ),
      isTrue,
    );
    expect(
      queueButtonDecorations.any(
        (decoration) =>
            decoration.border == Border.all(color: const Color(0x29ffffff)),
      ),
      isTrue,
    );
    expect(
      tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: queueButtonFinder,
              matching: find.byType(DecoratedBox),
            ),
          )
          .length,
      greaterThanOrEqualTo(1),
    );
    final queueButtonGlass = tester.widget<GlassContainer>(
      find
          .descendant(
            of: queueButtonFinder,
            matching: find.byType(GlassContainer),
          )
          .first,
    );
    expect(queueButtonGlass.settings, immersiveModeTopButtonNightGlassSettings);
    final queueButtonForeground =
        tester
            .widget<IconTheme>(
              find
                  .descendant(
                    of: queueButtonFinder,
                    matching: find.byType(IconTheme),
                  )
                  .first,
            )
            .data
            .color;
    expect(queueButtonForeground, const Color(0xe0ffffff));
    final queueButtonText = tester.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('ImmersiveMode.QueueLabel')),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );
    expect(queueButtonText.style.color, const Color(0xe0ffffff));
    final queueButtonDecoration =
        tester
                .widgetList<DecoratedBox>(
                  find.descendant(
                    of: queueButtonFinder,
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .last
                .decoration
            as BoxDecoration;
    expect(queueButtonDecoration.color, const Color(0x14ffffff));
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
      const Color(0xf0f6f9fc),
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
      const Color(0x380078d7),
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
      find.byKey(const ValueKey('ImmersiveMode.QueuePanelBackground')),
    );
    final queuePanelDecoration =
        queuePanelBackground.decoration as BoxDecoration;
    expect(queuePanelDecoration.color, const Color(0xdb12100e));
    expect(queuePanelDecoration.gradient, isA<LinearGradient>());
    expect(
      find.byKey(const ValueKey('ImmersiveMode.QueuePanelGlass')),
      findsOneWidget,
    );
    final queuePanelGlass = tester.widget<GlassContainer>(
      find.byKey(const ValueKey('ImmersiveMode.QueuePanelGlass')),
    );
    expect(queuePanelGlass.quality, GlassQuality.minimal);
    expect(queuePanelGlass.settings?.blur, 46);
    expect(queuePanelGlass.settings?.saturation, 1.65);
    expect(queuePanelGlass.settings?.standardOpacityMultiplier, 0.35);
    expect(
      tester.widget<Text>(find.text('1 songs')).style?.color,
      const Color(0xb8ffffff),
    );
  });

  testWidgets('ImmersiveModePage top buttons hover blue in night mode', (
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
      _ImmersiveModeTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeNowPlayingRepository(_snapshot),
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    final backButtonFinder = find.ancestor(
      of: find.byKey(const ValueKey('ImmersiveMode.BackIcon')),
      matching: find.byType(SmPlayerTextIconButton),
    );
    final queueButtonFinder = find.ancestor(
      of: find.byKey(const ValueKey('ImmersiveMode.QueueLabel')),
      matching: find.byType(SmPlayerTextIconButton),
    );

    bool hasHoverBlue(Finder button) {
      return tester
          .widgetList<DecoratedBox>(
            find.descendant(of: button, matching: find.byType(DecoratedBox)),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .any((decoration) => decoration.color == const Color(0x290078d7));
    }

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(backButtonFinder));
    await tester.pump();
    expect(hasHoverBlue(backButtonFinder), isTrue);

    await mouse.moveTo(tester.getCenter(queueButtonFinder));
    await tester.pump();
    expect(hasHoverBlue(queueButtonFinder), isTrue);
    await mouse.removePointer();
  });

  testWidgets('ImmersiveModePage queue rows use Electron compact layout', (
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
      _ImmersiveModeTestApp(
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

    final firstRow = find.byKey(const ValueKey('now-playing-full-row-1-0'));
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
    final firstRowRemoveAction = find.descendant(
      of: firstRow,
      matching: find.byKey(const ValueKey('PlaylistControlItem.RemoveAction')),
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
      80,
    );
    expect(firstRowPlayNextAction, findsNothing);
    expect(tester.getSize(firstRowActions).width, 34);
    expect(tester.getSize(firstRowDuration).width, 20);
    expect(
      tester.getRect(firstRow).right - tester.getRect(firstRowDuration).right,
      20,
    );
    expect(
      tester.getRect(firstRowDuration).left -
          tester.getRect(firstRowMoreAction).right,
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

    Color rowBackgroundFor(Finder row) {
      final animatedRow =
          find
              .descendant(
                of: find.descendant(
                  of: row,
                  matching: find.byKey(
                    const ValueKey('PlaylistControlItem.Row'),
                  ),
                ),
                matching: find.byType(AnimatedContainer),
              )
              .first;
      final decoration =
          tester.widget<AnimatedContainer>(animatedRow).decoration
              as BoxDecoration;
      return decoration.color!;
    }

    expect(hoverOpacityFor(firstRowMoreAction).opacity, 0);
    expect(hoverOpacityFor(firstRowRemoveAction).opacity, 0);
    expect(rowBackgroundFor(firstRow), const Color(0x00eaf6ff));
    expect(
      find.byKey(const ValueKey('PlaylistControlItem.AddToAction')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byKey(
          const ValueKey('PlaylistControlItem.RemoveAction'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('PlaylistControlItem.FavoriteAction')),
      findsNothing,
    );
  });

  testWidgets('writes ImmersiveModePage queue hover screenshot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1009, 678);
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
      RepaintBoundary(
        key: repaintKey,
        child: _ImmersiveModeTestApp(
          snapshot: _searchSnapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Now Playing').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final firstRow = find.byKey(const ValueKey('now-playing-full-row-1-0'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(firstRow));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await _writeNowPlayingBoundaryPng(
      tester,
      repaintKey,
      'build/immersive_mode_queue_hover_verify.png',
      pixelRatio: 2,
    );
  });

  testWidgets(
    'ImmersiveModePage omits playback load failure banner like Electron',
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
        _ImmersiveModeTestApp(
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

  testWidgets('ImmersiveModePage keeps full player surface out of loading', (
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
      _ImmersiveModeTestApp(
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
      _ImmersiveModeTestApp(
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
    'ImmersiveModePage progress seek commits on release like Electron',
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
        _ImmersiveModeTestApp(
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
        _ImmersiveModeTestApp(
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

  testWidgets('ImmersiveModePage compact footer reuses nav-minimal surface', (
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
      _ImmersiveModeTestApp(
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
          .widget<Icon>(find.byKey(const ValueKey('ImmersiveMode.BackIcon')))
          .size,
      isNull,
    );
    expect(
      tester
          .widget<Icon>(find.byKey(const ValueKey('ImmersiveMode.QueueIcon')))
          .size,
      isNull,
    );
    final compactTopQueueButton = tester.widget<SmPlayerTextIconButton>(
      find.ancestor(
        of: find.byKey(const ValueKey('ImmersiveMode.QueueLabel')),
        matching: find.byType(SmPlayerTextIconButton),
      ),
    );
    expect(compactTopQueueButton.fontSize, 14);
    BoxDecoration exitDecoration() =>
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
                )
                .decoration!
            as BoxDecoration;

    expect(
      tester.getSize(
        find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
      ),
      const Size(68, 68),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
        matching: find.byKey(const ValueKey('ImmersiveMode.ExitAlbumSwatch')),
      ),
      findsNothing,
    );
    expect(exitDecoration().color, Colors.transparent);
    expect(exitDecoration().border?.top.color, Colors.transparent);
    expect(exitDecoration().gradient, isNull);
    expect(exitDecoration().boxShadow, isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
        matching: find.byKey(
          const ValueKey('ImmersiveMode.ExitArtworkBackdrop'),
        ),
      ),
      findsNothing,
    );
    expect(
      tester.widget<ExitFullscreenIcon>(
        find.byKey(const ValueKey('ImmersiveMode.ExitIcon')),
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
        find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
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
      of: find.byKey(const ValueKey('ImmersiveMode.QueueLabel')),
      matching: find.byType(SmPlayerTextIconButton),
    );
    await tester.tap(queueButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final compactQueueList = tester.widget<ListView>(
      find.byKey(const ValueKey('ImmersiveMode.QueueList')),
    );
    expect(compactQueueList.padding, const EdgeInsets.fromLTRB(10, 0, 0, 2));
    expect(
      tester
              .getRect(find.byKey(const ValueKey('ImmersiveMode.QueueList')))
              .right -
          tester.getRect(find.byType(PlaylistControlItem).first).right,
      10,
    );
  });

  testWidgets('writes ImmersiveModePage top text icon buttons screenshot', (
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
        child: _ImmersiveModeTestApp(
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
      find.byKey(const ValueKey('ImmersiveMode.BackIcon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ImmersiveMode.QueueLabel')),
      findsOneWidget,
    );
    final backButton = tester.widget<SmPlayerTextIconButton>(
      find.ancestor(
        of: find.byKey(const ValueKey('ImmersiveMode.BackIcon')),
        matching: find.byType(SmPlayerTextIconButton),
      ),
    );
    expect(backButton.showLabel, isFalse);
    expect(backButton.tooltipEnabled, isFalse);
    expect(backButton.height, 40);
    expect(backButton.borderRadius, 12);
    expect(find.byTooltip('Back'), findsNothing);
    final backButtonGlass = tester.widget<GlassContainer>(
      find.descendant(
        of: find.byWidget(backButton),
        matching: find.byType(GlassContainer),
      ),
    );
    expect(backButtonGlass.quality, GlassQuality.minimal);
    expect(backButtonGlass.settings, immersiveModeTopButtonNightGlassSettings);
    final queueButton = tester.widget<SmPlayerTextIconButton>(
      find.ancestor(
        of: find.byKey(const ValueKey('ImmersiveMode.QueueLabel')),
        matching: find.byType(SmPlayerTextIconButton),
      ),
    );
    expect(queueButton.showLabel, isTrue);
    expect(queueButton.tooltipEnabled, isFalse);
    expect(queueButton.height, 40);
    expect(queueButton.iconSize, 18);
    expect(queueButton.borderRadius, 12);
    expect(find.byTooltip('Now Playing'), findsNothing);
    final queueButtonGlass = tester.widget<GlassContainer>(
      find.descendant(
        of: find.byWidget(queueButton),
        matching: find.byType(GlassContainer),
      ),
    );
    expect(queueButtonGlass.quality, GlassQuality.minimal);
    expect(queueButtonGlass.settings, immersiveModeTopButtonNightGlassSettings);
    await _writeNowPlayingBoundaryPng(
      tester,
      repaintKey,
      'build/immersive_mode_top_text_icon_buttons_verify.png',
      pixelRatio: 2,
    );
  });

  testWidgets('writes ImmersiveModePage MediaControl footer screenshot', (
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
        child: _ImmersiveModeTestApp(
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
      'build/immersive_mode_media_control_footer_verify.png',
      pixelRatio: 2,
    );
  });

  testWidgets(
    'ImmersiveModePage compact footer matches Electron column geometry',
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
        _ImmersiveModeTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      final exitRect = tester.getRect(
        find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
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
    'ImmersiveModePage compact footer keeps voice and More inside utility',
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
        _ImmersiveModeTestApp(
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
    'ImmersiveModePage nav-minimal footer keeps voice and More in 80px utility',
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
        _ImmersiveModeTestApp(
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
    'ImmersiveModePage switches compact columns at Electron 520px breakpoint',
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
          _ImmersiveModeTestApp(
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
          find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
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
          find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
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
    'ImmersiveModePage mid-width footer uses compact utility like Electron',
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
        _ImmersiveModeTestApp(
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
          find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
        ),
        const Size(72, 72),
      );
      expect(
        tester.widget<ExitFullscreenIcon>(
          find.byKey(const ValueKey('ImmersiveMode.ExitIcon')),
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
    'ImmersiveModePage compact volume popover overlays from Electron anchor',
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
        _ImmersiveModeTestApp(
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
    'ImmersiveModePage utility switches at Electron 1200px breakpoint',
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
          _ImmersiveModeTestApp(
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
    'ImmersiveModePage switches nav-minimal layout at Electron 800px breakpoint',
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
          _ImmersiveModeTestApp(
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
      expect(compactFrameGlass.settings?.blur, 46);
      expect(compactFrameGlass.settings?.saturation, 1.65);
      final compactFrameBorderDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
      );
      final compactFrameBorder =
          (compactFrameBorderDecoration.decoration as BoxDecoration).border!
              as Border;
      expect(
        compactFrameBorder.top.color,
        MediaControlColors.compactPlayerBorder,
      );
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
            color: MediaControlColors.compactPlayerShadow,
            offset: Offset(0, -12),
            blurRadius: 36,
          ),
        ],
      );
      final compactFrameBackgroundDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBackground')),
      );
      final compactFrameBackground =
          compactFrameBackgroundDecoration.decoration as BoxDecoration;
      expect(
        compactFrameBackground.color,
        MediaControlColors.playerSurfaceSolid,
      );
      expect(compactFrameBackground.gradient, isNull);
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
      expect(wideFrameGlass.settings?.blur, 46);
      expect(wideFrameGlass.settings?.saturation, 1.65);
      final wideFrameBorderDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
      );
      final wideFrameBorder =
          (wideFrameBorderDecoration.decoration as BoxDecoration).border!
              as Border;
      expect(wideFrameBorder.top.color, MediaControlColors.playerBorder);
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
            color: MediaControlColors.playerShadow,
            offset: Offset(0, 18),
            blurRadius: 48,
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
    'ImmersiveModePage keeps nav-minimal columns across Electron 721px lower bound',
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
          _ImmersiveModeTestApp(
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
          find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
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
          find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
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

  testWidgets('ImmersiveModePage wide mode row keeps Electron active state', (
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
      _ImmersiveModeTestApp(
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
    final transparentHoverBackground = const Color(
      0x1a0078d7,
    ).withValues(alpha: 0);
    expect(
      buttonDecoration(const ValueKey('MediaControl.ShuffleButton')).color,
      transparentHoverBackground,
    );
    expect(
      buttonDecoration(const ValueKey('MediaControl.RepeatButton')).color,
      const Color(0x1a0078d7),
    );
    expect(
      buttonDecoration(const ValueKey('MediaControl.RepeatOneButton')).color,
      transparentHoverBackground,
    );

    await tester.tap(find.byKey(const ValueKey('MediaControl.RepeatButton')));
    await tester.pump();

    expect(mediaController.state.mode, PlaybackMode.once);
    expect(
      buttonDecoration(const ValueKey('MediaControl.RepeatButton')).color,
      transparentHoverBackground,
    );
  });

  testWidgets(
    'ImmersiveModePage night utility active state follows Electron cascade',
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
        _ImmersiveModeTestApp(
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
    'ImmersiveModePage primary and utility hover use selected-state color',
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
          _ImmersiveModeTestApp(
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
        expect(moreDecoration().color, expectedHoverColor.withValues(alpha: 0));
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
      await verifyMoreHover(const Color(0x380078d7));
    },
  );

  testWidgets('ImmersiveModePage wide mode row keeps Electron voice slot', (
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
      _ImmersiveModeTestApp(
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
    'ImmersiveModePage wide mute keeps Electron active volume button',
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
        _ImmersiveModeTestApp(
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
      expect(
        volumeDecoration().color,
        const Color(0x1a0078d7).withValues(alpha: 0),
      );
    },
  );

  testWidgets(
    'ImmersiveModePage wide footer uses Electron 0.9fr side columns',
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
        _ImmersiveModeTestApp(
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
              of: find.byKey(const ValueKey('ImmersiveMode.PlayerBarOpacity')),
              matching: find.byType(Positioned),
            )
            .first,
      );
      expect(playerBarPosition.left, 0);
      expect(playerBarPosition.right, 0);
      expect(playerBarPosition.bottom, 0);
      expect(playerBarPosition.height, 120);
      final playerBarOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('ImmersiveMode.PlayerBarOpacity')),
      );
      expect(playerBarOpacity.opacity, 1);
      expect(playerBarOpacity.duration, const Duration(milliseconds: 180));
      expect(playerBarOpacity.curve, Curves.ease);
      final playerBarSlide = tester.widget<AnimatedSlide>(
        find.byKey(const ValueKey('ImmersiveMode.PlayerBarSlide')),
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
      expect(frameGlass.settings?.blur, 46);
      expect(frameGlass.settings?.saturation, 1.65);
      expect(frameBorder.top, isNot(BorderSide.none));
      expect(frameBorder.top.color, MediaControlColors.playerBorder);
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
            color: MediaControlColors.playerShadow,
            offset: Offset(0, 18),
            blurRadius: 48,
          ),
        ],
      );
      final frameBackgroundDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBackground')),
      );
      final frameBackground =
          frameBackgroundDecoration.decoration as BoxDecoration;
      expect(frameBackground.color, MediaControlColors.playerSurfaceSolid);
      expect(frameBackground.gradient, isNull);
      final frameInsetHighlight = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameInsetHighlight')),
      );
      expect(frameInsetHighlight.color, Colors.transparent);
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
        playDecoration.border,
        Border.all(color: MediaControlColors.accentBorder),
      );
      expect(playDecoration.boxShadow, const [
        BoxShadow(
          color: MediaControlColors.accentShadow,
          offset: Offset(0, 12),
          blurRadius: 24,
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
        const Color(0x240078d7),
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
      expect(volumeTooltipDecoration.color, const Color(0xf5ffffff));
      expect(
        volumeTooltipDecoration.border,
        Border.all(color: const Color(0x1a323e4e)),
      );
      expect(volumeTooltipDecoration.boxShadow, const [
        BoxShadow(
          color: Color(0x2e2a384e),
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
        MediaControlColors.textStrong,
      );
      final volumeTooltipArrow = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('VolumeSlider.TooltipArrow')),
      );
      final volumeTooltipArrowBorder =
          (volumeTooltipArrow.decoration as BoxDecoration).border! as Border;
      expect(volumeTooltipArrowBorder.right.color, const Color(0x1a323e4e));
      expect(volumeTooltipArrowBorder.bottom.color, const Color(0x1a323e4e));
      expect(volumeTooltipArrowBorder.top, BorderSide.none);
      expect(volumeTooltipArrowBorder.left, BorderSide.none);
      await volumeMouse.removePointer();
    },
  );

  testWidgets(
    'ImmersiveModePage night footer uses Electron full-page frame colors',
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
        _ImmersiveModeTestApp(
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
      expect(frameGlass.settings?.blur, 46);
      expect(frameGlass.settings?.saturation, 1.65);

      final frameBorderDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
      );
      final frameBorder =
          (frameBorderDecoration.decoration as BoxDecoration).border! as Border;
      expect(frameBorder.top.color, MediaControlColors.nightPlayerBorder);
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
      expect(frameInsetHighlight.color, Colors.transparent);
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
    'ImmersiveModePage favorite active style follows Electron day and night',
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
          _ImmersiveModeTestApp(
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
        expect(
          favoriteDecoration().color,
          expectedHoverColor.withValues(alpha: 0),
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
    'ImmersiveModePage night exit overlay stays visible on hover like Electron',
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
        _ImmersiveModeTestApp(
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
          of: find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
          matching: find.byKey(const ValueKey('ImmersiveMode.ExitAlbumSwatch')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
          matching: find.byType(SongArtwork),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
          matching: find.text('Blue Song'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
          matching: find.text('Artist A'),
        ),
        findsNothing,
      );
      BoxDecoration exitShellDecoration() =>
          tester
                  .widget<AnimatedContainer>(
                    find.byKey(
                      const ValueKey('ImmersiveMode.ExitArtworkShell'),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      BoxDecoration exitOverlayDecoration() =>
          tester
                  .widget<DecoratedBox>(
                    find.byKey(
                      const ValueKey('ImmersiveMode.ExitArtworkOverlay'),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      AnimatedContainer exitShell() => tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
      );

      expect(exitOverlayDecoration().color, const Color(0x6b080c12));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
          matching: find.byKey(
            const ValueKey('ImmersiveMode.ExitArtworkBackdrop'),
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
          find.byKey(const ValueKey('ImmersiveMode.ExitIcon')),
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
          find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
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
    'ImmersiveModePage keeps wide layout with compact menu at 780px',
    (tester) async {
      tester.view.physicalSize = const Size(760, 760);
      tester.view.devicePixelRatio = 1;
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.never),
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        resetSmPlayerGlobalSettingsSnapshot();
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
      mediaController.syncPlaybackProgress(12, durationSeconds: 120);

      await tester.pumpWidget(
        _ImmersiveModeTestApp(
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
        find.byKey(const ValueKey('ImmersiveMode.BackIcon')),
        findsNothing,
      );
      expect(
        tester
            .widget<IconTheme>(
              find
                  .ancestor(
                    of: find.byKey(const ValueKey('ImmersiveMode.QueueIcon')),
                    matching: find.byType(IconTheme),
                  )
                  .first,
            )
            .data
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
              find.byKey(const ValueKey('ImmersiveMode.ExitArtworkShell')),
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
      expect(frameBorder.top.color, MediaControlColors.compactPlayerBorder);
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
            color: MediaControlColors.compactPlayerShadow,
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
      expect(frameBackground.color, MediaControlColors.playerSurfaceSolid);
      expect(frameBackground.gradient, isNull);
      final frameInsetHighlight = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameInsetHighlight')),
      );
      expect(frameInsetHighlight.color, Colors.transparent);
      final queueButtonFinder = find.ancestor(
        of: find.byKey(const ValueKey('ImmersiveMode.QueueLabel')),
        matching: find.byType(SmPlayerTextIconButton),
      );
      SmPlayerTextIconButton queueButton() =>
          tester.widget<SmPlayerTextIconButton>(queueButtonFinder);
      expect(queueButton().borderRadius, 12);
      expect(queueButton().active, isFalse);

      await tester.tap(queueButtonFinder);
      await tester.pump();
      expect(queueButton().active, isTrue);
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();

      await tester.drag(
        find.byKey(const ValueKey('ImmersiveMode.LyricsStage')),
        const Offset(0, -90),
      );
      await tester.pump();
      final lyricStageRect = tester.getRect(
        find.byKey(const ValueKey('ImmersiveMode.LyricsStage')),
      );
      final seekButtonRect = tester.getRect(
        find.byKey(const ValueKey('ImmersiveMode.LyricSeekButton')),
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
    'ImmersiveModePage night compact footer follows Electron nav-minimal cascade',
    (tester) async {
      tester.view.physicalSize = const Size(760, 760);
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
        _ImmersiveModeTestApp(
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
      expect(frameGlass.settings?.blur, 46);
      expect(frameGlass.settings?.saturation, 1.65);

      final frameBorderDecoration = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
      );
      final frameBorder =
          (frameBorderDecoration.decoration as BoxDecoration).border! as Border;
      expect(frameBorder.top.color, MediaControlColors.nightPlayerBorder);
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
      expect(frameBackground.color, MediaControlColors.nightPlayerSurface);
      expect(frameBackground.gradient, isNull);
      expect(
        find.byKey(const ValueKey('MediaControl.PlayerCompactBaseGradient')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MediaControl.PlayerCompactCoverGradient')),
        findsNothing,
      );

      final frameInsetHighlight = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('MediaControl.PlayerFrameInsetHighlight')),
      );
      expect(frameInsetHighlight.color, Colors.transparent);
    },
  );

  testWidgets('ImmersiveModePage favorite button updates current song', (
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
      _ImmersiveModeTestApp(
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

  testWidgets('ImmersiveModePage more menu opens before preference refresh', (
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
      _ImmersiveModeTestApp(
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

  testWidgets('ImmersiveModePage compact More menu opens above footer button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
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
    );

    await tester.pumpWidget(
      _ImmersiveModeTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeNowPlayingRepository(_snapshot),
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    final moreButton = find.byKey(const ValueKey('MediaControl.MoreButton'));
    await tester.tap(moreButton);
    await tester.pumpAndSettle();

    final moreRect = tester.getRect(moreButton);
    final panelRect = tester.getRect(
      find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
    );
    expect(panelRect.bottom, moreOrLessEquals(moreRect.top - 8, epsilon: 1));
  });

  testWidgets(
    'ImmersiveModePage wide More matches Electron queue and current song items',
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
        _ImmersiveModeTestApp(
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
      expect(find.text('Save Playlist'), findsNothing);
      expect(find.text('Clear Now Playing'), findsNothing);
      expect(find.byKey(const ValueKey('add-to')), findsOneWidget);
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
      expect(find.text('Save Playlist'), findsNothing);
      expect(find.text('Clear Now Playing'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('add-to')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('add-to-now-playing')), findsNothing);
      expect(find.text('My Favorites'), findsOneWidget);
      expect(find.text('New Playlist'), findsOneWidget);
      expect(find.text('Mix'), findsOneWidget);
      expect(find.text('Built in'), findsNothing);
    },
  );

  testWidgets('ImmersiveModePage More Play Artist uses sidebar artist icon', (
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
      _ImmersiveModeTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();

    expect(find.text('Play Artist'), findsOneWidget);
    expect(find.byIcon(FluentIcons.people_24_regular), findsOneWidget);
    expect(find.byIcon(FluentIcons.people_20_regular), findsNothing);
  });

  testWidgets('ImmersiveModePage More Play Artist and Album replace queue', (
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
      _ImmersiveModeTestApp(
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
    'ImmersiveModePage Add To Now Playing undo removes inserted range',
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
          const LibrarySong(
            id: 3,
            path: r'C:\Music\green.mp3',
            title: 'Green Song',
            artist: 'Artist C',
            artists: ['Artist C'],
            album: 'Green Hour',
            duration: 140,
            playCount: 0,
            lyricsOffsetMs: 0,
            dateAdded: '2026-05-22T00:00:00',
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
          id: 3,
          title: 'Green Song',
          artist: 'Artist C',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        durationSeconds: 140,
        queueIndex: null,
      );

      await tester.pumpWidget(
        _ImmersiveModeTestApp(
          snapshot: snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-to')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-to-now-playing')));
      await tester.pumpAndSettle();

      expect(repository.snapshot.nowPlaying.songIds, [1, 2, 1, 3]);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(repository.snapshot.nowPlaying.songIds, [1, 2, 1]);
    },
  );

  testWidgets(
    'ImmersiveModePage More disables Random Play when queue and library are empty',
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
        _ImmersiveModeTestApp(
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
    'ImmersiveModePage compact More includes Electron utility substitutes',
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
        _ImmersiveModeTestApp(
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
      expect(find.text('Save Playlist'), findsNothing);
      expect(find.text('Clear Now Playing'), findsNothing);

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

      expect(checkedFor('List'), isFalse);
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
    'ImmersiveModePage compact mode context menu opens like Electron',
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
        _ImmersiveModeTestApp(
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

  testWidgets('ImmersiveModePage compact mode cycles in Electron order', (
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
      _ImmersiveModeTestApp(
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
    'ImmersiveModePage compact mode menu checks current Electron item',
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
        _ImmersiveModeTestApp(
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
      expect(checkedFor('Repeat'), isFalse);
      expect(checkedFor('Repeat One'), isFalse);
    },
  );

  testWidgets('ImmersiveModePage compact mode long press opens Electron menu', (
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
      _ImmersiveModeTestApp(
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
      find.ancestor(of: modeTooltip, matching: find.byType(HoldReleaseAction)),
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
  });

  testWidgets(
    'ImmersiveModePage compact More disables Favorite without current song',
    (tester) async {
      tester.view.physicalSize = const Size(500, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeNowPlayingRepository(_snapshot);

      await tester.pumpWidget(
        _ImmersiveModeTestApp(
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
    'ImmersiveModePage Clear Now Playing keeps fullscreen and clears queue',
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
        _ImmersiveModeTestApp(
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

      await tester.tap(find.byKey(const ValueKey('ImmersiveMode.QueueLabel')));
      await tester.pump(const Duration(milliseconds: 320));
      expect(
        find.byKey(const ValueKey('ImmersiveMode.QueueSavePlaylistButton')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('ImmersiveMode.QueueClearNowPlayingButton')),
      );
      await tester.pump();

      expect(exitCalls, 0);
      expect(repository.snapshot.nowPlaying.songIds, isEmpty);
      expect(
        find.byKey(const ValueKey('ImmersiveMode.QueueLabel')),
        findsOneWidget,
      );
    },
  );

  testWidgets('ImmersiveModePage exit button follows Electron close action', (
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
      _ImmersiveModeTestApp(
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

    expect(exitCalls, 0);
    expect(find.byType(ImmersiveModePage), findsNothing);
    expect(find.byTooltip('Exit immersive mode'), findsNothing);
    expect(find.text('Previous Page'), findsOneWidget);
  });

  testWidgets(
    'ImmersiveModePage queue context menu opens before preference refresh',
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
        _ImmersiveModeTestApp(
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
      expect(find.text('Play Next'), findsNothing);
      expect(find.text('Add To'), findsWidgets);

      repository.completePreference(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'ImmersiveModePage queue context Add To omits builtin Now Playing target',
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
        _ImmersiveModeTestApp(
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

      expect(find.byKey(const ValueKey('add-to-now-playing')), findsNothing);
      expect(
        find.text('Now Playing').evaluate().length,
        nowPlayingTextCountBeforeMenu + 1,
      );
    },
  );

  testWidgets('ImmersiveModePage more view dialog pins player bar', (
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
      _ImmersiveModeTestApp(
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

    expect(_hasPlayerBarOpacity(tester, 0), isTrue);
  });

  testWidgets('ImmersiveModePage queue view opens dialog and closes panel', (
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
      _ImmersiveModeTestApp(
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

  testWidgets('ImmersiveModePage multi-select play preserves queue order', (
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
      _ImmersiveModeTestApp(
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
    await tester.pump(const Duration(milliseconds: 220));

    expect(repository.snapshot.nowPlaying.songIds, [1, 2]);
    expect(mediaController.state.track.id, 1);
    expect(mediaController.state.selectedQueueIndex, 0);
  });

  testWidgets('ImmersiveModePage context Select resets selection to row', (
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
      _ImmersiveModeTestApp(
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

  testWidgets('ImmersiveModePage current queue row tap keeps playing', (
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
      _ImmersiveModeTestApp(
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

  testWidgets('ImmersiveModePage multi-select remove clears selection', (
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
      _ImmersiveModeTestApp(
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
    expect(
      find.byKey(const ValueKey('MultiSelectCommandBar.MoreButton')),
      findsNothing,
    );
    final commandBarRect = tester.getRect(
      find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
    );
    expect(commandBarRect.left, 0);
    expect(commandBarRect.width, 2200);
    expect(commandBarRect.bottom, 900);

    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();

    expect(repository.snapshot.nowPlaying.songIds, [2]);
    expect(mediaController.state.track.id, 1);
    expect(mediaController.state.selectedQueueIndex, isNull);
    expect(mediaController.state.isPlaying, isFalse);
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
    'ImmersiveModePage current playing remove undo does not duplicate song',
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
        queueIndex: 0,
      );

      await tester.pumpWidget(
        _ImmersiveModeTestApp(
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

      await tester.tap(blueRow.first, buttons: kSecondaryMouseButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.tap(find.text('Remove').last);
      await tester.pump();

      expect(repository.snapshot.nowPlaying.songIds, [2]);
      expect(mediaController.state.track.id, 2);
      expect(mediaController.state.selectedQueueIndex, 0);
      expect(mediaController.state.isPlaying, isTrue);

      await tester.tap(find.text('Undo'));
      await tester.pump();

      expect(repository.snapshot.nowPlaying.songIds, [1, 2]);
      expect(mediaController.state.track.id, 2);
      expect(mediaController.state.selectedQueueIndex, 1);
      expect(mediaController.state.isPlaying, isTrue);
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'ImmersiveModePage multi-select favorites respects hide preference',
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
        _ImmersiveModeTestApp(
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
    'ImmersiveModePage multi-select playlist Add To respects hide preference',
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
        _ImmersiveModeTestApp(
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
      await tester.tap(find.text('Mix'));
      await tester.pumpAndSettle();

      expect(repository.playlistSongIds[10], [1]);
      expect(find.text('1 selected'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'ImmersiveModePage queue panel does not raise or pin player bar',
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
        _ImmersiveModeTestApp(
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
        find.byKey(const ValueKey('ImmersiveMode.QueuePopoverHost')),
      );
      final playerBarLayer = positionedLayerOf(
        find.byKey(const ValueKey('ImmersiveMode.PlayerBarOpacity')),
      );
      expect(queueLayer.parent, same(playerBarLayer.parent));
      final stack = queueLayer.parent! as RenderStack;
      expect(
        stackPaintIndex(stack, playerBarLayer),
        greaterThan(stackPaintIndex(stack, queueLayer)),
      );
      expect(_hasPlayerBarOpacity(tester, 0), isTrue);
      final playerBarOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('ImmersiveMode.PlayerBarOpacity')),
      );
      expect(playerBarOpacity.duration, const Duration(milliseconds: 180));
      expect(playerBarOpacity.curve, Curves.ease);
      final playerBarSlide = tester.widget<AnimatedSlide>(
        find.byKey(const ValueKey('ImmersiveMode.PlayerBarSlide')),
      );
      expect(playerBarSlide.duration, const Duration(milliseconds: 260));
      expect(playerBarSlide.curve, const Cubic(0.2, 0, 0, 1));
      expect(playerBarSlide.offset, const Offset(0, 1));
      final idleFrameRect = tester.getRect(
        find.byKey(const ValueKey('MediaControl.PlayerFrameBorder')),
      );
      expect(idleFrameRect.top, 900);
      expect(idleFrameRect.bottom, 1020);
    },
  );

  testWidgets('ImmersiveModePage queue panel animates in from hidden offset', (
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
      _ImmersiveModeTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Now Playing').first);
    await tester.pump();

    AnimatedSlide queueSlide() {
      return tester.widget<AnimatedSlide>(
        find.byKey(const ValueKey('ImmersiveMode.QueuePopoverSlide')),
      );
    }

    AnimatedOpacity queueOpacity() {
      return tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('ImmersiveMode.QueuePopoverOpacity')),
      );
    }

    expect(queueSlide().offset, const Offset(1.08, 0));
    expect(queueOpacity().opacity, 0);

    await tester.pump();

    expect(queueSlide().offset, Offset.zero);
    expect(queueOpacity().opacity, 1);
  });

  testWidgets(
    'ImmersiveModePage compact queue follows Electron z-index above footer',
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
        _ImmersiveModeTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Now Playing').first);
      await tester.pump(const Duration(milliseconds: 300));
      final queueCloseIcon = find.descendant(
        of: find.byKey(const ValueKey('ImmersiveMode.QueueCloseButton')),
        matching: find.byType(Icon),
      );
      expect(
        tester.widget<Icon>(queueCloseIcon).icon,
        FluentIcons.chevron_down_20_regular,
      );

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
        find.byKey(const ValueKey('ImmersiveMode.QueuePopoverHost')),
      );
      final playerBarLayer = positionedLayerOf(
        find.byKey(const ValueKey('ImmersiveMode.PlayerBarOpacity')),
      );
      expect(queueLayer.parent, same(playerBarLayer.parent));
      final stack = queueLayer.parent! as RenderStack;
      expect(
        stackPaintIndex(stack, queueLayer),
        greaterThan(stackPaintIndex(stack, playerBarLayer)),
      );
    },
  );

  testWidgets('ImmersiveModePage More pins player bar while menu is open', (
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
      _ImmersiveModeTestApp(
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

    expect(_hasPlayerBarOpacity(tester, 0), isTrue);
  });

  testWidgets('ImmersiveModePage keeps player bar raised while pointer stays', (
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
      _ImmersiveModeTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeNowPlayingRepository(_snapshot),
        mediaController: mediaController,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 260));
    expect(_hasPlayerBarOpacity(tester, 0), isTrue);

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
  });

  testWidgets(
    'ImmersiveModePage empty queue panel omits header like Electron',
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
        _ImmersiveModeTestApp(
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

  testWidgets('ImmersiveModePage empty loading queue shows compact loading', (
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
      _ImmersiveModeTestApp(
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

  testWidgets('ImmersiveModePage queue rows reuse default artwork fallback', (
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
      _ImmersiveModeTestApp(
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
    'ImmersiveModePage displays current track instead of selected queue index',
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
        _ImmersiveModeTestApp(
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

  testWidgets('ImmersiveModePage falls back to playback track like Electron', (
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
      _ImmersiveModeTestApp(
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

  testWidgets('ImmersiveModePage opens queue centered on current row', (
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
      _ImmersiveModeTestApp(
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
      find.byKey(const ValueKey('ImmersiveMode.QueueList')),
    );
    expect(
      queueLists.any((list) => (list.controller?.offset ?? 0) > 1500),
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('now-playing-full-row-31-30')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ImmersiveModePage),
        matching: find.byKey(const ValueKey('ImmersiveMode.QueueScrollbar')),
      ),
      findsOneWidget,
    );
    final queueScrollbar = tester.widget<Scrollbar>(
      find.byKey(const ValueKey('ImmersiveMode.QueueScrollbar')),
    );
    expect(queueScrollbar.thumbVisibility, isNull);
  });

  testWidgets('ImmersiveModePage queue song click keeps scroll position', (
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
      _ImmersiveModeTestApp(
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

    final queueList = tester.widget<ListView>(
      find.byKey(const ValueKey('ImmersiveMode.QueueList')),
    );
    final controller = queueList.controller!;
    controller.jumpTo(780);
    await tester.pump();
    final beforeOffset = controller.offset;

    mediaController.playTrack(
      const MediaControlTrack(
        id: 19,
        title: 'Queue Song 19',
        artist: 'Artist',
        artworkUrl: '',
        isLoading: false,
        favorite: false,
      ),
      durationSeconds: 120,
      queueIndex: 18,
    );
    await tester.pump();
    await tester.pump();

    expect(mediaController.state.track.id, 19);
    expect(mediaController.state.selectedQueueIndex, 18);
    expect(controller.offset, beforeOffset);
  });

  test('ImmersiveModePage reorders queue downward like Electron', () {
    expect(reorderImmersiveModeQueueSongIds(const [1, 2, 3], 0, 2), [2, 1, 3]);
    expect(reorderImmersiveModeQueueSongIds(const [1, 2, 3], 2, 0), [3, 1, 2]);
    expect(moveImmersiveModeQueueSongIds(const [1, 2, 3, 4], 0, 2, true), [
      2,
      3,
      1,
      4,
    ]);
    expect(moveImmersiveModeQueueSongIds(const [1, 2, 3, 4], 3, 1, false), [
      1,
      4,
      2,
      3,
    ]);
  });

  test('ImmersiveModePage play next queue matches Electron helper', () {
    expect(playNextImmersiveModeQueueSongIds(const [1, 2, 3], 9, 2, -1, 1), [
      1,
      2,
      9,
      3,
    ]);
    expect(playNextImmersiveModeQueueSongIds(const [1, 2, 3, 4], 2, 4, 1, 3), [
      1,
      3,
      4,
      2,
    ]);
    expect(playNextImmersiveModeQueueSongIds(const [1, 2, 3, 4], 4, 2, 3, 1), [
      1,
      2,
      4,
      3,
    ]);
    expect(
      playNextImmersiveModeQueueSongIds(const [1, 2, 3, 4], 1, 3, 0, null),
      [2, 3, 1, 4],
    );
    expect(playNextImmersiveModeQueueSongIds(const [1, 2, 3], 2, 2, 1, 1), [
      1,
      3,
      2,
    ]);
  });

  test('ImmersiveModePage lyric seek time matches Electron formatter', () {
    expect(formatImmersiveModeLyricSeekTime(65), '1:05');
    expect(formatImmersiveModeLyricSeekTime(3661), '1:01:01');
  });

  testWidgets('ImmersiveModePage scrolls to active lyric after loading', (
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
      _ImmersiveModeTestApp(
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
      find.byKey(const ValueKey('ImmersiveMode.LyricsList')),
    );
    expect((lyricsList.padding! as EdgeInsets).bottom, 32);
    expect(find.text('Lyric line 8'), findsOneWidget);
    expect(lyricsList.controller?.offset, greaterThan(180));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ImmersiveMode.LyricsStage')),
        matching: find.byType(RawScrollbar),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'ImmersiveModePage plain lyrics stay on first line without duration',
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
        _ImmersiveModeTestApp(
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

  testWidgets('ImmersiveModePage lyric rows do not seek on tap', (
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
    mediaController.syncPlaybackProgress(12, durationSeconds: 120);

    await tester.pumpWidget(
      _ImmersiveModeTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.drag(
      find.byKey(const ValueKey('ImmersiveMode.LyricsStage')),
      const Offset(0, -90),
    );
    await tester.pump();

    final seekButton = tester.widget<SmPlayerTextIconButton>(
      find.byKey(const ValueKey('ImmersiveMode.LyricSeekButton')),
    );
    expect(seekButton.borderRadius, 999);
    expect(seekButton.height, 34);
    expect(seekButton.horizontalPadding, 12);
    expect(seekButton.verticalPadding, 0);
    expect(seekButton.tooltipEnabled, isFalse);
    expect(seekButton.glassSettings, immersiveModeTopButtonGlassSettings);
    expect(find.byTooltip(seekButton.label), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('ImmersiveMode.LyricSeekButton')))
          .height,
      greaterThanOrEqualTo(34),
    );
    final seekButtonGlass = tester.widget<GlassContainer>(
      find
          .descendant(
            of: find.byWidget(seekButton),
            matching: find.byType(GlassContainer),
          )
          .first,
    );
    expect(seekButtonGlass.useOwnLayer, isTrue);
    expect(seekButtonGlass.quality, GlassQuality.minimal);
    expect(seekButtonGlass.shape, isA<LiquidRoundedRectangle>());
    expect(seekButtonGlass.settings?.blur, 46);
    expect(seekButtonGlass.settings?.thickness, 24);
    expect(seekButtonGlass.settings?.refractiveIndex, 1.06);
    expect(seekButtonGlass.settings?.saturation, 1.9);
    expect(seekButtonGlass.settings?.lightIntensity, 0.16);
    expect(seekButtonGlass.settings?.ambientStrength, 0.12);
    expect(seekButtonGlass.settings?.glowIntensity, 0.1);
    expect(seekButtonGlass.settings?.glassColor, const Color(0x52ffffff));
    expect(seekButtonGlass.settings?.standardOpacityMultiplier, 0.5);

    final seekButtonRect = tester.getRect(
      find.byKey(const ValueKey('ImmersiveMode.LyricSeekButton')),
    );
    final seekButtonEdgePoint = Offset(
      seekButtonRect.center.dx,
      seekButtonRect.top + 4,
    );
    final seekButtonHover = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await seekButtonHover.addPointer();
    await seekButtonHover.moveTo(seekButtonEdgePoint);
    await tester.pump();
    final hoveredSeekButtonDecoration =
        tester
                .widgetList<DecoratedBox>(
                  find.descendant(
                    of: find.byWidget(seekButton),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .last
                .decoration
            as BoxDecoration;
    expect(hoveredSeekButtonDecoration.color, const Color(0x1a0078d7));
    expect(
      hoveredSeekButtonDecoration.border,
      Border.all(color: const Color(0x2e768499)),
    );
    await tester.pump(const Duration(seconds: 6));
    expect(
      find.byKey(const ValueKey('ImmersiveMode.LyricSeekButton')),
      findsOneWidget,
    );

    mediaController.setPlaybackActive(false);
    await tester.pump();
    await tester.tap(find.text('Lyric line 2'));
    await tester.pump();

    expect(mediaController.state.progressSeconds, 12);
    expect(mediaController.state.isPlaying, isFalse);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ImmersiveMode.LyricSeekButton')),
        matching: find.text(seekButton.label),
      ),
      findsWidgets,
    );

    final seekSeconds = _durationTextToSeconds(seekButton.label);
    await tester.tapAt(seekButtonEdgePoint);
    await tester.pump();
    await seekButtonHover.removePointer();

    expect(mediaController.state.progressSeconds, seekSeconds);
    expect(mediaController.state.isPlaying, isTrue);
    expect(mediaController.state.playbackStatus, PlaybackStatus.seeking);
  });

  testWidgets(
    'ImmersiveModePage compact lyric seek hover covers Electron overflow area',
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
      mediaController.syncPlaybackProgress(12, durationSeconds: 120);

      await tester.pumpWidget(
        _ImmersiveModeTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.drag(
        find.byKey(const ValueKey('ImmersiveMode.LyricsStage')),
        const Offset(0, -90),
      );
      await tester.pump();

      final lyricStageRect = tester.getRect(
        find.byKey(const ValueKey('ImmersiveMode.LyricsStage')),
      );
      final seekButtonRect = tester.getRect(
        find.byKey(const ValueKey('ImmersiveMode.LyricSeekButton')),
      );
      expect(lyricStageRect.width, 360);
      expect(seekButtonRect.right, greaterThan(lyricStageRect.right));
      final overflowHoverPoint = Offset(
        lyricStageRect.right + 8,
        seekButtonRect.center.dy,
      );
      expect(overflowHoverPoint.dx, lessThan(seekButtonRect.right));
      final seekButtonHover = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await seekButtonHover.addPointer();
      await seekButtonHover.moveTo(overflowHoverPoint);
      await tester.pump();

      final hoveredSeekButtonDecoration =
          tester
                  .widgetList<DecoratedBox>(
                    find.descendant(
                      of: find.byKey(
                        const ValueKey('ImmersiveMode.LyricSeekButton'),
                      ),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .last
                  .decoration
              as BoxDecoration;
      expect(hoveredSeekButtonDecoration.color, const Color(0x1a0078d7));
      expect(
        hoveredSeekButtonDecoration.border,
        Border.all(color: const Color(0x2e768499)),
      );
      await seekButtonHover.removePointer();
    },
  );

  testWidgets('ImmersiveModePage lyric seek uses top button night style', (
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
    );
    mediaController.syncPlaybackProgress(12, durationSeconds: 120);

    await tester.pumpWidget(
      _ImmersiveModeTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _LongLyricsRepository(_snapshot),
        mediaController: mediaController,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.drag(
      find.byKey(const ValueKey('ImmersiveMode.LyricsStage')),
      const Offset(0, -90),
    );
    await tester.pump();

    final seekButton = tester.widget<SmPlayerTextIconButton>(
      find.byKey(const ValueKey('ImmersiveMode.LyricSeekButton')),
    );
    expect(seekButton.borderRadius, 999);
    expect(seekButton.height, 34);
    expect(seekButton.verticalPadding, 0);
    expect(seekButton.glassSettings, immersiveModeTopButtonNightGlassSettings);
    final queueButton = tester.widget<SmPlayerTextIconButton>(
      find.ancestor(
        of: find.byKey(const ValueKey('ImmersiveMode.QueueLabel')),
        matching: find.byType(SmPlayerTextIconButton),
      ),
    );
    final queueButtonDecoration =
        tester
                .widgetList<DecoratedBox>(
                  find.descendant(
                    of: find.byWidget(queueButton),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .last
                .decoration
            as BoxDecoration;
    final seekButtonDecoration =
        tester
                .widgetList<DecoratedBox>(
                  find.descendant(
                    of: find.byWidget(seekButton),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .last
                .decoration
            as BoxDecoration;
    expect(seekButtonDecoration.color, queueButtonDecoration.color);
    expect(seekButtonDecoration.border, queueButtonDecoration.border);
    final seekButtonForeground =
        tester
            .widget<IconTheme>(
              find
                  .descendant(
                    of: find.byWidget(seekButton),
                    matching: find.byType(IconTheme),
                  )
                  .first,
            )
            .data
            .color;
    expect(seekButtonForeground, const Color(0xe0ffffff));
  });
}

class _NowPlayingTestApp extends StatelessWidget {
  const _NowPlayingTestApp({
    required this.snapshot,
    required this.i18n,
    this.repository,
    this.mediaController,
    this.searchQuery = '',
  });

  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final _FakeNowPlayingRepository? repository;
  final MediaControlController? mediaController;
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
        if (mediaController != null)
          mediaControlControllerProvider.overrideWith(
            (ref) => mediaController!,
          ),
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

class _ImmersiveModeTestApp extends StatelessWidget {
  const _ImmersiveModeTestApp({
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
    GoRouter? router;
    final app =
        useRouter
            ? MaterialApp.router(
              theme: buildSmPlayerTheme(themeSettings),
              routerConfig:
                  router = GoRouter(
                    initialLocation: '/immersive-mode',
                    routes: [
                      GoRoute(
                        path: '/immersive-mode',
                        builder:
                            (context, state) =>
                                const Scaffold(body: ImmersiveModePage()),
                      ),
                      GoRoute(
                        path: '/now-playing',
                        builder:
                            (context, state) =>
                                const Scaffold(body: SizedBox.shrink()),
                      ),
                      GoRoute(
                        path: '/previous',
                        builder:
                            (context, state) =>
                                const Scaffold(body: Text('Previous Page')),
                      ),
                    ],
                  ),
            )
            : MaterialApp(
              theme: buildSmPlayerTheme(themeSettings),
              home: const Scaffold(body: ImmersiveModePage()),
            );
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryRepositoryProvider.overrideWithValue(repository),
        mediaControlControllerProvider.overrideWith((ref) => mediaController),
        smPlayerShellActionsProvider.overrideWithValue(
          shellActions == null
              ? null
              : SmPlayerShellActions(
                onOpenVoiceAssistant: shellActions!.onOpenVoiceAssistant,
                onExitWindowFullScreen: shellActions!.onExitWindowFullScreen,
                onExitImmersiveMode:
                    shellActions!.onExitImmersiveMode ??
                    (router == null
                        ? null
                        : () {
                          router!.go('/previous');
                        }),
                onNavigate: shellActions!.onNavigate,
              ),
        ),
      ],
      child: SmPlayerI18nScope(i18n: i18n, child: app),
    );
  }
}

double _durationTextToSeconds(String text) {
  final parts = text.split(':');
  return double.parse(parts[0]) * 60 + double.parse(parts[1]);
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
  var replaceNowPlayingCount = 0;

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
    replaceNowPlayingCount += 1;
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
  final inlineAddTo = find.text('Add To').hitTestable();
  if (inlineAddTo.evaluate().isNotEmpty) {
    await tester.tap(inlineAddTo.first);
    await tester.pumpAndSettle();
    return;
  }

  await tester.tap(find.byTooltip('More').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add To').hitTestable().first);
  await tester.pumpAndSettle();
}

Future<void> _selectBlueSongInNowPlayingMultiSelect(WidgetTester tester) async {
  await tester.tap(
    find
        .descendant(
          of: find.byType(PlaylistControlItem),
          matching: find.text('Blue Song'),
        )
        .first,
    buttons: kSecondaryMouseButton,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Select'));
  await tester.pumpAndSettle();
}

bool _hasPlayerBarOpacity(WidgetTester tester, double opacity) {
  return tester
      .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
      .any((widget) => widget.opacity == opacity);
}
