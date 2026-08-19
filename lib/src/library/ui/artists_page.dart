import 'dart:async';
import 'dart:math';
import 'dart:ui' show ColorFilter, ImageFilter, lerpDouble;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_interaction_colors.dart';
import '../../app/auto_hide_scrollbar_visibility.dart';
import '../../app/loading_state.dart';
import '../../app/input_dialog.dart';
import '../../app/shell_models.dart';
import '../../app/smplayer_vector_icons.dart';
import '../../app/undoable_notification.dart';
import '../../app/workspace_app_bar_portal.dart';
import '../../i18n/app_i18n.dart';
import '../../playback/media_control_provider.dart';
import '../../playback/media_control_model.dart'
    show PlaybackMode, shufflePlaybackQueueForCurrentTrack;
import '../../playback/playback_queue_actions.dart';
import '../../playback/playlist_control.dart';
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
import '../../platform/desktop_feature_service.dart';
import 'quick_jump_tooltip.dart';

part 'artists_master_detail.dart';
part 'artist_list_item.dart';
part 'artist_list_artwork.dart';
part 'artists_detail.dart';
part 'artist_detail_header_delegate.dart';
part 'artist_detail_header.dart';
part 'artist_detail_compact_command_row.dart';
part 'artist_header_action_button_style.dart';
part 'artist_album_sliver_section.dart';
part 'artist_album_song_row_shell.dart';
part 'artist_album_song_list_top_border_painter.dart';
part 'artists_page_state_helpers.dart';
part 'artists_master_metrics.dart';
part 'compact_artists_page.dart';
part 'artists_master.dart';
part 'artist_quick_jump.dart';
part 'artists_loading_master.dart';
part 'artists_progress.dart';
part 'artists_detail_loading_state.dart';
part 'artists_loading_spinner.dart';
part 'artists_loading_spinner_painter.dart';
part 'artists_custom_scrollbar.dart';
part 'artists_page_panel.dart';
part 'artists_empty_state.dart';
part 'artists_app_bar_search_actions.dart';
part 'artists_search_box.dart';
part 'artist_album_header.dart';
part 'artist_album_title_link.dart';
part 'album_artwork.dart';
part 'artists_colors.dart';
part 'artists_page_actions.dart';
part 'artists_page_data.dart';
part 'artists_summary_format.dart';

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
  var _artistSortCriterion = ArtistSortCriterion.name;
  var _reverseArtistDisplayOrder = false;
  String? _appliedTargetArtistName;
  String? _pendingOpenedArtistRoute;
  String? _notifiedMissingTargetArtistName;
  String? _locatedArtistName;
  var _locateArtistPulse = 0;
  var _artistScrollTop = 0.0;
  String? _artistQuickJumpPinnedKey;
  var _artistQuickJumpJumping = false;
  final _selection = PageSelectionController<int>.stored('artists');
  final _artistListController = ScrollController();
  final _artistDetailController = ScrollController();
  final _appBarPortalOwner = Object();
  String? _appBarPortalSignature;
  late final StateController<WorkspaceAppBarPortalEntry?> _appBarPortalNotifier;
  MusicDialogEntry? _musicDialog;

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
    required String layoutSignature,
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
      layoutSignature: layoutSignature,
      searchSuggestionCount: searchSuggestionCount,
      searchHistoryCount: searchHistoryCount,
      bottomContent: bottomContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
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
            sortCriterion: _artistSortCriterion,
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
            onChangeArtistSort: _changeArtistSort,
          ),
          compactTitle: i18n.t('library.allArtists'),
          layoutSignature: 'loading',
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
      data: (rawSnapshot) {
        final libraryData = ref.watch(
          _artistsLibraryDataProvider((
            snapshot: rawSnapshot,
            songOverrides: songOverrides,
            i18n: i18n,
          )),
        );
        final snapshot = libraryData.snapshot;
        final artistGroups = libraryData.artistGroups;
        final sortedArtistGroups = ref.watch(
          _sortedArtistGroupsProvider((
            artistGroups: artistGroups,
            criterion: _artistSortCriterion,
          )),
        );
        final visibleArtists =
            _reverseArtistDisplayOrder
                ? sortedArtistGroups.reversed.toList()
                : sortedArtistGroups;
        if (widget.targetArtistName != null) {
          final target = widget.targetArtistName!;
          final targetIndex = visibleArtists.indexWhere(
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

        final targetArtistName = widget.targetArtistName;
        final targetArtistAvailable =
            targetArtistName != null &&
            visibleArtists.any((artist) => artist.name == targetArtistName);
        final compactLayout = _isArtistsPageCompactWorkspace(context);
        final targetArtist =
            targetArtistAvailable
                ? visibleArtists.firstWhere(
                  (artist) => artist.name == targetArtistName,
                )
                : null;
        if (!targetArtistAvailable &&
            !visibleArtists.any(
              (artist) => artist.name == _selectedArtistName,
            )) {
          _selection.cancel();
          _selectedArtistName =
              compactLayout || visibleArtists.isEmpty
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
            targetArtist ??
            (matchingSelectedArtists.isNotEmpty
                ? matchingSelectedArtists.first
                : null);
        final artistQuickJumpKeys = artistQuickJumpKeysForSort(
          _artistSortCriterion,
        );
        final artistQuickJumpMap = buildArtistQuickJumpMap(
          visibleArtists,
          _artistSortCriterion,
        );
        final activeArtistQuickJumpKey = _getActiveArtistQuickJumpKey(
          visibleArtists,
          _artistSortCriterion,
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
        final songsById = libraryData.songsById;
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
        return Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth <= 720;
                final compactAppBarTitle =
                    compact
                        ? compactSelectedArtist?.name ??
                            _allArtistsTitle(snapshot, artistGroups, i18n)
                        : _allArtistsTitle(snapshot, artistGroups, i18n);
                final compactAppBarDetailControls =
                    useWorkspaceAppBar &&
                            compact &&
                            compactSelectedArtist != null
                        ? DecoratedBox(
                          key: const ValueKey(
                            'Artists.DetailHeader.AppBarShadow',
                          ),
                          decoration:
                              _ArtistsColors.compactDetailHeaderDecoration(
                                Theme.of(context).brightness,
                              ),
                          child: _ArtistDetailCompactCommandRow(
                            artist: compactSelectedArtist,
                            i18n: i18n,
                            workspaceAppBarBottom: true,
                            onPlaySongs: () {
                              _playShuffledSongIds(
                                compactSelectedArtist.songs
                                    .map((song) => song.id)
                                    .toList(),
                                artistName: compactSelectedArtist.name,
                              );
                            },
                            onOpenArtistMenu: (position) {
                              _showGroupContextMenu(
                                position: position,
                                type: _ArtistGroupMenuType.artist,
                                label: compactSelectedArtist.name,
                                songs: compactSelectedArtist.songs,
                                showLocateArtist: true,
                              );
                            },
                          ),
                        )
                        : null;
                _syncAppBarPortal(
                  showPortal: true,
                  routePath: '/artists',
                  content: _ArtistsAppBarSearchActions(
                    searchOpen: _appBarSearchOpen,
                    artistSearch: _artistSearch,
                    sortCriterion: _artistSortCriterion,
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
                    onChangeArtistSort: _changeArtistSort,
                  ),
                  compactTitle: compactAppBarTitle,
                  layoutSignature:
                      compact
                          ? 'compact:${compactSelectedArtist?.name ?? ''}'
                          : 'wide',
                  searchSuggestionCount: artistSearchSuggestions.length,
                  searchHistoryCount: artistSearchHistoryEntries.length,
                  bottomContent: compactAppBarDetailControls,
                );
                return _ArtistsPagePanel(
                  child: _ArtistsMasterDetail(
                    compact: compact,
                    artistSearch: _artistSearch,
                    compactSelectedArtist: compactSelectedArtist,
                    wideSelectedArtist: wideSelectedArtist,
                    visibleArtists: visibleArtists,
                    sortCriterion: _artistSortCriterion,
                    artistQuickJumpKeys: artistQuickJumpKeys,
                    artistQuickJumpMap: artistQuickJumpMap,
                    activeArtistQuickJumpKey: activeArtistQuickJumpKey,
                    locatedArtistName: _locatedArtistName,
                    locateArtistPulse: _locateArtistPulse,
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
                    selectedTrackId: mediaState.trackId,
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
                    onChangeArtistSort: _changeArtistSort,
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
                    onPlaySongs: _playShuffledSongIds,
                    onPlayTrack: _playTrackInQueue,
                    onPlaySong: _moveToMusicOrPlay,
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
            MultiSelectCommandBar(
              visible: _selection.multiSelect,
              bottomInset: multiSelectCommandBarShellBottomInset,
              selectedCount: selectedVisibleSongIds.length,
              playlists: customPlaylists,
              addToSongIds: selectedVisibleSongIds,
              nowPlayingSongIds: snapshot.nowPlaying.songIds,
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
                currentTrackId: mediaState.trackId,
                isPlaying: mediaState.isPlaying,
                queueSongIds: dialog.queueSongIds,
                onPlay:
                    ref.read(mediaControlControllerProvider).onTogglePlayPause,
                onPlayTrack: _playTrackInQueue,
                onReveal: (path) {
                  unawaited(revealItemInFolder(path));
                },
                onSaved: () {
                  notifyLyricsSaved(ref, dialog.song.id);
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
    final artistGroups = _readArtistGroups(snapshot, i18n);
    final suggestions = searchArtists(artistGroups, query);
    final exactMatches =
        artistGroups.where((artist) => artist.name == query).toList();
    final targetArtist =
        exactMatches.isNotEmpty
            ? exactMatches.first
            : (suggestions.isEmpty ? null : suggestions.first);
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .addRecentSearch(query, SearchHistoryType.artists)
          .then((_) {
            invalidateRecentSearchData(ref);
          }),
    );
    if (targetArtist != null) {
      setState(() {
        _artistSearch = targetArtist.name;
      });
      _openArtistDetail(targetArtist.name);
    }
  }

  void _updateArtistsPageState(VoidCallback update) {
    setState(update);
  }
}

enum _ArtistGroupMenuType { artist, album }
