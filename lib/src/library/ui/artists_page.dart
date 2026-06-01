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
part 'artists_page_search.dart';
part 'artists_album_header.dart';
part 'artists_colors.dart';
part 'artists_page_actions.dart';

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
  String? _pendingOpenedArtistRoute;
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
      if (widget.targetArtistName == _pendingOpenedArtistRoute) {
        _appliedTargetArtistName = widget.targetArtistName;
        _selectedArtistName = widget.targetArtistName ?? '';
        _pendingOpenedArtistRoute = null;
      } else {
        _appliedTargetArtistName = null;
        _pendingOpenedArtistRoute = null;
      }
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
    Widget? bottomContent,
  }) {
    _syncArtistsAppBarPortal(
      this,
      showPortal: showPortal,
      routePath: routePath,
      content: content,
      compactTitle: compactTitle,
      searchSuggestionCount: searchSuggestionCount,
      searchHistoryCount: searchHistoryCount,
      bottomContent: bottomContent,
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
        final compactAppBarArtist =
            compactSelectedArtist ??
            (targetArtistAvailable
                ? visibleArtists.firstWhere(
                  (artist) => artist.name == targetArtistName,
                )
                : null);
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
            compactLayout
                ? compactAppBarArtist?.name ??
                    _allArtistsTitle(snapshot, artistGroups, i18n)
                : _allArtistsTitle(snapshot, artistGroups, i18n);
        final compactAppBarDetailControls =
            useWorkspaceAppBar && compactLayout && compactAppBarArtist != null
                ? _ArtistDetailCompactCommandRow(
                  artist: compactAppBarArtist,
                  i18n: i18n,
                  onReturnToArtistList: _returnToArtistList,
                  onPlaySongs: () {
                    _playShuffledSongIds(
                      compactAppBarArtist.songs.map((song) => song.id).toList(),
                      artistName: compactAppBarArtist.name,
                    );
                  },
                  onOpenArtistMenu: (position) {
                    _showGroupContextMenu(
                      position: position,
                      type: _ArtistGroupMenuType.artist,
                      label: compactAppBarArtist.name,
                      songs: compactAppBarArtist.songs,
                      showLocateArtist: true,
                    );
                  },
                )
                : null;
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
          bottomContent: compactAppBarDetailControls,
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

  void _updateArtistsPageState(VoidCallback update) {
    setState(update);
  }
}

enum _ArtistGroupMenuType { artist, album }
