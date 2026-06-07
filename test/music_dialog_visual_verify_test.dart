import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/album_artwork_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LyricsRequestMode, SettingsSnapshot;

void main() {
  setUpAll(() async {
    final fontData =
        await File(
          '/System/Library/Fonts/Supplemental/Arial.ttf',
        ).readAsBytes();
    final loader = FontLoader('MusicDialogVisualFont')..addFont(
      Future.value(ByteData.view(Uint8List.fromList(fontData).buffer)),
    );
    await loader.load();
  });

  testWidgets('writes MusicDialog runtime verification screenshots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _captureMusicDialog(
      tester,
      name: 'properties_light',
      initialMode: SongDialogMode.properties,
    );
    await _captureMusicDialog(
      tester,
      name: 'properties_dark',
      initialMode: SongDialogMode.properties,
      brightness: Brightness.dark,
    );
    await _captureMusicDialog(
      tester,
      name: 'lyrics_light',
      initialMode: SongDialogMode.lyrics,
    );
    await _captureMusicDialog(
      tester,
      name: 'lyrics_dark',
      initialMode: SongDialogMode.lyrics,
      brightness: Brightness.dark,
    );
    tester.view.physicalSize = const Size(640, 820);
    await _captureMusicDialog(
      tester,
      name: 'lyrics_mobile_light',
      initialMode: SongDialogMode.lyrics,
    );
    await _captureMusicDialog(
      tester,
      name: 'lyrics_mobile_dark',
      initialMode: SongDialogMode.lyrics,
      brightness: Brightness.dark,
    );
    tester.view.physicalSize = const Size(1200, 900);
    await _captureMusicDialog(
      tester,
      name: 'lyrics_dirty_timed_light',
      initialMode: SongDialogMode.lyrics,
      lyricsDirtyTimed: true,
    );
    await _captureMusicDialog(
      tester,
      name: 'lyrics_dirty_timed_dark',
      initialMode: SongDialogMode.lyrics,
      brightness: Brightness.dark,
      lyricsDirtyTimed: true,
    );
    tester.view.physicalSize = const Size(640, 820);
    await _captureMusicDialog(
      tester,
      name: 'lyrics_dirty_timed_mobile_light',
      initialMode: SongDialogMode.lyrics,
      lyricsDirtyTimed: true,
    );
    await _captureMusicDialog(
      tester,
      name: 'lyrics_dirty_timed_mobile_dark',
      initialMode: SongDialogMode.lyrics,
      brightness: Brightness.dark,
      lyricsDirtyTimed: true,
    );
    tester.view.physicalSize = const Size(1200, 900);
    await _captureMusicDialog(
      tester,
      name: 'lyrics_empty_light',
      initialMode: SongDialogMode.lyrics,
      lyricsEmpty: true,
    );
    await _captureMusicDialog(
      tester,
      name: 'lyrics_empty_dark',
      initialMode: SongDialogMode.lyrics,
      brightness: Brightness.dark,
      lyricsEmpty: true,
    );
    await _captureMusicDialog(
      tester,
      name: 'lyrics_loading_light',
      initialMode: SongDialogMode.lyrics,
      lyricsLoading: true,
    );
    await _captureMusicDialog(
      tester,
      name: 'lyrics_loading_dark',
      initialMode: SongDialogMode.lyrics,
      brightness: Brightness.dark,
      lyricsLoading: true,
    );
    await _captureMusicDialog(
      tester,
      name: 'lyrics_saving_light',
      initialMode: SongDialogMode.lyrics,
      lyricsSaving: true,
    );
    await _captureMusicDialog(
      tester,
      name: 'lyrics_saving_dark',
      initialMode: SongDialogMode.lyrics,
      brightness: Brightness.dark,
      lyricsSaving: true,
    );
    tester.view.physicalSize = const Size(640, 820);
    await _captureMusicDialog(
      tester,
      name: 'lyrics_saving_mobile_light',
      initialMode: SongDialogMode.lyrics,
      lyricsSaving: true,
    );
    await _captureMusicDialog(
      tester,
      name: 'lyrics_saving_mobile_dark',
      initialMode: SongDialogMode.lyrics,
      brightness: Brightness.dark,
      lyricsSaving: true,
    );
    tester.view.physicalSize = const Size(1200, 900);
    await _captureMusicDialog(
      tester,
      name: 'album_art_light',
      initialMode: SongDialogMode.albumArt,
    );
    await _captureMusicDialog(
      tester,
      name: 'album_art_source_menu_light',
      initialMode: SongDialogMode.albumArt,
      albumArtSourceMenu: true,
    );
    await _captureMusicDialog(
      tester,
      name: 'album_art_delete_confirm_light',
      initialMode: SongDialogMode.albumArt,
      albumArtDeleteConfirm: true,
    );
    await _captureMusicDialog(
      tester,
      name: 'album_art_recommendation_light',
      initialMode: SongDialogMode.albumArt,
      currentSongResolvesArtwork: false,
    );
    await _captureAlbumArtworkDialog(tester, name: 'album_artwork_light');
    await _captureAlbumArtworkDialog(
      tester,
      name: 'album_artwork_source_menu_light',
      sourceMenu: true,
    );
    await _captureAlbumArtworkDialog(
      tester,
      name: 'album_artwork_delete_confirm_light',
      deleteConfirm: true,
    );
    await _captureAlbumArtworkDialog(
      tester,
      name: 'album_artwork_dark',
      brightness: Brightness.dark,
    );
    tester.view.physicalSize = const Size(640, 820);
    await _captureAlbumArtworkDialog(
      tester,
      name: 'album_artwork_mobile_light',
    );
    tester.view.physicalSize = const Size(1200, 900);
    await _captureAlbumArtLibraryPickerDialog(
      tester,
      name: 'album_art_library_picker_light',
    );
    await _captureAlbumArtLibraryPickerDialog(
      tester,
      name: 'album_art_library_picker_dark',
      brightness: Brightness.dark,
    );
    await _captureAlbumArtLibraryPickerDialog(
      tester,
      name: 'album_art_library_picker_history_light',
      showSearchHistory: true,
    );
    await _captureAlbumArtLibraryPickerDialog(
      tester,
      name: 'album_art_library_picker_history_dark',
      brightness: Brightness.dark,
      showSearchHistory: true,
    );
    await _captureAlbumArtLibraryPickerDialog(
      tester,
      name: 'album_art_library_picker_empty_light',
      empty: true,
    );
    tester.view.physicalSize = const Size(640, 820);
    await _captureAlbumArtLibraryPickerDialog(
      tester,
      name: 'album_art_library_picker_empty_mobile_light',
      empty: true,
    );
    await _captureAlbumArtLibraryPickerDialog(
      tester,
      name: 'album_art_library_picker_mobile_light',
    );
    tester.view.physicalSize = const Size(1200, 900);
    await _captureLyricsDiscardConfirmDialog(
      tester,
      name: 'lyrics_discard_confirm_light',
    );
    await _captureLyricsDiscardConfirmDialog(
      tester,
      name: 'lyrics_discard_confirm_dark',
      brightness: Brightness.dark,
    );
    tester.view.physicalSize = const Size(640, 820);
    await _captureLyricsDiscardConfirmDialog(
      tester,
      name: 'lyrics_discard_confirm_mobile_light',
    );
    await _captureLyricsDiscardConfirmDialog(
      tester,
      name: 'lyrics_discard_confirm_mobile_dark',
      brightness: Brightness.dark,
    );
    tester.view.physicalSize = const Size(1200, 900);
  });
}

Future<void> _captureMusicDialog(
  WidgetTester tester, {
  required String name,
  required SongDialogMode initialMode,
  Brightness? brightness,
  bool lyricsLoading = false,
  bool lyricsEmpty = false,
  bool lyricsDirtyTimed = false,
  bool lyricsSaving = false,
  bool currentSongResolvesArtwork = true,
  bool albumArtDeleteConfirm = false,
  bool albumArtSourceMenu = false,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();

  final repaintKey = GlobalKey();
  final repo = _VisualMusicDialogRepo(
    lyricsLoading: lyricsLoading,
    lyricsEmpty: lyricsEmpty,
    saveSongLyricsCompleter: lyricsSaving ? Completer<void>() : null,
    currentSongResolvesArtwork: currentSongResolvesArtwork,
  );
  final theme = buildSmPlayerTheme(
    const SettingsSnapshot.defaults(),
    brightness: brightness,
  ).copyWith(
    textTheme: ThemeData(fontFamily: 'MusicDialogVisualFont').textTheme,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [libraryRepositoryProvider.overrideWithValue(repo)],
      child: SmPlayerI18nScope(
        i18n: _i18n,
        child: RepaintBoundary(
          key: repaintKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Scaffold(
              body: MusicDialog(
                song: _currentSong,
                initialMode: initialMode,
                currentTrackId: _currentSong.id,
                isPlaying: initialMode == SongDialogMode.properties,
                queueSongIds: const [_currentSongId, _matchSongId],
                onPlay: () {},
                onPlayTrack: (_, _) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  if (lyricsLoading) {
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('MusicDialog.SaveProgress')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('MusicDialog.LoadingSpinner')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  } else {
    await tester.pumpAndSettle();
  }
  if (lyricsDirtyTimed || lyricsSaving) {
    final lyricsField = find.byType(TextField).last;
    await tester.tap(lyricsField);
    await tester.pump();
    await tester.enterText(
      lyricsField,
      lyricsSaving
          ? '[00:01.00]First line saving\n[00:04.00]Second line'
          : '[00:01.00]First line edited\n[00:04.00]Second line',
    );
    await tester.pumpAndSettle();
    final editedField = tester.widget<TextField>(lyricsField);
    expect(
      editedField.controller?.text,
      lyricsSaving
          ? '[00:01.00]First line saving\n[00:04.00]Second line'
          : '[00:01.00]First line edited\n[00:04.00]Second line',
    );
    expect(
      find.byKey(const ValueKey('MusicDialog.LyricsTimestampToggle')),
      findsOneWidget,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }
  if (lyricsSaving) {
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('MusicDialog.SaveProgress')), findsOne);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).enabled,
      false,
    );
  }
  if (initialMode == SongDialogMode.albumArt) {
    if (currentSongResolvesArtwork) {
      await _waitForAlbumArtworkImage(tester, repo.artworkPath);
      if (albumArtSourceMenu) {
        await tester.tap(find.widgetWithText(TextButton, 'Change Artwork'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
          findsOneWidget,
        );
      } else if (albumArtDeleteConfirm) {
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('MusicDialog.ArtworkDeleteConfirm')),
          findsOneWidget,
        );
      }
    } else {
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendation')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.DefaultAlbumArtwork')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('MusicDialog.DefaultAlbumArtworkLogo')),
        findsNothing,
      );
    }
  }
  _logMusicDialogRects(tester, name);

  final path = '/tmp/smplayer_music_dialog_$name.png';
  await tester.runAsync(() async {
    final boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  });
  expect(File(path).existsSync(), isTrue);
}

Future<void> _captureAlbumArtworkDialog(
  WidgetTester tester, {
  required String name,
  Brightness? brightness,
  bool deleteConfirm = false,
  bool sourceMenu = false,
}) async {
  final repaintKey = GlobalKey();
  final repo = _VisualMusicDialogRepo();
  final theme = buildSmPlayerTheme(
    const SettingsSnapshot.defaults(),
    brightness: brightness,
  ).copyWith(
    textTheme: ThemeData(fontFamily: 'MusicDialogVisualFont').textTheme,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [libraryRepositoryProvider.overrideWithValue(repo)],
      child: SmPlayerI18nScope(
        i18n: _i18n,
        child: RepaintBoundary(
          key: repaintKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Scaffold(
              body: AlbumArtworkDialog(
                albumName: 'Album',
                artworkUrl: repo.artworkPath,
                songId: _currentSongId,
                onClose: () {},
                onSaved: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _waitForAlbumArtworkImage(tester, repo.artworkPath);
  if (sourceMenu) {
    await tester.tap(find.widgetWithText(TextButton, 'Change Artwork'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('MenuFlyout.GlassPanel')), findsOneWidget);
  } else if (deleteConfirm) {
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('MusicDialog.ArtworkDeleteConfirm')),
      findsOneWidget,
    );
  }
  _logMusicDialogRects(tester, name);

  final path = '/tmp/smplayer_music_dialog_$name.png';
  await tester.runAsync(() async {
    final boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  });
  expect(File(path).existsSync(), isTrue);
}

Future<void> _captureAlbumArtLibraryPickerDialog(
  WidgetTester tester, {
  required String name,
  Brightness? brightness,
  bool showSearchHistory = false,
  bool empty = false,
}) async {
  final repaintKey = GlobalKey();
  final repo = _VisualMusicDialogRepo(
    recentSearches:
        showSearchHistory
            ? const [
              SearchHistoryEntry(
                id: 7,
                query: 'History Query',
                type: SearchHistoryType.sidebar,
                searchedAt: '2026-06-05T00:00:00Z',
              ),
            ]
            : const [],
  );
  final theme = buildSmPlayerTheme(
    const SettingsSnapshot.defaults(),
    brightness: brightness,
  ).copyWith(
    textTheme: ThemeData(fontFamily: 'MusicDialogVisualFont').textTheme,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [libraryRepositoryProvider.overrideWithValue(repo)],
      child: SmPlayerI18nScope(
        i18n: _i18n,
        child: RepaintBoundary(
          key: repaintKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Scaffold(
              body: AlbumArtLibraryPickerDialog(
                albumName: 'Album',
                currentSong: _currentSong,
                songs:
                    empty
                        ? const [_currentSong]
                        : const [_currentSong, _matchSong],
                onApply: (_) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (showSearchHistory) {
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchHistoryPanel')),
      findsOneWidget,
    );
  }
  _logMusicDialogRects(tester, name);

  final path = '/tmp/smplayer_music_dialog_$name.png';
  await tester.runAsync(() async {
    final boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  });
  expect(File(path).existsSync(), isTrue);
}

Future<void> _captureLyricsDiscardConfirmDialog(
  WidgetTester tester, {
  required String name,
  Brightness? brightness,
}) async {
  final repaintKey = GlobalKey();
  final repo = _VisualMusicDialogRepo();
  final theme = buildSmPlayerTheme(
    const SettingsSnapshot.defaults(),
    brightness: brightness,
  ).copyWith(
    textTheme: ThemeData(fontFamily: 'MusicDialogVisualFont').textTheme,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [libraryRepositoryProvider.overrideWithValue(repo)],
      child: SmPlayerI18nScope(
        i18n: _i18n,
        child: RepaintBoundary(
          key: repaintKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Scaffold(
              body: MusicDialog(
                song: _currentSong,
                initialMode: SongDialogMode.lyrics,
                currentTrackId: _currentSong.id,
                isPlaying: false,
                queueSongIds: const [_currentSongId, _matchSongId],
                onPlay: () {},
                onPlayTrack: (_, _) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, 'Dirty lyrics');
  final closeButton = find.byKey(const ValueKey('popup-dialog-close-button'));
  if (closeButton.evaluate().isNotEmpty) {
    await tester.tap(closeButton);
  } else {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  }
  await tester.pumpAndSettle();
  expect(find.text('Discard unsaved lyrics changes?'), findsOneWidget);
  _logMusicDialogRects(tester, name);

  final path = '/tmp/smplayer_music_dialog_$name.png';
  await tester.runAsync(() async {
    final boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  });
  expect(File(path).existsSync(), isTrue);
}

void _logMusicDialogRects(WidgetTester tester, String name) {
  Map<String, num>? rectOf(Finder finder) {
    if (finder.evaluate().isEmpty) {
      return null;
    }
    final rect = tester.getRect(finder.first);
    return {
      'x': rect.left,
      'y': rect.top,
      'width': rect.width,
      'height': rect.height,
    };
  }

  final state = {
    'name': name,
    'dialog': rectOf(find.byKey(const ValueKey('popup-dialog-shell'))),
    'playButton': rectOf(find.widgetWithText(TextButton, 'Play')),
    'pauseButton': rectOf(find.widgetWithText(TextButton, 'Pause')),
    'searchButton': rectOf(find.widgetWithText(TextButton, 'Search')),
    'importButton': rectOf(find.widgetWithText(TextButton, 'Import')),
    'saveButton': rectOf(find.widgetWithText(TextButton, 'Save')),
    'resetButton': rectOf(find.widgetWithText(TextButton, 'Reset')),
    'moreButton': rectOf(
      find.byKey(const ValueKey('MusicDialog.CommandBar.MoreButton')),
    ),
    'lyricsTimestampToggle': rectOf(
      find.byKey(const ValueKey('MusicDialog.LyricsTimestampToggle')),
    ),
    'loadingSpinner': rectOf(
      find.byKey(const ValueKey('MusicDialog.LoadingSpinner')),
    ),
    'deleteButton': rectOf(find.widgetWithText(TextButton, 'Delete')),
    'changeArtworkButton': rectOf(
      find.widgetWithText(TextButton, 'Change Artwork'),
    ),
    'menuFlyoutPanel': rectOf(
      find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
    ),
    'menuFlyoutLocalItem': rectOf(find.text('Choose local file')),
    'menuFlyoutLibraryItem': rectOf(find.text('Choose from library')),
    'propertyList': rectOf(
      find.byKey(const ValueKey('MusicDialog.PropertyList')),
    ),
    'titleInput': rectOf(find.widgetWithText(TextField, 'Current Song')),
    'lyricsTextarea':
        name.startsWith('lyrics') ? rectOf(find.byType(TextField)) : null,
    'albumArtwork': rectOf(
      find.byKey(const ValueKey('MusicDialog.AlbumArtworkImageShell')),
    ),
    'albumArtDefaultArtwork': rectOf(
      find.byKey(const ValueKey('MusicDialog.DefaultAlbumArtwork')),
    ),
    'albumArtDefaultArtworkLogo': rectOf(
      find.byKey(const ValueKey('MusicDialog.DefaultAlbumArtworkLogo')),
    ),
    'albumArtRecommendation': rectOf(
      find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendation')),
    ),
    'albumArtRecommendationButton': rectOf(
      find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendationButton')),
    ),
    'albumArtRecommendationPreview': rectOf(
      find.byKey(const ValueKey('MusicDialog.AlbumArtRecommendationPreview')),
    ),
    'albumArtDeleteConfirm': rectOf(
      find.byKey(const ValueKey('MusicDialog.ArtworkDeleteConfirm')),
    ),
    'albumArtDeleteConfirmText': rectOf(
      find.byKey(const ValueKey('MusicDialog.ArtworkDeleteConfirmText')),
    ),
    'albumArtDeleteConfirmYes': rectOf(
      find.byKey(const ValueKey('MusicDialog.ArtworkDeleteConfirmYes')),
    ),
    'albumArtDeleteConfirmCancel': rectOf(
      find.byKey(const ValueKey('MusicDialog.ArtworkDeleteConfirmCancel')),
    ),
    'albumArtPickerBody': rectOf(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.Body')),
    ),
    'albumArtPickerNav': rectOf(find.byKey(const ValueKey('popup-dialog-nav'))),
    'albumArtPickerTitle': rectOf(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.Title')),
    ),
    'albumArtPickerSearchField': rectOf(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchField')),
    ),
    'albumArtPickerSearchInput': rectOf(
      find.descendant(
        of: find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchField')),
        matching: find.byType(TextField),
      ),
    ),
    'albumArtPickerListFrame': rectOf(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.ListFrame')),
    ),
    'albumArtPickerChoice': rectOf(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.Choice.2')),
    ),
    'albumArtPickerPreview': rectOf(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.Preview')),
    ),
    'albumArtPickerFooter': rectOf(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.Footer')),
    ),
    'albumArtPickerCancelButton': rectOf(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.CancelButton')),
    ),
    'albumArtPickerApplyButton': rectOf(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.ApplyButton')),
    ),
    'albumArtPickerSearchHistoryPanel': rectOf(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchHistoryPanel')),
    ),
    'albumArtPickerSearchHistoryItem': rectOf(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchHistoryItem.7')),
    ),
    'albumArtPickerSearchHistorySelect': rectOf(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchHistorySelect.7')),
    ),
    'albumArtPickerSearchHistoryRemove': rectOf(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchHistoryRemove.7')),
    ),
    'albumArtPickerMessage': rectOf(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.Message')),
    ),
    'albumArtPickerMessageText': rectOf(
      find.byKey(const ValueKey('AlbumArtLibraryPicker.MessageText')),
    ),
    'inputDialog': rectOf(
      find.byKey(const ValueKey('popup-input-dialog-surface')),
    ),
    'styles': {
      'titleInput': _textFieldStyleOf(tester, 'Current Song'),
      'disabledInput': _textFieldStyleOf(tester, 'MP3'),
      'lyricsTextarea':
          name.startsWith('lyrics') ? _firstTextFieldStyleOf(tester) : null,
      'albumArtworkImage': _decorationStyleOf(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('MusicDialog.AlbumArtworkImageShell')),
          matching: find.byType(DecoratedBox),
        ),
      ),
      'albumArtworkLoading': _decorationStyleOf(
        tester,
        find.byKey(const ValueKey('MusicDialog.AlbumArtworkLoadingOverlay')),
      ),
      'albumArtDeleteConfirm': _decorationStyleOf(
        tester,
        find.byKey(const ValueKey('MusicDialog.ArtworkDeleteConfirm')),
      ),
      'albumArtDeleteConfirmText': _textStyleOf(
        tester,
        find.byKey(const ValueKey('MusicDialog.ArtworkDeleteConfirmText')),
      ),
      'menuFlyoutPanel': _decorationStyleOf(
        tester,
        find.byKey(const ValueKey('MenuFlyout.GlassPanel')),
      ),
      'pickerSearchDecoration': _decorationStyleOf(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchField')),
          matching: find.byType(DecoratedBox),
        ),
      ),
      'pickerSearchInput': _textFieldStyleOfFinder(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchField')),
          matching: find.byType(TextField),
        ),
      ),
      'pickerChoiceArtwork': _decorationStyleOf(
        tester,
        find.byKey(const ValueKey('AlbumArtLibraryPicker.ChoiceArtwork.2')),
      ),
      'pickerChoiceSurface': _decorationStyleOf(
        tester,
        find.byKey(const ValueKey('AlbumArtLibraryPicker.ChoiceSurface.2')),
      ),
      'pickerChoiceTitle': _textStyleOf(
        tester,
        find.byKey(const ValueKey('AlbumArtLibraryPicker.ChoiceTitle.2')),
      ),
      'pickerPreviewArtwork': _decorationStyleOf(
        tester,
        find.byKey(const ValueKey('AlbumArtLibraryPicker.PreviewArtwork')),
      ),
      'pickerPreviewTitle': _textStyleOf(
        tester,
        find.byKey(const ValueKey('AlbumArtLibraryPicker.PreviewTitle')),
      ),
      'pickerMessage': _textStyleOf(
        tester,
        find.byKey(const ValueKey('AlbumArtLibraryPicker.MessageText')),
      ),
      'pickerSearchHistoryPanel': _decorationStyleOf(
        tester,
        find.byKey(const ValueKey('AlbumArtLibraryPicker.SearchHistoryPanel')),
      ),
      'inputDialog': _decorationStyleOf(
        tester,
        find.byKey(const ValueKey('popup-input-dialog-surface')),
      ),
    },
    'propertyRows': [
      for (final label in _propertyRowLabels)
        {
          'label': label,
          'rect': rectOf(
            find.byKey(ValueKey('MusicDialog.PropertyRow.$label')),
          ),
        },
    ],
  };
  // Printed output is part of the visual parity evidence for Electron-vs-Flutter
  // runtime geometry and is intentionally stable JSON.
  // ignore: avoid_print
  print('Flutter MusicDialog rects: ${jsonEncode(state)}');
}

Map<String, Object?>? _decorationStyleOf(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) {
    return null;
  }
  final widget = tester.widget(finder.first);
  final Decoration decoration;
  if (widget is DecoratedBox) {
    decoration = widget.decoration;
  } else if (widget is AnimatedContainer) {
    decoration = widget.decoration ?? const BoxDecoration();
  } else if (widget is Container) {
    decoration = widget.decoration ?? const BoxDecoration();
  } else {
    return {'type': widget.runtimeType.toString()};
  }
  if (decoration is! BoxDecoration) {
    return {'type': decoration.runtimeType.toString()};
  }
  return {
    'color': decoration.color?.toARGB32(),
    'borderRadius': _borderRadiusToJson(decoration.borderRadius),
    'border': _boxBorderToJson(decoration.border),
    'boxShadow': [
      for (final shadow in decoration.boxShadow ?? const <BoxShadow>[])
        {
          'color': shadow.color.toARGB32(),
          'blurRadius': shadow.blurRadius,
          'offsetX': shadow.offset.dx,
          'offsetY': shadow.offset.dy,
          'spreadRadius': shadow.spreadRadius,
        },
    ],
    'hasGradient': decoration.gradient != null,
  };
}

Map<String, Object?>? _boxBorderToJson(BoxBorder? value) {
  if (value == null) {
    return null;
  }
  if (value is! Border) {
    return {'type': value.runtimeType.toString()};
  }
  return {
    'topColor': value.top.color.toARGB32(),
    'topWidth': value.top.width,
    'rightColor': value.right.color.toARGB32(),
    'rightWidth': value.right.width,
    'bottomColor': value.bottom.color.toARGB32(),
    'bottomWidth': value.bottom.width,
    'leftColor': value.left.color.toARGB32(),
    'leftWidth': value.left.width,
  };
}

Map<String, Object?>? _borderRadiusToJson(BorderRadiusGeometry? value) {
  if (value == null) {
    return null;
  }
  final resolved = value.resolve(TextDirection.ltr);
  return {
    'topLeft': resolved.topLeft.x,
    'topRight': resolved.topRight.x,
    'bottomRight': resolved.bottomRight.x,
    'bottomLeft': resolved.bottomLeft.x,
  };
}

Map<String, Object?>? _firstTextFieldStyleOf(WidgetTester tester) {
  final finder = find.byType(TextField);
  if (finder.evaluate().isEmpty) {
    return null;
  }
  return _textFieldStyleFromWidget(tester.widget<TextField>(finder.first));
}

Map<String, Object?>? _textFieldStyleOfFinder(
  WidgetTester tester,
  Finder finder,
) {
  if (finder.evaluate().isEmpty) {
    return null;
  }
  return _textFieldStyleFromWidget(tester.widget<TextField>(finder.first));
}

Map<String, Object?>? _textStyleOf(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) {
    return null;
  }
  final textFinder =
      tester.widget(finder.first) is Text
          ? finder.first
          : find
              .descendant(of: finder.first, matching: find.byType(Text))
              .first;
  final text = tester.widget<Text>(textFinder);
  final style = text.style;
  return {
    'fontFamily': style?.fontFamily,
    'fontSize': style?.fontSize,
    'fontWeight': style?.fontWeight?.value,
    'height': style?.height,
    'color': style?.color?.toARGB32(),
    'maxLines': text.maxLines,
    'textAlign': text.textAlign?.name,
  };
}

Map<String, Object?>? _textFieldStyleOf(WidgetTester tester, String text) {
  final finder = find.widgetWithText(TextField, text);
  if (finder.evaluate().isEmpty) {
    return null;
  }

  return _textFieldStyleFromWidget(tester.widget<TextField>(finder.first));
}

Map<String, Object?> _textFieldStyleFromWidget(TextField field) {
  final style = field.style;
  final decoration = field.decoration;
  final fillColor = decoration?.fillColor;
  final contentPadding = decoration?.contentPadding;
  final constraints = decoration?.constraints;
  return {
    'enabled': field.enabled,
    'readOnly': field.readOnly,
    'minLines': field.minLines,
    'maxLines': field.maxLines,
    'expands': field.expands,
    'textAlignVertical': field.textAlignVertical?.y,
    'fontFamily': style?.fontFamily,
    'fontSize': style?.fontSize,
    'fontWeight': style?.fontWeight?.value,
    'height': style?.height,
    'color': style?.color?.toARGB32(),
    'fillColor': fillColor?.toARGB32(),
    'contentPadding': _edgeInsetsGeometryToJson(contentPadding),
    'minHeight': constraints?.minHeight,
    'maxHeight': constraints?.maxHeight,
  };
}

Map<String, double>? _edgeInsetsGeometryToJson(EdgeInsetsGeometry? value) {
  if (value == null) {
    return null;
  }
  final resolved = value.resolve(TextDirection.ltr);
  return {
    'left': resolved.left,
    'top': resolved.top,
    'right': resolved.right,
    'bottom': resolved.bottom,
  };
}

const _propertyRowLabels = [
  'Title',
  'Subtitle',
  'Artist',
  'Album',
  'Album Artist',
  'Play Count',
  'Publisher',
  'Track Number',
  'Year',
  'Bitrate',
  'Composers',
  'Date Created',
  'Date Modified',
  'Duration',
  'File Size',
  'File Type',
  'Genre',
  'local.path',
];

Future<void> _waitForAlbumArtworkImage(
  WidgetTester tester,
  String artworkPath,
) async {
  expect(File(artworkPath).existsSync(), isTrue);
  final shellFinder = find.byKey(
    const ValueKey('MusicDialog.AlbumArtworkImageShell'),
  );
  expect(shellFinder, findsOneWidget);

  final loadingFinder = find.byKey(
    const ValueKey('MusicDialog.AlbumArtworkLoadingOverlay'),
  );
  for (var attempt = 0; attempt < 20; attempt += 1) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 16));
    if (loadingFinder.evaluate().isEmpty) {
      return;
    }
  }
  expect(loadingFinder, findsNothing);
}

class _VisualMusicDialogRepo extends LibraryRepository {
  _VisualMusicDialogRepo({
    this.lyricsLoading = false,
    this.lyricsEmpty = false,
    this.saveSongLyricsCompleter,
    this.currentSongResolvesArtwork = true,
    this.recentSearches = const [],
  }) {
    artworkPath = File('assets/branding/app-icon.png').absolute.path;
  }

  late final String artworkPath;
  final bool lyricsLoading;
  final bool lyricsEmpty;
  final Completer<void>? saveSongLyricsCompleter;
  final bool currentSongResolvesArtwork;
  final List<SearchHistoryEntry> recentSearches;

  @override
  Future<LibraryContentData> getLibraryContentData() async {
    return LibraryContentData(
      songs: const [_currentSong, _matchSong],
      hasLibrary: true,
      sortCriterion: MusicLibrarySortCriterion.title,
      albumsSort: AlbumSortCriterion.defaultSort,
      databasePath: '',
      recentSearches: recentSearches,
    );
  }

  @override
  Future<SongPropertiesSnapshot> getSongProperties(int songId) async {
    return const SongPropertiesSnapshot(
      songId: _currentSongId,
      path: '/Users/me/Music/Current Song.mp3',
      title: 'Current Song',
      subtitle: 'Live session',
      artist: 'Artist, Guest',
      artists: ['Artist', 'Guest'],
      album: 'Album',
      albumArtist: 'Artist',
      publisher: 'SM Records',
      trackNumber: 3,
      year: 2026,
      genre: 'Pop, Rock',
      composers: 'Composer A, Composer B',
      duration: 245,
      bitrate: 320,
      fileSize: 7340032,
      dateCreated: '2026-06-01T08:00:00Z',
      dateModified: '2026-06-05T09:30:00Z',
      fileType: 'MP3',
      playCount: 12,
    );
  }

  @override
  Future<LyricsSnapshot> getSongLyrics(
    int songId, {
    LyricsRequestMode mode = LyricsRequestMode.auto,
  }) async {
    if (lyricsLoading) {
      return Completer<LyricsSnapshot>().future;
    }
    if (lyricsEmpty) {
      return const LyricsSnapshot(
        source: LyricsSource.none,
        isSynced: false,
        rawText: '',
        lines: [],
      );
    }
    return const LyricsSnapshot(
      source: LyricsSource.lrcFile,
      isSynced: true,
      rawText: '[00:01.00]First line\n[00:04.00]Second line',
      lines: [
        LyricsLine(id: 0, timestampMs: 1000, text: 'First line'),
        LyricsLine(id: 1, timestampMs: 4000, text: 'Second line'),
      ],
    );
  }

  @override
  Future<SongArtworkSnapshot> getSongArtworkSnapshot(int songId) async {
    return const SongArtworkSnapshot(
      songId: _currentSongId,
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
      for (final songId in songIds)
        SongArtworkSnapshot(
          songId: songId,
          artworkUrl:
              songId == _currentSongId && !currentSongResolvesArtwork
                  ? ''
                  : artworkPath,
          sourceUrl:
              songId == _currentSongId && !currentSongResolvesArtwork
                  ? ''
                  : artworkPath,
          sourcePath:
              songId == _currentSongId && !currentSongResolvesArtwork
                  ? ''
                  : artworkPath,
          source:
              songId == _currentSongId && !currentSongResolvesArtwork
                  ? SongArtworkSource.none
                  : SongArtworkSource.cached,
        ),
    ];
  }

  @override
  Future<void> updateSongProperties(
    int songId,
    SongPropertiesUpdate update,
  ) async {}

  @override
  Future<void> saveSongLyrics(int songId, String rawLyrics) async {
    final completer = saveSongLyricsCompleter;
    if (completer != null) {
      return completer.future;
    }
  }

  @override
  Future<void> saveSongArtwork(int songId, String sourcePath) async {}

  @override
  Future<void> deleteSongArtwork(int songId) async {}

  @override
  Future<void> saveAlbumArtwork(String albumName, String sourcePath) async {}

  @override
  Future<void> deleteAlbumArtwork(String albumName) async {}
}

const _currentSongId = 1;
const _matchSongId = 2;

const _currentSong = LibrarySong(
  id: _currentSongId,
  path: '/Users/me/Music/Current Song.mp3',
  title: 'Current Song',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 245,
  playCount: 12,
  lyricsOffsetMs: 0,
  dateAdded: '2026-06-01T00:00:00Z',
  favorite: false,
  thumbnailPath: '',
);

const _matchSong = LibrarySong(
  id: _matchSongId,
  path: '/Users/me/Music/Match Song.mp3',
  title: 'Match Song',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 180,
  playCount: 4,
  lyricsOffsetMs: 0,
  dateAdded: '2026-06-01T00:00:00Z',
  favorite: false,
  thumbnailPath: '',
);

const _i18n = SmPlayerI18n(
  locale: 'en-US',
  messages: {
    'common.add': 'Add',
    'common.album': 'Album',
    'common.artist': 'Artist',
    'common.artistSeparator': ' / ',
    'common.artistUnknown': 'Unknown Artist',
    'common.cancel': 'Cancel',
    'common.clear': 'Clear',
    'common.close': 'Close',
    'common.comma': ', ',
    'common.confirm': 'Confirm',
    'common.duration': 'Duration',
    'common.import': 'Import',
    'common.playCount': 'Play Count',
    'common.reset': 'Reset',
    'common.search': 'Search',
    'common.yes': 'Yes',
    'context.pause': 'Pause',
    'context.play': 'Play',
    'context.seeAlbumArt': 'Album Art',
    'context.seeLyrics': 'Lyrics',
    'context.seeMusicInfo': 'Music Info',
    'lyrics.title': 'Lyrics',
    'nowPlaying.loading': 'Loading',
    'nowPlaying.noLyrics': 'No lyrics found',
    'playlists.delete': 'Delete',
    'playlists.removeSelected': 'Remove',
    'settings.save': 'Save',
    'song.albumArtist': 'Album Artist',
    'song.albumArt': 'Album Art',
    'song.albumArtDeleted': 'Album art deleted',
    'song.albumArtRecommendationPrefix': 'Smart match: use {artist}\'s ',
    'song.albumArtRecommendationSuffix': ' as the cover',
    'song.albumArtRecommendationTitle': '"{title}"',
    'song.albumArtUpdated': 'Album art updated',
    'song.bitrate': 'Bitrate',
    'song.changeArtwork': 'Change Artwork',
    'song.chooseArtworkFromLibrary': 'Choose from library',
    'song.chooseArtworkFromLocal': 'Choose local file',
    'song.clearPlayCount': 'Clear',
    'song.hasBeenPlayed': '"{title}" has been played {count} times.',
    'song.resetPlayCountToZero': 'Reset to 0',
    'song.composers': 'Composers',
    'song.dateCreated': 'Date Created',
    'song.dateModified': 'Date Modified',
    'song.discardLyricsConfirm': 'Discard unsaved lyrics changes?',
    'song.fileSize': 'File Size',
    'song.fileType': 'File Type',
    'song.genre': 'Genre',
    'song.getLyricsFailed': 'Failed to get lyrics. Please try again later.',
    'song.importLyricsFailed': 'Failed to import lyrics.',
    'song.lyricsReset': 'Lyrics reset',
    'song.lyricsUpdated': 'The lyrics of "{title}" have been updated!',
    'song.noAlbumArt': 'No album art',
    'song.noLibraryArtwork': 'No available album art in the library',
    'song.nothingChanged': 'No changes were detected.',
    'song.openBrowserSuccessful': 'Browser opened.',
    'song.processingRequest': 'Processing',
    'song.propertiesReset': 'Properties reset',
    'song.propertiesUpdated': 'Properties updated',
    'song.publisher': 'Publisher',
    'song.removeAlbumArt': 'Remove {title} art?',
    'song.searchLibraryArtwork': 'Search songs, artists, or albums',
    'song.searchLyricsFailed': 'No matching lyrics found.',
    'song.showInExplorer': 'Show in Explorer',
    'song.showLyricsTimestamps': 'Show timestamps',
    'song.syncTitleToFilename': 'Sync to filename "{filename}"',
    'song.subtitle': 'Subtitle',
    'song.trackNumber': 'Track Number',
    'song.updateFailed': 'Update failed',
    'song.useSelectedArtwork': 'Use this cover',
    'song.year': 'Year',
    'sidebar.recentSearches': 'Recent searches',
    'sidebar.removeRecentSearch': 'Remove {query}',
    'table.title': 'Title',
  },
);
