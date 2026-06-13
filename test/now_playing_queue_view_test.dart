import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/playback/now_playing_queue_view.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';

void main() {
  testWidgets('NowPlayingQueueView wide rows keep Electron album column', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = ScrollController();
    final repaintKey = GlobalKey();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [DefaultAlbumArtworkThemeColors.light],
          ),
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 300,
              child: RepaintBoundary(
                key: repaintKey,
                child: NowPlayingQueueView(
                  queueSongs: const [_song],
                  visibleEntries: const [(0, _song)],
                  searchQuery: '',
                  scrollController: controller,
                  selectedQueueIndex: null,
                  selectedTrackId: _song.id,
                  isPlaying: false,
                  selectionMode: false,
                  isSelected: (_) => false,
                  onReorderVisible: (_, _) {},
                  onPlayQueueTrack: (_, _) {},
                  onTogglePlayPause: () {},
                  onToggleQueueSelection: (_) {},
                  onToggleFavorite: (_) {},
                  onOpenAddToPlaylist: (_, _) {},
                  onRemoveQueueIndex: (_, _) {},
                  onOpenContextMenu: (_, _, _) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final item = tester.widget<PlaylistControlItem>(
      find.byType(PlaylistControlItem),
    );
    expect(item.showAlbum, isTrue);
    expect(
      find.byKey(const ValueKey('PlaylistControlItem.AlbumColumn')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('PlaylistControlItem.InlineAlbum')),
      findsNothing,
    );

    await tester.runAsync(() async {
      final boundary =
          repaintKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File(
        '/tmp/smplayer_now_playing_queue_wide_album_column_verify.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
  });
}

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'common.albumUnknown': 'Unknown Album',
    'common.artistSeparator': ' / ',
    'common.artistUnknown': 'Unknown Artist',
    'context.addToPlaylist': 'Add To',
    'nowPlaying.noQueueMatch': 'No queue match',
    'nowPlaying.queueSearchHelp': 'Search help',
    'nowPlaying.remove': 'Remove',
    'player.more': 'More',
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
  dateAdded: '2026-06-13',
  favorite: false,
  thumbnailPath: '',
);
