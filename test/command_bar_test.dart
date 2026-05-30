import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/app/uniform_multi_select_icon.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'common.myFavorites': 'My Favorites',
      'common.nowPlaying': 'Now Playing',
      'context.addToPlaylist': 'Add To',
      'context.deleteFromDisk': 'Delete From Disk',
      'context.hideFile': 'Hide File',
      'context.moveToFolder': 'Move To Folder',
      'context.pause': 'Pause',
      'context.play': 'Play',
      'context.playNext': 'Play Next',
      'context.removeFromList': 'Remove From List',
      'context.seeAlbum': 'See Album',
      'context.seeAlbumArt': 'See Album Art',
      'context.seeArtist': 'See Artist',
      'context.seeLocalFile': 'See In File Explorer',
      'context.seeLyrics': 'See Lyrics',
      'context.seeMusicInfo': 'See Music Info',
      'context.select': 'Select',
      'context.view': 'View',
      'playlists.newPlaylist': 'New Playlist',
      'preferences.level.dislike': 'Dislike',
      'preferences.level.do-not-appear': 'Do Not Appear',
      'preferences.level.high': 'High',
      'preferences.level.higher': 'Higher',
      'preferences.level.normal': 'Normal',
      'preferences.level.very-high': 'Very High',
      'preferences.undoPrefer': 'Undo Prefer',
      'notification.removedFrom': 'Removed {title} from {target}',
      'notification.songsRemovedFrom': 'Removed {count} songs from {target}',
      'settings.preferenceSettings': 'Preference Settings',
    },
  );

  testWidgets('CommandBar keeps buttons inline when space is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            child: CommandBar(
              children: [
                CommandBarButton(
                  key: const ValueKey('first-button'),
                  icon: FluentIcons.play_24_regular,
                  label: 'First',
                  onPressed: () {},
                ),
                CommandBarButton(
                  key: const ValueKey('second-button'),
                  icon: FluentIcons.add_24_regular,
                  label: 'Second',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('first-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('second-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('CommandBar.MoreButton')), findsNothing);
  });

  testWidgets(
    'CommandBar standard text buttons use the shared text icon button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommandBar(
              children: [
                CommandBarButton(
                  icon: FluentIcons.play_24_regular,
                  label: 'Play',
                  onPressed: () {},
                ),
                CommandBarButton(
                  icon: FluentIcons.more_horizontal_24_regular,
                  label: 'More',
                  showLabel: false,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(SmPlayerTextIconButton), findsNWidgets(2));
    },
  );

  testWidgets('CommandBar icon-only buttons use night colors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          extensions: const [SmPlayerTextIconButtonColors.night],
        ),
        home: Scaffold(
          body: CommandBar(
            children: [
              CommandBarButton(
                key: const ValueKey('more-button'),
                icon: FluentIcons.more_horizontal_24_regular,
                label: 'More',
                showLabel: false,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final decoratedBox = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byKey(const ValueKey('more-button')),
            matching: find.byType(DecoratedBox),
          ),
        )
        .firstWhere((box) => box.decoration is BoxDecoration);
    final decoration = decoratedBox.decoration as BoxDecoration;

    expect(decoration.color, SmPlayerTextIconButtonColors.night.control);
    expect(
      decoration.border,
      Border.all(color: SmPlayerTextIconButtonColors.night.controlBorder),
    );
  });

  testWidgets('CommandBar appbar actions share icon and text button metrics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandBar(
            style: CommandBarStyleVariant.appBar,
            children: [
              CommandBarButton(
                key: const ValueKey('appbar-icon'),
                icon: FluentIcons.search_20_regular,
                label: 'Search',
                showLabel: false,
                onPressed: () {},
              ),
              CommandBarButton(
                key: const ValueKey('appbar-text'),
                icon: FluentIcons.play_20_regular,
                label: 'Quick Play',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final iconRect = tester.getRect(find.byKey(const ValueKey('appbar-icon')));
    final textRect = tester.getRect(find.byKey(const ValueKey('appbar-text')));
    expect(iconRect.size, const Size.square(40));
    expect(textRect.height, 40);

    final textButton = tester.widget<SmPlayerTextIconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('appbar-text')),
        matching: find.byType(SmPlayerTextIconButton),
      ),
    );
    expect(textButton.fontSize, 14);
    expect(textButton.fontVariations, const [FontVariation.weight(650)]);
  });

  testWidgets('SmPlayerTextIconButton does not render a box shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmPlayerTextIconButton(
            icon: FluentIcons.play_24_regular,
            label: 'Play',
            onPressed: () {},
          ),
        ),
      ),
    );

    final decoratedBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(SmPlayerTextIconButton),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.boxShadow, isNull);
  });

  testWidgets('CommandBar moves rightmost overflowable buttons into More', (
    tester,
  ) async {
    var invoked = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 170,
            child: CommandBar(
              overflowLabel: 'More',
              children: [
                CommandBarButton(
                  key: const ValueKey('first-button'),
                  icon: FluentIcons.play_24_regular,
                  label: 'First',
                  onPressed: () {
                    invoked = 'first';
                  },
                ),
                CommandBarButton(
                  key: const ValueKey('second-button'),
                  icon: FluentIcons.add_24_regular,
                  label: 'Second',
                  onPressed: () {
                    invoked = 'second';
                  },
                ),
                CommandBarButton(
                  key: const ValueKey('third-button'),
                  icon: FluentIcons.delete_24_regular,
                  label: 'Third',
                  onPressed: () {
                    invoked = 'third';
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('first-button')), findsNothing);
    expect(find.byKey(const ValueKey('second-button')), findsNothing);
    expect(find.byKey(const ValueKey('third-button')), findsNothing);
    expect(find.byKey(const ValueKey('CommandBar.MoreButton')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('CommandBar.MoreButton')));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Third'), findsOneWidget);

    await tester.tap(find.text('Third'));
    await tester.pumpAndSettle();

    expect(invoked, 'third');
  });

  testWidgets('CommandBar keeps overflow on one row instead of wrapping', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 240,
              child: CommandBar(
                overflowLabel: 'More',
                children: [
                  CommandBarButton(
                    icon: FluentIcons.play_24_regular,
                    label: 'Quick Play',
                    onPressed: () {},
                  ),
                  CommandBarButton(
                    icon: FluentIcons.arrow_shuffle_24_regular,
                    label: 'Random Play',
                    onPressed: () {},
                  ),
                  CommandBarButton(
                    icon: FluentIcons.arrow_sort_24_regular,
                    label: 'Sort',
                    onPressed: () {},
                  ),
                  CommandBarButton(
                    icon: FluentIcons.multiselect_ltr_24_regular,
                    label: 'Multi Select',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final commandBarRect = tester.getRect(find.byType(CommandBar));
    expect(commandBarRect.height, 48);
    expect(find.byKey(const ValueKey('CommandBar.MoreButton')), findsOneWidget);
  });

  testWidgets('CommandBar overflow click can open a new root flyout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 96,
            child: CommandBar(
              overflowLabel: 'More',
              children: [
                CommandBarButton(
                  icon: FluentIcons.arrow_shuffle_24_regular,
                  label: 'Random',
                  onPressed: () {},
                  onOverflowPressedWithContext: (context) {
                    showMenuFlyout(
                      context,
                      items: [
                        MenuFlyoutItem(
                          key: 'library',
                          text: 'Library',
                          onPressed: () {},
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('CommandBar.MoreButton')));
    await tester.pumpAndSettle();

    expect(find.text('Random'), findsOneWidget);
    expect(find.text('Library'), findsNothing);

    await tester.tap(find.text('Random'));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
  });

  testWidgets('MenuFlyout opens submenu items like Electron flyouts', (
    tester,
  ) async {
    var selected = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    items: [
                      MenuFlyoutItem(
                        key: 'add-to',
                        text: 'Add To',
                        icon: FluentIcons.add_20_regular,
                        submenu: [
                          MenuFlyoutItem(
                            key: 'playlist',
                            text: 'Mix',
                            icon: FluentIcons.music_note_2_20_regular,
                            onPressed: () {
                              selected = 'mix';
                            },
                          ),
                        ],
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Add To'), findsOneWidget);
    expect(find.text('Mix'), findsNothing);

    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();

    expect(selected, 'mix');
  });

  testWidgets('MenuFlyout uses the AlbumsPage uniform multi-select icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    items: [
                      MenuFlyoutItem(
                        key: 'select',
                        text: 'Select',
                        icon: FluentIcons.multiselect_ltr_20_regular,
                        onPressed: () {},
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(UniformMultiSelectIcon), findsOneWidget);
  });

  testWidgets('MenuFlyout closes on Escape like Electron flyouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    items: [
                      MenuFlyoutItem(
                        key: 'first',
                        text: 'First',
                        onPressed: () {},
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('First'), findsNothing);
  });

  testWidgets('MenuFlyout item actions receive the source anchor context', (
    tester,
  ) async {
    BuildContext? sourceContext;
    BuildContext? actionContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) {
                sourceContext = context;
                return TextButton(
                  onPressed: () {
                    showMenuFlyout(
                      context,
                      items: [
                        MenuFlyoutItem(
                          key: 'anchor-action',
                          text: 'Anchor Action',
                          onPressedWithContext: (context) {
                            actionContext = context;
                          },
                        ),
                      ],
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anchor Action'));
    await tester.pumpAndSettle();

    expect(actionContext, same(sourceContext));
  });

  testWidgets('MenuFlyout does not scroll when all items fit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    items: [
                      MenuFlyoutItem(
                        key: 'first',
                        text: 'First',
                        onPressed: () {},
                      ),
                      MenuFlyoutItem(
                        key: 'second',
                        text: 'Second',
                        onPressed: () {},
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets('MenuFlyout root does not scroll like Electron root flyouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 220);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    position: const Offset(8, 8),
                    avoidPlayerBar: false,
                    items: [
                      for (var index = 0; index < 8; index += 1)
                        MenuFlyoutItem(
                          key: 'item-$index',
                          text: 'Item $index',
                          onPressed: () {},
                        ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsNothing);
    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets('MenuFlyout submenu does not scroll when all items fit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMenuFlyout(
                    context,
                    position: const Offset(8, 8),
                    avoidPlayerBar: false,
                    items: [
                      MenuFlyoutItem(
                        key: 'parent',
                        text: 'Parent',
                        submenu: [
                          for (var index = 0; index < 3; index += 1)
                            MenuFlyoutItem(
                              key: 'submenu-item-$index',
                              text: 'Submenu Item $index',
                              onPressed: () {},
                            ),
                        ],
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.text('Parent')));
    await tester.pumpAndSettle();

    expect(find.text('Submenu Item 0'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets(
    'MenuFlyout submenu scrolls when items exceed the available height',
    (tester) async {
      tester.view.physicalSize = const Size(320, 220);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () {
                    showMenuFlyout(
                      context,
                      position: const Offset(8, 8),
                      avoidPlayerBar: false,
                      items: [
                        MenuFlyoutItem(
                          key: 'parent',
                          text: 'Parent',
                          submenu: [
                            for (var index = 0; index < 8; index += 1)
                              MenuFlyoutItem(
                                key: 'submenu-item-$index',
                                text: 'Submenu Item $index',
                                onPressed: () {},
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      await gesture.moveTo(tester.getCenter(find.text('Parent')));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(Scrollable), findsOneWidget);
    },
  );

  test(
    'MusicMenuFlyout mirrors Electron Add To filtering and View submenu',
    () {
      final items = buildMusicMenuFlyoutItems(
        i18n: i18n,
        songId: 1,
        isFavorite: false,
        isCurrentTrack: false,
        isPlaying: true,
        currentTrackId: 2,
        playlists: const [
          MultiSelectCommandBarPlaylist(
            id: 10,
            name: 'Already Has Song',
            songIds: [1],
          ),
          MultiSelectCommandBarPlaylist(id: 11, name: 'Mix', songIds: [2]),
        ],
        folders: const [
          MenuFlyoutFolder(
            id: 1,
            name: 'Rock',
            path: r'C:\Music\Rock',
            parentId: 0,
          ),
        ],
        showMoveToFolder: true,
        showHideFile: true,
        preferenceLevel: 'high',
        onPlay: () {},
        onPause: () {},
        onPlayNext: () {},
        onAddToNowPlaying: () {},
        onCreatePlaylist: () {},
        onAddToPlaylist: (_) {},
        onRemove: () {},
        onSelect: () {},
        onToggleFavorite: () {},
        onSetPreference: (_) {},
        onUndoPreference: () {},
        onMoveToFolder: (_) {},
        onDelete: () {},
        onHide: () {},
        onSeeArtist: () {},
        onSeeAlbum: () {},
        onSeeMusicInfo: () {},
        onSeeLyrics: () {},
        onSeeAlbumArt: () {},
        onSeeLocal: () {},
      );

      final addToItem = items.singleWhere((item) => item.key == 'add-to');
      expect(
        addToItem.submenu.map((item) => item.text),
        containsAll(['Now Playing', 'My Favorites', 'New Playlist', 'Mix']),
      );
      expect(
        addToItem.submenu.map((item) => item.text),
        isNot(contains('Already Has Song')),
      );

      expect(
        items.map((item) => item.key),
        containsAll(['select', 'preference', 'delete', 'hide-file', 'view']),
      );
      expect(
        items.singleWhere((item) => item.key == 'select').icon,
        FluentIcons.multiselect_ltr_20_regular,
      );
      final viewItem = items.singleWhere((item) => item.key == 'view');
      expect(viewItem.submenu.map((item) => item.text), [
        'See Artist',
        'See Album',
        'See Music Info',
        'See Lyrics',
        'See Album Art',
        'See In File Explorer',
      ]);
      expect(
        viewItem.submenu
            .where(
              (item) => {
                'see-music-info',
                'see-lyrics',
                'see-album-art',
              }.contains(item.key),
            )
            .map((item) => item.keepOpen),
        everyElement(isTrue),
      );
    },
  );

  test('MusicMenuFlyout hides View when music properties are disabled', () {
    final items = buildMusicMenuFlyoutItems(
      i18n: i18n,
      songId: 1,
      isFavorite: false,
      isCurrentTrack: false,
      isPlaying: true,
      currentTrackId: 2,
      playlists: const [],
      showMusicProperties: false,
      onPlay: () {},
      onPause: () {},
      onPlayNext: () {},
      onAddToNowPlaying: () {},
      onCreatePlaylist: () {},
      onAddToPlaylist: (_) {},
      onRemove: () {},
      onSelect: () {},
      onToggleFavorite: () {},
      onSetPreference: (_) {},
      onSeeArtist: () {},
      onSeeAlbum: () {},
      onSeeMusicInfo: () {},
      onSeeLyrics: () {},
      onSeeAlbumArt: () {},
      onSeeLocal: () {},
    );

    expect(items.map((item) => item.key), isNot(contains('view')));
  });

  test(
    'songsRemovedUndoMessage mirrors Electron single and count messages',
    () {
      const songsById = {
        1: LibrarySong(
          id: 1,
          path: '/music/first.mp3',
          title: 'First',
          artist: 'Artist',
          artists: ['Artist'],
          album: 'Album',
          duration: 100,
          playCount: 1,
          lyricsOffsetMs: 0,
          dateAdded: '2026-01-01',
          favorite: true,
          thumbnailPath: '',
        ),
        2: LibrarySong(
          id: 2,
          path: '/music/second.mp3',
          title: 'Second',
          artist: 'Artist',
          artists: ['Artist'],
          album: 'Album',
          duration: 100,
          playCount: 1,
          lyricsOffsetMs: 0,
          dateAdded: '2026-01-01',
          favorite: true,
          thumbnailPath: '',
        ),
      };

      expect(
        songsRemovedUndoMessage(
          i18n: i18n,
          songIds: const [1],
          songsById: songsById,
          target: 'My Favorites',
        ),
        'Removed First from My Favorites',
      );
      expect(
        songsRemovedUndoMessage(
          i18n: i18n,
          songIds: const [1, 2],
          songsById: songsById,
          target: 'Mix',
        ),
        'Removed 2 songs from Mix',
      );
    },
  );
}
