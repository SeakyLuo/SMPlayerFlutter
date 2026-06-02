import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/album_tile.dart'
    show AlbumTile, AlbumTileData, getAlbumArtworkSong;
import 'package:smplayer_flutter/src/library/ui/albums_page.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/page_search_history_panel.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';

void main() {
  setUp(PageSelectionController.clearStoredStates);

  const i18n = SmPlayerI18n(
    locale: 'zh-CN',
    messages: {
      'albums.addSelectedTo': '添加到',
      'albums.clearSelection': '清除选择',
      'albums.multiSelect': '多选',
      'albums.noMatch': '没有匹配的专辑',
      'albums.noMatchCopy': '换一个专辑或歌手关键词试试。',
      'albums.playSelected': '播放',
      'albums.reverseSelection': '反选',
      'albums.searchAlbumPlaceholder': '搜索专辑',
      'albums.selectAll': '全选',
      'albums.selectedCount': '已选择 {count} 项',
      'albums.sort.artist': '歌手',
      'albums.sort.default': '默认排序',
      'albums.sort.name': '名称',
      'albums.sort.reverse': '反向',
      'collection.noAlbums': '还没有专辑',
      'collection.scanFirst': '请先选择音乐文件夹并扫描。',
      'common.albumUnknown': '未知专辑',
      'common.artistUnknown': '未知歌手',
      'common.cancel': '取消',
      'common.albums': 'Albums',
      'common.multiSelect': 'Multi Select',
      'common.myFavorites': 'My Favorites',
      'common.clear': 'Clear',
      'common.close': 'Close',
      'common.nowPlaying': 'Now Playing',
      'common.search': 'Search',
      'common.sort': '排序',
      'common.undo': 'Undo',
      'context.addToPlaylist': '添加到',
      'context.select': '选择',
      'context.seeAlbumArt': '查看专辑插图',
      'local.sortReverseList': 'Reverse List',
      'nowPlaying.randomPlay': '随机播放',
      'nowPlaying.loading': '加载中',
      'notification.songAddedTo': 'Added {title} to {target}',
      'notification.songsAddedTo': 'Added {count} songs to {target}',
      'playlists.newPlaylist': 'New Playlist',
      'preferences.level.dislike': 'Dislike',
      'preferences.level.do-not-appear': 'Do Not Appear',
      'preferences.level.high': 'High',
      'preferences.level.higher': 'Higher',
      'preferences.level.normal': 'Normal',
      'preferences.level.very-high': 'Very High',
      'preferences.undoPrefer': 'Undo Prefer',
      'sidebar.recentSearches': 'Recent searches',
      'sidebar.removeRecentSearch': 'Remove {query}',
      'settings.preferenceSettings': 'Preference Settings',
      'player.more': '更多',
    },
  );

  testWidgets('AlbumsPage uses shared multi-select command bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _AlbumsTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await _tapAlbumsCommand(tester, i18n.t('common.multiSelect'));
    await tester.tap(find.text('Blue Hour'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 项'), findsOneWidget);

    await tester.tap(find.text('反选'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 项'), findsOneWidget);
    expect(find.text('Red Days'), findsOneWidget);
  });

  testWidgets('AlbumsPage multi-select bar bleeds to workspace edges', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _AlbumsTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await _tapAlbumsCommand(tester, i18n.t('common.multiSelect'));
    await tester.pumpAndSettle();

    final surfaceRect = tester.getRect(
      find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
    );
    expect(surfaceRect.left, 0);
    expect(surfaceRect.right, 1200);
    expect(surfaceRect.width, 1200);
    expect(surfaceRect.bottom, 800 - multiSelectCommandBarShellBottomInset);
  });

  testWidgets('AlbumsPage context menu can enter selection mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _AlbumsTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Hour'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 项'), findsOneWidget);
  });

  testWidgets('AlbumsPage context menu uses Electron Add To submenu', (
    tester,
  ) async {
    await tester.pumpWidget(
      _AlbumsTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Hour'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text(i18n.t('context.addToPlaylist')), findsAtLeastNWidgets(1));
    expect(find.text('Mix'), findsNothing);
    expect(find.text('Built in'), findsNothing);

    await tester.tap(find.text(i18n.t('context.addToPlaylist')).last);
    await tester.pumpAndSettle();

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('My Favorites'), findsOneWidget);
    expect(find.text('New Playlist'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);
    expect(find.text('Built in'), findsNothing);
  });

  testWidgets('AlbumsPage context shuffle records the album like Electron', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _AlbumsTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Hour'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(i18n.t('nowPlaying.randomPlay')));
    await tester.pumpAndSettle();

    expect(repository.recordedAlbums, ['Blue Hour']);
    expect(repository.replacedNowPlaying, [1]);
    expect(mediaController.state.track.id, 1);
  });

  testWidgets('AlbumsPage context shuffle keeps Electron raw album grouping', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();
    const snapshot = LibraryContentData(
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
        LibrarySong(
          id: 2,
          path: r'C:\Music\spaced-blue.mp3',
          title: 'Spaced Blue Song',
          artist: 'Artist A',
          artists: ['Artist A'],
          album: ' Blue Hour ',
          duration: 120,
          playCount: 0,
          lyricsOffsetMs: 0,
          dateAdded: '2026-05-20T00:00:00',
          favorite: false,
          thumbnailPath: '',
        ),
      ],
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
      favoritePlaylistId: 1,
      nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
      hasLibrary: true,
      sortCriterion: MusicLibrarySortCriterion.title,
      albumsSort: AlbumSortCriterion.defaultSort,
      showCount: true,
      hideMultiSelectCommandBarAfterOperation: true,
      databasePath: '',
    );

    await tester.pumpWidget(
      _AlbumsTestApp(
        snapshot: snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Hour'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(i18n.t('nowPlaying.randomPlay')));
    await tester.pumpAndSettle();

    expect(repository.recordedAlbums, ['Blue Hour']);
    expect(repository.replacedNowPlaying, [1]);
    expect(mediaController.state.track.id, 1);
  });

  testWidgets(
    'AlbumsPage context shuffle waits for queue before MediaControl',
    (tester) async {
      final repository = _DelayedReplaceLibraryRepository();
      final mediaController = MediaControlController();

      await tester.pumpWidget(
        _AlbumsTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: mediaController,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blue Hour'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text(i18n.t('nowPlaying.randomPlay')));
      await tester.pump();

      expect(repository.pendingReplaceSongIds, [1]);
      expect(mediaController.state.track.id, isNull);

      repository.completeReplace();
      await tester.pumpAndSettle();

      expect(repository.replacedNowPlaying, [1]);
      expect(mediaController.state.track.id, 1);
      expect(mediaController.state.selectedQueueIndex, 0);
    },
  );

  testWidgets('AlbumsPage context menu writes Electron album preference', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _AlbumsTestApp(snapshot: _snapshot, i18n: i18n, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Hour'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preference Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Do Not Appear'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);

    await tester.tap(find.text('High'));
    await tester.pump();

    expect(repository.preferenceType, 'album');
    expect(repository.preferenceItemId, 'Blue Hour');
    expect(repository.preferenceName, 'Blue Hour');
    expect(repository.preferenceLevel, 'high');
  });

  testWidgets('AlbumsPage context menu shows Electron current preference', (
    tester,
  ) async {
    final repository =
        _FakeLibraryRepository()..existingPreferenceLevel = 'high';

    await tester.pumpWidget(
      _AlbumsTestApp(snapshot: _snapshot, i18n: i18n, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Hour'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preference Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Undo Prefer'), findsOneWidget);

    await tester.tap(find.text('Undo Prefer'));
    await tester.pump();

    expect(repository.removedPreferenceType, 'album');
    expect(repository.removedPreferenceItemId, 'Blue Hour');
  });

  testWidgets('AlbumsPage context menu opens Electron album art preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      _AlbumsTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Hour'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看专辑插图'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('Albums.ArtPreview.Dialog')),
      findsOneWidget,
    );
    expect(find.text('Blue Hour'), findsWidgets);

    final backdropTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('Albums.ArtPreview.Backdrop')),
    );
    await tester.tapAt(backdropTopLeft + const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('Albums.ArtPreview.Dialog')),
      findsNothing,
    );
  });

  testWidgets('AlbumsPage exposes Electron appbar search entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _AlbumsAppBarPortalTestApp(snapshot: _snapshot, i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('Albums.AppBar.Search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Red');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.byKey(const ValueKey('Albums.Progress')), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Red Days'), findsOneWidget);
    expect(find.text('Blue Hour'), findsNothing);
    expect(
      find.byKey(const ValueKey('Albums.AppBar.SearchField')),
      findsNothing,
    );
  });

  testWidgets(
    'AlbumsPage appbar search separates clear and close like Electron',
    (tester) async {
      await tester.pumpWidget(
        _AlbumsAppBarPortalTestApp(snapshot: _snapshot, i18n: i18n),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('Albums.AppBar.Search')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Red');
      await tester.pumpAndSettle();

      expect(find.byTooltip('Clear'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
      expect(find.byTooltip('Close'), findsOneWidget);
    },
  );

  testWidgets('AlbumsPage loading state shows Electron progress strip', (
    tester,
  ) async {
    final loading = Completer<LibraryContentData>();

    await tester.pumpWidget(
      _AlbumsLoadingTestApp(snapshotFuture: loading.future, i18n: i18n),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('Albums.Progress')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AlbumsPage page search caps width like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _AlbumsTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(PageSearchField).first).width, 360);
  });

  testWidgets('AlbumsPage search history overlays without moving grid', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _AlbumsTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        darkMode: true,
      ),
    );
    await tester.pumpAndSettle();

    final firstTile = find.byKey(const ValueKey('AlbumTile.Container')).first;
    final tileTopBefore = tester.getTopLeft(firstTile).dy;

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    final historyPanel = find.byType(PageSearchHistoryPanel);
    expect(
      find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Red')),
      findsOneWidget,
    );
    expect(tester.getSize(historyPanel).width, 360);
    expect(tester.getSize(historyPanel).height, lessThan(160));
    expect(tester.getTopLeft(firstTile).dy, tileTopBefore);

    final glassPanel = tester.widget<GlassContainer>(
      find.descendant(of: historyPanel, matching: find.byType(GlassContainer)),
    );
    expect(glassPanel.quality, GlassQuality.minimal);
    expect(glassPanel.settings?.blur, 46);
    expect(glassPanel.settings?.saturation, 1.65);
    expect(glassPanel.settings?.standardOpacityMultiplier, 0.32);

    final panelDecoration = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: historyPanel,
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.border != null);
    final panelBorder = panelDecoration.border as Border;
    expect(panelBorder.top.color, const Color(0x38d6e0ec));
    expect(panelBorder.top.width, 1);
  });

  testWidgets('AlbumsPage multi-select play replaces Now Playing', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _AlbumsTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await _tapAlbumsCommand(tester, i18n.t('common.multiSelect'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Hour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(i18n.t('albums.playSelected')));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1]);
    expect(mediaController.state.track.id, 1);
    expect(mediaController.state.isPlaying, isTrue);
  });

  testWidgets(
    'AlbumsPage multi-select Play respects Electron hide preference',
    (tester) async {
      final repository = _FakeLibraryRepository();

      await tester.pumpWidget(
        _AlbumsTestApp(
          snapshot: _keepSelectionSnapshot,
          i18n: i18n,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await _tapAlbumsCommand(tester, i18n.t('common.multiSelect'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue Hour'));
      await tester.pumpAndSettle();
      expect(
        find.text(i18n.t('albums.selectedCount', {'count': 1})),
        findsOneWidget,
      );

      await tester.tap(find.text(i18n.t('albums.playSelected')));
      await tester.pumpAndSettle();

      expect(repository.replacedNowPlaying, [1]);
      expect(
        find.text(i18n.t('albums.selectedCount', {'count': 1})),
        findsOneWidget,
      );
    },
  );

  testWidgets('AlbumsPage multi-select adds album songs to playlist', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _AlbumsTestApp(snapshot: _snapshot, i18n: i18n, repository: repository),
    );
    await tester.pumpAndSettle();

    await _tapAlbumsCommand(tester, i18n.t('common.multiSelect'));
    await tester.tap(find.text('Blue Hour'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(i18n.t('albums.addSelectedTo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();

    expect(repository.addedPlaylistId, 10);
    expect(repository.addedSongIds, [1]);
    expect(find.text('Added Blue Song to Mix'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.removedPlaylistId, 10);
    expect(repository.removedSongIds, [1]);
  });

  testWidgets('AlbumsPage exits multi-select in compact layout like Electron', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_AlbumsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(
      find.text(i18n.t('albums.selectedCount', {'count': 0})),
      findsNothing,
    );
  });

  testWidgets('AlbumsPage keeps quick jump visible in compact layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_AlbumsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('Albums.QuickJump.B')), findsOneWidget);
    expect(find.byKey(const ValueKey('Albums.QuickJump.R')), findsOneWidget);
  });

  testWidgets('AlbumsPage grid uses Electron two-row overscan', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_AlbumsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(
      tester.widget<GridView>(find.byType(GridView)).scrollCacheExtent,
      const ScrollCacheExtent.pixels(500),
    );
  });

  testWidgets('AlbumsPage compact grid uses Electron compact overscan', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_AlbumsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(
      tester.widget<GridView>(find.byType(GridView)).scrollCacheExtent,
      const ScrollCacheExtent.pixels(468),
    );
  });

  testWidgets('AlbumsPage uses Electron night colors in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _AlbumsTestApp(snapshot: _snapshot, i18n: i18n, darkMode: true),
    );
    await tester.pumpAndSettle();

    final albumTitleColors =
        tester
            .widgetList<Text>(find.text('Blue Hour'))
            .map((widget) => widget.style?.color)
            .toSet();
    expect(albumTitleColors, contains(const Color(0xf0f6f9fc)));
    expect(
      _quickJumpForeground(tester, 'B', const {}),
      const Color(0xff459de2),
    );
    final artworkDecoration =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey('AlbumTile.ArtworkSurface')).first,
                )
                .decoration
            as BoxDecoration;
    expect(artworkDecoration.color, const Color(0x14ffffff));
    expect(artworkDecoration.boxShadow!.single.color, const Color(0x4d000000));
    expect(artworkDecoration.boxShadow!.single.blurRadius, 18);
    expect(artworkDecoration.boxShadow!.single.offset, const Offset(0, 8));
  });

  testWidgets('AlbumsPage album item matches Electron tile styling', (
    tester,
  ) async {
    await tester.pumpWidget(_AlbumsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    final tileFinder = find.byKey(const ValueKey('AlbumTile.Container')).first;
    expect(tester.getSize(tileFinder).width, 180);
    final tile = tester.widget<AnimatedContainer>(tileFinder);
    expect(tile.constraints!.minHeight, 232);
    expect(tile.padding, const EdgeInsets.all(10));
    final baseDecoration = tile.decoration! as BoxDecoration;
    expect(baseDecoration.borderRadius, BorderRadius.circular(12));
    expect(baseDecoration.color, const Color(0x000078d7));
    expect(baseDecoration.border!.top.color, const Color(0x000078d7));

    final artworkDecoration =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey('AlbumTile.ArtworkSurface')).first,
                )
                .decoration
            as BoxDecoration;
    expect(artworkDecoration.color, const Color(0xb8ffffff));
    expect(artworkDecoration.borderRadius, BorderRadius.circular(8));
    expect(artworkDecoration.boxShadow!.single.color, const Color(0x21202d3f));
    expect(artworkDecoration.boxShadow!.single.blurRadius, 18);
    expect(artworkDecoration.boxShadow!.single.offset, const Offset(0, 8));

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(pointer.removePointer);
    await pointer.addPointer();
    final baseArtworkSize = tester.getSize(
      find.byKey(const ValueKey('AlbumTile.ArtworkSurface')).first,
    );
    await pointer.moveTo(tester.getCenter(tileFinder));
    await tester.pumpAndSettle();

    final hoverDecoration =
        tester.widget<AnimatedContainer>(tileFinder).decoration!
            as BoxDecoration;
    expect(hoverDecoration.color, const Color(0x140078d7));
    expect(hoverDecoration.border!.top.color, const Color(0x260078d7));
    expect(hoverDecoration.boxShadow!.single.color, const Color(0x000078d7));
    expect(hoverDecoration.boxShadow!.single.blurRadius, 0);
    expect(hoverDecoration.boxShadow!.single.offset, Offset.zero);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('AlbumTile.ArtworkSurface')).first,
      ),
      baseArtworkSize,
    );
  });

  testWidgets('AlbumTile selected state uses shared clean card style', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: Scaffold(
            body: AlbumTile(
              album: AlbumTileData(
                name: 'Blue Hour',
                artist: 'Artist A',
                songs: [_snapshot.songs.first],
                duration: 120,
              ),
              multiSelect: true,
              selected: true,
              onOpenAlbum: () {},
              onPlayAlbum: () {},
              onAddAlbum: (_) {},
              onToggleSelection: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final tile = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('AlbumTile.Container')),
    );
    final decoration = tile.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xffd9ecfb));
    expect(decoration.border!.top.color, const Color(0x260078d7));
    expect(decoration.boxShadow, const [
      BoxShadow(color: Color(0x300078d7), offset: Offset(0, 8), blurRadius: 18),
    ]);
    final artworkDecoration =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey('AlbumTile.ArtworkSurface')),
                )
                .decoration
            as BoxDecoration;
    expect(artworkDecoration.boxShadow, const [
      BoxShadow(color: Color(0x120078d7), offset: Offset(0, 4), blurRadius: 10),
    ]);

    final title = tester.widget<Text>(find.text('Blue Hour'));
    final subtitle = tester.widget<Text>(find.text('Artist A'));
    expect(title.style?.color, const Color(0xff0063b1));
    expect(subtitle.style?.color, const Color(0xff0063b1));
  });

  testWidgets('AlbumsPage reverse sort persists like Electron local state', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_AlbumsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Blue Hour')).dx,
      lessThan(tester.getTopLeft(find.text('Red Days')).dx),
    );

    await tester.tap(find.text(i18n.t('albums.sort.default')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(i18n.t('local.sortReverseList')));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Red Days')).dx,
      lessThan(tester.getTopLeft(find.text('Blue Hour')).dx),
    );
  });

  testWidgets('AlbumsPage quick jump keeps clicked key active on same row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_AlbumsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    expect(_quickJumpBackground(tester, 'B'), isNot(Colors.transparent));
    expect(_quickJumpBackground(tester, 'R'), Colors.transparent);

    await tester.tap(find.byKey(const ValueKey('Albums.QuickJump.R')));
    await tester.pumpAndSettle();

    expect(_quickJumpBackground(tester, 'B'), Colors.transparent);
    expect(_quickJumpBackground(tester, 'R'), isNot(Colors.transparent));
  });

  testWidgets('AlbumsPage syncs Electron sort setting with selection', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final snapshot = ValueNotifier(_albumSortDefaultSnapshot);
    final repository = _ValueListenableAlbumsRepository(snapshot);

    await tester.pumpWidget(
      _AlbumsSnapshotListenableTestApp(
        snapshot: snapshot,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Alpha Album')).dx,
      lessThan(tester.getTopLeft(find.text('Zeta Album')).dx),
    );

    await tester.tap(find.text(i18n.t('common.multiSelect')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha Album'));
    await tester.pumpAndSettle();

    snapshot.value = _albumSortArtistSnapshot;
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Zeta Album')).dx,
      lessThan(tester.getTopLeft(find.text('Alpha Album')).dx),
    );
  });

  testWidgets('AlbumsPage album play records the album like Electron', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _AlbumsTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.text('Blue Hour')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SmPlayerPlayIcon).first);
    await tester.pumpAndSettle();

    expect(repository.recordedAlbums, ['Blue Hour']);
    expect(repository.replacedNowPlaying, [1]);
    expect(mediaController.state.track.id, 1);
    await gesture.removePointer();
  });

  testWidgets('AlbumsPage opens album tiles through the Electron query route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/albums',
      routes: [
        GoRoute(
          path: '/albums',
          builder:
              (context, state) => Scaffold(
                body: AlbumsPage(
                  targetAlbumName: state.uri.queryParameters['album'],
                ),
              ),
        ),
      ],
    );

    await tester.pumpWidget(
      _AlbumsRouterTestApp(snapshot: _snapshot, i18n: i18n, router: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Hour'));
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/albums');
    expect(uri.queryParameters['album'], 'Blue Hour');
  });

  testWidgets('AlbumsPage records submitted album searches', (tester) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _AlbumsTestApp(snapshot: _snapshot, i18n: i18n, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), ' Blue ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.byKey(const ValueKey('Albums.Progress')), findsOneWidget);

    await tester.pumpAndSettle();

    expect(repository.recordedSearches, [
      (query: 'Blue', type: SearchHistoryType.albums),
    ]);
  });

  testWidgets('AlbumsPage shows compact loading during empty processing', (
    tester,
  ) async {
    await tester.pumpWidget(_AlbumsTestApp(snapshot: _snapshot, i18n: i18n));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Missing');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.byKey(const ValueKey('Albums.Progress')), findsOneWidget);
    expect(find.text(i18n.t('nowPlaying.loading')), findsOneWidget);
    expect(find.text(i18n.t('albums.noMatch')), findsNothing);

    await tester.pumpAndSettle();

    expect(find.text(i18n.t('albums.noMatch')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('Albums.EmptyState'))).height,
      lessThan(100),
    );
  });

  testWidgets('AlbumsPage clears only visible album search history', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _AlbumsTestApp(
        snapshot: _snapshotWithManyRecentSearches,
        i18n: i18n,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text(i18n.t('common.clear')).last);
    await tester.pump();

    expect(
      repository.removedRecentSearchIds,
      List.generate(10, (index) => index + 1),
    );
  });

  test('searchAlbums follows Electron album-name scope', () {
    final albums = buildAlbumViews(_snapshot.songs, i18n);

    expect(searchAlbums(albums, 'Artist A'), isEmpty);
    expect(searchAlbums(albums, 'Blue').map((album) => album.name), [
      'Blue Hour',
    ]);
  });

  test('album artwork picks first song with artwork like Electron', () {
    expect(getAlbumArtworkSong(_albumArtworkSongs).id, 2);
  });

  test('buildAlbumViews keeps Electron source-order artwork', () {
    final albums = buildAlbumViews(_albumArtworkSourceOrderSongs, i18n);

    expect(albums.single.songs.map((song) => song.id), [4, 3]);
    expect(albums.single.artworkSong!.id, 3);
  });

  testWidgets('AlbumsPage selects album search suggestions', (tester) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _AlbumsTestApp(snapshot: _snapshot, i18n: i18n, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Blu');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Blue Hour')),
    );
    await tester.pumpAndSettle();

    expect(repository.recordedSearches, [
      (query: 'Blue Hour', type: SearchHistoryType.albums),
    ]);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Blue Hour',
    );
    expect(find.text('Red Days'), findsNothing);
  });

  testWidgets('AlbumsPage selects recent album searches', (tester) async {
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _AlbumsTestApp(snapshot: _snapshot, i18n: i18n, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('PageSearchHistoryPanel.Item.red')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('PageSearchHistoryPanel.Item.Red')),
    );
    await tester.pumpAndSettle();

    expect(repository.recordedSearches, [
      (query: 'Red', type: SearchHistoryType.albums),
    ]);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Red',
    );
    expect(find.text('Blue Hour'), findsNothing);
  });
}

Color? _quickJumpBackground(WidgetTester tester, String key) {
  final button = tester.widget<TextButton>(
    find.byKey(ValueKey('Albums.QuickJump.$key')),
  );
  return button.style?.backgroundColor?.resolve({});
}

Color? _quickJumpForeground(
  WidgetTester tester,
  String key,
  Set<WidgetState> states,
) {
  final button = tester.widget<TextButton>(
    find.byKey(ValueKey('Albums.QuickJump.$key')),
  );
  return button.style?.foregroundColor?.resolve(states);
}

Future<void> _tapAlbumsCommand(WidgetTester tester, String label) async {
  final direct = find.text(label).hitTestable();
  if (direct.evaluate().isNotEmpty) {
    await tester.tap(direct.first);
    await tester.pumpAndSettle();
    return;
  }
  final tooltip = find.byTooltip(label).hitTestable();
  if (tooltip.evaluate().isNotEmpty) {
    await tester.tap(tooltip.first);
    await tester.pumpAndSettle();
    return;
  }
  await tester.tap(
    find.byKey(const ValueKey('CommandBar.MoreButton')).hitTestable().last,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

class _AlbumsRouterTestApp extends StatelessWidget {
  const _AlbumsRouterTestApp({
    required this.snapshot,
    required this.i18n,
    required this.router,
  });

  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp.router(
          theme: _albumsPageTestTheme(),
          routerConfig: router,
        ),
      ),
    );
  }
}

class _AlbumsTestApp extends StatelessWidget {
  const _AlbumsTestApp({
    required this.snapshot,
    required this.i18n,
    this.repository,
    this.mediaController,
    this.darkMode = false,
  });

  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final LibraryRepository? repository;
  final MediaControlController? mediaController;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
        if (repository != null)
          libraryRepositoryProvider.overrideWithValue(repository!),
        if (mediaController != null)
          mediaControlControllerProvider.overrideWith(
            (ref) => mediaController!,
          ),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _albumsPageTestTheme(
            brightness: darkMode ? Brightness.dark : Brightness.light,
          ),
          home: const Scaffold(body: AlbumsPage()),
        ),
      ),
    );
  }
}

class _AlbumsAppBarPortalTestApp extends StatelessWidget {
  const _AlbumsAppBarPortalTestApp({
    required this.snapshot,
    required this.i18n,
  });

  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _albumsPageTestTheme(),
          home: Scaffold(
            body: Column(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final entry = ref.watch(workspaceAppBarPortalProvider);
                    return SizedBox(height: 80, child: entry?.content);
                  },
                ),
                const Expanded(
                  child: WorkspaceNavigationAppBarScope(
                    active: true,
                    child: AlbumsPage(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumsLoadingTestApp extends StatelessWidget {
  const _AlbumsLoadingTestApp({
    required this.snapshotFuture,
    required this.i18n,
  });

  final Future<LibraryContentData> snapshotFuture;
  final SmPlayerI18n i18n;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryContentDataProvider.overrideWith((ref) => snapshotFuture),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _albumsPageTestTheme(),
          home: const Scaffold(body: AlbumsPage()),
        ),
      ),
    );
  }
}

class _AlbumsSnapshotListenableTestApp extends StatelessWidget {
  const _AlbumsSnapshotListenableTestApp({
    required this.snapshot,
    required this.i18n,
    required this.repository,
  });

  final ValueNotifier<LibraryContentData> snapshot;
  final SmPlayerI18n i18n;
  final _ValueListenableAlbumsRepository repository;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryRepositoryProvider.overrideWithValue(repository),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: _AlbumsSnapshotInvalidator(snapshot: snapshot),
      ),
    );
  }
}

class _AlbumsSnapshotInvalidator extends ConsumerStatefulWidget {
  const _AlbumsSnapshotInvalidator({required this.snapshot});

  final ValueNotifier<LibraryContentData> snapshot;

  @override
  ConsumerState<_AlbumsSnapshotInvalidator> createState() =>
      _AlbumsSnapshotInvalidatorState();
}

class _AlbumsSnapshotInvalidatorState
    extends ConsumerState<_AlbumsSnapshotInvalidator> {
  @override
  void initState() {
    super.initState();
    widget.snapshot.addListener(_invalidateSnapshot);
  }

  @override
  void didUpdateWidget(_AlbumsSnapshotInvalidator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) {
      oldWidget.snapshot.removeListener(_invalidateSnapshot);
      widget.snapshot.addListener(_invalidateSnapshot);
    }
  }

  @override
  void dispose() {
    widget.snapshot.removeListener(_invalidateSnapshot);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: _albumsPageTestTheme(),
      home: const Scaffold(body: AlbumsPage()),
    );
  }

  void _invalidateSnapshot() {
    ref.invalidate(libraryContentDataProvider);
  }
}

ThemeData _albumsPageTestTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  return ThemeData(
    brightness: brightness,
    extensions: [
      dark
          ? DefaultAlbumArtworkThemeColors.dark
          : DefaultAlbumArtworkThemeColors.light,
      dark ? AppNotificationThemeColors.dark : AppNotificationThemeColors.light,
    ],
  );
}

class _FakeLibraryRepository extends LibraryRepository {
  List<int> replacedNowPlaying = [];
  int? addedPlaylistId;
  List<int> addedSongIds = [];
  int? removedPlaylistId;
  List<int> removedSongIds = [];
  List<int> favoriteSongIds = [];
  bool? favoriteValue;
  List<String> recordedAlbums = [];
  List<({String query, SearchHistoryType type})> recordedSearches = [];
  String? preferenceType;
  String? preferenceItemId;
  String? preferenceName;
  String? preferenceLevel;
  String? existingPreferenceLevel;
  String? removedPreferenceType;
  String? removedPreferenceItemId;
  List<int> removedRecentSearchIds = [];

  @override
  Future<void> replaceNowPlaying(List<int> songIds) async {
    replacedNowPlaying = songIds.toList();
  }

  @override
  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    addedPlaylistId = playlistId;
    addedSongIds = songIds.toList();
  }

  @override
  Future<void> removeSongsFromPlaylist(
    int playlistId,
    List<int> songIds,
  ) async {
    removedPlaylistId = playlistId;
    removedSongIds = songIds.toList();
  }

  @override
  Future<void> setSongsFavorite(List<int> songIds, bool favorite) async {
    favoriteSongIds = songIds.toList();
    favoriteValue = favorite;
  }

  @override
  Future<void> recordAlbumPlayed(String album) async {
    recordedAlbums.add(album);
  }

  @override
  Future<SearchHistoryEntry?> addRecentSearch(
    String query, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) async {
    recordedSearches.add((query: query, type: type));
    return SearchHistoryEntry(
      id: recordedSearches.length,
      query: query.trim(),
      type: type,
      searchedAt: '2026-05-23T00:00:00Z',
    );
  }

  @override
  Future<void> addPreferenceItem(
    String type,
    String itemId,
    String name,
    String level,
  ) async {
    preferenceType = type;
    preferenceItemId = itemId;
    preferenceName = name;
    preferenceLevel = level;
  }

  @override
  Future<String?> getPreferenceLevel(String type, String itemId) async {
    return existingPreferenceLevel;
  }

  @override
  Future<void> removePreferenceItem(String type, String itemId) async {
    removedPreferenceType = type;
    removedPreferenceItemId = itemId;
  }

  @override
  Future<void> removeRecentSearches(List<int> ids) async {
    removedRecentSearchIds = ids.toList();
  }
}

class _DelayedReplaceLibraryRepository extends _FakeLibraryRepository {
  Completer<void>? _replaceCompleter;
  List<int> pendingReplaceSongIds = [];

  @override
  Future<void> replaceNowPlaying(List<int> songIds) async {
    pendingReplaceSongIds = songIds.toList();
    _replaceCompleter = Completer<void>();
    await _replaceCompleter!.future;
    await super.replaceNowPlaying(songIds);
  }

  void completeReplace() {
    _replaceCompleter!.complete();
  }
}

class _ValueListenableAlbumsRepository extends _FakeLibraryRepository {
  _ValueListenableAlbumsRepository(this.snapshot);

  final ValueNotifier<LibraryContentData> snapshot;

  @override
  Future<LibraryContentData> getLibraryContentData() async {
    return snapshot.value;
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
    LibrarySong(
      id: 2,
      path: r'C:\Music\red.mp3',
      title: 'Red Song',
      artist: 'Artist B',
      artists: ['Artist B'],
      album: 'Red Days',
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
  recentSearches: [
    SearchHistoryEntry(
      id: 21,
      query: 'Red',
      type: SearchHistoryType.albums,
      searchedAt: '2026-05-21T00:00:00',
    ),
    SearchHistoryEntry(
      id: 20,
      query: 'red',
      type: SearchHistoryType.albums,
      searchedAt: '2026-05-20T00:00:00',
    ),
  ],
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
  favoritePlaylistId: 1,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

final _keepSelectionSnapshot = LibraryContentData(
  songs: _snapshot.songs,
  recentSongs: _snapshot.recentSongs,
  recentPlaylists: _snapshot.recentPlaylists,
  recentAlbums: _snapshot.recentAlbums,
  recentArtists: _snapshot.recentArtists,
  recentSearches: _snapshot.recentSearches,
  playlists: _snapshot.playlists,
  favoritePlaylistId: _snapshot.favoritePlaylistId,
  nowPlaying: _snapshot.nowPlaying,
  hasLibrary: _snapshot.hasLibrary,
  sortCriterion: _snapshot.sortCriterion,
  albumsSort: _snapshot.albumsSort,
  showCount: _snapshot.showCount,
  hideMultiSelectCommandBarAfterOperation: false,
  databasePath: _snapshot.databasePath,
);

final _snapshotWithManyRecentSearches = LibraryContentData(
  songs: _snapshot.songs,
  recentSongs: _snapshot.recentSongs,
  recentPlaylists: _snapshot.recentPlaylists,
  recentAlbums: _snapshot.recentAlbums,
  recentArtists: _snapshot.recentArtists,
  recentSearches: [
    for (var index = 1; index <= 12; index += 1)
      SearchHistoryEntry(
        id: index,
        query: 'Album $index',
        type: SearchHistoryType.albums,
        searchedAt:
            '2026-05-${(30 - index).toString().padLeft(2, '0')}T00:00:00',
      ),
    const SearchHistoryEntry(
      id: 99,
      query: 'Sidebar',
      type: SearchHistoryType.sidebar,
      searchedAt: '2026-05-31T00:00:00',
    ),
  ],
  playlists: _snapshot.playlists,
  favoritePlaylistId: _snapshot.favoritePlaylistId,
  nowPlaying: _snapshot.nowPlaying,
  hasLibrary: _snapshot.hasLibrary,
  sortCriterion: _snapshot.sortCriterion,
  albumsSort: _snapshot.albumsSort,
  showCount: _snapshot.showCount,
  hideMultiSelectCommandBarAfterOperation:
      _snapshot.hideMultiSelectCommandBarAfterOperation,
  databasePath: _snapshot.databasePath,
);

const _albumSortDefaultSnapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 20,
      path: r'C:\Music\zeta.mp3',
      title: 'Zeta Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Zeta Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 21,
      path: r'C:\Music\alpha.mp3',
      title: 'Alpha Song',
      artist: 'Artist B',
      artists: ['Artist B'],
      album: 'Alpha Album',
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
  playlists: [],
  favoritePlaylistId: 1,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

final _albumSortArtistSnapshot = LibraryContentData(
  songs: _albumSortDefaultSnapshot.songs,
  recentSongs: _albumSortDefaultSnapshot.recentSongs,
  recentPlaylists: _albumSortDefaultSnapshot.recentPlaylists,
  recentAlbums: _albumSortDefaultSnapshot.recentAlbums,
  recentArtists: _albumSortDefaultSnapshot.recentArtists,
  recentSearches: _albumSortDefaultSnapshot.recentSearches,
  playlists: _albumSortDefaultSnapshot.playlists,
  favoritePlaylistId: _albumSortDefaultSnapshot.favoritePlaylistId,
  nowPlaying: _albumSortDefaultSnapshot.nowPlaying,
  hasLibrary: _albumSortDefaultSnapshot.hasLibrary,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.artist,
  showCount: _albumSortDefaultSnapshot.showCount,
  hideMultiSelectCommandBarAfterOperation:
      _albumSortDefaultSnapshot.hideMultiSelectCommandBarAfterOperation,
  databasePath: _albumSortDefaultSnapshot.databasePath,
);

const _albumArtworkSongs = [
  LibrarySong(
    id: 1,
    path: r'C:\Music\first.mp3',
    title: 'First Song',
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
  LibrarySong(
    id: 2,
    path: r'C:\Music\artwork.mp3',
    title: 'Artwork Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Blue Hour',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-19T00:00:00',
    favorite: false,
    thumbnailPath: r'C:\Music\cover.jpg',
  ),
];

const _albumArtworkSourceOrderSongs = [
  LibrarySong(
    id: 3,
    path: r'C:\Music\zulu-artwork.mp3',
    title: 'Zulu Artwork',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Blue Hour',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: r'C:\Music\zulu-cover.jpg',
  ),
  LibrarySong(
    id: 4,
    path: r'C:\Music\alpha-artwork.mp3',
    title: 'Alpha Artwork',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Blue Hour',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-19T00:00:00',
    favorite: false,
    thumbnailPath: r'C:\Music\alpha-cover.jpg',
  ),
];
