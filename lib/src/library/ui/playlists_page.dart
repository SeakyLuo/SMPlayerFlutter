import 'dart:async';
import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/edge_auto_hide_scrollbar.dart';
import 'package:smplayer_flutter/src/app/input_dialog.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/grid_view_holder.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_control.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_model.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/page_search_history_panel.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart'
    as song_display;
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/playback_queue_actions.dart';

part 'playlists_page_crud_actions.dart';
part 'playlists_page_drag_actions.dart';
part 'playlists_page_local_overrides.dart';
part 'playlists_page_playback_actions.dart';
part 'playlists_page_search_actions.dart';
part 'playlists_page_toolbar.dart';
part 'playlists_app_bar_actions.dart';
part 'playlists_empty_state.dart';
part 'playlists_page_helpers.dart';
part 'playlist_drop_placeholder.dart';
part 'playlists_colors.dart';

const _playlistCardWidth = gridViewHolderWidth;
const _playlistCardHeight = gridViewHolderHeight;
const _playlistGridCrossAxisSpacing = 30.0;
const _playlistDragOverlapThreshold = 0.2;

class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({
    super.key,
    this.selectedPlaylistId,
    this.searchQuery = '',
  });

  final int? selectedPlaylistId;
  final String searchQuery;

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  late var _searchDraft = widget.searchQuery.trim();
  late var _searchQuery = widget.searchQuery.trim();
  var _searchFocused = false;
  var _appBarSearchOpen = false;
  List<int>? _previewPlaylistIds;
  List<int>? _committedPlaylistIds;
  List<int>? _dragStartPlaylistIds;
  int? _draggingPlaylistId;
  var _playlistDragAccepted = false;
  Offset? _playlistDragAnchorOffset;
  final _playlistCardContexts = <int, BuildContext>{};
  int? _lastPersistedPlaylistId;
  int? _recordedBrowsePlaylistId;
  final _appBarPortalOwner = Object();
  String? _appBarPortalSignature;
  late final StateController<WorkspaceAppBarPortalEntry?> _appBarPortalNotifier;

  void _updateState(VoidCallback callback) {
    setState(callback);
  }

  @override
  void initState() {
    super.initState();
    _appBarPortalNotifier = ref.read(workspaceAppBarPortalProvider.notifier);
  }

  void _recordBrowseAfterFrame(int playlistId) {
    if (_recordedBrowsePlaylistId == playlistId) {
      return;
    }
    _recordedBrowsePlaylistId = playlistId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _recordedBrowsePlaylistId != playlistId) {
        return;
      }
      unawaited(_recordBrowse(playlistId));
    });
  }

  Future<void> _recordBrowse(int playlistId) async {
    final recentBrowses = ref.read(recentBrowsesProvider.notifier);
    final entry = await ref
        .read(libraryRepositoryProvider)
        .recordRecentBrowse(RecentBrowseType.playlist, '$playlistId');
    await recentBrowses.record(entry);
  }

  @override
  void didUpdateWidget(covariant PlaylistsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      final query = widget.searchQuery.trim();
      _searchDraft = query;
      _searchQuery = query;
    }
  }

  @override
  void dispose() {
    _clearAppBarPortalOwner();
    super.dispose();
  }

  void _clearAppBarPortalOwner() {
    clearWorkspaceAppBarPortalOwnerAfterDispose(
      _appBarPortalNotifier,
      _appBarPortalOwner,
    );
  }

  void _syncAppBarPortal({
    required bool showPortal,
    required String routePath,
    required String title,
    required SmPlayerI18n i18n,
    required List<String> searchSuggestions,
    required List<SearchHistoryEntry> searchHistoryEntries,
    required VoidCallback onCreatePlaylist,
  }) {
    final signature =
        '$showPortal:$routePath:$title:$_appBarSearchOpen:$_searchDraft:$_searchQuery:$_searchFocused:${searchSuggestions.length}:${searchHistoryEntries.length}';
    if (_appBarPortalSignature == signature) {
      return;
    }
    _appBarPortalSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final notifier = ref.read(workspaceAppBarPortalProvider.notifier);
      if (!showPortal) {
        if (notifier.state?.owner == _appBarPortalOwner) {
          notifier.state = null;
        }
        return;
      }
      notifier.state = WorkspaceAppBarPortalEntry(
        owner: _appBarPortalOwner,
        routePath: routePath,
        routeLocation: routePath,
        title: title,
        content: _PlaylistsAppBarActions(
          searchOpen: _appBarSearchOpen,
          searchDraft: _searchDraft,
          searchHasText: _searchDraft.isNotEmpty || _searchQuery.isNotEmpty,
          i18n: i18n,
          searchFocused: _searchFocused,
          searchSuggestions: searchSuggestions,
          searchHistoryEntries: searchHistoryEntries,
          onOpenSearch: () {
            setState(() {
              _appBarSearchOpen = true;
              _searchFocused = true;
            });
          },
          onCloseSearch: () {
            setState(() {
              _appBarSearchOpen = false;
              _searchFocused = false;
            });
          },
          onSearchChanged: (value) {
            setState(() {
              _searchDraft = value;
            });
          },
          onSearchFocusChanged: _changeSearchFocus,
          onSearchSubmitted: () {
            _submitSearch(closeAppBar: true);
          },
          onClearSearch: _clearSearch,
          onSelectSearchSuggestion: _selectSearchQuery,
          onRemoveRecentSearch: _removeRecentSearch,
          onClearRecentSearches: _clearRecentSearches,
          onCreatePlaylist: onCreatePlaylist,
        ),
        replacesTitle: _appBarSearchOpen,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(libraryContentDataProvider);
    final favoriteOverrides = ref.watch(libraryFavoriteOverridesProvider);
    final songOverrides = ref.watch(librarySongOverridesProvider);
    final playlistOverrides = ref.watch(libraryPlaylistOverridesProvider);
    final deletedPlaylistIds = ref.watch(libraryDeletedPlaylistIdsProvider);
    final nowPlayingSongIdsOverride = ref.watch(
      nowPlayingQueueOverrideProvider,
    );

    if (i18nValue.isLoading || snapshotValue.isLoading) {
      return const SmPlayerLoadingState();
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const SizedBox.shrink();
    }

    return snapshotValue.when(
      loading: () => const SmPlayerLoadingState(),
      error:
          (_, _) => Center(
            child: Text(
              i18n.t('playlists.none'),
              style: const TextStyle(color: _PlaylistsColors.textMuted),
            ),
          ),
      data: (rawSnapshot) {
        final snapshot = _applyLocalSnapshotOverrides(
          applyLibraryFavoriteOverrides(
            rawSnapshot,
            favoriteOverrides,
            songOverrides,
            playlistOverrides,
            deletedPlaylistIds,
          ),
          nowPlayingSongIdsOverride,
        );
        final selectedPlaylist =
            snapshot.playlists
                .where((playlist) => playlist.id == widget.selectedPlaylistId)
                .firstOrNull;
        if (widget.selectedPlaylistId != null && selectedPlaylist != null) {
          _persistLastPlaylist(selectedPlaylist.id);
          _recordBrowseAfterFrame(selectedPlaylist.id);
          return _buildDetail(context, ref, i18n, snapshot, selectedPlaylist);
        }

        return _buildGrid(context, i18n, snapshot);
      },
    );
  }

  Widget _buildDetail(
    BuildContext context,
    WidgetRef ref,
    SmPlayerI18n i18n,
    LibraryContentData snapshot,
    LibraryPlaylist selectedPlaylist,
  ) {
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final songs =
        selectedPlaylist.songIds
            .map((songId) => songsById[songId])
            .whereType<LibrarySong>()
            .toList();
    final mediaControl = ref.watch(
      mediaControlControllerProvider.select(
        (controller) => (
          trackId: controller.state.track.id,
          isPlaying: controller.state.isPlaying,
        ),
      ),
    );
    final artworkUrl =
        songs
            .where((song) => song.thumbnailPath.isNotEmpty)
            .map((song) => song.thumbnailPath)
            .firstOrNull ??
        '';

    return SmPlayerI18nScope(
      i18n: i18n,
      child: HeaderedPlaylistControl(
        key: ValueKey('HeaderedPlaylist.Playlist.${selectedPlaylist.id}'),
        routeLocation: GoRouterState.of(context).uri.toString(),
        type:
            selectedPlaylist.isBuiltIn
                ? HeaderedPlaylistType.favorites
                : HeaderedPlaylistType.playlist,
        title: selectedPlaylist.name,
        headerSongs: songs,
        songs: songs,
        selectedTrackId: mediaControl.trackId,
        isPlaying: mediaControl.isPlaying,
        playlists: snapshot.playlists,
        favoritePlaylistId: snapshot.favoritePlaylistId,
        artworkUrl: artworkUrl,
        removable: true,
        showAlbum: true,
        canRename: !selectedPlaylist.isBuiltIn,
        canDelete: !selectedPlaylist.isBuiltIn,
        canClear: songs.isNotEmpty,
        canSetPreferred: true,
        sortCriterion: selectedPlaylist.sortCriterion,
        preferenceType:
            selectedPlaylist.isBuiltIn ? 'my-favorites' : 'playlist',
        preferenceItemId:
            selectedPlaylist.isBuiltIn ? '6' : selectedPlaylist.id.toString(),
        onPlayTrack: (trackId, queueSongIds) {
          _playTrack(snapshot, i18n, trackId, queueSongIds);
        },
        onMoveToMusicOrPlay: (songId) {
          insertOrPlayNowPlayingSong(
            ref: ref,
            snapshot: snapshot,
            i18n: i18n,
            songId: songId,
          );
        },
        onPlayNext: (songId) {
          _playNext(snapshot, songId);
        },
        onTogglePlayPause:
            ref.read(mediaControlControllerProvider).onTogglePlayPause,
        onAddSongToPlaylist: (playlistId, songId) {
          unawaited(
            _addSongsToPlaylistWithoutReload(snapshot, playlistId, [songId]),
          );
        },
        onAddSongsToPlaylist: (playlistId, songIds) {
          unawaited(
            _addSongsToPlaylistWithoutReload(snapshot, playlistId, songIds),
          );
        },
        onToggleFavorite: (songId, favorite) {
          if (favorite) {
            unawaited(
              setSongsFavoriteWithUndo(
                context: context,
                ref: ref,
                i18n: i18n,
                songIds: [songId],
                favorite: true,
              ),
            );
            return;
          }
          unawaited(setSongsFavorite(ref, [songId], false));
        },
        onRemoveSongs: (songIds) async {
          await ref
              .read(libraryRepositoryProvider)
              .removeSongsFromPlaylist(selectedPlaylist.id, songIds);
          _patchLocalPlaylist(
            _copyPlaylistWithSongIds(
              selectedPlaylist,
              selectedPlaylist.songIds
                  .where((songId) => !songIds.contains(songId))
                  .toList(),
            ),
          );
        },
        onRename: (name) {
          _renamePlaylistWithoutReload(selectedPlaylist, name);
        },
        onDelete: () async {
          await ref
              .read(libraryRepositoryProvider)
              .deletePlaylist(selectedPlaylist.id);
          _removeLocalPlaylist(selectedPlaylist.id);
          if (context.mounted) {
            context.go('/playlists');
          }
        },
        onClear: () async {
          await ref
              .read(libraryRepositoryProvider)
              .removeSongsFromPlaylist(
                selectedPlaylist.id,
                songs.map((song) => song.id).toList(),
              );
          _patchLocalPlaylist(
            _copyPlaylistWithSongIds(selectedPlaylist, const []),
          );
        },
        onSetPreferred: (level) async {
          await ref
              .read(libraryRepositoryProvider)
              .addPreferenceItem(
                selectedPlaylist.isBuiltIn ? 'my-favorites' : 'playlist',
                selectedPlaylist.isBuiltIn
                    ? '6'
                    : selectedPlaylist.id.toString(),
                selectedPlaylist.isBuiltIn
                    ? i18n.t('common.myFavorites')
                    : selectedPlaylist.name,
                level,
              );
        },
        onRecordPlay: () {
          ref
              .read(libraryRepositoryProvider)
              .recordPlaylistPlayed(selectedPlaylist.id);
        },
        onSortSongs: (songIds, sortCriterion) {
          unawaited(
            ref
                .read(libraryRepositoryProvider)
                .reorderPlaylistSongs(
                  selectedPlaylist.id,
                  songIds,
                  sortCriterion,
                ),
          );
          _patchLocalPlaylist(
            _copyPlaylistWithSongIds(
              selectedPlaylist,
              songIds,
              sortCriterion: sortCriterion,
            ),
          );
        },
        onArtistClick: (artist) {
          context.go('/artists?artist=${Uri.encodeQueryComponent(artist)}');
        },
        onAlbumClick: (album) {
          context.go('/albums?album=${Uri.encodeQueryComponent(album)}');
        },
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    SmPlayerI18n i18n,
    LibraryContentData snapshot,
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
      onCreatePlaylist: () {
        unawaited(_createPlaylist(context, i18n, snapshot));
      },
    );

    return Column(
      children: [
        if (!useWorkspaceAppBar) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: _PlaylistsToolbar(
              searchDraft: _searchDraft,
              searchHasText: _searchDraft.isNotEmpty || _searchQuery.isNotEmpty,
              i18n: i18n,
              searchFocused: _searchFocused,
              searchSuggestions: searchSuggestions,
              searchHistoryEntries: searchHistoryEntries,
              onSearchChanged: (value) {
                setState(() {
                  _searchDraft = value;
                });
              },
              onSearchFocusChanged: _changeSearchFocus,
              onSearchSubmitted: _submitSearch,
              onClearSearch: _clearSearch,
              onSelectSearchSuggestion: _selectSearchQuery,
              onRemoveRecentSearch: _removeRecentSearch,
              onClearRecentSearches: _clearRecentSearches,
              onCreatePlaylist: () {
                unawaited(_createPlaylist(context, i18n, snapshot));
              },
            ),
          ),
          const SizedBox(height: 18),
        ],
        Expanded(
          child:
              visiblePlaylists.isEmpty
                  ? _PlaylistsEmptyState(
                    title:
                        _searchQuery.isEmpty
                            ? i18n.t('playlists.none')
                            : i18n.t('playlists.noMatch'),
                    message:
                        _searchQuery.isEmpty
                            ? i18n.t('collection.scanFirst')
                            : i18n.t('playlists.noMatchCopy'),
                  )
                  : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = ((constraints.maxWidth +
                                  _playlistGridCrossAxisSpacing) /
                              (_playlistCardWidth +
                                  _playlistGridCrossAxisSpacing))
                          .floor()
                          .clamp(1, 8);
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
                                  padding: EdgeInsets.fromLTRB(
                                    38,
                                    useWorkspaceAppBar ? 20 : 8,
                                    14,
                                    116,
                                  ),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        mainAxisExtent: 250,
                                        crossAxisSpacing:
                                            _playlistGridCrossAxisSpacing,
                                        mainAxisSpacing: 26,
                                      ),
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
                                                  setState(() {
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
                                                    if (playlistSongs
                                                        .isNotEmpty) {
                                                      ref
                                                          .read(
                                                            libraryRepositoryProvider,
                                                          )
                                                          .recordPlaylistPlayed(
                                                            playlist.id,
                                                          );
                                                      _playTrack(
                                                        snapshot,
                                                        i18n,
                                                        playlistSongs.first.id,
                                                        playlistSongs
                                                            .map(
                                                              (song) => song.id,
                                                            )
                                                            .toList(),
                                                      );
                                                    }
                                                  },
                                                  onContextMenu: (position) {
                                                    _showPlaylistMenu(
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
