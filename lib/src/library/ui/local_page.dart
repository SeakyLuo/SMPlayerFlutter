import 'dart:async';
import 'dart:io';
import 'dart:math';

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
import '../../playback/media_control_track_factory.dart';
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
        hideSongFileWithUndo,
        moveSongToFolderWithUndo,
        requestLocalMoveConflictResolution,
        requestDeleteSongFromDisk,
        setSongsFavoriteWithUndo;
import 'local_folder_model.dart';
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
  final _treeExpandedFolderPaths = <String>{};
  final _scrollController = ScrollController();
  LocalFolderRefreshProgress? _refreshProgress;
  ({FolderNode folder, LocalFolderRefreshResult result})? _refreshResultDialog;
  String? _localOperationTitle;
  LocalFolderScanCancellation? _scanCancellation;
  var _refreshFolderRunning = false;
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
        final snapshot = applyLibraryFavoriteOverrides(
          rawSnapshot,
          const {},
          songOverrides,
        );
        return SmPlayerI18nScope(
          i18n: i18n,
          child: _buildPage(context, snapshot, i18n),
        );
      },
    );
  }

  Widget _buildPage(
    BuildContext context,
    LibraryContentData snapshot,
    SmPlayerI18n i18n,
  ) {
    if (snapshot.rootPath.isEmpty) {
      return LocalPageScaffold(
        child: Stack(
          children: [
            LocalPageEmptyState(
              title: i18n.t('local.noRoot'),
              message: i18n.t('local.noRootCopy'),
              action: LocalCommandButton(
                onPressed:
                    _rootScanRunning || _pickingLibraryRoot
                        ? null
                        : () {
                          unawaited(_pickAndScanLibraryRoot(i18n));
                        },
                icon:
                    _pickingLibraryRoot ? null : FluentIcons.folder_20_regular,
                label:
                    _pickingLibraryRoot
                        ? i18n.t('library.openingFolderPicker')
                        : i18n.t('library.chooseFolder'),
                loading: _pickingLibraryRoot,
              ),
            ),
            if (_refreshProgress case final progress?)
              ScanProgressOverlay(
                title: _localOperationTitle ?? i18n.t('local.updateFolder'),
                progress: progress,
                onCancel:
                    progress.canCancel ? () => _requestCancelScan(i18n) : null,
              ),
          ],
        ),
      );
    }

    final folderIndex = buildFolderIndex(
      snapshot.songs,
      snapshot.folders,
      snapshot.rootPath,
    );
    final nodes = Map<String, FolderNode>.of(folderIndex.nodes);
    for (final folderPath in _createdFolderPaths) {
      final folder = nodes.putIfAbsent(
        folderPath,
        () => createFolderNode(folderPath, snapshot.rootPath),
      );
      final parentPath = getParentPath(folder.relativePath);
      final parent = nodes.putIfAbsent(
        parentPath,
        () => createFolderNode(parentPath, snapshot.rootPath),
      );
      if (!parent.childPaths.contains(folder.relativePath)) {
        parent.childPaths.add(folder.relativePath);
      }
    }
    for (final node in nodes.values) {
      node.childPaths.sort(
        (left, right) =>
            compareLocalText(nodes[left]!.name, nodes[right]!.name),
      );
    }
    final songsById = folderIndex.songsById;
    final currentNode = nodes[widget.currentRelativePath];
    if (currentNode == null) {
      return LocalPageScaffold(
        child: LocalPageEmptyState(
          title: i18n.t('local.folderNotFound'),
          message: i18n.t('local.folderNotFoundDescription'),
          action: LocalCommandButton(
            onPressed: () => _openFolder(''),
            icon: FluentIcons.arrow_left_20_regular,
            label: i18n.t('local.backToRoot'),
          ),
        ),
      );
    }

    final currentSortMode = localSortModeFromCriterion(currentNode.criterion);
    if (_sortMode != currentSortMode &&
        _sortMode != LocalSortMode.reverse &&
        !_multiSelect) {
      _sortMode = currentSortMode;
    }

    final currentSongs = sortSongs(
      currentNode.directSongIds
          .map((songId) => songsById[songId]!)
          .where((song) => matchesSongSearch(song, widget.searchQuery))
          .toList(),
      _sortMode,
      currentSortMode,
    );
    final normalizedSearchQuery = widget.searchQuery.trim().toLowerCase();
    final childFolders = sortFolders(
      currentNode.childPaths
          .map((childPath) => nodes[childPath]!)
          .where(
            (folder) =>
                normalizedSearchQuery.isEmpty ||
                folder.name.toLowerCase().contains(normalizedSearchQuery),
          )
          .toList(),
    );
    final localCompactFolderTreeRows = buildLocalCompactFolderTreeRows(
      childFolders: childFolders,
      nodes: nodes,
      songsById: songsById,
      expandedFolderPaths: _treeExpandedFolderPaths,
      sortMode: _sortMode,
      searchQuery: widget.searchQuery,
    );
    final localCompactFolderTreeFolderPaths =
        localCompactFolderTreeRows
            .where((row) => row.type == LocalCompactTreeRowType.folder)
            .map((row) => row.folder!.relativePath)
            .toList();
    final localCompactFolderTreeSongIds =
        localCompactFolderTreeRows
            .where((row) => row.type == LocalCompactTreeRowType.song)
            .map((row) => row.song!.id)
            .toList();
    final showLocalSectionHeaders =
        childFolders.isNotEmpty && currentSongs.isNotEmpty;
    final visibleSongIds = currentSongs.map((song) => song.id).toList();
    final folderQueueSongIds =
        currentNode.directSongIds
            .map((songId) => songsById[songId]!)
            .where((song) => matchesSongSearch(song, widget.searchQuery))
            .map((song) => song.id)
            .toList();
    final currentNodeDirectSongIdSet = currentNode.directSongIds.toSet();
    final hasSubfolderSongs = currentNode.subtreeSongIds.any(
      (songId) => !currentNodeDirectSongIdSet.contains(songId),
    );
    final customPlaylists =
        snapshot.playlists
            .where((playlist) => !playlist.isBuiltIn)
            .map(
              (playlist) => MultiSelectCommandBarPlaylist(
                id: playlist.id,
                name: playlist.name,
                songIds: playlist.songIds,
              ),
            )
            .toList();
    final songQuickJumpMap = buildLocalSongQuickJumpMap(
      currentSongs,
      _sortMode,
      currentSortMode,
      i18n,
    );
    final mediaState = ref.watch(mediaControlControllerProvider).state;

    return LayoutBuilder(
      builder: (context, constraints) {
        final colors = LocalPageColors.of(context);
        final isCompactLayout = constraints.maxWidth < localCompactBreakpoint;
        final selectableFolderPaths =
            isCompactLayout
                ? localCompactFolderTreeFolderPaths
                : childFolders.map((folder) => folder.relativePath).toList();
        final selectableSongIds =
            isCompactLayout
                ? [...localCompactFolderTreeSongIds, ...visibleSongIds]
                : visibleSongIds;
        final selectableFolderPathSet = selectableFolderPaths.toSet();
        final selectableSongIdSet = selectableSongIds.toSet();
        final effectiveSelectedFolderPaths =
            _selectedFolderPaths
                .where(selectableFolderPathSet.contains)
                .toList();
        final effectiveSelectedSongIds =
            _selectedSongIds.where(selectableSongIdSet.contains).toList();
        final selectedFolderAbsolutePaths =
            effectiveSelectedFolderPaths
                .map((folderPath) => nodes[folderPath]!.path)
                .toList();
        final selectedQueueSongIds =
            {
              ...effectiveSelectedSongIds,
              ...effectiveSelectedFolderPaths.expand(
                (folderPath) => nodes[folderPath]!.subtreeSongIds,
              ),
            }.toList();
        final selectedLocalItemCount =
            effectiveSelectedFolderPaths.length +
            effectiveSelectedSongIds.length;
        final selectedMoveToFolderMenuItems = buildLocalMoveToFolderMenuItems(
          nodes: nodes,
          songsById: songsById,
          songIds: effectiveSelectedSongIds,
          folderPaths: selectedFolderAbsolutePaths,
          i18n: i18n,
          onMoveToFolder: (targetFolder) {
            _moveLocalItemsToFolder(
              songIds: effectiveSelectedSongIds,
              folderPaths: selectedFolderAbsolutePaths,
              targetFolderPath: targetFolder.path,
            );
            setState(() {
              _hideMultiSelectAfterOperation(
                snapshot.hideMultiSelectCommandBarAfterOperation,
              );
            });
          },
        );
        final showsInlineTitle = !WorkspaceNavigationAppBarScope.of(context);
        return LocalPageScaffold(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  if (showsInlineTitle) ...[
                    LocalTitleGrid(
                      songs: snapshot.songs,
                      folders: snapshot.folders,
                      i18n: i18n,
                      rootPath: snapshot.rootPath,
                      currentRelativePath: widget.currentRelativePath,
                      onHiddenFoldersListButtonClick:
                          () => context.go('/hidden-folders'),
                      onCurrentFolderClick: _scrollCurrentFolderToTop,
                      onOpenFolder: _openFolder,
                      onWillAcceptDrop:
                          (targetRelativePath, payload) =>
                              isLocalMoveTargetFolder(
                                payload: payload,
                                targetFolder: nodes[targetRelativePath]!,
                                nodes: nodes,
                                songsById: songsById,
                              ),
                      onAcceptDrop: (targetRelativePath, payload) {
                        _moveLocalItemsToFolder(
                          songIds: payload.songIds,
                          folderPaths: payload.folderPaths,
                          targetFolderPath: nodes[targetRelativePath]!.path,
                        );
                        setState(_clearMultiSelectStatus);
                      },
                      onOpenFolderMenu:
                          (targetRelativePath, position) =>
                              _showFolderChainMenu(
                                position: position,
                                folder: nodes[targetRelativePath]!,
                                nodes: nodes,
                                songsById: songsById,
                                playlists: customPlaylists,
                                snapshot: snapshot,
                                i18n: i18n,
                              ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  CommandBar(
                    contentSizing: CommandBarContentSizing.intrinsic,
                    overflowReserve: isCompactLayout ? 44 : 0,
                    overflowLabel: i18n.t('player.more'),
                    overflowItems:
                        isCompactLayout
                            ? [
                              MenuFlyoutItem(
                                key: 'hidden-folders',
                                text: i18n.t('local.viewHiddenFolders'),
                                icon: FluentIcons.folder_prohibited_20_regular,
                                onPressed: () => context.go('/hidden-folders'),
                              ),
                            ]
                            : const [],
                    content: Text(
                      formatFolderCardStats(
                        i18n,
                        childFolders.length,
                        currentSongs.length,
                      ),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontVariations: const [FontVariation.weight(650)],
                      ),
                    ),
                    children: [
                      CommandBarButton(
                        iconWidget: const ShuffleIcon(),
                        useShuffleIcon: true,
                        label: i18n.t('nowPlaying.randomPlay'),
                        overflowSubmenu:
                            visibleSongIds.isNotEmpty && hasSubfolderSongs
                                ? _localShuffleMenuItems(
                                  currentNode,
                                  visibleSongIds,
                                  i18n,
                                )
                                : const [],
                        onPressedWithContext:
                            (buttonContext) => _playShuffledFromToolbar(
                              buttonContext,
                              currentNode,
                              visibleSongIds,
                              hasSubfolderSongs,
                              i18n,
                            ),
                      ),
                      CommandBarButton(
                        icon: FluentIcons.arrow_sync_24_regular,
                        label:
                            isCompactLayout
                                ? i18n.t('local.updateFolderShort')
                                : i18n.t('local.updateFolder'),
                        onPressed: () => _refreshFolder(currentNode, i18n),
                      ),
                      CommandBarButton(
                        icon: FluentIcons.arrow_sort_24_regular,
                        label: i18n.t('common.sort'),
                        overflowSubmenu: _localSortMenuItems(currentNode, i18n),
                        onPressedWithContext:
                            (context) =>
                                _showSortMenu(context, i18n, currentNode),
                      ),
                      CommandBarButton(
                        icon: FluentIcons.add_24_regular,
                        label: i18n.t('local.newFolder'),
                        onPressed:
                            () => _createFolder(
                              parent: currentNode,
                              nodes: nodes,
                              rootPath: snapshot.rootPath,
                              i18n: i18n,
                            ),
                      ),
                      CommandBarButton(
                        icon: FluentIcons.multiselect_ltr_24_regular,
                        label: i18n.t('albums.multiSelect'),
                        active: _multiSelect,
                        onPressed: _enableMultiSelect,
                      ),
                      if (_multiSelect)
                        CommandBarButton(
                          icon: FluentIcons.delete_24_regular,
                          label: i18n.t('context.deleteFromDisk'),
                          disabled: selectedLocalItemCount == 0,
                          onPressed:
                              () => _showMessage(
                                i18n.t('context.deleteFromDisk'),
                              ),
                        ),
                    ],
                  ),
                  SizedBox(height: isCompactLayout ? 8 : 16),
                  Expanded(
                    child: LocalPageContentPanel(
                      scrollController: _scrollController,
                      scrollable: true,
                      compact: isCompactLayout,
                      bottomPadding:
                          _multiSelect ? multiSelectCommandBarScrollSpacer : 18,
                      child:
                          childFolders.isEmpty && currentSongs.isEmpty
                              ? buildLocalPageEmptyContent(
                                i18n: i18n,
                                snapshot: snapshot,
                                searchQuery: widget.searchQuery,
                                onOpenSettings: () => context.go('/settings'),
                              )
                              : LocalContentView(
                                childFolders: childFolders,
                                currentSongs: currentSongs,
                                nodes: nodes,
                                songsById: songsById,
                                selectedFolderPaths: _selectedFolderPaths,
                                selectedSongIds: _selectedSongIds,
                                selectedTrackId: mediaState.track.id,
                                isPlaying: mediaState.isPlaying,
                                multiSelect: _multiSelect,
                                isCompactLayout: isCompactLayout,
                                showLocalSectionHeaders:
                                    showLocalSectionHeaders,
                                foldersExpanded: _foldersExpanded,
                                songsExpanded: _songsExpanded,
                                showSongQuickJump:
                                    currentSongs.length >= 50 &&
                                    songQuickJumpMap.length >= 4,
                                reserveSongQuickJumpSpace:
                                    currentSongs.length >= 50,
                                songQuickJumpBasisName:
                                    getLocalSongQuickJumpBasisName(
                                      _sortMode,
                                      currentSortMode,
                                      i18n,
                                    ),
                                songQuickJumpMap: songQuickJumpMap,
                                sortMode: _sortMode,
                                currentSortMode: currentSortMode,
                                queueSongIds: visibleSongIds,
                                folderQueueSongIds: folderQueueSongIds,
                                compactTreeRows: localCompactFolderTreeRows,
                                compactQueueSongIds:
                                    localCompactFolderTreeSongIds,
                                i18n: i18n,
                                onToggleFoldersExpanded:
                                    () => setState(() {
                                      _foldersExpanded = !_foldersExpanded;
                                    }),
                                onToggleSongsExpanded:
                                    () => setState(() {
                                      _songsExpanded = !_songsExpanded;
                                    }),
                                onToggleTreeFolderExpanded:
                                    (folderPath) => setState(() {
                                      if (_treeExpandedFolderPaths.contains(
                                        folderPath,
                                      )) {
                                        _treeExpandedFolderPaths.remove(
                                          folderPath,
                                        );
                                      } else {
                                        _treeExpandedFolderPaths.add(
                                          folderPath,
                                        );
                                      }
                                    }),
                                onPlayFolder: (folder) => _playShuffled(folder),
                                onAddFolder:
                                    (folder, position) => _showAddToMenu(
                                      position: position,
                                      songIds: folder.subtreeSongIds,
                                      defaultPlaylistName: folder.name,
                                      playlists: customPlaylists,
                                      snapshot: snapshot,
                                      i18n: i18n,
                                    ),
                                onRefreshFolder:
                                    (folder) => _refreshFolder(folder, i18n),
                                onSearchFolder:
                                    (folder) => _searchDirectory(folder, i18n),
                                onRevealFolder: _revealFolder,
                                onOpenFolder: _openFolder,
                                onOpenFolderMenu:
                                    (folder, position) => _showFolderMenu(
                                      position: position,
                                      folder: folder,
                                      nodes: nodes,
                                      songsById: songsById,
                                      playlists: customPlaylists,
                                      snapshot: snapshot,
                                      i18n: i18n,
                                    ),
                                onToggleFolderSelection: _toggleFolderSelection,
                                onMoveLocalItemsToFolder: ({
                                  required songIds,
                                  required folderPaths,
                                  required targetFolderPath,
                                }) {
                                  _moveLocalItemsToFolder(
                                    songIds: songIds,
                                    folderPaths: folderPaths,
                                    targetFolderPath: targetFolderPath,
                                  );
                                },
                                onPlayTrack: _playTrack,
                                onTogglePlayPause:
                                    () =>
                                        ref
                                            .read(
                                              mediaControlControllerProvider,
                                            )
                                            .onTogglePlayPause(),
                                onToggleSongSelection: _toggleSongSelection,
                                onPlayNext: (songId) => _playNext(songId),
                                onToggleFavorite:
                                    (songId, favorite) => _toggleSongsFavorite([
                                      songId,
                                    ], favorite),
                                onAddSong:
                                    (song, position) => _showAddToMenu(
                                      position: position,
                                      songIds: [song.id],
                                      defaultPlaylistName: song.title,
                                      playlists: customPlaylists,
                                      snapshot: snapshot,
                                      i18n: i18n,
                                    ),
                                onOpenSongMenu:
                                    (song, position) => _showSongMenu(
                                      position: position,
                                      song: song,
                                      queueSongIds: visibleSongIds,
                                      playlists: customPlaylists,
                                      snapshot: snapshot,
                                      i18n: i18n,
                                    ),
                                onJumpToSongKey:
                                    (key) => _jumpToSongKey(
                                      key,
                                      songQuickJumpMap,
                                      currentSongs,
                                    ),
                                scrollController: _scrollController,
                              ),
                    ),
                  ),
                ],
              ),
              MultiSelectCommandBar(
                visible: _multiSelect,
                bottomInset: multiSelectCommandBarShellBottomInset,
                horizontalBleed: isCompactLayout ? 12 : 24,
                selectedCount: selectedLocalItemCount,
                playlists: customPlaylists,
                showPlay: selectedQueueSongIds.isNotEmpty,
                showAddTo: selectedQueueSongIds.isNotEmpty,
                addToSongIds: selectedQueueSongIds,
                includeNowPlayingInAddTo: true,
                includeFavoritesInAddTo: _hasNotFavoriteSongs(
                  selectedQueueSongIds,
                  songsById,
                ),
                onAddToNowPlaying:
                    selectedQueueSongIds.isEmpty
                        ? null
                        : () {
                          _addSongsToNowPlaying(selectedQueueSongIds);
                          setState(() {
                            _hideMultiSelectAfterOperation(
                              snapshot.hideMultiSelectCommandBarAfterOperation,
                            );
                          });
                        },
                onToggleFavorite:
                    selectedQueueSongIds.isEmpty
                        ? null
                        : () {
                          _toggleSongsFavorite(
                            _notFavoriteSongIds(
                              selectedQueueSongIds,
                              songsById,
                            ),
                            true,
                          );
                          setState(() {
                            _hideMultiSelectAfterOperation(
                              snapshot.hideMultiSelectCommandBarAfterOperation,
                            );
                          });
                        },
                onCreatePlaylist:
                    selectedQueueSongIds.isEmpty
                        ? null
                        : () async {
                          await _createPlaylist(
                            getNextPlaylistName(
                              currentNode.name,
                              snapshot.playlists,
                            ),
                            selectedQueueSongIds,
                            snapshot,
                            i18n,
                          );
                          if (mounted) {
                            setState(() {
                              _hideMultiSelectAfterOperation(
                                snapshot
                                    .hideMultiSelectCommandBarAfterOperation,
                              );
                            });
                          }
                        },
                onPlay:
                    selectedQueueSongIds.isEmpty
                        ? null
                        : () {
                          _playTrack(
                            selectedQueueSongIds.first,
                            selectedQueueSongIds,
                          );
                          setState(() {
                            _hideMultiSelectAfterOperation(
                              snapshot.hideMultiSelectCommandBarAfterOperation,
                            );
                          });
                        },
                onAddToPlaylist:
                    selectedQueueSongIds.isEmpty
                        ? null
                        : (playlistId) {
                          _addSongsToPlaylist(playlistId, selectedQueueSongIds);
                          setState(() {
                            _hideMultiSelectAfterOperation(
                              snapshot.hideMultiSelectCommandBarAfterOperation,
                            );
                          });
                        },
                onRemove:
                    () => _requestDeleteLocalItems(
                      songIds: effectiveSelectedSongIds,
                      folderPaths: selectedFolderAbsolutePaths,
                      i18n: i18n,
                    ),
                removeLabel: i18n.t('context.deleteFromDisk'),
                extraActions: [
                  MultiSelectCommandBarExtraAction(
                    key: 'move-to-folder',
                    text: i18n.t('context.moveToFolder'),
                    icon: FluentIcons.folder_20_regular,
                    disabled:
                        selectedLocalItemCount == 0 ||
                        selectedMoveToFolderMenuItems.isEmpty,
                    onPressed: () {},
                    onPressedWithContext:
                        (buttonContext) => _showSelectedMoveToFolderMenu(
                          buttonContext: buttonContext,
                          nodes: nodes,
                          songsById: songsById,
                          songIds: effectiveSelectedSongIds,
                          folderPaths: selectedFolderAbsolutePaths,
                          i18n: i18n,
                          hideMultiSelectCommandBarAfterOperation:
                              snapshot.hideMultiSelectCommandBarAfterOperation,
                        ),
                  ),
                ],
                onSelectAll:
                    () => setState(() {
                      _selectedFolderPaths
                        ..clear()
                        ..addAll(selectableFolderPaths);
                      _selectedSongIds
                        ..clear()
                        ..addAll(selectableSongIds);
                    }),
                onReverseSelection:
                    () => setState(() {
                      final nextFolderPaths =
                          selectableFolderPaths
                              .where(
                                (folderPath) =>
                                    !_selectedFolderPaths.contains(folderPath),
                              )
                              .toSet();
                      final nextSongIds =
                          selectableSongIds
                              .where(
                                (songId) => !_selectedSongIds.contains(songId),
                              )
                              .toSet();
                      _selectedFolderPaths
                        ..clear()
                        ..addAll(nextFolderPaths);
                      _selectedSongIds
                        ..clear()
                        ..addAll(nextSongIds);
                    }),
                onClearSelection:
                    () => setState(() {
                      _selectedFolderPaths.clear();
                      _selectedSongIds.clear();
                    }),
                onCancel: () => setState(_clearMultiSelectStatus),
              ),
              if (_refreshProgress case final progress?)
                ScanProgressOverlay(
                  title: _localOperationTitle ?? i18n.t('local.updateFolder'),
                  progress: progress,
                  onCancel:
                      progress.canCancel
                          ? () => _requestCancelScan(i18n)
                          : null,
                ),
              if (_refreshResultDialog case final dialog?)
                FolderUpdateResultDialog(
                  folder: dialog.folder,
                  result: dialog.result,
                  songs: snapshot.songs,
                  selectedTrackId: mediaState.track.id,
                  isPlaying: mediaState.isPlaying,
                  onPlay: (songId) {
                    if (songId == mediaState.track.id) {
                      ref
                          .read(mediaControlControllerProvider)
                          .onTogglePlayPause();
                    } else {
                      _playTrack(songId, [songId]);
                    }
                  },
                  onOpenSongMenu:
                      (song, position) => _showSongMenu(
                        position: position,
                        song: song,
                        queueSongIds: visibleSongIds,
                        playlists: customPlaylists,
                        snapshot: snapshot,
                        i18n: i18n,
                        showSelect: false,
                        showMusicProperties: false,
                        showDelete: false,
                      ),
                  onApplyArtistSplits:
                      (splits) => _applyFolderUpdateArtistSplits(splits, i18n),
                  onDismissArtistSplitSuggestions:
                      _dismissFolderUpdateArtistSplitSuggestions,
                  onClose: () {
                    setState(() {
                      _refreshResultDialog = null;
                    });
                  },
                ),
              if (_musicDialog case final dialog?)
                MusicDialog(
                  song: dialog.song,
                  initialMode: dialog.mode,
                  currentTrackId: mediaState.track.id,
                  isPlaying: mediaState.isPlaying,
                  queueSongIds: dialog.queueSongIds,
                  onPlay:
                      ref
                          .read(mediaControlControllerProvider)
                          .onTogglePlayPause,
                  onPlayTrack: _playTrack,
                  onReveal: (path) {
                    unawaited(revealItemInFolder(path));
                  },
                  onSaved: () => notifyLyricsSaved(ref, dialog.song.id),
                  onClose: () {
                    setState(() {
                      _musicDialog = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
