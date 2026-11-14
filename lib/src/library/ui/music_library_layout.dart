part of 'music_library_page.dart';

extension _MusicLibraryLayout on _MusicLibraryPageState {
  Widget _buildLibraryPage(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(
      browsingAvailableLibraryContentDataProvider,
    );
    final favoriteOverrides = ref.watch(libraryFavoriteOverridesProvider);
    final songOverrides = ref.watch(librarySongOverridesProvider);
    final playlistOverrides = ref.watch(libraryPlaylistOverridesProvider);
    final deletedPlaylistIds = ref.watch(libraryDeletedPlaylistIdsProvider);
    final playlistOrder = ref.watch(libraryPlaylistOrderProvider);

    if (i18nValue.isLoading) {
      return const _LibraryScaffold(child: SmPlayerLoadingState());
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const _LibraryScaffold(child: SmPlayerLoadingState());
    }

    return snapshotValue.when(
      skipLoadingOnReload: true,
      loading: () => const _LibraryScaffold(child: SmPlayerLoadingState()),
      error: (_, _) => const _LibraryScaffold(child: LibraryLoadFailure()),
      data: (snapshot) {
        final playlists = applyLibraryPlaylistOverridesToPlaylists(
          snapshot.playlists,
          playlistOverrides,
          deletedPlaylistIds,
          playlistOrder,
        );
        if (_snapshotSortCriterion != snapshot.sortCriterion) {
          _snapshotSortCriterion = snapshot.sortCriterion;
          _sortCriterion = snapshot.sortCriterion;
          _sortDirection = MusicLibrarySortDirection.ascending;
        }

        if (snapshot.songs.isEmpty) {
          return _LibraryScaffold(
            child: _EmptyState(
              title:
                  snapshot.hasLibrary
                      ? i18n.t('library.noSearchMatch', {
                        'query': widget.searchQuery,
                      })
                      : i18n.t(
                        ref.watch(musicShareProvider).selectedSource == 'local'
                            ? 'library.scanToBegin'
                            : 'share.emptyLibrary',
                      ),
              message:
                  snapshot.hasLibrary
                      ? i18n.t('library.tryAnotherSearch')
                      : i18n.t(
                        ref.watch(musicShareProvider).selectedSource == 'local'
                            ? 'library.scanHelp'
                            : 'share.connectHint',
                      ),
            ),
          );
        }

        final viewCache = _MusicLibraryViewCache.resolve(
          current: _viewCache,
          sourceSongs:
              snapshot.songs.where((song) => song.remoteAvailable).toList(),
          favoriteOverrides: favoriteOverrides,
          songOverrides: songOverrides,
          i18n: i18n,
        );
        _viewCache = viewCache;
        final sortedSongs = viewCache.songsFor(_sortCriterion, _sortDirection);
        final mediaState = ref.watch(
          mediaControlControllerProvider.select(
            (controller) => (
              trackId: controller.state.track.id,
              isPlaying: controller.state.isPlaying,
            ),
          ),
        );
        final quickJumpMap = viewCache.quickJumpMapFor(
          _sortCriterion,
          _sortDirection,
        );

        return SmPlayerI18nScope(
          i18n: i18n,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final colors = _LibraryPalette.of(context);
              final useWorkspaceAppBar = WorkspaceNavigationAppBarScope.of(
                context,
              );
              final compact = constraints.maxWidth < 720 && useWorkspaceAppBar;
              _compactLayout = compact;
              _syncAppBarPortal(
                showPortal: true,
                routePath: '/songs',
                title:
                    snapshot.showCount
                        ? i18n.t('library.allSongsWithCount', {
                          'count': sortedSongs.length,
                        })
                        : i18n.t('library.allSongs'),
                quickJumpActive: _quickJumpPanelOpen,
                multiSelect: _selection.multiSelect,
                multiSelectLabel: i18n.t('albums.multiSelect'),
                exitMultiSelectTooltip: i18n.t('common.exitMultiSelectTooltip'),
              );
              if (!compact && _quickJumpPanelOpen) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _updateLibraryState(() {
                      _quickJumpPanelOpen = false;
                    });
                  }
                });
              }
              final customPlaylists =
                  playlists
                      .where(
                        (playlist) =>
                            !playlist.isBuiltIn &&
                            canEditPlaylist(playlist) &&
                            playlistBelongsToSource(
                              playlist,
                              activeMusicShareAccess!.selectedSource,
                            ),
                      )
                      .map(
                        (playlist) => MultiSelectCommandBarPlaylist(
                          id: playlist.id,
                          name: playlist.name,
                          songIds: playlist.songIds,
                        ),
                      )
                      .toList();
              final activeQuickJumpKey = _activeQuickJumpKey(
                sortedSongs,
                compact,
                i18n,
              );
              final visibleSongIds = [for (final song in sortedSongs) song.id];
              final selectedVisibleSongs = [
                for (final song in sortedSongs)
                  if (_selection.isSelected(song.id)) song,
              ];
              final selectedVisibleSongIds = [
                for (final song in selectedVisibleSongs) song.id,
              ];
              return Stack(
                children: [
                  _LibraryScaffold(
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.escape): () {
                          if (_quickJumpPanelOpen) {
                            _updateLibraryState(() {
                              _quickJumpPanelOpen = false;
                            });
                          } else if (_selection.multiSelect) {
                            _updateLibraryState(_selection.cancel);
                          }
                        },
                      },
                      child: Focus(
                        child: NotificationListener<UserScrollNotification>(
                          onNotification: _handleUserScroll,
                          child: Stack(
                            children: [
                              DecoratedBox(
                                key: const ValueKey(
                                  'MusicLibrary.ContentShell',
                                ),
                                decoration: BoxDecoration(
                                  color: colors.panel,
                                  gradient: colors.panelGradient,
                                  borderRadius: BorderRadius.circular(
                                    compact ? 10 : 14,
                                  ),
                                  border: Border.all(color: colors.panelBorder),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.panelShadow,
                                      offset: Offset(0, 22),
                                      blurRadius: 52,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    compact ? 10 : 14,
                                  ),
                                  child: Padding(
                                    padding:
                                        compact
                                            ? EdgeInsets.zero
                                            : const EdgeInsets.all(10),
                                    child: Row(
                                      children: [
                                        if (!compact)
                                          _QuickJumpRail(
                                            activeKey: activeQuickJumpKey,
                                            keys: _quickJumpKeysForDirection(
                                              _sortDirection,
                                            ),
                                            enabledKeys:
                                                quickJumpMap.keys.toSet(),
                                            targetName: i18n.t('common.songs'),
                                            basisName:
                                                _libraryQuickJumpBasisName(
                                                  _sortCriterion,
                                                  i18n,
                                                ),
                                            i18n: i18n,
                                            onJump: (key) {
                                              _jumpToKey(
                                                quickJumpMap,
                                                key,
                                                compact,
                                              );
                                            },
                                          ),
                                        Expanded(
                                          child:
                                              compact
                                                  ? _CompactSongList(
                                                    songs: sortedSongs,
                                                    scrollController:
                                                        _scrollController,
                                                    sortCriterion:
                                                        _sortCriterion,
                                                    sortDirection:
                                                        _sortDirection,
                                                    selectedSongIds:
                                                        _selection
                                                            .selectedItems,
                                                    selectedTrackId:
                                                        mediaState.trackId,
                                                    isPlaying:
                                                        mediaState.isPlaying,
                                                    multiSelect:
                                                        _selection.multiSelect,
                                                    i18n: i18n,
                                                    onSort: _toggleSort,
                                                    onSelected: (songId) {
                                                      _selectSongFromPointer(
                                                        songId,
                                                        sortedSongs.map(
                                                          (song) => song.id,
                                                        ),
                                                      );
                                                    },
                                                    onAddNextAndPlay: (songId) {
                                                      _addNextAndPlay(songId);
                                                    },
                                                    onTogglePlayPause:
                                                        ref
                                                            .read(
                                                              mediaControlControllerProvider,
                                                            )
                                                            .onTogglePlayPause,
                                                    onToggleSelection:
                                                        _toggleSongSelection,
                                                    onToggleFavorite: (songId) {
                                                      final song = sortedSongs
                                                          .firstWhere(
                                                            (song) =>
                                                                song.id ==
                                                                songId,
                                                          );
                                                      setSongsFavoriteFromControl(
                                                        ref,
                                                        [songId],
                                                        !song.favorite,
                                                      );
                                                    },
                                                    onPlayNext: _playNext,
                                                    onOpenAddToPlaylistMenu: (
                                                      buttonContext,
                                                      song,
                                                    ) {
                                                      return _showSongAddToMenu(
                                                        buttonContext,
                                                        song,
                                                        customPlaylists,
                                                      );
                                                    },
                                                    onOpenContextMenu: (
                                                      position,
                                                      song,
                                                    ) {
                                                      return _openSongContextMenu(
                                                        position,
                                                        song,
                                                        sortedSongs,
                                                        customPlaylists,
                                                      );
                                                    },
                                                  )
                                                  : _WideSongTable(
                                                    songs: sortedSongs,
                                                    sortCriterion:
                                                        _sortCriterion,
                                                    sortDirection:
                                                        _sortDirection,
                                                    scrollController:
                                                        _scrollController,
                                                    selectedSongIds:
                                                        _selection
                                                            .selectedItems,
                                                    selectedTrackId:
                                                        mediaState.trackId,
                                                    isPlaying:
                                                        mediaState.isPlaying,
                                                    multiSelect:
                                                        _selection.multiSelect,
                                                    i18n: i18n,
                                                    columnWidths: _columnWidths,
                                                    onSort: _toggleSort,
                                                    onResizeColumn:
                                                        _resizeColumn,
                                                    onSelected: (songId) {
                                                      _selectSongFromPointer(
                                                        songId,
                                                        sortedSongs.map(
                                                          (song) => song.id,
                                                        ),
                                                      );
                                                    },
                                                    onAddNextAndPlay: (songId) {
                                                      _addNextAndPlay(songId);
                                                    },
                                                    onTogglePlayPause:
                                                        ref
                                                            .read(
                                                              mediaControlControllerProvider,
                                                            )
                                                            .onTogglePlayPause,
                                                    onToggleSelection:
                                                        _toggleSongSelection,
                                                    onToggleFavorite: (songId) {
                                                      final song = sortedSongs
                                                          .firstWhere(
                                                            (song) =>
                                                                song.id ==
                                                                songId,
                                                          );
                                                      setSongsFavoriteFromControl(
                                                        ref,
                                                        [songId],
                                                        !song.favorite,
                                                      );
                                                    },
                                                    onPlayNext: _playNext,
                                                    onOpenAddToPlaylistMenu: (
                                                      buttonContext,
                                                      song,
                                                    ) {
                                                      return _showSongAddToMenu(
                                                        buttonContext,
                                                        song,
                                                        customPlaylists,
                                                      );
                                                    },
                                                    onOpenContextMenu: (
                                                      position,
                                                      song,
                                                    ) {
                                                      return _openSongContextMenu(
                                                        position,
                                                        song,
                                                        sortedSongs,
                                                        customPlaylists,
                                                      );
                                                    },
                                                  ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (!compact)
                                Positioned(
                                  top: 54,
                                  right: 2,
                                  bottom: 10,
                                  width: 10,
                                  child: _MusicLibraryTableScrollbar(
                                    controller: _scrollController,
                                  ),
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
                                  onPlayTrack: (trackId, queueSongIds) {
                                    _playTrackInQueue(trackId, queueSongIds);
                                  },
                                  onReveal: (path) {
                                    unawaited(revealItemInFolder(path));
                                  },
                                  onSaved: () {
                                    notifyLyricsSaved(ref, dialog.song.id);
                                  },
                                  onClose: () {
                                    _updateLibraryState(() {
                                      _musicDialog = null;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (compact)
                    _AnimatedQuickJumpPanel(
                      visible: _quickJumpPanelOpen,
                      activeKey: activeQuickJumpKey,
                      keys: _quickJumpKeysForDirection(_sortDirection),
                      enabledKeys: quickJumpMap.keys.toSet(),
                      targetName: i18n.t('common.songs'),
                      basisName: _libraryQuickJumpBasisName(
                        _sortCriterion,
                        i18n,
                      ),
                      i18n: i18n,
                      underWorkspaceAppBar: useWorkspaceAppBar,
                      onDismiss: () {
                        _updateLibraryState(() {
                          _quickJumpPanelOpen = false;
                        });
                      },
                      onJump: (key) {
                        _jumpToKey(quickJumpMap, key, compact);
                        _updateLibraryState(() {
                          _quickJumpPanelOpen = false;
                        });
                      },
                    ),
                  MultiSelectCommandBar(
                    visible: _selection.multiSelect,
                    bottomInset: multiSelectCommandBarShellBottomInset,
                    selectedCount: selectedVisibleSongIds.length,
                    playlists: customPlaylists,
                    addToSongIds: selectedVisibleSongIds,
                    nowPlayingSongIds: snapshot.nowPlaying.songIds,
                    defaultPlaylistName: getNextPlaylistName(
                      i18n.t('common.songs'),
                      playlists,
                    ),
                    includeNowPlayingInAddTo: true,
                    includeFavoritesInAddTo: selectedVisibleSongs.any(
                      (song) => !song.favorite,
                    ),
                    onPlay:
                        selectedVisibleSongIds.isEmpty
                            ? null
                            : () => _playSongIds(selectedVisibleSongIds),
                    onAddToNowPlaying:
                        selectedVisibleSongIds.isEmpty
                            ? null
                            : () {
                              unawaited(
                                addSongsToNowPlayingWithUndo(
                                  context: context,
                                  ref: ref,
                                  i18n: i18n,
                                  songIds: selectedVisibleSongIds,
                                ),
                              );
                            },
                    onToggleFavorite:
                        selectedVisibleSongIds.isEmpty
                            ? null
                            : () {
                              unawaited(
                                setSongsFavoriteWithUndo(
                                  context: context,
                                  ref: ref,
                                  i18n: i18n,
                                  songIds: [
                                    for (final song in selectedVisibleSongs)
                                      if (!song.favorite) song.id,
                                  ],
                                  favorite: true,
                                ),
                              );
                            },
                    onCreatePlaylist:
                        selectedVisibleSongIds.isEmpty
                            ? null
                            : () async {
                              await createPlaylistWithSongs(
                                context: context,
                                ref: ref,
                                i18n: i18n,
                                playlists: playlists,
                                defaultName: getNextPlaylistName(
                                  i18n.t('common.songs'),
                                  playlists,
                                ),
                                songIds: selectedVisibleSongIds,
                              );
                            },
                    onAddToPlaylist:
                        selectedVisibleSongIds.isEmpty
                            ? null
                            : (playlistId) {
                              unawaited(
                                addSongsToPlaylistWithUndo(
                                  context: context,
                                  ref: ref,
                                  i18n: i18n,
                                  playlistId: playlistId,
                                  songIds: selectedVisibleSongIds,
                                ),
                              );
                            },
                    hideAfterOperation:
                        snapshot.hideMultiSelectCommandBarAfterOperation,
                    onSelectAll: () {
                      _updateLibraryState(() {
                        _selection.selectAll(visibleSongIds);
                      });
                    },
                    onReverseSelection: () {
                      _updateLibraryState(() {
                        _selection.reverseSelection(visibleSongIds);
                      });
                    },
                    onClearSelection: () {
                      _updateLibraryState(_selection.clearSelection);
                    },
                    onCancel: () {
                      _updateLibraryState(_selection.cancel);
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
