import 'dart:async';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/input_dialog.dart';
import '../../app/loading_state.dart';
import '../../app/undoable_notification.dart';
import '../../i18n/app_i18n.dart';
import '../../playback/media_control_model.dart';
import '../../playback/media_control_provider.dart';
import '../../platform/desktop_features.dart';
import '../../settings/settings_model.dart'
    show AppSettingsUpdate, LocalViewMode;
import '../data/library_models.dart';
import '../data/library_providers.dart';
import 'artists_page_model.dart';
import 'command_bar.dart';
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
import 'local_grid_content.dart';
import 'local_page_model.dart';
import 'local_page_quick_jump.dart';
import 'local_table_content.dart';
import 'local_title_grid.dart';
import 'music_dialog.dart';

const localCompactBreakpoint = 720.0;

typedef LocalScanLibraryCallback =
    FutureOr<LocalFolderRefreshResult> Function(
      String rootPath, {
      LocalFolderScanCancellation? cancellation,
      void Function(LocalFolderRefreshProgress progress)? onProgress,
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
  ({LibrarySong song, SongDialogMode mode})? _musicDialog;
  var _rootScanRunning = false;

  @override
  void didUpdateWidget(LocalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRelativePath != widget.currentRelativePath) {
      _clearMultiSelectStatus();
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(musicLibrarySnapshotProvider);

    if (i18nValue.isLoading) {
      return const _LocalScaffold(child: SmPlayerLoadingState());
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const _LocalScaffold(child: SmPlayerLoadingState());
    }

    return snapshotValue.when(
      loading: () => const _LocalScaffold(child: SmPlayerLoadingState()),
      error:
          (_, _) => _LocalScaffold(
            child: _LocalEmptyState(
              title: i18n.t('remoteShare.libraryLoadFailed'),
              message: i18n.t('library.scanHelp'),
            ),
          ),
      data: (snapshot) {
        return SmPlayerI18nScope(
          i18n: i18n,
          child: _buildPage(context, snapshot, i18n),
        );
      },
    );
  }

  Widget _buildPage(
    BuildContext context,
    MusicLibrarySnapshot snapshot,
    SmPlayerI18n i18n,
  ) {
    if (snapshot.rootPath.isEmpty) {
      return Stack(
        children: [
          _LocalScaffold(
            child: _LocalEmptyState(
              title: i18n.t('local.noRoot'),
              message: i18n.t('local.noRootCopy'),
              action: TextButton.icon(
                onPressed:
                    _rootScanRunning
                        ? null
                        : () {
                          unawaited(_pickAndScanLibraryRoot(i18n));
                        },
                icon: const Icon(FluentIcons.folder_20_regular),
                label: Text(i18n.t('library.chooseFolder')),
              ),
            ),
          ),
          if (_refreshProgress case final progress?)
            _LocalProgressOverlay(
              title: _localOperationTitle ?? i18n.t('local.updateFolder'),
              progress: progress,
              onCancel:
                  progress.canCancel ? () => _requestCancelScan(i18n) : null,
            ),
        ],
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
      return _LocalScaffold(
        child: _LocalEmptyState(
          title: i18n.t('local.folderNotFound'),
          action: TextButton.icon(
            onPressed: () => _openFolder(''),
            icon: const Icon(FluentIcons.arrow_left_20_regular),
            label: Text(i18n.t('local.backToRoot')),
          ),
        ),
      );
    }

    final currentSortMode = localSortModeFromCriterion(currentNode.criterion);
    if (_sortMode != currentSortMode && !_multiSelect) {
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
        return _LocalScaffold(
          child: Stack(
            children: [
              Column(
                children: [
                  LocalTitleGrid(
                    songs: snapshot.songs,
                    folders: snapshot.folders,
                    i18n: i18n,
                    rootPath: snapshot.rootPath,
                    currentRelativePath: widget.currentRelativePath,
                    onHiddenFoldersListButtonClick:
                        () => context.go('/hidden-folders'),
                    onOpenFolder: _openFolder,
                  ),
                  const SizedBox(height: 12),
                  CommandBar(
                    overflowLabel: i18n.t('player.more'),
                    content: Text(
                      i18n.t('local.folderCardStats', {
                        'folders': childFolders.length,
                        'songs': currentSongs.length,
                      }),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LocalPageColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    children: [
                      Builder(
                        builder: (buttonContext) {
                          return CommandBarButton(
                            icon: FluentIcons.arrow_shuffle_24_regular,
                            label: i18n.t('nowPlaying.randomPlay'),
                            onPressed:
                                () => _playShuffledFromToolbar(
                                  buttonContext,
                                  currentNode,
                                  visibleSongIds,
                                  hasSubfolderSongs,
                                  i18n,
                                ),
                          );
                        },
                      ),
                      CommandBarButton(
                        icon: FluentIcons.arrow_sync_24_regular,
                        label:
                            isCompactLayout
                                ? i18n.t('local.updateFolderShort')
                                : i18n.t('local.updateFolder'),
                        onPressed: () => _refreshFolder(currentNode, i18n),
                      ),
                      Builder(
                        builder: (context) {
                          return CommandBarButton(
                            icon: FluentIcons.arrow_sort_24_regular,
                            label: i18n.t('common.sort'),
                            onPressed:
                                () => _showSortMenu(context, i18n, currentNode),
                          );
                        },
                      ),
                      CommandBarButton(
                        icon:
                            snapshot.localViewMode == LocalViewMode.list
                                ? FluentIcons.grid_24_regular
                                : FluentIcons.text_bullet_list_ltr_24_regular,
                        label:
                            snapshot.localViewMode == LocalViewMode.list
                                ? i18n.t('local.viewGrid')
                                : i18n.t('local.viewList'),
                        onPressed:
                            () => _toggleLocalViewMode(snapshot.localViewMode),
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
                        icon: FluentIcons.select_all_on_24_regular,
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
                  const SizedBox(height: 12),
                  Expanded(
                    child: _LocalContentPanel(
                      scrollController: _scrollController,
                      scrollable: snapshot.localViewMode != LocalViewMode.list,
                      child:
                          childFolders.isEmpty && currentSongs.isEmpty
                              ? _buildEmptyContent(i18n, snapshot)
                              : snapshot.localViewMode == LocalViewMode.list
                              ? LocalTableContent(
                                scrollController: _scrollController,
                                childFolders: childFolders,
                                currentSongs: currentSongs,
                                nodes: nodes,
                                songsById: songsById,
                                selectedFolderPaths: _selectedFolderPaths,
                                selectedSongIds: _selectedSongIds,
                                selectedTrackId: mediaState.track.id,
                                isPlaying: mediaState.isPlaying,
                                multiSelect: _multiSelect,
                                showLocalSectionHeaders:
                                    showLocalSectionHeaders,
                                foldersExpanded: _foldersExpanded,
                                songsExpanded: _songsExpanded,
                                showSongQuickJump:
                                    currentSongs.length >= 50 &&
                                    songQuickJumpMap.length >= 4,
                                songQuickJumpBasisName:
                                    getLocalSongQuickJumpBasisName(
                                      _sortMode,
                                      currentSortMode,
                                      i18n,
                                    ),
                                songQuickJumpMap: songQuickJumpMap,
                                queueSongIds: visibleSongIds,
                                compactTreeRows:
                                    isCompactLayout
                                        ? localCompactFolderTreeRows
                                        : const [],
                                compactQueueSongIds:
                                    isCompactLayout
                                        ? [
                                          ...localCompactFolderTreeSongIds,
                                          ...visibleSongIds,
                                        ]
                                        : const [],
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
                                    (folder) => _showAddToMenu(
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
                                onAddSong:
                                    (song) => _showAddToMenu(
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
                                      rowExtent: 48,
                                    ),
                              )
                              : LocalGridContent(
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
                                    (folder) => _showAddToMenu(
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
                                    (song) => _showAddToMenu(
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
                                      rowExtent: 232,
                                    ),
                              ),
                    ),
                  ),
                ],
              ),
              MultiSelectCommandBar(
                visible: _multiSelect,
                selectedCount: selectedLocalItemCount,
                playlists: customPlaylists,
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
                    selectedLocalItemCount == 0
                        ? null
                        : () => _requestDeleteLocalItems(
                          songIds: effectiveSelectedSongIds,
                          folderPaths:
                              effectiveSelectedFolderPaths
                                  .map((folderPath) => nodes[folderPath]!.path)
                                  .toList(),
                          i18n: i18n,
                        ),
                removeLabel: i18n.t('context.deleteFromDisk'),
                extraActions: [
                  MultiSelectCommandBarExtraAction(
                    key: 'move-to-folder',
                    text: i18n.t('context.moveToFolder'),
                    icon: FluentIcons.folder_20_regular,
                    disabled: selectedLocalItemCount == 0,
                    onPressed:
                        () => _showSelectedMoveToFolderMenu(
                          nodes: nodes,
                          songsById: songsById,
                          songIds: effectiveSelectedSongIds,
                          folderPaths:
                              effectiveSelectedFolderPaths
                                  .map((folderPath) => nodes[folderPath]!.path)
                                  .toList(),
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
                _LocalProgressOverlay(
                  title: _localOperationTitle ?? i18n.t('local.updateFolder'),
                  progress: progress,
                  onCancel:
                      progress.canCancel
                          ? () => _requestCancelScan(i18n)
                          : null,
                ),
              if (_refreshResultDialog case final dialog?)
                _LocalRefreshResultDialog(
                  folder: dialog.folder,
                  result: dialog.result,
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
                  canPause:
                      dialog.song.id ==
                          ref
                              .read(mediaControlControllerProvider)
                              .state
                              .track
                              .id &&
                      ref.read(mediaControlControllerProvider).state.isPlaying,
                  onPlay: () {
                    _playTrack(dialog.song.id, [dialog.song.id]);
                  },
                  onReveal: (path) {
                    unawaited(revealItemInFolder(path));
                  },
                  onSaved: () {
                    ref.invalidate(musicLibrarySnapshotProvider);
                  },
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

  Widget _buildEmptyContent(SmPlayerI18n i18n, MusicLibrarySnapshot snapshot) {
    if (snapshot.songs.isEmpty) {
      return _LocalEmptyState(
        title: i18n.t('local.noSongsScanned'),
        message: i18n.t('local.scanPopulate'),
        action: TextButton.icon(
          onPressed:
              _rootScanRunning
                  ? null
                  : () {
                    unawaited(_scanLibraryRoot(snapshot.rootPath, i18n));
                  },
          icon: const Icon(FluentIcons.arrow_sync_20_regular),
          label: Text(i18n.t('local.rescan')),
        ),
      );
    }

    if (widget.searchQuery.trim().isNotEmpty) {
      return _LocalEmptyState(
        title: i18n.t('local.noSongsBranch', {'query': widget.searchQuery}),
        message: i18n.t('local.searchHelp'),
      );
    }

    return const SizedBox.expand();
  }

  void _showSortMenu(
    BuildContext buttonContext,
    SmPlayerI18n i18n,
    FolderNode currentNode,
  ) {
    showMenuFlyout(
      buttonContext,
      items: [
        MenuFlyoutItem(
          key: 'toolbar-sort-reverse',
          text: i18n.t('local.sortReverseList'),
          icon: FluentIcons.arrow_sort_down_lines_20_regular,
          onPressed:
              () => _updateSortMode(currentNode, LocalSortMode.reverse, i18n),
        ),
        const MenuFlyoutItem.separator(key: 'toolbar-sort-separator'),
        MenuFlyoutItem(
          key: 'toolbar-sort-title',
          text: i18n.t('local.sortByTitle'),
          icon: FluentIcons.text_sort_ascending_20_regular,
          checked: _sortMode == LocalSortMode.title,
          onPressed:
              () => _updateSortMode(currentNode, LocalSortMode.title, i18n),
        ),
        MenuFlyoutItem(
          key: 'toolbar-sort-artist',
          text: i18n.t('local.sortByArtist'),
          icon: FluentIcons.person_20_regular,
          checked: _sortMode == LocalSortMode.artist,
          onPressed:
              () => _updateSortMode(currentNode, LocalSortMode.artist, i18n),
        ),
        MenuFlyoutItem(
          key: 'toolbar-sort-album',
          text: i18n.t('local.sortByAlbum'),
          icon: FluentIcons.album_20_regular,
          checked: _sortMode == LocalSortMode.album,
          onPressed:
              () => _updateSortMode(currentNode, LocalSortMode.album, i18n),
        ),
      ],
    );
  }

  Future<void> _showFolderMenu({
    required Offset position,
    required FolderNode folder,
    required Map<String, FolderNode> nodes,
    required Map<int, LibrarySong> songsById,
    required List<MultiSelectCommandBarPlaylist> playlists,
    required MusicLibrarySnapshot snapshot,
    required SmPlayerI18n i18n,
  }) async {
    final preferenceLevel = await ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('folder', '${folder.id}');
    if (!mounted) {
      return;
    }
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: folder.subtreeSongIds,
      playlists: playlists,
      includeNowPlaying: true,
      includeFavorites: _hasNotFavoriteSongs(folder.subtreeSongIds, songsById),
      onAddToNowPlaying: () {
        _addSongsToNowPlaying(folder.subtreeSongIds);
      },
      onToggleFavorite: () {
        _toggleSongsFavorite(
          _notFavoriteSongIds(folder.subtreeSongIds, songsById),
          true,
        );
      },
      onCreatePlaylist: () {
        _createPlaylist(folder.name, folder.subtreeSongIds, snapshot, i18n);
      },
      onAddToPlaylist: (playlistId) {
        _addSongsToPlaylist(playlistId, folder.subtreeSongIds);
      },
    );
    final moveToFolderItem = _buildMoveToFolderMenuItem(
      nodes: nodes,
      songsById: songsById,
      songIds: const [],
      folderPaths: [folder.path],
      i18n: i18n,
      onMoveToFolder: (targetFolder) {
        _moveLocalItemsToFolder(
          songIds: const [],
          folderPaths: [folder.path],
          targetFolderPath: targetFolder.path,
        );
      },
    );

    showMenuFlyout(
      context,
      position: position,
      items: [
        MenuFlyoutItem(
          key: 'shuffle-folder',
          text: i18n.t('nowPlaying.randomPlay'),
          icon: FluentIcons.arrow_shuffle_20_regular,
          onPressed: () => _playShuffled(folder),
        ),
        if (addToItem != null) addToItem,
        MenuFlyoutItem(
          key: 'select-folder',
          text: i18n.t('context.select'),
          icon: FluentIcons.select_all_on_20_regular,
          onPressed: () => _selectFolder(folder),
        ),
        if (moveToFolderItem != null) moveToFolderItem,
        _buildFolderPreferenceMenuItem(i18n, folder, preferenceLevel),
        MenuFlyoutItem(
          key: 'show-in-explorer',
          text: i18n.t('context.reveal'),
          icon: FluentIcons.folder_open_20_regular,
          onPressed: () => _revealFolder(folder),
        ),
        MenuFlyoutItem(
          key: 'new-folder',
          text: i18n.t('local.newFolder'),
          icon: FluentIcons.add_20_regular,
          onPressed:
              () => _createFolder(
                parent: folder,
                nodes: nodes,
                rootPath: snapshot.rootPath,
                i18n: i18n,
              ),
        ),
        MenuFlyoutItem(
          key: 'delete-folder',
          text: i18n.t('local.deleteFolder'),
          icon: FluentIcons.delete_20_regular,
          onPressed: () => _requestDeleteFolder(folder, i18n),
        ),
        MenuFlyoutItem(
          key: 'refresh-folder',
          text: i18n.t('local.updateFolder'),
          icon: FluentIcons.arrow_sync_20_regular,
          onPressed: () => _refreshFolder(folder, i18n),
        ),
        MenuFlyoutItem(
          key: 'rename-folder',
          text: i18n.t('local.renameFolder'),
          icon: FluentIcons.rename_20_regular,
          onPressed:
              () => _renameFolder(
                folder: folder,
                nodes: nodes,
                rootPath: snapshot.rootPath,
                i18n: i18n,
              ),
        ),
        _buildFolderSortMenuItem(i18n, folder),
        MenuFlyoutItem(
          key: 'search-directory',
          text: i18n.t('local.searchDirectory'),
          icon: FluentIcons.search_20_regular,
          onPressed: () => _searchDirectory(folder, i18n),
        ),
        MenuFlyoutItem(
          key: 'hide-folder',
          text: i18n.t('local.hideFolder'),
          icon: FluentIcons.eye_off_20_regular,
          onPressed: () => _hideFolder(folder),
        ),
      ],
    );
  }

  Future<void> _showSongMenu({
    required Offset position,
    required LibrarySong song,
    required List<int> queueSongIds,
    required List<MultiSelectCommandBarPlaylist> playlists,
    required MusicLibrarySnapshot snapshot,
    required SmPlayerI18n i18n,
  }) async {
    final mediaState = ref.read(mediaControlControllerProvider).state;
    final preferenceLevel = await ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('song', '${song.id}');
    if (!mounted) {
      return;
    }

    showMenuFlyout(
      context,
      position: position,
      items: buildMusicMenuFlyoutItems(
        i18n: i18n,
        songId: song.id,
        isFavorite: song.favorite,
        isCurrentTrack: mediaState.track.id == song.id,
        isPlaying: mediaState.isPlaying,
        playlists: playlists,
        folders: _menuFolders(snapshot.folders),
        songPath: song.path,
        currentTrackId: mediaState.track.id,
        showMoveToFolder: snapshot.folders.isNotEmpty,
        showHideFile: true,
        onPlay: () => _playTrack(song.id, queueSongIds),
        onPause: ref.read(mediaControlControllerProvider).onTogglePlayPause,
        onPlayNext: () => _playNext(song.id),
        onAddToNowPlaying: () => _addSongsToNowPlaying([song.id]),
        onCreatePlaylist: () {
          _createPlaylist(
            getNextPlaylistName(song.title, snapshot.playlists),
            [song.id],
            snapshot,
            i18n,
          );
        },
        onAddToPlaylist: (playlistId) {
          _addSongsToPlaylist(playlistId, [song.id]);
        },
        onRemove: () => _showMessage(i18n.t('context.removeFromList')),
        onSelect: () => _selectSong(song.id),
        onToggleFavorite: () {
          _toggleSongsFavorite([song.id], !song.favorite);
        },
        onSetPreference: (level) async {
          await ref
              .read(libraryRepositoryProvider)
              .addPreferenceItem('song', '${song.id}', song.title, level);
          ref.invalidate(musicLibrarySnapshotProvider);
        },
        preferenceLevel: preferenceLevel,
        onUndoPreference:
            preferenceLevel == null
                ? null
                : () async {
                  await ref
                      .read(libraryRepositoryProvider)
                      .removePreferenceItem('song', '${song.id}');
                  ref.invalidate(musicLibrarySnapshotProvider);
                },
        onMoveToFolder: (folderPath) {
          moveSongToFolderWithUndo(
            context: context,
            ref: ref,
            i18n: i18n,
            song: song,
            folderPath: folderPath,
          );
        },
        onDelete: () {
          requestDeleteSongFromDisk(
            context: context,
            ref: ref,
            i18n: i18n,
            song: song,
          );
        },
        onHide: () {
          hideSongFileWithUndo(
            context: context,
            ref: ref,
            i18n: i18n,
            song: song,
          );
        },
        onSeeArtist: () {
          final artists = getSongArtists(song);
          final artist =
              artists.isEmpty ? i18n.t('common.artistUnknown') : artists.first;
          context.go('/artists?artist=${Uri.encodeQueryComponent(artist)}');
        },
        onSeeAlbum: () {
          context.go(
            '/albums?album=${Uri.encodeQueryComponent(displayAlbum(song, i18n))}',
          );
        },
        onSeeMusicInfo: () => _openMusicDialog(song, SongDialogMode.properties),
        onSeeLyrics: () => _openMusicDialog(song, SongDialogMode.lyrics),
        onSeeAlbumArt: () => _openMusicDialog(song, SongDialogMode.albumArt),
        onSeeLocal: () => _revealSong(song),
      ),
    );
  }

  void _openMusicDialog(LibrarySong song, SongDialogMode mode) {
    setState(() {
      _musicDialog = (song: song, mode: mode);
    });
  }

  MenuFlyoutItem _buildFolderSortMenuItem(
    SmPlayerI18n i18n,
    FolderNode folder,
  ) {
    final folderSortMode = localSortModeFromCriterion(folder.criterion);
    return MenuFlyoutItem(
      key: 'folder-sort',
      text: i18n.t('common.sort'),
      icon: FluentIcons.arrow_sort_20_regular,
      submenu: [
        MenuFlyoutItem(
          key: 'folder-sort-reverse',
          text: i18n.t('local.sortReverseList'),
          icon: FluentIcons.arrow_sort_down_lines_20_regular,
          onPressed:
              () => _updateFolderSortMode(folder, LocalSortMode.reverse, i18n),
        ),
        const MenuFlyoutItem.separator(key: 'folder-sort-separator'),
        for (final item in [
          (
            key: 'folder-sort-title',
            text: i18n.t('local.sortByTitle'),
            mode: LocalSortMode.title,
            icon: FluentIcons.text_sort_ascending_20_regular,
          ),
          (
            key: 'folder-sort-artist',
            text: i18n.t('local.sortByArtist'),
            mode: LocalSortMode.artist,
            icon: FluentIcons.person_20_regular,
          ),
          (
            key: 'folder-sort-album',
            text: i18n.t('local.sortByAlbum'),
            mode: LocalSortMode.album,
            icon: FluentIcons.album_20_regular,
          ),
        ])
          MenuFlyoutItem(
            key: item.key,
            text: item.text,
            icon: item.icon,
            checked: folderSortMode == item.mode,
            onPressed: () => _updateFolderSortMode(folder, item.mode, i18n),
          ),
      ],
    );
  }

  MenuFlyoutItem _buildFolderPreferenceMenuItem(
    SmPlayerI18n i18n,
    FolderNode folder,
    String? preferenceLevel,
  ) {
    return MenuFlyoutItem(
      key: 'preference',
      text: i18n.t('settings.preferenceSettings'),
      icon: FluentIcons.star_20_regular,
      submenu: [
        if (preferenceLevel != null) ...[
          MenuFlyoutItem(
            key: 'preference-undo',
            text: i18n.t('preferences.undoPrefer'),
            icon: FluentIcons.arrow_undo_20_regular,
            onPressed: () async {
              await ref
                  .read(libraryRepositoryProvider)
                  .removePreferenceItem('folder', '${folder.id}');
              ref.invalidate(musicLibrarySnapshotProvider);
            },
          ),
          const MenuFlyoutItem.separator(key: 'preference-undo-separator'),
        ],
        for (final level in const [
          'do-not-appear',
          'dislike',
          'normal',
          'high',
          'higher',
          'very-high',
        ])
          MenuFlyoutItem(
            key: 'preference-$level',
            text: i18n.t('preferences.level.$level'),
            checked: preferenceLevel == level,
            onPressed: () async {
              await ref
                  .read(libraryRepositoryProvider)
                  .addPreferenceItem(
                    'folder',
                    '${folder.id}',
                    folder.name,
                    level,
                  );
              ref.invalidate(musicLibrarySnapshotProvider);
            },
          ),
      ],
    );
  }

  Future<void> _updateSortMode(
    FolderNode folder,
    LocalSortMode sortMode,
    SmPlayerI18n i18n,
  ) async {
    if (_multiSelect) {
      _showMessage(i18n.t('local.pleaseExitMultiSelectMode'));
      return;
    }

    setState(() {
      _sortMode = sortMode;
    });
    if (sortMode != LocalSortMode.reverse) {
      await ref
          .read(libraryRepositoryProvider)
          .updateLocalFolderSort(folder.path, sortMode);
      ref.invalidate(musicLibrarySnapshotProvider);
    }
  }

  Future<void> _toggleLocalViewMode(LocalViewMode currentMode) async {
    final nextMode =
        currentMode == LocalViewMode.list
            ? LocalViewMode.grid
            : LocalViewMode.list;
    await ref
        .read(libraryRepositoryProvider)
        .updateSettings(AppSettingsUpdate(localViewMode: nextMode));
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  Future<void> _updateFolderSortMode(
    FolderNode folder,
    LocalSortMode sortMode,
    SmPlayerI18n i18n,
  ) async {
    if (_multiSelect) {
      _showMessage(i18n.t('local.pleaseExitMultiSelectMode'));
      return;
    }

    if (sortMode != LocalSortMode.reverse) {
      await ref
          .read(libraryRepositoryProvider)
          .updateLocalFolderSort(folder.path, sortMode);
      ref.invalidate(musicLibrarySnapshotProvider);
    }
    if (folder.relativePath == widget.currentRelativePath) {
      setState(() {
        _sortMode = sortMode;
      });
    }
  }

  void _enableMultiSelect() {
    setState(() {
      _multiSelect = true;
    });
  }

  void _selectFolder(FolderNode folder) {
    setState(() {
      _multiSelect = true;
      _selectedFolderPaths
        ..clear()
        ..add(folder.relativePath);
      _selectedSongIds.clear();
    });
  }

  void _selectSong(int songId) {
    setState(() {
      _multiSelect = true;
      _selectedSongIds
        ..clear()
        ..add(songId);
      _selectedFolderPaths.clear();
    });
  }

  void _toggleFolderSelection(String folderPath) {
    setState(() {
      _multiSelect = true;
      if (_selectedFolderPaths.contains(folderPath)) {
        _selectedFolderPaths.remove(folderPath);
      } else {
        _selectedFolderPaths.add(folderPath);
      }
    });
  }

  void _toggleSongSelection(int songId) {
    setState(() {
      _multiSelect = true;
      if (_selectedSongIds.contains(songId)) {
        _selectedSongIds.remove(songId);
      } else {
        _selectedSongIds.add(songId);
      }
    });
  }

  void _clearMultiSelectStatus() {
    _multiSelect = false;
    _selectedFolderPaths.clear();
    _selectedSongIds.clear();
  }

  void _hideMultiSelectAfterOperation(
    bool hideMultiSelectCommandBarAfterOperation,
  ) {
    _selectedFolderPaths.clear();
    _selectedSongIds.clear();
    if (hideMultiSelectCommandBarAfterOperation) {
      _multiSelect = false;
    }
  }

  void _openFolder(String relativePath) {
    final query = <String, String>{};
    if (relativePath.isNotEmpty) {
      query['path'] = relativePath;
    }
    if (widget.searchQuery.trim().isNotEmpty) {
      query['query'] = widget.searchQuery.trim();
    }

    context.go(Uri(path: '/local', queryParameters: query).toString());
  }

  Future<void> _renameFolder({
    required FolderNode folder,
    required Map<String, FolderNode> nodes,
    required String rootPath,
    required SmPlayerI18n i18n,
  }) async {
    final name = await _requestFolderName(
      i18n: i18n,
      title: i18n.t('local.renameFolderPrompt'),
      defaultName: folder.name,
      validate: (value) {
        return _folderNameValidationError(
          getParentPath(folder.relativePath),
          value,
          nodes,
          i18n,
          folder.name,
        );
      },
    );
    if (name == null || name == folder.name) {
      return;
    }

    await ref.read(libraryRepositoryProvider).renameFolder(folder.path, name);
    ref.invalidate(musicLibrarySnapshotProvider);

    if (folder.relativePath == widget.currentRelativePath && mounted) {
      final parentPath = getParentPath(folder.relativePath);
      final nextRelativePath = parentPath.isEmpty ? name : '$parentPath/$name';
      _openFolder(nextRelativePath);
    }
  }

  Future<void> _hideFolder(FolderNode folder) async {
    await ref.read(libraryRepositoryProvider).hideFolder(folder.path);
    ref.invalidate(musicLibrarySnapshotProvider);
    if (mounted) {
      setState(_clearMultiSelectStatus);
      showUndoableSnackBar(
        context: context,
        i18n: context.smPlayerI18n,
        message: context.smPlayerI18n.t('notification.hiddenStorageItem', {
          'name':
              folder.name.isEmpty
                  ? context.smPlayerI18n.t('local.libraryRoot')
                  : folder.name,
        }),
        onUndo: () async {
          await ref.read(libraryRepositoryProvider).unhideFolder(folder.path);
          ref.invalidate(musicLibrarySnapshotProvider);
        },
      );
    }
  }

  void _showSelectedMoveToFolderMenu({
    required Map<String, FolderNode> nodes,
    required Map<int, LibrarySong> songsById,
    required List<int> songIds,
    required List<String> folderPaths,
    required SmPlayerI18n i18n,
    required bool hideMultiSelectCommandBarAfterOperation,
  }) {
    final moveItems = _buildLocalMoveToFolderMenuItems(
      nodes: nodes,
      songsById: songsById,
      songIds: songIds,
      folderPaths: folderPaths,
      i18n: i18n,
      onMoveToFolder: (targetFolder) async {
        await _moveLocalItemsToFolder(
          songIds: songIds,
          folderPaths: folderPaths,
          targetFolderPath: targetFolder.path,
        );
        if (mounted) {
          setState(() {
            _hideMultiSelectAfterOperation(
              hideMultiSelectCommandBarAfterOperation,
            );
          });
        }
      },
    );
    if (moveItems.isEmpty) {
      return;
    }

    showMenuFlyout(context, items: moveItems);
  }

  MenuFlyoutItem? _buildMoveToFolderMenuItem({
    required Map<String, FolderNode> nodes,
    required Map<int, LibrarySong> songsById,
    required List<int> songIds,
    required List<String> folderPaths,
    required SmPlayerI18n i18n,
    required ValueChanged<FolderNode> onMoveToFolder,
  }) {
    final moveItems = _buildLocalMoveToFolderMenuItems(
      nodes: nodes,
      songsById: songsById,
      songIds: songIds,
      folderPaths: folderPaths,
      i18n: i18n,
      onMoveToFolder: onMoveToFolder,
    );
    if (moveItems.isEmpty) {
      return null;
    }

    return MenuFlyoutItem(
      key: 'move-to-folder',
      text: i18n.t('context.moveToFolder'),
      icon: FluentIcons.folder_20_regular,
      submenu: moveItems,
    );
  }

  List<MenuFlyoutItem> _buildLocalMoveToFolderMenuItems({
    required Map<String, FolderNode> nodes,
    required Map<int, LibrarySong> songsById,
    required List<int> songIds,
    required List<String> folderPaths,
    required SmPlayerI18n i18n,
    required ValueChanged<FolderNode> onMoveToFolder,
  }) {
    final nodesByAbsolutePath = {
      for (final node in nodes.values) normalizePath(node.path): node,
    };
    final songParentPaths =
        songIds
            .map(
              (songId) => normalizePath(
                _getAbsoluteParentPath(songsById[songId]!.path),
              ),
            )
            .toSet();
    final sourceFolders =
        folderPaths
            .map(
              (folderPath) => nodesByAbsolutePath[normalizePath(folderPath)]!,
            )
            .toList();

    bool isTargetFolder(FolderNode folder) {
      if (songParentPaths.contains(normalizePath(folder.path))) {
        return false;
      }

      return sourceFolders.every(
        (sourceFolder) =>
            folder.relativePath != sourceFolder.relativePath &&
            folder.relativePath != getParentPath(sourceFolder.relativePath),
      );
    }

    String folderMenuText(FolderNode folder) {
      return folder.name.isEmpty ? i18n.t('local.libraryRoot') : folder.name;
    }

    MenuFlyoutItem targetItem(FolderNode folder) {
      return MenuFlyoutItem(
        key:
            'move-folder-${folder.relativePath.isEmpty ? 'root' : folder.relativePath}-target',
        text: folderMenuText(folder),
        icon: FluentIcons.folder_20_regular,
        onPressed: () => onMoveToFolder(folder),
      );
    }

    MenuFlyoutItem? treeItem(FolderNode folder) {
      final childItems = [
        for (final childPath in folder.childPaths)
          if (treeItem(nodes[childPath]!) case final item?) item,
      ];
      if (childItems.isEmpty) {
        return isTargetFolder(folder) ? targetItem(folder) : null;
      }

      return MenuFlyoutItem(
        key:
            'move-folder-${folder.relativePath.isEmpty ? 'root' : folder.relativePath}',
        text: folderMenuText(folder),
        icon: FluentIcons.folder_20_regular,
        submenu:
            isTargetFolder(folder)
                ? [
                  targetItem(folder),
                  MenuFlyoutItem.separator(
                    key:
                        'move-folder-${folder.relativePath.isEmpty ? 'root' : folder.relativePath}-separator',
                  ),
                  ...childItems,
                ]
                : childItems,
      );
    }

    final rootItem = treeItem(nodes['']!);
    if (rootItem == null) {
      return const [];
    }
    return rootItem.submenu.isEmpty ? [rootItem] : rootItem.submenu;
  }

  Future<void> _moveLocalItemsToFolder({
    required List<int> songIds,
    required List<String> folderPaths,
    required String targetFolderPath,
  }) async {
    setState(() {
      _localOperationTitle = context.smPlayerI18n.t('context.moveToFolder');
      _refreshProgress = const LocalFolderRefreshProgress(
        current: 0,
        total: 1,
        currentPath: '',
      );
    });
    try {
      final result = await ref
          .read(libraryRepositoryProvider)
          .moveLocalItemsToFolder(
            songIds,
            folderPaths,
            targetFolderPath,
            resolveConflict:
                (sourcePath, targetPath) => requestLocalMoveConflictResolution(
                  context: context,
                  i18n: context.smPlayerI18n,
                  sourcePath: sourcePath,
                  targetPath: targetPath,
                ),
          );
      if (!mounted) {
        return;
      }
      ref.invalidate(musicLibrarySnapshotProvider);
      if (result.itemCount > 0) {
        showUndoableSnackBar(
          context: context,
          i18n: context.smPlayerI18n,
          message: context.smPlayerI18n.t('notification.movedLocalItems', {
            'count': result.itemCount,
          }),
          onUndo: () async {
            await ref
                .read(libraryRepositoryProvider)
                .undoMoveLocalItems(result);
            ref.invalidate(musicLibrarySnapshotProvider);
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshProgress = null;
          _localOperationTitle = null;
        });
      }
    }
  }

  Future<void> _refreshFolder(FolderNode folder, SmPlayerI18n i18n) async {
    final cancellation = LocalFolderScanCancellation();
    setState(() {
      _scanCancellation = cancellation;
      _localOperationTitle = i18n.t('local.updateFolderProgressTitle');
      _refreshProgress = const LocalFolderRefreshProgress(
        current: 0,
        total: 1,
        currentPath: '',
        stage: LocalFolderRefreshStage.checking,
        canCancel: true,
      );
    });

    try {
      final result = await ref
          .read(libraryRepositoryProvider)
          .refreshLocalFolder(
            folder.path,
            cancellation: cancellation,
            onProgress: (progress) {
              if (!mounted) {
                return;
              }
              setState(() {
                _refreshProgress = progress;
              });
            },
          );
      if (!mounted) {
        return;
      }
      ref.invalidate(musicLibrarySnapshotProvider);
      setState(() {
        _refreshProgress = null;
        _localOperationTitle = null;
        _scanCancellation = null;
        _refreshResultDialog = (folder: folder, result: result);
      });
      _showMessage(_formatLocalRefreshResult(result, i18n));
    } on LocalFolderScanCanceledException {
      if (mounted) {
        setState(() {
          _refreshProgress = null;
          _localOperationTitle = null;
          _scanCancellation = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _refreshProgress = null;
          _localOperationTitle = null;
          _scanCancellation = null;
        });
        _showMessage(i18n.t('local.updateFolder'));
      }
    }
  }

  Future<void> _pickAndScanLibraryRoot(SmPlayerI18n i18n) async {
    final selectedRootPath =
        widget.onPickLibraryRoot == null
            ? await FilePicker.getDirectoryPath()
            : await widget.onPickLibraryRoot!();
    if (selectedRootPath == null || selectedRootPath.isEmpty) {
      return;
    }
    await _scanLibraryRoot(selectedRootPath, i18n);
  }

  Future<void> _scanLibraryRoot(String rootPath, SmPlayerI18n i18n) async {
    if (_rootScanRunning) {
      return;
    }
    final cancellation = LocalFolderScanCancellation();
    setState(() {
      _rootScanRunning = true;
      _scanCancellation = cancellation;
      _localOperationTitle = i18n.t('library.scanning');
      _refreshProgress = const LocalFolderRefreshProgress(
        current: 0,
        total: 1,
        currentPath: '',
        stage: LocalFolderRefreshStage.checking,
        canCancel: true,
      );
    });
    try {
      final result =
          widget.onScanLibrary == null
              ? await ref
                  .read(libraryRepositoryProvider)
                  .scanAllMusicLibrary(
                    rootPath,
                    cancellation: cancellation,
                    onProgress: _setScanProgress,
                  )
              : await widget.onScanLibrary!(
                rootPath,
                cancellation: cancellation,
                onProgress: _setScanProgress,
              );
      ref.invalidate(musicLibrarySnapshotProvider);
      if (mounted) {
        setState(() {
          _refreshResultDialog = (
            folder: createFolderNode('', rootPath),
            result: result,
          );
        });
      }
    } on LocalFolderScanCanceledException {
      if (mounted) {
        setState(() {
          _refreshProgress = null;
          _localOperationTitle = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _rootScanRunning = false;
          _scanCancellation = null;
          _refreshProgress = null;
          _localOperationTitle = null;
        });
      }
    }
  }

  void _setScanProgress(LocalFolderRefreshProgress progress) {
    if (!mounted) {
      return;
    }
    setState(() {
      _refreshProgress = progress;
    });
  }

  Future<void> _requestCancelScan(SmPlayerI18n i18n) async {
    final cancellation = _scanCancellation;
    if (cancellation == null) {
      return;
    }
    final confirmed = await showSmPlayerConfirmDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('local.updateFolderProgressStopConfirmTitle'),
      message: i18n.t('local.updateFolderProgressStopConfirmMessage'),
      confirmText: i18n.t('local.updateFolderProgressStopConfirm'),
    );
    if (confirmed) {
      cancellation.cancel();
    }
  }

  Future<void> _requestDeleteLocalItems({
    required List<int> songIds,
    required List<String> folderPaths,
    required SmPlayerI18n i18n,
  }) async {
    final confirmed = await showSmPlayerConfirmDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('context.deleteFromDisk'),
      message: _formatDeleteSelectedLocalItemsConfirm(
        i18n,
        songIds.length + folderPaths.length,
      ),
      confirmText: i18n.t('context.deleteFromDisk'),
    );
    if (!confirmed) {
      return;
    }

    final pendingDelete = await ref
        .read(libraryRepositoryProvider)
        .beginDeleteLocalItems(songIds, folderPaths);
    await _showPendingLocalItemsDeleteUndo(
      pendingDelete.id,
      i18n.t('notification.deletedLocalItems', {
        'count': songIds.length + folderPaths.length,
      }),
    );
    if (mounted) {
      setState(() {
        _clearMultiSelectStatus();
      });
    }
  }

  Future<void> _requestDeleteFolder(
    FolderNode folder,
    SmPlayerI18n i18n,
  ) async {
    final confirmed = await showSmPlayerConfirmDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('local.deleteFolder'),
      message: i18n.t('local.deleteFolderConfirm', {'name': folder.name}),
      confirmText: i18n.t('local.deleteFolder'),
    );
    if (!confirmed) {
      return;
    }

    final pendingDelete = await ref
        .read(libraryRepositoryProvider)
        .beginDeleteLocalItems(const [], [folder.path]);
    await _showPendingLocalItemsDeleteUndo(
      pendingDelete.id,
      i18n.t('notification.deletedLocalItems', {'count': 1}),
    );
  }

  Future<void> _showPendingLocalItemsDeleteUndo(
    String deleteId,
    String message,
  ) async {
    ref.invalidate(musicLibrarySnapshotProvider);
    if (!mounted) {
      await ref
          .read(libraryRepositoryProvider)
          .commitDeleteLocalItems(deleteId);
      return;
    }

    final closedReason = await showUndoableSnackBar(
      context: context,
      i18n: context.smPlayerI18n,
      message: message,
      onUndo: () async {
        await ref
            .read(libraryRepositoryProvider)
            .undoDeleteLocalItems(deleteId);
        ref.invalidate(musicLibrarySnapshotProvider);
      },
    );
    if (closedReason != SnackBarClosedReason.action) {
      await ref
          .read(libraryRepositoryProvider)
          .commitDeleteLocalItems(deleteId);
    }
  }

  String _getAbsoluteParentPath(String filePath) {
    final index = max(filePath.lastIndexOf('\\'), filePath.lastIndexOf('/'));
    return index < 0 ? '' : filePath.substring(0, index);
  }

  List<MenuFlyoutFolder> _menuFolders(List<LibraryFolder> folders) {
    return folders
        .map(
          (folder) => MenuFlyoutFolder(
            id: folder.id,
            name: _displayFolderName(folder.path),
            path: folder.path,
            parentId: folder.parentId,
          ),
        )
        .toList();
  }

  String _displayFolderName(String path) {
    final segments = normalizePath(path).split('/');
    return segments.isEmpty ? path : segments.last;
  }

  String _formatDeleteSelectedLocalItemsConfirm(
    SmPlayerI18n i18n,
    int itemCount,
  ) {
    if (i18n.locale.startsWith('zh')) {
      return '要从磁盘删除选中的 $itemCount 个项目吗？';
    }
    return 'Delete $itemCount selected item${itemCount == 1 ? '' : 's'} from disk?';
  }

  void _playShuffled(FolderNode folder) {
    _playShuffledSongIds(folder.subtreeSongIds);
  }

  void _playShuffledFromToolbar(
    BuildContext buttonContext,
    FolderNode currentNode,
    List<int> queueSongIds,
    bool hasSubfolderSongs,
    SmPlayerI18n i18n,
  ) {
    if (queueSongIds.isNotEmpty && hasSubfolderSongs) {
      showMenuFlyout(
        buttonContext,
        items: [
          MenuFlyoutItem(
            key: 'toolbar-shuffle-current',
            text: i18n.t('local.scopeCurrent'),
            icon: FluentIcons.arrow_shuffle_20_regular,
            onPressed: () => _playShuffledSongIds(queueSongIds),
          ),
          MenuFlyoutItem(
            key: 'toolbar-shuffle-subtree',
            text: i18n.t('local.scopeSubtree'),
            icon: FluentIcons.folder_20_regular,
            onPressed: () => _playShuffledSongIds(currentNode.subtreeSongIds),
          ),
        ],
      );
      return;
    }

    _playShuffledSongIds(
      queueSongIds.isNotEmpty ? queueSongIds : currentNode.subtreeSongIds,
    );
  }

  void _playShuffledSongIds(List<int> sourceSongIds) {
    final songIds = shuffleSongIds(sourceSongIds);
    if (songIds.isEmpty) {
      final i18n = ref.read(smPlayerI18nProvider).valueOrNull!;
      _showMessage(i18n.t('local.noMusicUnderCurrentFolder'));
      return;
    }

    _playTrack(songIds.first, songIds);
  }

  void _playTrack(int trackId, List<int> queueSongIds) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final song = songsById[trackId]!;
    ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          MediaControlTrack(
            id: song.id,
            title: song.title,
            artist: song.artist,
            artworkUrl: song.thumbnailPath,
            isLoading: false,
            favorite: song.favorite,
          ),
          durationSeconds: song.duration.toDouble(),
          queueIndex: max(0, queueSongIds.indexOf(trackId)),
        );
    ref.invalidate(musicLibrarySnapshotProvider);
    setState(() {
      _selectedSongIds
        ..clear()
        ..add(trackId);
      if (!_multiSelect) {
        _selectedFolderPaths.clear();
      }
    });
  }

  void _playNext(int songId) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final queueSongIds = snapshot.nowPlaying.songIds.toList();
    final selectedQueueIndex =
        ref.read(mediaControlControllerProvider).state.selectedQueueIndex;
    final insertIndex =
        selectedQueueIndex != null && selectedQueueIndex < queueSongIds.length
            ? selectedQueueIndex + 1
            : queueSongIds.length;
    queueSongIds.insert(insertIndex, songId);
    ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  Future<void> _createFolder({
    required FolderNode parent,
    required Map<String, FolderNode> nodes,
    required String rootPath,
    required SmPlayerI18n i18n,
  }) async {
    final repository = ref.read(libraryRepositoryProvider);
    final name = await _requestFolderName(
      i18n: i18n,
      defaultName: _nextFolderName(parent.relativePath, nodes, i18n),
      validate: (value) {
        return _folderNameValidationError(
          parent.relativePath,
          value,
          nodes,
          i18n,
        );
      },
    );
    if (name == null) {
      return;
    }

    final relativePath =
        parent.relativePath.isEmpty ? name : '${parent.relativePath}/$name';
    await repository.createLocalFolder(rootPath, parent.relativePath, name);
    if (!mounted) {
      return;
    }

    setState(() {
      _createdFolderPaths.add(relativePath);
    });
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  String _nextFolderName(
    String parentRelativePath,
    Map<String, FolderNode> nodes,
    SmPlayerI18n i18n,
  ) {
    final baseName = i18n.t('local.newFolderName');
    if (!_folderPathExists(parentRelativePath, baseName, nodes)) {
      return baseName;
    }

    var index = 1;
    var nextName = '$baseName ($index)';
    while (_folderPathExists(parentRelativePath, nextName, nodes)) {
      index += 1;
      nextName = '$baseName ($index)';
    }
    return nextName;
  }

  bool _folderPathExists(
    String parentRelativePath,
    String folderName,
    Map<String, FolderNode> nodes,
  ) {
    final relativePath =
        parentRelativePath.isEmpty
            ? folderName
            : '$parentRelativePath/$folderName';
    return nodes.containsKey(relativePath) ||
        _createdFolderPaths.contains(relativePath);
  }

  String _folderNameValidationError(
    String parentRelativePath,
    String name,
    Map<String, FolderNode> nodes,
    SmPlayerI18n i18n, [
    String currentName = '',
  ]) {
    final nextName = name.trim();
    if (nextName.isEmpty) {
      return i18n.t('local.folderNameEmpty');
    }
    if (nextName.length > 50) {
      return i18n.t('local.folderNameTooLong');
    }
    if (nextName != currentName &&
        _folderPathExists(parentRelativePath, nextName, nodes)) {
      return i18n.t('local.folderNameUsed');
    }
    return '';
  }

  Future<String?> _requestFolderName({
    required SmPlayerI18n i18n,
    required String defaultName,
    required String Function(String value) validate,
    String? title,
  }) async {
    final result = await showSmPlayerInputDialog(
      context: context,
      i18n: i18n,
      title: title ?? i18n.t('local.newFolderPrompt'),
      defaultValue: defaultName,
      confirmText: i18n.t('playlists.create'),
      validate: validate,
    );
    return result;
  }

  void _addSongsToNowPlaying(List<int> songIds) {
    addSongsToNowPlayingWithUndo(
      context: context,
      ref: ref,
      i18n: context.smPlayerI18n,
      songIds: songIds,
    );
  }

  Future<void> _addSongsToPlaylist(int playlistId, List<int> songIds) async {
    await addSongsToPlaylistWithUndo(
      context: context,
      ref: ref,
      i18n: context.smPlayerI18n,
      playlistId: playlistId,
      songIds: songIds,
    );
  }

  Future<void> _toggleSongsFavorite(List<int> songIds, bool favorite) async {
    await setSongsFavoriteWithUndo(
      context: context,
      ref: ref,
      i18n: context.smPlayerI18n,
      songIds: songIds,
      favorite: favorite,
    );
  }

  void _showAddToMenu({
    required List<int> songIds,
    required String defaultPlaylistName,
    required List<MultiSelectCommandBarPlaylist> playlists,
    required MusicLibrarySnapshot snapshot,
    required SmPlayerI18n i18n,
  }) {
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: songIds,
      playlists: playlists,
      includeNowPlaying: true,
      includeFavorites: _hasNotFavoriteSongs(songIds, songsById),
      onAddToNowPlaying: () {
        _addSongsToNowPlaying(songIds);
      },
      onToggleFavorite: () {
        _toggleSongsFavorite(_notFavoriteSongIds(songIds, songsById), true);
      },
      onCreatePlaylist: () {
        _createPlaylist(defaultPlaylistName, songIds, snapshot, i18n);
      },
      onAddToPlaylist: (playlistId) {
        _addSongsToPlaylist(playlistId, songIds);
      },
    );

    if (addToItem == null) {
      return;
    }

    showMenuFlyout(context, items: addToItem.submenu);
  }

  Future<void> _createPlaylist(
    String defaultName,
    List<int> songIds,
    MusicLibrarySnapshot snapshot,
    SmPlayerI18n i18n,
  ) async {
    final name = await _requestPlaylistName(
      i18n: i18n,
      defaultName: defaultName,
      playlists: snapshot.playlists,
    );
    if (name == null) {
      return;
    }

    await ref.read(libraryRepositoryProvider).createPlaylist(name, songIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  Future<String?> _requestPlaylistName({
    required SmPlayerI18n i18n,
    required String defaultName,
    required List<LibraryPlaylist> playlists,
  }) async {
    final result = await showSmPlayerInputDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('playlists.createNew'),
      defaultValue: defaultName,
      placeholder: i18n.t('playlists.namePlaceholder'),
      confirmText: i18n.t('playlists.create'),
      validate: (name) {
        return validatePlaylistName(name, playlists, '', i18n);
      },
    );
    return result;
  }

  Future<void> _searchDirectory(FolderNode folder, SmPlayerI18n i18n) async {
    final query = await _requestSearchDirectoryQuery(folder, i18n);
    if (query == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    ref
        .read(libraryRepositoryProvider)
        .addRecentSearch(query, SearchHistoryType.folders);
    context.go(
      Uri(
        path: '/search',
        queryParameters: {
          'query': query,
          'type': 'folders',
          'folder': folder.relativePath,
        },
      ).toString(),
    );
  }

  Future<String?> _requestSearchDirectoryQuery(
    FolderNode folder,
    SmPlayerI18n i18n,
  ) async {
    return showSmPlayerInputDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('local.searchDirectoryPrompt', {'name': folder.name}),
      defaultValue: '',
      confirmText: i18n.t('common.search'),
      validate: (query) {
        return query.isEmpty ? i18n.t('local.searchQueryEmpty') : '';
      },
    );
  }

  bool _hasNotFavoriteSongs(
    List<int> songIds,
    Map<int, LibrarySong> songsById,
  ) {
    return songIds.any((songId) => !songsById[songId]!.favorite);
  }

  List<int> _notFavoriteSongIds(
    List<int> songIds,
    Map<int, LibrarySong> songsById,
  ) {
    return songIds.where((songId) => !songsById[songId]!.favorite).toList();
  }

  Future<void> _revealFolder(FolderNode folder) async {
    await openFolderInShell(folder.path);
  }

  Future<void> _revealSong(LibrarySong song) async {
    await revealItemInFolder(song.path);
  }

  void _jumpToSongKey(
    String key,
    Map<String, int> songQuickJumpMap, {
    required double rowExtent,
  }) {
    final index = songQuickJumpMap[key];
    if (index == null) {
      return;
    }

    _scrollController.animateTo(
      index * rowExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _formatLocalRefreshResult(
  LocalFolderRefreshResult result,
  SmPlayerI18n i18n,
) {
  final messages = [
    if (result.filesAdded.isNotEmpty)
      i18n.t('local.refreshAddedMultiple', {'count': result.filesAdded.length}),
    if (result.filesRemoved.isNotEmpty)
      i18n.t('local.refreshRemovedMultiple', {
        'count': result.filesRemoved.length,
      }),
    if (result.filesMoved.isNotEmpty)
      i18n.t('local.refreshMovedMultiple', {'count': result.filesMoved.length}),
    if (result.artistSplitsApplied.isNotEmpty)
      i18n.t('local.refreshArtistSplitsAppliedGroup', {
        'count': result.artistSplitsApplied.length,
      }),
    if (result.artistSplitSuggestions.isNotEmpty)
      i18n.t('local.refreshArtistSplitSuggestionsGroup', {
        'count': result.artistSplitSuggestions.length,
      }),
  ];
  return messages.isEmpty
      ? i18n.t('local.refreshNoChange')
      : messages.join(i18n.t('common.comma'));
}

String _relativeFileTitle(String filePath, String folderPath) {
  final normalizedFilePath = normalizePath(filePath);
  final normalizedFolderPath = normalizePath(folderPath);
  final filePathKey = normalizedFilePath.toLowerCase();
  final folderPathKey = normalizedFolderPath.toLowerCase();
  final relativePath =
      filePathKey.startsWith('$folderPathKey/')
          ? normalizedFilePath.substring(normalizedFolderPath.length + 1)
          : normalizedFilePath;
  return _fileTitle(relativePath);
}

String _fileTitle(String filePath) {
  final name = normalizePath(filePath).split('/').last;
  final extensionIndex = name.lastIndexOf('.');
  return extensionIndex > 0 ? name.substring(0, extensionIndex) : name;
}

class _LocalScaffold extends StatelessWidget {
  const _LocalScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: SizedBox.expand(child: child),
    );
  }
}

class _LocalContentPanel extends StatelessWidget {
  const _LocalContentPanel({
    required this.scrollController,
    required this.scrollable,
    required this.child,
  });

  final ScrollController scrollController;
  final bool scrollable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LocalPageColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LocalPageColors.panelBorder),
        boxShadow: const [
          BoxShadow(
            color: LocalPageColors.panelShadow,
            offset: Offset(0, 22),
            blurRadius: 52,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child:
            scrollable
                ? SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 18),
                  child: child,
                )
                : child,
      ),
    );
  }
}

class _LocalProgressOverlay extends StatelessWidget {
  const _LocalProgressOverlay({
    required this.title,
    required this.progress,
    required this.onCancel,
  });

  final String title;
  final LocalFolderRefreshProgress progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final value = progress.current / progress.total;
    final stageText = switch (progress.stage) {
      LocalFolderRefreshStage.checking => i18n.t(
        'local.updateFolderProgressActionChecking',
      ),
      LocalFolderRefreshStage.reading => i18n.t(
        'local.updateFolderProgressActionReading',
      ),
      LocalFolderRefreshStage.updating => i18n.t(
        'local.updateFolderProgressActionUpdating',
      ),
    };
    final countText = switch (progress.stage) {
      LocalFolderRefreshStage.checking => i18n.t(
        'local.updateFolderProgressChecked',
        {'count': progress.current, 'total': progress.total},
      ),
      LocalFolderRefreshStage.reading ||
      LocalFolderRefreshStage.updating => i18n.t(
        'local.updateFolderProgressProcessedSongs',
        {'count': progress.processedSongCount, 'total': progress.songCount},
      ),
    };

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.28),
      child: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: LocalPageColors.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LocalPageColors.panelBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: LocalPageColors.textStrong,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (onCancel != null)
                    TextButton(
                      onPressed: onCancel,
                      child: Text(i18n.t('local.updateFolderProgressStop')),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                stageText,
                style: const TextStyle(
                  color: LocalPageColors.textStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: value.clamp(0, 1).toDouble()),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  Text(
                    countText,
                    style: const TextStyle(color: LocalPageColors.textMuted),
                  ),
                  Text(
                    '${i18n.t('local.updateFolderProgressAdded')}: ${progress.addedCount}',
                    style: const TextStyle(color: LocalPageColors.textMuted),
                  ),
                  Text(
                    '${i18n.t('local.updateFolderProgressUpdated')}: ${progress.updatedCount}',
                    style: const TextStyle(color: LocalPageColors.textMuted),
                  ),
                  Text(
                    '${i18n.t('local.updateFolderProgressMissing')}: ${progress.missingCount}',
                    style: const TextStyle(color: LocalPageColors.textMuted),
                  ),
                ],
              ),
              if (progress.currentPath.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  progress.stage == LocalFolderRefreshStage.checking
                      ? i18n.t('local.updateFolderProgressCurrentFolder', {
                        'name': _fileTitle(progress.currentPath),
                      })
                      : _fileTitle(progress.currentPath),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: LocalPageColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalRefreshResultDialog extends StatefulWidget {
  const _LocalRefreshResultDialog({
    required this.folder,
    required this.result,
    required this.onClose,
  });

  final FolderNode folder;
  final LocalFolderRefreshResult result;
  final VoidCallback onClose;

  @override
  State<_LocalRefreshResultDialog> createState() =>
      _LocalRefreshResultDialogState();
}

class _LocalRefreshResultDialogState extends State<_LocalRefreshResultDialog> {
  late _LocalRefreshResultTab _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = _initialTab();
  }

  _LocalRefreshResultTab _initialTab() {
    if (_artistUpdateCount > 0) {
      return _LocalRefreshResultTab.artists;
    }
    if (widget.result.filesAdded.isNotEmpty) {
      return _LocalRefreshResultTab.added;
    }
    if (widget.result.filesRemoved.isNotEmpty) {
      return _LocalRefreshResultTab.removed;
    }
    if (widget.result.filesMoved.isNotEmpty) {
      return _LocalRefreshResultTab.moved;
    }
    return _LocalRefreshResultTab.added;
  }

  int get _artistUpdateCount =>
      widget.result.artistSplitsApplied.length +
      widget.result.artistSplitSuggestions.length +
      widget.result.artistMergeSuggestions.length;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final tabs = [
      if (widget.result.filesAdded.isNotEmpty)
        _LocalRefreshTabItem(
          tab: _LocalRefreshResultTab.added,
          label: i18n.t('local.refreshAddedTab'),
          count: widget.result.filesAdded.length,
          icon: FluentIcons.music_note_2_20_regular,
        ),
      if (widget.result.filesRemoved.isNotEmpty)
        _LocalRefreshTabItem(
          tab: _LocalRefreshResultTab.removed,
          label: i18n.t('local.refreshRemovedTab'),
          count: widget.result.filesRemoved.length,
          icon: FluentIcons.music_note_2_20_regular,
        ),
      if (widget.result.filesMoved.isNotEmpty)
        _LocalRefreshTabItem(
          tab: _LocalRefreshResultTab.moved,
          label: i18n.t('local.refreshMovedTab'),
          count: widget.result.filesMoved.length,
          icon: FluentIcons.music_note_2_20_regular,
        ),
      if (_artistUpdateCount > 0)
        _LocalRefreshTabItem(
          tab: _LocalRefreshResultTab.artists,
          label: i18n.t('local.refreshArtistUpdatesTab'),
          count: _artistUpdateCount,
          icon: FluentIcons.people_20_regular,
        ),
    ];

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.28),
      child: Center(
        child: Container(
          width: 620,
          constraints: const BoxConstraints(maxHeight: 620),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          decoration: BoxDecoration(
            color: LocalPageColors.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LocalPageColors.panelBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      i18n.t('local.updateResultOfFolder', {
                        'name':
                            widget.folder.name.isEmpty
                                ? i18n.t('local.libraryRoot')
                                : widget.folder.name,
                      }),
                      style: const TextStyle(
                        color: LocalPageColors.textStrong,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: i18n.t('common.close'),
                    onPressed: widget.onClose,
                    icon: const Icon(FluentIcons.dismiss_24_regular),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child:
                    !widget.result.hasChanges
                        ? Text(
                          i18n.t('local.refreshNoChange'),
                          style: const TextStyle(
                            color: LocalPageColors.textMuted,
                          ),
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final tab in tabs)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: _LocalRefreshTabButton(
                                        item: tab,
                                        selected: tab.tab == _activeTab,
                                        onPressed: () {
                                          setState(() {
                                            _activeTab = tab.tab;
                                          });
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Expanded(child: _buildActiveTabContent()),
                          ],
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    return switch (_activeTab) {
      _LocalRefreshResultTab.added => _LocalRefreshSection(
        folderPath: widget.folder.path,
        paths: widget.result.filesAdded,
      ),
      _LocalRefreshResultTab.removed => _LocalRefreshSection(
        folderPath: widget.folder.path,
        paths: widget.result.filesRemoved,
      ),
      _LocalRefreshResultTab.moved => _LocalRefreshSection(
        folderPath: widget.folder.path,
        paths: widget.result.filesMoved,
      ),
      _LocalRefreshResultTab.artists => _LocalArtistRefreshSection(
        result: widget.result,
      ),
    };
  }
}

enum _LocalRefreshResultTab { added, removed, moved, artists }

class _LocalRefreshTabItem {
  const _LocalRefreshTabItem({
    required this.tab,
    required this.label,
    required this.count,
    required this.icon,
  });

  final _LocalRefreshResultTab tab;
  final String label;
  final int count;
  final IconData icon;
}

class _LocalRefreshTabButton extends StatelessWidget {
  const _LocalRefreshTabButton({
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final _LocalRefreshTabItem item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          selected
              ? LocalPageColors.accentSoft
              : LocalPageColors.surfaceCardHover,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  selected
                      ? LocalPageColors.accentStrong
                      : LocalPageColors.panelBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 18, color: LocalPageColors.accentStrong),
              const SizedBox(width: 7),
              Text(
                item.label,
                style: TextStyle(
                  color:
                      selected
                          ? LocalPageColors.textStrong
                          : LocalPageColors.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                item.count.toString(),
                style: const TextStyle(
                  color: LocalPageColors.textStrong,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalRefreshSection extends StatelessWidget {
  const _LocalRefreshSection({required this.folderPath, required this.paths});

  final String folderPath;
  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      itemExtent: 58,
      itemCount: paths.length,
      itemBuilder: (context, index) {
        final path = paths[index];
        return DecoratedBox(
          decoration: BoxDecoration(
            color:
                index.isEven
                    ? LocalPageColors.surfaceCardHover
                    : LocalPageColors.panel,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _relativeFileTitle(path, folderPath),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LocalPageColors.textStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LocalArtistRefreshSection extends StatelessWidget {
  const _LocalArtistRefreshSection({required this.result});

  final LocalFolderRefreshResult result;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final separator = i18n.t('common.artistSeparator');
    final items = [
      ...result.artistSplitsApplied,
      ...result.artistSplitSuggestions,
      ...result.artistMergeSuggestions,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            i18n.t('local.refreshArtistUpdatesTab'),
            style: const TextStyle(
              color: LocalPageColors.textStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${item.title}: ${item.artist} -> ${item.artists.join(separator)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: LocalPageColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _LocalEmptyState extends StatelessWidget {
  const _LocalEmptyState({required this.title, this.message = '', this.action});

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: LocalPageColors.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LocalPageColors.panelBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: 104,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: LocalPageColors.artwork,
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    child: Icon(
                      FluentIcons.music_note_2_24_regular,
                      color: LocalPageColors.artworkIcon,
                      size: 62,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: LocalPageColors.textStrong,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: LocalPageColors.textMuted,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
