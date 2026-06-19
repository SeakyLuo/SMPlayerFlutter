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
                  onOpenArtist: (_) {},
                  onOpenAlbum: (_) {},
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

  testWidgets('NowPlayingQueueView row artist and album open detail routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = ScrollController();
    addTearDown(controller.dispose);
    String? openedArtist;
    String? openedAlbum;

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
                onOpenArtist: (artist) {
                  openedArtist = artist;
                },
                onOpenAlbum: (album) {
                  openedAlbum = album;
                },
                onOpenContextMenu: (_, _, _) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Artist'));
    await tester.pump();
    expect(openedArtist, 'Artist');

    await tester.tap(
      find.byKey(const ValueKey('PlaylistControlItem.AlbumColumn')),
    );
    await tester.pump();
    expect(openedAlbum, 'Album');
  });

  testWidgets(
    'NowPlayingQueueView compact list clears player and moves scrollbar to edge',
    (tester) async {
      tester.view.physicalSize = const Size(360, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = ScrollController();
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
                width: 360,
                height: 260,
                child: NowPlayingQueueView(
                  queueSongs: const [_song, _summerSong, _currentSong],
                  visibleEntries: const [
                    (0, _song),
                    (1, _summerSong),
                    (2, _currentSong),
                  ],
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
                  onOpenArtist: (_) {},
                  onOpenAlbum: (_) {},
                  onOpenContextMenu: (_, _, _) {},
                  compactScrollbarTrailingOffset: 8,
                ),
              ),
            ),
          ),
        ),
      );

      final list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      expect(list.padding, const EdgeInsets.fromLTRB(0, 0, 0, 28));

      expect(tester.getRect(find.byType(ReorderableListView)).left, 0);
      expect(tester.getRect(find.byType(ReorderableListView)).right, 360);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('NowPlayingQueue.Scrollbar')))
            .right,
        368,
      );
      final scrollbarTheme = tester.widget<ScrollbarTheme>(
        find.ancestor(
          of: find.byKey(const ValueKey('NowPlayingQueue.Scrollbar')),
          matching: find.byType(ScrollbarTheme),
        ),
      );
      expect(scrollbarTheme.data.thickness!.resolve({}), 5);
      expect(scrollbarTheme.data.thickness!.resolve({WidgetState.hovered}), 7);
      expect(find.byType(Scrollbar), findsOneWidget);
    },
  );

  testWidgets(
    'NowPlayingQueueView compact hover actions hug row trailing edge',
    (tester) async {
      tester.view.physicalSize = const Size(360, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = ScrollController();
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
                width: 360,
                height: 260,
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
                  onOpenArtist: (_) {},
                  onOpenAlbum: (_) {},
                  onOpenContextMenu: (_, _, _) {},
                ),
              ),
            ),
          ),
        ),
      );

      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(
        location: tester.getCenter(find.byType(PlaylistControlItem)),
      );
      addTearDown(mouse.removePointer);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      final rowRect = tester.getRect(
        find.byKey(const ValueKey('PlaylistControlItem.Row')),
      );
      final actionsRect = tester.getRect(
        find.byKey(const ValueKey('PlaylistControlItem.Actions')),
      );
      expect(rowRect.right - actionsRect.right, 10);
    },
  );

  testWidgets('NowPlayingQueueView requires selected index and track id', (
    tester,
  ) async {
    final controller = ScrollController();
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
              height: 420,
              child: NowPlayingQueueView(
                queueSongs: const [_song, _summerSong, _currentSong],
                visibleEntries: const [
                  (0, _song),
                  (1, _summerSong),
                  (2, _currentSong),
                ],
                searchQuery: '',
                scrollController: controller,
                selectedQueueIndex: 1,
                selectedTrackId: _currentSong.id,
                isPlaying: true,
                selectionMode: false,
                isSelected: (_) => false,
                onReorderVisible: (_, _) {},
                onPlayQueueTrack: (_, _) {},
                onTogglePlayPause: () {},
                onToggleQueueSelection: (_) {},
                onToggleFavorite: (_) {},
                onOpenAddToPlaylist: (_, _) {},
                onRemoveQueueIndex: (_, _) {},
                onOpenArtist: (_) {},
                onOpenAlbum: (_) {},
                onOpenContextMenu: (_, _, _) {},
              ),
            ),
          ),
        ),
      ),
    );

    final items =
        tester
            .widgetList<PlaylistControlItem>(find.byType(PlaylistControlItem))
            .toList();
    expect(items, hasLength(3));
    expect(items[0].current, isFalse);
    expect(items[1].current, isFalse);
    expect(items[1].song.title, 'Take me to your summer');
    expect(items[2].current, isFalse);
    expect(items[2].playing, isFalse);
    expect(items[2].song.title, 'Meteor Ice Cream');
  });

  testWidgets('NowPlayingQueueView highlights only selected duplicate row', (
    tester,
  ) async {
    final controller = ScrollController();
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
              height: 420,
              child: NowPlayingQueueView(
                queueSongs: const [_currentSong, _summerSong, _currentSong],
                visibleEntries: const [
                  (0, _currentSong),
                  (1, _summerSong),
                  (2, _currentSong),
                ],
                searchQuery: '',
                scrollController: controller,
                selectedQueueIndex: 2,
                selectedTrackId: _currentSong.id,
                isPlaying: true,
                selectionMode: false,
                isSelected: (_) => false,
                onReorderVisible: (_, _) {},
                onPlayQueueTrack: (_, _) {},
                onTogglePlayPause: () {},
                onToggleQueueSelection: (_) {},
                onToggleFavorite: (_) {},
                onOpenAddToPlaylist: (_, _) {},
                onRemoveQueueIndex: (_, _) {},
                onOpenArtist: (_) {},
                onOpenAlbum: (_) {},
                onOpenContextMenu: (_, _, _) {},
              ),
            ),
          ),
        ),
      ),
    );

    final items =
        tester
            .widgetList<PlaylistControlItem>(find.byType(PlaylistControlItem))
            .toList();
    expect(items, hasLength(3));
    expect(items[0].current, isFalse);
    expect(items[1].current, isFalse);
    expect(items[2].current, isTrue);
    expect(items[2].playing, isTrue);
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

const _summerSong = LibrarySong(
  id: 2,
  path: '/music/summer.mp3',
  title: 'Take me to your summer',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 196,
  playCount: 0,
  lyricsOffsetMs: 0,
  dateAdded: '2026-06-13',
  favorite: false,
  thumbnailPath: '',
);

const _currentSong = LibrarySong(
  id: 3,
  path: '/music/meteor-ice-cream.mp3',
  title: 'Meteor Ice Cream',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 244,
  playCount: 0,
  lyricsOffsetMs: 0,
  dateAdded: '2026-06-13',
  favorite: false,
  thumbnailPath: '',
);
