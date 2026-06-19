import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_floating_action_button.dart';
import 'package:smplayer_flutter/src/library/ui/card_corner_badge.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_card.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';
import 'package:smplayer_flutter/src/library/ui/local_content_view.dart';
import 'package:smplayer_flutter/src/library/ui/local_page_quick_jump.dart';
import 'package:smplayer_flutter/src/library/ui/playlist_artwork.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'common.folders': 'Folders',
      'common.songs': 'Songs',
      'common.artistSeparator': ', ',
      'common.artistUnknown': 'Unknown Artist',
      'context.addToPlaylist': 'Add To',
      'context.pause': 'Pause',
      'context.play': 'Play',
      'local.allSongs': 'All Songs',
      'local.folderCardStats': '{folders} folders · {songs} songs',
      'local.folderSongsShort': '{count} songs',
      'local.gridFolderPlayInfo': 'Play {name}',
      'local.openLocalButtonTooltip': 'Open local folder',
      'local.searchFolderButtonTooltip': 'Search folder',
      'local.updateFolder': 'Update Folder',
    },
  );

  testWidgets('Local content section night header matches day shape', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            extensions: const [
              DefaultAlbumArtworkThemeColors.dark,
              LocalPageColors.night,
            ],
          ),
          home: Scaffold(
            body: LocalContentSection(
              title: '文件夹',
              count: 2,
              expanded: true,
              onToggle: () {},
              child: const SizedBox(width: 320, height: 40),
            ),
          ),
        ),
      ),
    );

    final title = find.text('文件夹');
    final count = find.text('2');
    expect(title, findsOneWidget);
    expect(count, findsOneWidget);

    final header = find.ancestor(of: title, matching: find.byType(InkWell));
    final headerCenterY = tester.getCenter(header).dy;
    final titleCenterY = tester.getCenter(title).dy;
    final countCenterY = tester.getCenter(count).dy;

    expect((titleCenterY - headerCenterY).abs(), lessThanOrEqualTo(0.5));
    expect((countCenterY - headerCenterY).abs(), lessThanOrEqualTo(0.5));
    expect((titleCenterY - countCenterY).abs(), lessThanOrEqualTo(0.5));

    final titleText = tester.widget<Text>(title);
    final countText = tester.widget<Text>(count);
    expect(titleText.style?.fontSize, 16);
    expect(countText.style?.fontSize, 16);
    expect(
      find.descendant(
        of: header,
        matching: find.byIcon(FluentIcons.chevron_down_20_regular),
      ),
      findsOneWidget,
    );
    final headerContainer = tester.widget<Container>(
      find.descendant(of: header, matching: find.byType(Container)).first,
    );
    expect(headerContainer.constraints?.minHeight, 30);
    final decoration = headerContainer.decoration! as BoxDecoration;
    expect(decoration.color, Colors.transparent);
    expect(decoration.border, isNull);
    expect(decoration.borderRadius, BorderRadius.circular(8));
  });

  testWidgets('Local grid song hover mirrors Electron card surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [
              DefaultAlbumArtworkThemeColors.light,
              LocalPageColors.day,
            ],
          ),
          home: Scaffold(body: _localGridContent(i18n)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final songCard =
        find
            .ancestor(
              of: find.text('Root Song'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.constraints?.minHeight == 232 &&
                    widget.decoration is BoxDecoration,
              ),
            )
            .first;
    final songPlayButton = find.descendant(
      of: songCard,
      matching: find.byTooltip('Play'),
    );
    expect(songPlayButton, findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(songCard));
    addTearDown(gesture.removePointer);
    await tester.pump();

    expect(songPlayButton, findsOneWidget);
    final hoveredCard = tester.widget<Container>(songCard);
    final decoration = hoveredCard.decoration! as BoxDecoration;
    final foregroundDecoration =
        hoveredCard.foregroundDecoration! as BoxDecoration;
    expect(decoration.color, GlobalUI.hoverBgColorDay);
    expect(decoration.border, isNull);
    expect(
      foregroundDecoration.border,
      Border.all(color: GlobalUI.hoverBorderColorDay),
    );
    expect(decoration.boxShadow, hasLength(1));
    expect(decoration.boxShadow!.single, GlobalUI.hoverShadowDay);
  });

  testWidgets('Local grid song cover keeps Electron artwork shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [
              DefaultAlbumArtworkThemeColors.light,
              LocalPageColors.day,
            ],
          ),
          home: Scaffold(body: _localGridContent(i18n)),
        ),
      ),
    );
    await tester.pump();

    final cover = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('LocalGridSong.Cover.1')),
    );
    final decoration = cover.decoration! as BoxDecoration;
    expect(decoration.boxShadow, hasLength(1));
    expect(
      decoration.boxShadow!.single.color,
      LocalPageColors.day.artworkShadow,
    );
    expect(decoration.boxShadow!.single.offset, const Offset(0, 12));
    expect(decoration.boxShadow!.single.blurRadius, 24);
  });

  testWidgets('Local grid title sort shows Electron artist subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [
              DefaultAlbumArtworkThemeColors.light,
              LocalPageColors.day,
            ],
          ),
          home: Scaffold(body: _localGridContent(i18n)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Root Song'), findsOneWidget);
    expect(find.text('Artist A'), findsOneWidget);
    expect(find.text('Artist A · Root Album'), findsNothing);
  });

  testWidgets('Local grid song artist opens artist route', (tester) async {
    var playTrackCount = 0;
    final router = GoRouter(
      initialLocation: '/local',
      routes: [
        GoRoute(
          path: '/local',
          builder:
              (context, state) => Scaffold(
                body: _localGridContent(
                  i18n,
                  onPlayTrack: (_, _) {
                    playTrackCount += 1;
                  },
                ),
              ),
        ),
        GoRoute(
          path: '/artists',
          builder:
              (context, state) =>
                  Scaffold(body: Text(state.uri.queryParameters['artist']!)),
        ),
      ],
    );

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp.router(
          theme: ThemeData(
            extensions: const [
              DefaultAlbumArtworkThemeColors.light,
              LocalPageColors.day,
            ],
          ),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    final artistLink = find.byKey(const ValueKey('LocalGridSong.ArtistLink'));
    Text artistText() => tester.widget<Text>(
      find.descendant(of: artistLink, matching: find.byType(Text)),
    );

    expect(artistText().style?.color, const Color(0xff5b697a));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    addTearDown(mouse.removePointer);
    final artistCenter = tester.getCenter(artistLink);
    await mouse.moveTo(artistCenter);
    await tester.pump();
    await mouse.moveTo(artistCenter + const Offset(1, 0));
    await tester.pump();

    expect(artistText().style?.color, const Color(0xff0063b1));

    await tester.tap(artistLink);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/artists');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['artist'],
      'Artist A',
    );
    expect(playTrackCount, 0);
  });

  testWidgets('Local grid current song shows Electron playing wave', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [
              DefaultAlbumArtworkThemeColors.light,
              LocalPageColors.day,
            ],
          ),
          home: Scaffold(
            body: _localGridContent(i18n, selectedTrackId: 1, isPlaying: true),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('LocalGridSong.Playing.1.Wave')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('LocalGridSong.Playing.1.Backdrop')),
      findsOneWidget,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('LocalGridSong.Playing.1.Wave')),
      ),
      const Size(48, 48),
    );
    final waveGlass = tester.widget<GlassContainer>(
      find.byKey(const ValueKey('LocalGridSong.Playing.1.Backdrop')),
    );
    expect(waveGlass.useOwnLayer, isTrue);
    expect(waveGlass.shape, isA<LiquidOval>());

    final firstHeight = _playingBarHeight(tester, 'LocalGridSong.Playing.1', 0);
    await tester.pump(const Duration(milliseconds: 390));

    expect(
      _playingBarHeight(tester, 'LocalGridSong.Playing.1', 0),
      isNot(firstHeight),
    );
  });

  testWidgets('Local grid current selected song keeps idle playing surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [
              DefaultAlbumArtworkThemeColors.light,
              LocalPageColors.day,
            ],
          ),
          home: Scaffold(
            body: _localGridContent(
              i18n,
              selectedTrackId: 1,
              isPlaying: true,
              selectedSongIds: const {1},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Pause'), findsNothing);
    expect(
      find.byKey(const ValueKey('LocalGridSong.Playing.1.Backdrop')),
      findsOneWidget,
    );

    final songCard =
        find
            .ancestor(
              of: find.text('Root Song'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.constraints?.minHeight == 232 &&
                    widget.decoration is BoxDecoration,
              ),
            )
            .first;
    final decoration =
        tester.widget<Container>(songCard).decoration! as BoxDecoration;
    expect(decoration.color, LocalPageColors.day.surfaceCard);
    expect(decoration.boxShadow, isEmpty);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(songCard));
    addTearDown(gesture.removePointer);
    await tester.pump();

    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('LocalGridSong.Playing.1.Backdrop')),
      findsNothing,
    );
  });

  testWidgets('Local grid song focus mirrors Electron hover actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [
              DefaultAlbumArtworkThemeColors.light,
              LocalPageColors.day,
            ],
          ),
          home: Scaffold(
            body: _localGridContent(i18n, selectedTrackId: 1, isPlaying: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byTooltip('Pause'), findsNothing);
    expect(
      find.byKey(const ValueKey('LocalGridSong.Playing.1.Backdrop')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 140));

    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('LocalGridSong.Playing.1.Backdrop')),
      findsNothing,
    );

    final songCard =
        find
            .ancestor(
              of: find.text('Root Song'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.constraints?.minHeight == 232 &&
                    widget.decoration is BoxDecoration,
              ),
            )
            .first;
    final focusedCard = tester.widget<Container>(songCard);
    final decoration = focusedCard.decoration! as BoxDecoration;
    final foregroundDecoration =
        focusedCard.foregroundDecoration! as BoxDecoration;
    expect(decoration.color, GlobalUI.hoverBgColorDay);
    expect(decoration.border, isNull);
    expect(
      foregroundDecoration.border,
      Border.all(color: GlobalUI.hoverBorderColorDay),
    );
    expect(decoration.boxShadow, hasLength(1));
    expect(decoration.boxShadow!.single, GlobalUI.hoverShadowDay);
  });

  testWidgets('Local song quick jump uses Electron vertical metrics', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(extensions: const [LocalPageColors.day]),
          home: Scaffold(
            body: SizedBox(
              width: 30,
              height: 420,
              child: LocalSongQuickJump(
                basisName: 'title',
                enabledKeys: const {'#': 0, 'A': 1},
                i18n: i18n,
                visible: true,
                onJump: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hashButton = find.widgetWithText(TextButton, '#');
    final aButton = find.widgetWithText(TextButton, 'A');
    expect(tester.getSize(hashButton).width, 26);
    expect(tester.getTopLeft(hashButton).dy, 3);
    expect(
      tester.getTopLeft(aButton).dy - tester.getBottomLeft(hashButton).dy,
      1,
    );
  });

  testWidgets('Local song quick jump starts sticky only after reaching top', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final songs = [
      for (var index = 0; index < 36; index++)
        LibrarySong(
          id: index + 1,
          path: 'C:\\Music\\song_$index.mp3',
          title: index < 18 ? 'Alpha Song $index' : 'Bravo Song $index',
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
    ];
    final folderIndex = buildFolderIndex(songs, [
      const LibraryFolder(
        id: 8801,
        path: r'C:\Music\Folder',
        parentId: 0,
        criterion: 0,
      ),
    ], r'C:\Music');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            const _NoArtworkLibraryRepository(),
          ),
        ],
        child: SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [
                DefaultAlbumArtworkThemeColors.light,
                LocalPageColors.day,
              ],
            ),
            home: Scaffold(
              body: SizedBox(
                width: 900,
                height: 320,
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: LocalContentView(
                    childFolders: [folderIndex.nodes['Folder']!],
                    currentSongs: songs,
                    nodes: folderIndex.nodes,
                    songsById: folderIndex.songsById,
                    selectedFolderPaths: const {},
                    selectedSongIds: const {},
                    selectedTrackId: null,
                    isPlaying: false,
                    multiSelect: false,
                    isCompactLayout: false,
                    showLocalSectionHeaders: true,
                    foldersExpanded: true,
                    songsExpanded: true,
                    showSongQuickJump: true,
                    songQuickJumpBasisName: 'title',
                    songQuickJumpMap: const {'A': 0, 'B': 18},
                    sortMode: LocalSortMode.title,
                    currentSortMode: LocalSortMode.title,
                    queueSongIds: [for (final song in songs) song.id],
                    folderQueueSongIds: [for (final song in songs) song.id],
                    compactTreeRows: const [],
                    compactQueueSongIds: const [],
                    i18n: i18n,
                    onToggleFoldersExpanded: () {},
                    onToggleSongsExpanded: () {},
                    onToggleTreeFolderExpanded: (_) {},
                    onPlayFolder: (_) {},
                    onAddFolder: (_, _) {},
                    onRefreshFolder: (_) {},
                    onSearchFolder: (_) {},
                    onRevealFolder: (_) {},
                    onOpenFolder: (_) {},
                    onOpenFolderMenu: (_, _) {},
                    onToggleFolderSelection: (_) {},
                    onMoveLocalItemsToFolder:
                        ({
                          required folderPaths,
                          required songIds,
                          required targetFolderPath,
                        }) {},
                    onPlayTrack: (_, _) {},
                    onTogglePlayPause: () {},
                    onToggleSongSelection: (_) {},
                    onPlayNext: (_) {},
                    onToggleFavorite: (_, _) {},
                    onAddSong: (_, _) {},
                    onOpenSongMenu: (_, _) {},
                    onJumpToSongKey: (_) {},
                    scrollController: scrollController,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstQuickJumpButton = find.widgetWithText(TextButton, '#').first;
    final initialTop = tester.getTopLeft(firstQuickJumpButton).dy;
    expect(initialTop, greaterThan(80));

    scrollController.jumpTo(40);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(firstQuickJumpButton).dy,
      closeTo(initialTop - 40, 1),
    );

    scrollController.jumpTo(initialTop + 80);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(firstQuickJumpButton).dy, closeTo(9, 1));
  });

  testWidgets(
    'Local grid reserves quick jump rail when sort hides jump buttons',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [
                DefaultAlbumArtworkThemeColors.light,
                LocalPageColors.day,
              ],
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 1040,
                  child: _localGridContent(
                    i18n,
                    songCount: 5,
                    reserveSongQuickJumpSpace: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('LocalSongQuickJump.ReservedRail')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('Song 5')).dy,
        greaterThan(tester.getTopLeft(find.text('Root Song')).dy),
      );
    },
  );

  testWidgets('Local grid song title row does not expose favorite icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [
              DefaultAlbumArtworkThemeColors.light,
              LocalPageColors.day,
            ],
          ),
          home: Scaffold(body: _localGridContent(i18n, favorite: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Root Song'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Icon && widget.icon == FluentIcons.heart_16_filled,
      ),
      findsNothing,
    );
  });

  testWidgets('Local grid folder card exposes Electron content and actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    FolderNode? playedFolder;
    FolderNode? addFolder;
    Offset? addPosition;
    final content = _folderGridContent(
      i18n,
      onPlayFolder: (folder) {
        playedFolder = folder;
      },
      onAddFolder: (folder, position) {
        addFolder = folder;
        addPosition = position;
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            const _NoArtworkLibraryRepository(),
          ),
        ],
        child: SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [
                DefaultAlbumArtworkThemeColors.light,
                LocalPageColors.day,
              ],
            ),
            home: Scaffold(body: content),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Sub'), findsOneWidget);
    expect(find.text('1 folder · 1 song'), findsOneWidget);
    expect(find.textContaining('8842'), findsNothing);
    expect(find.textContaining(r'C:\Music\Sub'), findsNothing);
    expect(_assetImage('assets/branding/colorful_no_bg.png'), findsOneWidget);
    expect(_assetImage('assets/branding/folder.png'), findsOneWidget);
    final folderCover = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('LocalFolderCard.GridArtworkDropSurface')),
    );
    final folderCoverDecoration = folderCover.decoration! as BoxDecoration;
    expect(folderCoverDecoration.boxShadow, hasLength(1));
    expect(
      folderCoverDecoration.boxShadow!.single.color,
      LocalPageColors.day.artworkShadow,
    );

    final folderCard =
        find
            .ancestor(
              of: find.text('Sub'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.constraints?.minHeight == 232 &&
                    widget.decoration is BoxDecoration,
              ),
            )
            .first;
    final cardSizeBeforeHover = tester.getSize(folderCard);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(folderCard));
    addTearDown(gesture.removePointer);
    await tester.pump(const Duration(milliseconds: 140));
    expect(tester.getSize(folderCard), cardSizeBeforeHover);

    final hoveredCard = tester.widget<Container>(folderCard);
    final hoveredDecoration = hoveredCard.decoration! as BoxDecoration;
    final hoveredForeground =
        hoveredCard.foregroundDecoration! as BoxDecoration;
    expect(hoveredDecoration.border, isNull);
    expect(
      hoveredForeground.border,
      Border.all(color: GlobalUI.hoverBorderColorDay),
    );

    await tester.tap(find.byTooltip('Play Sub'));
    await tester.pump();
    expect(playedFolder?.relativePath, 'Sub');

    await tester.tap(find.byTooltip('Add To'));
    await tester.pump();
    expect(addFolder?.relativePath, 'Sub');
    expect(addPosition, isNotNull);
  });

  testWidgets(
    'Local list folder actions use Electron transparent icon buttons',
    (tester) async {
      tester.view.physicalSize = const Size(640, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FolderNode? playedFolder;
      FolderNode? addFolder;
      Offset? addPosition;
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: ThemeData(extensions: const [LocalPageColors.day]),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 560,
                  child: _folderListCard(
                    i18n,
                    onPlayFolder: (folder) {
                      playedFolder = folder;
                    },
                    onAddFolder: (folder, position) {
                      addFolder = folder;
                      addPosition = position;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ArtworkFloatingActionButton), findsNothing);
      final playButton = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byTooltip('Play Sub'),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(
        playButton.style?.fixedSize?.resolve(<WidgetState>{}),
        const Size.square(28),
      );

      final row = find.ancestor(
        of: find.text('Sub'),
        matching: find.byType(InkWell),
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(row));
      addTearDown(gesture.removePointer);
      await tester.pump(const Duration(milliseconds: 140));

      await tester.tap(find.byTooltip('Play Sub'));
      await tester.pump();
      expect(playedFolder?.relativePath, 'Sub');

      await tester.tap(find.byTooltip('Add To'));
      await tester.pump();
      expect(addFolder?.relativePath, 'Sub');
      expect(addPosition, isNotNull);
    },
  );

  testWidgets('Local folder selected state uses shared clean card style', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            const _NoArtworkLibraryRepository(),
          ),
        ],
        child: SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: ThemeData(extensions: const [LocalPageColors.day]),
            home: Scaffold(
              body: Column(
                children: [
                  _folderCard(
                    i18n,
                    variant: LocalFolderCardVariant.grid,
                    selected: true,
                  ),
                  SizedBox(
                    width: 560,
                    child: _folderListCard(
                      i18n,
                      selected: true,
                      onPlayFolder: (_) {},
                      onAddFolder: (_, _) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final gridCard =
        find
            .ancestor(
              of: find.text('Sub').first,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.constraints?.minHeight == 232 &&
                    widget.decoration is BoxDecoration,
              ),
            )
            .first;
    final gridDecoration =
        tester.widget<Container>(gridCard).decoration! as BoxDecoration;
    final gridForeground =
        tester.widget<Container>(gridCard).foregroundDecoration!
            as BoxDecoration;
    expect(gridDecoration.color, GlobalUI.selectedBgColorDay);
    expect(gridDecoration.border, isNull);
    expect(
      gridForeground.border,
      Border.all(color: GlobalUI.selectedBorderColorDay),
    );
    expect(gridDecoration.boxShadow, [GlobalUI.selectedShadowDay]);
    final folderCover = tester.widget<AnimatedContainer>(
      find
          .byKey(const ValueKey('LocalFolderCard.GridArtworkDropSurface'))
          .first,
    );
    final folderCoverDecoration = folderCover.decoration! as BoxDecoration;
    expect(
      folderCoverDecoration.boxShadow!.single.color,
      const Color(0x120078d7),
    );
    expect(folderCoverDecoration.boxShadow!.single.offset, const Offset(0, 4));
    expect(folderCoverDecoration.boxShadow!.single.blurRadius, 10);

    final listSurface = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('LocalFolderCard.ListDropSurface')),
    );
    final listDecoration = listSurface.decoration! as BoxDecoration;
    final listForeground = listSurface.foregroundDecoration! as ShapeDecoration;
    final listShape = listForeground.shape as RoundedRectangleBorder;
    expect(listDecoration.color, GlobalUI.selectedBgColorDay);
    expect(listDecoration.border, isNull);
    expect(listShape.side.color, GlobalUI.selectedBorderColorDay);
    expect(listShape.side.strokeAlign, BorderSide.strokeAlignOutside);
  });

  testWidgets('Local folder list tree toggle keeps balanced spacing', (
    tester,
  ) async {
    final folderIndex = buildFolderIndex(const [], [
      const LibraryFolder(
        id: 9001,
        path: r'C:\Music\Root',
        parentId: 0,
        criterion: 0,
      ),
      const LibraryFolder(
        id: 9002,
        path: r'C:\Music\Root\Child',
        parentId: 9001,
        criterion: 0,
      ),
    ], r'C:\Music');

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(extensions: const [LocalPageColors.day]),
          home: Scaffold(
            body: SizedBox(
              width: 560,
              child: LocalFolderCard(
                folder: folderIndex.nodes['Root']!,
                selected: false,
                multiSelect: false,
                nodes: folderIndex.nodes,
                songsById: folderIndex.songsById,
                i18n: i18n,
                variant: LocalFolderCardVariant.list,
                treeExpanded: false,
                treeExpandable: true,
                onToggleTreeExpanded: () {},
                onPlayFolder: (_) {},
                onAddFolder: (_, _) {},
                onRefreshFolder: (_) {},
                onSearchFolder: (_) {},
                onRevealFolder: (_) {},
                onOpenFolder: (_) {},
                onOpenFolderMenu: (_, _) {},
                onToggleSelection: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final surfaceRect = tester.getRect(
      find.byKey(const ValueKey('LocalFolderCard.ListDropSurface')),
    );
    final toggleRect = tester.getRect(
      find.byKey(const ValueKey('LocalFolderCard.ListTreeToggle')),
    );
    final toggleButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('LocalFolderCard.ListTreeToggle')),
    );
    final toggleShape =
        toggleButton.style?.shape?.resolve(<WidgetState>{})
            as RoundedRectangleBorder?;
    final iconSlotRect = tester.getRect(
      find.byKey(const ValueKey('LocalFolderCard.ListIconSlot')),
    );

    expect(toggleRect.width, 24);
    expect(toggleRect.height, 24);
    expect(toggleShape?.borderRadius, BorderRadius.circular(999));
    expect(toggleRect.left - surfaceRect.left, 8);
    expect(iconSlotRect.left - toggleRect.right, 6);
  });

  testWidgets('Local folder grid badge mirrors Electron floating icon style', (
    tester,
  ) async {
    Future<({BoxDecoration decoration, GlassContainer glass})> pumpBadge(
      Brightness brightness,
    ) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(
              const _NoArtworkLibraryRepository(),
            ),
          ],
          child: SmPlayerI18nScope(
            i18n: i18n,
            child: MaterialApp(
              theme: (brightness == Brightness.dark
                      ? ThemeData.dark()
                      : ThemeData.light())
                  .copyWith(
                    extensions: [
                      brightness == Brightness.dark
                          ? LocalPageColors.night
                          : LocalPageColors.day,
                    ],
                  ),
              home: Scaffold(
                body: _folderCard(i18n, variant: LocalFolderCardVariant.grid),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final badgeRoot = find.byKey(
        const ValueKey('LocalFolderCard.FolderTypeBadge'),
      );
      expect(tester.widget<CardCornerBadge>(badgeRoot), isA<CardCornerBadge>());
      final badge = tester.widget<DecoratedBox>(
        find
            .descendant(of: badgeRoot, matching: find.byType(DecoratedBox))
            .first,
      );
      final glass = tester.widget<GlassContainer>(
        find.descendant(of: badgeRoot, matching: find.byType(GlassContainer)),
      );
      return (decoration: badge.decoration as BoxDecoration, glass: glass);
    }

    final lightBadge = await pumpBadge(Brightness.light);
    expect(lightBadge.decoration.borderRadius, BorderRadius.circular(8));
    expect(lightBadge.decoration.boxShadow, hasLength(1));
    expect(
      lightBadge.decoration.boxShadow!.single.color,
      const Color(0x1f1e2a3a),
    );
    expect(lightBadge.decoration.boxShadow!.single.offset, const Offset(0, 12));
    expect(lightBadge.decoration.boxShadow!.single.blurRadius, 26);
    expect(lightBadge.glass.width, 32);
    expect(lightBadge.glass.height, 32);
    expect(lightBadge.glass.useOwnLayer, isTrue);
    expect(lightBadge.glass.quality, GlassQuality.minimal);
    expect(
      (lightBadge.glass.settings as LiquidGlassSettings).glassColor,
      const Color(0xd1ffffff),
    );
    expect((lightBadge.glass.settings as LiquidGlassSettings).blur, 16);

    final badgeSize = tester.getSize(
      find.byKey(const ValueKey('LocalFolderCard.FolderTypeBadge')),
    );
    expect(badgeSize, const Size.square(32));

    final darkBadge = await pumpBadge(Brightness.dark);
    expect(
      (darkBadge.glass.settings as LiquidGlassSettings).glassColor,
      const Color(0xc7181e26),
    );
    expect(
      darkBadge.decoration.boxShadow!.single.color,
      const Color(0x3d000000),
    );
  });

  testWidgets(
    'Local folder drop target is scoped to Electron grid artwork or list row',
    (tester) async {
      tester.view.physicalSize = const Size(980, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const payload = LocalItemsDragPayload(songIds: [1], folderPaths: []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(
              const _NoArtworkLibraryRepository(),
            ),
          ],
          child: SmPlayerI18nScope(
            i18n: i18n,
            child: MaterialApp(
              theme: ThemeData(extensions: const [LocalPageColors.day]),
              home: Scaffold(
                body: Row(
                  children: [
                    Draggable<LocalItemsDragPayload>(
                      data: payload,
                      feedback: const SizedBox.square(dimension: 24),
                      child: const SizedBox.square(
                        dimension: 48,
                        child: ColoredBox(color: Colors.black),
                      ),
                    ),
                    _folderCard(i18n, variant: LocalFolderCardVariant.grid),
                    SizedBox(
                      width: 560,
                      child: _folderCard(
                        i18n,
                        folderName: 'List',
                        variant: LocalFolderCardVariant.list,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gridSurface = find.byKey(
        const ValueKey('LocalFolderCard.GridArtworkDropSurface'),
      );
      final listSurface = find.byKey(
        const ValueKey('LocalFolderCard.ListDropSurface'),
      );
      expect(gridSurface, findsOneWidget);
      expect(listSurface, findsOneWidget);

      var gridDecoration =
          tester.widget<AnimatedContainer>(gridSurface).foregroundDecoration
              as ShapeDecoration;
      var gridShape = gridDecoration.shape as RoundedRectangleBorder;
      expect(gridShape.side.color, Colors.transparent);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Draggable<LocalItemsDragPayload>)),
      );
      await gesture.moveTo(tester.getCenter(gridSurface));
      await tester.pump();

      gridDecoration =
          tester.widget<AnimatedContainer>(gridSurface).foregroundDecoration
              as ShapeDecoration;
      gridShape = gridDecoration.shape as RoundedRectangleBorder;
      expect(gridShape.side.color, LocalPageColors.day.accentStrong);
      expect(gridShape.side.strokeAlign, BorderSide.strokeAlignOutside);
      final gridBoxDecoration =
          tester.widget<AnimatedContainer>(gridSurface).decoration
              as BoxDecoration;
      expect(gridBoxDecoration.boxShadow, hasLength(2));

      await gesture.moveTo(tester.getCenter(listSurface));
      await tester.pump();

      final listDecoration =
          tester.widget<AnimatedContainer>(listSurface).foregroundDecoration
              as ShapeDecoration;
      final listShape = listDecoration.shape as RoundedRectangleBorder;
      expect(listShape.side.color, LocalPageColors.day.accentStrong);
      expect(listShape.side.strokeAlign, BorderSide.strokeAlignOutside);

      await gesture.up();
    },
  );

  testWidgets('Local list folder play stays enabled for empty folder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    FolderNode? playedFolder;
    Offset? addPosition;
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(extensions: const [LocalPageColors.day]),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 560,
                child: _folderListCard(
                  i18n,
                  folderName: 'Empty',
                  includeSong: false,
                  onPlayFolder: (folder) {
                    playedFolder = folder;
                  },
                  onAddFolder: (_, position) {
                    addPosition = position;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final row = find.ancestor(
      of: find.text('Empty'),
      matching: find.byType(InkWell),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(row));
    addTearDown(gesture.removePointer);
    await tester.pump(const Duration(milliseconds: 140));

    await tester.tap(find.byTooltip('Play Empty'));
    await tester.pump();
    expect(playedFolder?.relativePath, 'Empty');

    final addButton = tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byTooltip('Add To'),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(addButton.onPressed, isNull);
    expect(addPosition, isNull);
  });

  test('Local folder thumbnail resolver keeps resolved artwork path', () async {
    const artworkPath = '/tmp/smplayer-folder-artwork.png';
    const song = LibrarySong(
      id: 101,
      path: r'C:\Music\ArtworkSub\root.mp3',
      title: 'Folder Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Root Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    );

    final artworkUrls = await resolveOriginalFolderThumbnailUrls(const [
      [song],
    ], const _ArtworkLibraryRepository({101: artworkPath}));

    expect(artworkUrls, [artworkPath]);
  });

  testWidgets('Local grid folder card renders resolved artwork image', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'smplayer_local_grid_artwork_',
    );
    addTearDown(() {
      tempDir.deleteSync(recursive: true);
    });
    final artworkFile = File('${tempDir.path}/folder-artwork.png');
    artworkFile.writeAsBytesSync(_pngFixtureBytes);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(
            _ArtworkLibraryRepository({101: artworkFile.path}),
          ),
        ],
        child: SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [
                DefaultAlbumArtworkThemeColors.light,
                LocalPageColors.day,
              ],
            ),
            home: Scaffold(
              body: _folderGridContent(
                i18n,
                folderName: 'ArtworkSub',
                rootSongId: 101,
                deepSongId: 102,
                onPlayFolder: (_) {},
                onAddFolder: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is FileImage &&
            (widget.image as FileImage).file.path == artworkFile.path,
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Local grid folder card uses single cover for two thumbnails like Electron',
    (tester) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'smplayer_local_grid_two_artwork_',
      );
      addTearDown(() {
        tempDir.deleteSync(recursive: true);
      });
      final firstArtworkFile = File('${tempDir.path}/folder-artwork-a.png');
      final secondArtworkFile = File('${tempDir.path}/folder-artwork-b.png');
      firstArtworkFile.writeAsBytesSync(_pngFixtureBytes);
      secondArtworkFile.writeAsBytesSync(_pngFixtureBytes);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(
              _ArtworkLibraryRepository({
                101: firstArtworkFile.path,
                102: secondArtworkFile.path,
              }),
            ),
          ],
          child: SmPlayerI18nScope(
            i18n: i18n,
            child: MaterialApp(
              theme: ThemeData(
                extensions: const [
                  DefaultAlbumArtworkThemeColors.light,
                  LocalPageColors.day,
                ],
              ),
              home: Scaffold(
                body: _folderGridContent(
                  i18n,
                  folderName: 'ArtworkSub',
                  rootSongId: 101,
                  deepSongId: 102,
                  onPlayFolder: (_) {},
                  onAddFolder: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(_fileImage(firstArtworkFile.path), findsOneWidget);
      expect(_fileImage(secondArtworkFile.path), findsNothing);
    },
  );
}

Finder _assetImage(String assetPath) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == assetPath,
  );
}

Finder _fileImage(String filePath) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is FileImage &&
        (widget.image as FileImage).file.path == filePath,
  );
}

final _pngFixtureBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAa0lEQVR42u3QQQ0AMAgEsJM9ayiZHJBBSPqogSbv96aurIoAAQIECBAgQIAAAQIECBAgQIAAAQIECBAgQIAAAQIECBAgQIAAAQIECBAgQIAAAQIECBAgQIAAAQIECBAgQIAAAQIECBBwP2AAQgwqWRbkoyAAAAAASUVORK5CYII=',
);

Widget _localGridContent(
  SmPlayerI18n i18n, {
  int? selectedTrackId,
  bool isPlaying = false,
  bool favorite = false,
  int songCount = 1,
  bool showSongQuickJump = false,
  bool reserveSongQuickJumpSpace = false,
  Set<int> selectedSongIds = const {},
  void Function(int trackId, List<int> queueSongIds)? onPlayTrack,
}) {
  final songs = [
    for (var index = 0; index < songCount; index += 1)
      LibrarySong(
        id: index + 1,
        path: 'C:\\Music\\song-${index + 1}.mp3',
        title: index == 0 ? 'Root Song' : 'Song ${index + 1}',
        artist: 'Artist A',
        artists: ['Artist A'],
        album: 'Root Album',
        duration: 120,
        playCount: 0,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-20T00:00:00',
        favorite: index == 0 && favorite,
        thumbnailPath: '',
      ),
  ];

  return LocalContentView(
    childFolders: const [],
    currentSongs: songs,
    nodes: const {},
    songsById: {for (final song in songs) song.id: song},
    selectedFolderPaths: const {},
    selectedSongIds: selectedSongIds,
    selectedTrackId: selectedTrackId,
    isPlaying: isPlaying,
    multiSelect: false,
    isCompactLayout: false,
    showLocalSectionHeaders: false,
    foldersExpanded: true,
    songsExpanded: true,
    showSongQuickJump: showSongQuickJump,
    reserveSongQuickJumpSpace: reserveSongQuickJumpSpace,
    songQuickJumpBasisName: '',
    songQuickJumpMap: const {},
    sortMode: LocalSortMode.title,
    currentSortMode: LocalSortMode.title,
    queueSongIds: [for (final song in songs) song.id],
    folderQueueSongIds: [for (final song in songs) song.id],
    compactTreeRows: const [],
    compactQueueSongIds: const [],
    i18n: i18n,
    onToggleFoldersExpanded: () {},
    onToggleSongsExpanded: () {},
    onToggleTreeFolderExpanded: (_) {},
    onPlayFolder: (_) {},
    onAddFolder: (_, _) {},
    onRefreshFolder: (_) {},
    onSearchFolder: (_) {},
    onRevealFolder: (_) {},
    onOpenFolder: (_) {},
    onOpenFolderMenu: (_, _) {},
    onToggleFolderSelection: (_) {},
    onMoveLocalItemsToFolder:
        ({
          required folderPaths,
          required songIds,
          required targetFolderPath,
        }) {},
    onPlayTrack: onPlayTrack ?? (_, _) {},
    onTogglePlayPause: () {},
    onToggleSongSelection: (_) {},
    onPlayNext: (_) {},
    onToggleFavorite: (_, _) {},
    onAddSong: (_, _) {},
    onOpenSongMenu: (_, _) {},
    onJumpToSongKey: (_) {},
  );
}

double _playingBarHeight(WidgetTester tester, String keyPrefix, int index) {
  return tester.getSize(find.byKey(ValueKey('$keyPrefix.Bar.$index'))).height;
}

Widget _folderGridContent(
  SmPlayerI18n i18n, {
  required ValueChanged<FolderNode> onPlayFolder,
  required void Function(FolderNode folder, Offset position) onAddFolder,
  String folderName = 'Sub',
  int rootSongId = 1,
  int deepSongId = 2,
}) {
  final rootSong = LibrarySong(
    id: rootSongId,
    path: 'C:\\Music\\$folderName\\root.mp3',
    title: 'Folder Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Root Album',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  );
  final deepSong = LibrarySong(
    id: deepSongId,
    path: 'C:\\Music\\$folderName\\Deep\\deep.mp3',
    title: 'Deep Song',
    artist: 'Artist B',
    artists: ['Artist B'],
    album: 'Deep Album',
    duration: 90,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  );
  final folderIndex = buildFolderIndex(
    [rootSong, deepSong],
    [
      LibraryFolder(
        id: 8842,
        path: 'C:\\Music\\$folderName',
        parentId: 0,
        criterion: 0,
      ),
      LibraryFolder(
        id: 8843,
        path: 'C:\\Music\\$folderName\\Deep',
        parentId: 8842,
        criterion: 0,
      ),
    ],
    r'C:\Music',
  );

  return LocalContentView(
    childFolders: [folderIndex.nodes[folderName]!],
    currentSongs: const [],
    nodes: folderIndex.nodes,
    songsById: folderIndex.songsById,
    selectedFolderPaths: const {},
    selectedSongIds: const {},
    selectedTrackId: null,
    isPlaying: false,
    multiSelect: false,
    isCompactLayout: false,
    showLocalSectionHeaders: false,
    foldersExpanded: true,
    songsExpanded: true,
    showSongQuickJump: false,
    songQuickJumpBasisName: '',
    songQuickJumpMap: const {},
    sortMode: LocalSortMode.title,
    currentSortMode: LocalSortMode.title,
    queueSongIds: [rootSongId],
    folderQueueSongIds: [rootSongId, deepSongId],
    compactTreeRows: const [],
    compactQueueSongIds: const [],
    i18n: i18n,
    onToggleFoldersExpanded: () {},
    onToggleSongsExpanded: () {},
    onToggleTreeFolderExpanded: (_) {},
    onPlayFolder: onPlayFolder,
    onAddFolder: onAddFolder,
    onRefreshFolder: (_) {},
    onSearchFolder: (_) {},
    onRevealFolder: (_) {},
    onOpenFolder: (_) {},
    onOpenFolderMenu: (_, _) {},
    onToggleFolderSelection: (_) {},
    onMoveLocalItemsToFolder:
        ({
          required folderPaths,
          required songIds,
          required targetFolderPath,
        }) {},
    onPlayTrack: (_, _) {},
    onTogglePlayPause: () {},
    onToggleSongSelection: (_) {},
    onPlayNext: (_) {},
    onToggleFavorite: (_, _) {},
    onAddSong: (_, _) {},
    onOpenSongMenu: (_, _) {},
    onJumpToSongKey: (_) {},
  );
}

Widget _folderCard(
  SmPlayerI18n i18n, {
  required LocalFolderCardVariant variant,
  String folderName = 'Sub',
  bool selected = false,
}) {
  final song = LibrarySong(
    id: 1,
    path: 'C:\\Music\\$folderName\\root.mp3',
    title: 'Folder Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Root Album',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  );
  final folderIndex = buildFolderIndex(
    [song],
    [
      LibraryFolder(
        id: 8842,
        path: 'C:\\Music\\$folderName',
        parentId: 0,
        criterion: 0,
      ),
    ],
    r'C:\Music',
  );
  final folder = folderIndex.nodes[folderName]!;
  return LocalFolderCard(
    folder: folder,
    selected: selected,
    multiSelect: false,
    nodes: folderIndex.nodes,
    songsById: folderIndex.songsById,
    i18n: i18n,
    variant: variant,
    onPlayFolder: (_) {},
    onAddFolder: (_, _) {},
    onRefreshFolder: (_) {},
    onSearchFolder: (_) {},
    onRevealFolder: (_) {},
    onOpenFolder: (_) {},
    onOpenFolderMenu: (_, _) {},
    onToggleSelection: (_) {},
    onWillAcceptDrop: (_, _) => true,
    onAcceptDrop: (_, _) {},
  );
}

Widget _folderListCard(
  SmPlayerI18n i18n, {
  required ValueChanged<FolderNode> onPlayFolder,
  required void Function(FolderNode folder, Offset position) onAddFolder,
  String folderName = 'Sub',
  bool includeSong = true,
  bool selected = false,
}) {
  final song = LibrarySong(
    id: 1,
    path: 'C:\\Music\\$folderName\\root.mp3',
    title: 'Folder Song',
    artist: 'Artist A',
    artists: ['Artist A'],
    album: 'Root Album',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  );
  final folderIndex = buildFolderIndex(includeSong ? [song] : const [], [
    LibraryFolder(
      id: 8842,
      path: 'C:\\Music\\$folderName',
      parentId: 0,
      criterion: 0,
    ),
  ], r'C:\Music');
  final folder = folderIndex.nodes[folderName]!;
  return LocalFolderCard(
    folder: folder,
    selected: selected,
    multiSelect: false,
    nodes: folderIndex.nodes,
    songsById: folderIndex.songsById,
    i18n: i18n,
    variant: LocalFolderCardVariant.list,
    onPlayFolder: onPlayFolder,
    onAddFolder: onAddFolder,
    onRefreshFolder: (_) {},
    onSearchFolder: (_) {},
    onRevealFolder: (_) {},
    onOpenFolder: (_) {},
    onOpenFolderMenu: (_, _) {},
    onToggleSelection: (_) {},
  );
}

class _NoArtworkLibraryRepository extends LibraryRepository {
  const _NoArtworkLibraryRepository();

  @override
  Future<List<SongArtworkSnapshot>> getSongArtworkSnapshots(
    List<int> songIds,
  ) async {
    return [
      for (final songId in songIds)
        SongArtworkSnapshot(
          songId: songId,
          artworkUrl: '',
          sourceUrl: '',
          sourcePath: '',
          source: SongArtworkSource.none,
        ),
    ];
  }
}

class _ArtworkLibraryRepository extends LibraryRepository {
  const _ArtworkLibraryRepository(this.artworkPathBySongId);

  final Map<int, String> artworkPathBySongId;

  @override
  Future<List<SongArtworkSnapshot>> getSongArtworkSnapshots(
    List<int> songIds,
  ) async {
    return [
      for (final songId in songIds)
        SongArtworkSnapshot(
          songId: songId,
          artworkUrl: artworkPathBySongId[songId] ?? '',
          sourceUrl: '',
          sourcePath: '',
          source:
              artworkPathBySongId.containsKey(songId)
                  ? SongArtworkSource.cached
                  : SongArtworkSource.none,
        ),
    ];
  }
}
