import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';

import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_floating_action_button.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/hidden_folders_page.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';
import 'package:smplayer_flutter/src/library/ui/local_move_to_folder_menu.dart';
import 'package:smplayer_flutter/src/library/ui/local_page.dart';
import 'package:smplayer_flutter/src/library/ui/local_page_shell.dart';
import 'package:smplayer_flutter/src/library/ui/local_page_quick_jump.dart';
import 'package:smplayer_flutter/src/library/ui/local_title_grid.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/missing_library_root_content.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show AppSettingsUpdate, LocalViewMode, LyricsRequestMode;

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'albums.clearSelection': 'Clear Selection',
      'albums.addSelectedTo': 'Add selected to',
      'albums.multiSelect': 'Multi Select',
      'albums.playSelected': 'Play selected',
      'albums.reverseSelection': 'Reverse Selection',
      'albums.selectAll': 'Select All',
      'albums.selectedCount': '{count} selected',
      'common.albumUnknown': 'Unknown Album',
      'common.artistUnknown': 'Unknown Artist',
      'common.cancel': 'Cancel',
      'common.close': 'Close',
      'common.comma': ', ',
      'common.artistSeparator': ', ',
      'common.folders': 'Folders',
      'common.name': 'Name',
      'common.artist': 'Artist',
      'common.album': 'Album',
      'common.myFavorites': 'My Favorites',
      'common.nowPlaying': 'Now Playing',
      'common.playlist': 'Playlist',
      'common.search': 'Search',
      'common.sort': 'Sort',
      'common.undo': 'Undo',
      'context.addFavorite': 'Add Favorite',
      'context.addToPlaylist': 'Add To',
      'context.deleteFromDisk': 'Delete from Disk',
      'context.hideFile': 'Hide File',
      'context.moveToFolder': 'Move To Folder',
      'context.pause': 'Pause',
      'context.play': 'Play',
      'context.playNext': 'Play Next',
      'context.reveal': 'Show In Explorer',
      'context.removeFavorite': 'Remove Favorite',
      'context.removeFromList': 'Remove From List',
      'context.seeAlbum': 'See Album',
      'context.seeAlbumArt': 'See Album Art',
      'context.seeArtist': 'See Artist',
      'context.seeLocalFile': 'See In File Explorer',
      'context.seeLyrics': 'See Lyrics',
      'context.seeMusicInfo': 'See Music Info',
      'context.select': 'Select',
      'context.view': 'View',
      'hiddenFolders.empty': 'No hidden items.',
      'hiddenFolders.introduction':
          'Hidden items stay out of Local until resumed.',
      'hiddenFolders.resume': 'Resume',
      'library.chooseFolder': 'Choose Folder',
      'library.refreshing': 'Refreshing library...',
      'library.scanHelp': 'Scan music first.',
      'library.scanning': 'Scanning...',
      'notification.deletedLocalItems': 'Deleted {count} items from disk',
      'notification.hiddenStorageItem': 'Hidden "{name}"',
      'notification.movedLocalItems': 'Moved {count} items',
      'notification.movedSong': 'Moved "{title}"',
      'local.allSongs': 'All Songs',
      'local.backToRoot': 'Back to Root',
      'local.currentPath': 'Current Path',
      'local.deleteFolder': 'Delete Folder',
      'local.deleteFolderConfirm': 'Delete "{name}" from disk?',
      'local.folderCardStats': '{folders} folders · {songs} songs',
      'local.gridFolderPlayInfo': 'Play {name}',
      'local.folderNotFound': 'Folder not found',
      'local.folderNotFoundDescription':
          'Return to the root folder and choose an existing folder.',
      'local.folderNameEmpty': 'Folder name cannot be empty.',
      'local.folderNameTooLong': 'Folder name cannot exceed 50 characters.',
      'local.folderNameUsed': 'A folder with this name already exists.',
      'local.goToSettings': 'Settings',
      'local.hiddenFolders': 'Hidden Folders',
      'local.hideFolder': 'Hide Folder',
      'local.libraryRoot': 'Library root',
      'local.newFolder': 'New Folder',
      'local.newFolderName': 'New Folder',
      'local.newFolderPrompt': 'Folder name',
      'local.noMusicUnderCurrentFolder': 'No music under current folder.',
      'local.noRoot': 'No root',
      'local.noRootCopy': 'Choose a library folder first.',
      'local.noSongsBranch': 'No songs for {query}',
      'local.noSongsScanned': 'No songs scanned',
      'local.path': 'Path',
      'local.pleaseExitMultiSelectMode': 'Exit multi-select mode first.',
      'local.renameFolder': 'Rename Folder',
      'local.renameFolderPrompt': 'Folder name',
      'local.rescan': 'Rescan Library',
      'local.scanPopulate': 'Scan to populate.',
      'local.refreshAddedGroup': 'Added ({count})',
      'local.refreshAddedMultiple': '{count} songs added',
      'local.refreshAddedOne': '"{name}" added',
      'local.refreshAddedTab': 'Added Songs',
      'local.refreshArtistMergeSuggestionsGroup': 'Possible merges ({count})',
      'local.refreshArtistSplitsAppliedGroup': 'Ready to Split ({count})',
      'local.refreshArtistSplitSuggestionsGroup': 'Possible splits ({count})',
      'local.refreshArtistUpdatesTab': 'Artist updates',
      'local.refreshMovedGroup': 'Moved ({count})',
      'local.refreshMovedMultiple': '{count} songs moved',
      'local.refreshMovedOne': '"{name}" moved',
      'local.refreshMovedTab': 'Moved Songs',
      'local.refreshNoChange': 'No changes found.',
      'local.refreshRemovedGroup': 'Removed ({count})',
      'local.refreshRemovedMultiple': '{count} songs removed',
      'local.refreshRemovedOne': '"{name}" removed',
      'local.refreshRemovedTab': 'Removed Songs',
      'local.scopeCurrent': 'Current folder',
      'local.scopeSubtree': 'Include subfolders',
      'local.searchDirectoryPrompt': 'Search under "{name}"',
      'local.searchDirectory': 'Search Directory',
      'local.searchHelp': 'Try another search.',
      'local.searchQueryEmpty': 'Search query cannot be empty.',
      'local.sortByAlbum': 'Album',
      'local.sortByArtist': 'Artist',
      'local.sortByTitle': 'Title',
      'local.sortReverseList': 'Reverse',
      'local.updateFolder': 'Update Folder',
      'local.viewHiddenFolders': 'Hidden Folders',
      'local.openLocalButtonTooltip': 'Open local folder',
      'local.playAllButtonTooltip': 'Shuffle all',
      'local.searchFolderButtonTooltip': 'Search folder',
      'local.updateFolderProgressActionChecking': 'Checking folders',
      'local.updateFolderProgressActionReading': 'Reading music',
      'local.updateFolderProgressActionUpdating': 'Updating library',
      'local.updateFolderProgressAdded': 'Added',
      'local.updateFolderProgressChecked': 'Checked: {count} / {total}',
      'local.updateFolderProgressCurrentFolder': 'Current folder: {name}',
      'local.updateFolderProgressMissing': 'Missing',
      'local.updateFolderProgressProcessedItems':
          'Processed: {count} / {total}',
      'local.updateFolderProgressProcessedSongs':
          'Processed songs: {count} / {total}',
      'local.updateFolderProgressStop': 'Stop Update',
      'local.updateFolderProgressStopConfirm': 'Stop Update',
      'local.updateFolderProgressStopConfirmMessage':
          'The scan will stop before library writes.',
      'local.updateFolderProgressStopConfirmTitle': 'Stop updating folder?',
      'local.updateFolderProgressTitle': 'Updating local folder',
      'local.updateFolderProgressUpdated': 'Updated',
      'local.updateFolderAccessDenied':
          'Authorization is needed to access {path}!',
      'local.updateFolderNotFound': 'Cannot find folder "{path}"!',
      'local.updateResultOfFolder': 'Update result for "{name}"',
      'local.updateFolderShort': 'Update',
      'local.viewGrid': 'Grid View',
      'local.viewList': 'List View',
      'nowPlaying.loading': 'Loading',
      'nowPlaying.randomPlay': 'Shuffle',
      'player.more': 'More',
      'player.pause': 'Pause',
      'playlists.create': 'Create',
      'playlists.createNew': 'Create Playlist',
      'playlists.nameEmpty': 'Name is required.',
      'playlists.namePlaceholder': 'Playlist name',
      'playlists.nameSpecial': 'Name contains unsupported text.',
      'playlists.nameTooLong': 'Name is too long.',
      'playlists.nameUsed': 'Name already exists.',
      'playlists.newPlaylist': 'New Playlist',
      'playlists.songCount': '{count} songs',
      'preferences.level.dislike': 'Dislike',
      'preferences.level.do-not-appear': 'Do Not Appear',
      'preferences.level.high': 'High',
      'preferences.level.higher': 'Higher',
      'preferences.level.normal': 'Normal',
      'preferences.level.very-high': 'Very High',
      'preferences.undoPrefer': 'Undo Preference',
      'settings.preferenceSettings': 'Preference Settings',
    },
  );

  testWidgets(
    'LocalPageContentPanel uses Electron multi-select scroll spacer',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: LocalPageContentPanel(
            scrollController: controller,
            scrollable: true,
            compact: false,
            bottomPadding: multiSelectCommandBarScrollSpacer,
            child: const SizedBox(height: 20),
          ),
        ),
      );

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      final padding = scrollView.child! as Padding;
      expect(
        padding.padding,
        const EdgeInsets.fromLTRB(6, 4, 6, multiSelectCommandBarScrollSpacer),
      );
    },
  );

  testWidgets('LocalPage toolbar shuffle matches Electron scope menu', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await _pressTextButtonByLabel(tester, 'Shuffle');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Current folder'), findsOneWidget);
    expect(find.text('Include subfolders'), findsOneWidget);

    await tester.tap(find.text('Current folder'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.replacedNowPlaying, [1]);
    expect(mediaController.state.track.id, 1);
    expect(mediaController.state.isPlaying, isTrue);
  });

  testWidgets('LocalPage toolbar shuffle on empty folder shows Electron copy', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithTargetFolder,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
        currentRelativePath: 'Target',
      ),
    );
    await tester.pumpAndSettle();

    await _pressTextButtonByLabel(tester, 'Shuffle');
    await tester.pumpAndSettle();

    expect(find.text('No music under current folder.'), findsOneWidget);
    await _dismissTransientNotifications(tester);
  });

  testWidgets('LocalPage refresh shows Electron-style result details', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository =
        _FakeLibraryRepository()
          ..refreshResult = const LocalFolderRefreshResult(
            filesAdded: [r'C:\Music\New Song.mp3'],
            filesRemoved: [r'C:\Music\Old Song.mp3'],
            filesMoved: [r'C:\Music\Moved Song.mp3'],
            artistSplitsApplied: [],
            artistSplitSuggestions: [],
            artistMergeSuggestions: [],
          );

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithSongs([
          ..._snapshot.songs,
          _localTestSong(
            id: 3,
            path: r'C:\Music\New Song.mp3',
            title: 'New Song',
          ),
          _localTestSong(
            id: 4,
            path: r'C:\Music\Moved Song.mp3',
            title: 'Moved Song',
          ),
        ]),
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await _pressTextButtonByLabel(tester, 'Update Folder');
    await tester.pumpAndSettle();

    expect(repository.refreshedFolderPath, r'C:\Music');
    expect(find.textContaining('Update result for'), findsOneWidget);
    expect(find.text('Added Songs'), findsOneWidget);
    expect(find.text('Removed Songs'), findsOneWidget);
    expect(find.text('Moved Songs'), findsOneWidget);
    expect(find.text('New Song'), findsWidgets);

    await tester.tap(find.text('Removed Songs'));
    await tester.pumpAndSettle();

    expect(find.text('Old Song'), findsOneWidget);
    expect(find.textContaining(r'C:\Music'), findsNothing);
    await _dismissTransientNotifications(tester);
  });

  testWidgets('LocalPage refresh result song menu excludes Electron actions', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository =
        _FakeLibraryRepository()
          ..refreshResult = const LocalFolderRefreshResult(
            filesAdded: [r'C:\Music\New Song.mp3'],
            filesRemoved: [],
            filesMoved: [],
            artistSplitsApplied: [],
            artistSplitSuggestions: [],
            artistMergeSuggestions: [],
          );

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithSongs([
          ..._snapshot.songs,
          _localTestSong(
            id: 3,
            path: r'C:\Music\New Song.mp3',
            title: 'New Song',
          ),
        ]),
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await _pressTextButtonByLabel(tester, 'Update Folder');
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(find.text('New Song').last),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Add To'), findsOneWidget);
    expect(find.text('Hide File'), findsOneWidget);
    expect(find.text('Select'), findsNothing);
    expect(find.text('View'), findsNothing);
    expect(find.text('See Music Info'), findsNothing);
    expect(find.text('Delete from Disk'), findsNothing);
    await _dismissTransientNotifications(tester);
  });

  testWidgets('LocalPage refresh ignores duplicate requests while running', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();
    final refreshCompleter = Completer<LocalFolderRefreshResult>();
    repository.refreshCompleter = refreshCompleter;

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await _pressCommandBarButton(tester, 'Update Folder');
    await tester.pump();
    await _pressCommandBarButton(tester, 'Update Folder');
    await tester.pump();

    expect(repository.refreshCallCount, 1);

    refreshCompleter.complete(
      const LocalFolderRefreshResult(
        filesAdded: [],
        filesRemoved: [],
        filesMoved: [],
        artistSplitsApplied: [],
        artistSplitSuggestions: [],
        artistMergeSuggestions: [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No changes found.'), findsOneWidget);
    expect(find.textContaining('Update result for'), findsNothing);
    await _dismissTransientNotifications(tester);
  });

  testWidgets('LocalPage shows Electron loading state while data loads', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final snapshotCompleter = Completer<LibraryContentData>();

    await tester.pumpWidget(
      _LocalPageLoadingTestApp(
        snapshotFuture: snapshotCompleter.future,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading'), findsOneWidget);

    snapshotCompleter.complete(_snapshot);
    await tester.pumpAndSettle();

    expect(find.text('Root Song'), findsOneWidget);
  });

  testWidgets('LocalPage refresh maps Electron folder errors', (tester) async {
    _setLargeSurface(tester);
    final repository =
        _FakeLibraryRepository()
          ..refreshError = StateError('Folder not found: C:\\Missing');

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await _pressCommandBarButton(tester, 'Update Folder');
    await tester.pumpAndSettle();

    expect(find.text('Cannot find folder "C:\\Missing"!'), findsOneWidget);
    expect(find.textContaining('Update result for'), findsNothing);
    await _dismissTransientNotifications(tester);
  });

  testWidgets('LocalPage ignores stored list view and uses Electron grid', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithLocalViewMode(LocalViewMode.list),
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Name'), findsNothing);
    expect(find.text('Artist'), findsNothing);
    expect(find.text('Album'), findsNothing);
    expect(
      find.byKey(const ValueKey('LocalTableContent.VirtualList')),
      findsNothing,
    );
    expect(find.text('Sub'), findsOneWidget);
    expect(find.text('Root Song'), findsOneWidget);
    expect(_richTextContaining('Folders'), findsOneWidget);
    expect(_richTextContaining('All Songs'), findsOneWidget);

    await tester.tap(find.text('Root Song'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.replacedNowPlaying, [1]);
    expect(mediaController.state.track.id, 1);
  });

  testWidgets('LocalPage stored list mode does not enter table routing', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageRouterTestApp(
        snapshot: _snapshotWithLocalViewMode(LocalViewMode.list),
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('LocalTableContent.VirtualList')),
      findsNothing,
    );
    expect(find.text('Root Song'), findsOneWidget);
    expect(find.text('Artist A'), findsOneWidget);
    expect(find.text('Root Album'), findsNothing);
  });

  testWidgets('LocalPage grid quick jump jumps by Electron title bucket', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _alphabetLocalSongsSnapshot(LocalViewMode.list),
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alpha Song 00'), findsOneWidget);
    final quickJumpB = find.widgetWithText(TextButton, 'B').first;
    final quickJumpBTop = tester.getTopLeft(quickJumpB).dy;
    final initialTop =
        tester
            .getTopLeft(
              find
                  .ancestor(
                    of: find.text('Alpha Song 00'),
                    matching: find.byWidgetPredicate(
                      (widget) =>
                          widget is Container &&
                          widget.constraints?.minHeight == 232 &&
                          widget.decoration is BoxDecoration,
                    ),
                  )
                  .first,
            )
            .dy;

    await tester.tap(quickJumpB);
    await tester.pumpAndSettle();

    expect(find.text('Bravo Song 00'), findsOneWidget);
    expect(tester.getTopLeft(quickJumpB).dy, closeTo(quickJumpBTop, 1));
    final bravoCard =
        find
            .ancestor(
              of: find.text('Bravo Song 00'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.constraints?.minHeight == 232 &&
                    widget.decoration is BoxDecoration,
              ),
            )
            .first;
    expect(tester.getTopLeft(bravoCard).dy, closeTo(initialTop, 1));
  });

  testWidgets('LocalPage grid quick jump follows Electron artist basis', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _artistQuickJumpSnapshot(LocalViewMode.list),
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Track 00'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'D').first);
    await tester.pumpAndSettle();

    expect(find.text('Track 60'), findsOneWidget);
  });

  testWidgets('LocalPage stored list mode still renders grid quick jump', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _albumQuickJumpSnapshot(LocalViewMode.list),
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Track 00'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'A'), findsWidgets);
    expect(
      find.byKey(const ValueKey('LocalTableContent.VirtualList')),
      findsNothing,
    );
  });

  testWidgets('LocalPage compact grid uses Electron folder tree rows', (
    tester,
  ) async {
    _setCompactSurface(tester);
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithTargetFolderAndLocalViewMode(LocalViewMode.list),
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sub'), findsOneWidget);
    expect(find.text('Root Song'), findsOneWidget);
    expect(find.text('Child Song'), findsNothing);

    await tester.tap(find.byIcon(FluentIcons.chevron_right_20_regular).first);
    await tester.pumpAndSettle();

    expect(find.text('Child Song'), findsOneWidget);

    await tester.tap(find.text('Child Song'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.replacedNowPlaying, [2]);
    expect(mediaController.state.track.id, 2);
  });

  testWidgets('LocalPage compact grid drags songs onto folders', (
    tester,
  ) async {
    _setCompactSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithTargetFolderAndLocalViewMode(LocalViewMode.list),
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    final start = tester.getCenter(find.text('Root Song'));
    final end = tester.getCenter(find.text('Target'));
    await tester.dragFrom(start, end - start);
    await tester.pumpAndSettle();

    expect(repository.movedSongIds, [1]);
    expect(repository.movedFolderPaths, isEmpty);
    expect(repository.movedTargetFolderPath, r'C:\Music\Target');
    await _dismissTransientNotifications(tester);
  });

  testWidgets('LocalPage dragging a selected folder moves selected folders', (
    tester,
  ) async {
    _setCompactSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _dragSelectionSnapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();

    await _dragTextToText(tester, 'Sub', 'Target');

    expect(repository.movedSongIds, isEmpty);
    expect(repository.movedFolderPaths, [r'C:\Music\Sub', r'C:\Music\Other']);
    expect(repository.movedTargetFolderPath, r'C:\Music\Target');
    await _dismissTransientNotifications(tester);
  });

  testWidgets(
    'LocalPage dragging an unselected folder moves only that folder',
    (tester) async {
      _setCompactSurface(tester);
      final repository = _FakeLibraryRepository();

      await tester.pumpWidget(
        _LocalPageTestApp(
          snapshot: _dragSelectionSnapshot,
          i18n: i18n,
          repository: repository,
          mediaController: MediaControlController(),
        ),
      );
      await tester.pumpAndSettle();

      await _pressCommandBarButton(tester, 'Multi Select');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();

      await _dragTextToText(tester, 'Sub', 'Target');

      expect(repository.movedSongIds, isEmpty);
      expect(repository.movedFolderPaths, [r'C:\Music\Sub']);
      expect(repository.movedTargetFolderPath, r'C:\Music\Target');
      await _dismissTransientNotifications(tester);
    },
  );

  testWidgets('LocalPage dragging a selected song moves selected songs', (
    tester,
  ) async {
    _setCompactSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _dragSelectionSnapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Root Song'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second Song'));
    await tester.pumpAndSettle();

    await _dragTextToText(tester, 'Root Song', 'Target');

    expect(repository.movedSongIds, [1, 3]);
    expect(repository.movedFolderPaths, isEmpty);
    expect(repository.movedTargetFolderPath, r'C:\Music\Target');
    await _dismissTransientNotifications(tester);
  });

  testWidgets('LocalPage dragging an unselected song moves only that song', (
    tester,
  ) async {
    _setCompactSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _dragSelectionSnapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second Song'));
    await tester.pumpAndSettle();

    await _dragTextToText(tester, 'Root Song', 'Target');

    expect(repository.movedSongIds, [1]);
    expect(repository.movedFolderPaths, isEmpty);
    expect(repository.movedTargetFolderPath, r'C:\Music\Target');
    await _dismissTransientNotifications(tester);
  });

  testWidgets('LocalPage compact tree select all uses visible tree rows', (
    tester,
  ) async {
    _setCompactSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithTargetFolder,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(FluentIcons.chevron_right_20_regular), findsOneWidget);
    await tester.tap(find.byIcon(FluentIcons.chevron_right_20_regular));
    await tester.pumpAndSettle();
    expect(find.text('Child Song'), findsOneWidget);

    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    _pressBottomTooltipIconButton(tester, 'More');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();

    expect(find.text('4 selected'), findsOneWidget);
  });

  testWidgets('LocalPage stored list mode keeps Electron grid content', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _manyLocalSongsSnapshot(LocalViewMode.list, 140),
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('LocalTableContent.VirtualList')),
      findsNothing,
    );
    expect(find.text('Song 0'), findsOneWidget);
    expect(find.text('Song 139'), findsOneWidget);
  });

  testWidgets('LocalPage toolbar does not expose a view toggle', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byWidgetPredicate(
        (widget) => widget is CommandBarButton && widget.label == 'List View',
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CommandBarButton && widget.label == 'Grid View',
      ),
      findsNothing,
    );
  });

  testWidgets('LocalPage grid sections collapse only when both groups exist', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(_richTextContaining('Folders'), findsOneWidget);
    expect(_richTextContaining('All Songs'), findsOneWidget);
    expect(find.text('Sub'), findsOneWidget);

    await tester.tap(
      find
          .ancestor(
            of: _richTextContaining('Folders'),
            matching: find.byType(TextButton),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Sub'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithoutFolders,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(_richTextContaining('Folders'), findsNothing);
    expect(_richTextContaining('All Songs'), findsNothing);
    expect(find.text('Root Song'), findsOneWidget);
  });

  testWidgets('LocalPage grid folder-only content has no section headers', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _folderOnlySnapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(_richTextContaining('Folders'), findsNothing);
    expect(_richTextContaining('All Songs'), findsNothing);
    expect(find.text('Sub'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
  });

  testWidgets('LocalPage empty root chooses and scans library', (tester) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _emptySnapshotWithRoot(''),
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
        onPickLibraryRoot: () async => r'C:\PickedMusic',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose Folder'));
    await tester.pumpAndSettle();

    expect(repository.scannedRootPath, r'C:\PickedMusic');
  });

  testWidgets('LocalPage empty scanned library shows settings action', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _emptySnapshotWithRoot(r'C:\Music'),
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(repository.scannedRootPath, isNull);
  });

  testWidgets('LocalPage custom root scan receives progress and cancellation', (
    tester,
  ) async {
    _setLargeSurface(tester);
    LocalFolderScanCancellation? scanCancellation;
    final scanCompleter = Completer<void>();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _emptySnapshotWithRoot(''),
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
        onPickLibraryRoot: () async => r'C:\PickedMusic',
        onScanLibrary: (rootPath, {cancellation, onProgress}) async {
          expect(rootPath, r'C:\PickedMusic');
          scanCancellation = cancellation;
          onProgress?.call(
            const LocalFolderRefreshProgress(
              current: 1,
              total: 2,
              currentPath: r'C:\PickedMusic\song.mp3',
              stage: LocalFolderRefreshStage.reading,
              processedSongCount: 1,
              songCount: 2,
              canCancel: true,
            ),
          );
          await scanCompleter.future;
          return const LocalFolderRefreshResult(
            filesAdded: [],
            filesRemoved: [],
            filesMoved: [],
            artistSplitsApplied: [],
            artistSplitSuggestions: [],
            artistMergeSuggestions: [],
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose Folder'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Scanning...'), findsOneWidget);
    expect(find.text('Reading music'), findsOneWidget);
    expect(find.text('Stop Update'), findsOneWidget);

    await tester.tap(find.text('Stop Update'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop Update').last);
    await tester.pump();

    expect(scanCancellation?.isCanceled, isTrue);

    scanCompleter.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('LocalPage multi-select add to playlist uses selected folders', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressTextButtonByLabel(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add selected to'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Road Mix'));
    await tester.pumpAndSettle();

    expect(repository.addedPlaylistId, 30);
    expect(repository.addedSongIds, [2]);
    await _dismissTransientNotifications(tester);
  });

  testWidgets(
    'LocalPage multi-select Add To respects Electron hide preference',
    (tester) async {
      _setLargeSurface(tester);
      final repository = _FakeLibraryRepository();

      await tester.pumpWidget(
        _LocalPageTestApp(
          snapshot: _snapshotWithHideAfterOperation(false),
          i18n: i18n,
          repository: repository,
          mediaController: MediaControlController(),
        ),
      );
      await tester.pumpAndSettle();

      await _pressTextButtonByLabel(tester, 'Multi Select');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sub'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Add selected to'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Road Mix'));
      await tester.pumpAndSettle();

      expect(repository.addedPlaylistId, 30);
      expect(repository.addedSongIds, [2]);
      expect(find.text('1 selected'), findsOneWidget);
      await _dismissTransientNotifications(tester);
    },
  );

  testWidgets('LocalPage multi-select Play respects Electron hide preference', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithHideAfterOperation(false),
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await _pressTextButtonByLabel(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sub'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('Play selected'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.replacedNowPlaying, [2]);
    expect(mediaController.state.track.id, 2);
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets(
    'LocalPage hides Play and Add To when selection has no songs like Electron',
    (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        _LocalPageTestApp(
          snapshot: _snapshotWithTargetFolder,
          i18n: i18n,
          repository: _FakeLibraryRepository(),
          mediaController: MediaControlController(),
        ),
      );
      await tester.pumpAndSettle();

      await _pressTextButtonByLabel(tester, 'Multi Select');
      await tester.tap(find.text('Target'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Play selected'), findsNothing);
      expect(find.text('Add selected to'), findsNothing);
      expect(find.text('Delete from Disk'), findsWidgets);
      expect(find.text('Move To Folder'), findsOneWidget);
    },
  );

  testWidgets('LocalPage song add menu supports now playing and favorites', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _hoverText(tester, 'Root Song');
    await tester.tap(_nearestArtworkAction(tester, 'Add To', 'Root Song'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Now Playing'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [9, 1]);

    await _hoverText(tester, 'Root Song');
    await tester.tap(_nearestArtworkAction(tester, 'Add To', 'Root Song'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Favorites'));
    await tester.pumpAndSettle();

    expect(repository.favoriteSongIds, [1]);
    expect(repository.favoriteValue, isTrue);
    await _dismissTransientNotifications(tester);
  });

  testWidgets('LocalPage folder add action uses folder subtree songs', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _hoverText(tester, 'Sub');
    await tester.tap(_nearestArtworkAction(tester, 'Add To', 'Sub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Road Mix'));
    await tester.pumpAndSettle();

    expect(repository.addedPlaylistId, 30);
    expect(repository.addedSongIds, [2]);
    await _dismissTransientNotifications(tester);
  });

  testWidgets('LocalPage new folder creates directory and shows it', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final root = Directory(
      '${Directory.current.path}${Platform.pathSeparator}build${Platform.pathSeparator}local_page_test_root',
    );
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
    root.createSync(recursive: true);
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithRoot(root.path),
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'New Folder');
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'New Folder');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    for (
      var attempt = 0;
      attempt < 10 && repository.createdLocalFolder == null;
      attempt += 1
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(repository.createdLocalFolder, (
      rootPath: root.path,
      relativePath: '',
      name: 'New Folder',
    ));
    expect(repository.refreshedFolderPath, root.path);
    expect(find.text('New Folder'), findsWidgets);
  });

  testWidgets('LocalPage blocks sort changes in multi-select mode', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await _pressCommandBarButton(tester, 'Sort');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Album').last);
    await tester.pumpAndSettle();

    expect(find.text('Exit multi-select mode first.'), findsOneWidget);
    expect(repository.updatedSortFolderPath, isNull);
    await _dismissTransientNotifications(tester);
  });

  testWidgets('LocalPage search folder uses Electron input dialog', (
    tester,
  ) async {
    _setCompactSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(FluentIcons.search_20_regular).first);
    await tester.pumpAndSettle();

    expect(find.text('Search under "Sub"'), findsOneWidget);

    await _tapPopupAction(tester, 'Search');
    await tester.pumpAndSettle();
    expect(find.text('Search query cannot be empty.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'jazz');
    await _tapPopupAction(tester, 'Search');
    await tester.pumpAndSettle();

    expect(repository.recentSearchQuery, 'jazz');
    expect(repository.recentSearchType, SearchHistoryType.folders);
    expect(find.text('search:jazz:folders:Sub'), findsOneWidget);
  });

  testWidgets('LocalPage route query opens target local folder', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
        initialLocation: '/local?path=Sub',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Child Song'), findsOneWidget);
    expect(find.text('Root Song'), findsNothing);
  });

  testWidgets('LocalPage folder click opens relative folder', (tester) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sub'));
    await tester.pumpAndSettle();

    expect(find.text('Child Song'), findsOneWidget);
    expect(find.text('Root Song'), findsNothing);
  });

  testWidgets('LocalPage song click plays Electron current-folder queue', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithMultipleRootSongs,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Second Root'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.replacedNowPlaying, [1, 3]);
    expect(mediaController.state.track.id, 3);
    expect(mediaController.state.selectedQueueIndex, 1);
    expect(find.text('1 selected'), findsNothing);
  });

  testWidgets('LocalPage song click toggles selection in multi-select', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithMultipleRootSongs,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second Root'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, isEmpty);
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('LocalPage route query opens nested local folder', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageRouterTestApp(
        snapshot: _nestedSnapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
        initialLocation: '/local?path=Sub/Deep',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Deep Song'), findsOneWidget);
    expect(find.text('Child Song'), findsNothing);
    expect(find.text('Root Song'), findsNothing);
  });

  testWidgets('LocalPage missing route folder returns to Electron root', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
        initialLocation: '/local?path=Missing',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Folder not found'), findsOneWidget);
    expect(
      find.text('Return to the root folder and choose an existing folder.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Back to Root'));
    await tester.pumpAndSettle();

    expect(find.text('Root Song'), findsOneWidget);
    expect(find.text('Folder not found'), findsNothing);
  });

  testWidgets('LocalPage breadcrumb search uses target folder scope', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('FolderChain.Path.')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search Directory'));
    await tester.pumpAndSettle();

    expect(find.text('Search under "Music"'), findsOneWidget);
    await _tapPopupAction(tester, 'Search');
    await tester.pumpAndSettle();
    expect(find.text('Search query cannot be empty.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'lofi');
    await _tapPopupAction(tester, 'Search');
    await tester.pumpAndSettle();

    expect(repository.recentSearchQuery, 'lofi');
    expect(repository.recentSearchType, SearchHistoryType.folders);
    expect(find.text('search:lofi:folders:'), findsOneWidget);
  });

  testWidgets('LocalPage hidden folders entry opens and resumes items', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository =
        _FakeLibraryRepository()
          ..hiddenItems = const [
            HiddenStorageItem(id: 1, type: 'folder', path: r'C:\Music\Hidden'),
            HiddenStorageItem(
              id: 2,
              type: 'file',
              path: r'C:\Music\Hidden Song.mp3',
            ),
          ];

    await tester.pumpWidget(
      _LocalPageRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hidden Folders'));
    await tester.pumpAndSettle();

    expect(
      find.text('Hidden items stay out of Local until resumed.'),
      findsOneWidget,
    );
    expect(find.text(r'C:\Music\Hidden'), findsOneWidget);
    expect(find.text(r'C:\Music\Hidden Song.mp3'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);
    final hiddenPathText = tester.widget<Text>(find.text(r'C:\Music\Hidden'));
    expect(hiddenPathText.maxLines, isNull);
    expect(hiddenPathText.overflow, isNull);
    expect(hiddenPathText.style?.fontWeight, FontWeight.w400);
    expect(find.byType(OutlinedButton), findsNWidgets(2));
    expect(find.byType(FilledButton), findsNothing);

    await tester.tap(find.text('Resume').first);
    await tester.pumpAndSettle();

    expect(repository.resumedHiddenItem?.path, r'C:\Music\Hidden');
    expect(find.text(r'C:\Music\Hidden Song.mp3'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(repository.resumedHiddenItem?.path, r'C:\Music\Hidden Song.mp3');
    expect(find.text('No hidden items.'), findsOneWidget);
  });

  testWidgets('LocalPage compact overflow opens hidden folders entry', (
    tester,
  ) async {
    _setCompactSurface(tester);

    await tester.pumpWidget(
      _LocalPageRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'Hidden Folders');
    await tester.pumpAndSettle();

    expect(find.text('No hidden items.'), findsOneWidget);
  });

  testWidgets('LocalPage hidden folders route shows initial empty state', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hidden Folders'));
    await tester.pumpAndSettle();

    expect(find.text('No hidden items.'), findsOneWidget);
    final emptyText = tester.widget<Text>(find.text('No hidden items.'));
    expect(emptyText.style?.fontSize, 20);
    expect(emptyText.style?.fontWeight, FontWeight.w700);
    final emptyBox = tester.widget<DecoratedBox>(
      find.ancestor(
        of: find.text('No hidden items.'),
        matching: find.byType(DecoratedBox),
      ),
    );
    final emptyDecoration = emptyBox.decoration as BoxDecoration;
    expect(emptyDecoration.borderRadius, BorderRadius.circular(18));
  });

  testWidgets('LocalPage toolbar stats use direct child counts', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithTargetFolder,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 folders · 1 song'), findsOneWidget);
    expect(find.text('2 folders · 2 songs'), findsNothing);
  });

  testWidgets('LocalPage toolbar buttons keep Electron visual order', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    final labels = [
      'Shuffle',
      'Update Folder',
      'Sort',
      'New Folder',
      'Multi Select',
    ];
    final leftPositions = [
      for (final label in labels)
        tester.getTopLeft(_findVisibleCommandBarButton(label)).dx,
    ];

    expect(leftPositions, orderedEquals([...leftPositions]..sort()));
  });

  testWidgets('LocalPage selection toolbar button order matches Electron', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();

    final labels = [
      'Shuffle',
      'Update Folder',
      'Sort',
      'New Folder',
      'Multi Select',
      'Delete from Disk',
    ];
    final leftPositions = [
      for (final label in labels)
        tester.getTopLeft(_findVisibleCommandBarButton(label)).dx,
    ];

    expect(leftPositions, orderedEquals([...leftPositions]..sort()));
  });

  testWidgets('LocalPage compact overflow menu order matches Electron', (
    tester,
  ) async {
    _setCompactSurface(tester);

    await tester.pumpWidget(
      _LocalPageRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('CommandBar.MoreButton')));
    await tester.pumpAndSettle();

    final labels = [
      'Update',
      'Sort',
      'New Folder',
      'Multi Select',
      'Hidden Folders',
    ];
    final topPositions = [
      for (final label in labels) tester.getTopLeft(find.text(label).last).dy,
    ];

    expect(topPositions, orderedEquals([...topPositions]..sort()));
  });

  testWidgets('LocalPage compact toolbar never shows sort before update', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(719, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _LocalPageRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    final updateButton = _findVisibleCommandBarButton('Update');
    final sortButton = _findVisibleCommandBarButton('Sort');

    if (sortButton.evaluate().isNotEmpty) {
      expect(updateButton, findsOneWidget);
      expect(
        tester.getTopLeft(updateButton).dx,
        lessThan(tester.getTopLeft(sortButton).dx),
      );
    }
  });

  testWidgets('HiddenFoldersPage shows Electron loading state', (tester) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();
    final hiddenItemsCompleter = Completer<List<HiddenStorageItem>>();
    repository.hiddenItemsCompleter = hiddenItemsCompleter;

    await tester.pumpWidget(
      _LocalPageRouterTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hidden Folders'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading'), findsOneWidget);

    hiddenItemsCompleter.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('No hidden items.'), findsOneWidget);
  });

  testWidgets('HiddenFoldersPage shows Electron root refresh banner', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final snapshotCompleter = Completer<LibraryContentData>();

    await tester.pumpWidget(
      _LocalPageRouterTestApp(
        initialLocation: '/hidden-folders',
        snapshot: _snapshot,
        snapshotFuture: snapshotCompleter.future,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Refreshing library...'), findsOneWidget);
    expect(find.text('No hidden items.'), findsOneWidget);

    snapshotCompleter.complete(_snapshot);
    await tester.pumpAndSettle();

    expect(find.text('Refreshing library...'), findsNothing);
    expect(find.text('No hidden items.'), findsOneWidget);
  });

  testWidgets('LocalPage multi-select commands ignore filtered-out items', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();
    final searchQuery = ValueNotifier('');
    await tester.pumpWidget(
      _LocalPageSearchQueryTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
        searchQuery: searchQuery,
      ),
    );
    await tester.pumpAndSettle();
    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sub'));
    await tester.pumpAndSettle();

    searchQuery.value = 'root';
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsNothing);
    expect(find.text('Add selected to'), findsNothing);
    expect(find.text('Road Mix'), findsNothing);
    expect(repository.addedPlaylistId, isNull);
  });

  testWidgets('LocalPage search filters folders and empty results', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final searchQuery = ValueNotifier('sub');

    await tester.pumpWidget(
      _LocalPageSearchQueryTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
        searchQuery: searchQuery,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sub'), findsOneWidget);
    expect(find.text('Root Song'), findsNothing);

    searchQuery.value = 'missing';
    await tester.pumpAndSettle();

    expect(find.text('No songs for missing'), findsOneWidget);
    expect(find.text('Try another search.'), findsOneWidget);
    expect(find.text('Sub'), findsNothing);
    expect(find.text('Root Song'), findsNothing);
  });

  testWidgets('LocalPage filtered select all uses visible items only', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();
    final searchQuery = ValueNotifier('root');

    await tester.pumpWidget(
      _LocalPageSearchQueryTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
        searchQuery: searchQuery,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Root Song'), findsOneWidget);
    expect(find.text('Sub'), findsNothing);

    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('Add selected to'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Road Mix'));
    await tester.pumpAndSettle();

    expect(repository.addedPlaylistId, 30);
    expect(repository.addedSongIds, [1]);
    await _dismissTransientNotifications(tester);
  });

  testWidgets('LocalPage clears selection when current folder changes', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();
    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
        currentRelativePath: 'Sub',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 selected'), findsNothing);
    expect(find.text('Add selected to'), findsNothing);
  });

  testWidgets('LocalPage empty folder stays blank without scan/search copy', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithTargetFolder,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
        currentRelativePath: 'Target',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No songs scanned'), findsNothing);
    expect(find.text('Scan to populate.'), findsNothing);
    expect(find.textContaining('No songs for'), findsNothing);
    expect(find.text('Try another search.'), findsNothing);
  });

  testWidgets('LocalPage selection commands mirror Electron sets', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('Clear Selection'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsNothing);

    await tester.tap(find.text('Sub'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('Reverse Selection'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.text('Add selected to'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Road Mix'));
    await tester.pumpAndSettle();

    expect(repository.addedPlaylistId, 30);
    expect(repository.addedSongIds, [1]);

    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsNothing);
    expect(find.text('Add selected to'), findsNothing);
    await _dismissTransientNotifications(tester);
  });

  testWidgets(
    'LocalPage delete selected button mirrors Electron disabled state',
    (tester) async {
      _setLargeSurface(tester);
      final repository = _FakeLibraryRepository();

      await tester.pumpWidget(
        _LocalPageTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: MediaControlController(),
        ),
      );
      await tester.pumpAndSettle();

      await _pressCommandBarButton(tester, 'Multi Select');
      await tester.pumpAndSettle();

      final deleteButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Delete from Disk').last,
      );
      expect(deleteButton.onPressed, isNull);

      await tester.tap(find.text('Delete from Disk'));
      await tester.pump();

      expect(find.text('Delete 0 selected items from disk?'), findsNothing);
      expect(repository.deletedSongIds, isEmpty);
      expect(repository.deletedFolderPaths, isEmpty);
    },
  );

  testWidgets('LocalPage keeps multi-select bar when setting is off', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithHideAfterOperation(false),
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add selected to'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Road Mix'));
    await tester.pumpAndSettle();

    expect(repository.addedPlaylistId, 30);
    expect(repository.addedSongIds, [2]);
    expect(find.text('Select All'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Add selected to'), findsNothing);
    expect(find.text('1 selected'), findsNothing);
    await _dismissTransientNotifications(tester);
  });

  testWidgets('LocalPage play selected uses selected queue', (tester) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play selected'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.replacedNowPlaying, [1, 2]);
    expect(mediaController.state.track.id, 1);
    expect(mediaController.state.isPlaying, isTrue);
  });

  testWidgets('LocalPage play selected dedupes overlapping folder songs', (
    tester,
  ) async {
    _setCompactSurface(tester);
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(FluentIcons.chevron_right_20_regular));
    await tester.pumpAndSettle();
    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Child Song'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('Play selected'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.replacedNowPlaying, [2]);
    expect(mediaController.state.track.id, 2);
  });

  testWidgets('LocalPage folder context menu mirrors Electron actions', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('Sub').first),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('Shuffle'), findsWidgets);
    expect(find.text('Add To'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Move To Folder'), findsOneWidget);
    expect(find.text('Preference Settings'), findsOneWidget);
    expect(find.text('Show In Explorer'), findsOneWidget);
    expect(find.text('New Folder'), findsWidgets);
    expect(find.text('Update Folder'), findsWidgets);

    await tester.tap(find.text('Preference Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();

    expect(repository.preferenceType, 'folder');
    expect(repository.preferenceItemId, '10');
    expect(repository.preferenceLevel, 'high');
  });

  testWidgets('LocalPage folder reveal action sends Electron folder path', (
    tester,
  ) async {
    _setLargeSurface(tester);
    String? revealedFolderPath;

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
        onOpenFolderInShell: (path) {
          revealedFolderPath = path;
        },
      ),
    );
    await tester.pumpAndSettle();

    await _openFolderContextMenu(tester, 'Sub');
    await tester.tap(find.text('Show In Explorer'));
    await tester.pumpAndSettle();

    expect(revealedFolderPath, r'C:\Music\Sub');
  });

  testWidgets('LocalPage breadcrumb menu keeps Electron reduced actions', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();
    final initialSortCount = find.text('Sort').evaluate().length;
    final initialNewFolderCount = find.text('New Folder').evaluate().length;
    final initialUpdateCount = find.text('Update Folder').evaluate().length;

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    final sortCountBeforeMenu = find.text('Sort').evaluate().length;
    final newFolderCountBeforeMenu = find.text('New Folder').evaluate().length;
    final updateCountBeforeMenu = find.text('Update Folder').evaluate().length;
    expect(sortCountBeforeMenu, greaterThanOrEqualTo(initialSortCount));
    expect(
      newFolderCountBeforeMenu,
      greaterThanOrEqualTo(initialNewFolderCount),
    );
    expect(updateCountBeforeMenu, greaterThanOrEqualTo(initialUpdateCount));

    await tester.tap(
      find.byKey(const ValueKey('FolderChain.Path.')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('Shuffle'), findsWidgets);
    expect(find.text('Add To'), findsOneWidget);
    expect(find.text('Move To Folder'), findsOneWidget);
    expect(find.text('Preference Settings'), findsOneWidget);
    expect(find.text('Show In Explorer'), findsOneWidget);
    expect(find.text('Search Directory'), findsOneWidget);

    expect(find.text('Select'), findsNothing);
    expect(find.text('Delete from Disk'), findsNothing);
    expect(find.text('Rename Folder'), findsNothing);
    expect(find.text('Hide Folder'), findsNothing);
    expect(find.text('Sort').evaluate().length, sortCountBeforeMenu);
    expect(find.text('New Folder').evaluate().length, newFolderCountBeforeMenu);
    expect(find.text('Update Folder').evaluate().length, updateCountBeforeMenu);
  });

  testWidgets('LocalPage breadcrumb menu actions target chain folder', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithTargetFolder,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
        currentRelativePath: 'Sub',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('FolderChain.Path.Sub')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shuffle').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.replacedNowPlaying, [2]);
    expect(mediaController.state.track.id, 2);

    await tester.tap(
      find.byKey(const ValueKey('FolderChain.Path.Sub')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Add To').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Road Mix'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.addedPlaylistId, 30);
    expect(repository.addedSongIds, [2]);

    await tester.tap(
      find.byKey(const ValueKey('FolderChain.Path.Sub')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Preference Settings').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('High'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.preferenceType, 'folder');
    expect(repository.preferenceItemId, '10');
    expect(repository.preferenceName, 'Sub');
    expect(repository.preferenceLevel, 'high');

    await tester.tap(
      find.byKey(const ValueKey('FolderChain.Path.Sub')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Move To Folder').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Target').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.movedSongIds, isEmpty);
    expect(repository.movedFolderPaths, [r'C:\Music\Sub']);
    expect(repository.movedTargetFolderPath, r'C:\Music\Target');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('LocalPage folder sort menu persists target folder', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('Sub').first),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Album').last);
    await tester.pumpAndSettle();

    expect(repository.updatedSortFolderPath, r'C:\Music\Sub');
    expect(repository.updatedSortCriterion, LocalFolderSortCriterion.album);
  });

  testWidgets('LocalPage folder sort menu mirrors Electron checkmark state', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithSubCriterion(2),
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('Sub').first),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort').last);
    await tester.pumpAndSettle();

    expect(find.byIcon(FluentIcons.checkmark_20_regular), findsOneWidget);
    expect(
      tester.getCenter(find.byIcon(FluentIcons.checkmark_20_regular)).dy,
      closeTo(tester.getCenter(find.text('Album').last).dy, 1),
    );
  });

  testWidgets('LocalPage toolbar sort persists current folder criterion', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'Sort');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Artist').last);
    await tester.pumpAndSettle();

    expect(repository.updatedSortFolderPath, r'C:\Music');
    expect(repository.updatedSortCriterion, LocalFolderSortCriterion.artist);
  });

  testWidgets('LocalPage toolbar sort menu mirrors Electron checkmark state', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'Sort');
    await tester.pumpAndSettle();

    expect(find.byIcon(FluentIcons.checkmark_20_regular), findsOneWidget);
    expect(
      tester.getCenter(find.byIcon(FluentIcons.checkmark_20_regular)).dy,
      closeTo(tester.getCenter(find.text('Title').first).dy, 1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithRootCriterion(1),
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'Sort');
    await tester.pumpAndSettle();

    expect(find.byIcon(FluentIcons.checkmark_20_regular), findsOneWidget);
    expect(
      tester.getCenter(find.byIcon(FluentIcons.checkmark_20_regular)).dy,
      closeTo(tester.getCenter(find.text('Artist').first).dy, 1),
    );
  });

  testWidgets('LocalPage album sort shows Electron song detail label', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithRootCriterion(2),
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Artist A · Root Album'), findsOneWidget);
  });

  testWidgets(
    'LocalPage single folder rename hide and delete mirror Electron',
    (tester) async {
      _setLargeSurface(tester);
      final repository = _FakeLibraryRepository();

      await tester.pumpWidget(
        _LocalPageTestApp(
          snapshot: _snapshot,
          i18n: i18n,
          repository: repository,
          mediaController: MediaControlController(),
        ),
      );
      await tester.pumpAndSettle();

      await _openFolderContextMenu(tester, 'Sub');
      await tester.tap(find.text('Rename Folder'));
      await tester.pumpAndSettle();
      expect(find.text('Folder name'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Renamed');
      await _tapPopupAction(tester, 'Create');
      await tester.pumpAndSettle();
      expect(repository.renamedFolderPath, r'C:\Music\Sub');
      expect(repository.renamedFolderName, 'Renamed');

      repository.renamedFolderPath = null;
      repository.renamedFolderName = null;
      await _openFolderContextMenu(tester, 'Sub');
      await tester.tap(find.text('Rename Folder'));
      await tester.pumpAndSettle();
      await _tapPopupAction(tester, 'Create');
      await tester.pumpAndSettle();
      expect(repository.renamedFolderPath, isNull);
      expect(repository.renamedFolderName, isNull);

      await _openFolderContextMenu(tester, 'Sub');
      await tester.tap(find.text('Hide Folder'));
      await tester.pumpAndSettle();
      expect(repository.hiddenFolderPath, r'C:\Music\Sub');
      expect(find.text('Hidden "Sub"'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repository.hiddenFolderPath, isNull);

      await _openFolderContextMenu(tester, 'Sub');
      await tester.tap(find.text('Delete Folder'));
      await tester.pumpAndSettle();
      expect(find.text('Delete "Sub" from disk?'), findsOneWidget);
      await _tapPopupAction(tester, 'Delete Folder');
      await tester.pump();
      expect(repository.deletedSongIds, isEmpty);
      expect(repository.deletedFolderPaths, [r'C:\Music\Sub']);
      expect(find.text('Undo'), findsOneWidget);
      await _dismissTransientNotifications(tester);
    },
  );

  testWidgets('LocalPage folder menu creates child folder under target', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _openFolderContextMenu(tester, 'Sub');
    await tester.tap(find.text('New Folder').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Child Created');
    await _tapPopupAction(tester, 'Create');
    await tester.pumpAndSettle();

    expect(repository.createdLocalFolder?.rootPath, r'C:\Music');
    expect(repository.createdLocalFolder?.relativePath, 'Sub');
    expect(repository.createdLocalFolder?.name, 'Child Created');
  });

  testWidgets('LocalPage selected local items move and delete like Electron', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithTargetFolder,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move To Folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Target').last);
    await tester.pumpAndSettle();

    expect(repository.movedSongIds, isEmpty);
    expect(repository.movedFolderPaths, [r'C:\Music\Sub']);
    expect(repository.movedTargetFolderPath, r'C:\Music\Target');

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete from Disk').last);
    await tester.pumpAndSettle();
    expect(find.text('Delete 1 selected item from disk?'), findsOneWidget);
    await tester.tap(find.text('Delete from Disk').last);
    await tester.pump();

    expect(repository.deletedSongIds, isEmpty);
    expect(repository.deletedFolderPaths, [r'C:\Music\Sub']);
    expect(find.text('Undo'), findsOneWidget);
    await _dismissTransientNotifications(tester);
  });

  testWidgets('LocalPage disables selected Move when Electron has no target', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await _pressCommandBarButton(tester, 'Multi Select');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sub'));
    await tester.pumpAndSettle();

    final moveButtons = tester.widgetList<TextButton>(
      find.ancestor(
        of: find.text('Move To Folder'),
        matching: find.byType(TextButton),
      ),
    );
    expect(moveButtons.any((button) => button.onPressed == null), isTrue);
  });

  test(
    'Local move-to-folder targets mirror Electron source/parent filtering',
    () {
      final index = buildFolderIndex(const [], const [
        LibraryFolder(id: 10, path: r'C:\Music\Sub', parentId: 0, criterion: 0),
        LibraryFolder(
          id: 11,
          path: r'C:\Music\Sub\Deep',
          parentId: 10,
          criterion: 0,
        ),
      ], r'C:\Music');

      final items = buildLocalMoveToFolderMenuItems(
        nodes: index.nodes,
        songsById: index.songsById,
        songIds: const [],
        folderPaths: const [r'C:\Music\Sub'],
        i18n: i18n,
        onMoveToFolder: (_) {},
      );

      final labels = _flattenMenuFlyoutLabels(items);
      expect(labels, contains('Sub'));
      expect(labels, contains('Deep'));
      expect(labels, isNot(contains('Library root')));
    },
  );

  testWidgets('LocalPage song context menu exposes Electron song actions', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('Root Song').first),
      buttons: kSecondaryMouseButton,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Add To'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Move To Folder'), findsWidgets);
    expect(find.text('Hide File'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('LocalPage song context Play Next inserts after current queue', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 9,
        title: 'Existing',
        artist: 'Artist',
        artworkUrl: '',
        isLoading: false,
      ),
      durationSeconds: 100,
      queueIndex: 0,
    );

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: repository,
        mediaController: mediaController,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tapAt(
      tester.getCenter(find.text('Root Song').first),
      buttons: kSecondaryMouseButton,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Play Next'));
    await tester.pumpAndSettle();

    expect(repository.replacedNowPlaying, [9, 1]);
  });

  testWidgets('LocalPage song context menu moves and hides single song', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final repository = _FakeLibraryRepository();

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshotWithTargetFolder,
        i18n: i18n,
        repository: repository,
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('Root Song').first),
      buttons: kSecondaryMouseButton,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Move To Folder').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Target').last);
    await tester.pumpAndSettle();

    expect(repository.movedSongId, 1);
    expect(repository.movedSongTargetFolderPath, r'C:\Music\Target');
    expect(find.text('Moved "Root Song"'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repository.movedSongId, isNull);
    expect(repository.movedSongTargetFolderPath, isNull);

    await tester.tapAt(
      tester.getCenter(find.text('Root Song').first),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide File'));
    await tester.pumpAndSettle();

    expect(repository.hiddenSongId, 1);
    expect(find.text('Hidden "Root Song"'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repository.hiddenSongId, isNull);
  });

  testWidgets('LocalPage current song context menu pauses playback', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final mediaController = MediaControlController();
    mediaController.playTrack(
      const MediaControlTrack(
        id: 1,
        title: 'Root Song',
        artist: 'Artist A',
        artworkUrl: '',
        isLoading: false,
      ),
      durationSeconds: 120,
      queueIndex: 0,
    );

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: mediaController,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tapAt(
      tester.getCenter(find.text('Root Song').first),
      buttons: kSecondaryMouseButton,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Play'), findsNothing);

    await tester.tap(find.text('Pause'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(mediaController.state.isPlaying, isFalse);
  });

  testWidgets('LocalPage song view menu opens MusicDialog', (tester) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('Root Song').first),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See Music Info'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Root Song'), findsWidgets);
    expect(find.text('Music Info'), findsOneWidget);
    expect(find.text('Lyrics'), findsOneWidget);
    expect(find.text('Album Art'), findsOneWidget);
  });

  testWidgets('LocalPage song See Local sends Electron song path', (
    tester,
  ) async {
    _setLargeSurface(tester);
    String? revealedSongPath;

    await tester.pumpWidget(
      _LocalPageTestApp(
        snapshot: _snapshot,
        i18n: i18n,
        repository: _FakeLibraryRepository(),
        mediaController: MediaControlController(),
        onRevealItemInFolder: (path) {
          revealedSongPath = path;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('Root Song').first),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See In File Explorer'));
    await tester.pumpAndSettle();

    expect(revealedSongPath, r'C:\Music\root.mp3');
  });

  testWidgets('FolderChainListView opens Electron child folder flyout', (
    tester,
  ) async {
    _setLargeSurface(tester);
    var openedFolder = '';

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _localPageTestTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 500,
              child: FolderChainListView(
                songs: _snapshot.songs,
                folders: _snapshot.folders,
                i18n: i18n,
                rootPath: _snapshot.rootPath,
                currentRelativePath: '',
                onOpenFolder: (folderPath) {
                  openedFolder = folderPath;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('FolderChain.Dropdown.')));
    await tester.pumpAndSettle();
    expect(find.text('Sub'), findsWidgets);

    await tester.tap(find.text('Sub').last);
    await tester.pumpAndSettle();

    expect(openedFolder, 'Sub');
  });

  testWidgets('FolderChainListView checks current child without icon gap', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _localPageTestTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 500,
              child: FolderChainListView(
                songs: _snapshot.songs,
                folders: _snapshot.folders,
                i18n: i18n,
                rootPath: _snapshot.rootPath,
                currentRelativePath: 'Sub',
                onOpenFolder: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Sub'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('FolderChain.Dropdown.')));
    await tester.pumpAndSettle();

    final currentChild = find.byKey(const ValueKey('FolderChain.Child.Sub'));
    expect(currentChild, findsOneWidget);
    expect(find.byTooltip('Sub'), findsNWidgets(2));
    expect(
      find.descendant(
        of: currentChild,
        matching: find.byIcon(FluentIcons.checkmark_20_regular),
      ),
      findsOneWidget,
    );
    final textLeft = tester.getTopLeft(
      find.descendant(of: currentChild, matching: find.text('Sub')).last,
    );
    final itemLeft = tester.getTopLeft(currentChild);
    expect(textLeft.dx - itemLeft.dx, lessThan(24));
    expect(
      tester
          .getCenter(
            find
                .descendant(
                  of: currentChild,
                  matching: find.byIcon(FluentIcons.checkmark_20_regular),
                )
                .first,
          )
          .dx,
      greaterThan(tester.getCenter(find.text('Sub').last).dx),
    );
  });

  testWidgets('FolderChainListView sizes child flyout to folder names', (
    tester,
  ) async {
    _setLargeSurface(tester);
    const folderName = 'Take me to your summer vacation playlist';
    const folderPath = r'C:\Music\Take me to your summer vacation playlist';

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _localPageTestTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 700,
              child: FolderChainListView(
                songs: [
                  ..._snapshot.songs,
                  LibrarySong(
                    id: 3,
                    path:
                        r'C:\Music\Take me to your summer vacation playlist\song.mp3',
                    title: 'Long Folder Song',
                    artist: 'Artist C',
                    artists: ['Artist C'],
                    album: 'Long Folder Album',
                    duration: 90,
                    playCount: 0,
                    lyricsOffsetMs: 0,
                    dateAdded: '2026-05-20T00:00:00',
                    favorite: false,
                    thumbnailPath: '',
                  ),
                ],
                folders: [
                  ..._snapshot.folders,
                  LibraryFolder(
                    id: 90,
                    path: folderPath,
                    parentId: 0,
                    criterion: 0,
                  ),
                ],
                i18n: i18n,
                rootPath: _snapshot.rootPath,
                currentRelativePath: folderName,
                onOpenFolder: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('FolderChain.Dropdown.')));
    await tester.pumpAndSettle();

    expect(
      tester
          .getSize(find.byKey(ValueKey('FolderChain.Child.$folderName')))
          .width,
      greaterThan(300),
    );
  });

  testWidgets('FolderChainListView opens Electron context menu callback', (
    tester,
  ) async {
    _setLargeSurface(tester);
    String? menuFolderPath;
    Offset? menuPosition;

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _localPageTestTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 500,
              child: FolderChainListView(
                songs: _snapshot.songs,
                folders: _snapshot.folders,
                i18n: i18n,
                rootPath: _snapshot.rootPath,
                currentRelativePath: '',
                onOpenFolder: (_) {},
                onOpenFolderMenu: (folderPath, position) {
                  menuFolderPath = folderPath;
                  menuPosition = position;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('FolderChain.Path.')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(menuFolderPath, '');
    expect(menuPosition, isNotNull);
  });
}

ThemeData _localPageTestTheme([Brightness brightness = Brightness.light]) {
  final dark = brightness == Brightness.dark;
  return ThemeData(
    brightness: brightness,
    extensions: [
      dark ? AppNotificationThemeColors.dark : AppNotificationThemeColors.light,
      dark
          ? DefaultAlbumArtworkThemeColors.dark
          : DefaultAlbumArtworkThemeColors.light,
      dark
          ? MissingLibraryRootThemeColors.night
          : MissingLibraryRootThemeColors.day,
      dark ? LocalPageColors.night : LocalPageColors.day,
    ],
  );
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(2000, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void _setCompactSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(640, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pressTextButtonByLabel(WidgetTester tester, String label) async {
  await _pressCommandBarButton(tester, label);
  await tester.pumpAndSettle();
}

Finder _findVisibleCommandBarButton(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is CommandBarButton && widget.label == label,
  );
}

Future<void> _dismissTransientNotifications(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

Future<void> _openFolderContextMenu(
  WidgetTester tester,
  String folderName,
) async {
  await tester.tapAt(
    tester.getCenter(find.text(folderName).first),
    buttons: kSecondaryMouseButton,
  );
  await tester.pumpAndSettle();
}

Future<void> _dragTextToText(
  WidgetTester tester,
  String sourceText,
  String targetText,
) async {
  final start = tester.getCenter(find.text(sourceText).first);
  final end = tester.getCenter(find.text(targetText).first);
  await tester.dragFrom(start, end - start);
  await tester.pumpAndSettle();
}

Future<void> _tapPopupAction(WidgetTester tester, String label) async {
  tester
      .widget<PopupDialogActionButton>(
        find.widgetWithText(PopupDialogActionButton, label).last,
      )
      .onPressed!();
}

TestGesture? _hoverGesture;

Future<void> _hoverText(WidgetTester tester, String text) async {
  final center = tester.getCenter(find.text(text).first);
  if (_hoverGesture == null) {
    _hoverGesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await _hoverGesture!.addPointer(location: center);
    addTearDown(() async {
      await _hoverGesture?.removePointer();
      _hoverGesture = null;
    });
  }
  await _hoverGesture!.moveTo(center);
  await tester.pump();
}

Finder _nearestArtworkAction(
  WidgetTester tester,
  String tooltip,
  String anchorText,
) {
  final anchor = tester.getCenter(find.text(anchorText).first);
  final elements =
      find
          .byWidgetPredicate(
            (widget) =>
                widget is ArtworkFloatingActionButton &&
                widget.tooltip == tooltip,
          )
          .evaluate()
          .toList()
        ..sort((left, right) {
          final leftFinder = find.byElementPredicate(
            (element) => element == left,
          );
          final rightFinder = find.byElementPredicate(
            (element) => element == right,
          );
          return (tester.getCenter(leftFinder) - anchor).distance.compareTo(
            (tester.getCenter(rightFinder) - anchor).distance,
          );
        });
  return find.byElementPredicate((element) => element == elements.first);
}

Finder _richTextContaining(String value) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText().contains(value),
  );
}

void _pressBottomTooltipIconButton(WidgetTester tester, String tooltip) {
  final elements =
      find
          .byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == tooltip,
          )
          .evaluate()
          .toList();
  elements.sort((left, right) {
    final leftCenter = tester.getCenter(
      find.byElementPredicate((element) {
        return element == left;
      }),
    );
    final rightCenter = tester.getCenter(
      find.byElementPredicate((element) {
        return element == right;
      }),
    );
    return leftCenter.dy.compareTo(rightCenter.dy);
  });
  final bottomTooltip = find.byElementPredicate(
    (element) => element == elements.last,
  );
  tester.widget<IconButton>(bottomTooltip).onPressed!();
}

Future<void> _pressCommandBarButton(WidgetTester tester, String label) async {
  final button = _findVisibleCommandBarButton(label);
  if (button.evaluate().isNotEmpty) {
    tester.widget<CommandBarButton>(button.first).onPressed!();
    return;
  }

  await tester.tap(find.byTooltip('More').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).first);
}

List<String> _flattenMenuFlyoutLabels(List<MenuFlyoutItem> items) {
  return [
    for (final item in items) ...[
      if (item.text.isNotEmpty) item.text,
      ..._flattenMenuFlyoutLabels(item.submenu),
    ],
  ];
}

class _LocalPageTestApp extends StatelessWidget {
  const _LocalPageTestApp({
    required this.snapshot,
    required this.i18n,
    required this.repository,
    required this.mediaController,
    this.currentRelativePath = '',
    this.onPickLibraryRoot,
    this.onScanLibrary,
    this.onOpenFolderInShell,
    this.onRevealItemInFolder,
  });

  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final LibraryRepository repository;
  final MediaControlController mediaController;
  final String currentRelativePath;
  final Future<String?> Function()? onPickLibraryRoot;
  final LocalScanLibraryCallback? onScanLibrary;
  final LocalPathAction? onOpenFolderInShell;
  final LocalPathAction? onRevealItemInFolder;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
        libraryRepositoryProvider.overrideWithValue(repository),
        mediaControlControllerProvider.overrideWith((ref) => mediaController),
        if (onOpenFolderInShell != null)
          localPageOpenFolderInShellProvider.overrideWithValue(
            onOpenFolderInShell!,
          ),
        if (onRevealItemInFolder != null)
          localPageRevealItemInFolderProvider.overrideWithValue(
            onRevealItemInFolder!,
          ),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _localPageTestTheme(),
          home: Scaffold(
            body: LocalPage(
              currentRelativePath: currentRelativePath,
              onPickLibraryRoot: onPickLibraryRoot,
              onScanLibrary: onScanLibrary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalPageLoadingTestApp extends StatelessWidget {
  const _LocalPageLoadingTestApp({
    required this.snapshotFuture,
    required this.i18n,
    required this.repository,
    required this.mediaController,
  });

  final Future<LibraryContentData> snapshotFuture;
  final SmPlayerI18n i18n;
  final LibraryRepository repository;
  final MediaControlController mediaController;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryContentDataProvider.overrideWith((ref) => snapshotFuture),
        libraryRepositoryProvider.overrideWithValue(repository),
        mediaControlControllerProvider.overrideWith((ref) => mediaController),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _localPageTestTheme(),
          home: const Scaffold(body: LocalPage()),
        ),
      ),
    );
  }
}

class _LocalPageRouterTestApp extends StatelessWidget {
  const _LocalPageRouterTestApp({
    required this.snapshot,
    required this.i18n,
    required this.repository,
    required this.mediaController,
    this.initialLocation = '/local',
    this.snapshotFuture,
  });

  final LibraryContentData snapshot;
  final Future<LibraryContentData>? snapshotFuture;
  final SmPlayerI18n i18n;
  final LibraryRepository repository;
  final MediaControlController mediaController;
  final String initialLocation;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/local',
          builder:
              (_, state) => Scaffold(
                body: LocalPage(
                  currentRelativePath: state.uri.queryParameters['path'] ?? '',
                  searchQuery: state.uri.queryParameters['query'] ?? '',
                ),
              ),
        ),
        GoRoute(
          path: '/search',
          builder:
              (_, state) => Scaffold(
                body: Text(
                  'search:${state.uri.queryParameters['query']}:'
                  '${state.uri.queryParameters['type']}:'
                  '${state.uri.queryParameters['folder']}',
                ),
              ),
        ),
        GoRoute(
          path: '/hidden-folders',
          builder: (_, _) => const Scaffold(body: HiddenFoldersPage()),
        ),
        GoRoute(
          path: '/artists',
          builder:
              (_, state) => Scaffold(
                body: Text('artist:${state.uri.queryParameters['artist']}'),
              ),
        ),
        GoRoute(
          path: '/albums',
          builder:
              (_, state) => Scaffold(
                body: Text('album:${state.uri.queryParameters['album']}'),
              ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryContentDataProvider.overrideWith(
          (ref) => snapshotFuture ?? Future.value(snapshot),
        ),
        libraryRepositoryProvider.overrideWithValue(repository),
        mediaControlControllerProvider.overrideWith((ref) => mediaController),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp.router(
          theme: _localPageTestTheme(),
          routerConfig: router,
        ),
      ),
    );
  }
}

class _LocalPageSearchQueryTestApp extends StatelessWidget {
  const _LocalPageSearchQueryTestApp({
    required this.snapshot,
    required this.i18n,
    required this.repository,
    required this.mediaController,
    required this.searchQuery,
  });

  final LibraryContentData snapshot;
  final SmPlayerI18n i18n;
  final LibraryRepository repository;
  final MediaControlController mediaController;
  final ValueNotifier<String> searchQuery;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        smPlayerI18nProvider.overrideWith((ref) async => i18n),
        libraryContentDataProvider.overrideWith((ref) async => snapshot),
        libraryRepositoryProvider.overrideWithValue(repository),
        mediaControlControllerProvider.overrideWith((ref) => mediaController),
      ],
      child: SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          theme: _localPageTestTheme(),
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: searchQuery,
              builder: (_, query, _) => LocalPage(searchQuery: query),
            ),
          ),
        ),
      ),
    );
  }
}

class _FakeLibraryRepository extends LibraryRepository {
  List<int> replacedNowPlaying = [];
  int? addedPlaylistId;
  List<int> addedSongIds = [];
  List<int> favoriteSongIds = [];
  bool? favoriteValue;
  String? updatedSortFolderPath;
  LocalFolderSortCriterion? updatedSortCriterion;
  String? recentSearchQuery;
  SearchHistoryType? recentSearchType;
  int? movedSongId;
  String? movedSongTargetFolderPath;
  List<int> movedSongIds = [];
  List<String> movedFolderPaths = [];
  String? movedTargetFolderPath;
  List<int> deletedSongIds = [];
  List<String> deletedFolderPaths = [];
  List<String> undoneLocalDeleteIds = [];
  List<String> committedLocalDeleteIds = [];
  String? hiddenFolderPath;
  String? renamedFolderPath;
  String? renamedFolderName;
  String? preferenceType;
  String? preferenceItemId;
  String? preferenceName;
  String? preferenceLevel;
  AppSettingsUpdate? settingsUpdate;
  String? refreshedFolderPath;
  int refreshCallCount = 0;
  Object? refreshError;
  Completer<LocalFolderRefreshResult>? refreshCompleter;
  ({String rootPath, String relativePath, String name})? createdLocalFolder;
  String? scannedRootPath;
  List<HiddenStorageItem> hiddenItems = [];
  Completer<List<HiddenStorageItem>>? hiddenItemsCompleter;
  HiddenStorageItem? resumedHiddenItem;
  LocalFolderRefreshResult refreshResult = const LocalFolderRefreshResult(
    filesAdded: [],
    filesRemoved: [],
    filesMoved: [],
    artistSplitsApplied: [],
    artistSplitSuggestions: [],
    artistMergeSuggestions: [],
  );
  int? hiddenSongId;

  @override
  Future<void> replaceNowPlaying(List<int> songIds) async {
    replacedNowPlaying = songIds.toList();
  }

  @override
  Future<void> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    addedPlaylistId = playlistId;
    addedSongIds = songIds.toList();
  }

  @override
  Future<void> setSongsFavorite(List<int> songIds, bool favorite) async {
    favoriteSongIds = songIds.toList();
    favoriteValue = favorite;
  }

  @override
  Future<void> updateLocalFolderSort(
    String folderPath,
    LocalFolderSortCriterion criterion,
  ) async {
    updatedSortFolderPath = folderPath;
    updatedSortCriterion = criterion;
  }

  @override
  Future<SearchHistoryEntry?> addRecentSearch(
    String query, [
    SearchHistoryType type = SearchHistoryType.sidebar,
  ]) async {
    recentSearchQuery = query;
    recentSearchType = type;
    return SearchHistoryEntry(
      id: 1,
      query: query.trim(),
      type: type,
      searchedAt: '2026-05-23T00:00:00Z',
    );
  }

  @override
  Future<LocalItemsMoveResult> moveLocalItemsToFolder(
    List<int> songIds,
    List<String> folderPaths,
    String targetFolderPath, {
    LocalMoveConflictResolver? resolveConflict,
  }) async {
    movedSongIds = songIds.toList();
    movedFolderPaths = folderPaths.toList();
    movedTargetFolderPath = targetFolderPath;
    return LocalItemsMoveResult(
      songs: [
        for (final songId in songIds)
          LocalSongMove(
            id: songId,
            oldPath: 'old-$songId.mp3',
            newPath: 'new-$songId.mp3',
          ),
      ],
      folders: [
        for (final folderPath in folderPaths)
          LocalFolderMove(
            oldPath: folderPath,
            newPath: '$targetFolderPath/moved',
          ),
      ],
    );
  }

  @override
  Future<void> undoMoveLocalItems(LocalItemsMoveResult result) async {
    movedSongIds = [];
    movedFolderPaths = [];
    movedTargetFolderPath = null;
    movedSongId = null;
    movedSongTargetFolderPath = null;
  }

  @override
  Future<LocalItemsMoveResult> moveSongToFolder(
    int songId,
    String folderPath, {
    LocalMoveConflictResolver? resolveConflict,
  }) async {
    movedSongId = songId;
    movedSongTargetFolderPath = folderPath;
    return LocalItemsMoveResult(
      songs: [
        LocalSongMove(
          id: songId,
          oldPath: 'old-$songId.mp3',
          newPath: '$folderPath/$songId.mp3',
        ),
      ],
      folders: const [],
    );
  }

  @override
  Future<LocalFolderRefreshResult> refreshLocalFolder(
    String folderPath, {
    void Function(LocalFolderRefreshProgress progress)? onProgress,
    LocalFolderScanCancellation? cancellation,
  }) async {
    refreshCallCount += 1;
    final error = refreshError;
    if (error != null) {
      throw error;
    }
    refreshedFolderPath = folderPath;
    onProgress?.call(
      LocalFolderRefreshProgress(
        current: refreshResult.filesAdded.length,
        total: refreshResult.filesAdded.length + 1,
        currentPath:
            refreshResult.filesAdded.isEmpty
                ? ''
                : refreshResult.filesAdded.last,
      ),
    );
    final completer = refreshCompleter;
    if (completer != null) {
      return completer.future;
    }
    return refreshResult;
  }

  @override
  Future<LocalFolderRefreshResult> createLocalFolder(
    String rootPath,
    String relativePath,
    String name, {
    void Function(LocalFolderRefreshProgress progress)? onProgress,
    LocalFolderScanCancellation? cancellation,
  }) async {
    createdLocalFolder = (
      rootPath: rootPath,
      relativePath: relativePath,
      name: name,
    );
    final folderPath =
        relativePath.isEmpty
            ? rootPath
            : '$rootPath${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}';
    refreshedFolderPath = folderPath;
    await Directory(
      '$folderPath${Platform.pathSeparator}$name',
    ).create(recursive: true);
    return refreshResult;
  }

  @override
  Future<LocalFolderRefreshResult> scanAllMusicLibrary(
    String rootPath, {
    void Function(LocalFolderRefreshProgress progress)? onProgress,
    LocalFolderScanCancellation? cancellation,
  }) async {
    scannedRootPath = rootPath;
    onProgress?.call(
      LocalFolderRefreshProgress(
        current: refreshResult.filesAdded.length,
        total: refreshResult.filesAdded.length + 1,
        currentPath:
            refreshResult.filesAdded.isEmpty
                ? ''
                : refreshResult.filesAdded.last,
      ),
    );
    return refreshResult;
  }

  @override
  Future<PendingLocalItemsDelete> beginDeleteLocalItems(
    List<int> songIds,
    List<String> folderPaths,
  ) async {
    deletedSongIds = songIds.toList();
    deletedFolderPaths = folderPaths.toList();
    return PendingLocalItemsDelete(
      id: 'pending-local-${folderPaths.length}-${songIds.length}',
      songIds: deletedSongIds,
      folderPaths: deletedFolderPaths,
    );
  }

  @override
  Future<void> undoDeleteLocalItems(String deleteId) async {
    undoneLocalDeleteIds.add(deleteId);
  }

  @override
  Future<void> commitDeleteLocalItems(String deleteId) async {
    committedLocalDeleteIds.add(deleteId);
  }

  @override
  Future<void> hideFolder(String folderPath) async {
    hiddenFolderPath = folderPath;
  }

  @override
  Future<void> hideSong(int songId) async {
    hiddenSongId = songId;
  }

  @override
  Future<void> unhideSong(int songId) async {
    hiddenSongId = null;
  }

  @override
  Future<void> unhideFolder(String folderPath) async {
    hiddenFolderPath = null;
  }

  @override
  Future<List<HiddenStorageItem>> getHiddenStorageItems() async {
    final completer = hiddenItemsCompleter;
    if (completer != null) {
      return completer.future;
    }
    return hiddenItems;
  }

  @override
  Future<void> resumeHiddenStorageItem(HiddenStorageItem item) async {
    resumedHiddenItem = item;
    hiddenItems = [
      for (final hiddenItem in hiddenItems)
        if (hiddenItem.id != item.id) hiddenItem,
    ];
  }

  @override
  Future<void> renameFolder(String folderPath, String name) async {
    renamedFolderPath = folderPath;
    renamedFolderName = name;
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
    return null;
  }

  @override
  Future<void> updateSettings(AppSettingsUpdate update) async {
    settingsUpdate = update;
  }

  @override
  Future<SongPropertiesSnapshot> getSongProperties(int songId) async {
    return SongPropertiesSnapshot(
      songId: songId,
      path: r'C:\Music\root.mp3',
      title: 'Root Song',
      subtitle: '',
      artist: 'Artist A',
      artists: const ['Artist A'],
      album: 'Root Album',
      albumArtist: '',
      publisher: '',
      trackNumber: 0,
      year: 0,
      genre: '',
      composers: '',
      duration: 120,
      bitrate: 0,
      fileSize: 1024,
      dateCreated: '2026-01-01T00:00:00Z',
      dateModified: '2026-01-01T00:00:00Z',
      fileType: 'MP3',
      playCount: 0,
    );
  }

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

const _snapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\root.mp3',
      title: 'Root Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Root Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 2,
      path: r'C:\Music\Sub\child.mp3',
      title: 'Child Song',
      artist: 'Artist B',
      artists: ['Artist B'],
      album: 'Child Album',
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
      id: 20,
      name: 'My Favorites',
      priority: 0,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: true,
    ),
    LibraryPlaylist(
      id: 30,
      name: 'Road Mix',
      priority: 1,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
  ],
  folders: [
    LibraryFolder(id: 10, path: r'C:\Music\Sub', parentId: 0, criterion: 0),
  ],
  favoritePlaylistId: 20,
  nowPlaying: NowPlayingSnapshot(playlistId: 9, songIds: [9]),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  rootPath: r'C:\Music',
  databasePath: '',
);

final _snapshotWithMultipleRootSongs = LibraryContentData(
  songs: [
    ..._snapshot.songs,
    LibrarySong(
      id: 3,
      path: r'C:\Music\second-root.mp3',
      title: 'Second Root',
      artist: 'Artist C',
      artists: ['Artist C'],
      album: 'Root Album',
      duration: 150,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
  ],
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
  hideMultiSelectCommandBarAfterOperation:
      _snapshot.hideMultiSelectCommandBarAfterOperation,
  rootPath: _snapshot.rootPath,
  databasePath: _snapshot.databasePath,
);

final _snapshotWithoutFolders = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\root.mp3',
      title: 'Root Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Root Album',
      duration: 120,
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
  playlists: _snapshot.playlists,
  folders: [],
  favoritePlaylistId: 20,
  nowPlaying: NowPlayingSnapshot(playlistId: 9, songIds: [9]),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  rootPath: r'C:\Music',
  databasePath: '',
);

final _folderOnlySnapshot = LibraryContentData(
  songs: const [],
  recentSongs: const [],
  recentPlaylists: const [],
  recentAlbums: const [],
  recentArtists: const [],
  recentSearches: const [],
  playlists: _snapshot.playlists,
  folders: const [
    LibraryFolder(id: 10, path: r'C:\Music\Sub', parentId: 0, criterion: 0),
    LibraryFolder(id: 11, path: r'C:\Music\Target', parentId: 0, criterion: 0),
  ],
  favoritePlaylistId: 20,
  nowPlaying: NowPlayingSnapshot(playlistId: 9, songIds: [9]),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  rootPath: r'C:\Music',
  databasePath: '',
);

final _nestedSnapshot = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\root.mp3',
      title: 'Root Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Root Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 2,
      path: r'C:\Music\Sub\child.mp3',
      title: 'Child Song',
      artist: 'Artist B',
      artists: ['Artist B'],
      album: 'Child Album',
      duration: 90,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 3,
      path: r'C:\Music\Sub\Deep\deep.mp3',
      title: 'Deep Song',
      artist: 'Artist C',
      artists: ['Artist C'],
      album: 'Deep Album',
      duration: 150,
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
  playlists: _snapshot.playlists,
  folders: [
    LibraryFolder(id: 10, path: r'C:\Music\Sub', parentId: 0, criterion: 0),
    LibraryFolder(
      id: 11,
      path: r'C:\Music\Sub\Deep',
      parentId: 10,
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
  rootPath: r'C:\Music',
  databasePath: '',
);

final _dragSelectionSnapshot = LibraryContentData(
  songs: [
    const LibrarySong(
      id: 1,
      path: r'C:\Music\root.mp3',
      title: 'Root Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Root Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    const LibrarySong(
      id: 3,
      path: r'C:\Music\second.mp3',
      title: 'Second Song',
      artist: 'Artist C',
      artists: ['Artist C'],
      album: 'Second Album',
      duration: 130,
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
  folders: const [
    LibraryFolder(id: 10, path: r'C:\Music\Sub', parentId: 0, criterion: 0),
    LibraryFolder(id: 11, path: r'C:\Music\Other', parentId: 0, criterion: 0),
    LibraryFolder(id: 12, path: r'C:\Music\Target', parentId: 0, criterion: 0),
  ],
  favoritePlaylistId: 20,
  nowPlaying: NowPlayingSnapshot(playlistId: 9, songIds: [9]),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  rootPath: r'C:\Music',
  databasePath: '',
);

LibraryContentData _snapshotWithSongs(List<LibrarySong> songs) {
  return LibraryContentData(
    songs: songs,
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
    hideMultiSelectCommandBarAfterOperation:
        _snapshot.hideMultiSelectCommandBarAfterOperation,
    rootPath: _snapshot.rootPath,
    databasePath: _snapshot.databasePath,
  );
}

LibraryContentData _snapshotWithHideAfterOperation(bool hideAfterOperation) {
  return LibraryContentData(
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
    hideMultiSelectCommandBarAfterOperation: hideAfterOperation,
    rootPath: _snapshot.rootPath,
    databasePath: _snapshot.databasePath,
  );
}

LibrarySong _localTestSong({
  required int id,
  required String path,
  required String title,
}) {
  return LibrarySong(
    id: id,
    path: path,
    title: title,
    artist: 'Artist A',
    artists: const ['Artist A'],
    album: 'Root Album',
    duration: 120,
    playCount: 0,
    lyricsOffsetMs: 0,
    dateAdded: '2026-05-20T00:00:00',
    favorite: false,
    thumbnailPath: '',
  );
}

const _snapshotWithTargetFolder = LibraryContentData(
  songs: [
    LibrarySong(
      id: 1,
      path: r'C:\Music\root.mp3',
      title: 'Root Song',
      artist: 'Artist A',
      artists: ['Artist A'],
      album: 'Root Album',
      duration: 120,
      playCount: 0,
      lyricsOffsetMs: 0,
      dateAdded: '2026-05-20T00:00:00',
      favorite: false,
      thumbnailPath: '',
    ),
    LibrarySong(
      id: 2,
      path: r'C:\Music\Sub\child.mp3',
      title: 'Child Song',
      artist: 'Artist B',
      artists: ['Artist B'],
      album: 'Child Album',
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
      id: 20,
      name: 'My Favorites',
      priority: 0,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: true,
    ),
    LibraryPlaylist(
      id: 30,
      name: 'Road Mix',
      priority: 1,
      songCount: 0,
      songIds: [],
      sortCriterion: PlaylistSortCriterion.title,
      isBuiltIn: false,
    ),
  ],
  folders: [
    LibraryFolder(id: 10, path: r'C:\Music\Sub', parentId: 0, criterion: 0),
    LibraryFolder(id: 11, path: r'C:\Music\Target', parentId: 0, criterion: 0),
  ],
  favoritePlaylistId: 20,
  nowPlaying: NowPlayingSnapshot(playlistId: 9, songIds: [9]),
  hasLibrary: true,
  sortCriterion: MusicLibrarySortCriterion.title,
  albumsSort: AlbumSortCriterion.defaultSort,
  showCount: true,
  hideMultiSelectCommandBarAfterOperation: true,
  rootPath: r'C:\Music',
  databasePath: '',
);

LibraryContentData _snapshotWithLocalViewMode(LocalViewMode localViewMode) {
  return LibraryContentData(
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
    hideMultiSelectCommandBarAfterOperation:
        _snapshot.hideMultiSelectCommandBarAfterOperation,
    localViewMode: localViewMode,
    rootPath: _snapshot.rootPath,
    databasePath: _snapshot.databasePath,
  );
}

LibraryContentData _snapshotWithRootCriterion(int criterion) {
  return LibraryContentData(
    songs: _snapshot.songs,
    recentSongs: _snapshot.recentSongs,
    recentPlaylists: _snapshot.recentPlaylists,
    recentAlbums: _snapshot.recentAlbums,
    recentArtists: _snapshot.recentArtists,
    recentSearches: _snapshot.recentSearches,
    playlists: _snapshot.playlists,
    folders: [
      LibraryFolder(
        id: 99,
        path: _snapshot.rootPath,
        parentId: 0,
        criterion: criterion,
      ),
      ..._snapshot.folders,
    ],
    favoritePlaylistId: _snapshot.favoritePlaylistId,
    nowPlaying: _snapshot.nowPlaying,
    hasLibrary: _snapshot.hasLibrary,
    sortCriterion: _snapshot.sortCriterion,
    albumsSort: _snapshot.albumsSort,
    showCount: _snapshot.showCount,
    hideMultiSelectCommandBarAfterOperation:
        _snapshot.hideMultiSelectCommandBarAfterOperation,
    rootPath: _snapshot.rootPath,
    databasePath: _snapshot.databasePath,
  );
}

LibraryContentData _snapshotWithSubCriterion(int criterion) {
  return LibraryContentData(
    songs: _snapshot.songs,
    recentSongs: _snapshot.recentSongs,
    recentPlaylists: _snapshot.recentPlaylists,
    recentAlbums: _snapshot.recentAlbums,
    recentArtists: _snapshot.recentArtists,
    recentSearches: _snapshot.recentSearches,
    playlists: _snapshot.playlists,
    folders: [
      LibraryFolder(
        id: 10,
        path: r'C:\Music\Sub',
        parentId: 0,
        criterion: criterion,
      ),
    ],
    favoritePlaylistId: _snapshot.favoritePlaylistId,
    nowPlaying: _snapshot.nowPlaying,
    hasLibrary: _snapshot.hasLibrary,
    sortCriterion: _snapshot.sortCriterion,
    albumsSort: _snapshot.albumsSort,
    showCount: _snapshot.showCount,
    hideMultiSelectCommandBarAfterOperation:
        _snapshot.hideMultiSelectCommandBarAfterOperation,
    rootPath: _snapshot.rootPath,
    databasePath: _snapshot.databasePath,
  );
}

LibraryContentData _snapshotWithTargetFolderAndLocalViewMode(
  LocalViewMode localViewMode,
) {
  return LibraryContentData(
    songs: _snapshotWithTargetFolder.songs,
    recentSongs: _snapshotWithTargetFolder.recentSongs,
    recentPlaylists: _snapshotWithTargetFolder.recentPlaylists,
    recentAlbums: _snapshotWithTargetFolder.recentAlbums,
    recentArtists: _snapshotWithTargetFolder.recentArtists,
    recentSearches: _snapshotWithTargetFolder.recentSearches,
    playlists: _snapshotWithTargetFolder.playlists,
    folders: _snapshotWithTargetFolder.folders,
    favoritePlaylistId: _snapshotWithTargetFolder.favoritePlaylistId,
    nowPlaying: _snapshotWithTargetFolder.nowPlaying,
    hasLibrary: _snapshotWithTargetFolder.hasLibrary,
    sortCriterion: _snapshotWithTargetFolder.sortCriterion,
    albumsSort: _snapshotWithTargetFolder.albumsSort,
    showCount: _snapshotWithTargetFolder.showCount,
    hideMultiSelectCommandBarAfterOperation:
        _snapshotWithTargetFolder.hideMultiSelectCommandBarAfterOperation,
    localViewMode: localViewMode,
    rootPath: _snapshotWithTargetFolder.rootPath,
    databasePath: _snapshotWithTargetFolder.databasePath,
  );
}

LibraryContentData _manyLocalSongsSnapshot(
  LocalViewMode localViewMode,
  int count,
) {
  return LibraryContentData(
    songs: [
      for (var index = 0; index < count; index += 1)
        LibrarySong(
          id: index + 1,
          path:
              r'C:\Music\song'
              '$index.mp3',
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
    ],
    recentSongs: const [],
    recentPlaylists: const [],
    recentAlbums: const [],
    recentArtists: const [],
    recentSearches: const [],
    playlists: _snapshot.playlists,
    folders: const [],
    favoritePlaylistId: _snapshot.favoritePlaylistId,
    nowPlaying: _snapshot.nowPlaying,
    hasLibrary: true,
    sortCriterion: MusicLibrarySortCriterion.title,
    albumsSort: AlbumSortCriterion.defaultSort,
    showCount: true,
    hideMultiSelectCommandBarAfterOperation: true,
    localViewMode: localViewMode,
    rootPath: r'C:\Music',
    databasePath: '',
  );
}

LibraryContentData _alphabetLocalSongsSnapshot(LocalViewMode localViewMode) {
  const prefixes = ['Alpha', 'Bravo', 'Charlie', 'Delta'];
  return LibraryContentData(
    songs: [
      for (var prefixIndex = 0; prefixIndex < prefixes.length; prefixIndex += 1)
        for (var index = 0; index < 20; index += 1)
          LibrarySong(
            id: prefixIndex * 20 + index + 1,
            path:
                r'C:\Music\'
                '${prefixes[prefixIndex].toLowerCase()}$index.mp3',
            title:
                '${prefixes[prefixIndex]} Song '
                '${index.toString().padLeft(2, '0')}',
            artist: '${prefixes[prefixIndex]} Artist',
            artists: ['${prefixes[prefixIndex]} Artist'],
            album: '${prefixes[prefixIndex]} Album',
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
    folders: const [],
    favoritePlaylistId: _snapshot.favoritePlaylistId,
    nowPlaying: _snapshot.nowPlaying,
    hasLibrary: true,
    sortCriterion: MusicLibrarySortCriterion.title,
    albumsSort: AlbumSortCriterion.defaultSort,
    showCount: true,
    hideMultiSelectCommandBarAfterOperation: true,
    localViewMode: localViewMode,
    rootPath: r'C:\Music',
    databasePath: '',
  );
}

LibraryContentData _artistQuickJumpSnapshot(LocalViewMode localViewMode) {
  const artistPrefixes = ['Alpha', 'Bravo', 'Charlie', 'Delta'];
  return LibraryContentData(
    songs: [
      for (
        var prefixIndex = 0;
        prefixIndex < artistPrefixes.length;
        prefixIndex += 1
      )
        for (var index = 0; index < 20; index += 1)
          LibrarySong(
            id: prefixIndex * 20 + index + 1,
            path:
                r'C:\Music\track'
                '${(prefixIndex * 20 + index).toString().padLeft(2, '0')}.mp3',
            title:
                'Track '
                '${(prefixIndex * 20 + index).toString().padLeft(2, '0')}',
            artist: '${artistPrefixes[prefixIndex]} Artist',
            artists: ['${artistPrefixes[prefixIndex]} Artist'],
            album: 'Shared Album',
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
    folders: const [
      LibraryFolder(id: 99, path: r'C:\Music', parentId: 0, criterion: 1),
    ],
    favoritePlaylistId: _snapshot.favoritePlaylistId,
    nowPlaying: _snapshot.nowPlaying,
    hasLibrary: true,
    sortCriterion: MusicLibrarySortCriterion.title,
    albumsSort: AlbumSortCriterion.defaultSort,
    showCount: true,
    hideMultiSelectCommandBarAfterOperation: true,
    localViewMode: localViewMode,
    rootPath: r'C:\Music',
    databasePath: '',
  );
}

LibraryContentData _albumQuickJumpSnapshot(LocalViewMode localViewMode) {
  const albumPrefixes = ['Alpha', 'Bravo', 'Charlie', 'Delta'];
  return LibraryContentData(
    songs: [
      for (
        var prefixIndex = 0;
        prefixIndex < albumPrefixes.length;
        prefixIndex += 1
      )
        for (var index = 0; index < 20; index += 1)
          LibrarySong(
            id: prefixIndex * 20 + index + 1,
            path:
                r'C:\Music\album-track'
                '${(prefixIndex * 20 + index).toString().padLeft(2, '0')}.mp3',
            title:
                'Track '
                '${(prefixIndex * 20 + index).toString().padLeft(2, '0')}',
            artist: 'Shared Artist',
            artists: const ['Shared Artist'],
            album: '${albumPrefixes[prefixIndex]} Album',
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
    folders: const [
      LibraryFolder(id: 99, path: r'C:\Music', parentId: 0, criterion: 2),
    ],
    favoritePlaylistId: _snapshot.favoritePlaylistId,
    nowPlaying: _snapshot.nowPlaying,
    hasLibrary: true,
    sortCriterion: MusicLibrarySortCriterion.title,
    albumsSort: AlbumSortCriterion.defaultSort,
    showCount: true,
    hideMultiSelectCommandBarAfterOperation: true,
    localViewMode: localViewMode,
    rootPath: r'C:\Music',
    databasePath: '',
  );
}

LibraryContentData _snapshotWithRoot(String rootPath) {
  return LibraryContentData(
    songs: [
      LibrarySong(
        id: 1,
        path: '$rootPath${Platform.pathSeparator}root.mp3',
        title: 'Root Song',
        artist: 'Artist A',
        artists: const ['Artist A'],
        album: 'Root Album',
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
    playlists: const [
      LibraryPlaylist(
        id: 20,
        name: 'My Favorites',
        priority: 0,
        songCount: 0,
        songIds: [],
        sortCriterion: PlaylistSortCriterion.title,
        isBuiltIn: true,
      ),
    ],
    folders: const [],
    favoritePlaylistId: 20,
    nowPlaying: const NowPlayingSnapshot(playlistId: 9, songIds: [9]),
    hasLibrary: true,
    sortCriterion: MusicLibrarySortCriterion.title,
    albumsSort: AlbumSortCriterion.defaultSort,
    showCount: true,
    hideMultiSelectCommandBarAfterOperation: true,
    rootPath: rootPath,
    databasePath: '',
  );
}

LibraryContentData _emptySnapshotWithRoot(String rootPath) {
  return LibraryContentData(
    songs: const [],
    recentSongs: const [],
    recentPlaylists: const [],
    recentAlbums: const [],
    recentArtists: const [],
    recentSearches: const [],
    playlists: const [
      LibraryPlaylist(
        id: 20,
        name: 'My Favorites',
        priority: 0,
        songCount: 0,
        songIds: [],
        sortCriterion: PlaylistSortCriterion.title,
        isBuiltIn: true,
      ),
    ],
    folders: const [],
    favoritePlaylistId: 20,
    nowPlaying: const NowPlayingSnapshot(playlistId: 9, songIds: [9]),
    hasLibrary: rootPath.isNotEmpty,
    sortCriterion: MusicLibrarySortCriterion.title,
    albumsSort: AlbumSortCriterion.defaultSort,
    showCount: true,
    hideMultiSelectCommandBarAfterOperation: true,
    rootPath: rootPath,
    databasePath: '',
  );
}
