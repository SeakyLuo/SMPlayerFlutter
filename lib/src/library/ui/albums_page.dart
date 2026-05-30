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

const _albumTileTrackWidth = 180.0;
const _albumColumnGap = 30.0;
const _albumQuickJumpWidth = 22.0;
const _albumGridShellGap = 4.0;
const _albumRowHeight = 250.0;
const _albumCompactRowHeight = 234.0;
const _albumOverscanRows = 2;

class AlbumView extends AlbumTileData {
  const AlbumView({
    required super.name,
    required super.artist,
    required super.songs,
    required super.duration,
    required super.artworkSong,
    required this.artists,
  });

  final List<String> artists;
}

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
    if (_appBarPortalNotifier.state?.owner == _appBarPortalOwner) {
      _appBarPortalNotifier.state = null;
    }
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
      data: (snapshot) {
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
                          : _AlbumsEmptyState(
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
                    selectedCount: selectedAlbums.length,
                    playlists: customPlaylists,
                    addToSongIds: selectedSongIds,
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
      includeNowPlaying: true,
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
        final snapshot = ref.read(libraryContentDataProvider).value!;
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
          icon: FluentIcons.arrow_shuffle_20_regular,
          onPressed: () {
            ref.read(libraryRepositoryProvider).recordAlbumPlayed(album.name);
            _playSongIds(album.songIds, shuffle: true);
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
                ref.invalidate(libraryContentDataProvider);
              },
      onSetPreference: (level) {
        ref
            .read(libraryRepositoryProvider)
            .addPreferenceItem('album', album.name, album.name, level);
        ref.invalidate(libraryContentDataProvider);
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
      includeNowPlaying: true,
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

  void _playSongIds(List<int> songIds, {bool shuffle = false}) {
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
    ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          mediaControlTrackForSong(firstSong, context.smPlayerI18n),
          durationSeconds: firstSong.duration.toDouble(),
          queueIndex: 0,
        );
    ref.invalidate(libraryContentDataProvider);
  }

  Future<void> _addSongsToNowPlayingWithUndo(List<int> songIds) async {
    if (songIds.isEmpty) {
      return;
    }

    final snapshot = ref.read(libraryContentDataProvider).value!;
    final insertedIndex = snapshot.nowPlaying.songIds.length;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final i18n = context.smPlayerI18n;
    await ref.read(libraryRepositoryProvider).replaceNowPlaying([
      ...snapshot.nowPlaying.songIds,
      ...songIds,
    ]);
    ref.invalidate(libraryContentDataProvider);
    _showUndoSnackBar(
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
            ref
                .read(libraryContentDataProvider)
                .valueOrNull
                ?.nowPlaying
                .songIds ??
            [...snapshot.nowPlaying.songIds, ...songIds];
        final nextSongIds =
            currentSongIds.toList()..removeRange(
              insertedIndex,
              min(insertedIndex + songIds.length, currentSongIds.length),
            );
        await ref
            .read(libraryRepositoryProvider)
            .replaceNowPlaying(nextSongIds);
        ref.invalidate(libraryContentDataProvider);
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
    ref.invalidate(libraryContentDataProvider);
    _showUndoSnackBar(
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
        ref.invalidate(libraryContentDataProvider);
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
    _showUndoSnackBar(
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

  void _showUndoSnackBar(String message, FutureOr<void> Function() onUndo) {
    showUndoableSnackBar(
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

class _AlbumGridDelegate extends SliverGridDelegate {
  const _AlbumGridDelegate({
    required this.crossAxisCount,
    required this.crossAxisExtent,
    required this.mainAxisExtent,
    required this.crossAxisSpacing,
  });

  final int crossAxisCount;
  final double crossAxisExtent;
  final double mainAxisExtent;
  final double crossAxisSpacing;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: mainAxisExtent,
      crossAxisStride: crossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: mainAxisExtent,
      childCrossAxisExtent: crossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(_AlbumGridDelegate oldDelegate) {
    return oldDelegate.crossAxisCount != crossAxisCount ||
        oldDelegate.crossAxisExtent != crossAxisExtent ||
        oldDelegate.mainAxisExtent != mainAxisExtent ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing;
  }
}

class _AlbumsToolbar extends StatefulWidget {
  const _AlbumsToolbar({
    required this.searchDraft,
    required this.searchHasText,
    required this.sortCriterion,
    required this.multiSelect,
    required this.i18n,
    required this.searchFocused,
    required this.searchSuggestions,
    required this.searchHistoryEntries,
    required this.onSearchChanged,
    required this.onSearchFocusChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onSelectSearchSuggestion,
    required this.onRemoveRecentSearch,
    required this.onClearRecentSearches,
    required this.onChangeAlbumSort,
    required this.onToggleMultiSelect,
  });

  final String searchDraft;
  final bool searchHasText;
  final AlbumSortCriterion sortCriterion;
  final bool multiSelect;
  final SmPlayerI18n i18n;
  final bool searchFocused;
  final List<String> searchSuggestions;
  final List<SearchHistoryEntry> searchHistoryEntries;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onSearchFocusChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSelectSearchSuggestion;
  final ValueChanged<int> onRemoveRecentSearch;
  final VoidCallback onClearRecentSearches;
  final ValueChanged<AlbumSortCriterion> onChangeAlbumSort;
  final VoidCallback onToggleMultiSelect;

  @override
  State<_AlbumsToolbar> createState() => _AlbumsToolbarState();
}

class _AlbumsToolbarState extends State<_AlbumsToolbar> {
  final _dropdownController = OverlayPortalController();

  bool get _showSuggestions =>
      widget.searchFocused && widget.searchSuggestions.isNotEmpty;

  bool get _showHistory =>
      widget.searchFocused &&
      widget.searchDraft.trim().isEmpty &&
      widget.searchHistoryEntries.isNotEmpty;

  bool get _showDropdown => _showSuggestions || _showHistory;

  @override
  void didUpdateWidget(covariant _AlbumsToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDropdown();
  }

  void _syncDropdown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_showDropdown) {
        _dropdownController.show();
      } else {
        _dropdownController.hide();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncDropdown();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
      child: CommandBar(
        overflowLabel: widget.i18n.t('player.more'),
        content: OverlayPortal.overlayChildLayoutBuilder(
          controller: _dropdownController,
          overlayChildBuilder: (context, info) {
            final origin = MatrixUtils.transformPoint(
              info.childPaintTransform,
              Offset.zero,
            );
            return Positioned(
              left: origin.dx,
              top: origin.dy + info.childSize.height + 8,
              width: info.childSize.width,
              child:
                  _showSuggestions
                      ? PageSearchSuggestionPanel(
                        labels: widget.searchSuggestions,
                        onSelect: widget.onSelectSearchSuggestion,
                      )
                      : PageSearchHistoryPanel(
                        entries: widget.searchHistoryEntries,
                        i18n: widget.i18n,
                        onSelect: widget.onSelectSearchSuggestion,
                        onRemove: widget.onRemoveRecentSearch,
                        onClear: widget.onClearRecentSearches,
                      ),
            );
          },
          child: SizedBox(
            width: 360,
            height: 40,
            child: PageSearchField(
              value: widget.searchDraft,
              hintText: widget.i18n.t('albums.searchAlbumPlaceholder'),
              focused: widget.searchFocused,
              onChanged: widget.onSearchChanged,
              onFocusChanged: widget.onSearchFocusChanged,
              onSubmitted: widget.onSearchSubmitted,
              onClear: widget.onClearSearch,
              searchTooltip: widget.i18n.t('common.search'),
              clearTooltip: widget.i18n.t('common.clear'),
            ),
          ),
        ),
        children: [
          CommandBarButton(
            icon: FluentIcons.multiselect_ltr_24_regular,
            label: widget.i18n.t('common.multiSelect'),
            active: widget.multiSelect,
            onPressed: widget.onToggleMultiSelect,
          ),
          Builder(
            builder: (context) {
              final sortItems = _albumSortMenuItems(
                widget.i18n,
                widget.sortCriterion,
                widget.onChangeAlbumSort,
              );
              return CommandBarButton(
                icon: FluentIcons.arrow_sort_24_regular,
                label: _albumSortLabel(widget.i18n, widget.sortCriterion),
                onPressed: () {
                  showMenuFlyout(context, items: sortItems);
                },
                onOverflowPressedWithContext: (buttonContext) {
                  unawaited(showMenuFlyout(buttonContext, items: sortItems));
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AlbumsAppBarActions extends StatelessWidget {
  const _AlbumsAppBarActions({
    required this.searchOpen,
    required this.searchDraft,
    required this.searchHasText,
    required this.sortCriterion,
    required this.i18n,
    required this.searchFocused,
    required this.searchSuggestions,
    required this.searchHistoryEntries,
    required this.onOpenSearch,
    required this.onCloseSearch,
    required this.onSearchChanged,
    required this.onSearchFocusChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onSelectSearchSuggestion,
    required this.onRemoveRecentSearch,
    required this.onClearRecentSearches,
    required this.onChangeAlbumSort,
  });

  final bool searchOpen;
  final String searchDraft;
  final bool searchHasText;
  final AlbumSortCriterion sortCriterion;
  final SmPlayerI18n i18n;
  final bool searchFocused;
  final List<String> searchSuggestions;
  final List<SearchHistoryEntry> searchHistoryEntries;
  final VoidCallback onOpenSearch;
  final VoidCallback onCloseSearch;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onSearchFocusChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSelectSearchSuggestion;
  final ValueChanged<int> onRemoveRecentSearch;
  final VoidCallback onClearRecentSearches;
  final ValueChanged<AlbumSortCriterion> onChangeAlbumSort;

  @override
  Widget build(BuildContext context) {
    final showSuggestions = searchFocused && searchSuggestions.isNotEmpty;
    final showHistory =
        searchFocused &&
        searchDraft.trim().isEmpty &&
        searchHistoryEntries.isNotEmpty;
    final panel = Material(
      key: const ValueKey('Albums.AppBarActions'),
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.zero,
        child:
            searchOpen
                ? SizedBox(
                  height: 36,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Focus(
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent &&
                                    event.logicalKey ==
                                        LogicalKeyboardKey.escape) {
                                  onCloseSearch();
                                  return KeyEventResult.handled;
                                }
                                return KeyEventResult.ignored;
                              },
                              child: PageSearchField(
                                key: const ValueKey(
                                  'Albums.AppBar.SearchField',
                                ),
                                value: searchDraft,
                                hintText: i18n.t(
                                  'albums.searchAlbumPlaceholder',
                                ),
                                focused: searchFocused,
                                autofocus: true,
                                height: 36,
                                appBar: true,
                                onChanged: onSearchChanged,
                                onFocusChanged: onSearchFocusChanged,
                                onSubmitted: onSearchSubmitted,
                                onClear: onClearSearch,
                                searchTooltip: i18n.t('common.search'),
                                clearTooltip: i18n.t('common.clear'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          AppBarPageSearchCloseButton(
                            tooltip: i18n.t('common.close'),
                            onPressed: onCloseSearch,
                          ),
                        ],
                      ),
                      if (showSuggestions || showHistory)
                        Positioned(
                          top: 42,
                          left: 0,
                          right: 40,
                          child:
                              showSuggestions
                                  ? PageSearchSuggestionPanel(
                                    labels: searchSuggestions,
                                    onSelect: onSelectSearchSuggestion,
                                  )
                                  : PageSearchHistoryPanel(
                                    entries: searchHistoryEntries,
                                    i18n: i18n,
                                    onSelect: onSelectSearchSuggestion,
                                    onRemove: onRemoveRecentSearch,
                                    onClear: onClearRecentSearches,
                                  ),
                        ),
                    ],
                  ),
                )
                : CommandBar(
                  style: CommandBarStyleVariant.appBar,
                  overflowLabel: i18n.t('player.more'),
                  children: [
                    CommandBarButton(
                      key: const ValueKey('Albums.AppBar.Search'),
                      icon: FluentIcons.search_20_regular,
                      label: i18n.t('common.search'),
                      active: searchHasText,
                      showLabel: false,
                      canOverflow: false,
                      onPressed: onOpenSearch,
                    ),
                    Builder(
                      builder: (context) {
                        return CommandBarButton(
                          key: const ValueKey('Albums.AppBar.Sort'),
                          icon: FluentIcons.arrow_sort_20_regular,
                          label: _albumSortLabel(i18n, sortCriterion),
                          showLabel: false,
                          canOverflow: false,
                          onPressed: () {
                            showMenuFlyout(
                              context,
                              items: _albumSortMenuItems(
                                i18n,
                                sortCriterion,
                                onChangeAlbumSort,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
      ),
    );
    return panel;
  }
}

class _AlbumsQuickJump extends StatelessWidget {
  const _AlbumsQuickJump({
    required this.activeKey,
    required this.enabledKeys,
    required this.i18n,
    required this.onJump,
  });

  final String activeKey;
  final Set<String> enabledKeys;
  final SmPlayerI18n i18n;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: _albumQuickJumpWidth,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 18),
      child: Column(
        children:
            artistQuickJumpKeys.map((key) {
              final enabled = enabledKeys.contains(key);
              final active = activeKey == key;
              return Expanded(
                child: Tooltip(
                  message: getQuickJumpTooltip(
                    key: key,
                    enabled: enabled,
                    targetName: i18n.t('common.albums'),
                    basisName: i18n.t('common.album'),
                    i18n: i18n,
                  ),
                  child: TextButton(
                    key: ValueKey('Albums.QuickJump.$key'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(20, 0),
                      foregroundColor:
                          enabled
                              ? active
                                  ? _AlbumsColors.quickJumpActiveForeground(
                                    brightness,
                                  )
                                  : _AlbumsColors.quickJumpForeground(
                                    brightness,
                                  )
                              : _AlbumsColors.quickJumpDisabled(brightness),
                      backgroundColor:
                          active
                              ? _AlbumsColors.quickJumpActiveBackground(
                                brightness,
                              )
                              : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    onPressed:
                        enabled
                            ? () {
                              onJump(key);
                            }
                            : null,
                    child: Text(
                      key,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _AlbumsProgress extends StatefulWidget {
  const _AlbumsProgress({super.key});

  @override
  State<_AlbumsProgress> createState() => _AlbumsProgressState();
}

class _AlbumsProgressState extends State<_AlbumsProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Transform.translate(
        offset: const Offset(0, -6),
        child: Container(
          height: 3,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _AlbumsColors.accentProgressTrackFor(brightness),
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final offset = lerpDouble(-1.2, 3.4, _controller.value)!;
              return FractionalTranslation(
                translation: Offset(offset, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(widthFactor: 0.34, child: child),
                ),
              );
            },
            child: ColoredBox(color: _AlbumsColors.accentFor(brightness)),
          ),
        ),
      ),
    );
  }
}

class _AlbumsPagePanel extends StatelessWidget {
  const _AlbumsPagePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: SizedBox.expand(child: child),
    );
  }
}

class _AlbumsEmptyState extends StatelessWidget {
  const _AlbumsEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _AlbumsColors.emptyStateSurfaceFor(brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _AlbumsColors.emptyStateBorderFor(brightness),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: _AlbumsColors.textStrongFor(brightness),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Text(
                message,
                style: TextStyle(
                  color: _AlbumsColors.textMutedFor(brightness),
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumArtPreviewDialog extends StatelessWidget {
  const _AlbumArtPreviewDialog({
    required this.album,
    required this.i18n,
    required this.onClose,
  });

  final AlbumView album;
  final SmPlayerI18n i18n;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final viewport = MediaQuery.sizeOf(context);
    final dialogWidth = min(420.0, viewport.width * 0.86);
    final artworkSize = min(320.0, viewport.width * 0.70);
    return Positioned.fill(
      child: Material(
        color: _AlbumsColors.previewBackdropFor(brightness),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('Albums.ArtPreview.Backdrop'),
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: const SizedBox.expand(),
              ),
            ),
            Center(
              child: GestureDetector(
                key: const ValueKey('Albums.ArtPreview.Dialog'),
                onTap: () {},
                child: Container(
                  width: dialogWidth,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _AlbumsColors.previewDialogSurfaceFor(brightness),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _AlbumsColors.previewDialogBorderFor(brightness),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _AlbumsColors.previewDialogShadowFor(brightness),
                        blurRadius: brightness == Brightness.dark ? 72 : 44,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -12,
                        right: -12,
                        child: IconButton(
                          tooltip: i18n.t('common.close'),
                          style: IconButton.styleFrom(
                            fixedSize: const Size.square(32),
                            minimumSize: const Size.square(32),
                            padding: EdgeInsets.zero,
                            backgroundColor:
                                _AlbumsColors.previewCloseSurfaceFor(
                                  brightness,
                                ),
                            foregroundColor: _AlbumsColors.textMutedFor(
                              brightness,
                            ),
                            hoverColor: _AlbumsColors.surfaceControlHoverFor(
                              brightness,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(FluentIcons.dismiss_20_regular),
                          iconSize: 16,
                          onPressed: onClose,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: AlbumArtControl(
                              album: album,
                              dimension: artworkSize,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            album.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _AlbumsColors.textStrongFor(brightness),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<AlbumView> buildAlbumViews(List<LibrarySong> songs, SmPlayerI18n i18n) {
  final groups = <String, List<LibrarySong>>{};
  for (final song in songs) {
    final albumName = displayAlbum(song, i18n);
    final group = groups[albumName] ?? <LibrarySong>[];
    group.add(song);
    groups[albumName] = group;
  }

  return groups.entries.map((entry) {
    final sourceAlbumSongs = entry.value;
    final albumSongs =
        sourceAlbumSongs.toList()
          ..sort((left, right) => compareArtistText(left.title, right.title));
    final artists = getAlbumArtists(albumSongs, i18n);
    final artworkSong =
        sourceAlbumSongs.any((song) => song.thumbnailPath.isNotEmpty)
            ? sourceAlbumSongs.firstWhere(
              (song) => song.thumbnailPath.isNotEmpty,
            )
            : sourceAlbumSongs.first;
    return AlbumView(
      name: entry.key,
      artists: artists,
      artist: artists.first,
      songs: albumSongs,
      artworkSong: artworkSong,
      duration: albumSongs.fold(0, (total, song) => total + song.duration),
    );
  }).toList();
}

List<String> getAlbumArtists(List<LibrarySong> songs, SmPlayerI18n i18n) {
  final artistCounts = <String, int>{};
  for (final song in songs) {
    final artists = getSongArtists(song);
    final artistNames =
        artists.isEmpty ? [i18n.t('common.artistUnknown')] : artists;
    for (final artist in artistNames) {
      artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
    }
  }

  final entries =
      artistCounts.entries.toList()..sort((left, right) {
        if (left.value != right.value) {
          return right.value.compareTo(left.value);
        }
        return compareArtistText(left.key, right.key);
      });
  return entries.map((entry) => entry.key).toList();
}

List<AlbumView> searchAlbums(List<AlbumView> albums, String query) {
  final keyword = query.trim();
  if (keyword.isEmpty) {
    return albums;
  }

  final scored =
      albums
          .map(
            (album) => (
              album: album,
              score: evaluateString(album.name, keyword),
            ),
          )
          .where((result) => result.score > 0)
          .toList();
  scored.sort((left, right) => right.score.compareTo(left.score));
  return scored.map((result) => result.album).toList();
}

Map<String, int> buildAlbumQuickJumpMap(List<AlbumView> albums) {
  final indexes = <String, int>{};
  for (var index = 0; index < albums.length; index += 1) {
    indexes.putIfAbsent(
      getArtistQuickJumpBucket(albums[index].name),
      () => index,
    );
  }
  return indexes;
}

List<AlbumView> sortAlbums(
  List<AlbumView> albums,
  AlbumSortCriterion criterion,
) {
  final sorted = albums.toList();
  switch (criterion) {
    case AlbumSortCriterion.artist:
      sorted.sort((left, right) {
        final artistCompare = compareArtistText(left.artist, right.artist);
        return artistCompare != 0
            ? artistCompare
            : compareArtistText(left.name, right.name);
      });
      return sorted;
    case AlbumSortCriterion.name:
    case AlbumSortCriterion.defaultSort:
      sorted.sort((left, right) {
        final nameCompare = compareArtistText(left.name, right.name);
        return nameCompare != 0
            ? nameCompare
            : compareArtistText(left.artist, right.artist);
      });
      return sorted;
    case AlbumSortCriterion.reverse:
      return sorted.reversed.toList();
  }
}

String _albumSortLabel(SmPlayerI18n i18n, AlbumSortCriterion criterion) {
  switch (criterion) {
    case AlbumSortCriterion.artist:
      return i18n.t('albums.sort.artist');
    case AlbumSortCriterion.name:
      return i18n.t('albums.sort.name');
    case AlbumSortCriterion.reverse:
      return i18n.t('local.sortReverseList');
    case AlbumSortCriterion.defaultSort:
      return i18n.t('albums.sort.default');
  }
}

List<MenuFlyoutItem> _albumSortMenuItems(
  SmPlayerI18n i18n,
  AlbumSortCriterion sortCriterion,
  ValueChanged<AlbumSortCriterion> onChangeAlbumSort,
) {
  return [
    MenuFlyoutItem(
      key: 'albums-sort-reverse',
      text: i18n.t('local.sortReverseList'),
      onPressed: () {
        onChangeAlbumSort(AlbumSortCriterion.reverse);
      },
    ),
    MenuFlyoutItem(
      key: 'albums-sort-default',
      text: i18n.t('albums.sort.default'),
      icon:
          sortCriterion == AlbumSortCriterion.defaultSort
              ? FluentIcons.checkmark_20_regular
              : null,
      onPressed: () {
        onChangeAlbumSort(AlbumSortCriterion.defaultSort);
      },
    ),
    MenuFlyoutItem(
      key: 'albums-sort-name',
      text: i18n.t('albums.sort.name'),
      icon:
          sortCriterion == AlbumSortCriterion.name
              ? FluentIcons.checkmark_20_regular
              : null,
      onPressed: () {
        onChangeAlbumSort(AlbumSortCriterion.name);
      },
    ),
    MenuFlyoutItem(
      key: 'albums-sort-artist',
      text: i18n.t('albums.sort.artist'),
      icon:
          sortCriterion == AlbumSortCriterion.artist
              ? FluentIcons.checkmark_20_regular
              : null,
      onPressed: () {
        onChangeAlbumSort(AlbumSortCriterion.artist);
      },
    ),
  ];
}

class _AlbumsColors {
  const _AlbumsColors._();

  static Color accentFor(Brightness brightness) {
    return brightness == Brightness.dark ? accent : accentStrong;
  }

  static Color accentProgressTrackFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1f0078d7)
        : accentProgressTrack;
  }

  static Color textStrongFor(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xf0f6f9fc) : textStrong;
  }

  static Color textMutedFor(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xadcbd5e1) : textMuted;
  }

  static Color emptyStateSurfaceFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x0bffffff)
        : emptyStateSurface;
  }

  static Color emptyStateBorderFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1fdee0ec)
        : emptyStateBorder;
  }

  static Color quickJumpForeground(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xadcbd5e1) : textMuted;
  }

  static Color quickJumpActiveBackground(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0x2e0078d7) : accentSoft;
  }

  static Color quickJumpActiveForeground(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xff459de2)
        : accentStrong;
  }

  static Color quickJumpDisabled(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0x40dee7f2) : disabled;
  }

  static Color previewBackdropFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x9e04080d)
        : const Color(0x61101824);
  }

  static Color previewDialogSurfaceFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xfa161c24)
        : const Color(0xfafafcff);
  }

  static Color previewDialogBorderFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1fdee0ec)
        : const Color(0xadffffff);
  }

  static Color previewDialogShadowFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x7a000000)
        : const Color(0x2435495f);
  }

  static Color previewCloseSurfaceFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x0effffff)
        : const Color(0x94ffffff);
  }

  static Color surfaceControlHoverFor(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0x290078d7) : accentSoft;
  }

  static const accent = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const accentSoft = Color(0x1a0078d7);
  static const accentProgressTrack = Color(0x1f0063b1);
  static const textStrong = Color(0xff1f252b);
  static const textMuted = Color(0xff5f625f);
  static const disabled = Color(0x3d5b697a);
  static const emptyStateSurface = Color(0x94ffffff);
  static const emptyStateBorder = Color(0x94ffffff);
}
