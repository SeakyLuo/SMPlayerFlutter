import '../../playback/playlist_control.dart';
import 'package:flutter/rendering.dart';
import 'library_scope_access.dart';
import 'package:path/path.dart' as p;
import '../data/library_repository.dart';
import '../../remote/music_source_selector.dart';
import '../../remote/music_share_download.dart';
import 'dart:async';
import '../../remote/music_source_providers.dart';
import '../../remote/remote_directory_provider.dart';
import '../../remote/music_share_models.dart';
import 'local_page_remote.dart';
import 'library_storage_actions.dart';
import 'library_load_failure.dart';
import 'local_directory_skeleton.dart';
import 'local_directory_count.dart';
import '../../remote/remote_page_access.dart';
import 'package:flutter/services.dart';

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
        runLibraryStorageAction,
        requestDeleteSongFromDisk,
        setSongsFavoriteWithUndo,
        showPlayNextUndoNotification;
import 'local_folder_model.dart';
import 'library_root_picker.dart';
import 'library_page_data_cache.dart';
import 'local_content_view.dart';
import 'local_page_empty_content.dart';
import 'local_move_to_folder_menu.dart';
import 'local_page_model.dart';
import 'scan_progress_overlay.dart';
import 'folder_update_result_dialog.dart';
import 'local_page_quick_jump.dart';
import 'local_page_shell.dart';
import 'local_title_grid.dart';
import 'music_dialog.dart';
import 'local_song_location.dart';

part 'local_page_content.dart';
part 'local_page_windows.dart';
part 'local_page_command_bar.dart';
part 'local_page_context_menus.dart';
part 'local_page_selection_actions.dart';
part 'local_page_scan_actions.dart';
part 'local_page_file_actions.dart';
part 'local_page_playback_actions.dart';
part 'local_page_folder_actions.dart';
part 'local_page_add_to_actions.dart';
part 'local_page_song_location.dart';

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
  final _songSliverKey = GlobalKey();
  LibraryDataQuery? _windowQuery;
  final _requestedWindows = <String, int>{};
  final _pendingWindows = <String, int>{};
  var _windowsScheduled = false;
  var _sortMode = LocalSortMode.title;
  String _source = 'local';
  Map<int, String>? _remoteSongFolders;
  final _remoteDataCache = RemoteDirectoryPageDataCache();
  bool get _remote => _source != 'local';
  bool get _canWriteDirectory =>
      !_remote ||
      ref
          .read(musicShareProvider)
          .peers
          .firstWhere((peer) => peer.id == _source)
          .canWrite;
  final _selectedFolderPaths = <String>{};
  final _selectedSongIds = <int>{};
  var _multiSelect = false;
  var _foldersExpanded = true;
  var _songsExpanded = true;
  final _createdFolderPaths = <String>{};
  final _dataCache = LibraryPageDataCache();
  final _treeExpandedFolderPaths = <String>{};
  final _scrollController = ScrollController();
  var _remoteDirectoryActive = false;
  final _scanProgressNotifier = ValueNotifier<LocalFolderRefreshProgress?>(
    null,
  );
  final _refreshButtonProgressNotifier = ValueNotifier<double?>(null);
  LocalFolderRefreshProgress? get _refreshProgress =>
      _scanProgressNotifier.value;
  set _refreshProgress(LocalFolderRefreshProgress? value) {
    _scanProgressNotifier.value = value;
  }

  ({FolderNode folder, LocalFolderRefreshResult result})? _refreshResultDialog;
  String? _localOperationTitle;
  LocalFolderScanCancellation? _scanCancellation;
  FolderNode? _refreshingFolder;
  Completer<void>? _refreshFolderCompletion;
  var _refreshFolderRunning = false;
  var _refreshFolderBackgrounded = false;
  var _refreshFolderCollapsing = false;
  var _refreshOverlayCollapseAlignment = Alignment.topRight;
  final _scanProgressClock = Stopwatch()..start();
  var _lastScanProgressUpdateMs = -100;
  MusicDialogEntry? _musicDialog;
  var _rootScanRunning = false;
  var _pickingLibraryRoot = false;
  LocalSongLocation? _handledSongLocation;
  int? _locatedSongId;
  Timer? _songLocationTimer;

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
    _scanProgressNotifier.dispose();
    _refreshButtonProgressNotifier.dispose();
    _songLocationTimer?.cancel();
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
    if (!TickerMode.valuesOf(context).enabled) return const SizedBox.shrink();
    final source = ref.watch(
      musicShareProvider.select((share) => share.selectedSource),
    );
    if (_source != source) {
      _remoteDirectoryActive = false;
      _source = source;
      _clearMultiSelectStatus();
      _treeExpandedFolderPaths.clear();
      _createdFolderPaths.clear();
      _remoteSongFolders = null;
      _sortMode = LocalSortMode.title;
    }
    if (_remote &&
        !_remoteDirectoryActive &&
        !TickerMode.valuesOf(context).enabled) {
      return const SizedBox.shrink();
    }
    if (_remote) {
      // Keep an opened directory mounted, including its scroll position and
      // provider subscription, while hidden folders cover this page.
      _remoteDirectoryActive = true;
    }
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final contextValue = ref.watch(
      libraryPageQueryProvider(
        const LibraryDataQuery(LibraryQueryKind.context),
      ),
    );
    if (!contextValue.hasValue) {
      return LocalPageScaffold(
        child:
            contextValue.hasError
                ? LibraryLoadFailure(
                  onRetry:
                      () => ref.invalidate(
                        libraryPageQueryProvider(
                          const LibraryDataQuery(LibraryQueryKind.context),
                        ),
                      ),
                )
                : const LocalDirectorySkeleton(includeHeader: true),
      );
    }
    final root =
        _remote
            ? '$remoteMusicScheme://$_source'
            : contextValue.requireValue.rootPath;
    final current = getLocalFolderAbsolutePath(widget.currentRelativePath, root);
    final directoryQuery = LibraryDataQuery(
      LibraryQueryKind.folders,
      source: _source,
      directWindows: {current: 0},
      order: _directoryOrder,
      descending: _sortMode == LocalSortMode.reverse,
      text: widget.searchQuery,
    );
    _windowQuery = directoryQuery;
    listenLibraryQueryFailure(
      ref,
      libraryDirectoryWindowsProvider(directoryQuery),
      () => ref.invalidate(libraryDirectoryWindowsProvider(directoryQuery)),
    );
    var snapshotValue = ref.watch(
      libraryDirectoryWindowsProvider(directoryQuery),
    );
    String? remoteRootName;
    if (_remote) {
      final access = RemotePageAccessScope.of(context);
      if ((access.loading || access.failed) && !snapshotValue.hasValue) {
        return _buildRemoteDirectoryPlaceholder(
          context,
          loading: access.loading,
        );
      }
      final directoryProvider = remoteDirectoryProvider(source);
      ref.listen(directoryProvider, (previous, next) {
        if (!next.isLoading &&
            next.hasError &&
            (previous?.isLoading != false ||
                !identical(previous?.error, next.error))) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final error = next.error;
              _showMessage(
                context.smPlayerI18n.t(
                  error is MusicShareException
                      ? error.messageKey
                      : 'share.connectionFailed',
                ),
              );
            }
          });
        }
      });
      final directory = ref.watch(directoryProvider);
      if (!directory.hasValue) {
        return _buildRemoteDirectoryPlaceholder(
          context,
          loading: directory.isLoading,
        );
      }
      final directoryIndex = directory.requireValue;
      remoteRootName = directoryIndex.rootName;
      if (snapshotValue.hasValue) {
        snapshotValue = AsyncData(snapshotValue.requireValue);
      }
      snapshotValue = snapshotValue.whenData((snapshot) {
        final data = _remoteDataCache.read(snapshot, directoryIndex, source);
        _remoteSongFolders = data.songFolders;
        return data.snapshot;
      });
    }
    ref.watch(recentSearchesProvider);
    final songOverrides = ref.watch(librarySongOverridesProvider);
    final songLocation = ref.watch(localSongLocationProvider);
    if (songLocation != null &&
        songLocation != _handledSongLocation &&
        songLocation.folderPath == widget.currentRelativePath &&
        widget.searchQuery.isEmpty &&
        snapshotValue.hasValue) {
      _handledSongLocation = songLocation;
      _clearMultiSelectStatus();
      _songsExpanded = true;
      _musicDialog = null;
      _refreshResultDialog = null;
      _locatedSongId = songLocation.songId;
      _songLocationTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _revealLocatedSong(songLocation);
      });
    }

    if (i18nValue.isLoading) {
      return const LocalPageScaffold(child: SmPlayerLoadingState());
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const LocalPageScaffold(child: SmPlayerLoadingState());
    }

    return snapshotValue.when(
      skipLoadingOnReload: true,
      loading:
          () =>
              _remote
                  ? _buildRemoteDirectoryPlaceholder(context, loading: true)
                  : _buildLocalDirectoryPlaceholder(context, root),
      error:
          (_, _) =>
              _remote
                  ? _buildRemoteDirectoryPlaceholder(context, loading: false)
                  : LocalPageScaffold(
                    child: LibraryLoadFailure(
                      onRetry:
                          () => ref.invalidate(
                            libraryDirectoryWindowsProvider(directoryQuery),
                          ),
                    ),
                  ),
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
          child: _buildPage(context, snapshot, i18n, rootName: remoteRootName),
        );
      },
    );
  }

  Widget _buildLocalDirectoryPlaceholder(
    BuildContext context,
    String rootPath,
  ) {
    if (rootPath.isEmpty) {
      return const LocalPageScaffold(
        child: LocalDirectorySkeleton(includeHeader: true),
      );
    }
    return _buildPage(
      context,
      unavailableRemoteDirectorySnapshot(
        _source,
        widget.currentRelativePath,
        rootPath: rootPath,
      ),
      context.smPlayerI18n,
      contentUnavailable: true,
      contentLoading: true,
    );
  }

  Widget _buildRemoteDirectoryPlaceholder(
    BuildContext context, {
    required bool loading,
  }) {
    _remoteSongFolders = const {};
    return _buildPage(
      context,
      unavailableRemoteDirectorySnapshot(_source, widget.currentRelativePath),
      context.smPlayerI18n,
      contentUnavailable: true,
      contentLoading: loading,
    );
  }
}
