import 'dart:async';
import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show
        ScrollCacheExtent,
        SliverConstraints,
        SliverGridDelegate,
        SliverGridLayout,
        SliverGridRegularTileLayout,
        axisDirectionIsReversed;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/loading_state.dart';
import '../../app/undoable_notification.dart';
import '../../app/workspace_app_bar_portal.dart';
import '../../i18n/app_i18n.dart';
import '../../playback/playback_queue_actions.dart';
import '../data/library_models.dart';
import '../data/library_providers.dart';
import 'album_tile.dart';
import 'artists_page_model.dart';
import 'command_bar.dart';
import 'menu_flyout.dart';
import 'menu_flyout_helpers.dart';
import 'multi_select_command_bar.dart';
import 'headered_playlist_model.dart' show getNextPlaylistName;
import 'library_page_actions.dart';
import 'page_search_history_panel.dart';
import 'page_selection_store.dart';
import 'quick_jump_tooltip.dart';

part 'albums_page_model.dart';
part 'albums_grid_delegate.dart';
part 'albums_toolbar.dart';
part 'albums_app_bar_actions.dart';
part 'albums_quick_jump.dart';
part 'albums_progress.dart';
part 'albums_page_panel.dart';
part 'albums_empty_state.dart';
part 'albums_art_preview_dialog.dart';
part 'albums_colors.dart';
part 'albums_page_search_actions.dart';
part 'albums_page_selection_actions.dart';
part 'albums_page_menu_actions.dart';
part 'albums_page_playback_actions.dart';
part 'albums_page_quick_jump_actions.dart';

class AlbumsPage extends ConsumerStatefulWidget {
  const AlbumsPage({super.key, this.targetAlbumName});

  final String? targetAlbumName;

  @override
  ConsumerState<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends ConsumerState<AlbumsPage> {
  var _searchDraft = '';
  var _searchQuery = '';
  var _searchFocused = false;
  var _appBarSearchOpen = false;
  var _sortCriterion = AlbumSortCriterion.defaultSort;
  AlbumSortCriterion? _syncedAlbumsSort;
  var _reverseDisplayOrder = false;
  var _processing = false;
  var _targetApplied = false;
  var _albumScrollTop = 0.0;
  String? _albumQuickJumpTargetKey;
  var _albumQuickJumpJumping = false;
  AlbumView? _albumArtPreview;
  Timer? _processingTimer;
  final _selection = PageSelectionController<String>.stored('albums');
  final _albumGridScrollController = ScrollController();
  final _appBarPortalOwner = Object();
  String? _appBarPortalSignature;
  late final StateController<WorkspaceAppBarPortalEntry?> _appBarPortalNotifier;

  @override
  void initState() {
    super.initState();
    _appBarPortalNotifier = ref.read(workspaceAppBarPortalProvider.notifier);
    _albumGridScrollController.addListener(_handleAlbumGridScroll);
  }

  @override
  void didUpdateWidget(AlbumsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetAlbumName != widget.targetAlbumName) {
      _targetApplied = false;
    }
  }

  @override
  void dispose() {
    _clearAppBarPortalOwner();
    _processingTimer?.cancel();
    _albumGridScrollController.removeListener(_handleAlbumGridScroll);
    _albumGridScrollController.dispose();
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
  }) {
    final signature =
        '$showPortal:$routePath:$title:$_appBarSearchOpen:$_searchDraft:$_searchQuery:$_sortCriterion:$_searchFocused:${searchSuggestions.length}:${searchHistoryEntries.length}';
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
        content: _buildAlbumsAppBarActions(
          i18n,
          searchSuggestions: searchSuggestions,
          searchHistoryEntries: searchHistoryEntries,
        ),
        replacesTitle: _appBarSearchOpen,
      );
    });
  }

  Widget _buildAlbumsAppBarActions(
    SmPlayerI18n i18n, {
    required List<String> searchSuggestions,
    required List<SearchHistoryEntry> searchHistoryEntries,
  }) {
    return _AlbumsAppBarActions(
      searchOpen: _appBarSearchOpen,
      searchDraft: _searchDraft,
      searchHasText: _searchDraft.isNotEmpty || _searchQuery.isNotEmpty,
      sortCriterion: _sortCriterion,
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
      onChangeAlbumSort: _changeAlbumSort,
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(libraryContentDataProvider);
    final songOverrides = ref.watch(librarySongOverridesProvider);

    if (i18nValue.isLoading) {
      return const _AlbumsPagePanel(child: SmPlayerLoadingState());
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const _AlbumsPagePanel(child: SmPlayerLoadingState());
    }

    return snapshotValue.when(
      loading: () {
        final useWorkspaceAppBar = WorkspaceNavigationAppBarScope.of(context);
        _syncAppBarPortal(
          showPortal: useWorkspaceAppBar,
          routePath: '/albums',
          title: i18n.t('library.allAlbums'),
          i18n: i18n,
          searchSuggestions: const [],
          searchHistoryEntries: const [],
        );
        return _AlbumsPagePanel(
          child: Column(
            children: [
              if (!useWorkspaceAppBar)
                _AlbumsToolbar(
                  searchDraft: _searchDraft,
                  searchHasText:
                      _searchDraft.isNotEmpty || _searchQuery.isNotEmpty,
                  sortCriterion: _sortCriterion,
                  multiSelect: _selection.multiSelect,
                  i18n: i18n,
                  searchFocused: _searchFocused,
                  searchSuggestions: const [],
                  searchHistoryEntries: const [],
                  onSearchChanged: (value) {
                    setState(() {
                      _searchDraft = value;
                    });
                  },
                  onSearchFocusChanged: _changeSearchFocus,
                  onSearchSubmitted: () {
                    _submitSearch();
                  },
                  onClearSearch: _clearSearch,
                  onSelectSearchSuggestion: _selectSearchQuery,
                  onRemoveRecentSearch: _removeRecentSearch,
                  onClearRecentSearches: _clearRecentSearches,
                  onChangeAlbumSort: _changeAlbumSort,
                  onToggleMultiSelect: _toggleMultiSelect,
                ),
              const _AlbumsProgress(key: ValueKey('Albums.Progress')),
              const Expanded(child: SmPlayerLoadingState(compact: true)),
            ],
          ),
        );
      },
      error:
          (_, _) => _AlbumsPagePanel(
            child: _AlbumsEmptyState(
              title: i18n.t('collection.albumNotFound'),
              message: i18n.t('library.scanHelp'),
            ),
          ),
      data: (rawSnapshot) {
        final snapshot = applyLibraryFavoriteOverrides(
          rawSnapshot,
          const {},
          songOverrides,
        );
        if (_syncedAlbumsSort != snapshot.albumsSort) {
          _sortCriterion = snapshot.albumsSort;
          _syncedAlbumsSort = snapshot.albumsSort;
          _reverseDisplayOrder = false;
        }

        final albums = buildAlbumViews(snapshot.songs, i18n);
        if (!_targetApplied && widget.targetAlbumName != null) {
          _targetApplied = true;
          final target = Uri.decodeComponent(widget.targetAlbumName!);
          if (albums.any((album) => album.name == target)) {
            _searchDraft = target;
            _searchQuery = target;
          }
        }

        final baseVisibleAlbums =
            _searchQuery.trim().isEmpty
                ? sortAlbums(albums, _sortCriterion)
                : searchAlbums(albums, _searchQuery);
        final visibleAlbums =
            _reverseDisplayOrder
                ? baseVisibleAlbums.reversed.toList()
                : baseVisibleAlbums;
        final albumQuickJumpMap = buildAlbumQuickJumpMap(visibleAlbums);
        final selectedAlbums =
            visibleAlbums
                .where((album) => _selection.isSelected(album.name))
                .toList();
        final selectedSongIds =
            selectedAlbums.expand((album) => album.songIds).toList();
        final songsById = {for (final song in snapshot.songs) song.id: song};
        final albumSearchSuggestions =
            _searchDraft.trim().isEmpty
                ? const <String>[]
                : searchAlbums(
                  albums,
                  _searchDraft,
                ).take(8).map((album) => album.name).toList();
        final albumSearchHistoryEntries = latestSearchHistoryEntries(
          snapshot.recentSearches,
          SearchHistoryType.albums,
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
        final useWorkspaceAppBar = WorkspaceNavigationAppBarScope.of(context);
        _syncAppBarPortal(
          showPortal: widget.targetAlbumName == null,
          routePath: '/albums',
          title: _allAlbumsTitle(snapshot, albums, i18n),
          i18n: i18n,
          searchSuggestions: albumSearchSuggestions,
          searchHistoryEntries: albumSearchHistoryEntries,
        );

        if (visibleAlbums.isEmpty) {
          return _AlbumsPagePanel(
            child: Column(
              children: [
                if (!useWorkspaceAppBar)
                  _AlbumsToolbar(
                    searchDraft: _searchDraft,
                    searchHasText:
                        _searchDraft.isNotEmpty || _searchQuery.isNotEmpty,
                    sortCriterion: _sortCriterion,
                    multiSelect: _selection.multiSelect,
                    i18n: i18n,
                    searchFocused: _searchFocused,
                    searchSuggestions: albumSearchSuggestions,
                    searchHistoryEntries: albumSearchHistoryEntries,
                    onSearchChanged: (value) {
                      setState(() {
                        _searchDraft = value;
                      });
                    },
                    onSearchFocusChanged: _changeSearchFocus,
                    onSearchSubmitted: () {
                      _submitSearch();
                    },
                    onClearSearch: _clearSearch,
                    onSelectSearchSuggestion: _selectSearchQuery,
                    onRemoveRecentSearch: _removeRecentSearch,
                    onClearRecentSearches: _clearRecentSearches,
                    onChangeAlbumSort: _changeAlbumSort,
                    onToggleMultiSelect: _toggleMultiSelect,
                  ),
                if (_processing)
                  const _AlbumsProgress(key: ValueKey('Albums.Progress')),
                Expanded(
                  child:
                      _processing
                          ? const SmPlayerLoadingState(compact: true)
                          : LayoutBuilder(
                            builder: (context, constraints) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  child: _AlbumsEmptyState(
                                    title:
                                        _searchQuery.isEmpty
                                            ? i18n.t('collection.noAlbums')
                                            : i18n.t('albums.noMatch'),
                                    message:
                                        _searchQuery.isEmpty
                                            ? i18n.t('collection.scanFirst')
                                            : i18n.t('albums.noMatchCopy'),
                                  ),
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            if (compact && _selection.multiSelect) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(_selection.cancel);
                }
              });
            }
            final albumGridShellGap =
                compact ? _albumCompactGridShellGap : _albumGridShellGap;
            final columns = ((constraints.maxWidth -
                        _albumQuickJumpWidth -
                        albumGridShellGap +
                        _albumColumnGap) /
                    (_albumTileTrackWidth + _albumColumnGap))
                .floor()
                .clamp(1, 12);
            final albumRowHeight =
                compact ? _albumCompactRowHeight : _albumRowHeight;
            final activeAlbumQuickJumpKey = _getActiveAlbumQuickJumpKey(
              visibleAlbums,
              columns,
              albumRowHeight,
            );

            return _AlbumsPagePanel(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    children: [
                      if (!useWorkspaceAppBar)
                        _AlbumsToolbar(
                          searchDraft: _searchDraft,
                          searchHasText:
                              _searchDraft.isNotEmpty ||
                              _searchQuery.isNotEmpty,
                          sortCriterion: _sortCriterion,
                          multiSelect: _selection.multiSelect,
                          i18n: i18n,
                          searchFocused: _searchFocused,
                          searchSuggestions: albumSearchSuggestions,
                          searchHistoryEntries: albumSearchHistoryEntries,
                          onSearchChanged: (value) {
                            setState(() {
                              _searchDraft = value;
                            });
                          },
                          onSearchFocusChanged: _changeSearchFocus,
                          onSearchSubmitted: () {
                            _submitSearch();
                          },
                          onClearSearch: _clearSearch,
                          onSelectSearchSuggestion: _selectSearchQuery,
                          onRemoveRecentSearch: _removeRecentSearch,
                          onClearRecentSearches: _clearRecentSearches,
                          onChangeAlbumSort: _changeAlbumSort,
                          onToggleMultiSelect: _toggleMultiSelect,
                        ),
                      if (_processing)
                        const _AlbumsProgress(key: ValueKey('Albums.Progress')),
                      Expanded(
                        child: Row(
                          children: [
                            _AlbumsQuickJump(
                              activeKey: activeAlbumQuickJumpKey,
                              enabledKeys: albumQuickJumpMap.keys.toSet(),
                              i18n: i18n,
                              onJump: (key) {
                                _jumpToAlbumKey(
                                  albumQuickJumpMap,
                                  key,
                                  columns,
                                  albumRowHeight,
                                );
                              },
                            ),
                            SizedBox(width: albumGridShellGap),
                            Expanded(
                              child: Scrollbar(
                                controller: _albumGridScrollController,
                                child: ScrollConfiguration(
                                  behavior: ScrollConfiguration.of(
                                    context,
                                  ).copyWith(scrollbars: false),
                                  child: GridView.builder(
                                    controller: _albumGridScrollController,
                                    scrollCacheExtent: ScrollCacheExtent.pixels(
                                      albumRowHeight * _albumOverscanRows,
                                    ),
                                    padding: EdgeInsets.fromLTRB(
                                      14,
                                      8,
                                      8,
                                      _selection.multiSelect
                                          ? multiSelectCommandBarScrollSpacer
                                          : 28,
                                    ),
                                    gridDelegate: _AlbumGridDelegate(
                                      crossAxisCount: columns,
                                      crossAxisExtent: _albumTileTrackWidth,
                                      mainAxisExtent: albumRowHeight,
                                      crossAxisSpacing: _albumColumnGap,
                                    ),
                                    itemCount: visibleAlbums.length,
                                    itemBuilder: (context, index) {
                                      final album = visibleAlbums[index];
                                      return AlbumTile(
                                        album: album,
                                        multiSelect: _selection.multiSelect,
                                        selected: _selection.isSelected(
                                          album.name,
                                        ),
                                        onOpenAlbum: () {
                                          _openAlbum(album.name);
                                        },
                                        onPlayAlbum: () {
                                          ref
                                              .read(libraryRepositoryProvider)
                                              .recordAlbumPlayed(album.name);
                                          _playSongIds(album.songIds);
                                        },
                                        onAddAlbum: (position) {
                                          _showAlbumAddToMenu(
                                            position,
                                            album,
                                            customPlaylists,
                                            snapshot,
                                            i18n,
                                          );
                                        },
                                        onToggleSelection: () {
                                          _toggleAlbumSelection(album.name);
                                        },
                                        onOpenContextMenu: (position) {
                                          unawaited(
                                            _showAlbumContextMenu(
                                              position,
                                              album,
                                              customPlaylists,
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  MultiSelectCommandBar(
                    visible: _selection.multiSelect,
                    bottomInset: multiSelectCommandBarShellBottomInset,
                    horizontalBleed: 24,
                    selectedCount: selectedAlbums.length,
                    playlists: customPlaylists,
                    addToSongIds: selectedSongIds,
                    nowPlayingSongIds: snapshot.nowPlaying.songIds,
                    includeNowPlayingInAddTo: true,
                    includeFavoritesInAddTo: hasNotFavoriteSongs(
                      selectedSongIds,
                      songsById,
                    ),
                    onAddToNowPlaying:
                        selectedSongIds.isEmpty
                            ? null
                            : () {
                              _addSongsToNowPlayingWithUndo(selectedSongIds);
                              _hideSelectionAfterOperation(
                                snapshot
                                    .hideMultiSelectCommandBarAfterOperation,
                              );
                            },
                    onToggleFavorite:
                        selectedSongIds.isEmpty
                            ? null
                            : () {
                              _setSongsFavoriteWithUndo(
                                notFavoriteSongIds(selectedSongIds, songsById),
                                true,
                              );
                              _hideSelectionAfterOperation(
                                snapshot
                                    .hideMultiSelectCommandBarAfterOperation,
                              );
                            },
                    onCreatePlaylist:
                        selectedSongIds.isEmpty
                            ? null
                            : () async {
                              await createPlaylistWithSongs(
                                context: context,
                                ref: ref,
                                i18n: i18n,
                                playlists: snapshot.playlists,
                                defaultName: getNextPlaylistName(
                                  i18n.t('common.albums'),
                                  snapshot.playlists,
                                ),
                                songIds: selectedSongIds,
                              );
                              if (mounted) {
                                _hideSelectionAfterOperation(
                                  snapshot
                                      .hideMultiSelectCommandBarAfterOperation,
                                );
                              }
                            },
                    onPlay:
                        selectedSongIds.isEmpty
                            ? null
                            : () {
                              _playSongIds(selectedSongIds);
                              _hideSelectionAfterOperation(
                                snapshot
                                    .hideMultiSelectCommandBarAfterOperation,
                              );
                            },
                    onAddToPlaylist: (playlistId) {
                      _addSongsToPlaylistWithUndo(playlistId, selectedSongIds);
                      _hideSelectionAfterOperation(
                        snapshot.hideMultiSelectCommandBarAfterOperation,
                      );
                    },
                    onSelectAll: () {
                      setState(() {
                        _selection.selectAll(
                          visibleAlbums.map((album) => album.name),
                        );
                      });
                    },
                    onReverseSelection: () {
                      setState(() {
                        _selection.reverseSelection(
                          visibleAlbums.map((album) => album.name),
                        );
                      });
                    },
                    onClearSelection: () {
                      setState(_selection.clearSelection);
                    },
                    onCancel: () {
                      setState(_selection.cancel);
                    },
                  ),
                  if (_albumArtPreview != null)
                    _AlbumArtPreviewDialog(
                      album: _albumArtPreview!,
                      i18n: i18n,
                      onClose: () {
                        setState(() {
                          _albumArtPreview = null;
                        });
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
