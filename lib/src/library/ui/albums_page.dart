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
import '../../playback/media_control_provider.dart';
import '../../playback/media_control_track_factory.dart';
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
part 'albums_page_chrome.dart';
part 'albums_art_preview_dialog.dart';
part 'albums_colors.dart';

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
                  onToggleMultiSelect: _enterMultiSelect,
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
                    onToggleMultiSelect: _enterMultiSelect,
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
            final columns = ((constraints.maxWidth -
                        _albumQuickJumpWidth -
                        _albumGridShellGap +
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
                          onToggleMultiSelect: _enterMultiSelect,
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
                            const SizedBox(width: _albumGridShellGap),
                            Expanded(
                              child: Scrollbar(
                                controller: _albumGridScrollController,
                                thumbVisibility: true,
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

  void _submitSearch({bool closeAppBar = false}) {
    final query = _searchDraft.trim();
    _showProcessing();
    setState(() {
      _searchDraft = query;
      _searchQuery = _searchDraft;
      _searchFocused = false;
      if (closeAppBar) {
        _appBarSearchOpen = false;
      }
    });
    if (query.isNotEmpty) {
      unawaited(
        ref
            .read(libraryRepositoryProvider)
            .addRecentSearch(query, SearchHistoryType.albums)
            .then((_) {
              invalidateRecentSearchData(ref);
            }),
      );
    }
    _scrollAlbumsToTop();
  }

  void _selectSearchQuery(String query) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _searchDraft = query;
      _searchQuery = query;
      _searchFocused = false;
      _appBarSearchOpen = false;
    });
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .addRecentSearch(query, SearchHistoryType.albums)
          .then((_) {
            invalidateRecentSearchData(ref);
          }),
    );
    _scrollAlbumsToTop();
  }

  void _clearSearch() {
    setState(() {
      _searchDraft = '';
      _searchQuery = '';
    });
    if (widget.targetAlbumName != null) {
      context.go('/albums');
    }
    _scrollAlbumsToTop();
  }

  void _changeSearchFocus(bool focused) {
    setState(() {
      _searchFocused = focused;
    });
  }

  void _removeRecentSearch(int entryId) {
    unawaited(
      ref.read(libraryRepositoryProvider).removeRecentSearches([entryId]).then((
        _,
      ) {
        invalidateRecentSearchData(ref);
      }),
    );
  }

  void _clearRecentSearches() {
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final entryIds =
        latestSearchHistoryEntries(
          snapshot.recentSearches,
          SearchHistoryType.albums,
        ).map((entry) => entry.id).toList();
    unawaited(
      ref.read(libraryRepositoryProvider).removeRecentSearches(entryIds).then((
        _,
      ) {
        invalidateRecentSearchData(ref);
      }),
    );
  }

  void _changeAlbumSort(AlbumSortCriterion criterion) {
    _showProcessing();
    setState(() {
      if (criterion == AlbumSortCriterion.reverse) {
        _reverseDisplayOrder = !_reverseDisplayOrder;
      } else {
        _reverseDisplayOrder = false;
        _sortCriterion = criterion;
      }
    });
    if (criterion != AlbumSortCriterion.reverse) {
      ref.read(libraryRepositoryProvider).updateAlbumsSort(criterion);
    }
    _scrollAlbumsToTop();
  }

  void _enterMultiSelect() {
    setState(() {
      _selection.enterMultiSelect();
    });
  }

  void _toggleAlbumSelection(String albumName) {
    setState(() {
      _selection.toggle(albumName);
    });
  }

  void _hideSelectionAfterOperation(
    bool hideMultiSelectCommandBarAfterOperation,
  ) {
    setState(() {
      _selection.hideAfterOperation(hideMultiSelectCommandBarAfterOperation);
    });
  }

  void _openAlbum(String albumName) {
    setState(() {
      _searchDraft = albumName;
      _searchQuery = albumName;
      _selection.clearSelection();
    });
    context.go('/albums?album=${Uri.encodeQueryComponent(albumName)}');
    _scrollAlbumsToTop();
  }

  Future<void> _showAlbumContextMenu(
    Offset position,
    AlbumView album,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) async {
    final i18n = context.smPlayerI18n;
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final preferenceLevel = await ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('album', album.name);
    if (!mounted) {
      return;
    }
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: album.songIds,
      playlists: playlists,
      includeNowPlaying: shouldShowNowPlayingAddToTarget(
        songIds: album.songIds,
        nowPlayingSongIds: snapshot.nowPlaying.songIds,
        isNowPlayingContext: false,
      ),
      includeFavorites: album.songs.any((song) => !song.favorite),
      onAddToNowPlaying: () {
        _addSongsToNowPlayingWithUndo(album.songIds);
      },
      onToggleFavorite:
          album.songs.any((song) => !song.favorite)
              ? () {
                _setSongsFavoriteWithUndo(
                  album.songs
                      .where((song) => !song.favorite)
                      .map((song) => song.id)
                      .toList(),
                  true,
                );
              }
              : null,
      onCreatePlaylist: () async {
        await createPlaylistWithSongs(
          context: context,
          ref: ref,
          i18n: i18n,
          playlists: snapshot.playlists,
          defaultName: getNextPlaylistName(album.name, snapshot.playlists),
          songIds: album.songIds,
        );
      },
      onAddToPlaylist: (playlistId) {
        _addSongsToPlaylistWithUndo(playlistId, album.songIds);
      },
    );
    showMenuFlyout(
      context,
      position: position,
      items: [
        MenuFlyoutItem(
          key: 'shuffle',
          text: i18n.t('nowPlaying.randomPlay'),
          useShuffleIcon: true,
          onPressed: () async {
            await ref
                .read(libraryRepositoryProvider)
                .recordAlbumPlayed(album.name);
            await _playSongIds(album.songIds, shuffle: true);
          },
        ),
        if (addToItem != null) addToItem,
        MenuFlyoutItem(
          key: 'select',
          text: i18n.t('context.select'),
          icon: FluentIcons.multiselect_ltr_20_regular,
          onPressed: () {
            setState(() {
              _selection.enterMultiSelect();
              _selection.selectSingle(album.name);
            });
          },
        ),
        _buildAlbumPreferenceMenuItem(i18n, album, preferenceLevel),
        MenuFlyoutItem(
          key: 'see-album-art',
          text: i18n.t('context.seeAlbumArt'),
          icon: FluentIcons.image_20_regular,
          onPressed: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              setState(() {
                _albumArtPreview = album;
              });
            });
          },
        ),
      ],
    );
  }

  MenuFlyoutItem _buildAlbumPreferenceMenuItem(
    SmPlayerI18n i18n,
    AlbumView album,
    String? preferenceLevel,
  ) {
    return buildPreferenceMenuFlyoutItem(
      i18n: i18n,
      key: 'preference',
      preferenceLevel: preferenceLevel,
      onUndoPreference:
          preferenceLevel == null
              ? null
              : () {
                ref
                    .read(libraryRepositoryProvider)
                    .removePreferenceItem('album', album.name);
              },
      onSetPreference: (level) {
        ref
            .read(libraryRepositoryProvider)
            .addPreferenceItem('album', album.name, album.name, level);
      },
    );
  }

  void _showAlbumAddToMenu(
    Offset position,
    AlbumView album,
    List<MultiSelectCommandBarPlaylist> playlists,
    LibraryContentData snapshot,
    SmPlayerI18n i18n,
  ) {
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: album.songIds,
      playlists: playlists,
      includeNowPlaying: shouldShowNowPlayingAddToTarget(
        songIds: album.songIds,
        nowPlayingSongIds: snapshot.nowPlaying.songIds,
        isNowPlayingContext: false,
      ),
      includeFavorites: album.songs.any((song) => !song.favorite),
      onAddToNowPlaying: () {
        _addSongsToNowPlayingWithUndo(album.songIds);
      },
      onToggleFavorite:
          album.songs.any((song) => !song.favorite)
              ? () {
                _setSongsFavoriteWithUndo(
                  album.songs
                      .where((song) => !song.favorite)
                      .map((song) => song.id)
                      .toList(),
                  true,
                );
              }
              : null,
      onCreatePlaylist: () {
        createPlaylistWithSongs(
          context: context,
          ref: ref,
          i18n: i18n,
          playlists: snapshot.playlists,
          defaultName: getNextPlaylistName(album.name, snapshot.playlists),
          songIds: album.songIds,
        );
      },
      onAddToPlaylist: (playlistId) {
        _addSongsToPlaylistWithUndo(playlistId, album.songIds);
      },
    );
    if (addToItem == null) {
      return;
    }

    showMenuFlyout(context, position: position, items: addToItem.submenu);
  }

  Future<void> _playSongIds(List<int> songIds, {bool shuffle = false}) async {
    if (songIds.isEmpty) {
      return;
    }

    final queueSongIds = songIds.toList();
    if (shuffle) {
      queueSongIds.shuffle(Random());
    }
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final firstSong = songsById[queueSongIds.first]!;
    final i18n = context.smPlayerI18n;
    ref.read(nowPlayingQueueOverrideProvider.notifier).state = queueSongIds;
    await ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          mediaControlTrackForSong(firstSong, i18n),
          durationSeconds: firstSong.duration.toDouble(),
          queueIndex: 0,
        );
  }

  Future<void> _addSongsToNowPlayingWithUndo(List<int> songIds) async {
    if (songIds.isEmpty) {
      return;
    }

    final snapshot = ref.read(libraryContentDataProvider).value!;
    final currentSongIds =
        ref.read(nowPlayingQueueOverrideProvider) ??
        snapshot.nowPlaying.songIds;
    final insertedIndex = currentSongIds.length;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final i18n = context.smPlayerI18n;
    final queueAfterAdd = [...currentSongIds, ...songIds];
    ref.read(nowPlayingQueueOverrideProvider.notifier).state = queueAfterAdd;
    await ref.read(libraryRepositoryProvider).replaceNowPlaying(queueAfterAdd);
    _showUndoNotification(
      songIds.length == 1
          ? i18n.t('notification.songAddedTo', {
            'title': songsById[songIds.first]!.title,
            'target': i18n.t('common.nowPlaying'),
          })
          : i18n.t('notification.songsAddedTo', {
            'count': songIds.length,
            'target': i18n.t('common.nowPlaying'),
          }),
      () async {
        final currentSongIds =
            ref.read(nowPlayingQueueOverrideProvider) ?? queueAfterAdd;
        final restoredSongIds =
            currentSongIds.toList()..removeRange(
              insertedIndex,
              min(insertedIndex + songIds.length, currentSongIds.length),
            );
        await ref
            .read(libraryRepositoryProvider)
            .replaceNowPlaying(restoredSongIds);
        ref.read(nowPlayingQueueOverrideProvider.notifier).state =
            restoredSongIds;
      },
    );
  }

  Future<void> _addSongsToPlaylistWithUndo(
    int playlistId,
    List<int> songIds,
  ) async {
    if (songIds.isEmpty) {
      return;
    }

    final snapshot = ref.read(libraryContentDataProvider).value!;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final targetPlaylist = snapshot.playlists.firstWhere(
      (playlist) => playlist.id == playlistId,
    );
    final i18n = context.smPlayerI18n;
    await ref
        .read(libraryRepositoryProvider)
        .addSongsToPlaylist(playlistId, songIds);
    _showUndoNotification(
      songIds.length == 1
          ? i18n.t('notification.songAddedTo', {
            'title': songsById[songIds.first]!.title,
            'target': targetPlaylist.name,
          })
          : i18n.t('notification.songsAddedTo', {
            'count': songIds.length,
            'target': targetPlaylist.name,
          }),
      () async {
        await ref
            .read(libraryRepositoryProvider)
            .removeSongsFromPlaylist(playlistId, songIds);
      },
    );
  }

  Future<void> _setSongsFavoriteWithUndo(
    List<int> songIds,
    bool favorite,
  ) async {
    if (songIds.isEmpty) {
      return;
    }

    final snapshot = ref.read(libraryContentDataProvider).value!;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final i18n = context.smPlayerI18n;
    await setSongsFavorite(ref, songIds, favorite);
    _showUndoNotification(
      songIds.length == 1
          ? i18n.t('notification.songAddedTo', {
            'title': songsById[songIds.first]!.title,
            'target': i18n.t('common.myFavorites'),
          })
          : i18n.t('notification.songsAddedTo', {
            'count': songIds.length,
            'target': i18n.t('common.myFavorites'),
          }),
      () async {
        await setSongsFavorite(ref, songIds, !favorite);
      },
    );
  }

  void _showUndoNotification(String message, FutureOr<void> Function() onUndo) {
    showUndoableNotification(
      context: context,
      i18n: context.smPlayerI18n,
      message: message,
      onUndo: onUndo,
    );
  }

  void _jumpToAlbumKey(
    Map<String, int> albumQuickJumpMap,
    String key,
    int columns,
    double albumRowHeight,
  ) {
    final targetIndex = albumQuickJumpMap[key];
    if (targetIndex == null) {
      return;
    }
    final targetRow = targetIndex ~/ columns;

    setState(() {
      _albumQuickJumpTargetKey = key;
      _albumQuickJumpJumping = true;
    });
    _albumGridScrollController.jumpTo(targetRow * albumRowHeight);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _albumQuickJumpJumping = false;
        });
      }
    });
  }

  void _scrollAlbumsToTop() {
    if (!_albumGridScrollController.hasClients) {
      return;
    }

    setState(() {
      _albumScrollTop = 0;
      _albumQuickJumpTargetKey = null;
      _albumQuickJumpJumping = false;
    });
    _albumGridScrollController.jumpTo(0);
  }

  void _handleAlbumGridScroll() {
    final nextScrollTop = _albumGridScrollController.offset;
    if (nextScrollTop == _albumScrollTop) {
      return;
    }

    setState(() {
      _albumScrollTop = nextScrollTop;
      if (!_albumQuickJumpJumping) {
        _albumQuickJumpTargetKey = null;
      }
    });
  }

  String _getActiveAlbumQuickJumpKey(
    List<AlbumView> visibleAlbums,
    int columns,
    double albumRowHeight,
  ) {
    if (visibleAlbums.isEmpty) {
      return '';
    }

    final topRow = max(0, (_albumScrollTop / albumRowHeight).floor());
    if (_albumQuickJumpTargetKey != null) {
      return _albumQuickJumpTargetKey!;
    }

    final activeIndex = min(visibleAlbums.length - 1, topRow * columns);
    return getArtistQuickJumpBucket(visibleAlbums[activeIndex].name);
  }

  void _showProcessing() {
    _processingTimer?.cancel();
    setState(() {
      _processing = true;
    });
    _processingTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _processing = false;
      });
    });
  }

  String _allAlbumsTitle(
    LibraryContentData snapshot,
    List<AlbumView> albums,
    SmPlayerI18n i18n,
  ) {
    return snapshot.showCount
        ? i18n.t('library.allAlbumsWithCount', {'count': albums.length})
        : i18n.t('library.allAlbums');
  }
}
