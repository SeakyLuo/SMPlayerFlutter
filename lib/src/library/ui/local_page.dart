import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/input_dialog.dart';
import '../../app/loading_state.dart';
import '../../app/smplayer_vector_icons.dart';
import '../../app/undoable_notification.dart';
import '../../app/workspace_app_bar_portal.dart';
import '../../i18n/app_i18n.dart';
import '../../playback/media_control_provider.dart';
import '../../playback/playback_queue_actions.dart';
import '../../platform/desktop_feature_service.dart';
import '../data/library_models.dart';
import '../data/library_providers.dart';
import 'artists_page_model.dart';
import 'command_bar.dart';
import 'menu_flyout.dart';
import 'menu_flyout_helpers.dart';
import 'multi_select_command_bar.dart';
import 'headered_playlist_model.dart'
    show getNextPlaylistName, validatePlaylistName;
import 'library_page_actions.dart'
    show
        addSongsToNowPlayingWithUndo,
        addSongsToPlaylistWithUndo,
        createPlaylistAndSync,
        hideSongFileWithUndo,
        moveSongToFolderWithUndo,
        requestLocalMoveConflictResolution,
        requestDeleteSongFromDisk,
        setSongsFavoriteWithUndo,
        showPlayNextUndoNotification;
import 'local_folder_model.dart';
import 'library_page_data_cache.dart';
import 'local_content_view.dart';
import 'local_i18n_counts.dart';
import 'local_page_empty_content.dart';
import 'local_move_to_folder_menu.dart';
import 'local_page_model.dart';
import 'scan_progress_overlay.dart';
import 'folder_update_result_dialog.dart';
import 'local_page_quick_jump.dart';
import 'local_page_shell.dart';
import 'local_title_grid.dart';
import 'music_dialog.dart';

part 'local_page_content.dart';
part 'local_page_context_menus.dart';
part 'local_page_selection_actions.dart';
part 'local_page_scan_actions.dart';
part 'local_page_file_actions.dart';
part 'local_page_playback_actions.dart';
part 'local_page_folder_actions.dart';
part 'local_page_add_to_actions.dart';

const localCompactBreakpoint = 720.0;

typedef LocalScanLibraryCallback =
    FutureOr<LocalFolderRefreshResult> Function(
      String rootPath, {
      LocalFolderScanCancellation? cancellation,
      void Function(LocalFolderRefreshProgress progress)? onProgress,
    });

typedef LocalPathAction = FutureOr<void> Function(String path);

final localPageOpenFolderInShellProvider = Provider<LocalPathAction>((ref) {
  return openFolderInShell;
});

final localPageRevealItemInFolderProvider = Provider<LocalPathAction>((ref) {
  return revealItemInFolder;
});

class LocalPage extends ConsumerStatefulWidget {
  const LocalPage({
    super.key,
    this.currentRelativePath = '',
    this.searchQuery = '',
    this.onPickLibraryRoot,
    this.onScanLibrary,
  });

  final String currentRelativePath;
  final String searchQuery;
  final FutureOr<String?> Function()? onPickLibraryRoot;
  final LocalScanLibraryCallback? onScanLibrary;

  @override
  ConsumerState<LocalPage> createState() => _LocalPageState();
}

class _LocalPageState extends ConsumerState<LocalPage> {
  var _sortMode = LocalSortMode.title;
  final _selectedFolderPaths = <String>{};
  final _selectedSongIds = <int>{};
  var _multiSelect = false;
  var _foldersExpanded = true;
  var _songsExpanded = true;
  final _createdFolderPaths = <String>{};
  final _dataCache = LibraryPageDataCache();
  final _treeExpandedFolderPaths = <String>{};
  final _scrollController = ScrollController();
  LocalFolderRefreshProgress? _refreshProgress;
  ({FolderNode folder, LocalFolderRefreshResult result})? _refreshResultDialog;
  String? _localOperationTitle;
  LocalFolderScanCancellation? _scanCancellation;
  var _refreshFolderRunning = false;
  final _scanProgressClock = Stopwatch()..start();
  var _lastScanProgressUpdateMs = -100;
  MusicDialogEntry? _musicDialog;
  var _rootScanRunning = false;
  var _pickingLibraryRoot = false;

  void _updateLocalPageState(VoidCallback update) {
    setState(update);
  }

  @override
  void didUpdateWidget(LocalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRelativePath != widget.currentRelativePath) {
      _clearMultiSelectStatus();
      _scrollCurrentFolderToTop();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollCurrentFolderToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(libraryContentDataProvider);
    ref.watch(recentSearchesProvider);
    final songOverrides = ref.watch(librarySongOverridesProvider);

    if (i18nValue.isLoading) {
      return const LocalPageScaffold(child: SmPlayerLoadingState());
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const LocalPageScaffold(child: SmPlayerLoadingState());
    }

    return snapshotValue.when(
      loading: () => const LocalPageScaffold(child: SmPlayerLoadingState()),
      error: (_, _) => const LocalPageScaffold(child: SmPlayerLoadingState()),
      data: (rawSnapshot) {
        final snapshot = _dataCache.snapshot(
          rawSnapshot,
          songOverrides,
          ref.watch(libraryPlaylistOverridesProvider),
          ref.watch(libraryDeletedPlaylistIdsProvider),
          ref.watch(libraryPlaylistOrderProvider),
        );
        return SmPlayerI18nScope(
          i18n: i18n,
          child: _buildPage(context, snapshot, i18n),
        );
      },
    );
  }
}
