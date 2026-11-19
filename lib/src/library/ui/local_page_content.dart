part of 'local_page.dart';

extension _LocalPageContent on _LocalPageState {
  Widget _buildPage(
    BuildContext context,
    LibraryContentData snapshot,
    SmPlayerI18n i18n, {
    bool contentUnavailable = false,
    bool contentLoading = false,
  }) {
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
            if (_refreshProgress != null) _buildScanProgressOverlay(i18n),
          ],
        ),
      );
    }

    final folderIndex = _dataCache.folders(
      snapshot,
      created: _createdFolderPaths,
      songFolderPaths: _remoteSongFolders,
      rootName:
          _remote && !contentUnavailable && !contentLoading
              ? ref.read(remoteDirectoryProvider(_source)).requireValue.rootName
              : null,
    );
    final nodes = folderIndex.nodes;
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateLocalPageState(() {});
      });
    }

    final currentSongs = sortSongs(
      currentNode.directSongIds
          .map((songId) => songsById[songId]!)
          .where((song) => matchesSongSearch(song, widget.searchQuery))
          .toList(),
      _sortMode,
      currentSortMode,
      _dataCache.sortKeys,
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
      _dataCache.sortKeys,
    );
    final localCompactFolderTreeRows = buildLocalCompactFolderTreeRows(
      childFolders: childFolders,
      nodes: nodes,
      songsById: songsById,
      expandedFolderPaths: _treeExpandedFolderPaths,
      sortMode: _sortMode,
      searchQuery: widget.searchQuery,
      sortKeys: _dataCache.sortKeys,
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
        childFolders.isNotEmpty && currentNode.directCount > 0;
    final visibleSongIds = currentSongs.map((song) => song.id).toList();
    final folderQueueSongIds =
        currentNode.directSongIds
            .map((songId) => songsById[songId]!)
            .where((song) => matchesSongSearch(song, widget.searchQuery))
            .map((song) => song.id)
            .toList();
    final hasSubfolderSongs = currentNode.songCount > currentNode.directCount;
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
    final mediaState = ref.watch(
      mediaControlControllerProvider.select(
        (controller) => (
          trackId: controller.state.track.id,
          isPlaying: controller.state.isPlaying,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final colors = LocalPageColors.of(context);
        final isCompactLayout = constraints.maxWidth < localCompactBreakpoint;
        final selectableFolderPaths =
            isCompactLayout
                ? localCompactFolderTreeFolderPaths
                : childFolders.map((folder) => folder.relativePath).toList();
        final selectableFolderPathSet = selectableFolderPaths.toSet();
        final effectiveSelectedFolderPaths =
            _selectedFolderPaths
                .where(selectableFolderPathSet.contains)
                .toList();
        final effectiveSelectedSongIds = _selectedSongIds.toList();
        final selectedFolderAbsolutePaths =
            effectiveSelectedFolderPaths
                .map((folderPath) => nodes[folderPath]!.path)
                .toList();
        final selectedQueueSongIds =
            selectedFolderAbsolutePaths.isEmpty
                ? effectiveSelectedSongIds
                : watchLibraryScopeIds(
                      ref,
                      LibraryDataQuery(
                        LibraryQueryKind.songs,
                        source: _source,
                        songIds: effectiveSelectedSongIds,
                        recursiveFolders: selectedFolderAbsolutePaths,
                      ),
                    ).valueOrNull ??
                    const <int>[];
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
            _updateLocalPageState(() {
              _hideMultiSelectAfterOperation(
                snapshot.hideMultiSelectCommandBarAfterOperation,
              );
            });
          },
        );
        final showsInlineTitle = !WorkspaceNavigationAppBarScope.of(context);
        final trailingAlignmentInset = localPageScrollbarGutter(
          isCompactLayout,
        );
        return LocalPageScaffold(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showsInlineTitle) ...[
                    Padding(
                      padding: EdgeInsets.only(
                        left: isCompactLayout ? 8 : 12,
                        right: trailingAlignmentInset,
                      ),
                      child: LocalTitleGrid(
                        nodes: nodes,
                        i18n: i18n,
                        rootPath: snapshot.rootPath,
                        currentRelativePath: widget.currentRelativePath,
                        onHiddenFoldersListButtonClick:
                            () => context.push<void>('/hidden-folders'),
                        onCurrentFolderClick:
                            contentUnavailable
                                ? () {
                                  RemotePageAccessScope.of(context).retry();
                                  final directory = remoteDirectoryProvider(
                                    _source,
                                  );
                                  final windows =
                                      libraryDirectoryWindowsProvider(
                                        _windowQuery!,
                                      );
                                  if (ref.read(directory).hasError) {
                                    ref.invalidate(directory);
                                  }
                                  if (ref.read(windows).hasError) {
                                    ref.invalidate(windows);
                                  }
                                }
                                : _scrollCurrentFolderToTop,
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
                          _updateLocalPageState(_clearMultiSelectStatus);
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
                    ),
                    const SizedBox(height: 12),
                  ],
                  Padding(
                    padding: EdgeInsets.only(
                      left: isCompactLayout ? 8 : 12,
                      right: trailingAlignmentInset,
                    ),
                    child: _buildDirectoryCommandBar(
                      context,
                      i18n,
                      currentNode,
                      snapshot,
                      nodes,
                      colors,
                      isCompactLayout,
                      contentUnavailable,
                      childFolders.length,
                      currentNode.directCount,
                      visibleSongIds,
                      hasSubfolderSongs,
                    ),
                  ),
                  SizedBox(height: isCompactLayout ? 8 : 16),
                  Expanded(
                    child: LocalPageContentPanel(
                      scrollController: _scrollController,
                      scrollable: false,
                      compact: isCompactLayout,
                      bottomPadding:
                          _multiSelect ? multiSelectCommandBarScrollSpacer : 28,
                      child:
                          contentUnavailable
                              ? (contentLoading
                                  ? const LocalDirectorySkeleton()
                                  : const SizedBox.shrink())
                              : childFolders.isEmpty &&
                                  currentNode.directCount == 0
                              ? buildLocalPageEmptyContent(
                                i18n: i18n,
                                snapshot: snapshot,
                                searchQuery: widget.searchQuery,
                                onOpenSettings: () => context.go('/settings'),
                              )
                              : LocalContentView(
                                songSliverKey: _songSliverKey,
                                locatedSongId: _locatedSongId,
                                songRows: currentNode.songRows,
                                totalSongs: currentNode.directCount,
                                onAccessSong:
                                    (index) => _accessFolderSong(
                                      currentNode.path,
                                      index,
                                    ),
                                onAccessFolderSong: _accessFolderSong,
                                childFolders: childFolders,
                                currentSongs: currentSongs,
                                nodes: nodes,
                                songsById: songsById,
                                selectedFolderPaths: _selectedFolderPaths,
                                selectedSongIds: _selectedSongIds,
                                selectedTrackId: mediaState.trackId,
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
                                    () => _updateLocalPageState(() {
                                      _foldersExpanded = !_foldersExpanded;
                                    }),
                                onToggleSongsExpanded:
                                    () => _updateLocalPageState(() {
                                      _songsExpanded = !_songsExpanded;
                                    }),
                                onToggleTreeFolderExpanded:
                                    (folderPath) => _updateLocalPageState(() {
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
                                    (folder, position) async => _showAddToMenu(
                                      position: position,
                                      songIds: await _folderScopeIds(folder),
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
                                onPlayTrack:
                                    (id, _) => _playDirectorySong(
                                      songsById[id]!,
                                      snapshot,
                                    ),
                                onPlaySong: _playSongImmediately,
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
                                      onPlayNext:
                                          !isCompactLayout &&
                                                  mediaState.trackId != null &&
                                                  song.id != mediaState.trackId
                                              ? () => _playNext(song.id)
                                              : null,
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
                visible: _multiSelect && !contentUnavailable,
                bottomInset: multiSelectCommandBarShellBottomInset,
                horizontalBleed: isCompactLayout ? 12 : 24,
                selectedCount: selectedLocalItemCount,
                playlists: customPlaylists,
                showPlay: selectedQueueSongIds.isNotEmpty,
                showAddTo: selectedQueueSongIds.isNotEmpty,
                addToSongIds: selectedQueueSongIds,
                nowPlayingSongIds: snapshot.nowPlaying.songIds,
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
                          _updateLocalPageState(() {
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
                          _updateLocalPageState(() {
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
                            _updateLocalPageState(() {
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
                          _updateLocalPageState(() {
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
                          _updateLocalPageState(() {
                            _hideMultiSelectAfterOperation(
                              snapshot.hideMultiSelectCommandBarAfterOperation,
                            );
                          });
                        },
                onRemove:
                    !_canWriteDirectory
                        ? null
                        : () => _requestDeleteLocalItems(
                          songIds: effectiveSelectedSongIds,
                          folderPaths: selectedFolderAbsolutePaths,
                          i18n: i18n,
                        ),
                removeLabel: i18n.t('context.deleteFromDisk'),
                extraActions: [
                  if (_canWriteDirectory)
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
                                snapshot
                                    .hideMultiSelectCommandBarAfterOperation,
                          ),
                    ),
                ],
                onSelectAll:
                    () => unawaited(
                      _selectDirectoryScope(
                        currentNode,
                        selectableFolderPaths,
                        nodes,
                        reverse: false,
                      ),
                    ),
                onReverseSelection:
                    () => unawaited(
                      _selectDirectoryScope(
                        currentNode,
                        selectableFolderPaths,
                        nodes,
                        reverse: true,
                      ),
                    ),
                onClearSelection:
                    () => _updateLocalPageState(() {
                      _selectedFolderPaths.clear();
                      _selectedSongIds.clear();
                    }),
                onCancel: () => _updateLocalPageState(_clearMultiSelectStatus),
              ),
              if (_refreshProgress != null &&
                  (!_refreshFolderRunning || !_refreshFolderBackgrounded))
                _buildScanProgressOverlay(i18n),
              if (_refreshResultDialog case final dialog?)
                FolderUpdateResultDialog(
                  folder: dialog.folder,
                  result: dialog.result,
                  songs: snapshot.songs,
                  selectedTrackId: mediaState.trackId,
                  isPlaying: mediaState.isPlaying,
                  onPlay: (songId) {
                    if (songId == mediaState.trackId) {
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
                    _updateLocalPageState(() {
                      _refreshResultDialog = null;
                    });
                  },
                ),
              if (_musicDialog case final dialog?)
                MusicDialog(
                  song: dialog.song,
                  initialMode: dialog.mode,
                  currentTrackId: mediaState.trackId,
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
                    _updateLocalPageState(() {
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
