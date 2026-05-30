import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';

void main() {
  testWidgets('writes PlaylistControlItem compact verification screenshot', (
    tester,
  ) async {
    await _writeScreenshot(
      tester,
      size: const Size(390, 220),
      path: '/tmp/smplayer_playlist_control_item_compact_verify.png',
    );
  });

  testWidgets(
    'writes PlaylistControlItem compact hover verification screenshot',
    (tester) async {
      await _writeScreenshot(
        tester,
        size: const Size(390, 220),
        path: '/tmp/smplayer_playlist_control_item_compact_hover_verify.png',
        hover: true,
      );
    },
  );

  testWidgets(
    'writes PlaylistControlItem compact night verification screenshot',
    (tester) async {
      await _writeScreenshot(
        tester,
        size: const Size(390, 220),
        path: '/tmp/smplayer_playlist_control_item_compact_night_verify.png',
        brightness: Brightness.dark,
        hover: true,
      );
    },
  );
}

Future<void> _writeScreenshot(
  WidgetTester tester, {
  required Size size,
  required String path,
  Brightness brightness = Brightness.light,
  bool hover = false,
}) async {
  final repaintKey = GlobalKey();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    SmPlayerI18nScope(
      i18n: _i18n,
      child: MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          extensions: [
            brightness == Brightness.dark
                ? DefaultAlbumArtworkThemeColors.dark
                : DefaultAlbumArtworkThemeColors.light,
          ],
        ),
        home: Scaffold(
          backgroundColor:
              brightness == Brightness.dark
                  ? const Color(0xff101419)
                  : const Color(0xfff6f9fc),
          body: Center(
            child: RepaintBoundary(
              key: repaintKey,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color:
                      brightness == Brightness.dark
                          ? const Color(0xff171c22)
                          : const Color(0xfff8fafc),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        brightness == Brightness.dark
                            ? const Color(0x1fd6e0ec)
                            : const Color(0x297e8b9a),
                  ),
                ),
                child: SizedBox(
                  width: 360,
                  child: PlaylistControlItem(
                    song: _song,
                    current: hover,
                    playing: false,
                    selected: false,
                    selectionMode: false,
                    variant: PlaylistControlItemVariant.compact,
                    compactDurationWidth: 20,
                    moreLabel: 'More',
                    onOpenContextMenu: _noopPosition,
                    onPlayTrack: _noop,
                    onTogglePlayPause: _noop,
                    onToggleSelection: _noop,
                    onPlayNextClick: _noop,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  if (hover) {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(PlaylistControlItem)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    addTearDown(mouse.removePointer);
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }

  await tester.runAsync(() async {
    final boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void _noop() {}

void _noopPosition(Offset position) {}

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'common.albumUnknown': 'Unknown Album',
    'common.artistSeparator': ' / ',
    'common.artistUnknown': 'Unknown Artist',
    'context.play': 'Play',
    'context.playNext': 'Play Next',
    'player.more': 'More',
    'player.pause': 'Pause',
  },
);

const _song = LibrarySong(
  id: 1,
  path: '/music/song.mp3',
  title: 'Acid Jazz 2',
  artist: 'Unknown Artist',
  artists: ['Unknown Artist'],
  album: 'Unknown Album',
  duration: 227,
  playCount: 0,
  lyricsOffsetMs: 0,
  dateAdded: '2026-05-25',
  favorite: false,
  thumbnailPath: '',
);
