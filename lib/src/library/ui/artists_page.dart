import 'dart:async';
import 'dart:math';
import 'dart:ui' show ColorFilter, ImageFilter, lerpDouble;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/loading_state.dart';
import '../../app/input_dialog.dart';
import '../../app/smplayer_vector_icons.dart';
import '../../app/undoable_notification.dart';
import '../../app/workspace_app_bar_portal.dart';
import '../../i18n/app_i18n.dart';
import '../../playback/media_control_provider.dart';
import '../../playback/media_control_model.dart'
    show PlaybackMode, shufflePlaybackQueueForCurrentTrack;
import '../../playback/media_control_track_factory.dart';
import '../../playback/playlist_control_item.dart';
import '../data/library_models.dart';
import '../data/library_providers.dart';
import 'album_tile.dart' show getAlbumArtworkSong;
import 'artists_page_model.dart';
import 'artwork_floating_action_button.dart';
import 'command_bar.dart';
import 'menu_flyout.dart';
import 'menu_flyout_helpers.dart';
import 'multi_select_command_bar.dart';
import 'library_page_actions.dart';
import 'music_dialog.dart';
import 'page_selection_store.dart';
import 'page_search_history_panel.dart';
import 'song_artwork.dart';
import '../../platform/desktop_features.dart';
import 'quick_jump_tooltip.dart';

part 'artists_master_detail.dart';
part 'artists_list_item.dart';
part 'artists_detail.dart';
part 'artists_page_state_helpers.dart';
part 'artists_page_master.dart';
part 'artists_page_chrome.dart';

const _artistsBackdropSaturate120 = ColorFilter.matrix([
  1.1574,
  -0.143,
  -0.0144,
  0,
  0,
  -0.0426,
  1.057,
  -0.0144,
  0,
  0,
  -0.0426,
  -0.143,
  1.1856,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

class ArtistsPage extends ConsumerStatefulWidget {
  const ArtistsPage({super.key, this.searchQuery = '', this.targetArtistName});

  final String searchQuery;
  final String? targetArtistName;

  @override
  ConsumerState<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends ConsumerState<ArtistsPage> {
  var _artistSearch = '';
  var _artistSearchFocused = false;
  var _appBarSearchOpen = false;
  var _selectedArtistName = '';
  String? _appliedTargetArtistName;
  String? _notifiedMissingTargetArtistName;
  var _artistScrollTop = 0.0;
  String? _artistQuickJumpPinnedKey;
  var _artistQuickJumpJumping = false;
  final _selection = PageSelectionController<int>.stored('artists');
  final _artistListController = ScrollController();
  final _artistDetailController = ScrollController();
  final _appBarPortalOwner = Object();
  String? _appBarPortalSignature;
  late final StateController<WorkspaceAppBarPortalEntry?> _appBarPortalNotifier;
  ({LibrarySong song, SongDialogMode mode})? _musicDialog;

  @override
  void initState() {
    super.initState();
    _appBarPortalNotifier = ref.read(workspaceAppBarPortalProvider.notifier);
    _artistListController.addListener(_handleArtistListScroll);
  }

  @override
  void didUpdateWidget(ArtistsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetArtistName != widget.targetArtistName) {
      _appliedTargetArtistName = null;
      _notifiedMissingTargetArtistName = null;
      if (widget.targetArtistName == null) {
        _selectedArtistName = '';
      }
    }
  }

  @override
  void dispose() {
    _clearAppBarPortalOwner();
    _artistListController.removeListener(_handleArtistListScroll);
    _artistListController.dispose();
    _artistDetailController.dispose();
    super.dispose();
  }

  void _clearAppBarPortalOwner() {
    _clearArtistsAppBarPortalOwner(this);
  }

  void _syncAppBarPortal({
    required bool showPortal,
    required String routePath,
    required Widget content,
    required String compactTitle,
    required int searchSuggestionCount,
    required int searchHistoryCount,
  }) {
    _syncArtistsAppBarPortal(
      this,
      showPortal: showPortal,
      routePath: routePath,
      content: content,
      compactTitle: compactTitle,
      searchSuggestionCount: searchSuggestionCount,
      searchHistoryCount: searchHistoryCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(libraryContentDataProvider);
    final mediaState = ref.watch(mediaControlControllerProvider).state;

    if (i18nValue.isLoading) {
      return const _ArtistsPagePanel(child: SmPlayerLoadingState());
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const _ArtistsPagePanel(child: SmPlayerLoadingState());
    }

    return snapshotValue.when(
      loading: () {
        final useWorkspaceAppBar = WorkspaceNavigationAppBarScope.of(context);
        _syncAppBarPortal(
          showPortal: true,
          routePath: '/artists',
          content: _ArtistsAppBarSearchActions(
            searchOpen: _appBarSearchOpen,
            artistSearch: _artistSearch,
            i18n: i18n,
            searchFocused: _artistSearchFocused,
            searchSuggestions: const [],
            searchHistoryEntries: const [],
            onOpenSearch: () {
              setState(() {
                _appBarSearchOpen = true;
                _artistSearchFocused = true;
              });
            },
            onCloseSearch: () {
              setState(() {
                _appBarSearchOpen = false;
                _artistSearchFocused = false;
              });
            },
            onSearchChanged: (value) {
              setState(() {
                _artistSearch = value;
              });
            },
            onSearchFocusChanged: _changeArtistSearchFocus,
            onSearchSubmitted: _recordLoadingArtistSearch,
            onClearSearch: () {
              setState(() {
                _artistSearch = '';
              });
            },
            onSelectSearchSuggestion: _selectArtistSearchQuery,
            onRemoveRecentSearch: _removeArtistRecentSearch,
            onClearRecentSearches: _clearArtistRecentSearches,
          ),
          compactTitle: i18n.t('library.allArtists'),
          searchSuggestionCount: 0,
          searchHistoryCount: 0,
        );
        return _ArtistsPagePanel(
          child: Row(
            children: [
              _ArtistsLoadingMaster(
                showSearch: !useWorkspaceAppBar,
                artistSearch: _artistSearch,
                scrollController: _artistListController,
                i18n: i18n,
                searchFocused: _artistSearchFocused,
                onChanged: (value) {
                  setState(() {
                    _artistSearch = value;
                  });
                },
                onFocusChanged: _changeArtistSearchFocus,
                onSubmitted: _recordLoadingArtistSearch,
              ),
              const Expanded(child: _ArtistsDetailLoadingState()),
            ],
          ),
        );
      },
      error:
          (_, _) => _ArtistsPagePanel(
            child: _ArtistsEmptyState(
              title: i18n.t('collection.artistNotFound'),
              message: i18n.t('library.scanHelp'),
            ),
          ),
      data: (snapshot) {
        final artistGroups = buildArtistGroups(snapshot.songs, i18n);
        if (widget.targetArtistName != null) {
          final target = widget.targetArtistName!;
          final targetIndex = artistGroups.indexWhere(
            (artist) => artist.name == target,
          );
          if (targetIndex >= 0 && _appliedTargetArtistName != target) {
            _appliedTargetArtistName = target;
            _notifiedMissingTargetArtistName = null;
            _selectedArtistName = target;
            _artistSearch = target;
            _selection.cancel();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              unawaited(
                ref
                    .read(libraryRepositoryProvider)
                    .addRecentSearch(target, SearchHistoryType.artists)
                    .then((_) {
                      invalidateRecentSearchData(ref);
                    }),
              );
              if (_artistListController.hasClients) {
                _artistListController.jumpTo(targetIndex * artistRowHeight);
              }
              if (_artistDetailController.hasClients) {
                _artistDetailController.jumpTo(0);
              }
            });
          } else if (targetIndex < 0 &&
              _notifiedMissingTargetArtistName != target) {
            _notifiedMissingTargetArtistName = target;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              showAppNotification(
                context: context,
                message: i18n.t('collection.artistNotFound'),
                duration: const Duration(milliseconds: 3200),
              );
            });
          }
        }

        final visibleArtists = artistGroups;
        final targetArtistName = widget.targetArtistName;
        final targetArtistAvailable =
            targetArtistName != null &&
            visibleArtists.any((artist) => artist.name == targetArtistName);
        if (!targetArtistAvailable &&
            !visibleArtists.any(
              (artist) => artist.name == _selectedArtistName,
            )) {
          _selection.cancel();
          _selectedArtistName =
              MediaQuery.sizeOf(context).width <= 720 || visibleArtists.isEmpty
                  ? ''
                  : visibleArtists.first.name;
        }
        final artistSearchSuggestions =
            _artistSearch.trim().isEmpty
                ? const <String>[]
                : searchArtists(
                  artistGroups,
                  _artistSearch,
                ).take(8).map((artist) => artist.name).toList();
        final artistSearchHistoryEntries = latestSearchHistoryEntries(
          snapshot.recentSearches,
          SearchHistoryType.artists,
        );
        final matchingSelectedArtists =
            visibleArtists
                .where((artist) => artist.name == _selectedArtistName)
                .toList();
        final wideSelectedArtist =
            matchingSelectedArtists.isNotEmpty
                ? matchingSelectedArtists.first
                : (visibleArtists.isEmpty ? null : visibleArtists.first);
        final compactSelectedArtist =
            matchingSelectedArtists.isNotEmpty
                ? matchingSelectedArtists.first
                : null;
        final artistQuickJumpMap = buildArtistQuickJumpMap(visibleArtists);
        final activeArtistQuickJumpKey = _getActiveArtistQuickJumpKey(
          visibleArtists,
        );

        final selectedArtistForSelection =
            compactSelectedArtist ?? wideSelectedArtist;
        final selectedArtistSongIds =
            selectedArtistForSelection?.songs.map((song) => song.id).toList() ??
            const <int>[];
        final selectedVisibleSongIds =
            selectedArtistSongIds
                .where((songId) => _selection.selectedItems.contains(songId))
                .toList();
        final songsById = {for (final song in snapshot.songs) song.id: song};
        final customLibraryPlaylists =
            snapshot.playlists
                .where((playlist) => !playlist.isBuiltIn)
                .toList();
        final customPlaylists =
            customLibraryPlaylists
                .map(
                  (playlist) => MultiSelectCommandBarPlaylist(
                    id: playlist.id,
                    name: playlist.name,
                    songIds: playlist.songIds,
                  ),
                )
                .toList();
        final useWorkspaceAppBar = WorkspaceNavigationAppBarScope.of(context);
        final compactLayout = MediaQuery.sizeOf(context).width <= 720;
        final compactAppBarTitle =
            widget.targetArtistName != null
                ? ''
                : compactLayout && compactSelectedArtist != null
                ? compactSelectedArtist.name
                : _allArtistsTitle(snapshot, artistGroups, i18n);
        _syncAppBarPortal(
          showPortal: true,
          routePath: '/artists',
          content: _ArtistsAppBarSearchActions(
            searchOpen: _appBarSearchOpen,
            artistSearch: _artistSearch,
            i18n: i18n,
            searchFocused: _artistSearchFocused,
            searchSuggestions: artistSearchSuggestions,
            searchHistoryEntries: artistSearchHistoryEntries,
            onOpenSearch: () {
              setState(() {
                _appBarSearchOpen = true;
                _artistSearchFocused = true;
              });
            },
            onCloseSearch: () {
              setState(() {
                _appBarSearchOpen = false;
                _artistSearchFocused = false;
              });
            },
            onSearchChanged: (value) {
              setState(() {
                _artistSearch = value;
              });
            },
            onSearchFocusChanged: _changeArtistSearchFocus,
            onSearchSubmitted: () {
              _submitArtistSearch();
              setState(() {
                _appBarSearchOpen = false;
              });
            },
            onClearSearch: () {
              setState(() {
                _artistSearch = '';
              });
            },
            onSelectSearchSuggestion: (query) {
              _selectArtistSearchQuery(query);
              setState(() {
                _appBarSearchOpen = false;
              });
            },
            onRemoveRecentSearch: _removeArtistRecentSearch,
            onClearRecentSearches: _clearArtistRecentSearches,
          ),
          compactTitle: compactAppBarTitle,
          searchSuggestionCount: artistSearchSuggestions.length,
          searchHistoryCount: artistSearchHistoryEntries.length,
        );

        return Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth <= 720;
                return _ArtistsPagePanel(
                  child: _ArtistsMasterDetail(
                    compact: compact,
                    artistSearch: _artistSearch,
                    compactSelectedArtist: compactSelectedArtist,
                    wideSelectedArtist: wideSelectedArtist,
                    visibleArtists: visibleArtists,
                    artistQuickJumpMap: artistQuickJumpMap,
                    activeArtistQuickJumpKey: activeArtistQuickJumpKey,
                    artistListController: _artistListController,
                    artistDetailController: _artistDetailController,
                    multiSelect: _selection.multiSelect,
                    selectedSongIds: _selection.selectedItems,
                    i18n: i18n,
                    showSearch: !useWorkspaceAppBar,
                    searchFocused: _artistSearchFocused,
                    searchSuggestions: artistSearchSuggestions,
                    searchHistoryEntries: artistSearchHistoryEntries,
                    selectedArtistSongIds: selectedArtistSongIds,
                    customPlaylists: customPlaylists,
                    selectedTrackId: mediaState.track.id,
                    isPlaying: mediaState.isPlaying,
                    onSearchChanged: (value) {
                      setState(() {
                        _artistSearch = value;
                      });
                    },
                    onSearchFocusChanged: _changeArtistSearchFocus,
                    onSearchSubmitted: _submitArtistSearch,
                    onSelectSearchSuggestion: _selectArtistSearchQuery,
                    onRemoveRecentSearch: _removeArtistRecentSearch,
                    onClearRecentSearches: _clearArtistRecentSearches,
                    onOpenArtistDetail: _openArtistDetail,
                    onPlayArtist: (artist) {
                      _playShuffledSongIds(
                        artist.songs.map((song) => song.id).toList(),
                        artistName: artist.name,
                      );
                    },
                    onOpenArtistMenu: ({required position, required artist}) {
                      _showGroupContextMenu(
                        position: position,
                        type: _ArtistGroupMenuType.artist,
                        label: artist.name,
                        songs: artist.songs,
                      );
                    },
                    onOpenArtistDetailMenu: ({
                      required position,
                      required artist,
                      required showLocateArtist,
                    }) {
                      _showGroupContextMenu(
                        position: position,
                        type: _ArtistGroupMenuType.artist,
                        label: artist.name,
                        songs: artist.songs,
                        showLocateArtist: showLocateArtist,
                      );
                    },
                    onOpenAlbumMenu: ({required position, required album}) {
                      _showGroupContextMenu(
                        position: position,
                        type: _ArtistGroupMenuType.album,
                        label: album.name,
                        songs: album.songs,
                      );
                    },
                    onJumpToArtistKey: _jumpToArtistKey,
                    onReturnToArtistList: _returnToArtistList,
                    onPlaySongs: _playShuffledSongIds,
                    onPlayTrack: _playTrackInQueue,
                    onTogglePlayPause:
                        ref
                            .read(mediaControlControllerProvider)
                            .onTogglePlayPause,
                    onPlayNext: _playNext,
                    onToggleFavorite: (songId, favorite) {
                      setSongsFavorite(ref, [songId], favorite);
                    },
                    onOpenSongAddToMenu: _showSongAddToMenu,
                    onToggleSongSelection: _toggleSongSelection,
                    onOpenSongContextMenu: (position, song) {
                      _showSongContextMenu(
                        position,
                        song,
                        selectedArtistSongIds,
                        customPlaylists,
                      );
                    },
                  ),
                );
              },
            ),
            if (_selection.multiSelect)
              MultiSelectCommandBar(
                visible: _selection.multiSelect,
                selectedCount: selectedVisibleSongIds.length,
                playlists: customPlaylists,
                addToSongIds: selectedVisibleSongIds,
                includeNowPlayingInAddTo: true,
                includeFavoritesInAddTo: hasNotFavoriteSongs(
                  selectedVisibleSongIds,
                  songsById,
                ),
                onAddToNowPlaying:
                    selectedVisibleSongIds.isEmpty
                        ? null
                        : () {
                          addSongsToNowPlayingWithUndo(
                            context: context,
                            ref: ref,
                            i18n: i18n,
                            songIds: selectedVisibleSongIds,
                          );
                        },
                onToggleFavorite:
                    selectedVisibleSongIds.isEmpty
                        ? null
                        : () {
                          setSongsFavoriteWithUndo(
                            context: context,
                            ref: ref,
                            i18n: i18n,
                            songIds: notFavoriteSongIds(
                              selectedVisibleSongIds,
                              songsById,
                            ),
                            favorite: true,
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
                            playlists: customLibraryPlaylists,
                            defaultName:
                                selectedArtistForSelection?.name ??
                                i18n.t('common.artists'),
                            songIds: selectedVisibleSongIds,
                          );
                        },
                onPlay: () {
                  _playSongIds(selectedVisibleSongIds);
                  setState(() {
                    _selection.hideAfterOperation(
                      snapshot.hideMultiSelectCommandBarAfterOperation,
                    );
                  });
                },
                onAddToPlaylist: (playlistId) {
                  addSongsToPlaylistWithUndo(
                    context: context,
                    ref: ref,
                    i18n: i18n,
                    playlistId: playlistId,
                    songIds: selectedVisibleSongIds,
                  );
                },
                onSelectAll: () {
                  setState(() {
                    _selection.selectAll(selectedArtistSongIds);
                  });
                },
                onReverseSelection: () {
                  setState(() {
                    _selection.reverseSelection(selectedArtistSongIds);
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
                canPause:
                    dialog.song.id == mediaState.track.id &&
                    mediaState.isPlaying,
                onPlay: () {
                  _playTrackInQueue(dialog.song.id, [dialog.song.id]);
                },
                onReveal: (path) {
                  unawaited(revealItemInFolder(path));
                },
                onSaved: () {
                  ref.invalidate(libraryContentDataProvider);
                },
                onClose: () {
                  setState(() {
                    _musicDialog = null;
                  });
                },
              ),
          ],
        );
      },
    );
  }

  void _openArtistDetail(String artistName) {
    _openArtistDetailForArtistsPage(this, artistName);
  }

  void _submitArtistSearch() {
    final query = _artistSearch.trim();
    if (query.isEmpty) {
      return;
    }

    final snapshot = ref.read(libraryContentDataProvider).value!;
    final i18n = ref.read(smPlayerI18nProvider).valueOrNull!;
    final artistGroups = buildArtistGroups(snapshot.songs, i18n);
    final suggestions = searchArtists(artistGroups, query);
    final exactMatches =
        artistGroups.where((artist) => artist.name == query).toList();
    final targetArtist =
        exactMatches.isNotEmpty
            ? exactMatches.first
            : (suggestions.isEmpty ? null : suggestions.first);
    if (targetArtist != null) {
      unawaited(
        ref
            .read(libraryRepositoryProvider)
            .addRecentSearch(targetArtist.name, SearchHistoryType.artists)
            .then((_) {
              invalidateRecentSearchData(ref);
            }),
      );
      setState(() {
        _artistSearch = targetArtist.name;
      });
      _openArtistDetail(targetArtist.name);
    } else {
      unawaited(
        ref
            .read(libraryRepositoryProvider)
            .addRecentSearch(query, SearchHistoryType.artists)
            .then((_) {
              invalidateRecentSearchData(ref);
            }),
      );
    }
  }

  void _recordLoadingArtistSearch() {
    _recordLoadingArtistSearchForArtistsPage(this);
  }

  void _selectArtistSearchQuery(String query) {
    setState(() {
      _artistSearch = query;
      _artistSearchFocused = false;
    });
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .addRecentSearch(query, SearchHistoryType.artists)
          .then((_) {
            invalidateRecentSearchData(ref);
          }),
    );
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final i18n = ref.read(smPlayerI18nProvider).valueOrNull!;
    final artistGroups = buildArtistGroups(snapshot.songs, i18n);
    final exactMatches =
        artistGroups.where((artist) => artist.name == query).toList();
    final suggestions = searchArtists(artistGroups, query);
    final targetArtist =
        exactMatches.isNotEmpty
            ? exactMatches.first
            : (suggestions.isEmpty ? null : suggestions.first);
    if (targetArtist != null) {
      _openArtistDetail(targetArtist.name);
    }
  }

  void _changeArtistSearchFocus(bool focused) {
    _changeArtistSearchFocusForArtistsPage(this, focused);
  }

  void _removeArtistRecentSearch(int entryId) {
    _removeArtistRecentSearchForArtistsPage(this, entryId);
  }

  void _clearArtistRecentSearches() {
    _clearArtistRecentSearchesForArtistsPage(this);
  }

  void _returnToArtistList() {
    _returnToArtistListForArtistsPage(this);
  }

  void _jumpToArtistKey(Map<String, int> artistQuickJumpMap, String key) {
    _jumpToArtistKeyForArtistsPage(this, artistQuickJumpMap, key);
  }

  void _scrollToArtist(String artistName) {
    _scrollToArtistForArtistsPage(this, artistName);
  }

  void _handleArtistListScroll() {
    _handleArtistListScrollForArtistsPage(this);
  }

  String _getActiveArtistQuickJumpKey(List<ArtistGroup> visibleArtists) {
    return _getActiveArtistQuickJumpKeyForArtistsPage(this, visibleArtists);
  }

  void _toggleSongSelection(int songId) {
    setState(() {
      _selection.toggle(songId);
    });
  }

  void _playSongIds(List<int> songIds) {
    _playSongIdsForArtistsPage(this, songIds);
  }

  void _playTrackInQueue(int songId, List<int> queueSongIds) {
    _playTrackInQueueForArtistsPage(this, songId, queueSongIds);
  }

  void _playNext(int songId) {
    _playNextForArtistsPage(this, songId);
  }

  void _moveToMusicOrPlay(int songId) {
    _moveToMusicOrPlayForArtistsPage(this, songId);
  }

  void _playShuffledSongIds(
    List<int> songIds, {
    String? artistName,
    String? albumName,
  }) {
    _playShuffledSongIdsForArtistsPage(
      this,
      songIds,
      artistName: artistName,
      albumName: albumName,
    );
  }

  Future<void> _showGroupContextMenu({
    required Offset position,
    required _ArtistGroupMenuType type,
    required String label,
    required List<LibrarySong> songs,
    bool showLocateArtist = false,
  }) {
    return _showGroupContextMenuForArtistsPage(
      this,
      position: position,
      type: type,
      label: label,
      songs: songs,
      showLocateArtist: showLocateArtist,
    );
  }

  MenuFlyoutItem _buildGroupPreferenceMenuItem(
    SmPlayerI18n i18n,
    _ArtistGroupMenuType type,
    String label,
    String? preferenceLevel,
  ) {
    return _buildGroupPreferenceMenuItemForArtistsPage(
      this,
      i18n,
      type,
      label,
      preferenceLevel,
    );
  }

  Future<void> _showSongContextMenu(
    Offset position,
    LibrarySong song,
    List<int> queueSongIds,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) {
    return _showSongContextMenuForArtistsPage(
      this,
      position,
      song,
      queueSongIds,
      playlists,
    );
  }

  void _openMusicDialog(LibrarySong song, SongDialogMode mode) {
    setState(() {
      _musicDialog = (song: song, mode: mode);
    });
  }

  void _showSongAddToMenu(BuildContext buttonContext, LibrarySong song) {
    _showSongAddToMenuForArtistsPage(this, buttonContext, song);
  }

  String _allArtistsTitle(
    LibraryContentData snapshot,
    List<ArtistGroup> artistGroups,
    SmPlayerI18n i18n,
  ) {
    return snapshot.showCount
        ? i18n.t('library.allArtistsWithCount', {'count': artistGroups.length})
        : i18n.t('library.allArtists');
  }
}

enum _ArtistGroupMenuType { artist, album }

class _ArtistsAppBarSearchActions extends StatelessWidget {
  const _ArtistsAppBarSearchActions({
    required this.searchOpen,
    required this.artistSearch,
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
  });

  final bool searchOpen;
  final String artistSearch;
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

  @override
  Widget build(BuildContext context) {
    if (!searchOpen) {
      return CommandBar(
        style: CommandBarStyleVariant.appBar,
        overflowLabel: i18n.t('player.more'),
        children: [
          CommandBarButton(
            key: const ValueKey('Artists.AppBar.Search'),
            icon: FluentIcons.search_20_regular,
            label: i18n.t('common.search'),
            active: artistSearch.isNotEmpty,
            showLabel: false,
            canOverflow: false,
            onPressed: onOpenSearch,
          ),
        ],
      );
    }
    final showSuggestions = searchFocused && searchSuggestions.isNotEmpty;
    final showHistory =
        searchFocused &&
        artistSearch.trim().isEmpty &&
        searchHistoryEntries.isNotEmpty;
    return SizedBox(
      height: 36,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              Expanded(
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.escape) {
                      onCloseSearch();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: PageSearchField(
                    key: const ValueKey('Artists.AppBar.SearchField'),
                    value: artistSearch,
                    hintText: i18n.t('artists.searchArtistsPlaceholder'),
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
    );
  }
}

class _ArtistsSearchBox extends StatefulWidget {
  const _ArtistsSearchBox({
    required this.artistSearch,
    required this.i18n,
    required this.searchFocused,
    required this.searchSuggestions,
    required this.searchHistoryEntries,
    required this.onChanged,
    required this.onFocusChanged,
    required this.onSubmitted,
    required this.onSelectSearchSuggestion,
    required this.onRemoveRecentSearch,
    required this.onClearRecentSearches,
  });

  final String artistSearch;
  final SmPlayerI18n i18n;
  final bool searchFocused;
  final List<String> searchSuggestions;
  final List<SearchHistoryEntry> searchHistoryEntries;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onFocusChanged;
  final VoidCallback onSubmitted;
  final ValueChanged<String> onSelectSearchSuggestion;
  final ValueChanged<int> onRemoveRecentSearch;
  final VoidCallback onClearRecentSearches;

  @override
  State<_ArtistsSearchBox> createState() => _ArtistsSearchBoxState();
}

class _ArtistsSearchBoxState extends State<_ArtistsSearchBox> {
  final _dropdownController = OverlayPortalController();

  bool get _showSuggestions =>
      widget.searchFocused && widget.searchSuggestions.isNotEmpty;

  bool get _showHistory =>
      widget.searchFocused &&
      widget.artistSearch.trim().isEmpty &&
      widget.searchHistoryEntries.isNotEmpty;

  bool get _showDropdown => _showSuggestions || _showHistory;

  @override
  void didUpdateWidget(covariant _ArtistsSearchBox oldWidget) {
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
    return OverlayPortal.overlayChildLayoutBuilder(
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
        height: 40,
        child: PageSearchField(
          value: widget.artistSearch,
          hintText: widget.i18n.t('artists.searchArtistsPlaceholder'),
          focused: widget.searchFocused,
          onChanged: widget.onChanged,
          onFocusChanged: widget.onFocusChanged,
          onSubmitted: widget.onSubmitted,
          onClear: () {
            widget.onChanged('');
          },
          searchTooltip: widget.i18n.t('common.search'),
          clearTooltip: widget.i18n.t('common.clear'),
        ),
      ),
    );
  }
}
