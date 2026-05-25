import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';

void main() {
  testWidgets('PlaylistControlItem opens shared swipe remove action', (
    tester,
  ) async {
    var removed = false;
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: PlaylistControlItem(
                song: _song,
                current: false,
                playing: false,
                selected: false,
                selectionMode: false,
                removeLabel: 'Remove',
                onPlayTrack: () {},
                onTogglePlayPause: () {},
                onToggleSelection: () {},
                onPlayNextClick: () {},
                onRemoveFromListClick: () {
                  removed = true;
                },
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PlaylistControlItem)),
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-50, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-50, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.byType(PlaylistControlItem)) + const Offset(126, 0),
    );
    await tester.pump();

    expect(removed, isTrue);
  });

  testWidgets('PlaylistControlItem shows Electron drop indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: const Scaffold(
            body: SizedBox(
              width: 360,
              child: PlaylistControlItem(
                song: _song,
                current: false,
                playing: false,
                selected: false,
                selectionMode: false,
                dropPosition: PlaylistControlDropPosition.before,
                onPlayTrack: _noop,
                onTogglePlayPause: _noop,
                onToggleSelection: _noop,
                onPlayNextClick: _noop,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('PlaylistControlItem.DropIndicator')),
      findsOneWidget,
    );
  });

  testWidgets('PlaylistControlItem activates with keyboard like Electron', (
    tester,
  ) async {
    var playCount = 0;
    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: PlaylistControlItem(
                song: _song,
                current: false,
                playing: false,
                selected: false,
                selectionMode: false,
                onPlayTrack: () {
                  playCount += 1;
                },
                onTogglePlayPause: _noop,
                onToggleSelection: _noop,
                onPlayNextClick: _noop,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PlaylistControlItem));
    await tester.pump();
    playCount = 0;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(playCount, 1);
  });
}

void _noop() {}

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'common.albumUnknown': 'Unknown Album',
    'common.artistSeparator': ' / ',
    'common.artistUnknown': 'Unknown Artist',
    'context.addToPlaylist': 'Add To',
    'context.play': 'Play',
    'context.playNext': 'Play Next',
    'nowPlaying.remove': 'Remove',
    'player.more': 'More',
    'player.pause': 'Pause',
  },
);

const _song = LibrarySong(
  id: 1,
  path: '/music/song.mp3',
  title: 'Song',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 180,
  playCount: 0,
  lyricsOffsetMs: 0,
  dateAdded: '2026-05-25',
  favorite: false,
  thumbnailPath: '',
);
