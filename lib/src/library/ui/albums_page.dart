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
import 'album_tile.dart';
import 'artists_page_model.dart';
import 'command_bar.dart';
import 'headered_playlist_model.dart' show getNextPlaylistName;
import 'library_page_actions.dart';
import 'page_search_history_panel.dart';
import 'page_selection_store.dart';
import 'quick_jump_tooltip.dart';

const _albumTileTrackWidth = 180.0;
const _albumColumnGap = 30.0;
const _albumRowHeight = 250.0;

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
  var _sortCriterion = AlbumSortCriterion.defaultSort;
  AlbumSortCriterion? _syncedAlbumsSort;
  var _reverseDisplayOrder = false;
  var _targetApplied = false;
  var _albumScrollTop = 0.0;
  String? _albumQuickJumpTargetKey;
  int? _albumQuickJumpTargetRow;
  final _selection = PageSelectionController<String>.stored('albums');
  final _albumGridScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
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
    _albumGridScrollController.removeListener(_handleAlbumGridScroll);
    _albumGridScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(musicLibrarySnapshotProvider);

    if (i18nValue.isLoading) {
      return const _AlbumsPagePanel(child: _AlbumsLoadingState());
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const _AlbumsPagePanel(child: _AlbumsLoadingState());
    }

    return snapshotValue.when(
      loading: () => const _AlbumsPagePanel(child: _AlbumsLoadingState()),
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
        final albumSearchHistoryEntries =
            snapshot.recentSearches
                .where((entry) => entry.type == SearchHistoryType.albums)
                .take(10)
                .toList();
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

        if (visibleAlbums.isEmpty) {
          return _AlbumsPagePanel(
            child: Column(
              children: [
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
                  onSearchSubmitted: _submitSearch,
                  onClearSearch: _clearSearch,
                  onSelectSearchSuggestion: _selectSearchQuery,
                  onRemoveRecentSearch: _removeRecentSearch,
                  onClearRecentSearches: _clearRecentSearches,
                  onChangeAlbumSort: _changeAlbumSort,
                  onToggleMultiSelect: _enterMultiSelect,
                ),
                Expanded(
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
            final columns =
                compact
                    ? 2
                    : ((constraints.maxWidth - 58 + _albumColumnGap) /
                            (_albumTileTrackWidth + _albumColumnGap))
                        .floor()
                        .clamp(1, 12);
            final activeAlbumQuickJumpKey = _getActiveAlbumQuickJumpKey(
              visibleAlbums,
              columns,
            );

            return _AlbumsPagePanel(
              child: Stack(
                children: [
                  Column(
                    children: [
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
                        onSearchSubmitted: _submitSearch,
                        onClearSearch: _clearSearch,
                        onSelectSearchSuggestion: _selectSearchQuery,
                        onRemoveRecentSearch: _removeRecentSearch,
                        onClearRecentSearches: _clearRecentSearches,
                        onChangeAlbumSort: _changeAlbumSort,
                        onToggleMultiSelect: _enterMultiSelect,
                      ),
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
                                );
                              },
                            ),
                            Expanded(
                              child: Scrollbar(
                                controller: _albumGridScrollController,
                                thumbVisibility: true,
                                child: GridView.builder(
                                  controller: _albumGridScrollController,
                                  padding: EdgeInsets.fromLTRB(
                                    18,
                                    16,
                                    18,
                                    _selection.multiSelect
                                        ? multiSelectCommandBarScrollSpacer
                                        : 28,
                                  ),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        mainAxisExtent: _albumRowHeight,
                                        crossAxisSpacing: _albumColumnGap,
                                        mainAxisSpacing: 0,
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
                                      onAddAlbum: () {
                                        _showAlbumAddToMenu(
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
                                        _showAlbumContextMenu(
                                          position,
                                          album,
                                          customPlaylists,
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
                              addSongsToNowPlaying(ref, selectedSongIds);
                              _hideSelectionAfterOperation(
                                snapshot
                                    .hideMultiSelectCommandBarAfterOperation,
                              );
                            },
                    onToggleFavorite:
                        selectedSongIds.isEmpty
                            ? null
                            : () {
                              setSongsFavorite(
                                ref,
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
                      addSongsToPlaylist(ref, playlistId, selectedSongIds);
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _submitSearch() {
    final query = _searchDraft.trim();
    setState(() {
      _searchDraft = query;
      _searchQuery = _searchDraft;
      _searchFocused = false;
    });
    if (query.isNotEmpty) {
      ref
          .read(libraryRepositoryProvider)
          .addRecentSearch(query, SearchHistoryType.albums);
      ref.invalidate(musicLibrarySnapshotProvider);
    }
    _scrollAlbumsToTop();
  }

  void _selectSearchQuery(String query) {
    setState(() {
      _searchDraft = query;
      _searchQuery = query;
      _searchFocused = false;
    });
    ref
        .read(libraryRepositoryProvider)
        .addRecentSearch(query, SearchHistoryType.albums);
    ref.invalidate(musicLibrarySnapshotProvider);
    _scrollAlbumsToTop();
  }

  void _clearSearch() {
    setState(() {
      _searchDraft = '';
      _searchQuery = '';
      _searchFocused = false;
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
    ref.read(libraryRepositoryProvider).removeRecentSearches([entryId]);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _clearRecentSearches() {
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final entryIds =
        snapshot.recentSearches
            .where((entry) => entry.type == SearchHistoryType.albums)
            .map((entry) => entry.id)
            .toList();
    ref.read(libraryRepositoryProvider).removeRecentSearches(entryIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _changeAlbumSort(AlbumSortCriterion criterion) {
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

  void _showAlbumContextMenu(
    Offset position,
    AlbumView album,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) {
    final i18n = context.smPlayerI18n;
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: album.songIds,
      playlists: playlists,
      includeNowPlaying: true,
      includeFavorites: album.songs.any((song) => !song.favorite),
      onAddToNowPlaying: () {
        addSongsToNowPlaying(ref, album.songIds);
      },
      onToggleFavorite:
          album.songs.any((song) => !song.favorite)
              ? () {
                setSongsFavorite(
                  ref,
                  album.songs
                      .where((song) => !song.favorite)
                      .map((song) => song.id)
                      .toList(),
                  true,
                );
              }
              : null,
      onCreatePlaylist: () async {
        final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
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
        addSongsToPlaylist(ref, playlistId, album.songIds);
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
            _playSongIds(album.songIds, shuffle: true);
          },
        ),
        if (addToItem != null) addToItem,
        MenuFlyoutItem(
          key: 'select',
          text: i18n.t('context.select'),
          icon: FluentIcons.select_all_on_20_regular,
          onPressed: () {
            setState(() {
              _selection.enterMultiSelect();
              if (!_selection.isSelected(album.name)) {
                _selection.toggle(album.name);
              }
            });
          },
        ),
        MenuFlyoutItem(
          key: 'see-album-art',
          text: i18n.t('context.seeAlbumArt'),
          icon: FluentIcons.image_20_regular,
          onPressed: () {
            _showMessage(i18n.t('context.seeAlbumArt'));
          },
        ),
      ],
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _showAlbumAddToMenu(
    AlbumView album,
    List<MultiSelectCommandBarPlaylist> playlists,
    MusicLibrarySnapshot snapshot,
    SmPlayerI18n i18n,
  ) {
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: album.songIds,
      playlists: playlists,
      includeNowPlaying: true,
      includeFavorites: album.songs.any((song) => !song.favorite),
      onAddToNowPlaying: () {
        addSongsToNowPlaying(ref, album.songIds);
      },
      onToggleFavorite:
          album.songs.any((song) => !song.favorite)
              ? () {
                setSongsFavorite(
                  ref,
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
        addSongsToPlaylist(ref, playlistId, album.songIds);
      },
    );
    if (addToItem == null) {
      return;
    }

    showMenuFlyout(context, items: addToItem.submenu);
  }

  void _playSongIds(List<int> songIds, {bool shuffle = false}) {
    if (songIds.isEmpty) {
      return;
    }

    final queueSongIds = songIds.toList();
    if (shuffle) {
      queueSongIds.shuffle(Random());
    }
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final firstSong = songsById[queueSongIds.first]!;
    ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          MediaControlTrack(
            id: firstSong.id,
            title: firstSong.title,
            artist: firstSong.artist,
            artworkUrl: firstSong.thumbnailPath,
            isLoading: false,
            favorite: firstSong.favorite,
          ),
          durationSeconds: firstSong.duration.toDouble(),
          queueIndex: 0,
        );
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _jumpToAlbumKey(
    Map<String, int> albumQuickJumpMap,
    String key,
    int columns,
  ) {
    final targetIndex = albumQuickJumpMap[key];
    if (targetIndex == null) {
      return;
    }
    final targetRow = targetIndex ~/ columns;

    setState(() {
      _albumQuickJumpTargetKey = key;
      _albumQuickJumpTargetRow = targetRow;
    });
    _albumGridScrollController.animateTo(
      targetRow * _albumRowHeight,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollAlbumsToTop() {
    if (!_albumGridScrollController.hasClients) {
      return;
    }

    setState(() {
      _albumScrollTop = 0;
      _albumQuickJumpTargetKey = null;
      _albumQuickJumpTargetRow = null;
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
    });
  }

  String _getActiveAlbumQuickJumpKey(
    List<AlbumView> visibleAlbums,
    int columns,
  ) {
    if (visibleAlbums.isEmpty) {
      return '';
    }

    final topRow = max(0, (_albumScrollTop / _albumRowHeight).floor());
    if (_albumQuickJumpTargetRow == topRow &&
        _albumQuickJumpTargetKey != null) {
      return _albumQuickJumpTargetKey!;
    }

    final activeIndex = min(visibleAlbums.length - 1, topRow * columns);
    return getArtistQuickJumpBucket(visibleAlbums[activeIndex].name);
  }
}

class _AlbumsToolbar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final showSuggestions = searchFocused && searchSuggestions.isNotEmpty;
    final showHistory =
        searchFocused &&
        searchDraft.trim().isEmpty &&
        searchHistoryEntries.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
      child: Column(
        children: [
          CommandBar(
            overflowLabel: i18n.t('player.more'),
            content: SizedBox(
              height: 40,
              child: Focus(
                onFocusChange: onSearchFocusChanged,
                child: TextField(
                  controller: TextEditingController(text: searchDraft)
                    ..selection = TextSelection.collapsed(
                      offset: searchDraft.length,
                    ),
                  onTap: () {
                    onSearchFocusChanged(true);
                  },
                  onChanged: onSearchChanged,
                  onSubmitted: (_) {
                    onSearchSubmitted();
                  },
                  decoration: InputDecoration(
                    hintText: i18n.t('albums.searchAlbumPlaceholder'),
                    prefixIcon: const Icon(FluentIcons.search_20_regular),
                    suffixIcon:
                        searchHasText
                            ? IconButton(
                              icon: const Icon(FluentIcons.dismiss_20_regular),
                              onPressed: onClearSearch,
                            )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: _AlbumsColors.commandSurface,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            children: [
              CommandBarButton(
                icon: FluentIcons.select_all_on_24_regular,
                label: i18n.t('common.multiSelect'),
                active: multiSelect,
                onPressed: onToggleMultiSelect,
              ),
              Builder(
                builder: (context) {
                  return CommandBarButton(
                    icon: FluentIcons.arrow_sort_24_regular,
                    label: _albumSortLabel(i18n, sortCriterion),
                    onPressed: () {
                      showMenuFlyout(
                        context,
                        items: [
                          MenuFlyoutItem(
                            key: 'reverse',
                            text: i18n.t('local.sortReverseList'),
                            icon: FluentIcons.arrow_sort_down_lines_20_regular,
                            checked:
                                sortCriterion == AlbumSortCriterion.reverse,
                            onPressed: () {
                              onChangeAlbumSort(AlbumSortCriterion.reverse);
                            },
                          ),
                          MenuFlyoutItem(
                            key: 'default',
                            text: i18n.t('albums.sort.default'),
                            icon: FluentIcons.arrow_sort_20_regular,
                            checked:
                                sortCriterion == AlbumSortCriterion.defaultSort,
                            onPressed: () {
                              onChangeAlbumSort(AlbumSortCriterion.defaultSort);
                            },
                          ),
                          MenuFlyoutItem(
                            key: 'name',
                            text: i18n.t('albums.sort.name'),
                            icon: FluentIcons.text_sort_ascending_20_regular,
                            checked: sortCriterion == AlbumSortCriterion.name,
                            onPressed: () {
                              onChangeAlbumSort(AlbumSortCriterion.name);
                            },
                          ),
                          MenuFlyoutItem(
                            key: 'artist',
                            text: i18n.t('albums.sort.artist'),
                            icon: FluentIcons.person_20_regular,
                            checked: sortCriterion == AlbumSortCriterion.artist,
                            onPressed: () {
                              onChangeAlbumSort(AlbumSortCriterion.artist);
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
          if (showSuggestions || showHistory)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SizedBox(
                  width: 420,
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
              ),
            ),
        ],
      ),
    );
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
    return Container(
      width: 58,
      padding: const EdgeInsets.fromLTRB(10, 28, 16, 16),
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
                      foregroundColor:
                          enabled
                              ? active
                                  ? _AlbumsColors.accentStrong
                                  : _AlbumsColors.textMuted
                              : _AlbumsColors.disabled,
                      backgroundColor:
                          active
                              ? _AlbumsColors.accentSoft
                              : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
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

class _AlbumsPagePanel extends StatelessWidget {
  const _AlbumsPagePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SizedBox.expand(child: child),
    );
  }
}

class _AlbumsLoadingState extends StatelessWidget {
  const _AlbumsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
  }
}

class _AlbumsEmptyState extends StatelessWidget {
  const _AlbumsEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title\n$message',
        textAlign: TextAlign.center,
        style: const TextStyle(color: _AlbumsColors.textMuted, height: 1.5),
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

class _AlbumsColors {
  const _AlbumsColors._();

  static const commandSurface = Color(0xd9ffffff);
  static const accentStrong = Color(0xff0063b1);
  static const accentSoft = Color(0x1a0078d7);
  static const textMuted = Color(0xff5b697a);
  static const disabled = Color(0x3d5b697a);
}
