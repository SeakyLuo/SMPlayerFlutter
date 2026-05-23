import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/app/window_drag_provider.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/album_detail_page.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_app_bar_portal.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_control.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';

void main() {
  setUp(PageSelectionController.clearStoredStates);

  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'albums.clearSelection': 'Clear Selection',
      'albums.editArtwork': 'Edit Artwork',
      'albums.multiSelect': 'Multi Select',
      'albums.playSelected': 'Play Selected',
      'albums.reverseSelection': 'Reverse Selection',
      'albums.selectAll': 'Select All',
      'albums.selectedCount': '{count} selected',
      'albums.sort.reverse': 'Reverse',
      'collection.albumNotFound': 'Album Not Found',
      'collection.albumNotFoundCopy':
          'Try selecting another album from your library.',
      'common.album': 'Album',
      'common.albumUnknown': 'Unknown Album',
      'common.artist': 'Artist',
      'common.artistUnknown': 'Unknown Artist',
      'common.artistSeparator': ' / ',
      'common.cancel': 'Cancel',
      'common.clear': 'Clear',
      'common.close': 'Close',
      'common.duration': 'Duration',
      'common.favorite': 'Favorite',
      'common.myFavorites': 'My Favorites',
      'common.name': 'Name',
      'common.nowPlaying': 'Now Playing',
      'common.reset': 'Reset',
      'common.sort': 'Sort',
      'common.yes': 'Yes',
      'context.addToPlaylist': 'Add To',
      'context.play': 'Play',
      'context.playNext': 'Play Next',
      'context.removeFromList': 'Remove From List',
      'headeredPlaylist.songArtist': 'Song/Artist',
      'headeredPlaylist.songsPrefix': 'Songs: ',
      'nowPlaying.randomPlay': 'Shuffle',
      'player.more': 'More',
      'playlists.delete': 'Delete',
      'playlists.newPlaylist': 'New Playlist',
      'playlists.removeSelected': 'Remove Selected',
      'playlists.rename': 'Rename',
      'playlists.save': 'Save',
      'preferences.level.dislike': 'Dislike',
      'preferences.level.do-not-appear': 'Do Not Appear',
      'preferences.level.high': 'High',
      'preferences.level.higher': 'Higher',
      'preferences.level.normal': 'Normal',
      'preferences.level.very-high': 'Very High',
      'preferences.undoPrefer': 'Undo Prefer',
      'settings.preferenceSettings': 'Preference Settings',
      'settings.save': 'Save',
      'song.albumArt': 'Album Art',
      'song.albumArtDeleted': 'Album art deleted',
      'song.albumArtReset': 'Album art has been reset.',
      'song.albumArtSaved': 'New album art has been saved!',
      'song.changeArtwork': 'Change',
      'song.noAlbumArt': 'No Album Art',
      'song.processingRequest': 'Your previous request is still processing.',
      'song.removeAlbumArt': 'Remove album art from "{title}"?',
      'song.updateFailed': 'Update failed.',
      'table.album': 'Album',
      'table.artist': 'Artist',
      'table.dateAdded': 'Date Added',
      'table.duration': 'Duration',
      'table.playCount': 'Play Count',
      'table.title': 'Title',
    },
  );

  testWidgets('AlbumDetailPage Add To matches Electron targets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _AlbumDetailTestApp(repository: repository, i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsNothing);
    expect(find.text('Preference Settings'), findsOneWidget);
    expect(find.text('Edit Artwork'), findsOneWidget);
    await tester.tap(find.byTooltip('Add To'));
    await tester.pumpAndSettle();

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('My Favorites'), findsOneWidget);
    expect(find.text('New Playlist'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);

    await tester.tap(find.text('Now Playing'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [9, 1]);

    await tester.tap(find.byTooltip('Add To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Favorites'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.favoriteValue, isTrue);

    await tester.pump(undoableNotificationDuration);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'AlbumDetailPage wires Electron preference and artwork commands',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _FakeLibraryRepository();

      await tester.pumpWidget(
        _AlbumDetailTestApp(repository: repository, i18n: i18n),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preference Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Do Not Appear'), findsOneWidget);
      expect(find.text('Dislike'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Higher'), findsOneWidget);
      expect(find.text('Very High'), findsOneWidget);

      await tester.tap(find.text('High'));
      await tester.pump();

      expect(repository.preferenceType, 'album');
      expect(repository.preferenceItemId, 'Blue Hour');
      expect(repository.preferenceName, 'Blue Hour - Artist A');
      expect(repository.preferenceLevel, 'high');

      await tester.tap(find.text('Edit Artwork'));
      await tester.pumpAndSettle();

      expect(find.text('Album Art'), findsWidgets);
      expect(find.text('Change'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('No Album Art'), findsOneWidget);
    },
  );

  testWidgets('AlbumDetailPage matches Electron headered playlist metrics', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_AlbumDetailTestApp(i18n: i18n));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(HeaderedPlaylistCover)),
      const Size(240, 240),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('HeaderedPlaylist.ListHeader'))),
      const Size(1100, 42),
    );
    expect(tester.getSize(find.text('Duration')).width, greaterThan(50));
    final firstRow = find.byKey(const ValueKey('HeaderedPlaylist.Row.1'));
    expect(tester.getSize(firstRow), const Size(1100, 88));
    expect(
      tester.getRect(find.text('Blue Song')).left -
          tester.getRect(firstRow).left,
      92,
    );
    expect(
      tester.widget<PlaylistControlItem>(firstRow).variant,
      PlaylistControlItemVariant.headeredPlaylist,
    );

    final title = tester.widget<Text>(find.text('Blue Hour'));
    expect(title.style?.fontSize, 48);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(title.style?.fontVariations, const [FontVariation.weight(650)]);

    expect(
      tester.getRect(find.text('Edit Artwork')).right,
      lessThanOrEqualTo(1200),
    );
  });

  testWidgets('AlbumDetailPage matches compact Electron headered playlist', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 360);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_AlbumDetailTestApp(i18n: i18n));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('HeaderedPlaylist.ListHeader')),
      findsNothing,
    );
    expect(
      tester.getSize(find.byType(HeaderedPlaylistCover)),
      const Size(180, 180),
    );
    final firstRow = find.byKey(const ValueKey('HeaderedPlaylist.Row.1'));
    expect(tester.getSize(firstRow), const Size(696, 86));
    expect(
      tester.getRect(find.text('Blue Song')).left -
          tester.getRect(firstRow).left,
      80,
    );

    final title = tester.widget<Text>(find.text('Blue Hour'));
    expect(title.style?.fontSize, 24);
    expect(title.style?.fontWeight, FontWeight.w800);
    expect(title.style?.fontVariations, const [FontVariation.weight(800)]);
  });

  testWidgets('HeaderedPlaylistControl reuses Electron metrics for playlists', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _HeaderedPlaylistTestApp(
        i18n: i18n,
        type: HeaderedPlaylistType.playlist,
        title: 'Mix',
        removable: true,
        canRename: true,
        canDelete: true,
        canClear: true,
        showAlbum: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(HeaderedPlaylistCover)),
      const Size(240, 240),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('HeaderedPlaylist.ListHeader'))),
      const Size(1100, 42),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('HeaderedPlaylist.Row.1'))),
      const Size(1100, 88),
    );
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Clear', skipOffstage: false), findsWidgets);
    final commandBar = find.byKey(
      const ValueKey('HeaderedPlaylist.CommandBar'),
    );
    final commandClear = find.descendant(
      of: commandBar,
      matching: find.text('Clear'),
    );
    final commandDelete = find.descendant(
      of: commandBar,
      matching: find.text('Delete'),
    );
    expect(
      tester.getRect(commandClear).top,
      lessThanOrEqualTo(tester.getRect(commandDelete).top),
    );
  });

  testWidgets('HeaderedPlaylistControl reuses Electron metrics for favorites', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _HeaderedPlaylistTestApp(
        i18n: i18n,
        type: HeaderedPlaylistType.favorites,
        title: 'My Favorites',
        removable: true,
        canClear: true,
        showAlbum: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('HeaderedPlaylist.ListHeader')),
      findsNothing,
    );
    expect(
      tester.getSize(find.byType(HeaderedPlaylistCover)),
      const Size(180, 180),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('HeaderedPlaylist.Row.1'))),
      const Size(696, 86),
    );
    expect(find.text('My Favorites'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
  });

  testWidgets(
    'HeaderedPlaylistControl publishes collapsed compact appbar portal',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(700, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _HeaderedPlaylistTestApp(
          i18n: i18n,
          type: HeaderedPlaylistType.playlist,
          title: 'Mix',
          removable: true,
          canRename: true,
          canDelete: true,
          canClear: true,
          showAlbum: true,
          showPortalProbe: true,
          songCount: 12,
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const ValueKey('HeaderedPlaylist.ScrollView')),
        const Offset(0, -180),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('HeaderedPlaylist.CollapsedBar')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('HeaderedPlaylist.PortalProbe')),
        findsOneWidget,
      );
      expect(find.text('portal:Mix'), findsOneWidget);
    },
  );

  testWidgets(
    'HeaderedPlaylistControl header starts desktop drag outside buttons',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var dragStarts = 0;
      var dragEnds = 0;
      await tester.pumpWidget(
        _HeaderedPlaylistTestApp(
          i18n: i18n,
          type: HeaderedPlaylistType.playlist,
          title: 'Mix',
          showAlbum: true,
          onWindowDragStart: () {
            dragStarts += 1;
          },
          onWindowDragEnd: () {
            dragEnds += 1;
          },
        ),
      );
      await tester.pumpAndSettle();

      final titleGesture = await tester.startGesture(
        tester.getCenter(find.text('Mix')),
      );
      await tester.pump();
      await titleGesture.up();
      await tester.pump();

      expect(dragStarts, 1);
      expect(dragEnds, 1);

      final shuffleGesture = await tester.startGesture(
        tester.getCenter(find.text('Shuffle')),
      );
      await tester.pump();
      await shuffleGesture.up();
      await tester.pump();

      expect(dragStarts, 1);
      expect(dragEnds, 1);
    },
  );

  testWidgets(
    'HeaderedPlaylistControl keeps multi-select after operation when setting is off',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _HeaderedPlaylistTestApp(
          i18n: i18n,
          type: HeaderedPlaylistType.playlist,
          title: 'Mix',
          showAlbum: true,
          snapshot: _snapshotWithHideAfterOperation(false),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Multi Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue Song'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Play Selected'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Play Selected'), findsOneWidget);
    },
  );

  testWidgets(
    'HeaderedPlaylistControl hides multi-select after operation when setting is on',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _HeaderedPlaylistTestApp(
          i18n: i18n,
          type: HeaderedPlaylistType.playlist,
          title: 'Mix',
          showAlbum: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Multi Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue Song'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Play Selected'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsNothing);
      expect(find.text('Play Selected'), findsNothing);
    },
  );

  testWidgets(
    'HeaderedPlaylistControl filters stored selected IDs by visible queue',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final storedSelection = PageSelectionController<int>.stored(
        'headered-playlist:playlist:Mix',
      );
      storedSelection.selectAll([1, 999]);

      List<int>? playedSongIds;
      await tester.pumpWidget(
        _HeaderedPlaylistTestApp(
          i18n: i18n,
          type: HeaderedPlaylistType.playlist,
          title: 'Mix',
          showAlbum: true,
          onPlayTrack: (_, songIds) {
            playedSongIds = songIds;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Play Selected'));
      await tester.pumpAndSettle();

      expect(playedSongIds, [1]);
    },
  );

  testWidgets('AlbumDetailPage shows Electron current preference state', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository =
        _FakeLibraryRepository()..existingPreferenceLevel = 'high';

    await tester.pumpWidget(
      _AlbumDetailTestApp(repository: repository, i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Preference Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Undo Prefer'), findsOneWidget);

    await tester.tap(find.text('Undo Prefer'));
    await tester.pump();

    expect(repository.removedPreferenceType, 'album');
    expect(repository.removedPreferenceItemId, 'Blue Hour');
  });

  testWidgets('AlbumDetailPage pins collapsed Electron headered hero', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 360);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _AlbumDetailTestApp(i18n: i18n, snapshot: _longAlbumSnapshot),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('HeaderedPlaylist.CollapsedBar')),
      findsNothing,
    );

    await tester.dragFrom(const Offset(600, 340), const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('HeaderedPlaylist.CollapsedBar')),
      findsNothing,
    );
    expect(
      tester.getSize(find.byType(HeaderedPlaylistCover)),
      const Size(86, 86),
    );
    final collapsedTitle = tester.widget<Text>(find.text('Blue Hour'));
    expect(collapsedTitle.style?.fontSize, 26);
    expect(collapsedTitle.style?.fontWeight, FontWeight.w600);
    expect(collapsedTitle.style?.fontVariations, const [
      FontVariation.weight(650),
    ]);

    await tester.dragFrom(const Offset(600, 340), const Offset(0, 60));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('HeaderedPlaylist.CollapsedBar')),
      findsNothing,
    );
    expect(tester.getSize(find.byType(HeaderedPlaylistCover)).width, 86);

    await tester.dragFrom(const Offset(600, 340), const Offset(0, 80));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('HeaderedPlaylist.CollapsedBar')),
      findsNothing,
    );
    expect(
      tester.getSize(find.byType(HeaderedPlaylistCover)).width,
      greaterThan(86),
    );
  });

  testWidgets('AlbumDetailPage records play only for Electron shuffle', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _AlbumDetailTestApp(repository: repository, i18n: i18n),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Song'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [1]);
    expect(repository.recordedAlbums, isEmpty);

    await tester.tap(find.text('Shuffle'));
    await tester.pumpAndSettle();

    expect(repository.recordedAlbums, ['Blue Hour']);
  });

  testWidgets('AlbumDetailPage renders Electron not found state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _AlbumDetailTestApp(albumName: 'Missing', i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Album Not Found'), findsOneWidget);
    expect(find.textContaining('Try selecting another album'), findsOneWidget);
  });

  testWidgets('AlbumDetailPage matches Electron raw album route', (
    tester,
  ) async {
    await tester.pumpWidget(
      _AlbumDetailTestApp(albumName: i18n.t('common.albumUnknown'), i18n: i18n),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unknown Album Song'), findsNothing);
    expect(find.textContaining('Album Not Found'), findsOneWidget);
  });
}

class _AlbumDetailTestApp extends StatelessWidget {
  const _AlbumDetailTestApp({
    required this.i18n,
    this.repository,
    this.albumName = 'Blue Hour',
    this.snapshot = _snapshot,
  });

  final SmPlayerI18n i18n;
  final LibraryRepository? repository;
  final String albumName;
  final LibraryViewData snapshot;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryViewDataProvider.overrideWith((ref) async => snapshot),
        if (repository != null)
          libraryRepositoryProvider.overrideWithValue(repository!),
      ],
      child: MaterialApp(
        home: Scaffold(body: AlbumDetailPage(albumName: albumName)),
      ),
    );
  }
}

class _HeaderedPlaylistTestApp extends StatelessWidget {
  const _HeaderedPlaylistTestApp({
    required this.i18n,
    required this.type,
    required this.title,
    this.removable = false,
    this.showAlbum = false,
    this.canRename = false,
    this.canDelete = false,
    this.canClear = false,
    this.showPortalProbe = false,
    this.songCount = 2,
    this.snapshot = _snapshot,
    this.onWindowDragStart,
    this.onWindowDragEnd,
    this.onPlayTrack,
  });

  final SmPlayerI18n i18n;
  final HeaderedPlaylistType type;
  final String title;
  final bool removable;
  final bool showAlbum;
  final bool canRename;
  final bool canDelete;
  final bool canClear;
  final bool showPortalProbe;
  final int songCount;
  final LibraryViewData snapshot;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;
  final HeaderedPlaylistTrackHandler? onPlayTrack;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryViewDataProvider.overrideWith((ref) async => snapshot),
        libraryRepositoryProvider.overrideWithValue(_FakeLibraryRepository()),
        if (onWindowDragStart != null && onWindowDragEnd != null)
          smPlayerWindowDragProvider.overrideWithValue(
            SmPlayerWindowDragCallbacks(
              onStart: onWindowDragStart!,
              onEnd: onWindowDragEnd!,
            ),
          ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SmPlayerI18nScope(
            i18n: i18n,
            child: Stack(
              children: [
                HeaderedPlaylistControl(
                  type: type,
                  title: title,
                  songs: _headeredPlaylistSongs(songCount),
                  selectedTrackId: null,
                  playlists: snapshot.playlists,
                  favoritePlaylistId: snapshot.favoritePlaylistId,
                  artworkUrl: '',
                  removable: removable,
                  showAlbum: showAlbum,
                  canRename: canRename,
                  canDelete: canDelete,
                  canClear: canClear,
                  onPlayTrack: onPlayTrack ?? (_, _) {},
                  onAddSongToPlaylist: (_, _) {},
                  onRemoveSongs: (_) {},
                  onRename: (_) {},
                  onDelete: () {},
                  onClear: () {},
                  onPlayNext: (_) {},
                ),
                if (showPortalProbe)
                  Consumer(
                    builder: (context, ref, _) {
                      final entry = ref.watch(
                        headeredPlaylistAppBarPortalProvider,
                      );
                      if (entry == null) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        'portal:${entry.title}',
                        key: const ValueKey('HeaderedPlaylist.PortalProbe'),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<LibrarySong> _headeredPlaylistSongs(int count) {
  if (count <= 2) {
    return _snapshot.songs.take(count).toList();
  }
  return [
    ..._snapshot.songs.take(2),
    for (var index = 2; index < count; index += 1)
      LibrarySong(
        id: index + 100,
        path: 'C:\\Music\\song-$index.mp3',
        title: 'Song $index',
        artist: 'Artist $index',
        artists: ['Artist $index'],
        album: 'Album $index',
        duration: 120,
        playCount: 0,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-20T00:00:00',
        favorite: false,
        thumbnailPath: '',
      ),
  ];
}

class _FakeLibraryRepository extends LibraryRepository {
  List<int> replacedNowPlaying = [];
  List<int> favoriteSongIds = [];
  List<String> recordedAlbums = [];
  bool? favoriteValue;
  String? preferenceType;
  String? preferenceItemId;
  String? preferenceName;
  String? preferenceLevel;
  String? existingPreferenceLevel;
  String? removedPreferenceType;
  String? removedPreferenceItemId;

  @override
  Future<void> replaceNowPlaying(List<int> songIds) async {
    replacedNowPlaying = songIds.toList();
  }

  @override
  Future<void> setSongsFavorite(List<int> songIds, bool favorite) async {
    favoriteSongIds = songIds.toList();
    favoriteValue = favorite;
  }

  @override
  Future<void> recordAlbumPlayed(String albumName) async {
    recordedAlbums.add(albumName);
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

const _snapshot = LibraryViewData(
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
      id: 9,
      path: r'C:\Music\queued.mp3',
      title: 'Queued Song',
      artist: 'Artist Q',
      artists: ['Artist Q'],
      album: 'Queue',
      duration: 90,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 11,
      path: r'C:\Music\unknown.mp3',
      title: 'Unknown Album Song',
      artist: 'Artist U',
      artists: ['Artist U'],
      album: '',
      duration: 90,
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
  playlists: [
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
  favoritePlaylistId: 3,
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: [9]),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

final _longAlbumSnapshot = LibraryViewData(
  songs: [
    ..._snapshot.songs,
    for (var index = 0; index < 16; index += 1)
      LibrarySong(
        id: 100 + index,
        path: r'C:\Music\blue-extra.mp3',
        title: 'Blue Extra $index',
        artist: 'Artist A',
        artists: const ['Artist A'],
        album: 'Blue Hour',
        duration: 120,
        playCount: 0,
        lyricsOffsetMs: 0,
        dateAdded: '2026-05-20T00:00:00',
        favorite: false,
        thumbnailPath: '',
      ),
  ],
  recentSongs: const [],
  recentPlaylists: const [],
  recentAlbums: const [],
  recentArtists: const [],
  recentSearches: const [],
  playlists: _snapshot.playlists,
  favoritePlaylistId: _snapshot.favoritePlaylistId,
  nowPlaying: _snapshot.nowPlaying,
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);

LibraryViewData _snapshotWithHideAfterOperation(bool value) {
  return LibraryViewData(
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
    hideMultiSelectCommandBarAfterOperation: value,
    localViewMode: _snapshot.localViewMode,
    rootPath: _snapshot.rootPath,
    databasePath: _snapshot.databasePath,
  );
}
