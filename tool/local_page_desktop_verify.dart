import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/shell_page.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_card.dart';
import 'package:smplayer_flutter/src/library/ui/local_page.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LyricsRequestMode, SettingsSnapshot;
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  resetSmPlayerGlobalSettingsSnapshot();
  await windowManager.ensureInitialized();

  final width = double.parse(
    Platform.environment['LOCAL_VERIFY_WIDTH'] ?? '1280',
  );
  final height = double.parse(
    Platform.environment['LOCAL_VERIFY_HEIGHT'] ?? '820',
  );
  final brightness =
      Platform.environment['LOCAL_VERIFY_BRIGHTNESS'] == 'dark'
          ? Brightness.dark
          : Brightness.light;
  await windowManager.setTitle('SMPlayer Local Verify');
  await windowManager.setSize(Size(width, height));
  await windowManager.center();
  await windowManager.show();

  runApp(_LocalVerifyApp(width: width, height: height, brightness: brightness));
}

class _LocalVerifyApp extends StatefulWidget {
  const _LocalVerifyApp({
    required this.width,
    required this.height,
    required this.brightness,
  });

  final double width;
  final double height;
  final Brightness brightness;

  @override
  State<_LocalVerifyApp> createState() => _LocalVerifyAppState();
}

class _LocalVerifyAppState extends State<_LocalVerifyApp> {
  final _boundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_captureAfterLayout());
    });
  }

  Future<void> _captureAfterLayout() async {
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    await _applyRequestedHover();
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final output = File(
      _resolveOutputPath(
        Platform.environment['LOCAL_VERIFY_OUTPUT'] ??
            'build/smplayer_flutter_desktop_local_page_archive_${widget.width.round()}x${widget.height.round()}_verify.png',
      ),
    );
    await output.parent.create(recursive: true);
    await output.writeAsBytes(data!.buffer.asUint8List());
    debugPrint('Local verify screenshot: ${output.path}');
    final geometryOutput = File(
      _resolveOutputPath(
        Platform.environment['LOCAL_VERIFY_GEOMETRY_OUTPUT'] ??
            output.path.replaceAll(RegExp(r'\.png$'), '.geometry.json'),
      ),
    );
    await geometryOutput.parent.create(recursive: true);
    await geometryOutput.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_collectGeometry()),
    );
    debugPrint('Local verify geometry: ${geometryOutput.path}');
    await windowManager.destroy();
    exit(0);
  }

  Map<String, Object?> _collectGeometry() {
    final view = View.of(_boundaryKey.currentContext!);
    final commandBar = _firstElement((element) => element.widget is CommandBar);
    final firstFolderCard = _firstElement(
      (element) =>
          element.widget is LocalFolderCard &&
          (element.widget as LocalFolderCard).folder.name == 'Encore',
    );
    final firstSongCard =
        widget.width < 720
            ? _rawRectForElement(
              _firstElement(
                (element) =>
                    element.widget.key ==
                    const ValueKey('LocalCompactSongRow.2'),
              ),
            )
            : _ancestorRectForText(
              'Glass Horizon',
              (rect) =>
                  rect.width > 170 && rect.width < 190 && rect.height > 220,
            );
    final introText = _textRect('Intro Signal');
    final encoreText = _textRect('Encore');
    final toolbarSummaryText = _textRect('1 folder · 3 songs');
    final folderInfoText = _textRect('1 song');
    final glassHorizonText = _textRect('Glass Horizon');
    final noonSectionText = _textRect('Noon Section');
    final glassHorizonDurationText = _textRect('3:04');
    final folderActions = _elementByKey('LocalFolderCard.GridActions');
    final songActions = _elementByKey('LocalGridSong.Actions.2');
    final compactFolderActions = _elementByKey('LocalFolderCard.ListActions');
    final compactPlayNext = _elementByKey('PlaylistControlItem.PlayNextAction');
    final compactMore = _elementByKey('PlaylistControlItem.MoreAction');
    final hiddenFoldersButton = _elementByKey(
      'LocalTitleGrid.HiddenFoldersButton',
    );
    final folderChainDropdownButtons = _elementsByKeyPrefix(
      'FolderChain.Dropdown.',
    );
    final compactSongActionsRect = _unionRects([
      _rawRectForElement(compactPlayNext),
      _rawRectForElement(compactMore),
    ]);
    return {
      'viewport': {
        'width': widget.width,
        'height': widget.height,
        'devicePixelRatio': view.devicePixelRatio,
      },
      'appShell': _rectForElement(_boundaryKey.currentContext! as Element),
      'commandbar': _rectForElement(commandBar),
      'firstFolderCard': _rectForElement(firstFolderCard),
      'firstSongRowOrCard':
          firstSongCard == null ? null : _roundRect(firstSongCard),
      'folderHoverActions': _rectForElement(folderActions),
      'folderHoverActionsOpacity': _opacityForElement(folderActions),
      'songHoverActions': _rectForElement(songActions),
      'songHoverActionsOpacity': _opacityForElement(songActions),
      'compactFolderActions': _rectForElement(compactFolderActions),
      'compactFolderActionsOpacity': _opacityForElement(compactFolderActions),
      'compactSongActions':
          compactSongActionsRect == null
              ? null
              : _roundRect(compactSongActionsRect),
      'compactSongHoverActionsOpacity': _opacityForElement(compactPlayNext),
      'compactSongPlayNextAction': _rectForElement(compactPlayNext),
      'compactSongMoreAction': _rectForElement(compactMore),
      'toolbarSummaryText':
          toolbarSummaryText == null ? null : _roundRect(toolbarSummaryText),
      'encoreText': encoreText == null ? null : _roundRect(encoreText),
      'folderInfoText':
          folderInfoText == null ? null : _roundRect(folderInfoText),
      'glassHorizonText':
          glassHorizonText == null ? null : _roundRect(glassHorizonText),
      'noonSectionText':
          noonSectionText == null ? null : _roundRect(noonSectionText),
      'introText': introText == null ? null : _roundRect(introText),
      'glassHorizonDurationText':
          glassHorizonDurationText == null
              ? null
              : _roundRect(glassHorizonDurationText),
      'hiddenFoldersButton': _rectForElement(hiddenFoldersButton),
      'folderChainDropdownCount': folderChainDropdownButtons.length,
      'folderChainDropdownButtons':
          folderChainDropdownButtons.map(_rectForElement).toList(),
    };
  }

  Future<void> _applyRequestedHover() async {
    final target = Platform.environment['LOCAL_VERIFY_HOVER_TARGET'];
    if (target == null || target.isEmpty) {
      return;
    }
    final rect =
        switch (target) {
          'folder' => _rawRectForElement(
            _firstElement(
              (element) =>
                  element.widget is LocalFolderCard &&
                  (element.widget as LocalFolderCard).folder.name == 'Encore',
            ),
          ),
          'song' => _rawRectForElement(
            _ancestorForText(
              'Glass Horizon',
              (rect) =>
                  rect.width > 170 && rect.width < 190 && rect.height > 220,
            ),
          ),
          'compactFolder' => _rawRectForElement(
            _firstElement(
              (element) =>
                  element.widget is LocalFolderCard &&
                  (element.widget as LocalFolderCard).folder.name == 'Encore',
            ),
          ),
          'compactSong' => _rawRectForElement(
            _elementByKey('LocalCompactSongRow.2'),
          ),
          _ => throw StateError('Unknown LOCAL_VERIFY_HOVER_TARGET: $target'),
        }!;
    final position = rect.center;
    GestureBinding.instance.handlePointerEvent(
      const PointerAddedEvent(device: 81, kind: PointerDeviceKind.mouse),
    );
    GestureBinding.instance.handlePointerEvent(
      PointerHoverEvent(
        device: 81,
        kind: PointerDeviceKind.mouse,
        position: position,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Element? _firstElement(bool Function(Element element) test) {
    Element? match;
    void visit(Element element) {
      if (match != null) {
        return;
      }
      if (test(element)) {
        match = element;
        return;
      }
      element.visitChildren(visit);
    }

    _boundaryKey.currentContext?.visitChildElements(visit);
    return match;
  }

  Element? _elementByKey(String key) {
    return _firstElement((element) => element.widget.key == ValueKey(key));
  }

  List<Element> _elementsByKeyPrefix(String prefix) {
    final matches = <Element>[];
    void visit(Element element) {
      final key = element.widget.key;
      if (key is ValueKey<String> && key.value.startsWith(prefix)) {
        matches.add(element);
      }
      element.visitChildren(visit);
    }

    _boundaryKey.currentContext?.visitChildElements(visit);
    return matches;
  }

  Rect? _textRect(String text) {
    final element = _firstElement(
      (element) =>
          element.widget is Text && (element.widget as Text).data == text,
    );
    return _rawRectForElement(element);
  }

  Rect? _ancestorRectForText(String text, bool Function(Rect rect) test) {
    return _rawRectForElement(_ancestorForText(text, test));
  }

  Element? _ancestorForText(String text, bool Function(Rect rect) test) {
    final element = _firstElement(
      (element) =>
          element.widget is Text && (element.widget as Text).data == text,
    );
    Element? match;
    element?.visitAncestorElements((ancestor) {
      final rect = _rawRectForElement(ancestor);
      if (rect != null && test(rect)) {
        match = ancestor;
        return false;
      }
      return true;
    });
    return match;
  }

  Map<String, double>? _rectForElement(Element? element) {
    final rect = _rawRectForElement(element);
    return rect == null ? null : _roundRect(rect);
  }

  Rect? _rawRectForElement(Element? element) {
    final renderObject = element?.renderObject;
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  Rect? _unionRects(Iterable<Rect?> rects) {
    Rect? result;
    for (final rect in rects) {
      if (rect == null) {
        continue;
      }
      result = result == null ? rect : result.expandToInclude(rect);
    }
    return result;
  }

  double? _opacityForElement(Element? element) {
    if (element == null) {
      return null;
    }
    var opacity = 1.0;
    element.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;
      if (widget is AnimatedOpacity) {
        opacity *= widget.opacity;
      } else if (widget is Opacity) {
        opacity *= widget.opacity;
      }
      return true;
    });
    final widget = element.widget;
    if (widget is AnimatedOpacity) {
      opacity *= widget.opacity;
    } else if (widget is Opacity) {
      opacity *= widget.opacity;
    }
    return (opacity * 100).roundToDouble() / 100;
  }

  Map<String, double> _roundRect(Rect rect) {
    double round(double value) => (value * 100).roundToDouble() / 100;
    return {
      'left': round(rect.left),
      'top': round(rect.top),
      'width': round(rect.width),
      'height': round(rect.height),
      'right': round(rect.right),
      'bottom': round(rect.bottom),
    };
  }

  @override
  Widget build(BuildContext context) {
    const snapshot = _snapshot;
    const repository = _LocalVerifyRepository(snapshot);
    const routeLocation = '/local?path=Collections%2FLive%2FSessions%2FArchive';
    return ProviderScope(
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
            brightness: widget.brightness,
          ),
          home: RepaintBoundary(
            key: _boundaryKey,
            child: SmPlayerShellPage(
              appVersion: '0.0.0',
              currentPath: '/local',
              currentLocation: routeLocation,
              desktopFeatureService: const NoopDesktopFeatureService(),
              settingsRepository: repository,
              child: const LocalPage(
                currentRelativePath: 'Collections/Live/Sessions/Archive',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _resolveOutputPath(String path) {
  if (path.startsWith('/')) {
    return path;
  }
  return path;
}

class _LocalVerifyRepository extends LibraryRepository {
  const _LocalVerifyRepository(this.snapshot);

  final LibraryContentData snapshot;

  @override
  Future<void> initializeLibraryDatabase() async {}

  @override
  Future<LibraryContentData> getLibraryContentData() async {
    return snapshot;
  }

  @override
  Future<ShellNavigationData> getShellNavigationData() async {
    return ShellNavigationData(
      songs: snapshot.songs,
      playlists: snapshot.playlists,
      folders: snapshot.folders,
      recentSearches: snapshot.recentSearches,
      nowPlaying: snapshot.nowPlaying,
      rootPath: snapshot.rootPath,
    );
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
  Future<void> replaceNowPlaying(List<int> songIds) async {}

  @override
  Future<LyricsSnapshot> getSongLyrics(
    int songId, {
    LyricsRequestMode mode = LyricsRequestMode.auto,
  }) async {
    return const LyricsSnapshot(
      source: LyricsSource.none,
      isSynced: false,
      rawText: '',
      lines: [],
    );
  }

  @override
  Future<SongArtworkSnapshot> getSongArtworkSnapshot(int songId) async {
    return SongArtworkSnapshot(
      songId: songId,
      artworkUrl: '',
      sourceUrl: '',
      sourcePath: '',
      source: SongArtworkSource.none,
    );
  }

  @override
  Future<List<SongArtworkSnapshot>> getSongArtworkSnapshots(
    List<int> songIds,
  ) async {
    return [
      for (final songId in songIds.toSet())
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

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'app.shell': 'Simple Melody Player',
    'albums.multiSelect': 'Multi Select',
    'common.album': 'Album',
    'common.albumUnknown': 'Unknown Album',
    'common.artist': 'Artist',
    'common.artistSeparator': ', ',
    'common.artistUnknown': 'Unknown Artist',
    'common.albums': 'Albums',
    'common.artists': 'Artists',
    'common.folders': 'Folders',
    'common.local': 'Local',
    'common.myFavorites': 'My Favorites',
    'common.name': 'Name',
    'common.nowPlaying': 'Now Playing',
    'common.playlists': 'Playlists',
    'common.recent': 'Recent',
    'common.search': 'Search',
    'common.settings': 'Settings',
    'common.sort': 'Sort',
    'context.addFavorite': 'Add Favorite',
    'context.addToPlaylist': 'Add To',
    'context.deleteFromDisk': 'Delete From Disk',
    'context.pause': 'Pause',
    'context.play': 'Play',
    'context.playNext': 'Play Next',
    'context.removeFavorite': 'Remove Favorite',
    'hiddenFolders.empty': 'No hidden items.',
    'hiddenFolders.introduction':
        'Hidden items stay out of Local until resumed.',
    'hiddenFolders.resume': 'Resume',
    'library.chooseFolder': 'Choose Folder',
    'library.openingFolderPicker': 'Opening Folder Picker',
    'library.title': 'Music Library',
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
    'local.openLocalButtonTooltip': 'Open local',
    'local.searchFolderButtonTooltip': 'Search in folder',
    'local.sortByAlbum': 'Album',
    'local.sortByArtist': 'Artist',
    'local.sortByTitle': 'Title',
    'local.updateFolder': 'Refresh folder',
    'local.updateFolderShort': 'Refresh',
    'local.viewHiddenFolders': 'View Hidden Folders',
    'musicLibrary.titleHeader': 'Title',
    'nowPlaying.randomPlay': 'Shuffle',
    'player.more': 'More',
  },
);

const _snapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path:
          '/Users/luohaitian/Music/Collections/Live/Sessions/Archive/Intro.mp3',
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
      path:
          '/Users/luohaitian/Music/Collections/Live/Sessions/Archive/Glass Horizon.mp3',
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
      path:
          '/Users/luohaitian/Music/Collections/Live/Sessions/Archive/North Pier.mp3',
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
      path:
          '/Users/luohaitian/Music/Collections/Live/Sessions/Archive/Encore/Last Light.mp3',
      title: 'Last Light',
      artist: 'River North',
      artists: ['River North'],
      album: 'Encore',
      duration: 203,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-31T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
  ],
  playlists: [
    LibraryPlaylist(
      id: 9,
      name: 'Now Playing',
      priority: 0,
      songCount: 1,
      songIds: [9],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: true,
    ),
    LibraryPlaylist(
      id: 20,
      name: 'Favorites',
      priority: 1,
      songCount: 1,
      songIds: [2],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: true,
    ),
    LibraryPlaylist(
      id: 30,
      name: 'Road Tape',
      priority: 2,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
  ],
  folders: [
    LibraryFolder(
      id: 1,
      path: '/Users/luohaitian/Music/Collections',
      parentId: 0,
      criterion: 0,
    ),
    LibraryFolder(
      id: 2,
      path: '/Users/luohaitian/Music/Collections/Live',
      parentId: 1,
      criterion: 0,
    ),
    LibraryFolder(
      id: 3,
      path: '/Users/luohaitian/Music/Collections/Live/Sessions',
      parentId: 2,
      criterion: 0,
    ),
    LibraryFolder(
      id: 4,
      path: '/Users/luohaitian/Music/Collections/Live/Sessions/Archive',
      parentId: 3,
      criterion: 0,
    ),
    LibraryFolder(
      id: 5,
      path: '/Users/luohaitian/Music/Collections/Live/Sessions/Archive/Encore',
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
  rootPath: '/Users/luohaitian/Music',
  databasePath: '',
);
