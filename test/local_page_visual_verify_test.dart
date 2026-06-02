import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/shell_page.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/hidden_folders_page.dart';
import 'package:smplayer_flutter/src/library/ui/local_page.dart';
import 'package:smplayer_flutter/src/library/ui/local_page_quick_jump.dart';
import 'package:smplayer_flutter/src/library/ui/missing_library_root_content.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/platform/desktop_feature_service.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LocalViewMode, SettingsSnapshot;

void main() {
  testWidgets('writes LocalPage light and night verification screenshots', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path: 'build/smplayer_local_page_light_verify.png',
    );
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.dark,
      path: 'build/smplayer_local_page_dark_verify.png',
    );
  });

  testWidgets('writes LocalPage empty-root night verification screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.dark,
      path: 'build/smplayer_local_page_empty_root_dark_verify.png',
      snapshot: _snapshotWithRootPath(''),
      expectedText: 'No root',
    );
  });

  testWidgets('writes compact LocalPage night verification screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.dark,
      path: 'build/smplayer_local_page_compact_dark_verify.png',
      physicalSize: const Size(640, 900),
    );
  });

  testWidgets('writes compact LocalPage light verification screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path: 'build/smplayer_local_page_compact_light_verify.png',
      physicalSize: const Size(640, 900),
    );
  });

  testWidgets('writes compact LocalPage appbar-body light screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path: 'build/smplayer_local_page_compact_appbar_body_light_verify.png',
      physicalSize: const Size(640, 900),
      workspaceAppBarActive: true,
      expectedText: 'Intro Signal',
    );
  });

  testWidgets('writes compact expanded tree night verification screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.dark,
      path: 'build/smplayer_local_page_compact_tree_dark_verify.png',
      currentRelativePath: 'Collections',
      physicalSize: const Size(640, 900),
      exercise: (tester) async {
        await tester.tap(find.byTooltip('Live'));
        await tester.pump(const Duration(milliseconds: 300));
      },
      expectedText: 'Sessions',
    );
  });

  testWidgets('writes deep breadcrumb night verification screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.dark,
      path: 'build/smplayer_local_page_deep_breadcrumb_dark_verify.png',
      physicalSize: const Size(760, 760),
      expectedText: 'Archive',
    );
  });

  testWidgets('writes breadcrumb flyout night verification screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.dark,
      path: 'build/smplayer_local_page_breadcrumb_flyout_dark_verify.png',
      physicalSize: const Size(760, 760),
      exercise: (tester) async {
        await tester.tap(
          find.byKey(
            const ValueKey('FolderChain.Dropdown.Collections/Live/Sessions'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            const ValueKey(
              'FolderChain.Child.Collections/Live/Sessions/Archive',
            ),
          ),
          findsOneWidget,
        );
      },
      expectedText: 'Archive',
    );
  });

  testWidgets(
    'writes LocalPage stored-list grid night verification screenshot',
    (tester) async {
      await _writeLocalPageScreenshot(
        tester,
        brightness: Brightness.dark,
        path: 'build/smplayer_local_page_stored_list_grid_dark_verify.png',
        snapshot: _snapshotWithLocalViewMode(LocalViewMode.list),
        expectedText: 'Intro Signal',
      );
      expect(find.text('Name'), findsNothing);
      expect(
        find.byKey(const ValueKey('LocalTableContent.VirtualList')),
        findsNothing,
      );
    },
  );

  testWidgets('writes compact LocalPage stored-list grid light screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path:
          'build/smplayer_local_page_compact_stored_list_grid_light_verify.png',
      physicalSize: const Size(640, 900),
      snapshot: _snapshotWithLocalViewMode(LocalViewMode.list),
      expectedText: 'Intro Signal',
    );
    expect(find.text('Name'), findsNothing);
    expect(
      find.byKey(const ValueKey('LocalTableContent.CompactList')),
      findsNothing,
    );
    expect(find.text('River North'), findsOneWidget);
    expect(find.text('Archive Night'), findsWidgets);
  });

  testWidgets('writes compact folder hover actions light screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path: 'build/smplayer_local_page_compact_folder_hover_light_verify.png',
      physicalSize: const Size(640, 900),
      snapshot: _snapshotWithLocalViewMode(LocalViewMode.list),
      expectedText: 'Encore',
      exercise: (tester) async {
        final folderRow = find.ancestor(
          of: find.text('Encore'),
          matching: find.byType(InkWell),
        );
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        final rowCenter = tester.getCenter(folderRow);
        await gesture.addPointer(location: rowCenter);
        await gesture.moveTo(rowCenter);
        await tester.pump(const Duration(milliseconds: 180));
        expect(
          find.byTooltip('Shuffle all music under "Encore"'),
          findsOneWidget,
        );
        expect(find.byTooltip('Add To'), findsWidgets);
      },
    );
  });

  testWidgets('writes wide folder hover actions light screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path: 'build/smplayer_local_page_wide_folder_hover_light_verify.png',
      expectedText: 'Encore',
      exercise: (tester) async {
        final folderCard =
            find
                .ancestor(
                  of: find.text('Encore'),
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Container &&
                        widget.constraints?.minHeight == 232 &&
                        widget.decoration is BoxDecoration,
                  ),
                )
                .first;
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        final cardCenter = tester.getCenter(folderCard);
        await gesture.addPointer(location: cardCenter);
        await gesture.moveTo(cardCenter);
        await tester.pump(const Duration(milliseconds: 180));
        expect(
          find.byTooltip('Shuffle all music under "Encore"'),
          findsOneWidget,
        );
        expect(find.byTooltip('Add To'), findsWidgets);
      },
    );
  });

  testWidgets('writes wide song hover actions light screenshot', (
    tester,
  ) async {
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path: 'build/smplayer_local_page_wide_song_hover_light_verify.png',
      expectedText: 'Intro Signal',
      exercise: (tester) async {
        final songCard = find.ancestor(
          of: find.text('Intro Signal'),
          matching: find.byType(InkWell),
        );
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        final cardCenter = tester.getCenter(songCard);
        await gesture.addPointer(location: cardCenter);
        await gesture.moveTo(cardCenter);
        await tester.pump(const Duration(milliseconds: 180));
        expect(find.byTooltip('Play'), findsOneWidget);
        expect(find.byTooltip('Add To'), findsWidgets);
      },
    );
  });

  testWidgets('writes current song night verification screenshot', (
    tester,
  ) async {
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Intro Signal',
        artist: 'River North',
        artworkUrl: '',
        isLoading: false,
      ),
      durationSeconds: 92,
      queueIndex: 0,
    );
    await _writeLocalPageScreenshot(
      tester,
      brightness: Brightness.dark,
      path: 'build/smplayer_local_page_current_song_dark_verify.png',
      mediaController: mediaController,
      expectedText: 'Intro Signal',
    );
  });

  testWidgets('writes shell LocalPage archive light verification screenshot', (
    tester,
  ) async {
    await _writeShellLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path: 'build/smplayer_flutter_shell_local_page_archive_light_verify.png',
    );
  });

  testWidgets('writes shell LocalPage archive folder hover screenshot', (
    tester,
  ) async {
    await _writeShellLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path:
          'build/smplayer_flutter_shell_local_page_archive_folder_hover_light_verify.png',
      hoverTarget: _ShellLocalHoverTarget.folder,
    );
  });

  testWidgets('writes shell LocalPage archive song hover screenshot', (
    tester,
  ) async {
    await _writeShellLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path:
          'build/smplayer_flutter_shell_local_page_archive_song_hover_light_verify.png',
      hoverTarget: _ShellLocalHoverTarget.song,
    );
  });

  testWidgets(
    'writes shell LocalPage multi-select dark verification screenshot',
    (tester) async {
      await _writeShellLocalPageScreenshot(
        tester,
        brightness: Brightness.dark,
        path: 'build/smplayer_flutter_shell_local_multiselect_dark_verify.png',
        physicalSize: const Size(1200, 820),
        expectWideGridLeftEdge: false,
        exercise: (tester) async {
          await tester.tap(find.byTooltip('More').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Multi Select').last);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
            findsOneWidget,
          );
          await tester.tap(find.text('Select All').last);
          await tester.pumpAndSettle();
          expect(find.textContaining('selected'), findsWidgets);
          final surfaceRect = tester.getRect(
            find.byKey(const ValueKey('MultiSelectCommandBar.Surface')),
          );
          expect(
            surfaceRect.left,
            moreOrLessEquals(SmPlayerShellMetrics.sidebarWidth, epsilon: 1),
          );
          expect(surfaceRect.right, moreOrLessEquals(1200, epsilon: 1));
          expect(
            surfaceRect.width,
            moreOrLessEquals(
              1200 - SmPlayerShellMetrics.sidebarWidth,
              epsilon: 1,
            ),
          );
          expect(
            surfaceRect.bottom,
            moreOrLessEquals(
              820 - SmPlayerShellMetrics.playerHeight + 1,
              epsilon: 1,
            ),
          );
        },
      );
    },
  );

  testWidgets(
    'writes compact shell LocalPage archive light verification screenshot',
    (tester) async {
      await _writeShellLocalPageScreenshot(
        tester,
        brightness: Brightness.light,
        path:
            'build/smplayer_flutter_shell_local_page_archive_compact_light_verify.png',
        physicalSize: const Size(640, 900),
        expectWideGridLeftEdge: false,
        expectCompactPanelWidth: true,
      );
    },
  );

  testWidgets('writes compact shell LocalPage folder hover screenshot', (
    tester,
  ) async {
    await _writeShellLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path:
          'build/smplayer_flutter_shell_local_page_archive_compact_folder_hover_light_verify.png',
      physicalSize: const Size(640, 900),
      expectWideGridLeftEdge: false,
      expectCompactPanelWidth: true,
      hoverTarget: _ShellLocalHoverTarget.compactFolder,
    );
  });

  testWidgets('writes compact shell LocalPage folder focus screenshot', (
    tester,
  ) async {
    await _writeShellLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path:
          'build/smplayer_flutter_shell_local_page_archive_compact_folder_focus_light_verify.png',
      physicalSize: const Size(640, 900),
      expectWideGridLeftEdge: false,
      expectCompactPanelWidth: true,
      hoverTarget: _ShellLocalHoverTarget.compactFolderFocus,
    );
  });

  testWidgets('writes compact shell LocalPage song hover screenshot', (
    tester,
  ) async {
    await _writeShellLocalPageScreenshot(
      tester,
      brightness: Brightness.light,
      path:
          'build/smplayer_flutter_shell_local_page_archive_compact_song_hover_light_verify.png',
      physicalSize: const Size(640, 900),
      expectWideGridLeftEdge: false,
      expectCompactPanelWidth: true,
      hoverTarget: _ShellLocalHoverTarget.compactSong,
    );
  });

  testWidgets('writes HiddenFoldersPage night verification screenshot', (
    tester,
  ) async {
    await _writeHiddenFoldersScreenshot(
      tester,
      path: 'build/smplayer_hidden_folders_dark_verify.png',
    );
  });
}

Future<void> _writeLocalPageScreenshot(
  WidgetTester tester, {
  required Brightness brightness,
  required String path,
  LibraryContentData snapshot = _snapshot,
  String currentRelativePath = 'Collections/Live/Sessions/Archive',
  Size physicalSize = const Size(1280, 820),
  String expectedText = 'Archive',
  Future<void> Function(WidgetTester tester)? exercise,
  MediaControlController? mediaController,
  bool workspaceAppBarActive = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = physicalSize;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  final repaintKey = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: repaintKey,
      child: _VisualVerifyApp(
        brightness: brightness,
        repository: const _VisualRepository(),
        snapshot: snapshot,
        mediaController: mediaController,
        child: ColoredBox(
          color: _shellBackground(brightness),
          child: WorkspaceNavigationAppBarScope(
            active: workspaceAppBarActive,
            child: LocalPage(currentRelativePath: currentRelativePath),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  if (exercise != null) {
    await exercise(tester);
  }

  expect(find.text(expectedText), findsWidgets);
  if (snapshot.rootPath.isNotEmpty && physicalSize.width >= 720) {
    expect(find.byTooltip('Hidden Folders'), findsOneWidget);
  }
  await _writeBoundaryPng(tester, repaintKey, path);
  await tester.tapAt(const Offset(4, 4));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _writeShellLocalPageScreenshot(
  WidgetTester tester, {
  required Brightness brightness,
  required String path,
  LibraryContentData snapshot = _snapshot,
  String currentRelativePath = 'Collections/Live/Sessions/Archive',
  Size physicalSize = const Size(1280, 820),
  bool expectWideGridLeftEdge = true,
  bool expectCompactPanelWidth = false,
  _ShellLocalHoverTarget? hoverTarget,
  Future<void> Function(WidgetTester tester)? exercise,
}) async {
  resetSmPlayerGlobalSettingsSnapshot();
  resetSmPlayerShellGlobalStateForTest();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = physicalSize;
  addTearDown(() {
    resetSmPlayerGlobalSettingsSnapshot();
    resetSmPlayerShellGlobalStateForTest();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  final repository = _VisualRepository(snapshot);
  final routeLocation =
      Uri(
        path: '/local',
        queryParameters: {'path': currentRelativePath},
      ).toString();
  final repaintKey = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: repaintKey,
      child: ProviderScope(
        overrides: [
          smPlayerI18nProvider.overrideWith((ref) async => _i18n),
          libraryContentDataProvider.overrideWith((ref) async => snapshot),
          libraryRepositoryProvider.overrideWithValue(repository),
        ],
        child: SmPlayerI18nScope(
          i18n: _i18n,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildSmPlayerTheme(
              const SettingsSnapshot.defaults(),
              brightness: brightness,
            ),
            home: SmPlayerShellPage(
              appVersion: '0.0.0',
              currentPath: '/local',
              currentLocation: routeLocation,
              desktopFeatureService: const NoopDesktopFeatureService(),
              settingsRepository: repository,
              child: LocalPage(currentRelativePath: currentRelativePath),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));

  expect(find.text('Archive'), findsWidgets);
  expect(find.text('Intro Signal'), findsWidgets);
  expect(find.byType(SmPlayerShellPage), findsOneWidget);
  if (expectWideGridLeftEdge) {
    final folderCard = _wideFolderCardFinder();
    final folderRect = tester.getRect(folderCard);
    expect(folderRect.left, moreOrLessEquals(350, epsilon: 2));
    expect(folderRect.top, moreOrLessEquals(220, epsilon: 3));
    expect(folderRect.width, moreOrLessEquals(180, epsilon: 1));
    expect(folderRect.height, moreOrLessEquals(232, epsilon: 1));
    final songCard = _wideSongCardFinder();
    final songRect = tester.getRect(songCard);
    expect(songRect.left, moreOrLessEquals(350, epsilon: 2));
    expect(songRect.top, moreOrLessEquals(520, epsilon: 3));
    expect(songRect.width, moreOrLessEquals(180, epsilon: 1));
    expect(songRect.height, moreOrLessEquals(232, epsilon: 1));

    if (hoverTarget != null) {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final hoverFinder =
          hoverTarget == _ShellLocalHoverTarget.folder ? folderCard : songCard;
      final center = tester.getCenter(hoverFinder);
      await gesture.addPointer(location: center);
      await gesture.moveTo(center);
      await tester.pump(const Duration(milliseconds: 180));

      final playTooltip =
          hoverTarget == _ShellLocalHoverTarget.folder
              ? 'Shuffle all music under "Encore"'
              : 'Play';
      expect(find.byTooltip(playTooltip), findsOneWidget);
      expect(find.byTooltip('Add To'), findsOneWidget);
      final playRect = tester.getRect(_glassButtonForTooltip(playTooltip));
      final addRect = tester.getRect(_glassButtonForTooltip('Add To'));
      final expectedTop =
          hoverTarget == _ShellLocalHoverTarget.folder ? 286.0 : 586.0;
      expect(playRect.left, moreOrLessEquals(387, epsilon: 4));
      expect(playRect.top, moreOrLessEquals(expectedTop, epsilon: 4));
      expect(playRect.width, moreOrLessEquals(48, epsilon: 1));
      expect(playRect.height, moreOrLessEquals(48, epsilon: 1));
      expect(addRect.left, moreOrLessEquals(445, epsilon: 4));
      expect(addRect.top, moreOrLessEquals(expectedTop, epsilon: 4));
      expect(addRect.width, moreOrLessEquals(48, epsilon: 1));
      expect(addRect.height, moreOrLessEquals(48, epsilon: 1));
    }
  }
  if (expectCompactPanelWidth) {
    final folderRow = find.ancestor(
      of: find.text('Encore'),
      matching: find.byType(InkWell),
    );
    final rowRect = tester.getRect(folderRow);
    expect(rowRect.left, moreOrLessEquals(13, epsilon: 2));
    expect(rowRect.width, moreOrLessEquals(614, epsilon: 4));
    expect(rowRect.height, moreOrLessEquals(46, epsilon: 2));
    final songRow =
        find
            .ancestor(
              of: find.text('Glass Horizon'),
              matching: find.byType(InkWell),
            )
            .first;
    final songRowRect = tester.getRect(songRow);
    expect(songRowRect.left, moreOrLessEquals(13, epsilon: 2));
    expect(songRowRect.top, moreOrLessEquals(275, epsilon: 3));
    expect(songRowRect.width, moreOrLessEquals(614, epsilon: 4));
    expect(songRowRect.height, moreOrLessEquals(79, epsilon: 2));

    if (hoverTarget == _ShellLocalHoverTarget.compactFolder ||
        hoverTarget == _ShellLocalHoverTarget.compactFolderFocus) {
      if (hoverTarget == _ShellLocalHoverTarget.compactFolderFocus) {
        final folderContext = tester.element(folderRow);
        FocusScope.of(folderContext).requestFocus(Focus.of(folderContext));
      } else {
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        final center = tester.getCenter(folderRow);
        await gesture.addPointer(location: center);
        await gesture.moveTo(center);
      }
      await tester.pump(const Duration(milliseconds: 180));

      final playRect = tester.getRect(
        find.byTooltip('Shuffle all music under "Encore"'),
      );
      final addRect = tester.getRect(find.byTooltip('Add To'));
      final refreshRect = tester.getRect(find.byTooltip('Refresh folder'));
      final searchRect = tester.getRect(find.byTooltip('Search in folder'));
      final openRect = tester.getRect(find.byTooltip('Open local'));
      final rects = [playRect, addRect, refreshRect, searchRect, openRect];
      for (var index = 0; index < rects.length; index += 1) {
        expect(
          rects[index].left,
          moreOrLessEquals(465 + index * 30, epsilon: 4),
        );
        expect(rects[index].top, moreOrLessEquals(184, epsilon: 4));
        expect(rects[index].width, moreOrLessEquals(28, epsilon: 1));
        expect(rects[index].height, moreOrLessEquals(28, epsilon: 1));
      }
    }

    if (hoverTarget == _ShellLocalHoverTarget.compactSong) {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final center = tester.getCenter(songRow);
      await gesture.addPointer(location: center);
      await gesture.moveTo(center);
      await tester.pump(const Duration(milliseconds: 180));

      expect(
        find.descendant(of: songRow, matching: find.byTooltip('Add To')),
        findsNothing,
      );
      expect(find.byTooltip('Play Next'), findsWidgets);
      expect(find.byTooltip('More'), findsWidgets);
      final playNextRect = tester.getRect(
        find
            .descendant(
              of: songRow,
              matching: find.byKey(
                const ValueKey('PlaylistControlItem.PlayNextAction'),
              ),
            )
            .first,
      );
      final moreRect = tester.getRect(
        find
            .descendant(
              of: songRow,
              matching: find.byKey(
                const ValueKey('PlaylistControlItem.MoreAction'),
              ),
            )
            .first,
      );
      expect(playNextRect.left, moreOrLessEquals(515, epsilon: 4));
      expect(playNextRect.top, moreOrLessEquals(297, epsilon: 4));
      expect(playNextRect.width, moreOrLessEquals(34, epsilon: 1));
      expect(playNextRect.height, moreOrLessEquals(34, epsilon: 1));
      expect(moreRect.left, moreOrLessEquals(549, epsilon: 4));
      expect(moreRect.top, moreOrLessEquals(297, epsilon: 4));
      expect(moreRect.width, moreOrLessEquals(34, epsilon: 1));
      expect(moreRect.height, moreOrLessEquals(34, epsilon: 1));
    }
  }
  if (exercise != null) {
    await exercise(tester);
  }
  await _writeBoundaryPng(tester, repaintKey, path);
}

Finder _wideFolderCardFinder() {
  return find
      .ancestor(
        of: find.text('Encore'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.minHeight == 232 &&
              widget.decoration is BoxDecoration,
        ),
      )
      .first;
}

Finder _wideSongCardFinder() {
  return find
      .ancestor(of: find.text('Glass Horizon'), matching: find.byType(InkWell))
      .first;
}

Finder _glassButtonForTooltip(String tooltip) {
  return find
      .descendant(
        of: find.byTooltip(tooltip),
        matching: find.byType(GlassIconButton),
      )
      .first;
}

enum _ShellLocalHoverTarget {
  folder,
  song,
  compactFolder,
  compactFolderFocus,
  compactSong,
}

Future<void> _writeHiddenFoldersScreenshot(
  WidgetTester tester, {
  required String path,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 520);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  final repaintKey = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: repaintKey,
      child: _VisualVerifyApp(
        brightness: Brightness.dark,
        repository: const _VisualRepository(),
        snapshot: _snapshot,
        child: ColoredBox(
          color: _shellBackground(Brightness.dark),
          child: const HiddenFoldersPage(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  expect(
    find.text('Hidden items stay out of Local until resumed.'),
    findsOneWidget,
  );
  expect(find.text('Resume'), findsNWidgets(2));
  await _writeBoundaryPng(tester, repaintKey, path);
}

Future<void> _writeBoundaryPng(
  WidgetTester tester,
  GlobalKey key,
  String path,
) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

class _VisualVerifyApp extends StatelessWidget {
  const _VisualVerifyApp({
    required this.brightness,
    required this.repository,
    required this.snapshot,
    this.mediaController,
    required this.child,
  });

  final Brightness brightness;
  final LibraryRepository repository;
  final LibraryContentData snapshot;
  final MediaControlController? mediaController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => _i18n),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
        libraryRepositoryProvider.overrideWithValue(repository),
        mediaControlControllerProvider.overrideWith(
          (ref) => mediaController ?? MediaControlController(),
        ),
      ],
      child: SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode:
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            backgroundColor: _shellBackground(brightness),
            body: child,
          ),
        ),
      ),
    );
  }
}

class _VisualRepository extends LibraryRepository {
  const _VisualRepository([this.snapshot = _snapshot]);

  final LibraryContentData snapshot;

  @override
  Future<LibraryContentData> getLibraryContentData() async {
    return snapshot;
  }

  @override
  Future<SettingsSnapshot?> getSettingsSnapshot() async {
    return const SettingsSnapshot.defaults();
  }

  @override
  Future<void> saveViewState({String? lastPage, int? lastPlaylistId}) async {}

  @override
  Future<void> commitPendingDeletes() async {}

  @override
  Future<bool> shouldCheckStartupArtistSplits() async {
    return false;
  }

  @override
  Future<List<HiddenStorageItem>> getHiddenStorageItems() async {
    return const [
      HiddenStorageItem(
        id: 1,
        type: 'folder',
        path: r'C:\Music\Collections\Hidden Imports',
      ),
      HiddenStorageItem(
        id: 2,
        type: 'file',
        path: r'C:\Music\Collections\Live\Sidelined.mp3',
      ),
    ];
  }

  @override
  Future<void> resumeHiddenStorageItem(HiddenStorageItem item) async {}
}

LibraryContentData _snapshotWithRootPath(String rootPath) {
  return LibraryContentData(
    songs: _snapshot.songs,
    recentSongs: _snapshot.recentSongs,
    recentPlaylists: _snapshot.recentPlaylists,
    recentAlbums: _snapshot.recentAlbums,
    recentArtists: _snapshot.recentArtists,
    recentSearches: _snapshot.recentSearches,
    playlists: _snapshot.playlists,
    folders: _snapshot.folders,
    favoritePlaylistId: _snapshot.favoritePlaylistId,
    nowPlaying: _snapshot.nowPlaying,
    hasLibrary: _snapshot.hasLibrary,
    sortCriterion: _snapshot.sortCriterion,
    albumsSort: _snapshot.albumsSort,
    showCount: _snapshot.showCount,
    hideMultiSelectCommandBarAfterOperation:
        _snapshot.hideMultiSelectCommandBarAfterOperation,
    localViewMode: _snapshot.localViewMode,
    rootPath: rootPath,
    databasePath: _snapshot.databasePath,
  );
}

LibraryContentData _snapshotWithLocalViewMode(LocalViewMode localViewMode) {
  return LibraryContentData(
    songs: _snapshot.songs,
    recentSongs: _snapshot.recentSongs,
    recentPlaylists: _snapshot.recentPlaylists,
    recentAlbums: _snapshot.recentAlbums,
    recentArtists: _snapshot.recentArtists,
    recentSearches: _snapshot.recentSearches,
    playlists: _snapshot.playlists,
    folders: _snapshot.folders,
    favoritePlaylistId: _snapshot.favoritePlaylistId,
    nowPlaying: _snapshot.nowPlaying,
    hasLibrary: _snapshot.hasLibrary,
    sortCriterion: _snapshot.sortCriterion,
    albumsSort: _snapshot.albumsSort,
    showCount: _snapshot.showCount,
    hideMultiSelectCommandBarAfterOperation:
        _snapshot.hideMultiSelectCommandBarAfterOperation,
    localViewMode: localViewMode,
    rootPath: _snapshot.rootPath,
    databasePath: _snapshot.databasePath,
  );
}

ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xff0078d7),
      brightness: brightness,
    ),
    extensions: [
      dark ? AppNotificationThemeColors.dark : AppNotificationThemeColors.light,
      dark
          ? DefaultAlbumArtworkThemeColors.dark
          : DefaultAlbumArtworkThemeColors.light,
      dark
          ? MissingLibraryRootThemeColors.night
          : MissingLibraryRootThemeColors.day,
      dark ? LocalPageColors.night : LocalPageColors.day,
    ],
  );
}

Color _shellBackground(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xff0f1318)
      : const Color(0xfff8fbfe);
}

const _snapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\Collections\Live\Sessions\Archive\Intro.mp3',
      title: 'Intro Signal',
      artist: 'River North',
      artists: ['River North'],
      album: 'Archive Night',
      duration: 92,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-31T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 2,
      path: r'C:\Music\Collections\Live\Sessions\Archive\Glass Horizon.mp3',
      title: 'Glass Horizon',
      artist: 'Noon Section',
      artists: ['Noon Section'],
      album: 'Archive Night',
      duration: 184,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-31T00:00:00',
      favorite: true,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 3,
      path: r'C:\Music\Collections\Live\Sessions\Archive\North Pier.mp3',
      title: 'North Pier',
      artist: 'Noon Section',
      artists: ['Noon Section'],
      album: 'Archive Night',
      duration: 226,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-31T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 4,
      path: r'C:\Music\Collections\Live\Sessions\Archive\Encore\Afterlight.mp3',
      title: 'Afterlight',
      artist: 'The Harbor',
      artists: ['The Harbor'],
      album: 'Late Set',
      duration: 206,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-31T00:00:00',
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
      id: 20,
      name: 'My Favorites',
      priority: 0,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: true,
    ),
    LibraryPlaylist(
      id: 30,
      name: 'Road Mix',
      priority: 1,
      songCount: 3,
      songIds: [1, 2, 3],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
  ],
  folders: [
    LibraryFolder(
      id: 1,
      path: r'C:\Music\Collections',
      parentId: 0,
      criterion: 0,
    ),
    LibraryFolder(
      id: 2,
      path: r'C:\Music\Collections\Live',
      parentId: 1,
      criterion: 0,
    ),
    LibraryFolder(
      id: 3,
      path: r'C:\Music\Collections\Live\Sessions',
      parentId: 2,
      criterion: 0,
    ),
    LibraryFolder(
      id: 4,
      path: r'C:\Music\Collections\Live\Sessions\Archive',
      parentId: 3,
      criterion: 0,
    ),
    LibraryFolder(
      id: 5,
      path: r'C:\Music\Collections\Live\Sessions\Archive\Encore',
      parentId: 4,
      criterion: 0,
    ),
  ],
  favoritePlaylistId: 20,
  nowPlaying: NowPlayingSnapshot(playlistId: 9, songIds: [9]),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  rootPath: r'C:\Music',
  databasePath: '',
);

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'app.shell': 'Simple Melody Player',
    'albums.addSelectedTo': 'Add To',
    'albums.clearSelection': 'Clear Selection',
    'albums.multiSelect': 'Multi Select',
    'albums.playSelected': 'Play',
    'albums.reverseSelection': 'Reverse Selection',
    'albums.selectAll': 'Select All',
    'albums.selectedCount': '{count} selected',
    'common.album': 'Album',
    'common.albumUnknown': 'Unknown Album',
    'common.artist': 'Artist',
    'common.artistSeparator': ', ',
    'common.artistUnknown': 'Unknown Artist',
    'common.cancel': 'Cancel',
    'common.folders': 'Folders',
    'common.myFavorites': 'Favorites',
    'common.name': 'Name',
    'common.sort': 'Sort',
    'context.addFavorite': 'Add Favorite',
    'context.addToPlaylist': 'Add To',
    'context.deleteFromDisk': 'Delete From Disk',
    'context.pause': 'Pause',
    'context.play': 'Play',
    'context.playNext': 'Play Next',
    'context.removeFavorite': 'Remove Favorite',
    'context.removeFromList': 'Remove',
    'hiddenFolders.empty': 'No hidden items.',
    'hiddenFolders.introduction':
        'Hidden items stay out of Local until resumed.',
    'hiddenFolders.resume': 'Resume',
    'library.chooseFolder': 'Choose Folder',
    'library.openingFolderPicker': 'Opening Folder Picker',
    'local.allSongs': 'All Songs',
    'local.currentPath': 'Current Path',
    'local.folderCardStats': '{folders} folders · {songs} songs',
    'local.folderSongsShort': '{count} songs',
    'local.gridFolderPlayInfo': 'Shuffle all music under "{name}"',
    'local.hiddenFolders': 'Hidden Folders',
    'local.libraryRoot': 'Library root',
    'local.newFolder': 'New Folder',
    'local.noRoot': 'No root',
    'local.noRootCopy': 'Choose a library folder first.',
    'local.sortByAlbum': 'Album',
    'local.sortByArtist': 'Artist',
    'local.sortByTitle': 'Title',
    'local.updateFolderShort': 'Refresh',
    'local.sortReverseList': 'Reverse',
    'local.updateFolder': 'Refresh folder',
    'local.openLocalButtonTooltip': 'Open local',
    'local.searchFolderButtonTooltip': 'Search in folder',
    'local.viewHiddenFolders': 'View Hidden Folders',
    'musicLibrary.titleHeader': 'Title',
    'nowPlaying.randomPlay': 'Shuffle',
    'player.more': 'More',
  },
);
