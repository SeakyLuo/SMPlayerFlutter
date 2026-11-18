part of 'playlists_page.dart';

extension _PlaylistsPageGrid on _PlaylistsPageState {
  Widget _buildGrid(
    BuildContext context,
    SmPlayerI18n i18n,
    LibraryContentData snapshot,
    List<int>? playlistOrder,
  ) {
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final customPlaylists =
        snapshot.playlists
            .where(
              (playlist) =>
                  !playlist.isBuiltIn &&
                  playlist.name != i18n.t('common.nowPlaying') &&
                  playlist.name != 'Now Playing',
            )
            .toList();
    final customPlaylistIds =
        customPlaylists.map((playlist) => playlist.id).toList();
    final orderedIds =
        _previewPlaylistIds ??
        _committedPlaylistIdsFor(customPlaylistIds) ??
        playlistOrder ??
        customPlaylistIds;
    final playlistById = {
      for (final playlist in customPlaylists) playlist.id: playlist,
    };
    final orderedPlaylists =
        orderedIds
            .map((playlistId) => playlistById[playlistId])
            .whereType<LibraryPlaylist>()
            .toList();
    final visiblePlaylists =
        _searchQuery.trim().isEmpty
            ? orderedPlaylists
            : _searchPlaylists(orderedPlaylists, songsById, _searchQuery);
    final searchSuggestions =
        _searchDraft.trim().isEmpty
            ? const <String>[]
            : _playlistSearchSuggestions(customPlaylists, songsById);
    final searchHistoryEntries = latestSearchHistoryEntries(
      ref.watch(recentSearchesProvider).valueOrNull ?? snapshot.recentSearches,
      SearchHistoryType.playlists,
    );
    final useWorkspaceAppBar = WorkspaceNavigationAppBarScope.of(context);
    _syncAppBarPortal(
      showPortal: true,
      routePath: '/playlists',
      title:
          snapshot.showCount
              ? i18n.t('search.playlistsWithCount', {
                'count':
                    snapshot.playlists
                        .where((playlist) => !playlist.isBuiltIn)
                        .length,
              })
              : i18n.t('common.playlists'),
      i18n: i18n,
      searchSuggestions: searchSuggestions,
      searchHistoryEntries: searchHistoryEntries,
      onCreatePlaylist:
          !canCreateSourcePlaylist()
              ? null
              : () {
                unawaited(_createPlaylist(context, i18n, snapshot));
              },
    );

    return Column(
      children: [
        if (!useWorkspaceAppBar) ...[
          _buildGridToolbar(
            i18n,
            searchSuggestions,
            searchHistoryEntries,
            !canCreateSourcePlaylist()
                ? null
                : () => unawaited(_createPlaylist(context, i18n, snapshot)),
          ),
          const SizedBox(height: 12),
        ],
        Expanded(
          child:
              visiblePlaylists.isEmpty
                  ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _PlaylistsEmptyState(
                      searching: _searchQuery.isNotEmpty,
                      onAction:
                          _searchQuery.isEmpty
                              ? !canCreateSourcePlaylist()
                                  ? null
                                  : () => unawaited(
                                    _createPlaylist(context, i18n, snapshot),
                                  )
                              : _clearSearch,
                      title:
                          _searchQuery.isEmpty
                              ? i18n.t('playlists.none')
                              : i18n.t('playlists.noMatch'),
                      message:
                          _searchQuery.isEmpty
                              ? i18n.t('playlists.noneCopy')
                              : i18n.t('playlists.noMatchCopy'),
                    ),
                  )
                  : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = _playlistGridColumns(
                        constraints.maxWidth,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(right: 18),
                        child: EdgeAutoHideScrollbar(
                          trailingEdgeOffset: 18,
                          builder:
                              (scrollController) => Listener(
                                onPointerMove: (event) {
                                  if (_draggingPlaylistId == null) {
                                    return;
                                  }
                                  _previewPlaylistMoveToPoint(
                                    customPlaylistIds,
                                    event.position,
                                  );
                                },
                                child: GridView.builder(
                                  key: const ValueKey('Playlists.GridView'),
                                  controller: scrollController,
                                  padding: _playlistGridPadding(
                                    useWorkspaceAppBar,
                                  ),
                                  gridDelegate: _playlistGridDelegate(columns),
                                  itemCount: visiblePlaylists.length,
                                  itemBuilder: (context, index) {
                                    final playlist = visiblePlaylists[index];
                                    final playlistSongs =
                                        playlist.songIds
                                            .map((songId) => songsById[songId])
                                            .whereType<LibrarySong>()
                                            .toList();
                                    return KeyedSubtree(
                                      key: ValueKey(
                                        'Playlists.PlaylistGridItem.${playlist.id}',
                                      ),
                                      child: Builder(
                                        builder: (targetContext) {
                                          _playlistCardContexts[playlist.id] =
                                              targetContext;
                                          return DragTarget<int>(
                                            onWillAcceptWithDetails: (details) {
                                              return details.data !=
                                                  playlist.id;
                                            },
                                            onMove: (details) {
                                              _previewPlaylistMoveToPoint(
                                                customPlaylistIds,
                                                details.offset,
                                              );
                                            },
                                            onAcceptWithDetails: (_) {
                                              _playlistDragAccepted = true;
                                              _commitPlaylistPreview();
                                            },
                                            builder: (context, _, __) {
                                              if (_draggingPlaylistId ==
                                                  playlist.id) {
                                                return _PlaylistDropPlaceholder(
                                                  i18n: i18n,
                                                );
                                              }

                                              return Draggable<int>(
                                                maxSimultaneousDrags:
                                                    canEditPlaylist(playlist)
                                                        ? 1
                                                        : 0,
                                                data: playlist.id,
                                                dragAnchorStrategy: (
                                                  draggable,
                                                  context,
                                                  position,
                                                ) {
                                                  final renderObject =
                                                      context.findRenderObject()
                                                          as RenderBox;
                                                  _playlistDragAnchorOffset =
                                                      renderObject
                                                          .globalToLocal(
                                                            position,
                                                          );
                                                  return _playlistDragAnchorOffset!;
                                                },
                                                feedback: Material(
                                                  color: Colors.transparent,
                                                  child: SizedBox(
                                                    width: _playlistCardWidth,
                                                    height: _playlistCardHeight,
                                                    child: GridViewHolder(
                                                      playlist: playlist,
                                                      songs: playlistSongs,
                                                      subtitle: i18n.t(
                                                        'playlists.songCount',
                                                        {
                                                          'count':
                                                              playlist
                                                                  .songCount,
                                                        },
                                                      ),
                                                      playTooltip: i18n.t(
                                                        'context.play',
                                                      ),
                                                      dragTooltip: i18n.t(
                                                        'playlists.dragToSort',
                                                      ),
                                                      cardKey: const ValueKey(
                                                        'Playlists.PlaylistCard',
                                                      ),
                                                      artworkKey: const ValueKey(
                                                        'Playlists.ArtworkSurface',
                                                      ),
                                                      dragging: true,
                                                      sorting: true,
                                                      selected: false,
                                                      onOpen: () {},
                                                      onPlay: () {},
                                                      onContextMenu: (_) {},
                                                    ),
                                                  ),
                                                ),
                                                onDragStarted: () {
                                                  _updateState(() {
                                                    _draggingPlaylistId =
                                                        playlist.id;
                                                    _playlistDragAccepted =
                                                        false;
                                                    final playlistIds =
                                                        customPlaylistIds;
                                                    _dragStartPlaylistIds =
                                                        playlistIds;
                                                    _previewPlaylistIds =
                                                        playlistIds;
                                                  });
                                                },
                                                onDraggableCanceled: (_, __) {
                                                  if (_playlistDragAccepted) {
                                                    return;
                                                  }
                                                  _commitPlaylistPreview();
                                                },
                                                onDragUpdate: (details) {
                                                  _previewPlaylistMoveToPoint(
                                                    customPlaylistIds,
                                                    details.globalPosition,
                                                  );
                                                },
                                                onDragEnd: (details) {
                                                  if (_playlistDragAccepted) {
                                                    return;
                                                  }
                                                  _previewPlaylistMoveToPoint(
                                                    customPlaylistIds,
                                                    details.offset,
                                                  );
                                                  _commitPlaylistPreview();
                                                },
                                                child: GridViewHolder(
                                                  playlist: playlist,
                                                  songs: playlistSongs,
                                                  subtitle: i18n.t(
                                                    'playlists.songCount',
                                                    {
                                                      'count':
                                                          playlist.songCount,
                                                    },
                                                  ),
                                                  playTooltip: i18n.t(
                                                    'context.play',
                                                  ),
                                                  dragTooltip: i18n.t(
                                                    'playlists.dragToSort',
                                                  ),
                                                  cardKey: const ValueKey(
                                                    'Playlists.PlaylistCard',
                                                  ),
                                                  artworkKey: const ValueKey(
                                                    'Playlists.ArtworkSurface',
                                                  ),
                                                  dragging: false,
                                                  sorting:
                                                      _draggingPlaylistId !=
                                                      null,
                                                  selected: false,
                                                  onOpen: () {
                                                    _persistLastPlaylist(
                                                      playlist.id,
                                                    );
                                                    context.go(
                                                      '/playlists/${playlist.id}',
                                                    );
                                                  },
                                                  onPlay: () {
                                                    if (playlist
                                                        .songIds
                                                        .isEmpty)
                                                      return;
                                                    unawaited(
                                                      recordRecentPlaylistPlayback(
                                                        ref,
                                                        playlist.id,
                                                      ),
                                                    );
                                                    _playTrack(
                                                      snapshot,
                                                      i18n,
                                                      playlist.songIds.first,
                                                      playlist.songIds,
                                                    );
                                                  },
                                                  onContextMenu: (position) {
                                                    return _showPlaylistMenu(
                                                      context,
                                                      i18n,
                                                      snapshot,
                                                      playlist,
                                                      position,
                                                    );
                                                  },
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
