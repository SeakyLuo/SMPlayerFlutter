import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';

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

    expect(find.byKey(const ValueKey('first-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('second-button')), findsNothing);
    expect(find.byKey(const ValueKey('third-button')), findsNothing);
    expect(find.byKey(const ValueKey('CommandBar.MoreButton')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('CommandBar.MoreButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Third'));
    await tester.pumpAndSettle();

    expect(invoked, 'third');
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
        containsAll(['preference', 'delete', 'hide-file', 'view']),
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
    },
  );
}
