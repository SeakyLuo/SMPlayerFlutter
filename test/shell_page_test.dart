import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smplayer_flutter/src/app/shell_page.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LyricsRequestMode;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('shell matches Electron navigation breakpoints', () {
    expect(
      SmPlayerShellMetrics.navigationModeForWidth(719),
      SmPlayerNavigationMode.minimal,
    );
    expect(
      SmPlayerShellMetrics.navigationModeForWidth(720),
      SmPlayerNavigationMode.overlay,
    );
    expect(
      SmPlayerShellMetrics.navigationModeForWidth(1199),
      SmPlayerNavigationMode.overlay,
    );
    expect(
      SmPlayerShellMetrics.navigationModeForWidth(1200),
      SmPlayerNavigationMode.wide,
    );
  });

  test('compareAppVersions mirrors Electron version ordering', () {
    expect(compareAppVersions('1.2.0', '1.1.9'), greaterThan(0));
    expect(compareAppVersions('1.0', '1.0.0'), 0);
    expect(compareAppVersions('1.0.0', '1.0.1'), lessThan(0));
  });

  test('resolvePlayerArtistRouteName mirrors Electron artist splitting', () {
    const i18n = SmPlayerI18n(
      locale: 'en-US',
      messages: {'common.artistUnknown': 'Unknown Artist'},
    );
    const song = LibrarySong(
      id: 1,
      path: '/tmp/song.mp3',
      title: 'Song',
      artist: 'Alpha; Beta',
      artists: [],
      album: 'Album',
      duration: 100,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '',
      favorite: false,
      thumbnailPath: '',
    );

    expect(resolvePlayerArtistRouteName(song, i18n), 'Alpha');
    expect(
      resolvePlayerArtistRouteName(
        const LibrarySong(
          id: 2,
          path: '/tmp/song2.mp3',
          title: 'Song 2',
          artist: 'Fallback',
          artists: ['Primary', 'Secondary'],
          album: 'Album',
          duration: 100,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '',
          favorite: false,
          thumbnailPath: '',
        ),
        i18n,
      ),
      'Primary',
    );
    expect(
      resolvePlayerArtistRouteName(
        const LibrarySong(
          id: 3,
          path: '/tmp/song3.mp3',
          title: 'Song 3',
          artist: '',
          artists: [],
          album: 'Album',
          duration: 100,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '',
          favorite: false,
          thumbnailPath: '',
        ),
        i18n,
      ),
      'Unknown Artist',
    );
  });

  test(
    'resolveQueuePlaybackStartSeconds mirrors Electron loaded-track replay',
    () {
      expect(
        resolveQueuePlaybackStartSeconds(
          currentTrackId: 7,
          nextTrackId: 7,
          currentProgressSeconds: 64,
        ),
        64,
      );
      expect(
        resolveQueuePlaybackStartSeconds(
          currentTrackId: 7,
          nextTrackId: 8,
          currentProgressSeconds: 64,
        ),
        0,
      );
    },
  );

  test('pending seek filter mirrors Electron position-event guard', () {
    expect(
      shouldIgnoreAudioPositionForPendingSeek(
        positionSeconds: 11,
        pendingSeekSeconds: 42,
        toleranceSeconds: 0.25,
      ),
      isTrue,
    );
    expect(
      shouldIgnoreAudioPositionForPendingSeek(
        positionSeconds: 41.8,
        pendingSeekSeconds: 42,
        toleranceSeconds: 0.25,
      ),
      isFalse,
    );
    expect(
      shouldIgnoreAudioPositionForPendingSeek(
        positionSeconds: 11,
        pendingSeekSeconds: null,
        toleranceSeconds: 0.25,
      ),
      isFalse,
    );
  });

  test('nextQueueIndexForPlayback mirrors Electron queue modes', () {
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 1,
        mode: PlaybackMode.once,
        forward: true,
        automatic: false,
      ),
      2,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 2,
        mode: PlaybackMode.once,
        forward: true,
        automatic: true,
      ),
      isNull,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 2,
        mode: PlaybackMode.once,
        forward: true,
        automatic: false,
      ),
      isNull,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 0,
        mode: PlaybackMode.once,
        forward: false,
        automatic: false,
      ),
      isNull,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 2,
        mode: PlaybackMode.repeatOne,
        forward: true,
        automatic: false,
      ),
      isNull,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 2,
        mode: PlaybackMode.repeat,
        forward: true,
        automatic: true,
      ),
      0,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 1,
        mode: PlaybackMode.repeatOne,
        forward: true,
        automatic: true,
      ),
      1,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 1,
        mode: PlaybackMode.shuffle,
        forward: true,
        automatic: true,
      ),
      2,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 2,
        mode: PlaybackMode.shuffle,
        forward: true,
        automatic: true,
      ),
      0,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: 0,
        mode: PlaybackMode.shuffle,
        forward: false,
        automatic: false,
      ),
      2,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: -1,
        mode: PlaybackMode.once,
        forward: true,
        automatic: false,
      ),
      0,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: -1,
        mode: PlaybackMode.once,
        forward: false,
        automatic: false,
      ),
      isNull,
    );
    expect(
      nextQueueIndexForPlayback(
        queueLength: 3,
        currentIndex: -1,
        mode: PlaybackMode.repeat,
        forward: false,
        automatic: false,
      ),
      2,
    );
  });

  test(
    'currentPlaybackQueueIndex mirrors Electron stale queue index fallback',
    () {
      expect(currentPlaybackQueueIndex([10, 20, 30], 20, 1), 1);
      expect(currentPlaybackQueueIndex([10, 20, 30], 20, 0), 1);
      expect(currentPlaybackQueueIndex([10, 20, 30], 99, 0), -1);
      expect(currentPlaybackQueueIndex([10, 20, 30], null, 0), -1);
    },
  );

  test('playback shortcuts mirror Electron shell keys', () {
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.space,
        control: false,
        alt: false,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.togglePlayPause,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.arrowRight,
        control: true,
        alt: false,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.next,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.arrowLeft,
        control: true,
        alt: false,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.previous,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.arrowRight,
        control: false,
        alt: false,
        meta: false,
        shift: true,
      ),
      SmPlayerPlaybackShortcut.seekForwardLong,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.arrowLeft,
        control: false,
        alt: false,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.seekBackwardShort,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.keyS,
        control: false,
        alt: true,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.toggleShuffle,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.keyR,
        control: false,
        alt: true,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.toggleRepeat,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.digit1,
        control: false,
        alt: true,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.toggleRepeatOne,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.arrowRight,
        control: false,
        alt: true,
        meta: false,
        shift: false,
      ),
      isNull,
    );
  });

  testWidgets('shell uses Electron wide layout metrics', (tester) async {
    _setViewSize(tester, const Size(1300, 600));

    await tester.pumpWidget(const _ShellPageTestApp());

    final sidebar = find.byKey(SmPlayerShellKeys.sidebar);
    final workspace = find.byKey(SmPlayerShellKeys.workspace);
    final reservedPlayer = find.byKey(SmPlayerShellKeys.reservedPlayer);

    expect(tester.getSize(sidebar).width, SmPlayerShellMetrics.sidebarWidth);
    expect(
      tester.getSize(sidebar).height,
      600 - SmPlayerShellMetrics.playerHeight,
    );
    expect(tester.getTopLeft(workspace).dx, SmPlayerShellMetrics.sidebarWidth);
    expect(
      tester.getSize(workspace).height,
      600 -
          SmPlayerShellMetrics.playerHeight +
          SmPlayerShellMetrics.playerTopRadius,
    );
    expect(
      tester.getSize(reservedPlayer).height,
      SmPlayerShellMetrics.playerHeight,
    );
  });

  testWidgets('shell collapses navigation to Electron rail width', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.TogglePaneButton')),
    );
    await tester.pumpAndSettle();

    final sidebar = find.byKey(SmPlayerShellKeys.sidebar);
    final workspace = find.byKey(SmPlayerShellKeys.workspace);

    expect(
      tester.getSize(sidebar).width,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
    expect(
      tester.getTopLeft(workspace).dx,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
  });

  testWidgets('overlay navigation opens above the 64px shell rail', (
    tester,
  ) async {
    _setViewSize(tester, const Size(800, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pumpAndSettle();

    final sidebar = find.byKey(SmPlayerShellKeys.sidebar);
    final workspace = find.byKey(SmPlayerShellKeys.workspace);

    expect(tester.getSize(sidebar).width, SmPlayerShellMetrics.sidebarWidth);
    expect(
      tester.getTopLeft(workspace).dx,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
  });

  testWidgets('minimal navigation starts as Electron rail layout', (
    tester,
  ) async {
    _setViewSize(tester, const Size(600, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pump();

    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
    expect(
      tester.getTopLeft(find.byKey(SmPlayerShellKeys.workspace)).dx,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
  });

  testWidgets('navigation mode changes follow Electron collapse rules', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pump();
    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.sidebarWidth,
    );

    _setViewSize(tester, const Size(800, 600), resetAfterTest: false);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );

    _setViewSize(tester, const Size(1300, 600), resetAfterTest: false);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.sidebarWidth,
    );
  });

  testWidgets('shell restores Electron navigation collapsed storage state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SmPlayerShellStorageKeys.navigationCollapsed: true,
    });
    _setViewSize(tester, const Size(800, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
  });

  testWidgets('shell persists navigation collapsed changes', (tester) async {
    _setViewSize(tester, const Size(800, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.TogglePaneButton')),
    );
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(SmPlayerShellStorageKeys.navigationCollapsed),
      isTrue,
    );
  });

  testWidgets('release notes do not open on first install', (tester) async {
    await tester.pumpWidget(
      const _ShellPageTestApp(
        appVersion: '1.0.0',
        messages: _releaseNotesMessages,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Release Notes'), findsNothing);
  });

  testWidgets('shell commits pending deletes during startup', (tester) async {
    final repository = _StartupRepository();

    await tester.pumpWidget(_ShellPageTestApp(repository: repository));
    await tester.pump();

    expect(repository.commitPendingDeletesCount, 1);
  });

  testWidgets('shell restores Electron playback state during startup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SmPlayerSettingsStorageKeys.lastMusicIndex: 1,
      SmPlayerSettingsStorageKeys.musicProgress: 42.0,
      SmPlayerSettingsStorageKeys.autoPlay: false,
      SmPlayerSettingsStorageKeys.saveMusicProgress: true,
    });
    final repository = _SnapshotRepository(
      const MusicLibrarySnapshot(
        songs: [
          LibrarySong(
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
          LibrarySong(
            id: 20,
            path: '/tmp/second.mp3',
            title: 'Second Song',
            artist: 'Second Artist',
            artists: ['Second Artist'],
            album: 'Second Album',
            duration: 240,
            playCount: 0,
            lyricsOffsetMs: 0,
            dateAdded: '',
            favorite: false,
            thumbnailPath: '',
          ),
        ],
        hasLibrary: true,
        sortCriterion: MusicLibrarySortCriterion.title,
        albumsSort: AlbumSortCriterion.defaultSort,
        databasePath: '',
        nowPlaying: NowPlayingSnapshot(playlistId: 1, songIds: [10, 20]),
      ),
    );
    final desktopService = _ShellDesktopFeatureService();

    await tester.pumpWidget(
      _ShellPageTestApp(repository: repository, desktopService: desktopService),
    );
    for (var pump = 0; pump < 6; pump += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final restoredSession = desktopService.mediaSessions.lastWhere(
      (state) => state.active,
    );
    expect(restoredSession.title, 'Second Song');
    expect(restoredSession.playing, isFalse);
    expect(restoredSession.durationSeconds, 240);
    expect(restoredSession.progressSeconds, 42);
  });

  testWidgets('shell restores playback from normalized Electron queue', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SmPlayerSettingsStorageKeys.lastMusicIndex: 0,
      SmPlayerSettingsStorageKeys.musicProgress: 24.0,
      SmPlayerSettingsStorageKeys.autoPlay: false,
      SmPlayerSettingsStorageKeys.saveMusicProgress: true,
    });
    final repository = _SnapshotRepository(
      const MusicLibrarySnapshot(
        songs: [
          LibrarySong(
            id: 20,
            path: '/tmp/second.mp3',
            title: 'Second Song',
            artist: 'Second Artist',
            artists: ['Second Artist'],
            album: 'Second Album',
            duration: 240,
            playCount: 0,
            lyricsOffsetMs: 0,
            dateAdded: '',
            favorite: false,
            thumbnailPath: '',
          ),
        ],
        hasLibrary: true,
        sortCriterion: MusicLibrarySortCriterion.title,
        albumsSort: AlbumSortCriterion.defaultSort,
        databasePath: '',
        nowPlaying: NowPlayingSnapshot(playlistId: 1, songIds: [99, 20]),
      ),
    );
    final desktopService = _ShellDesktopFeatureService();

    await tester.pumpWidget(
      _ShellPageTestApp(repository: repository, desktopService: desktopService),
    );
    for (var pump = 0; pump < 6; pump += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final restoredSession = desktopService.mediaSessions.lastWhere(
      (state) => state.active,
    );
    expect(restoredSession.title, 'Second Song');
    expect(restoredSession.durationSeconds, 240);
    expect(restoredSession.progressSeconds, 24);
  });

  testWidgets('shell resolves missing player artwork once like Electron', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SmPlayerSettingsStorageKeys.lastMusicIndex: 0,
      SmPlayerSettingsStorageKeys.musicProgress: 0.0,
      SmPlayerSettingsStorageKeys.autoPlay: false,
      SmPlayerSettingsStorageKeys.saveMusicProgress: true,
    });
    final repository = _SnapshotRepository(
      const MusicLibrarySnapshot(
        songs: [
          LibrarySong(
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
        ],
        hasLibrary: true,
        sortCriterion: MusicLibrarySortCriterion.title,
        albumsSort: AlbumSortCriterion.defaultSort,
        databasePath: '',
        nowPlaying: NowPlayingSnapshot(playlistId: 1, songIds: [10]),
      ),
    );

    await tester.pumpWidget(
      _ShellPageTestApp(
        repository: repository,
        desktopService: _ShellDesktopFeatureService(),
      ),
    );
    for (var pump = 0; pump < 12; pump += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(repository.artworkSnapshotSongIds, [10]);
    expect(repository.artworkSnapshotRequestCount, 1);
  });

  testWidgets('mini mode progress seek commits on release like Electron', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 720));
    SharedPreferences.setMockInitialValues({
      SmPlayerSettingsStorageKeys.lastMusicIndex: 0,
      SmPlayerSettingsStorageKeys.musicProgress: 10.0,
      SmPlayerSettingsStorageKeys.autoPlay: false,
      SmPlayerSettingsStorageKeys.saveMusicProgress: true,
    });
    final repository = _SnapshotRepository(
      const MusicLibrarySnapshot(
        songs: [
          LibrarySong(
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
        ],
        hasLibrary: true,
        sortCriterion: MusicLibrarySortCriterion.title,
        albumsSort: AlbumSortCriterion.defaultSort,
        databasePath: '',
        nowPlaying: NowPlayingSnapshot(playlistId: 1, songIds: [10]),
      ),
    );
    final desktopService = _ShellDesktopFeatureService();

    await tester.pumpWidget(
      _ShellPageTestApp(
        repository: repository,
        desktopService: desktopService,
        initialMiniMode: true,
      ),
    );
    for (var pump = 0; pump < 6; pump += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final progressFinder = find.byKey(
      const ValueKey('MiniMode.ProgressSlider'),
    );
    final progressSlider = tester.widget<Slider>(progressFinder);
    progressSlider.onChangeStart!(10);
    await tester.pump();
    progressSlider.onChanged!(42);
    await tester.pump();

    expect(tester.widget<Slider>(progressFinder).value, 42);
    expect(
      desktopService.mediaSessions
          .lastWhere((state) => state.active)
          .progressSeconds,
      10,
    );

    tester.widget<Slider>(progressFinder).onChangeEnd!(42);
    await tester.pump();

    expect(
      desktopService.mediaSessions
          .lastWhere((state) => state.active)
          .progressSeconds,
      42,
    );
  });

  testWidgets('mini mode volume icon follows Electron thresholds', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 720));
    SharedPreferences.setMockInitialValues({
      SmPlayerSettingsStorageKeys.lastMusicIndex: 0,
      SmPlayerSettingsStorageKeys.volume: 20,
      SmPlayerSettingsStorageKeys.isMuted: false,
      SmPlayerSettingsStorageKeys.autoPlay: false,
    });
    final repository = _SnapshotRepository(
      const MusicLibrarySnapshot(
        songs: [
          LibrarySong(
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
        ],
        hasLibrary: true,
        sortCriterion: MusicLibrarySortCriterion.title,
        albumsSort: AlbumSortCriterion.defaultSort,
        databasePath: '',
        nowPlaying: NowPlayingSnapshot(playlistId: 1, songIds: [10]),
      ),
    );

    await tester.pumpWidget(
      _ShellPageTestApp(
        repository: repository,
        desktopService: _ShellDesktopFeatureService(),
        initialMiniMode: true,
      ),
    );
    for (var pump = 0; pump < 6; pump += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.byIcon(Icons.volume_down_rounded), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
  });

  testWidgets('mini mode track copy follows Electron control visibility', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 720));
    SharedPreferences.setMockInitialValues({
      SmPlayerSettingsStorageKeys.lastMusicIndex: 0,
      SmPlayerSettingsStorageKeys.autoPlay: false,
    });
    final repository = _SnapshotRepository(
      const MusicLibrarySnapshot(
        songs: [
          LibrarySong(
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
        ],
        hasLibrary: true,
        sortCriterion: MusicLibrarySortCriterion.title,
        albumsSort: AlbumSortCriterion.defaultSort,
        databasePath: '',
        nowPlaying: NowPlayingSnapshot(playlistId: 1, songIds: [10]),
      ),
    );

    await tester.pumpWidget(
      _ShellPageTestApp(
        repository: repository,
        desktopService: _ShellDesktopFeatureService(),
        initialMiniMode: true,
      ),
    );
    for (var pump = 0; pump < 6; pump += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final trackCopy = find.byKey(const ValueKey('MiniMode.TrackCopyOpacity'));
    expect(tester.widget<AnimatedOpacity>(trackCopy).opacity, 0);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(10, 10));
    await tester.pump();
    await gesture.moveTo(const Offset(650, 360));
    await tester.pump();

    expect(tester.widget<AnimatedOpacity>(trackCopy).opacity, 1);
  });

  testWidgets('shell syncs tray visibility state from desktop service', (
    tester,
  ) async {
    final desktopService = _ShellDesktopFeatureService();

    await tester.pumpWidget(_ShellPageTestApp(desktopService: desktopService));
    await tester.pump();
    expect(desktopService.trayStates.last.isWindowVisible, isTrue);

    desktopService.emit(
      const DesktopFeatureAction(
        DesktopFeatureCommand.windowVisibilityChanged,
        isWindowVisible: false,
      ),
    );
    await tester.pump();

    expect(desktopService.trayStates.last.isWindowVisible, isFalse);
  });

  testWidgets('sidebar titlebar drag calls desktop drag bridge', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 600));
    final desktopService = _ShellDesktopFeatureService();

    await tester.pumpWidget(_ShellPageTestApp(desktopService: desktopService));
    await tester.pump();

    final titleCenter = tester.getCenter(find.text('app.shell'));
    final gesture = await tester.startGesture(titleCenter);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(desktopService.startWindowDragCount, 1);
    expect(desktopService.stopWindowDragCount, 1);
  });

  testWidgets('shell shows window for external show-window command', (
    tester,
  ) async {
    final desktopService = _ShellDesktopFeatureService()..windowVisible = false;

    await tester.pumpWidget(_ShellPageTestApp(desktopService: desktopService));
    await tester.pump();

    desktopService.emit(
      const DesktopFeatureAction(DesktopFeatureCommand.showWindow),
    );
    await tester.pump();

    expect(desktopService.showWindowCount, 1);
    expect(desktopService.toggleWindowVisibilityCount, 0);
    expect(desktopService.windowVisible, isTrue);
  });

  testWidgets('shell syncs light window controls for night mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SmPlayerSettingsStorageKeys.nightMode: 'on',
    });
    final desktopService = _ShellDesktopFeatureService();

    await tester.pumpWidget(_ShellPageTestApp(desktopService: desktopService));
    await tester.pumpAndSettle();

    expect(desktopService.windowControlsLight, isTrue);
  });

  testWidgets('shell mirrors desktop fullscreen change events', (tester) async {
    final desktopService = _ShellDesktopFeatureService();
    final navigations = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        child: SmPlayerI18nScope(
          i18n: const SmPlayerI18n(locale: 'en-US', messages: {}),
          child: MaterialApp(
            home: SmPlayerShellPage(
              currentPath: '/now-playing/full',
              desktopFeatureService: desktopService,
              onNavigate: navigations.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    desktopService.emit(
      const DesktopFeatureAction(
        DesktopFeatureCommand.windowFullScreenChanged,
        isWindowFullScreen: false,
      ),
    );
    await tester.pump();

    expect(navigations.last, '/now-playing');
  });

  testWidgets('release notes open after app version upgrade', (tester) async {
    SharedPreferences.setMockInitialValues({
      SmPlayerSettingsStorageKeys.lastReleaseNotesVersion: '0.9.0',
    });

    await tester.pumpWidget(
      const _ShellPageTestApp(
        appVersion: '1.0.0',
        messages: _releaseNotesMessages,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Release Notes'), findsOneWidget);
    expect(find.text('Version 3.0.0'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(
        SmPlayerSettingsStorageKeys.lastReleaseNotesVersion,
      ),
      '1.0.0',
    );
    expect(find.text('Release Notes'), findsNothing);
  });
}

class _ShellPageTestApp extends StatelessWidget {
  const _ShellPageTestApp({
    this.appVersion,
    this.messages = const {},
    this.repository,
    this.desktopService,
    this.initialMiniMode = false,
  });

  final String? appVersion;
  final Map<String, String> messages;
  final LibraryRepository? repository;
  final DesktopFeatureService? desktopService;
  final bool initialMiniMode;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        if (repository != null)
          libraryRepositoryProvider.overrideWithValue(repository!),
      ],
      child: SmPlayerI18nScope(
        i18n: SmPlayerI18n(locale: 'en-US', messages: messages),
        child: MaterialApp(
          home: SmPlayerShellPage(
            appVersion: appVersion,
            desktopFeatureService: desktopService,
            initialMiniMode: initialMiniMode,
          ),
        ),
      ),
    );
  }
}

class _StartupRepository extends LibraryRepository {
  var commitPendingDeletesCount = 0;

  @override
  Future<void> commitPendingDeletes() async {
    commitPendingDeletesCount += 1;
  }
}

class _SnapshotRepository extends _StartupRepository {
  _SnapshotRepository(this.snapshot);

  final MusicLibrarySnapshot snapshot;
  var artworkSnapshotRequestCount = 0;
  final artworkSnapshotSongIds = <int>[];

  @override
  Future<MusicLibrarySnapshot> getMusicLibrarySnapshot() async {
    return snapshot;
  }

  @override
  Future<LyricsSnapshot> getSongLyrics(
    int songId, {
    LyricsRequestMode mode = LyricsRequestMode.auto,
  }) async {
    return const LyricsSnapshot(
      source: LyricsSource.none,
      isSynced: false,
      rawText: '',
      lines: [],
    );
  }

  @override
  Future<SongArtworkSnapshot> getSongArtworkSnapshot(int songId) async {
    artworkSnapshotRequestCount += 1;
    artworkSnapshotSongIds.add(songId);
    return SongArtworkSnapshot(
      songId: songId,
      artworkUrl: '',
      sourceUrl: '',
      sourcePath: '',
      source: SongArtworkSource.none,
    );
  }
}

class _ShellDesktopFeatureService implements DesktopFeatureService {
  ValueChanged<DesktopFeatureAction>? onAction;
  final trayStates = <DesktopTrayState>[];
  final mediaSessions = <MediaSessionDisplayState>[];
  var windowVisible = true;
  var windowFullScreen = false;
  var showWindowCount = 0;
  var toggleWindowVisibilityCount = 0;
  var startWindowDragCount = 0;
  var stopWindowDragCount = 0;
  bool? windowControlsLight;

  void emit(DesktopFeatureAction action) {
    if (action.isWindowVisible case final isVisible?) {
      windowVisible = isVisible;
    }
    if (action.isWindowFullScreen case final isFullScreen?) {
      windowFullScreen = isFullScreen;
    }
    onAction!(action);
  }

  @override
  Future<void> initialize(ValueChanged<DesktopFeatureAction> onAction) async {
    this.onAction = onAction;
  }

  @override
  Future<List<String>> getSystemFonts() async {
    return const [];
  }

  @override
  Future<void> updateTray(DesktopTrayState state) async {
    trayStates.add(state);
  }

  @override
  Future<void> showTrackNotification(TrackNotificationPayload payload) async {}

  @override
  Future<void> updateMediaSession(MediaSessionDisplayState state) async {
    mediaSessions.add(state);
  }

  @override
  Future<void> updateDesktopLyricsState(
    DesktopLyricsDisplayState state,
  ) async {}

  @override
  Future<void> enterMiniMode() async {}

  @override
  Future<void> exitMiniMode() async {}

  @override
  Future<void> startWindowDrag() async {
    startWindowDragCount += 1;
  }

  @override
  Future<void> stopWindowDrag() async {
    stopWindowDragCount += 1;
  }

  @override
  Future<void> setWindowFullScreen(bool fullScreen) async {
    windowFullScreen = fullScreen;
  }

  @override
  Future<void> setWindowControlsLight(bool light) async {
    windowControlsLight = light;
  }

  @override
  Future<bool> getWindowFullScreen() async {
    return windowFullScreen;
  }

  @override
  Future<bool> getWindowVisible() async {
    return windowVisible;
  }

  @override
  Future<void> showWindow() async {
    showWindowCount += 1;
    windowVisible = true;
  }

  @override
  Future<void> toggleWindowVisibility() async {
    toggleWindowVisibilityCount += 1;
    windowVisible = !windowVisible;
  }

  @override
  Future<void> quit() async {}

  @override
  void dispose() {}
}

const _releaseNotesMessages = {
  'settings.releaseNotes': 'Release Notes',
  'settings.releaseNotesArtists': 'Artists',
  'settings.releaseNotesIntro': 'History Updates',
  'settings.releaseNotesLibrary': 'Library',
  'settings.releaseNotesUi': 'UI',
  'settings.releaseNotesVersion': 'Version',
  'releaseNotes.architectureFeedback': 'Feedback',
  'common.close': 'Close',
};

void _setViewSize(
  WidgetTester tester,
  Size size, {
  bool resetAfterTest = true,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  if (resetAfterTest) {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }
}
