import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/app/shell_overlay_host.dart';
import 'package:smplayer_flutter/src/app/shell_page.dart';
import 'package:smplayer_flutter/src/app/shell_player_host.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_shell_metrics.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/platform/desktop_feature_service.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LyricsRequestMode, NightMode, SettingsSnapshot, SmPlayerDisplayMode;

void main() {
  setUp(() {
    resetSmPlayerGlobalSettingsSnapshot();
    resetSmPlayerShellGlobalStateForTest();
    addTearDown(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
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

  test('resolveShellPlayerSong mirrors Electron currentTrack lookup', () {
    const snapshot = LibraryContentData(
      songs: [
        LibrarySong(
          id: 1,
          path: '/tmp/old.mp3',
          title: 'Old queue song',
          artist: 'Artist',
          artists: ['Artist'],
          album: 'Album',
          duration: 180,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '',
          favorite: false,
          thumbnailPath: '',
        ),
        LibrarySong(
          id: 3,
          path: '/tmp/current.mp3',
          title: 'Current artist song',
          artist: 'Artist',
          artists: ['Artist'],
          album: 'Album',
          duration: 200,
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
      nowPlaying: NowPlayingSnapshot(playlistId: 1, songIds: [1]),
    );

    expect(resolveShellPlayerSong(snapshot, 3)?.title, 'Current artist song');
    expect(resolveShellPlayerSong(snapshot, null), isNull);
  });

  testWidgets('ShellOverlayHost opens MusicDialog from player dialog state', (
    tester,
  ) async {
    const currentSong = LibrarySong(
      id: 10,
      path: '/tmp/current.mp3',
      title: 'Current Song',
      artist: 'Artist',
      artists: ['Artist'],
      album: 'Album',
      duration: 180,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '',
      favorite: false,
      thumbnailPath: '',
    );
    const dialogSong = LibrarySong(
      id: 20,
      path: '/tmp/dialog.mp3',
      title: 'Dialog Song',
      artist: 'Artist',
      artists: ['Artist'],
      album: 'Album',
      duration: 200,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '',
      favorite: false,
      thumbnailPath: '',
    );
    const snapshot = LibraryContentData(
      songs: [currentSong, dialogSong],
      hasLibrary: true,
      sortCriterion: MusicLibrarySortCriterion.title,
      albumsSort: AlbumSortCriterion.defaultSort,
      databasePath: '',
      nowPlaying: NowPlayingSnapshot(playlistId: 1, songIds: [10, 20]),
    );
    final repository = _SnapshotRepository(snapshot);
    final playerDialogNotifier = ValueNotifier<ShellPlayerDialog?>(null);
    final playerDialogRefreshNotifier = ValueNotifier<int>(0);
    final mediaController =
        MediaControlController()..playTrack(
          const MediaControlTrack(
            id: 10,
            title: 'Current Song',
            artist: 'Artist',
            artworkUrl: '',
            isLoading: false,
          ),
          durationSeconds: 180,
          queueIndex: 0,
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(repository),
          libraryContentDataProvider.overrideWith((ref) async => snapshot),
        ],
        child: SmPlayerI18nScope(
          i18n: const SmPlayerI18n(
            locale: 'en-US',
            messages: {
              'common.artist': 'Artist',
              'common.import': 'Import',
              'common.reset': 'Reset',
              'common.search': 'Search',
              'context.pause': 'Pause',
              'context.play': 'Play',
              'context.seeAlbumArt': 'Album Art',
              'context.seeLyrics': 'Lyrics',
              'context.seeMusicInfo': 'Music Info',
              'nowPlaying.loading': 'Loading',
              'nowPlaying.noLyrics': 'No Lyrics',
              'settings.save': 'Save',
            },
          ),
          child: MaterialApp(
            theme: buildSmPlayerTheme(const SettingsSnapshot.defaults()),
            home: ShellOverlayHost(
              playerDialogNotifier: playerDialogNotifier,
              playerDialogRefreshNotifier: playerDialogRefreshNotifier,
              mediaControlController: mediaController,
              releaseNotesDialogVersion: null,
              startupArtistSplitResult: null,
              startupArtistSplitApplying: false,
              onTogglePlayPause: () {},
              onRevealPath: (_) {},
              onCloseReleaseNotes: (_) async {},
              onDismissStartupArtistSplitReview: () {},
              onApplyStartupArtistSplits: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    playerDialogNotifier.value = (
      song: dialogSong,
      mode: SongDialogMode.lyrics,
    );
    await tester.pumpAndSettle();

    expect(find.byType(MusicDialog), findsOneWidget);
    final dialog = tester.widget<MusicDialog>(find.byType(MusicDialog));
    expect(dialog.song.id, 20);
    expect(dialog.initialMode, SongDialogMode.lyrics);
    expect(dialog.currentTrackId, 10);
    expect(dialog.isPlaying, isTrue);
    expect(dialog.queueSongIds, [10, 20]);

    dialog.onSaved?.call();
    await tester.pump();
    expect(playerDialogRefreshNotifier.value, 1);

    dialog.onClose();
    await tester.pump();
    expect(playerDialogNotifier.value, isNull);
  });

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

  test('audio loading state keeps pending autoplay active', () {
    expect(
      shouldApplyAudioBackendPlayingState(
        backendLoading: true,
        backendPlaying: false,
        pendingAutoplay: true,
      ),
      isFalse,
    );
    expect(
      shouldApplyAudioBackendPlayingState(
        backendLoading: true,
        backendPlaying: true,
        pendingAutoplay: true,
      ),
      isTrue,
    );
    expect(
      shouldApplyAudioBackendPlayingState(
        backendLoading: false,
        backendPlaying: false,
        pendingAutoplay: true,
      ),
      isFalse,
    );
    expect(
      shouldApplyAudioBackendPlayingState(
        backendLoading: false,
        backendPlaying: false,
        pendingAutoplay: false,
      ),
      isTrue,
    );
  });

  test('audio loading indicator clears once pending autoplay is playing', () {
    expect(
      shouldShowAudioBackendLoading(
        backendLoading: true,
        waitingForCurrentLoad: true,
        pendingAutoplay: true,
        backendPlaying: false,
      ),
      isTrue,
    );
    expect(
      shouldShowAudioBackendLoading(
        backendLoading: false,
        waitingForCurrentLoad: true,
        pendingAutoplay: true,
        backendPlaying: false,
      ),
      isTrue,
    );
    expect(
      shouldShowAudioBackendLoading(
        backendLoading: false,
        waitingForCurrentLoad: true,
        pendingAutoplay: true,
        backendPlaying: true,
      ),
      isFalse,
    );
    expect(
      shouldShowAudioBackendLoading(
        backendLoading: false,
        waitingForCurrentLoad: true,
        pendingAutoplay: false,
        backendPlaying: false,
      ),
      isFalse,
    );
  });

  test('audio file permission classifier detects macOS sandbox denials', () {
    expect(
      isAudioFilePermissionDenied(
        const FileSystemException(
          'Operation not permitted',
          '/Users/me/Music/song.wav',
          OSError('Operation not permitted', 1),
        ),
      ),
      isTrue,
    );
    expect(
      isAudioFilePermissionDenied(
        const FileSystemException(
          'Permission denied',
          '/Users/me/Music/song.wav',
          OSError('Permission denied', 13),
        ),
      ),
      isTrue,
    );
    expect(
      isAudioFilePermissionDenied(
        const FileSystemException(
          'No such file',
          '/Users/me/Music/song.wav',
          OSError('No such file', 2),
        ),
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
        key: LogicalKeyboardKey.mediaPlayPause,
        control: false,
        alt: false,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.togglePlayPause,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.f8,
        control: false,
        alt: false,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.togglePlayPause,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.mediaPlay,
        control: false,
        alt: false,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.play,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.mediaPause,
        control: false,
        alt: false,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.pause,
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
        key: LogicalKeyboardKey.mediaTrackNext,
        control: false,
        alt: false,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.next,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.f9,
        control: false,
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
        key: LogicalKeyboardKey.mediaTrackPrevious,
        control: false,
        alt: false,
        meta: false,
        shift: false,
      ),
      SmPlayerPlaybackShortcut.previous,
    );
    expect(
      playbackShortcutForKey(
        key: LogicalKeyboardKey.f7,
        control: false,
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

  testWidgets(
    'shell provides Electron player-relative headered scrollbar inset',
    (tester) async {
      _setViewSize(tester, const Size(1300, 600));

      await tester.pumpWidget(
        _ShellPageTestApp(
          child: Consumer(
            builder: (context, ref, _) {
              return Text(
                '${ref.watch(headeredPlaylistScrollbarBottomProvider)}',
                key: const ValueKey('HeaderedPlaylist.ScrollbarBottomProbe'),
              );
            },
          ),
        ),
      );

      expect(
        find.text('${SmPlayerShellMetrics.playerTopRadius + 10}'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shell renders Electron workspace title for normal routes', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 700));

    await tester.pumpWidget(
      const _ShellPageTestApp(
        currentPath: '/settings',
        currentLocation: '/settings',
        messages: {'common.settings': 'Settings'},
      ),
    );

    final title = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == 'Settings' &&
            widget.style?.fontSize == 40,
      ),
    );
    expect(title.style?.fontSize, 40);
    expect(title.style?.fontWeight, FontWeight.w500);
    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.workspace)).height,
      700 -
          SmPlayerShellMetrics.playerHeight +
          SmPlayerShellMetrics.playerTopRadius,
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
    for (var pump = 0; pump < 20; pump += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }

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

  testWidgets('navigation expands without intermediate layout overflow', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.TogglePaneButton')),
    );
    await tester.pump(const Duration(milliseconds: 90));

    expect(tester.takeException(), isNull);
  });

  testWidgets('overlay navigation opens above the 64px shell rail', (
    tester,
  ) async {
    _setViewSize(tester, const Size(800, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.TogglePaneButton')),
    );
    await tester.pumpAndSettle();

    final sidebar = find.byKey(SmPlayerShellKeys.sidebar);
    final workspace = find.byKey(SmPlayerShellKeys.workspace);

    expect(tester.getSize(sidebar).width, SmPlayerShellMetrics.sidebarWidth);
    expect(
      tester.getTopLeft(workspace).dx,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
  });

  testWidgets('overlay navigation starts collapsed on app startup', (
    tester,
  ) async {
    _setViewSize(tester, const Size(800, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
    expect(
      tester.getTopLeft(find.byKey(SmPlayerShellKeys.workspace)).dx,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
  });

  testWidgets('minimal navigation starts with only the Electron menu button', (
    tester,
  ) async {
    _setViewSize(tester, const Size(600, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pump();

    expect(find.byKey(SmPlayerShellKeys.sidebar), findsNothing);
    expect(find.byKey(SmPlayerShellKeys.minimalMenuButton), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(SmPlayerShellKeys.workspace)).dx, 0);
  });

  testWidgets('minimal workspace reserves Electron player height', (
    tester,
  ) async {
    _setViewSize(tester, const Size(600, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pump();

    final workspace = find.byKey(SmPlayerShellKeys.workspace);
    final reservedPlayer = find.byKey(SmPlayerShellKeys.reservedPlayer);

    expect(
      tester.getTopLeft(workspace).dy,
      SmPlayerShellMetrics.minimalTitlebarHeight,
    );
    expect(
      tester.getSize(workspace).height,
      600 -
          SmPlayerShellMetrics.playerHeight +
          SmPlayerShellMetrics.playerTopRadius -
          SmPlayerShellMetrics.minimalTitlebarHeight,
    );
    expect(
      tester.getSize(reservedPlayer).height,
      SmPlayerShellMetrics.playerHeight,
    );
  });

  testWidgets('shell workspace hover reaches page content', (tester) async {
    _setViewSize(tester, const Size(600, 600));
    var hovered = false;

    await tester.pumpWidget(
      _ShellPageTestApp(
        child: MouseRegion(
          key: const ValueKey('ShellHoverProbe'),
          onEnter: (_) {
            hovered = true;
          },
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(
      tester.getCenter(find.byKey(SmPlayerShellKeys.workspace)),
    );
    await tester.pump();

    expect(hovered, isTrue);
  });

  testWidgets('minimal navigation expands as a floating pane over content', (
    tester,
  ) async {
    _setViewSize(tester, const Size(600, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pump();
    final closedMenuRect = tester.getRect(
      find.byKey(SmPlayerShellKeys.minimalMenuButton),
    );
    await tester.tap(find.byKey(SmPlayerShellKeys.minimalMenuButton));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.sidebarWidth,
    );
    expect(tester.getTopLeft(find.byKey(SmPlayerShellKeys.workspace)).dx, 0);
    expect(
      find.byKey(SmPlayerShellKeys.navigationDismissLayer),
      findsOneWidget,
    );
    expect(
      tester.getRect(
        find.byKey(const ValueKey('MainNavigationView.TogglePaneButton')),
      ),
      closedMenuRect,
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

  testWidgets('shell restores Electron navigation collapsed memory state', (
    tester,
  ) async {
    setSmPlayerShellNavigationCollapsedForTest(true);
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
    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.TogglePaneButton')),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.collapsedSidebarWidth,
    );
  });

  testWidgets('shell restores in-memory navigation collapsed state', (
    tester,
  ) async {
    _setViewSize(tester, const Size(800, 600));

    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.TogglePaneButton')),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const _ShellPageTestApp());
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.collapsedSidebarWidth,
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

  testWidgets('shell shows Recent workspace header for empty recent page', (
    tester,
  ) async {
    final repository = _SnapshotRepository(
      const LibraryContentData(
        songs: [],
        recentSongs: [],
        recentPlaylists: [],
        recentAlbums: [],
        recentArtists: [],
        recentSearches: [],
        playlists: [],
        hasLibrary: true,
        sortCriterion: MusicLibrarySortCriterion.title,
        albumsSort: AlbumSortCriterion.defaultSort,
        databasePath: '',
        nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
      ),
    );

    await tester.pumpWidget(
      _ShellPageTestApp(
        repository: repository,
        currentPath: '/recent',
        currentLocation: '/recent',
        messages: const {'common.recent': 'Recent'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent'), findsOneWidget);
  });

  testWidgets('shell sidebar search keeps typed value editable', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 600));
    final repository = _SnapshotRepository(
      const LibraryContentData(
        songs: [],
        recentSongs: [],
        recentPlaylists: [],
        recentAlbums: [],
        recentArtists: [],
        recentSearches: [
          SearchHistoryEntry(
            id: 1,
            query: 'Jazz',
            type: SearchHistoryType.sidebar,
            searchedAt: '2026-05-21T00:00:00Z',
          ),
        ],
        playlists: [],
        hasLibrary: true,
        sortCriterion: MusicLibrarySortCriterion.title,
        albumsSort: AlbumSortCriterion.defaultSort,
        databasePath: '',
        nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
      ),
    );

    await tester.pumpWidget(
      _ShellPageTestApp(
        repository: repository,
        messages: const {
          'common.search': 'Search',
          'common.clear': 'Clear',
          'sidebar.recentSearches': 'Recent searches',
          'sidebar.removeRecentSearch': 'Remove {query}',
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Recent searches'), findsOneWidget);
    expect(
      tester
          .getTopLeft(find.byKey(SmPlayerShellKeys.navigationDismissLayer))
          .dx,
      SmPlayerShellMetrics.sidebarWidth,
    );
    final editableTextState = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(editableTextState.widget.focusNode.hasFocus, isTrue);
    for (var frame = 0; frame < 10; frame += 1) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(editableTextState.widget.focusNode.hasFocus, isTrue);
    }
    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(editableTextState.widget.focusNode.hasFocus, isTrue);
    expect(find.text('Recent searches'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      'Blue',
    );
    await tester.pump();

    final textField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
        matching: find.byType(EditableText),
      ),
    );
    expect(textField.controller.text, 'Blue');
    expect(
      find.byKey(const ValueKey('MainNavigationView.ClearSearchButton')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(SmPlayerShellKeys.navigationDismissLayer));
    await tester.pumpAndSettle();

    expect(find.text('Recent searches'), findsNothing);
    expect(editableTextState.widget.focusNode.hasFocus, isFalse);
  });

  testWidgets('shell shortcuts do not steal sidebar search focus', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 600));
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(
        lastMusicIndex: 0,
        autoPlay: false,
      ),
    );
    final repository = _SnapshotRepository(
      const LibraryContentData(
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
        recentSongs: [],
        recentPlaylists: [],
        recentAlbums: [],
        recentArtists: [],
        recentSearches: [],
        playlists: [],
        hasLibrary: true,
        sortCriterion: MusicLibrarySortCriterion.title,
        albumsSort: AlbumSortCriterion.defaultSort,
        databasePath: '',
        nowPlaying: NowPlayingSnapshot(playlistId: 1, songIds: [10]),
      ),
    );
    final desktopService = _ShellDesktopFeatureService();

    await tester.pumpWidget(
      _ShellPageTestApp(repository: repository, desktopService: desktopService),
    );
    for (var pump = 0; pump < 6; pump += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('MainNavigationView.SearchTextField')),
      'Blue',
    );
    await tester.pump();
    final editableTextState = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(editableTextState.widget.focusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(editableTextState.widget.focusNode.hasFocus, isTrue);
    expect(_lastActiveMediaSession(desktopService).playing, isFalse);
  });

  testWidgets('overlay sidebar search expands and keeps focus', (tester) async {
    _setViewSize(tester, const Size(800, 600));
    final repository = _SnapshotRepository(
      const LibraryContentData(
        songs: [],
        recentSongs: [],
        recentPlaylists: [],
        recentAlbums: [],
        recentArtists: [],
        recentSearches: [
          SearchHistoryEntry(
            id: 1,
            query: 'Jazz',
            type: SearchHistoryType.sidebar,
            searchedAt: '2026-05-21T00:00:00Z',
          ),
        ],
        playlists: [],
        hasLibrary: true,
        sortCriterion: MusicLibrarySortCriterion.title,
        albumsSort: AlbumSortCriterion.defaultSort,
        databasePath: '',
        nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
      ),
    );

    await tester.pumpWidget(
      _ShellPageTestApp(
        repository: repository,
        messages: const {
          'common.search': 'Search',
          'common.clear': 'Clear',
          'sidebar.recentSearches': 'Recent searches',
          'sidebar.removeRecentSearch': 'Remove {query}',
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('MainNavigationView.SearchButton')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(SmPlayerShellKeys.sidebar)).width,
      SmPlayerShellMetrics.sidebarWidth,
    );
    expect(find.text('Recent searches'), findsOneWidget);
    final editableTextState = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(editableTextState.widget.focusNode.hasFocus, isTrue);
  });

  testWidgets(
    'shell hides Recent workspace header when recent page has content',
    (tester) async {
      final repository = _SnapshotRepository(
        const LibraryContentData(
          songs: [
            LibrarySong(
              id: 1,
              path: '/tmp/first.mp3',
              title: 'First Song',
              artist: 'First Artist',
              artists: ['First Artist'],
              album: 'First Album',
              duration: 180,
              playCount: 0,
              lyricsOffsetMs: 0,
              dateAdded: '2026-05-24T00:00:00Z',
              favorite: false,
              thumbnailPath: '',
            ),
          ],
          recentSongs: [],
          recentPlaylists: [],
          recentAlbums: [],
          recentArtists: [],
          recentSearches: [],
          playlists: [],
          hasLibrary: true,
          sortCriterion: MusicLibrarySortCriterion.title,
          albumsSort: AlbumSortCriterion.defaultSort,
          databasePath: '',
          nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
        ),
      );

      await tester.pumpWidget(
        _ShellPageTestApp(
          repository: repository,
          currentPath: '/recent',
          currentLocation: '/recent',
          messages: const {'common.recent': 'Recent'},
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data == 'Recent' &&
              widget.style?.fontSize == 40,
        ),
        findsNothing,
      );
    },
  );

  testWidgets('shell restores Electron playback state during startup', (
    tester,
  ) async {
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(
        lastMusicIndex: 1,
        musicProgress: 42,
        autoPlay: false,
        saveMusicProgress: true,
      ),
    );
    final repository = _SnapshotRepository(
      const LibraryContentData(
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

  testWidgets('shell playback shortcuts drive the active player', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 700));
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(
        lastMusicIndex: 0,
        musicProgress: 10,
        autoPlay: false,
        saveMusicProgress: true,
      ),
    );
    final repository = _SnapshotRepository(
      const LibraryContentData(
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

    expect(_lastActiveMediaSession(desktopService).title, 'First Song');
    expect(_lastActiveMediaSession(desktopService).playing, isFalse);
    expect(_lastActiveMediaSession(desktopService).progressSeconds, 10);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_lastActiveMediaSession(desktopService).progressSeconds, 15);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(_lastActiveMediaSession(desktopService).progressSeconds, 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(_lastActiveMediaSession(desktopService).title, 'Second Song');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(_lastActiveMediaSession(desktopService).title, 'First Song');

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(
      desktopService.mediaSessions.any(
        (state) => state.active && state.title == 'First Song' && state.playing,
      ),
      isTrue,
    );
  });

  testWidgets(
    'bottom player shuffle mode rewrites queue without refetching library',
    (tester) async {
      _setViewSize(tester, const Size(1300, 700));
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(
          lastMusicIndex: 0,
          autoPlay: false,
        ),
      );
      final repository = _SnapshotRepository(
        const LibraryContentData(
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

      await tester.pumpWidget(_ShellPageTestApp(repository: repository));
      for (var pump = 0; pump < 6; pump += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final requestsBeforeShuffle = repository.getLibraryContentDataCount;

      await tester.tap(
        find.byKey(const ValueKey('MediaControl.ShuffleButton')),
      );
      await tester.pump();

      expect(repository.replaceNowPlayingCalls, hasLength(1));
      final nextQueue = repository.replaceNowPlayingCalls.single;
      expect(nextQueue, hasLength(2));
      expect(nextQueue.first, 10);
      expect(nextQueue.toSet(), {10, 20});
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SmPlayerShellPage)),
      );
      expect(container.read(nowPlayingQueueOverrideProvider), nextQueue);
      expect(repository.getLibraryContentDataCount, requestsBeforeShuffle);
    },
  );

  testWidgets('bottom player song info enters immersive now playing', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 700));
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(
        lastMusicIndex: 0,
        musicProgress: 0,
        autoPlay: false,
        saveMusicProgress: true,
      ),
    );
    final navigations = <String>[];
    final desktopService = _ShellDesktopFeatureService();
    final repository = _SnapshotRepository(
      const LibraryContentData(
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
        desktopService: desktopService,
        onNavigate: navigations.add,
      ),
    );
    for (var pump = 0; pump < 8; pump += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    await tester.tap(find.text('First Song'));
    await tester.pump();

    expect(navigations.single, startsWith('/immersive-mode'));
    expect(desktopService.windowFullScreen, isFalse);
    expect(
      smPlayerGlobalSettingsSnapshot.lastDisplayMode,
      SmPlayerDisplayMode.immersive,
    );
  });

  testWidgets(
    'bottom player song info exits native fullscreen before immersive now playing',
    (tester) async {
      _setViewSize(tester, const Size(1300, 700));
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(
          lastMusicIndex: 0,
          musicProgress: 0,
          autoPlay: false,
          saveMusicProgress: true,
        ),
      );
      final navigations = <String>[];
      final desktopService = _ShellDesktopFeatureService();
      final repository = _SnapshotRepository(
        const LibraryContentData(
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
          desktopService: desktopService,
          initialDisplayMode: SmPlayerDisplayMode.fullScreen,
          onNavigate: navigations.add,
        ),
      );
      for (var pump = 0; pump < 8; pump += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(desktopService.windowFullScreen, isTrue);

      await tester.tap(find.text('First Song'));
      await tester.pump();

      expect(navigations.single, startsWith('/immersive-mode'));
      expect(desktopService.windowFullScreen, isFalse);
      expect(
        smPlayerGlobalSettingsSnapshot.lastDisplayMode,
        SmPlayerDisplayMode.immersive,
      );

      desktopService.emit(
        const DesktopFeatureAction(
          DesktopFeatureCommand.windowFullScreenChanged,
          isWindowFullScreen: false,
        ),
      );
      await tester.pump();

      expect(navigations.single, startsWith('/immersive-mode'));
      expect(
        smPlayerGlobalSettingsSnapshot.lastDisplayMode,
        SmPlayerDisplayMode.immersive,
      );
    },
  );

  testWidgets('bottom player More fullscreen toggles native fullscreen only', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 700));
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(
        lastMusicIndex: 0,
        autoPlay: false,
      ),
    );
    final navigations = <String>[];
    final desktopService = _ShellDesktopFeatureService();
    final repository = _SnapshotRepository(
      const LibraryContentData(
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
        messages: const {
          'player.more': 'More',
          'nowPlaying.fullScreen': 'Full Screen',
          'nowPlaying.quickPlay': 'Quick Play',
          'context.view': 'View',
          'player.miniMode': 'Mini Mode',
        },
        repository: repository,
        desktopService: desktopService,
        onNavigate: navigations.add,
      ),
    );
    for (var pump = 0; pump < 20; pump += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('First Song'), findsOneWidget);

    await tester.tap(find.byTooltip('More').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Full Screen'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(navigations, isEmpty);
    expect(desktopService.windowFullScreen, isTrue);
    expect(
      smPlayerGlobalSettingsSnapshot.lastDisplayMode,
      SmPlayerDisplayMode.fullScreen,
    );
  });

  testWidgets('shell restores fullscreen display mode into native fullscreen', (
    tester,
  ) async {
    final desktopService = _ShellDesktopFeatureService();

    await tester.pumpWidget(
      _ShellPageTestApp(
        desktopService: desktopService,
        initialDisplayMode: SmPlayerDisplayMode.fullScreen,
        currentPath: '/songs',
      ),
    );
    await tester.pump();

    expect(desktopService.windowFullScreen, isTrue);
  });

  testWidgets(
    'shell restores immersive display mode without native fullscreen',
    (tester) async {
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(
          lastMusicIndex: 1,
          musicProgress: 42,
          autoPlay: false,
          saveMusicProgress: true,
        ),
      );
      final repository = _SnapshotRepository(
        const LibraryContentData(
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
        _ShellPageTestApp(
          repository: repository,
          desktopService: desktopService,
          initialDisplayMode: SmPlayerDisplayMode.immersive,
          currentPath: '/immersive-mode',
        ),
      );
      for (var pump = 0; pump < 8; pump += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(desktopService.windowFullScreen, isFalse);
      final restoredSession = _lastActiveMediaSession(desktopService);
      expect(restoredSession.title, 'Second Song');
      expect(restoredSession.durationSeconds, 240);
      expect(restoredSession.progressSeconds, 42);
    },
  );

  testWidgets(
    'bottom player favorite toggles from player state before library refresh',
    (tester) async {
      _setViewSize(tester, const Size(1300, 700));
      setSmPlayerGlobalSettingsSnapshot(
        const SettingsSnapshot.defaults().copyWith(
          lastMusicIndex: 0,
          musicProgress: 0,
          autoPlay: false,
          saveMusicProgress: true,
        ),
      );
      final repository = _SnapshotRepository(
        const LibraryContentData(
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
          playlists: [
            LibraryPlaylist(
              id: 2,
              name: 'My Favorites',
              priority: 0,
              songCount: 0,
              songIds: [],
              sortCriterion: PlaylistSortCriterion.title,
              isBuiltIn: true,
            ),
          ],
          favoritePlaylistId: 2,
          nowPlaying: NowPlayingSnapshot(playlistId: 1, songIds: [10]),
        ),
      );

      await tester.pumpWidget(
        _ShellPageTestApp(
          repository: repository,
          messages: const {
            'player.like': 'Add to My Favorites',
            'player.unlike': 'Remove from My Favorites',
          },
        ),
      );
      for (var pump = 0; pump < 8; pump += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      await tester.tap(find.byTooltip('Add to My Favorites'));
      await tester.pump();
      expect(repository.snapshot.songs.single.favorite, isTrue);
      expect(_snapshotFavoritePlaylist(repository.snapshot).songIds, [10]);

      await tester.tap(find.byTooltip('Remove from My Favorites'));
      await tester.pump();

      expect(repository.favoriteWrites, hasLength(2));
      expect(repository.favoriteWrites[0].songIds, [10]);
      expect(repository.favoriteWrites[0].favorite, isTrue);
      expect(repository.favoriteWrites[1].songIds, [10]);
      expect(repository.favoriteWrites[1].favorite, isFalse);
      expect(repository.snapshot.songs.single.favorite, isFalse);
      expect(_snapshotFavoritePlaylist(repository.snapshot).songIds, isEmpty);
    },
  );

  testWidgets('shell restores playback from normalized Electron queue', (
    tester,
  ) async {
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(
        lastMusicIndex: 0,
        musicProgress: 24,
        autoPlay: false,
        saveMusicProgress: true,
      ),
    );
    final repository = _SnapshotRepository(
      const LibraryContentData(
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
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(
        lastMusicIndex: 0,
        musicProgress: 0,
        autoPlay: false,
        saveMusicProgress: true,
      ),
    );
    final repository = _SnapshotRepository(
      const LibraryContentData(
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
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(
        lastMusicIndex: 0,
        musicProgress: 10,
        autoPlay: false,
        saveMusicProgress: true,
      ),
    );
    final repository = _SnapshotRepository(
      const LibraryContentData(
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
        initialDisplayMode: SmPlayerDisplayMode.mini,
      ),
    );
    for (var pump = 0; pump < 6; pump += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final progressFinder = find.byKey(
      const ValueKey('MiniMode.ProgressSlider'),
    );
    final progressSlider = tester.widget<Slider>(progressFinder);
    expect(progressSlider.value, 10);
    expect(progressSlider.onChangeStart, isNotNull);
    expect(progressSlider.onChanged, isNotNull);
    expect(progressSlider.onChangeEnd, isNotNull);
    expect(desktopService.enterMiniModeCount, 1);
  });

  testWidgets('mini mode volume icon follows Electron thresholds', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 720));
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(
        lastMusicIndex: 0,
        volume: 20,
        isMuted: false,
        autoPlay: false,
      ),
    );
    final repository = _SnapshotRepository(
      const LibraryContentData(
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
        initialDisplayMode: SmPlayerDisplayMode.mini,
      ),
    );
    for (var pump = 0; pump < 6; pump += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      find.byKey(const ValueKey('MiniMode.Icon.volumeLow')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('MiniMode.Icon.volumeMedium')),
      findsNothing,
    );
  });

  testWidgets('initial mini mode restores current song and enables controls', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 720));
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(
        lastMusicIndex: 0,
        volume: 50,
        isMuted: false,
        autoPlay: false,
      ),
    );
    final repository = _SnapshotRepository(
      const LibraryContentData(
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
        initialDisplayMode: SmPlayerDisplayMode.mini,
      ),
    );
    for (var pump = 0; pump < 8; pump += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(10, 10));
    await tester.pump();
    await gesture.moveTo(const Offset(650, 360));
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('First Song'), findsOneWidget);
    final progressSlider = tester.widget<Slider>(
      find.byKey(const ValueKey('MiniMode.ProgressSlider')),
    );
    expect(progressSlider.onChanged, isNotNull);

    await tester.tap(find.byKey(const ValueKey('MiniMode.VolumeButton')));
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.byKey(const ValueKey('MiniMode.VolumeSlider')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('MiniMode.PlaybackModeButton')));
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.byKey(const ValueKey('MiniMode.Icon.shuffle')), findsOneWidget);
  });

  testWidgets('mini mode track copy follows Electron control visibility', (
    tester,
  ) async {
    _setViewSize(tester, const Size(1300, 720));
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(
        lastMusicIndex: 0,
        autoPlay: false,
      ),
    );
    final repository = _SnapshotRepository(
      const LibraryContentData(
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
        initialDisplayMode: SmPlayerDisplayMode.mini,
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

    final titleCenter = tester.getCenter(find.text('Simple Melody Player'));
    final gesture = await tester.startGesture(titleCenter);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(desktopService.startWindowDragCount, 1);
    expect(desktopService.stopWindowDragCount, 1);
  });

  testWidgets('Windows titlebar drag calls desktop drag bridge', (
    tester,
  ) async {
    if (!Platform.isWindows) {
      return;
    }
    _setViewSize(tester, const Size(1300, 600));
    final desktopService = _ShellDesktopFeatureService();

    await tester.pumpWidget(_ShellPageTestApp(desktopService: desktopService));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('WindowsAppTitleBar.DragRegion')),
      ),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(desktopService.startWindowDragCount, 1);
    expect(desktopService.stopWindowDragCount, 1);
  });

  testWidgets('Windows titlebar controls call desktop window bridge', (
    tester,
  ) async {
    if (!Platform.isWindows) {
      return;
    }
    _setViewSize(tester, const Size(1300, 600));
    final desktopService = _ShellDesktopFeatureService();

    await tester.pumpWidget(_ShellPageTestApp(desktopService: desktopService));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('WindowsAppTitleBar.MinimizeButton')),
    );
    await tester.tap(
      find.byKey(const ValueKey('WindowsAppTitleBar.MaximizeButton')),
    );
    await tester.tap(
      find.byKey(const ValueKey('WindowsAppTitleBar.CloseButton')),
    );

    expect(desktopService.minimizeWindowCount, 1);
    expect(desktopService.toggleWindowMaximizedCount, 1);
    expect(desktopService.closeWindowCount, 1);
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
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(nightMode: NightMode.onMode),
    );
    final desktopService = _ShellDesktopFeatureService();

    await tester.pumpWidget(_ShellPageTestApp(desktopService: desktopService));
    await tester.pumpAndSettle();

    expect(desktopService.windowControlsLight, isTrue);
  });

  testWidgets('shell fullscreen change events do not exit immersive route', (
    tester,
  ) async {
    final desktopService = _ShellDesktopFeatureService();
    final navigations = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        child: SmPlayerI18nScope(
          i18n: const SmPlayerI18n(locale: 'en-US', messages: {}),
          child: MaterialApp(
            theme: buildSmPlayerTheme(const SettingsSnapshot.defaults()),
            home: SmPlayerShellPage(
              currentPath: '/immersive-mode',
              desktopFeatureService: desktopService,
              initialDisplayMode: SmPlayerDisplayMode.fullScreen,
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

    expect(navigations, isEmpty);
    expect(
      smPlayerGlobalSettingsSnapshot.lastDisplayMode,
      SmPlayerDisplayMode.immersive,
    );
  });

  testWidgets(
    'shell records native fullscreen separately from immersive mode',
    (tester) async {
      final desktopService = _ShellDesktopFeatureService();

      await tester.pumpWidget(
        _ShellPageTestApp(
          desktopService: desktopService,
          currentPath: '/songs',
        ),
      );
      await tester.pump();

      desktopService.emit(
        const DesktopFeatureAction(
          DesktopFeatureCommand.windowFullScreenChanged,
          isWindowFullScreen: true,
        ),
      );
      await tester.pump();

      expect(
        smPlayerGlobalSettingsSnapshot.lastDisplayMode,
        SmPlayerDisplayMode.fullScreen,
      );
    },
  );

  testWidgets('release notes open after app version upgrade', (tester) async {
    _setViewSize(tester, const Size(1300, 700));
    setSmPlayerGlobalSettingsSnapshot(
      const SettingsSnapshot.defaults().copyWith(
        lastReleaseNotesVersion: '0.9.0',
      ),
    );

    await tester.pumpWidget(
      const _ShellPageTestApp(
        appVersion: '1.0.0',
        messages: _releaseNotesMessages,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Release Notes'), findsOneWidget);
    expect(find.text('Version 3.0.0'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('popup-dialog-overlay'))),
      const Size(1300, 700),
    );

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(smPlayerGlobalSettingsSnapshot.lastReleaseNotesVersion, '1.0.0');
    expect(find.text('Release Notes'), findsNothing);
  });
}

class _ShellPageTestApp extends StatelessWidget {
  const _ShellPageTestApp({
    this.appVersion,
    this.messages = const {},
    this.repository,
    this.desktopService,
    this.initialDisplayMode = SmPlayerDisplayMode.normal,
    this.currentPath,
    this.currentLocation,
    this.onNavigate,
    this.child,
  });

  final String? appVersion;
  final Map<String, String> messages;
  final LibraryRepository? repository;
  final DesktopFeatureService? desktopService;
  final SmPlayerDisplayMode initialDisplayMode;
  final String? currentPath;
  final String? currentLocation;
  final ValueChanged<String>? onNavigate;
  final Widget? child;

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
          theme: buildSmPlayerTheme(const SettingsSnapshot.defaults()),
          home: SmPlayerShellPage(
            appVersion: appVersion,
            desktopFeatureService: desktopService,
            initialDisplayMode: initialDisplayMode,
            currentPath: currentPath,
            currentLocation: currentLocation,
            onNavigate: onNavigate,
            child: child,
          ),
        ),
      ),
    );
  }
}

MediaSessionDisplayState _lastActiveMediaSession(
  _ShellDesktopFeatureService desktopService,
) {
  return desktopService.mediaSessions.lastWhere((state) => state.active);
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

  LibraryContentData snapshot;
  var getLibraryContentDataCount = 0;
  var artworkSnapshotRequestCount = 0;
  final artworkSnapshotSongIds = <int>[];
  final favoriteWrites = <({List<int> songIds, bool favorite})>[];
  final replaceNowPlayingCalls = <List<int>>[];

  @override
  Future<LibraryContentData> getLibraryContentData() async {
    getLibraryContentDataCount += 1;
    return snapshot;
  }

  @override
  Future<SongPropertiesSnapshot> getSongProperties(int songId) async {
    final song = snapshot.songs.firstWhere((song) => song.id == songId);
    return SongPropertiesSnapshot(
      songId: song.id,
      path: song.path,
      title: song.title,
      subtitle: '',
      artist: song.artist,
      artists: song.artists,
      album: song.album,
      albumArtist: '',
      publisher: '',
      trackNumber: 0,
      year: 0,
      genre: '',
      composers: '',
      duration: song.duration,
      bitrate: 0,
      fileSize: 1024,
      dateCreated: '2026-01-01T00:00:00Z',
      dateModified: '2026-01-01T00:00:00Z',
      fileType: 'MP3',
      playCount: song.playCount,
    );
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

  @override
  Future<void> setSongsFavorite(List<int> songIds, bool favorite) async {
    favoriteWrites.add((songIds: songIds, favorite: favorite));
    snapshot = _snapshotWithFavoriteSongs(snapshot, songIds, favorite);
  }

  @override
  Future<void> replaceNowPlaying(List<int> songIds) async {
    replaceNowPlayingCalls.add(songIds);
  }
}

LibraryContentData _snapshotWithFavoriteSongs(
  LibraryContentData snapshot,
  List<int> songIds,
  bool favorite,
) {
  final songIdSet = songIds.toSet();
  final songs =
      snapshot.songs.map((song) {
        if (!songIdSet.contains(song.id)) {
          return song;
        }
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
      }).toList();
  final playlists =
      snapshot.playlists.map((playlist) {
        if (playlist.id != snapshot.favoritePlaylistId) {
          return playlist;
        }
        final nextSongIds = [
          if (favorite) ...{
            ...playlist.songIds,
            ...songIds,
          } else
            ...playlist.songIds.where((songId) => !songIdSet.contains(songId)),
        ];
        return LibraryPlaylist(
          id: playlist.id,
          name: playlist.name,
          priority: playlist.priority,
          songCount: nextSongIds.length,
          songIds: nextSongIds,
          sortCriterion: playlist.sortCriterion,
          isBuiltIn: playlist.isBuiltIn,
        );
      }).toList();

  return LibraryContentData(
    songs: songs,
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
    localViewMode: snapshot.localViewMode,
    rootPath: snapshot.rootPath,
    databasePath: snapshot.databasePath,
  );
}

LibraryPlaylist _snapshotFavoritePlaylist(LibraryContentData snapshot) {
  return snapshot.playlists.firstWhere(
    (playlist) => playlist.id == snapshot.favoritePlaylistId,
  );
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
  var minimizeWindowCount = 0;
  var toggleWindowMaximizedCount = 0;
  var closeWindowCount = 0;
  var enterMiniModeCount = 0;
  var exitMiniModeCount = 0;
  bool? windowControlsLight;
  var windowMaximized = false;

  void emit(DesktopFeatureAction action) {
    if (action.isWindowVisible case final isVisible?) {
      windowVisible = isVisible;
    }
    if (action.isWindowFullScreen case final isFullScreen?) {
      windowFullScreen = isFullScreen;
    }
    if (action.isWindowMaximized case final isMaximized?) {
      windowMaximized = isMaximized;
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
  Future<void> enterMiniMode() async {
    enterMiniModeCount += 1;
  }

  @override
  Future<void> exitMiniMode() async {
    exitMiniModeCount += 1;
  }

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
  Future<bool> getWindowMaximized() async {
    return windowMaximized;
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
  Future<void> minimizeWindow() async {
    minimizeWindowCount += 1;
  }

  @override
  Future<void> toggleWindowMaximized() async {
    toggleWindowMaximizedCount += 1;
    windowMaximized = !windowMaximized;
    emit(
      DesktopFeatureAction(
        DesktopFeatureCommand.windowMaximizedChanged,
        isWindowMaximized: windowMaximized,
      ),
    );
  }

  @override
  Future<void> closeWindow() async {
    closeWindowCount += 1;
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
