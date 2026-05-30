import 'dart:async';
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/album_tile.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_floating_action_button.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_card.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/search_page_model.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart'
    as song_display;
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({
    super.key,
    required this.query,
    required this.activeType,
    this.folderRelativePath,
  });

  final String query;
  final String? activeType;
  final String? folderRelativePath;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const _artistPreviewLimit = 10;
  static const _sectionPreviewLimit = 5;

  late final SettingsController _settingsController;
  final _selection = PageSelectionController<String>.stored('search');
  final _appBarPortalOwner = Object();
  String? _appBarPortalSignature;
  late final VoidCallback _clearAppBarPortalOwner;
  var _settings = const SettingsSnapshot.defaults();
  late var _activeFilter = searchFilterKeyFromType(widget.activeType);
  LibrarySong? _dialogSong;
  SongDialogMode? _dialogMode;
  SearchResult? _albumArtPreview;
  final _expandedSections = <SearchResultType>{};

  @override
  void initState() {
    super.initState();
    final appBarPortalNotifier = ref.read(
      workspaceAppBarPortalProvider.notifier,
    );
    _clearAppBarPortalOwner = () {
      if (appBarPortalNotifier.state?.owner == _appBarPortalOwner) {
        appBarPortalNotifier.state = null;
      }
    };
    _settingsController = SettingsController(
      null,
      ref.read(libraryRepositoryProvider),
    );
    _restoreSettings();
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextFilter = searchFilterKeyFromType(widget.activeType);
    if (oldWidget.query != widget.query ||
        oldWidget.folderRelativePath != widget.folderRelativePath) {
      _expandedSections.clear();
      _selection.cancel();
      _activeFilter = SearchFilterKey.all;
      _dialogSong = null;
      _dialogMode = null;
      _albumArtPreview = null;
      return;
    }
    if (nextFilter != _activeFilter) {
      _activeFilter = nextFilter;
      _recordRecentSearch();
    }
  }

  @override
  void dispose() {
    _clearAppBarPortalOwner();
    _settingsController.dispose();
    super.dispose();
  }

  void _syncAppBarPortal({
    required bool showPortal,
    required SmPlayerI18n i18n,
    required String title,
    required SearchResults results,
  }) {
    final signature =
        '$showPortal:$title:$_activeFilter:${results.artists.length}:'
        '${results.albums.length}:${results.songs.length}:'
        '${results.playlists.length}:${results.folders.length}';
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
        routePath: '/search',
        title: title,
        content: const SizedBox.shrink(),
        bottomContent: _SearchFilterTabs(
          i18n: i18n,
          activeFilter: _activeFilter,
          results: results,
          onChanged: _changeFilter,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshotValue = ref.watch(libraryContentDataProvider);
    final mediaControlState = ref.watch(mediaControlControllerProvider).state;
    final i18n =
        ref.watch(smPlayerI18nProvider).value ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    final query = widget.query.trim();

    return snapshotValue.when(
      loading: () {
        _syncAppBarPortal(
          showPortal: true,
          i18n: i18n,
          title: _searchTitle(i18n),
          results: const SearchResults.empty(),
        );
        return _SearchPageSurface(
          child:
              query.isEmpty
                  ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 22),
                    child: _SearchEmptyState(
                      message: i18n.t('search.enterKeyword'),
                    ),
                  )
                  : _SearchLoadingState(message: i18n.t('nowPlaying.loading')),
        );
      },
      error: (_, _) {
        _syncAppBarPortal(
          showPortal: true,
          i18n: i18n,
          title: _searchTitle(i18n),
          results: const SearchResults.empty(),
        );
        return _SearchPageSurface(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 22),
            child: _SearchEmptyState(message: i18n.t('search.noResult')),
          ),
        );
      },
      data: (snapshot) {
        final normalizedQuery = query.toLowerCase();
        final searchFolderPath = _searchFolderPath(
          snapshot.rootPath,
          widget.folderRelativePath,
        );
        final searchableSongs =
            searchFolderPath.isEmpty
                ? snapshot.songs
                : snapshot.songs
                    .where(
                      (song) => isSongUnderFolder(song.path, searchFolderPath),
                    )
                    .toList();
        final searchableFolders =
            searchFolderPath.isEmpty
                ? snapshot.folders
                : snapshot.folders
                    .where(
                      (folder) =>
                          isFolderUnderFolder(folder.path, searchFolderPath),
                    )
                    .toList();
        final results = buildSearchResults(
          searchableSongs,
          searchableFolders,
          snapshot.playlists,
          snapshot.rootPath,
          normalizedQuery,
          i18n,
        );
        final hasResults = _totalCount(results) > 0;
        final showNavigationAppBar = WorkspaceNavigationAppBarScope.of(context);
        _syncAppBarPortal(
          showPortal: true,
          i18n: i18n,
          title: _searchTitle(i18n),
          results: results,
        );
        final criteria = SearchCriteria(
          artists: _settings.searchArtistsCriterion,
          albums: _settings.searchAlbumsCriterion,
          songs: _settings.searchSongsCriterion,
          playlists: _settings.searchPlaylistsCriterion,
          folders: _settings.searchFoldersCriterion,
        );
        final sections = _buildSections(results, criteria);
        final visibleSections = _visibleSections(sections);
        final selectedSongIds = _selectedSongIds(visibleSections);
        final selectedItemCount = _selectedItemCount(visibleSections);
        final selectedKeys = _selectableKeys(sections);
        final folderIndex = buildFolderIndex(
          snapshot.songs,
          snapshot.folders,
          snapshot.rootPath,
        );

        return SmPlayerI18nScope(
          i18n: i18n,
          child: _SearchPageSurface(
            child: Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    if (query.isEmpty || !hasResults)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 6, 24, 22),
                        sliver: SliverToBoxAdapter(
                          child: _SearchEmptyState(
                            message:
                                query.isEmpty
                                    ? i18n.t('search.enterKeyword')
                                    : i18n.t('search.noResult'),
                          ),
                        ),
                      )
                    else ...[
                      if (!showNavigationAppBar)
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SearchResultToolbarDelegate(
                            child: _SearchFilterTabs(
                              i18n: i18n,
                              activeFilter: _activeFilter,
                              results: results,
                              onChanged: _changeFilter,
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          18,
                          24,
                          _selection.multiSelect
                              ? multiSelectCommandBarScrollSpacer
                              : 22,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            for (final section in visibleSections) ...[
                              _SearchResultSection(
                                section: section,
                                i18n: i18n,
                                activeFilter: _activeFilter,
                                showCount: snapshot.showCount,
                                mediaControlState: mediaControlState,
                                selection: _selection,
                                playlists: _customPlaylists(snapshot.playlists),
                                songsById: {
                                  for (final song in snapshot.songs)
                                    song.id: song,
                                },
                                folderNodes: folderIndex.nodes,
                                allPlaylists: snapshot.playlists,
                                expanded: _isSectionExpanded(section.type),
                                onToggleExpanded: _toggleExpandedSection,
                                onSortChanged: (criterion) {
                                  _updateSort(section.type, criterion);
                                },
                                onGetPreferenceLevel:
                                    _getSearchResultPreferenceLevel,
                                onSetPreference: _setSearchResultPreference,
                                onUndoPreference: _undoSearchResultPreference,
                                onGetSongPreferenceLevel:
                                    _getSongPreferenceLevel,
                                onSetSongPreference: _setSongPreference,
                                onUndoSongPreference: _undoSongPreference,
                                onSelectionChanged: () {
                                  setState(() {});
                                },
                                onOpenCard: (card) {
                                  _openCard(section.type, card, query);
                                },
                                onPlaySongs: _playSongIds,
                                onPlayCard: (card) {
                                  _playCard(section.type, card);
                                },
                                onPlayTrack: (song, index) {
                                  _playTrack(
                                    song,
                                    index,
                                    section.songs
                                        .map((item) => item.id)
                                        .toList(),
                                  );
                                },
                                onTogglePlayPause:
                                    ref
                                        .read(mediaControlControllerProvider)
                                        .onTogglePlayPause,
                                onPlayNext: _playNext,
                                onAddSongsToNowPlaying: (songIds) {
                                  return addSongsToNowPlayingWithUndo(
                                    context: context,
                                    ref: ref,
                                    i18n: i18n,
                                    songIds: songIds,
                                  );
                                },
                                onAddSongsToPlaylist: (playlistId, songIds) {
                                  return addSongsToPlaylistWithUndo(
                                    context: context,
                                    ref: ref,
                                    i18n: i18n,
                                    playlistId: playlistId,
                                    songIds: songIds,
                                    useSingleSongCall: true,
                                  );
                                },
                                onAddCardSongsToPlaylist: (
                                  playlistId,
                                  songIds,
                                ) {
                                  return addSongsToPlaylistWithUndo(
                                    context: context,
                                    ref: ref,
                                    i18n: i18n,
                                    playlistId: playlistId,
                                    songIds: songIds,
                                  );
                                },
                                onToggleSongsFavorite: (songIds, favorite) {
                                  return setSongsFavoriteWithUndo(
                                    context: context,
                                    ref: ref,
                                    i18n: i18n,
                                    songIds: songIds,
                                    favorite: favorite,
                                  );
                                },
                                onCreatePlaylist: _createPlaylist,
                                onDeleteSong: _deleteSong,
                                onOpenArtist: _openArtist,
                                onOpenAlbum: _openAlbum,
                                onOpenMusicDialog: _openMusicDialog,
                                onPreviewAlbumArt: _showAlbumArtPreview,
                                onSearchDirectory: _searchDirectory,
                                onRevealCard: _revealSearchCard,
                                onRevealSong: _revealSong,
                              ),
                              const SizedBox(height: 18),
                            ],
                          ]),
                        ),
                      ),
                    ],
                  ],
                ),
                MultiSelectCommandBar(
                  visible: _selection.multiSelect,
                  selectedCount: selectedItemCount,
                  playlists: _customPlaylists(snapshot.playlists),
                  showAddTo: true,
                  addToSongIds: selectedSongIds,
                  includeNowPlayingInAddTo: true,
                  includeFavoritesInAddTo: hasNotFavoriteSongs(
                    selectedSongIds,
                    {for (final song in snapshot.songs) song.id: song},
                  ),
                  onPlay: () {
                    _playSongIds(shuffleSearchSongIds(selectedSongIds));
                    _selection.hideAfterOperation(
                      snapshot.hideMultiSelectCommandBarAfterOperation,
                    );
                    setState(() {});
                  },
                  onAddToNowPlaying: () {
                    addSongsToNowPlayingWithUndo(
                      context: context,
                      ref: ref,
                      i18n: i18n,
                      songIds: selectedSongIds,
                    );
                    _selection.hideAfterOperation(
                      snapshot.hideMultiSelectCommandBarAfterOperation,
                    );
                    setState(() {});
                  },
                  onToggleFavorite: () {
                    final songsById = {
                      for (final song in snapshot.songs) song.id: song,
                    };
                    setSongsFavoriteWithUndo(
                      context: context,
                      ref: ref,
                      i18n: i18n,
                      songIds: notFavoriteSongIds(selectedSongIds, songsById),
                      favorite: true,
                    );
                    _selection.hideAfterOperation(
                      snapshot.hideMultiSelectCommandBarAfterOperation,
                    );
                    setState(() {});
                  },
                  onCreatePlaylist: () async {
                    await createPlaylistWithSongs(
                      context: context,
                      ref: ref,
                      i18n: i18n,
                      playlists: snapshot.playlists,
                      defaultName:
                          query.isEmpty ? i18n.t('common.songs') : query,
                      songIds: selectedSongIds,
                    );
                    if (!mounted) {
                      return;
                    }
                    _selection.hideAfterOperation(
                      snapshot.hideMultiSelectCommandBarAfterOperation,
                    );
                    setState(() {});
                  },
                  onAddToPlaylist: (playlistId) {
                    addSongsToPlaylistWithUndo(
                      context: context,
                      ref: ref,
                      i18n: i18n,
                      playlistId: playlistId,
                      songIds: selectedSongIds,
                      useSingleSongCall: true,
                    );
                    _selection.hideAfterOperation(
                      snapshot.hideMultiSelectCommandBarAfterOperation,
                    );
                    setState(() {});
                  },
                  onSelectAll: () {
                    setState(() {
                      _selection.selectAll(selectedKeys);
                    });
                  },
                  onReverseSelection: () {
                    setState(() {
                      _selection.reverseSelection(selectedKeys);
                    });
                  },
                  onClearSelection: () {
                    setState(_selection.clearSelection);
                  },
                  onCancel: () {
                    setState(_selection.cancel);
                  },
                ),
                if (_dialogSong != null && _dialogMode != null)
                  MusicDialog(
                    song: _dialogSong!,
                    initialMode: _dialogMode!,
                    canPause:
                        mediaControlState.isPlaying &&
                        mediaControlState.track.id == _dialogSong!.id,
                    onPlay: () {
                      if (mediaControlState.track.id == _dialogSong!.id) {
                        ref
                            .read(mediaControlControllerProvider)
                            .onTogglePlayPause();
                        return;
                      }
                      _playSongIds([_dialogSong!.id]);
                    },
                    onReveal: _revealSongPath,
                    onClose: () {
                      setState(() {
                        _dialogSong = null;
                        _dialogMode = null;
                      });
                    },
                  ),
                if (_albumArtPreview != null)
                  _SearchAlbumArtPreviewDialog(
                    card: _albumArtPreview!,
                    onClose: () {
                      setState(() {
                        _albumArtPreview = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_SearchSectionData> _buildSections(
    SearchResults results,
    SearchCriteria criteria,
  ) {
    return [
      _SearchSectionData.cards(
        type: SearchResultType.artists,
        criterion: criteria.artists,
        cards: sortSearchResults(results.artists, criteria.artists),
        previewLimit: _artistPreviewLimit,
      ),
      _SearchSectionData.cards(
        type: SearchResultType.albums,
        criterion: criteria.albums,
        cards: sortSearchResults(results.albums, criteria.albums),
        previewLimit: _sectionPreviewLimit,
      ),
      _SearchSectionData.songs(
        criterion: criteria.songs,
        songs: sortSearchSongs(results.songs, criteria.songs),
        previewLimit: _sectionPreviewLimit,
      ),
      _SearchSectionData.cards(
        type: SearchResultType.playlists,
        criterion: criteria.playlists,
        cards: sortSearchResults(results.playlists, criteria.playlists),
        previewLimit: _sectionPreviewLimit,
      ),
      _SearchSectionData.cards(
        type: SearchResultType.folders,
        criterion: criteria.folders,
        cards: sortSearchResults(results.folders, criteria.folders),
        previewLimit: _sectionPreviewLimit,
      ),
    ];
  }

  List<_SearchSectionData> _visibleSections(List<_SearchSectionData> sections) {
    final filtered =
        _activeFilter == SearchFilterKey.all
            ? sections.where((section) => section.count > 0).toList()
            : sections
                .where(
                  (section) =>
                      section.count > 0 &&
                      _filterForSection(section.type) == _activeFilter,
                )
                .toList();
    if (_activeFilter == SearchFilterKey.all) {
      filtered.sort((left, right) {
        final leftEmpty = left.count == 0 ? 1 : 0;
        final rightEmpty = right.count == 0 ? 1 : 0;
        return leftEmpty.compareTo(rightEmpty);
      });
    }
    return filtered;
  }

  void _changeFilter(SearchFilterKey filter) {
    final type = searchFilterTypeValue(filter);
    setState(() {
      _activeFilter = filter;
    });
    context.go(
      Uri(
        path: '/search',
        queryParameters: {
          'query': widget.query.trim(),
          if (filter != SearchFilterKey.all) 'type': type,
          if (widget.folderRelativePath?.isNotEmpty == true)
            'folder': widget.folderRelativePath!,
        },
      ).toString(),
    );
    _recordRecentSearch();
  }

  String _searchTitle(SmPlayerI18n i18n) {
    final query = widget.query.trim();
    final folder = widget.folderRelativePath ?? '';
    if (query.isNotEmpty && folder.isNotEmpty) {
      return i18n.t('search.directoryResultOf', {
        'query': query,
        'folder': folder.split('/').last,
      });
    }
    return query.isNotEmpty
        ? i18n.t('search.resultOf', {'query': query})
        : i18n.t('search.resultTitle');
  }

  bool _isSectionExpanded(SearchResultType type) {
    return _activeFilter != SearchFilterKey.all ||
        _expandedSections.contains(type);
  }

  void _toggleExpandedSection(SearchResultType type) {
    setState(() {
      if (_expandedSections.contains(type)) {
        _expandedSections.remove(type);
      } else {
        _expandedSections.add(type);
      }
    });
  }

  Future<void> _restoreSettings() async {
    await _settingsController.refresh();
    if (!mounted) {
      return;
    }

    setState(() {
      _settings = _settingsController.snapshot;
    });
  }

  Future<void> _updateSort(
    SearchResultType type,
    SearchSortCriterion criterion,
  ) async {
    final update = switch (type) {
      SearchResultType.artists => AppSettingsUpdate(
        searchArtistsCriterion: criterion,
      ),
      SearchResultType.albums => AppSettingsUpdate(
        searchAlbumsCriterion: criterion,
      ),
      SearchResultType.songs => AppSettingsUpdate(
        searchSongsCriterion: criterion,
      ),
      SearchResultType.playlists => AppSettingsUpdate(
        searchPlaylistsCriterion: criterion,
      ),
      SearchResultType.folders => AppSettingsUpdate(
        searchFoldersCriterion: criterion,
      ),
    };
    await _settingsController.updateSettings(update);
    if (!mounted) {
      return;
    }

    setState(() {
      _settings = _settingsController.snapshot;
    });
  }

  Future<String?> _getSearchResultPreferenceLevel(
    SearchResultType type,
    SearchResult card,
  ) async {
    final preferenceType = _searchResultPreferenceType(type);
    if (preferenceType == null) {
      return null;
    }
    return ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel(
          preferenceType,
          _searchResultPreferenceId(preferenceType, card),
        );
  }

  Future<void> _setSearchResultPreference(
    SearchResultType type,
    SearchResult card,
    String level,
  ) async {
    final preferenceType = _searchResultPreferenceType(type);
    if (preferenceType == null) {
      return;
    }
    await ref
        .read(libraryRepositoryProvider)
        .addPreferenceItem(
          preferenceType,
          _searchResultPreferenceId(preferenceType, card),
          card.title,
          level,
        );
    ref.invalidate(libraryContentDataProvider);
  }

  Future<void> _undoSearchResultPreference(
    SearchResultType type,
    SearchResult card,
  ) async {
    final preferenceType = _searchResultPreferenceType(type);
    if (preferenceType == null) {
      return;
    }
    await ref
        .read(libraryRepositoryProvider)
        .removePreferenceItem(
          preferenceType,
          _searchResultPreferenceId(preferenceType, card),
        );
    ref.invalidate(libraryContentDataProvider);
  }

  Future<String?> _getSongPreferenceLevel(LibrarySong song) {
    return ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('song', '${song.id}');
  }

  Future<void> _setSongPreference(LibrarySong song, String level) async {
    await ref
        .read(libraryRepositoryProvider)
        .addPreferenceItem('song', '${song.id}', song.title, level);
    ref.invalidate(libraryContentDataProvider);
  }

  Future<void> _undoSongPreference(LibrarySong song) async {
    await ref
        .read(libraryRepositoryProvider)
        .removePreferenceItem('song', '${song.id}');
    ref.invalidate(libraryContentDataProvider);
  }

  void _recordRecentSearch() {
    final query = widget.query.trim();
    if (query.isEmpty) {
      return;
    }

    final type =
        widget.folderRelativePath?.isNotEmpty == true
            ? SearchHistoryType.folders
            : searchHistoryTypeForFilter(_activeFilter);
    unawaited(
      ref.read(libraryRepositoryProvider).addRecentSearch(query, type).then((
        _,
      ) {
        invalidateRecentSearchData(ref);
      }),
    );
  }

  int _totalCount(SearchResults results) {
    return results.artists.length +
        results.albums.length +
        results.songs.length +
        results.playlists.length +
        results.folders.length;
  }

  List<String> _selectableKeys(List<_SearchSectionData> sections) {
    return [
      for (final section in _visibleSections(sections))
        ...section.visibleKeys(),
    ];
  }

  int _selectedItemCount(List<_SearchSectionData> visibleSections) {
    final selectedKeys = _selection.selectedItems;
    var count = 0;
    for (final section in visibleSections) {
      if (section.type == SearchResultType.songs) {
        for (final song in section.songs) {
          if (selectedKeys.contains(_songSelectionKey(song))) {
            count += 1;
          }
        }
      } else {
        for (final card in section.cards) {
          if (selectedKeys.contains(
            getSearchResultCardKey(section.type, card),
          )) {
            count += 1;
          }
        }
      }
    }
    return count;
  }

  List<int> _selectedSongIds(List<_SearchSectionData> visibleSections) {
    final songIds = <int>[];
    final selectedKeys = _selection.selectedItems;
    for (final section in visibleSections) {
      if (section.type == SearchResultType.songs) {
        for (final song in section.songs) {
          if (selectedKeys.contains(_songSelectionKey(song))) {
            songIds.add(song.id);
          }
        }
      } else {
        for (final card in section.cards) {
          if (selectedKeys.contains(
            getSearchResultCardKey(section.type, card),
          )) {
            songIds.addAll(card.songIds);
          }
        }
      }
    }
    return getUniqueSongIds(songIds);
  }

  void _openCard(SearchResultType type, SearchResult card, String query) {
    switch (type) {
      case SearchResultType.artists:
      case SearchResultType.albums:
      case SearchResultType.playlists:
        context.go(card.path);
      case SearchResultType.folders:
        final params = {'path': card.localFolderRelativePath ?? ''};
        context.go(Uri(path: '/local', queryParameters: params).toString());
      case SearchResultType.songs:
        break;
    }
  }

  void _playCard(SearchResultType type, SearchResult card) {
    if (type == SearchResultType.artists) {
      ref.read(libraryRepositoryProvider).recordArtistPlayed(card.title);
    }
    _playSongIds(shuffleSearchSongIds(card.songIds));
    ref.invalidate(libraryContentDataProvider);
  }

  void _playTrack(LibrarySong song, int index, List<int> songIds) {
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          mediaControlTrackForSong(song, context.smPlayerI18n),
          durationSeconds: song.duration.toDouble(),
          queueIndex: index,
        );
    ref.read(libraryRepositoryProvider).replaceNowPlaying(songIds);
    ref.invalidate(libraryContentDataProvider);
  }

  void _playSongIds(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }

    final songs = ref.read(libraryContentDataProvider).value!.songs;
    final songsById = {for (final song in songs) song.id: song};
    final firstSong = songsById[songIds.first]!;
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          mediaControlTrackForSong(firstSong, context.smPlayerI18n),
          durationSeconds: firstSong.duration.toDouble(),
          queueIndex: 0,
        );
    ref.read(libraryRepositoryProvider).replaceNowPlaying(songIds);
    ref.invalidate(libraryContentDataProvider);
  }

  void _playNext(LibrarySong song) {
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final queueSongIds = snapshot.nowPlaying.songIds.toList();
    queueSongIds.remove(song.id);
    final selectedQueueIndex =
        ref.read(mediaControlControllerProvider).state.selectedQueueIndex;
    queueSongIds.insert(
      selectedQueueIndex == null ? 0 : selectedQueueIndex + 1,
      song.id,
    );
    ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
    ref.invalidate(libraryContentDataProvider);
  }

  Future<void> _createPlaylist(String name, List<int> songIds) async {
    await ref.read(libraryRepositoryProvider).createPlaylist(name, songIds);
    ref.invalidate(libraryContentDataProvider);
  }

  void _openMusicDialog(LibrarySong song, SongDialogMode mode) {
    setState(() {
      _dialogSong = song;
      _dialogMode = mode;
      _albumArtPreview = null;
    });
  }

  void _showAlbumArtPreview(SearchResult card) {
    setState(() {
      _albumArtPreview = card;
      _dialogSong = null;
      _dialogMode = null;
    });
  }

  Future<void> _searchDirectory(SearchResult card) async {
    final i18n =
        ref.read(smPlayerI18nProvider).value ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    final query = await showPopupTextDialog(
      context: context,
      title: i18n.t('local.searchDirectoryPrompt', {'name': card.title}),
      initialValue: '',
      confirmLabel: i18n.t('common.search'),
    );
    if (query == null || !mounted) {
      return;
    }

    context.go(
      Uri(
        path: '/local',
        queryParameters: {
          'path': card.localFolderRelativePath ?? '',
          if (query.isNotEmpty) 'query': query,
        },
      ).toString(),
    );
  }

  Future<void> _revealSearchCard(SearchResult card) async {
    await openFolderInShell(card.sourcePath!);
  }

  Future<void> _revealSong(LibrarySong song) async {
    await _revealSongPath(song.path);
  }

  Future<void> _revealSongPath(String songPath) async {
    await revealItemInFolder(songPath);
  }

  void _deleteSong(LibrarySong song) {
    unawaited(
      requestDeleteSongFromDisk(
        context: context,
        ref: ref,
        i18n: context.smPlayerI18n,
        song: song,
      ),
    );
  }

  void _openArtist(String artist) {
    context.go('/artists?artist=${Uri.encodeQueryComponent(artist)}');
  }

  void _openAlbum(String album) {
    final albumName =
        album.isEmpty ? context.smPlayerI18n.t('common.albumUnknown') : album;
    context.go('/albums?album=${Uri.encodeQueryComponent(albumName)}');
  }

  List<MultiSelectCommandBarPlaylist> _customPlaylists(
    List<LibraryPlaylist> playlists,
  ) {
    return playlists
        .where((playlist) => !playlist.isBuiltIn)
        .map(
          (playlist) => MultiSelectCommandBarPlaylist(
            id: playlist.id,
            name: playlist.name,
            songIds: playlist.songIds,
          ),
        )
        .toList();
  }
}

class _SearchPageSurface extends StatelessWidget {
  const _SearchPageSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shellColors = ShellThemeColors.of(context);
    return ColoredBox(
      color: shellColors.workspaceSolidSurface,
      child: SizedBox.expand(child: child),
    );
  }
}

class _SearchResultToolbarDelegate extends SliverPersistentHeaderDelegate {
  const _SearchResultToolbarDelegate({required this.child});

  static const _height = 50.0;

  final Widget child;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = SearchPageThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.78, 1],
          colors: colors.resultToolbarGradient,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SearchResultToolbarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _SearchSectionData {
  const _SearchSectionData.cards({
    required this.type,
    required this.criterion,
    required this.cards,
    required this.previewLimit,
  }) : songs = const [];

  const _SearchSectionData.songs({
    required this.criterion,
    required this.songs,
    required this.previewLimit,
  }) : type = SearchResultType.songs,
       cards = const [];

  final SearchResultType type;
  final SearchSortCriterion criterion;
  final List<SearchResult> cards;
  final List<LibrarySong> songs;
  final int previewLimit;

  int get count => type == SearchResultType.songs ? songs.length : cards.length;

  List<String> visibleKeys({bool preview = false}) {
    final itemCount = (preview ? count.clamp(0, previewLimit) : count).toInt();
    return type == SearchResultType.songs
        ? [for (final song in songs.take(itemCount)) _songSelectionKey(song)]
        : [
          for (final card in cards.take(itemCount))
            getSearchResultCardKey(type, card),
        ];
  }
}

class _SearchFilterTabs extends StatelessWidget {
  const _SearchFilterTabs({
    required this.i18n,
    required this.activeFilter,
    required this.results,
    required this.onChanged,
  });

  final SmPlayerI18n i18n;
  final SearchFilterKey activeFilter;
  final SearchResults results;
  final ValueChanged<SearchFilterKey> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = <({SearchFilterKey key, String label, int count, int order})>[
      (
        key: SearchFilterKey.all,
        label: i18n.t('common.all'),
        count:
            results.artists.length +
            results.albums.length +
            results.songs.length +
            results.playlists.length +
            results.folders.length,
        order: 0,
      ),
      (
        key: SearchFilterKey.artists,
        label: i18n.t('common.artists'),
        count: results.artists.length,
        order: 1,
      ),
      (
        key: SearchFilterKey.albums,
        label: i18n.t('common.albums'),
        count: results.albums.length,
        order: 2,
      ),
      (
        key: SearchFilterKey.songs,
        label: i18n.t('common.songs'),
        count: results.songs.length,
        order: 3,
      ),
      (
        key: SearchFilterKey.playlists,
        label: i18n.t('common.playlists'),
        count: results.playlists.length,
        order: 4,
      ),
      (
        key: SearchFilterKey.folders,
        label: i18n.t('common.folders'),
        count: results.folders.length,
        order: 5,
      ),
    ];
    final orderedTabs = [
      tabs.first,
      ...tabs.skip(1).toList()..sort((left, right) {
        final leftEmpty = left.count == 0;
        final rightEmpty = right.count == 0;
        if (leftEmpty != rightEmpty) {
          return leftEmpty ? 1 : -1;
        }
        return left.order.compareTo(right.order);
      }),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 38),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
          child: Row(
            children: [
              for (final tab in orderedTabs) ...[
                _SearchFilterTab(
                  label: tab.label,
                  count: tab.count,
                  selected: tab.key == activeFilter,
                  enabled: tab.key == SearchFilterKey.all || tab.count > 0,
                  onPressed: () {
                    onChanged(tab.key);
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchFilterTab extends StatelessWidget {
  const _SearchFilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final int count;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    final foreground =
        selected
            ? Colors.white
            : enabled
            ? colors.textStrong
            : colors.textStrong.withValues(alpha: 0.46);

    return Opacity(
      opacity: enabled ? 1 : 0.46,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            gradient:
                selected
                    ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xff2584dd), _SearchColors.accent],
                    )
                    : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.transparent : colors.controlBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '$count',
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _activeSortLabel(
  List<({SearchSortCriterion value, String label})> options,
  SearchSortCriterion criterion,
) {
  return options.firstWhere((option) => option.value == criterion).label;
}

class _SearchResultSection extends StatelessWidget {
  const _SearchResultSection({
    required this.section,
    required this.i18n,
    required this.activeFilter,
    required this.showCount,
    required this.mediaControlState,
    required this.selection,
    required this.playlists,
    required this.songsById,
    required this.folderNodes,
    required this.allPlaylists,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSortChanged,
    required this.onGetPreferenceLevel,
    required this.onSetPreference,
    required this.onUndoPreference,
    required this.onGetSongPreferenceLevel,
    required this.onSetSongPreference,
    required this.onUndoSongPreference,
    required this.onSelectionChanged,
    required this.onOpenCard,
    required this.onPlaySongs,
    required this.onPlayCard,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onAddSongsToNowPlaying,
    required this.onAddSongsToPlaylist,
    required this.onAddCardSongsToPlaylist,
    required this.onToggleSongsFavorite,
    required this.onCreatePlaylist,
    required this.onDeleteSong,
    required this.onOpenArtist,
    required this.onOpenAlbum,
    required this.onOpenMusicDialog,
    required this.onPreviewAlbumArt,
    required this.onSearchDirectory,
    required this.onRevealCard,
    required this.onRevealSong,
  });

  final _SearchSectionData section;
  final SmPlayerI18n i18n;
  final SearchFilterKey activeFilter;
  final bool showCount;
  final MediaControlState mediaControlState;
  final PageSelectionController<String> selection;
  final List<MultiSelectCommandBarPlaylist> playlists;
  final Map<int, LibrarySong> songsById;
  final Map<String, FolderNode> folderNodes;
  final List<LibraryPlaylist> allPlaylists;
  final bool expanded;
  final ValueChanged<SearchResultType> onToggleExpanded;
  final ValueChanged<SearchSortCriterion> onSortChanged;
  final Future<String?> Function(SearchResultType, SearchResult)
  onGetPreferenceLevel;
  final Future<void> Function(SearchResultType, SearchResult, String)
  onSetPreference;
  final Future<void> Function(SearchResultType, SearchResult) onUndoPreference;
  final Future<String?> Function(LibrarySong) onGetSongPreferenceLevel;
  final Future<void> Function(LibrarySong, String) onSetSongPreference;
  final Future<void> Function(LibrarySong) onUndoSongPreference;
  final VoidCallback onSelectionChanged;
  final ValueChanged<SearchResult> onOpenCard;
  final ValueChanged<List<int>> onPlaySongs;
  final ValueChanged<SearchResult> onPlayCard;
  final void Function(LibrarySong, int) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<LibrarySong> onPlayNext;
  final Future<void> Function(List<int>) onAddSongsToNowPlaying;
  final Future<void> Function(int, List<int>) onAddSongsToPlaylist;
  final Future<void> Function(int, List<int>) onAddCardSongsToPlaylist;
  final Future<void> Function(List<int>, bool) onToggleSongsFavorite;
  final Future<void> Function(String, List<int>) onCreatePlaylist;
  final ValueChanged<LibrarySong> onDeleteSong;
  final ValueChanged<String> onOpenArtist;
  final ValueChanged<String> onOpenAlbum;
  final void Function(LibrarySong, SongDialogMode) onOpenMusicDialog;
  final ValueChanged<SearchResult> onPreviewAlbumArt;
  final ValueChanged<SearchResult> onSearchDirectory;
  final Future<void> Function(SearchResult) onRevealCard;
  final Future<void> Function(LibrarySong) onRevealSong;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    final preview = activeFilter == SearchFilterKey.all;
    final visibleCount =
        preview && !expanded ? section.previewLimit : section.count;
    final showViewToggle = preview && section.count > section.previewLimit;
    final sortOptions = getSortOptions(section.type, i18n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _sectionTitle(section.type, section.count),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              if (showViewToggle) ...[
                _SearchSectionActionButton(
                  icon: FluentIcons.grid_20_regular,
                  label:
                      expanded
                          ? i18n.t('search.viewLess')
                          : i18n.t('search.viewAll'),
                  onPressed: () => onToggleExpanded(section.type),
                ),
                const SizedBox(width: 6),
              ],
              Builder(
                builder: (buttonContext) {
                  return _SearchSectionActionButton(
                    icon: FluentIcons.arrow_sort_20_regular,
                    label: _activeSortLabel(sortOptions, section.criterion),
                    onPressed: () {
                      showMenuFlyout(
                        buttonContext,
                        items: [
                          for (final option in sortOptions)
                            MenuFlyoutItem(
                              key:
                                  'search-sort-${section.type}-${option.value}',
                              text: option.label,
                              icon:
                                  option.value == section.criterion
                                      ? FluentIcons.checkmark_20_regular
                                      : null,
                              onPressed: () => onSortChanged(option.value),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (section.type == SearchResultType.songs)
          _buildSongs(context, visibleCount)
        else
          _buildCards(context, visibleCount),
      ],
    );
  }

  String _sectionTitle(SearchResultType type, int count) {
    if (!showCount) {
      return switch (type) {
        SearchResultType.artists => i18n.t('common.artists'),
        SearchResultType.albums => i18n.t('common.albums'),
        SearchResultType.songs => i18n.t('common.songs'),
        SearchResultType.playlists => i18n.t('common.playlists'),
        SearchResultType.folders => i18n.t('common.folders'),
      };
    }

    return switch (type) {
      SearchResultType.artists => i18n.t('search.artistsWithCount', {
        'count': count,
      }),
      SearchResultType.albums => i18n.t('search.albumsWithCount', {
        'count': count,
      }),
      SearchResultType.songs => i18n.t('search.songsWithCount', {
        'count': count,
      }),
      SearchResultType.playlists => i18n.t('search.playlistsWithCount', {
        'count': count,
      }),
      SearchResultType.folders => i18n.t('search.foldersWithCount', {
        'count': count,
      }),
    };
  }

  Widget _buildSongs(BuildContext context, int visibleCount) {
    final songs = section.songs.take(visibleCount).toList();
    return Column(
      children: [
        for (var index = 0; index < songs.length; index += 1)
          PlaylistControlItem(
            key: ValueKey('search-song-${songs[index].id}'),
            song: songs[index],
            current: songs[index].id == mediaControlState.track.id,
            playing:
                songs[index].id == mediaControlState.track.id &&
                mediaControlState.isPlaying,
            selected: selection.isSelected(_songSelectionKey(songs[index])),
            selectionMode: selection.multiSelect,
            playNextLabel: i18n.t('context.playNext'),
            removeLabel: i18n.t('nowPlaying.remove'),
            onPlayTrack: () {
              onPlayTrack(songs[index], index);
            },
            onTogglePlayPause: onTogglePlayPause,
            onToggleSelection: () {
              selection.toggle(_songSelectionKey(songs[index]));
              onSelectionChanged();
            },
            onPlayNextClick: () {
              onPlayNext(songs[index]);
            },
            onRemoveFromListClick: () {},
            onOpenContextMenu: (position) {
              _showSongContextMenu(context, position, songs[index]);
            },
          ),
      ],
    );
  }

  Widget _buildCards(BuildContext context, int visibleCount) {
    if (section.type == SearchResultType.albums) {
      return Wrap(
        spacing: 30,
        runSpacing: 26,
        children: [
          for (final card in section.cards.take(visibleCount))
            AlbumTile(
              album: getSearchAlbumTileData(card, songsById, i18n),
              multiSelect: selection.multiSelect,
              selected: selection.isSelected(
                getSearchResultCardKey(section.type, card),
              ),
              onOpenAlbum: () {
                onOpenCard(card);
              },
              onPlayAlbum: () {
                onPlayCard(card);
              },
              onAddAlbum: (position) {
                _showCardAddToMenu(context, position, card);
              },
              onToggleSelection: () {
                selection.toggle(getSearchResultCardKey(section.type, card));
                onSelectionChanged();
              },
              onOpenContextMenu: (position) {
                _showCardContextMenu(context, position, card);
              },
            ),
        ],
      );
    }

    if (section.type == SearchResultType.playlists) {
      return _SearchResultCardGrid(
        type: section.type,
        children: [
          for (final card in section.cards.take(visibleCount))
            _SearchPlaylistGridCard(
              card: card,
              playlist: allPlaylists.firstWhere(
                (playlist) => playlist.id.toString() == card.sourceId,
              ),
              songsById: songsById,
              selected: selection.isSelected(
                getSearchResultCardKey(section.type, card),
              ),
              multiSelect: selection.multiSelect,
              i18n: i18n,
              onOpen: () {
                onOpenCard(card);
              },
              onPlay: () {
                final playlist = allPlaylists.firstWhere(
                  (playlist) => playlist.id.toString() == card.sourceId,
                );
                onPlaySongs([
                  for (final songId in playlist.songIds)
                    if (songsById.containsKey(songId)) songId,
                ]);
              },
              onToggleSelection: () {
                selection.toggle(getSearchResultCardKey(section.type, card));
                onSelectionChanged();
              },
              onOpenContextMenu: (position) {
                _showCardContextMenu(context, position, card);
              },
            ),
        ],
      );
    }

    if (section.type == SearchResultType.folders) {
      return Wrap(
        spacing: 30,
        runSpacing: 26,
        children: [
          for (final card in section.cards.take(visibleCount))
            if (folderNodes[card.localFolderRelativePath ?? '']
                case final folder?)
              LocalFolderCard(
                folder: folder,
                selected: selection.isSelected(
                  getSearchResultCardKey(section.type, card),
                ),
                multiSelect: selection.multiSelect,
                nodes: folderNodes,
                songsById: songsById,
                i18n: i18n,
                onPlayFolder: (_) {
                  onPlayCard(card);
                },
                onAddFolder: (_, position) {
                  _showCardAddToMenu(context, position, card);
                },
                onRefreshFolder: (_) {},
                onSearchFolder: (_) {
                  onSearchDirectory(card);
                },
                onRevealFolder: (_) {
                  unawaited(onRevealCard(card));
                },
                onOpenFolder: (_) {
                  onOpenCard(card);
                },
                onOpenFolderMenu: (_, position) {
                  _showCardContextMenu(context, position, card);
                },
                onToggleSelection: (_) {
                  selection.toggle(getSearchResultCardKey(section.type, card));
                  onSelectionChanged();
                },
              ),
        ],
      );
    }

    final cards = section.cards.take(visibleCount).toList();
    return _SearchResultCardGrid(
      type: section.type,
      children: [
        for (final card in cards)
          Builder(
            builder: (context) {
              return _SearchResultCard(
                card: card,
                type: section.type,
                selected: selection.isSelected(
                  getSearchResultCardKey(section.type, card),
                ),
                multiSelect: selection.multiSelect,
                onOpen: () {
                  onOpenCard(card);
                },
                onPlay: () {
                  onPlayCard(card);
                },
                onToggleSelection: () {
                  selection.toggle(getSearchResultCardKey(section.type, card));
                  onSelectionChanged();
                },
                onOpenContextMenu: (position) {
                  _showCardContextMenu(context, position, card);
                },
              );
            },
          ),
      ],
    );
  }

  Future<void> _showSongContextMenu(
    BuildContext context,
    Offset position,
    LibrarySong song,
  ) async {
    final mediaState = mediaControlState;
    final preferenceLevel = await onGetSongPreferenceLevel(song);
    if (!context.mounted) {
      return;
    }
    showMenuFlyout(
      context,
      position: position,
      items: buildMusicMenuFlyoutItems(
        i18n: i18n,
        songId: song.id,
        isFavorite: song.favorite,
        isCurrentTrack: song.id == mediaState.track.id,
        isPlaying: mediaState.isPlaying,
        currentTrackId: mediaState.track.id,
        songPath: song.path,
        playlists: playlists,
        preferenceLevel: preferenceLevel,
        onUndoPreference:
            preferenceLevel == null
                ? null
                : () {
                  unawaited(onUndoSongPreference(song));
                },
        onPlay: () {
          onPlaySongs([song.id]);
        },
        onPause: onTogglePlayPause,
        onPlayNext: () {
          onPlayNext(song);
        },
        onAddToNowPlaying: () {
          unawaited(onAddSongsToNowPlaying([song.id]));
        },
        onCreatePlaylist: () {
          unawaited(onCreatePlaylist(song.title, [song.id]));
        },
        onAddToPlaylist: (playlistId) {
          unawaited(onAddSongsToPlaylist(playlistId, [song.id]));
        },
        onRemove: () {},
        onSelect: () {
          selection.enterMultiSelect();
          final songKey = _songSelectionKey(song);
          selection.replaceSelection([
            for (final key in selection.selectedItems)
              if (!_isSearchSongSelectionKey(key)) key,
            songKey,
          ], selectionAnchor: songKey);
          onSelectionChanged();
        },
        onToggleFavorite: () {
          unawaited(onToggleSongsFavorite([song.id], !song.favorite));
        },
        onSetPreference: (level) {
          unawaited(onSetSongPreference(song, level));
        },
        onDelete: () {
          onDeleteSong(song);
        },
        onHide: () {},
        onSeeArtist: () {
          final artist = song_display.primaryDisplayArtist(
            song,
            context.smPlayerI18n,
          );
          onOpenArtist(artist);
        },
        onSeeAlbum: () {
          onOpenAlbum(song_display.displayAlbum(song, context.smPlayerI18n));
        },
        onSeeMusicInfo: () {
          onOpenMusicDialog(song, SongDialogMode.properties);
        },
        onSeeLyrics: () {
          onOpenMusicDialog(song, SongDialogMode.lyrics);
        },
        onSeeAlbumArt: () {
          onOpenMusicDialog(song, SongDialogMode.albumArt);
        },
        onSeeLocal: () => onRevealSong(song),
      ),
    );
  }

  Future<void> _showCardContextMenu(
    BuildContext context,
    Offset position,
    SearchResult card,
  ) async {
    final cardKey = getSearchResultCardKey(section.type, card);
    final preferenceLevel = await onGetPreferenceLevel(section.type, card);
    if (!context.mounted) {
      return;
    }
    final favoriteSongIds = [
      for (final songId in card.songIds)
        if (songsById[songId]?.favorite != true) songId,
    ];
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: card.songIds,
      playlists: playlists,
      includeNowPlaying: true,
      includeFavorites: favoriteSongIds.isNotEmpty,
      onAddToNowPlaying: () {
        onAddSongsToNowPlaying(card.songIds);
      },
      onToggleFavorite: () {
        onToggleSongsFavorite(favoriteSongIds, true);
      },
      onCreatePlaylist: () {
        onCreatePlaylist(card.title, card.songIds);
      },
      onAddToPlaylist: (playlistId) {
        onAddCardSongsToPlaylist(playlistId, card.songIds);
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
            onPlayCard(card);
          },
        ),
        if (addToItem != null) addToItem,
        MenuFlyoutItem(
          key: 'select',
          text: i18n.t('context.select'),
          icon: FluentIcons.multiselect_ltr_20_regular,
          onPressed: () {
            selection.enterMultiSelect();
            selection.replaceSelection([
              for (final key in selection.selectedItems)
                if (_isSearchSongSelectionKey(key)) key,
              cardKey,
            ], selectionAnchor: cardKey);
            onSelectionChanged();
          },
        ),
        if (_searchResultPreferenceType(section.type) != null)
          _buildSearchResultPreferenceMenuItem(card, preferenceLevel),
        if (section.type == SearchResultType.albums)
          MenuFlyoutItem(
            key: 'see-album-art',
            text: i18n.t('context.seeAlbumArt'),
            icon: FluentIcons.image_20_regular,
            onPressed: () {
              onPreviewAlbumArt(card);
            },
          ),
        if (section.type == SearchResultType.folders) ...[
          MenuFlyoutItem(
            key: 'show-in-explorer',
            text: i18n.t('context.reveal'),
            pendingText: i18n.t('context.openingLocal'),
            icon: FluentIcons.folder_open_20_regular,
            onPressed: () => onRevealCard(card),
          ),
          MenuFlyoutItem(
            key: 'search-directory',
            text: i18n.t('local.searchDirectory'),
            icon: FluentIcons.search_20_regular,
            onPressed: () {
              onSearchDirectory(card);
            },
          ),
        ],
      ],
    );
  }

  void _showCardAddToMenu(
    BuildContext context,
    Offset position,
    SearchResult card,
  ) {
    final favoriteSongIds = [
      for (final songId in card.songIds)
        if (songsById[songId]?.favorite != true) songId,
    ];
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: card.songIds,
      playlists: playlists,
      includeNowPlaying: true,
      includeFavorites: favoriteSongIds.isNotEmpty,
      onAddToNowPlaying: () {
        onAddSongsToNowPlaying(card.songIds);
      },
      onToggleFavorite: () {
        onToggleSongsFavorite(favoriteSongIds, true);
      },
      onCreatePlaylist: () {
        onCreatePlaylist(card.title, card.songIds);
      },
      onAddToPlaylist: (playlistId) {
        onAddSongsToPlaylist(playlistId, card.songIds);
      },
    );
    if (addToItem == null) {
      return;
    }

    showMenuFlyout(context, position: position, items: addToItem.submenu);
  }

  MenuFlyoutItem _buildSearchResultPreferenceMenuItem(
    SearchResult card,
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
                onUndoPreference(section.type, card);
              },
      onSetPreference: (level) {
        onSetPreference(section.type, card, level);
      },
    );
  }
}

class _SearchSectionActionButton extends StatelessWidget {
  const _SearchSectionActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SmPlayerTextIconButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
    );
  }
}

String? _searchResultPreferenceType(SearchResultType type) {
  return switch (type) {
    SearchResultType.artists => 'artist',
    SearchResultType.albums => 'album',
    SearchResultType.playlists => 'playlist',
    SearchResultType.folders => 'folder',
    SearchResultType.songs => null,
  };
}

String _searchResultPreferenceId(String preferenceType, SearchResult card) {
  return preferenceType == 'folder' || preferenceType == 'playlist'
      ? card.sourceId!
      : card.title;
}

class _SearchAlbumArtPreviewDialog extends StatelessWidget {
  const _SearchAlbumArtPreviewDialog({
    required this.card,
    required this.onClose,
  });

  final SearchResult card;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final artworkFile = card.artworkUrl.isEmpty ? null : File(card.artworkUrl);

    return PopupDialog(
      overlayClassName: 'album-art-preview-overlay AlbumArtPreviewOverlay',
      className: 'album-art-preview-dialog AlbumArtPreviewDialog',
      navClassName: 'album-art-preview-nav AlbumArtPreviewNav',
      navLabel: i18n.t('context.seeAlbumArt'),
      ariaLabel: card.title,
      width: 560,
      height: 620,
      onClose: onClose,
      navChildren: [
        Expanded(
          child: Text(
            card.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PopupDialogColors.textStrong,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
      child: Center(
        child:
            artworkFile != null && artworkFile.existsSync()
                ? Container(
                  width: 420,
                  height: 420,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2932423a),
                        blurRadius: 42,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.file(artworkFile, fit: BoxFit.cover),
                )
                : SizedBox.square(
                  dimension: 420,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xffe8eef5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          FluentIcons.image_24_regular,
                          color: PopupDialogColors.textMuted,
                          size: 48,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          i18n.t('song.noAlbumArt'),
                          style: const TextStyle(
                            color: PopupDialogColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}

class _SearchResultCardGrid extends StatelessWidget {
  const _SearchResultCardGrid({required this.type, required this.children});

  final SearchResultType type;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isArtist = type == SearchResultType.artists;
    final spacing = isArtist ? 12.0 : 30.0;
    final runSpacing = isArtist ? 2.0 : 26.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final itemWidth =
            isArtist && maxWidth.isFinite
                ? _stretchedGridWidth(maxWidth, 260, spacing)
                : 180.0;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

double _stretchedGridWidth(double maxWidth, double minWidth, double spacing) {
  final rawColumns = ((maxWidth + spacing) / (minWidth + spacing)).floor();
  final columns = rawColumns < 1 ? 1 : rawColumns;
  return (maxWidth - spacing * (columns - 1)) / columns;
}

class _SearchPlaylistGridCard extends StatefulWidget {
  const _SearchPlaylistGridCard({
    required this.card,
    required this.playlist,
    required this.songsById,
    required this.selected,
    required this.multiSelect,
    required this.i18n,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSelection,
    required this.onOpenContextMenu,
  });

  final SearchResult card;
  final LibraryPlaylist playlist;
  final Map<int, LibrarySong> songsById;
  final bool selected;
  final bool multiSelect;
  final SmPlayerI18n i18n;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final VoidCallback onToggleSelection;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  State<_SearchPlaylistGridCard> createState() =>
      _SearchPlaylistGridCardState();
}

class _SearchPlaylistGridCardState extends State<_SearchPlaylistGridCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    final songs =
        widget.playlist.songIds
            .map((songId) => widget.songsById[songId])
            .whereType<LibrarySong>()
            .toList();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.multiSelect ? widget.onToggleSelection : widget.onOpen,
        onSecondaryTapDown: (details) {
          widget.onOpenContextMenu(details.globalPosition);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 180,
          constraints: const BoxConstraints(minHeight: 232),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                widget.selected || _hovered
                    ? colors.cardHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow:
                widget.selected
                    ? const [
                      BoxShadow(
                        color: Color(0x141e2a3a),
                        blurRadius: 34,
                        offset: Offset(0, 16),
                      ),
                    ]
                    : null,
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox.square(
                      dimension: 160,
                      child: _SearchPlaylistArtwork(songs: songs),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.i18n.t('playlists.songCount', {
                      'count': widget.playlist.songCount,
                    }),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ],
              ),
              if (_hovered && !widget.multiSelect)
                Positioned(
                  right: 8,
                  bottom: 60,
                  child: _SearchCardPlayButton(onPressed: widget.onPlay),
                ),
              if (widget.multiSelect || widget.selected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _SearchSelectionMark(selected: widget.selected),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchPlaylistArtwork extends StatelessWidget {
  const _SearchPlaylistArtwork({required this.songs});

  final List<LibrarySong> songs;

  @override
  Widget build(BuildContext context) {
    final artworkUrls =
        songs
            .where((song) => song.thumbnailPath.isNotEmpty)
            .map((song) => song.thumbnailPath)
            .toSet()
            .take(4)
            .toList();
    if (artworkUrls.isEmpty) {
      return const DefaultAlbumArtwork();
    }
    if (artworkUrls.length == 1) {
      return Image.file(File(artworkUrls.first), fit: BoxFit.cover);
    }
    return GridView.count(
      crossAxisCount: 2,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final artworkUrl in artworkUrls)
          Image.file(File(artworkUrl), fit: BoxFit.cover),
        if (artworkUrls.length == 3) const DefaultAlbumArtwork(),
      ],
    );
  }
}

class _SearchSelectionMark extends StatelessWidget {
  const _SearchSelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? _SearchColors.accent : colors.selectionMarkSurface,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.transparent : colors.selectionMarkBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1f485870),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: 23,
        child:
            selected
                ? const Icon(
                  FluentIcons.checkmark_16_regular,
                  color: Colors.white,
                  size: 16,
                )
                : null,
      ),
    );
  }
}

class _SearchResultCard extends StatefulWidget {
  const _SearchResultCard({
    required this.card,
    required this.type,
    required this.selected,
    required this.multiSelect,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSelection,
    required this.onOpenContextMenu,
  });

  final SearchResult card;
  final SearchResultType type;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final VoidCallback onToggleSelection;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    final isArtist = widget.type == SearchResultType.artists;
    final artworkFile =
        widget.card.artworkUrl.isEmpty ? null : File(widget.card.artworkUrl);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.multiSelect ? widget.onToggleSelection : widget.onOpen,
        onSecondaryTapDown: (details) {
          widget.onOpenContextMenu(details.globalPosition);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          constraints: BoxConstraints(minHeight: isArtist ? 86 : 0),
          padding:
              isArtist
                  ? const EdgeInsets.symmetric(horizontal: 14, vertical: 11)
                  : const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _cardSurface(isArtist),
            border:
                isArtist
                    ? Border.all(
                      color:
                          widget.selected
                              ? colors.accentSelectedBorder
                              : Colors.transparent,
                    )
                    : null,
            borderRadius: BorderRadius.circular(isArtist ? 10 : 14),
            boxShadow: _cardShadow(isArtist),
          ),
          child: Stack(
            children: [
              if (isArtist)
                _SearchCompactCardBody(
                  title: widget.card.title,
                  subtitle: widget.card.subtitle,
                  artwork: _SearchCardArtwork(
                    file: artworkFile,
                    size: 64,
                    radius: 8,
                    elevated: _hovered,
                  ),
                )
              else
                _SearchGridCardBody(
                  title: widget.card.title,
                  subtitle: widget.card.subtitle,
                  artwork: _SearchCardArtwork(
                    file: artworkFile,
                    size: 156,
                    radius: 12,
                  ),
                ),
              if (isArtist && _hovered && !widget.multiSelect)
                Positioned.fill(
                  left: 14,
                  right: null,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 30),
                      child: _SearchCardPlayButton(onPressed: widget.onPlay),
                    ),
                  ),
                ),
              if (!isArtist && _hovered && !widget.multiSelect)
                Positioned(
                  top: 116,
                  right: 8,
                  child: _SearchCardPlayButton(onPressed: widget.onPlay),
                ),
              if (widget.multiSelect || widget.selected)
                Positioned(
                  top: isArtist ? 9 : 8,
                  right: isArtist ? 9 : 8,
                  child: _SearchSelectionMark(selected: widget.selected),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _cardSurface(bool isArtist) {
    final colors = SearchPageThemeColors.of(context);
    if (widget.selected) {
      return colors.cardSelected;
    }
    if (_hovered) {
      return isArtist ? colors.cardHover : colors.panel;
    }
    return Colors.transparent;
  }

  List<BoxShadow>? _cardShadow(bool isArtist) {
    if (isArtist) {
      if (!widget.selected && !_hovered) {
        return null;
      }
      return const [
        BoxShadow(
          color: Color(0x141e2a3a),
          blurRadius: 30,
          offset: Offset(0, 14),
        ),
      ];
    }
    if (!widget.selected) {
      return null;
    }
    return const [
      BoxShadow(
        color: Color(0x1f1f2a38),
        blurRadius: 18,
        offset: Offset(0, 10),
      ),
    ];
  }
}

class _SearchCompactCardBody extends StatelessWidget {
  const _SearchCompactCardBody({
    required this.title,
    required this.subtitle,
    required this.artwork,
  });

  final String title;
  final String subtitle;
  final Widget artwork;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    return Row(
      children: [
        artwork,
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchGridCardBody extends StatelessWidget {
  const _SearchGridCardBody({
    required this.title,
    required this.subtitle,
    required this.artwork,
  });

  final String title;
  final String subtitle;
  final Widget artwork;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        artwork,
        const SizedBox(height: 12),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _SearchCardArtwork extends StatelessWidget {
  const _SearchCardArtwork({
    required this.file,
    required this.size,
    required this.radius,
    this.elevated = false,
  });

  final File? file;
  final double size;
  final double radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      transform: elevated ? Matrix4.translationValues(0, -1, 0) : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow:
            elevated
                ? const [
                  BoxShadow(
                    color: Color(0x33322d3f),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ]
                : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox.square(
          dimension: size,
          child: SongArtwork(artworkPath: file?.path),
        ),
      ),
    );
  }
}

class _SearchCardPlayButton extends StatelessWidget {
  const _SearchCardPlayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ArtworkFloatingActionButton(
      tooltip: context.smPlayerI18n.t('context.play'),
      size: 34,
      iconSize: 17,
      icon: const SmPlayerPlayIcon(size: 17, color: Colors.white),
      onPressed: onPressed,
    );
  }
}

class _SearchLoadingState extends StatelessWidget {
  const _SearchLoadingState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 22),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _SearchColors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              message,
              style: TextStyle(color: colors.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.emptyStateSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.emptyStateBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Text(
            message,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 26,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

SearchFilterKey _filterForSection(SearchResultType type) {
  return switch (type) {
    SearchResultType.artists => SearchFilterKey.artists,
    SearchResultType.albums => SearchFilterKey.albums,
    SearchResultType.songs => SearchFilterKey.songs,
    SearchResultType.playlists => SearchFilterKey.playlists,
    SearchResultType.folders => SearchFilterKey.folders,
  };
}

String _songSelectionKey(LibrarySong song) {
  return 'songs:${song.id}';
}

bool _isSearchSongSelectionKey(String key) {
  return key.startsWith('songs:');
}

class SearchPageThemeColors extends ThemeExtension<SearchPageThemeColors> {
  const SearchPageThemeColors({
    required this.textStrong,
    required this.textMuted,
    required this.controlBorder,
    required this.subtleBorder,
    required this.controlSurface,
    required this.controlHover,
    required this.accentStrong,
    required this.accentSelectedBorder,
    required this.selectionMarkBorder,
    required this.selectionMarkSurface,
    required this.cardHover,
    required this.cardSelected,
    required this.panel,
    required this.emptyStateSurface,
    required this.emptyStateBorder,
    required this.resultToolbarGradient,
  });

  final Color textStrong;
  final Color textMuted;
  final Color controlBorder;
  final Color subtleBorder;
  final Color controlSurface;
  final Color controlHover;
  final Color accentStrong;
  final Color accentSelectedBorder;
  final Color selectionMarkBorder;
  final Color selectionMarkSurface;
  final Color cardHover;
  final Color cardSelected;
  final Color panel;
  final Color emptyStateSurface;
  final Color emptyStateBorder;
  final List<Color> resultToolbarGradient;

  static const light = SearchPageThemeColors(
    textStrong: _SearchColors.textStrong,
    textMuted: _SearchColors.textMuted,
    controlBorder: _SearchColors.controlBorder,
    subtleBorder: _SearchColors.subtleBorder,
    controlSurface: _SearchColors.controlSurface,
    controlHover: _SearchColors.accentSoft,
    accentStrong: _SearchColors.accent,
    accentSelectedBorder: _SearchColors.accentSelectedBorder,
    selectionMarkBorder: Color(0x52768499),
    selectionMarkSurface: Colors.white,
    cardHover: _SearchColors.cardHover,
    cardSelected: _SearchColors.cardSelected,
    panel: Colors.white,
    emptyStateSurface: _SearchColors.emptyStateSurface,
    emptyStateBorder: _SearchColors.emptyStateBorder,
    resultToolbarGradient: [
      Color(0xf5fafcff),
      Color(0xe0fafcff),
      Color(0x00fafcff),
    ],
  );

  static const dark = SearchPageThemeColors(
    textStrong: Color(0xeff6f9fc),
    textMuted: Color(0xb8d8e2ef),
    controlBorder: Color(0x29d6e0ec),
    subtleBorder: Color(0x29d6e0ec),
    controlSurface: Color(0x0effffff),
    controlHover: SmPlayerInteractionColors.hoverSurfaceDark,
    accentStrong: Color(0xff5fb6ff),
    accentSelectedBorder: Color(0x6b0078d7),
    selectionMarkBorder: Color(0x6bdce6f2),
    selectionMarkSurface: Color(0xb812161d),
    cardHover: SmPlayerInteractionColors.hoverSurfaceDark,
    cardSelected: Color(0x2e0078d7),
    panel: Color(0x0cffffff),
    emptyStateSurface: _SearchColors.nightEmptyStateSurface,
    emptyStateBorder: _SearchColors.nightEmptyStateBorder,
    resultToolbarGradient: [
      Color(0xf5101419),
      Color(0xe0101419),
      Color(0x00101419),
    ],
  );

  static SearchPageThemeColors of(BuildContext context) {
    return Theme.of(context).extension<SearchPageThemeColors>() ?? light;
  }

  @override
  SearchPageThemeColors copyWith() {
    return this;
  }

  @override
  SearchPageThemeColors lerp(
    covariant ThemeExtension<SearchPageThemeColors>? other,
    double t,
  ) {
    return this;
  }
}

class _SearchColors {
  const _SearchColors._();

  static const accent = Color(0xff0063b1);
  static const accentSoft = SmPlayerInteractionColors.hoverSurface;
  static const controlBorder = Color(0x3d7e8b9a);
  static const subtleBorder = Color(0x2e768499);
  static const controlSurface = Color(0x94ffffff);
  static const cardHover = SmPlayerInteractionColors.hoverSurface;
  static const cardSelected = Color(0x1f0078d7);
  static const accentSelectedBorder = Color(0x6b0078d7);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const emptyStateSurface = Color(0x94ffffff);
  static const emptyStateBorder = Color(0x94ffffff);
  static const nightEmptyStateSurface = Color(0x0cffffff);
  static const nightEmptyStateBorder = Color(0x1fd6e0ec);
}

String _searchFolderPath(String rootPath, String? folderRelativePath) {
  final relativePath = folderRelativePath ?? '';
  if (relativePath.isEmpty) {
    return '';
  }

  final separator = rootPath.contains('\\') ? '\\' : '/';
  final normalizedRoot = rootPath.replaceFirst(RegExp(r'[\\/]+$'), '');
  return '$normalizedRoot$separator${relativePath.split('/').join(separator)}';
}
