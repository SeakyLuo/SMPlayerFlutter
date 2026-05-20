import 'dart:io';
import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/app_i18n.dart';
import '../../playback/media_control_model.dart';
import '../../playback/media_control_provider.dart';
import '../data/library_models.dart';
import '../data/library_providers.dart';
import 'artists_page_model.dart';
import 'command_bar.dart';
import 'headered_playlist_model.dart'
    show getNextPlaylistName, validatePlaylistName;
import 'library_page_actions.dart'
    show hideSongFile, moveSongToFolder, requestDeleteSongFromDisk;
import 'local_folder_model.dart';
import 'local_grid_content.dart';
import 'local_page_model.dart';
import 'local_page_quick_jump.dart';
import 'local_title_grid.dart';

const localCompactBreakpoint = 720.0;

class LocalPage extends ConsumerStatefulWidget {
  const LocalPage({
    super.key,
    this.currentRelativePath = '',
    this.searchQuery = '',
  });

  final String currentRelativePath;
  final String searchQuery;

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
      return const _LocalScaffold(child: _LoadingState());
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const _LocalScaffold(child: _LoadingState());
    }

    return snapshotValue.when(
      loading: () => const _LocalScaffold(child: _LoadingState()),
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
      return _LocalScaffold(
        child: _LocalEmptyState(
          title: i18n.t('local.noRoot'),
          message: i18n.t('local.noRootCopy'),
          action: TextButton.icon(
            onPressed: () => context.go('/settings'),
            icon: const Icon(FluentIcons.settings_20_regular),
            label: Text(i18n.t('library.chooseFolder')),
          ),
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
                      child:
                          childFolders.isEmpty && currentSongs.isEmpty
                              ? _buildEmptyContent(i18n, snapshot)
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
                                    (key) =>
                                        _jumpToSongKey(key, songQuickJumpMap),
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
          onPressed: () => context.go('/settings'),
          icon: const Icon(FluentIcons.settings_20_regular),
          label: Text(i18n.t('local.goToSettings')),
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

  void _showFolderMenu({
    required Offset position,
    required FolderNode folder,
    required Map<String, FolderNode> nodes,
    required Map<int, LibrarySong> songsById,
    required List<MultiSelectCommandBarPlaylist> playlists,
    required MusicLibrarySnapshot snapshot,
    required SmPlayerI18n i18n,
  }) {
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
        _buildFolderPreferenceMenuItem(i18n, folder),
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
          moveSongToFolder(ref, song.id, folderPath);
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
          hideSongFile(ref, song.id);
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
        onSeeMusicInfo: () => _showMessage(i18n.t('context.seeMusicInfo')),
        onSeeLyrics: () => _showMessage(i18n.t('context.seeLyrics')),
        onSeeAlbumArt: () => _showMessage(i18n.t('context.seeAlbumArt')),
        onSeeLocal: () => _revealSong(song),
      ),
    );
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
  ) {
    return MenuFlyoutItem(
      key: 'preference',
      text: i18n.t('settings.preferenceSettings'),
      icon: FluentIcons.star_20_regular,
      submenu: [
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
            onPressed: () async {
              await ref
                  .read(libraryRepositoryProvider)
                  .addPreferenceItem('folder', folder.path, folder.name, level);
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
            folder.relativePath != getParentPath(sourceFolder.relativePath) &&
            !folder.relativePath.startsWith('${sourceFolder.relativePath}/'),
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
      await ref
          .read(libraryRepositoryProvider)
          .moveLocalItemsToFolder(songIds, folderPaths, targetFolderPath);
      if (!mounted) {
        return;
      }
      ref.invalidate(musicLibrarySnapshotProvider);
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
    setState(() {
      _localOperationTitle = i18n.t('local.updateFolderProgressTitle');
      _refreshProgress = const LocalFolderRefreshProgress(
        current: 0,
        total: 1,
        currentPath: '',
      );
    });

    try {
      final result = await ref
          .read(libraryRepositoryProvider)
          .refreshLocalFolder(
            folder.path,
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
        _refreshResultDialog = (folder: folder, result: result);
      });
      _showMessage(_formatLocalRefreshResult(result, i18n));
    } catch (_) {
      if (mounted) {
        setState(() {
          _refreshProgress = null;
          _localOperationTitle = null;
        });
        _showMessage(i18n.t('local.updateFolder'));
      }
    }
  }

  Future<void> _requestDeleteLocalItems({
    required List<int> songIds,
    required List<String> folderPaths,
    required SmPlayerI18n i18n,
  }) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: Text(i18n.t('context.deleteFromDisk')),
                content: Text(
                  _formatDeleteSelectedLocalItemsConfirm(
                    i18n,
                    songIds.length + folderPaths.length,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(i18n.t('common.cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(i18n.t('context.deleteFromDisk')),
                  ),
                ],
              ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    await ref
        .read(libraryRepositoryProvider)
        .deleteLocalItems(songIds, folderPaths);
    ref.invalidate(musicLibrarySnapshotProvider);
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
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: Text(i18n.t('local.deleteFolder')),
                content: Text(
                  i18n.t('local.deleteFolderConfirm', {'name': folder.name}),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(i18n.t('common.cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(i18n.t('local.deleteFolder')),
                  ),
                ],
              ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    await ref.read(libraryRepositoryProvider).deleteLocalItems(const [], [
      folder.path,
    ]);
    ref.invalidate(musicLibrarySnapshotProvider);
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
    final folder = createFolderNode(relativePath, rootPath);
    await Directory(folder.path).create();
    if (!mounted) {
      return;
    }

    setState(() {
      _createdFolderPaths.add(relativePath);
    });
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
    final controller = TextEditingController(text: defaultName);
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(title ?? i18n.t('local.newFolderPrompt')),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(errorText: errorText),
                onSubmitted: (_) {
                  final name = controller.text.trim();
                  final validation = validate(name);
                  if (validation.isNotEmpty) {
                    setDialogState(() {
                      errorText = validation;
                    });
                    return;
                  }
                  Navigator.of(dialogContext).pop(name);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(i18n.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    final validation = validate(name);
                    if (validation.isNotEmpty) {
                      setDialogState(() {
                        errorText = validation;
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(name);
                  },
                  child: Text(i18n.t('playlists.create')),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  void _addSongsToNowPlaying(List<int> songIds) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    ref.read(libraryRepositoryProvider).replaceNowPlaying([
      ...snapshot.nowPlaying.songIds,
      ...songIds,
    ]);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  Future<void> _addSongsToPlaylist(int playlistId, List<int> songIds) async {
    await ref
        .read(libraryRepositoryProvider)
        .addSongsToPlaylist(playlistId, songIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  Future<void> _toggleSongsFavorite(List<int> songIds, bool favorite) async {
    await ref
        .read(libraryRepositoryProvider)
        .setSongsFavorite(songIds, favorite);
    final mediaController = ref.read(mediaControlControllerProvider);
    if (songIds.contains(mediaController.state.track.id) &&
        mediaController.state.track.favorite != favorite) {
      mediaController.onToggleFavorite();
    }
    ref.invalidate(musicLibrarySnapshotProvider);
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
    final controller = TextEditingController(text: defaultName);
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(i18n.t('playlists.createNew')),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: i18n.t('playlists.namePlaceholder'),
                  errorText: errorText,
                ),
                onSubmitted: (_) {
                  final name = controller.text.trim();
                  final validation = validatePlaylistName(
                    name,
                    playlists,
                    '',
                    i18n,
                  );
                  if (validation.isNotEmpty) {
                    setDialogState(() {
                      errorText = validation;
                    });
                    return;
                  }
                  Navigator.of(dialogContext).pop(name);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(i18n.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    final validation = validatePlaylistName(
                      name,
                      playlists,
                      '',
                      i18n,
                    );
                    if (validation.isNotEmpty) {
                      setDialogState(() {
                        errorText = validation;
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(name);
                  },
                  child: Text(i18n.t('playlists.create')),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
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
    return showDialog<String>(
      context: context,
      builder: (_) => _SearchDirectoryDialog(folder: folder, i18n: i18n),
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
    if (Platform.isWindows) {
      await Process.run('explorer', [folder.path]);
      return;
    }

    if (Platform.isMacOS) {
      await Process.run('open', [folder.path]);
      return;
    }

    await Process.run('xdg-open', [folder.path]);
  }

  Future<void> _revealSong(LibrarySong song) async {
    if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', song.path]);
      return;
    }

    if (Platform.isMacOS) {
      await Process.run('open', ['-R', song.path]);
      return;
    }

    await Process.run('xdg-open', [_getAbsoluteParentPath(song.path)]);
  }

  void _jumpToSongKey(String key, Map<String, int> songQuickJumpMap) {
    final index = songQuickJumpMap[key];
    if (index == null) {
      return;
    }

    _scrollController.animateTo(
      (index * 232).toDouble(),
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
    required this.child,
  });

  final ScrollController scrollController;
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
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 18),
          child: child,
        ),
      ),
    );
  }
}

class _SearchDirectoryDialog extends StatefulWidget {
  const _SearchDirectoryDialog({required this.folder, required this.i18n});

  final FolderNode folder;
  final SmPlayerI18n i18n;

  @override
  State<_SearchDirectoryDialog> createState() => _SearchDirectoryDialogState();
}

class _SearchDirectoryDialogState extends State<_SearchDirectoryDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    return AlertDialog(
      title: Text(
        i18n.t('local.searchDirectoryPrompt', {'name': widget.folder.name}),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(errorText: _errorText),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(i18n.t('common.cancel')),
        ),
        FilledButton(onPressed: _confirm, child: Text(i18n.t('common.search'))),
      ],
    );
  }

  void _confirm() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _errorText = widget.i18n.t('local.searchQueryEmpty');
      });
      return;
    }

    Navigator.of(context).pop(query);
  }
}

class _LocalProgressOverlay extends StatelessWidget {
  const _LocalProgressOverlay({required this.title, required this.progress});

  final String title;
  final LocalFolderRefreshProgress progress;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final value = progress.current / progress.total;

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
              Text(
                title,
                style: const TextStyle(
                  color: LocalPageColors.textStrong,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: value.clamp(0, 1).toDouble()),
              const SizedBox(height: 10),
              Text(
                i18n.t('local.updateFolderProgressProcessedItems', {
                  'count': progress.current,
                  'total': progress.total,
                }),
                style: const TextStyle(color: LocalPageColors.textMuted),
              ),
              if (progress.currentPath.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _fileTitle(progress.currentPath),
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

class _LocalRefreshResultDialog extends StatelessWidget {
  const _LocalRefreshResultDialog({
    required this.folder,
    required this.result,
    required this.onClose,
  });

  final FolderNode folder;
  final LocalFolderRefreshResult result;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

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
                            folder.name.isEmpty
                                ? i18n.t('local.libraryRoot')
                                : folder.name,
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
                    onPressed: onClose,
                    icon: const Icon(FluentIcons.dismiss_24_regular),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!result.hasChanges)
                        Text(
                          i18n.t('local.refreshNoChange'),
                          style: const TextStyle(
                            color: LocalPageColors.textMuted,
                          ),
                        ),
                      _LocalRefreshSection(
                        title: i18n.t('local.refreshAddedGroup', {
                          'count': result.filesAdded.length,
                        }),
                        folderPath: folder.path,
                        paths: result.filesAdded,
                      ),
                      _LocalRefreshSection(
                        title: i18n.t('local.refreshRemovedGroup', {
                          'count': result.filesRemoved.length,
                        }),
                        folderPath: folder.path,
                        paths: result.filesRemoved,
                      ),
                      _LocalRefreshSection(
                        title: i18n.t('local.refreshMovedGroup', {
                          'count': result.filesMoved.length,
                        }),
                        folderPath: folder.path,
                        paths: result.filesMoved,
                      ),
                      if (result.artistSplitsApplied.isNotEmpty ||
                          result.artistSplitSuggestions.isNotEmpty)
                        _LocalArtistRefreshSection(result: result),
                    ],
                  ),
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
  const _LocalRefreshSection({
    required this.title,
    required this.folderPath,
    required this.paths,
  });

  final String title;
  final String folderPath;
  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: LocalPageColors.textStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final path in paths)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _relativeFileTitle(path, folderPath),
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 30,
        child: CircularProgressIndicator(strokeWidth: 2.5),
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
