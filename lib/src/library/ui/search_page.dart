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
import 'package:smplayer_flutter/src/library/ui/grid_artwork_card_content.dart';
import 'package:smplayer_flutter/src/library/ui/grid_view_holder.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_card.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/search_artist_card.dart';
import 'package:smplayer_flutter/src/library/ui/search_page_model.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart'
    as song_display;
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';
import 'package:smplayer_flutter/src/platform/desktop_feature_service.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/playback_queue_actions.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

part 'search_album_art_preview_dialog.dart';
part 'search_filter_tabs.dart';
part 'search_page_shell.dart';
part 'search_result_cards.dart';
part 'search_result_sections.dart';
part 'search_theme.dart';

const _searchPageHorizontalInset = 8.0;

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
  MusicDialogEntry? _musicDialog;
  SearchResult? _albumArtPreview;
  final _expandedSections = <SearchResultType>{};

  @override
  void initState() {
    super.initState();
    final appBarPortalNotifier = ref.read(
      workspaceAppBarPortalProvider.notifier,
    );
    _clearAppBarPortalOwner = () {
      clearWorkspaceAppBarPortalOwnerAfterDispose(
        appBarPortalNotifier,
        _appBarPortalOwner,
      );
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
      _musicDialog = null;
      _albumArtPreview = null;
      return;
    }
    if (nextFilter != _activeFilter) {
      _activeFilter = nextFilter;
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
        bottomContent: _SearchHeaderSurface(
          child: _SearchFilterTabs(
            i18n: i18n,
            activeFilter: _activeFilter,
            results: results,
            onChanged: _changeFilter,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshotValue = ref.watch(libraryContentDataProvider);
    final songOverrides = ref.watch(librarySongOverridesProvider);
    final mediaState = ref.watch(
      mediaControlControllerProvider.select(
        (controller) => (
          trackId: controller.state.track.id,
          isPlaying: controller.state.isPlaying,
        ),
      ),
    );
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
                    padding: const EdgeInsets.fromLTRB(
                      _searchPageHorizontalInset,
                      6,
                      _searchPageHorizontalInset,
                      22,
                    ),
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
            padding: const EdgeInsets.fromLTRB(
              _searchPageHorizontalInset,
              6,
              _searchPageHorizontalInset,
              22,
            ),
            child: _SearchEmptyState(message: i18n.t('search.noResult')),
          ),
        );
      },
      data: (rawSnapshot) {
        final snapshot = applyLibraryFavoriteOverrides(
          rawSnapshot,
          const {},
          songOverrides,
        );
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
        final searchablePlaylists = buildSearchablePlaylists(
          snapshot.playlists,
          snapshot.nowPlaying.playlistId,
        );
        final results = buildSearchResults(
          searchableSongs,
          searchableFolders,
          searchablePlaylists,
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
                        padding: const EdgeInsets.fromLTRB(
                          _searchPageHorizontalInset,
                          6,
                          _searchPageHorizontalInset,
                          22,
                        ),
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
                          _searchPageHorizontalInset,
                          18,
                          _searchPageHorizontalInset,
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
                                currentTrackId: mediaState.trackId,
                                isPlaying: mediaState.isPlaying,
                                selection: _selection,
                                playlists: _customPlaylists(snapshot.playlists),
                                nowPlayingSongIds: snapshot.nowPlaying.songIds,
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
                  bottomInset: multiSelectCommandBarShellBottomInset,
                  selectedCount: selectedItemCount,
                  playlists: _customPlaylists(snapshot.playlists),
                  showAddTo: true,
                  addToSongIds: selectedSongIds,
                  nowPlayingSongIds: snapshot.nowPlaying.songIds,
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
                      final songsById = {
                        for (final song
                            in ref
                                .read(libraryContentDataProvider)
                                .value!
                                .songs)
                          song.id: song,
                      };
                      _playTrack(
                        songsById[trackId]!,
                        queueSongIds.indexOf(trackId),
                        queueSongIds,
                      );
                    },
                    onReveal: _revealSongPath,
                    onClose: () {
                      setState(() {
                        _musicDialog = null;
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
  }

  Future<void> _undoSongPreference(LibrarySong song) async {
    await ref
        .read(libraryRepositoryProvider)
        .removePreferenceItem('song', '${song.id}');
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
  }

  void _playTrack(LibrarySong song, int index, List<int> songIds) {
    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).value!,
      i18n: context.smPlayerI18n,
      songIds: songIds,
      queueIndex: index,
    );
  }

  void _playSongIds(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }

    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).value!,
      i18n: context.smPlayerI18n,
      songIds: songIds,
      queueIndex: 0,
    );
  }

  void _playNext(LibrarySong song) {
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final queueSongIds = currentNowPlayingSongIds(ref, snapshot);
    queueSongIds.remove(song.id);
    final insertIndex = insertIndexAfterCurrentOccurrence(
      ref.read(mediaControlControllerProvider).state,
      queueSongIds,
    );
    queueSongIds.insert(insertIndex, song.id);
    setNowPlayingQueue(ref, queueSongIds);
  }

  Future<void> _createPlaylist(String name, List<int> songIds) async {
    await ref.read(libraryRepositoryProvider).createPlaylist(name, songIds);
  }

  void _openMusicDialog(
    LibrarySong song,
    SongDialogMode mode,
    List<int> queueSongIds,
  ) {
    setState(() {
      _musicDialog = (song: song, mode: mode, queueSongIds: queueSongIds);
      _albumArtPreview = null;
    });
  }

  void _showAlbumArtPreview(SearchResult card) {
    setState(() {
      _albumArtPreview = card;
      _musicDialog = null;
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

String _searchFolderPath(String rootPath, String? folderRelativePath) {
  final relativePath = folderRelativePath ?? '';
  if (relativePath.isEmpty) {
    return '';
  }

  final separator = rootPath.contains('\\') ? '\\' : '/';
  final normalizedRoot = rootPath.replaceFirst(RegExp(r'[\\/]+$'), '');
  return '$normalizedRoot$separator${relativePath.split('/').join(separator)}';
}
