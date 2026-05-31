import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  final width = double.parse(Platform.environment['ARTISTS_VERIFY_WIDTH']!);
  final height = double.parse(Platform.environment['ARTISTS_VERIFY_HEIGHT']!);
  final brightnessName = Platform.environment['ARTISTS_VERIFY_BRIGHTNESS']!;
  final navMinimal = Platform.environment['ARTISTS_VERIFY_NAV_MINIMAL'] == '1';
  final targetArtistName = Platform.environment['ARTISTS_VERIFY_TARGET_ARTIST'];
  final brightness =
      brightnessName == 'dark' ? Brightness.dark : Brightness.light;
  await windowManager.setTitle('SMPlayer Artists Verify');
  await windowManager.setSize(Size(width, height));
  await windowManager.center();
  await windowManager.show();
  runApp(
    _ArtistsVerifyApp(
      width: width,
      brightness: brightness,
      navMinimal: navMinimal,
      targetArtistName: targetArtistName,
    ),
  );
}

class _ArtistsVerifyApp extends StatefulWidget {
  const _ArtistsVerifyApp({
    required this.width,
    required this.brightness,
    required this.navMinimal,
    required this.targetArtistName,
  });

  final double width;
  final Brightness brightness;
  final bool navMinimal;
  final String? targetArtistName;

  @override
  State<_ArtistsVerifyApp> createState() => _ArtistsVerifyAppState();
}

class _ArtistsVerifyAppState extends State<_ArtistsVerifyApp> {
  final _boundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_captureAfterLayout());
    });
  }

  Future<void> _captureAfterLayout() async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final brightnessName =
        widget.brightness == Brightness.dark ? 'dark' : 'light';
    final navSuffix = widget.navMinimal ? '_nav_minimal' : '';
    final file = File(
      '${Directory.systemTemp.path}/flutter_artists_verify_${brightnessName}_${widget.width.round()}$navSuffix.png',
    );
    await file.writeAsBytes(data!.buffer.asUint8List());
    debugPrint('Artists verify screenshot: ${file.path}');
    await windowManager.destroy();
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final artistsPage = WorkspaceNavigationAppBarScope(
      active: widget.navMinimal,
      child: ArtistsPage(targetArtistName: widget.targetArtistName),
    );
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => _i18n),
        libraryContentDataProvider.overrideWith((ref) async => _snapshot),
      ],
      child: SmPlayerI18nScope(
        i18n: _i18n,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode:
              widget.brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
          home: Scaffold(
            backgroundColor: _shellBackground(widget.brightness),
            body: RepaintBoundary(
              key: _boundaryKey,
              child: ColoredBox(
                color: _shellBackground(widget.brightness),
                child:
                    widget.navMinimal
                        ? Column(
                          children: [
                            const _ArtistsVerifyAppBar(),
                            Expanded(child: artistsPage),
                          ],
                        )
                        : artistsPage,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtistsVerifyAppBar extends ConsumerWidget {
  const _ArtistsVerifyAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(workspaceAppBarPortalProvider);
    final brightness = Theme.of(context).brightness;
    final foreground =
        brightness == Brightness.dark
            ? const Color(0xfff6f9fc)
            : const Color(0xff111827);
    final background =
        brightness == Brightness.dark
            ? const Color(0xff0f1318)
            : const Color(0xfff8fbfe);
    final height = entry?.bottomContent == null ? 40.0 : 80.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        boxShadow:
            entry?.bottomContent == null
                ? null
                : [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: brightness == Brightness.dark ? 0.18 : 0.06,
                    ),
                    offset: const Offset(0, 8),
                    blurRadius: 18,
                  ),
                ],
      ),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.menu, size: 24, color: foreground),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(width: 40, height: 40, child: entry?.content),
                  ],
                ),
              ),
            ),
            if (entry?.bottomContent case final bottom?)
              SizedBox(height: 40, child: bottom),
          ],
        ),
      ),
    );
  }
}

Color _shellBackground(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xff0f1318)
      : const Color(0xfff8fbfe);
}

ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return ThemeData(
    brightness: brightness,
    extensions: [
      dark ? AppNotificationThemeColors.dark : AppNotificationThemeColors.light,
      dark
          ? DefaultAlbumArtworkThemeColors.dark
          : DefaultAlbumArtworkThemeColors.light,
    ],
  );
}

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'artists.albumSummary': '{songs} songs · {duration}',
    'artists.artistSummary': '{albums} albums · {songs} songs',
    'artists.emptyCopy': 'No artists yet.',
    'artists.locateArtist': 'Locate Artist',
    'artists.searchArtistsPlaceholder': 'Search artists',
    'artists.selectArtist': 'Select an artist',
    'albums.addSelectedTo': 'Add To',
    'albums.clearSelection': 'Clear Selection',
    'albums.playSelected': 'Play Selected',
    'albums.reverseSelection': 'Reverse Selection',
    'albums.selectAll': 'Select All',
    'albums.selectedCount': '{count} selected',
    'collection.artistNotFound': 'Artist not found',
    'collection.noArtists': 'No artists',
    'common.albumUnknown': 'Unknown Album',
    'common.artist': 'Artist',
    'common.artistSeparator': ' / ',
    'common.artists': 'Artists',
    'common.artistUnknown': 'Unknown Artist',
    'common.cancel': 'Cancel',
    'common.clear': 'Clear',
    'common.close': 'Close',
    'common.confirm': 'Confirm',
    'common.favorite': 'Favorite',
    'common.import': 'Import',
    'common.multiSelect': 'Multi Select',
    'common.myFavorites': 'My Favorites',
    'common.nowPlaying': 'Now Playing',
    'common.search': 'Search',
    'common.undo': 'Undo',
    'context.addToPlaylist': 'Add To',
    'context.deleteFromDisk': 'Delete From Disk',
    'context.deleteSongConfirm': 'Delete "{title}" from disk?',
    'context.pause': 'Pause',
    'context.play': 'Play',
    'context.playNext': 'Play Next',
    'context.seeAlbum': 'See Album',
    'context.seeAlbumArt': 'See Album Art',
    'context.seeArtist': 'See Artist',
    'context.seeLyrics': 'See Lyrics',
    'context.seeLocalFile': 'See In File Explorer',
    'context.seeMusicInfo': 'See Music Info',
    'context.select': 'Select',
    'context.view': 'View',
    'library.scanHelp': 'Scan music first.',
    'library.tryAnotherSearch': 'Try another search.',
    'notification.deletedFromDisk': 'Deleted {title} from disk',
    'notification.playNext': '"{title}" will play next',
    'notification.songAddedTo': 'Added "{title}" to {target}',
    'nowPlaying.loading': 'Loading',
    'nowPlaying.noLyrics': 'No Lyrics',
    'nowPlaying.randomPlay': 'Shuffle',
    'player.more': 'More',
    'player.pause': 'Pause',
    'playlists.create': 'Create',
    'playlists.createNew': 'Create New Playlist',
    'playlists.delete': 'Delete',
    'playlists.namePlaceholder': 'Playlist name',
    'playlists.newName': 'New Playlist',
    'playlists.newPlaylist': 'New Playlist',
    'preferences.level.dislike': 'Dislike',
    'preferences.level.do-not-appear': 'Do Not Appear',
    'preferences.level.high': 'High',
    'preferences.level.higher': 'Higher',
    'preferences.level.normal': 'Normal',
    'preferences.level.very-high': 'Very High',
    'preferences.undoPrefer': 'Undo Prefer',
    'quickJump.disabled': 'No {target} has {basis} starting with {group}',
    'quickJump.enabled': 'Jump to {target} whose {basis} starts with {group}',
    'quickJump.letterGroup': '{key}',
    'quickJump.symbolGroup': 'numbers, symbols, or other characters',
    'settings.preferenceSettings': 'Preference Settings',
    'settings.save': 'Save',
    'sidebar.back': 'Back',
    'sidebar.recentSearches': 'Recent searches',
    'sidebar.removeRecentSearch': 'Remove {query}',
    'song.changeArtwork': 'Change Artwork',
    'song.noAlbumArt': 'No Album Art',
  },
);

const _snapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\blue-1.mp3',
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
      id: 2,
      path: r'C:\Music\blue-2.mp3',
      title: 'Blue Song 2',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Blue Hour',
      duration: 180,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-21T00:00:00',
      favorite: true,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 3,
      path: r'C:\Music\green.mp3',
      title: 'Green Song',
      artist: 'Artist A; Artist B',
      artists: ['Artist A', 'Artist B'],
      album: 'Green Hour',
      duration: 210,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-22T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 4,
      path: r'C:\Music\unknown.mp3',
      title: 'Unknown Album Song',
      artist: '',
      artists: [],
      album: '',
      duration: 95,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-23T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
  ],
  recentSearches: [
    SearchHistoryEntry(
      id: 31,
      query: 'Artist A',
      type: SearchHistoryType.artists,
      searchedAt: '2026-05-21T00:00:00',
    ),
  ],
  playlists: [
    LibraryPlaylist(
      id: 3,
      name: 'Built in',
      priority: 0,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: true,
    ),
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
  nowPlaying: NowPlayingSnapshot(playlistId: 0, songIds: []),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  databasePath: '',
);
