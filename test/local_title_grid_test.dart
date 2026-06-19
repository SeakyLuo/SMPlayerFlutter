import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';
import 'package:smplayer_flutter/src/library/ui/local_page_quick_jump.dart';
import 'package:smplayer_flutter/src/library/ui/local_title_grid.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'local.currentPath': 'Current Path',
      'local.hiddenFolders': 'Hidden Folders',
      'local.path': 'Path',
    },
  );

  testWidgets('LocalTitleGrid renders Electron breadcrumb label and chain', (
    tester,
  ) async {
    _setSurface(tester);

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(extensions: const [LocalPageColors.day]),
          home: Scaffold(
            body: LocalTitleGrid(
              songs: const [],
              folders: const [
                LibraryFolder(
                  id: 1,
                  path: r'C:\Music\Sub',
                  parentId: 0,
                  criterion: 0,
                ),
                LibraryFolder(
                  id: 2,
                  path: r'C:\Music\Sub\Deep',
                  parentId: 1,
                  criterion: 0,
                ),
              ],
              i18n: i18n,
              rootPath: r'C:\Music',
              currentRelativePath: 'Sub/Deep',
              onHiddenFoldersListButtonClick: () {},
              onOpenFolder: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Current Path'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Sub'), findsOneWidget);
    expect(find.text('Deep'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('FolderChainListView.GlassBackground')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('FolderChain.Dropdown.Sub')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('FolderChain.Dropdown.Sub/Deep')),
      findsNothing,
    );
    expect(find.textContaining(r'C:\Music'), findsNothing);
  });

  testWidgets('FolderChainListView hover background matches container radius', (
    tester,
  ) async {
    _setSurface(tester);

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: ThemeData(extensions: const [LocalPageColors.day]),
          home: Scaffold(
            body: FolderChainListView(
              songs: const [],
              folders: const [],
              i18n: i18n,
              rootPath: r'C:\Music',
              currentRelativePath: '',
              onOpenFolder: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.text('Music')));
    await tester.pumpAndSettle();

    final hoverDecoration =
        tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).firstWhere((
              box,
            ) {
              final decoration = box.decoration;
              return decoration is BoxDecoration &&
                  decoration.color == LocalPageColors.day.surfaceControlHover;
            }).decoration
            as BoxDecoration;

    expect(
      hoverDecoration.borderRadius,
      BorderRadius.circular(localFolderChainRadius),
    );
  });

  testWidgets(
    'FolderChainListView current segment scroll action matches Electron',
    (tester) async {
      _setSurface(tester);
      var currentClicks = 0;

      await tester.pumpWidget(
        _FolderChainTestApp(
          i18n: i18n,
          folders: const [
            LibraryFolder(
              id: 10,
              path: r'C:\Music\Sub',
              parentId: 0,
              criterion: 0,
            ),
          ],
          currentRelativePath: 'Sub',
          onCurrentFolderClick: () {
            currentClicks += 1;
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('FolderChain.Path.Sub')));
      await tester.pump();

      expect(currentClicks, 1);
    },
  );

  testWidgets('FolderChainListView wheel scrolls horizontally like Electron', (
    tester,
  ) async {
    _setSurface(tester);
    final folders = _nestedFolders(12);

    await tester.pumpWidget(
      _FolderChainTestApp(
        i18n: i18n,
        width: 180,
        folders: folders,
        currentRelativePath: _nestedRelativePath(12),
      ),
    );
    await tester.pump();
    await tester.pump();

    final listView = tester.widget<ListView>(find.byType(ListView).first);
    final controller = listView.controller!;
    controller.jumpTo(0);
    await tester.pump();

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(FolderChainListView)),
        scrollDelta: const Offset(0, 80),
      ),
    );
    await tester.pump();

    expect(controller.offset, greaterThan(0));
  });

  testWidgets(
    'FolderChainListView pointer drag scrolls and suppresses segment tap',
    (tester) async {
      _setSurface(tester);
      final folders = _nestedFolders(12);
      String? openedFolder;

      await tester.pumpWidget(
        _FolderChainTestApp(
          i18n: i18n,
          width: 180,
          folders: folders,
          currentRelativePath: _nestedRelativePath(12),
          onOpenFolder: (folderPath) {
            openedFolder = folderPath;
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      final listView = tester.widget<ListView>(find.byType(ListView).first);
      final controller = listView.controller!;
      controller.jumpTo(0);
      await tester.pump();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final start = tester.getCenter(find.byType(FolderChainListView));
      await gesture.down(start);
      await gesture.moveBy(const Offset(-80, 0));
      await gesture.up();
      await tester.pump();
      await gesture.removePointer();

      expect(controller.offset, greaterThan(0));
      expect(openedFolder, isNull);
    },
  );

  testWidgets('FolderChainListView closes child flyouts and opens next menu', (
    tester,
  ) async {
    _setSurface(tester);
    const folders = [
      LibraryFolder(id: 1, path: r'C:\Music\A', parentId: 0, criterion: 0),
      LibraryFolder(id: 2, path: r'C:\Music\A\B', parentId: 1, criterion: 0),
      LibraryFolder(id: 3, path: r'C:\Music\C', parentId: 0, criterion: 0),
    ];

    await tester.pumpWidget(
      _FolderChainTestApp(
        i18n: i18n,
        folders: folders,
        currentRelativePath: 'A',
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('FolderChain.Dropdown.')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('FolderChain.Child.C')), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('FolderChain.Child.C')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('FolderChain.Dropdown.')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('FolderChain.Child.C')), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('FolderChain.Child.C')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('FolderChain.Dropdown.A')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('FolderChain.Child.C')), findsNothing);
    expect(find.byKey(const ValueKey('FolderChain.Child.A/B')), findsOneWidget);

    await tester.tapAt(const Offset(1100, 760));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('FolderChain.Child.A/B')), findsNothing);
  });

  testWidgets(
    'FolderChainListView child flyout uses MenuFlyout and targets child menu',
    (tester) async {
      _setSmallSurface(tester);
      final folders = [
        for (var index = 0; index < 18; index += 1)
          LibraryFolder(
            id: index + 1,
            path: 'C:\\Music\\Child$index',
            parentId: 0,
            criterion: 0,
          ),
      ];
      String? menuFolderPath;

      await tester.pumpWidget(
        _FolderChainTestApp(
          i18n: i18n,
          width: 240,
          folders: folders,
          currentRelativePath: '',
          onOpenFolderMenu: (folderPath, _) {
            menuFolderPath = folderPath;
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('FolderChain.Dropdown.')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('MenuFlyoutPanel.0.18')),
        findsOneWidget,
      );
      final firstChild = find.byKey(const ValueKey('FolderChain.Child.Child0'));
      final lastChild = find.byKey(const ValueKey('FolderChain.Child.Child17'));
      expect(firstChild, findsOneWidget);
      expect(tester.getRect(firstChild).left, greaterThanOrEqualTo(0));

      await tester.tap(firstChild, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(menuFolderPath, 'Child0');

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(firstChild, findsNothing);

      await tester.tap(find.byKey(const ValueKey('FolderChain.Dropdown.')));
      await tester.pumpAndSettle();
      expect(firstChild, findsOneWidget);

      final menuList =
          find
              .descendant(
                of: find.byKey(const ValueKey('MenuFlyoutPanel.0.18')),
                matching: find.byType(Scrollable),
              )
              .first;
      await tester.scrollUntilVisible(lastChild, 180, scrollable: menuList);
      await tester.pumpAndSettle();
      expect(lastChild, findsOneWidget);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(firstChild, findsNothing);
    },
  );

  testWidgets(
    'FolderChainListView accepts drops on path segments and child flyout items',
    (tester) async {
      _setSurface(tester);
      const folders = [
        LibraryFolder(id: 1, path: r'C:\Music\A', parentId: 0, criterion: 0),
        LibraryFolder(id: 2, path: r'C:\Music\A\B', parentId: 1, criterion: 0),
        LibraryFolder(id: 3, path: r'C:\Music\C', parentId: 0, criterion: 0),
      ];
      final acceptedTargets = <String>[];

      await tester.pumpWidget(
        _FolderChainTestApp(
          i18n: i18n,
          folders: folders,
          currentRelativePath: 'A/B',
          dragPayload: const LocalItemsDragPayload(
            songIds: [7],
            folderPaths: [],
          ),
          onWillAcceptDrop: (targetRelativePath, payload) {
            return payload.songIds.single == 7 && targetRelativePath != 'A/B';
          },
          onAcceptDrop: (targetRelativePath, payload) {
            acceptedTargets.add(targetRelativePath);
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.drag(
        find.byKey(const ValueKey('FolderChain.DragSource')),
        tester.getCenter(find.byKey(const ValueKey('FolderChain.Path.A'))) -
            tester.getCenter(
              find.byKey(const ValueKey('FolderChain.DragSource')),
            ),
      );
      await tester.pumpAndSettle();
      expect(acceptedTargets, ['A']);

      await tester.tap(find.byKey(const ValueKey('FolderChain.Dropdown.')));
      await tester.pumpAndSettle();
      final childTarget = tester.widget<DragTarget<Object>>(
        find
            .descendant(
              of: find.byKey(const ValueKey('FolderChain.Child.C')),
              matching: find.byWidgetPredicate(
                (widget) => widget is DragTarget,
              ),
            )
            .first,
      );
      const payload = LocalItemsDragPayload(songIds: [7], folderPaths: []);
      final willAccept = childTarget.onWillAcceptWithDetails!(
        DragTargetDetails<Object>(
          data: payload,
          offset: tester.getCenter(
            find.byKey(const ValueKey('FolderChain.Child.C')),
          ),
        ),
      );
      expect(willAccept, isTrue);
      childTarget.onAcceptWithDetails!(
        DragTargetDetails<Object>(
          data: payload,
          offset: tester.getCenter(
            find.byKey(const ValueKey('FolderChain.Child.C')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(acceptedTargets, ['A', 'C']);
    },
  );

  testWidgets(
    'FolderChainListView ancestor click opens Electron target segment',
    (tester) async {
      _setSurface(tester);
      String? openedFolder;

      await tester.pumpWidget(
        _FolderChainTestApp(
          i18n: i18n,
          folders: const [
            LibraryFolder(
              id: 1,
              path: r'C:\Music\A',
              parentId: 0,
              criterion: 0,
            ),
            LibraryFolder(
              id: 2,
              path: r'C:\Music\A\B',
              parentId: 1,
              criterion: 0,
            ),
          ],
          currentRelativePath: 'A/B',
          onOpenFolder: (folderPath) {
            openedFolder = folderPath;
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('FolderChain.Path.A')));
      await tester.pump();

      expect(openedFolder, 'A');
    },
  );

  testWidgets('LocalPageColors resolves night palette from theme', (
    tester,
  ) async {
    Color? resolvedPanel;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          extensions: const [LocalPageColors.night],
        ),
        home: Builder(
          builder: (context) {
            resolvedPanel = LocalPageColors.of(context).panel;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(resolvedPanel, LocalPageColors.night.panel);
  });
}

class _FolderChainTestApp extends StatelessWidget {
  const _FolderChainTestApp({
    required this.i18n,
    required this.folders,
    required this.currentRelativePath,
    this.width = 500,
    this.onCurrentFolderClick,
    this.onOpenFolder,
    this.onOpenFolderMenu,
    this.dragPayload,
    this.onWillAcceptDrop,
    this.onAcceptDrop,
  });

  final SmPlayerI18n i18n;
  final List<LibraryFolder> folders;
  final String currentRelativePath;
  final double width;
  final VoidCallback? onCurrentFolderClick;
  final ValueChanged<String>? onOpenFolder;
  final void Function(String targetRelativePath, Offset position)?
  onOpenFolderMenu;
  final LocalItemsDragPayload? dragPayload;
  final bool Function(String targetRelativePath, LocalItemsDragPayload payload)?
  onWillAcceptDrop;
  final void Function(String targetRelativePath, LocalItemsDragPayload payload)?
  onAcceptDrop;

  @override
  Widget build(BuildContext context) {
    return SmPlayerI18nScope(
      i18n: i18n,
      child: MaterialApp(
        theme: ThemeData(extensions: const [LocalPageColors.day]),
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dragPayload != null)
                Draggable<LocalItemsDragPayload>(
                  data: dragPayload!,
                  feedback: const Material(
                    child: SizedBox.square(dimension: 24),
                  ),
                  child: Container(
                    key: const ValueKey('FolderChain.DragSource'),
                    width: 24,
                    height: 24,
                    color: Colors.transparent,
                  ),
                ),
              SizedBox(
                width: width,
                child: FolderChainListView(
                  songs: const [],
                  folders: folders,
                  i18n: i18n,
                  rootPath: r'C:\Music',
                  currentRelativePath: currentRelativePath,
                  onCurrentFolderClick: onCurrentFolderClick,
                  onOpenFolder: onOpenFolder ?? (_) {},
                  onOpenFolderMenu: onOpenFolderMenu,
                  onWillAcceptDrop: onWillAcceptDrop,
                  onAcceptDrop: onAcceptDrop,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<LibraryFolder> _nestedFolders(int count) {
  final folders = <LibraryFolder>[];
  var relativePath = '';
  for (var index = 0; index < count; index += 1) {
    final name = 'Folder$index';
    relativePath = relativePath.isEmpty ? name : '$relativePath/$name';
    folders.add(
      LibraryFolder(
        id: index + 1,
        path: 'C:\\Music\\${relativePath.replaceAll('/', '\\')}',
        parentId: index,
        criterion: 0,
      ),
    );
  }
  return folders;
}

String _nestedRelativePath(int count) {
  return [
    for (var index = 0; index < count; index += 1) 'Folder$index',
  ].join('/');
}

void _setSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void _setSmallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(240, 420);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
