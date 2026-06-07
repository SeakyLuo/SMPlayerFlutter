import 'dart:async';
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/album_tile.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_floating_action_button.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/grid_artwork_card_content.dart';
import 'package:smplayer_flutter/src/library/ui/grid_view_holder.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_model.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/selected_collection_card_style.dart';
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';
import 'package:smplayer_flutter/src/playback/playing_wave.dart';
import 'package:smplayer_flutter/src/platform/desktop_feature_service.dart';

import 'recent_page_model.dart';
import 'recent_scrollbar.dart';
import 'recent_search_list.dart';

part 'recent_added_page.dart';
part 'recent_played_page.dart';
part 'recent_searches_page.dart';
part 'recent_page_selection.dart';
part 'recent_page_playback.dart';
part 'recent_page_menus.dart';
part 'recent_tabs.dart';
part 'recent_app_bar_tabs.dart';
part 'recent_played_filter_bar.dart';
part 'recent_played_panel.dart';
part 'recent_song_grid.dart';
part 'grid_view_music_item_control.dart';
part 'recent_collection_grids.dart';
part 'recent_page_shell.dart';
part 'recent_timeline.dart';
part 'recent_theme.dart';

enum RecentTab { added, played, searches }

enum RecentPlayedFilter { songs, artists, albums, playlists }

const _recentMinimalContentBreakpoint = 656.0;
const _recentPlayedFilterRadius = 999.0;
const _recentCollectionTileWidth = 180.0;
const _recentCollectionTileHeight = 242.0;
const _recentCollectionColumnGap = 30.0;
const _recentCollectionRowGap = 26.0;
const _recentArtistMinColumnWidth = 260.0;
const _recentArtistColumnGap = 12.0;
const _recentArtistRowHeight = 72.0;
const _recentArtistRowGap = 2.0;
const _recentSongTileWidth = 270.0;
const _recentSongTileColumnGap = 28.0;

class RecentPage extends ConsumerStatefulWidget {
  const RecentPage({super.key});

  @override
  ConsumerState<RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends ConsumerState<RecentPage> {
  static const recentAddedLimit = 500;
  static const _activeTabStorageKey = 'RecentPage.activeTab';
  static const _activePlayedFilterStorageKey = 'RecentPage.activePlayedFilter';

  var _activeTab = RecentTab.added;
  var _activePlayedFilter = RecentPlayedFilter.songs;
  var _multiSelect = false;
  var _recentAddedTimelineLabel = '';
  var _recentPlayedTimelineLabel = '';
  final _selectedSongIds = <int>{};
  final _selectedCollectionKeys = <String>{};
  final _selectedSearchIds = <int>{};
  MusicDialogEntry? _musicDialog;
  final _appBarPortalOwner = Object();
  String? _appBarPortalSignature;
  late final StateController<WorkspaceAppBarPortalEntry?> _appBarPortalNotifier;
  var _pageStorageRestored = false;

  @override
  void initState() {
    super.initState();
    _appBarPortalNotifier = ref.read(workspaceAppBarPortalProvider.notifier);
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pageStorageRestored) {
      return;
    }
    _pageStorageRestored = true;
    final storedTab = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: _activeTabStorageKey);
    final storedFilter = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: _activePlayedFilterStorageKey);
    if (storedTab is RecentTab) {
      _activeTab = storedTab;
    }
    if (storedFilter is RecentPlayedFilter) {
      _activePlayedFilter = storedFilter;
    }
  }

  void _syncAppBarPortal({
    required bool showPortal,
    required String routePath,
    required SmPlayerI18n i18n,
    required String title,
    required int addedCount,
    required int playedCount,
    required int searchesCount,
    required bool showCount,
  }) {
    final signature =
        '$showPortal:$routePath:$title:$_activeTab:$addedCount:$playedCount:$searchesCount:$showCount';
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
        title: title,
        replacesTitle: true,
        content: _RecentAppBarTabs(
          i18n: i18n,
          activeTab: _activeTab,
          addedCount: addedCount,
          playedCount: playedCount,
          searchesCount: searchesCount,
          showCount: showCount,
          onChanged: _switchTab,
        ),
      );
    });
  }

  void _switchTab(RecentTab tab) {
    setState(() {
      _activeTab = tab;
      _clearSelection();
    });
    PageStorage.maybeOf(
      context,
    )?.writeState(context, tab, identifier: _activeTabStorageKey);
  }

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(recentPageDataProvider);
    final mediaControlState = ref.watch(mediaControlControllerProvider).state;

    if (i18nValue.isLoading) {
      return const _RecentPagePanel(child: SmPlayerLoadingState());
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const _RecentPagePanel(
        child: _RecentEmptyState(title: 'Recent failed to load', message: ''),
      );
    }

    return snapshotValue.when(
      loading: () => const _RecentPagePanel(child: SmPlayerLoadingState()),
      error:
          (_, _) => _RecentPagePanel(
            child: _RecentEmptyState(
              title: i18n.t('recent.empty'),
              message: '',
            ),
          ),
      data: (snapshot) {
        final recentAddedSongs =
            snapshot.songs.toList()..sort(
              (left, right) =>
                  dateValue(right.dateAdded) - dateValue(left.dateAdded),
            );
        final addedSongs = recentAddedSongs.take(recentAddedLimit).toList();
        final recentPlaylistViews = buildRecentPlaylistViews(
          snapshot.playlists,
          snapshot.songs,
          snapshot.recentPlaylists,
        );
        final recentAlbumViews = buildRecentAlbumViews(
          snapshot.songs,
          snapshot.recentAlbums,
          i18n,
        );
        final recentArtistViews = buildRecentArtistViews(
          snapshot.songs,
          snapshot.recentArtists,
          i18n,
        );
        final recentPlayedCount =
            snapshot.recentSongs.length +
            snapshot.recentPlaylists.length +
            snapshot.recentAlbums.length +
            snapshot.recentArtists.length;
        final visibleSongs =
            _activeTab == RecentTab.added
                ? addedSongs
                : _activeTab == RecentTab.played &&
                    _activePlayedFilter == RecentPlayedFilter.songs
                ? snapshot.recentSongs
                : const <LibrarySong>[];
        final selectedVisibleSongIds =
            visibleSongs
                .where((song) => _selectedSongIds.contains(song.id))
                .map((song) => song.id)
                .toList();
        final selectedSearchIds =
            snapshot.recentSearches
                .where((entry) => _selectedSearchIds.contains(entry.id))
                .map((entry) => entry.id)
                .toList();
        final selectedCount =
            _activeTab == RecentTab.searches
                ? selectedSearchIds.length
                : _activePlayedFilter == RecentPlayedFilter.songs
                ? selectedVisibleSongIds.length
                : _selectedCollectionKeys.length;
        final selectedOperationSongIds =
            _activeTab == RecentTab.played &&
                    _activePlayedFilter != RecentPlayedFilter.songs
                ? _selectedCollectionSongIds(
                  recentPlaylistViews,
                  recentAlbumViews,
                  recentArtistViews,
                )
                : selectedVisibleSongIds;
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
        return _RecentPagePanel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useAppBarTabs =
                  constraints.maxWidth < _recentMinimalContentBreakpoint;
              final useWorkspaceAppBar = WorkspaceNavigationAppBarScope.of(
                context,
              );
              _syncAppBarPortal(
                showPortal: useWorkspaceAppBar,
                routePath: '/recent',
                i18n: i18n,
                title: i18n.t('common.recent'),
                addedCount: addedSongs.length,
                playedCount: recentPlayedCount,
                searchesCount: snapshot.recentSearches.length,
                showCount: snapshot.showCount,
              );

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    spacing: 4,
                    children: [
                      if (useAppBarTabs && !useWorkspaceAppBar)
                        _RecentAppBarTabs(
                          i18n: i18n,
                          activeTab: _activeTab,
                          addedCount: addedSongs.length,
                          playedCount: recentPlayedCount,
                          searchesCount: snapshot.recentSearches.length,
                          showCount: snapshot.showCount,
                          onChanged: _switchTab,
                        )
                      else if (!useWorkspaceAppBar)
                        _RecentTabs(
                          i18n: i18n,
                          activeTab: _activeTab,
                          addedCount: addedSongs.length,
                          playedCount: recentPlayedCount,
                          searchesCount: snapshot.recentSearches.length,
                          showCount: snapshot.showCount,
                          onChanged: _switchTab,
                        ),
                      Expanded(
                        child: switch (_activeTab) {
                          RecentTab.searches => _RecentSearchesPage(
                            entries: snapshot.recentSearches,
                            i18n: i18n,
                            multiSelect: _multiSelect,
                            selectedEntryIds: _selectedSearchIds,
                            routeForSearchHistory: _routeForSearchHistory,
                            onToggleMultiSelect: () {
                              setState(() {
                                _multiSelect = !_multiSelect;
                                _clearSelection();
                              });
                            },
                            onClearSelection: () {
                              setState(_clearSelection);
                            },
                            onToggleSelection: _toggleSearchSelection,
                            onRemove: (entryId) {
                              unawaited(
                                _removeRecentSearchesWithUndo([entryId]),
                              );
                            },
                          ),
                          RecentTab.played => _RecentPlayedPage(
                            filter: _activePlayedFilter,
                            songs: snapshot.recentSongs,
                            playlists: recentPlaylistViews,
                            albums: recentAlbumViews,
                            artists: recentArtistViews,
                            i18n: i18n,
                            timelineLabel: _recentPlayedTimelineLabel,
                            playedCount: recentPlayedCount,
                            customPlaylists: customPlaylists,
                            multiSelect: _multiSelect,
                            selectedSongIds: _selectedSongIds,
                            selectedCollectionKeys: _selectedCollectionKeys,
                            mediaControlState: mediaControlState,
                            onFilterChanged: (filter) {
                              setState(() {
                                _activePlayedFilter = filter;
                                _clearSelection();
                              });
                              PageStorage.maybeOf(context)?.writeState(
                                context,
                                filter,
                                identifier: _activePlayedFilterStorageKey,
                              );
                            },
                            onToggleMultiSelect: () {
                              setState(() {
                                _multiSelect = !_multiSelect;
                                _clearSelection();
                              });
                            },
                            onClearSelection: () {
                              setState(_clearSelection);
                            },
                            onPlaySongs: _playSongIds,
                            onPlaySong: _playSong,
                            onPlayNext: _playNext,
                            onToggleSongSelection: _toggleSongSelection,
                            onToggleCollectionSelection:
                                _toggleCollectionSelection,
                            onRecordCollectionPlayed:
                                _recordRecentCollectionPlayed,
                            onOpenSongContextMenu: _showSongContextMenu,
                            onOpenCollectionAddToMenu: _showCollectionAddToMenu,
                            onOpenArtistContextMenu: _showArtistContextMenu,
                            onTimelineLabelChange:
                                _setRecentPlayedTimelineLabel,
                          ),
                          RecentTab.added => _RecentAddedPage(
                            songs: addedSongs,
                            i18n: i18n,
                            timelineLabel: _recentAddedTimelineLabel,
                            customPlaylists: customPlaylists,
                            selectedSongIds: _selectedSongIds,
                            multiSelect: _multiSelect,
                            mediaControlState: mediaControlState,
                            onToggleMultiSelect: () {
                              setState(() {
                                _multiSelect = !_multiSelect;
                                _clearSelection();
                              });
                            },
                            onPlaySong: _playSong,
                            onPlayNext: _playNext,
                            onToggleSelection: _toggleSongSelection,
                            onOpenSongAddToMenu: _showCollectionAddToMenu,
                            onOpenSongContextMenu: _showSongContextMenu,
                            onTimelineLabelChange: _setRecentAddedTimelineLabel,
                          ),
                        },
                      ),
                    ],
                  ),
                  MultiSelectCommandBar(
                    visible: _multiSelect,
                    bottomInset: multiSelectCommandBarShellBottomInset,
                    leftBleed: useAppBarTabs ? 8 : 24,
                    rightBleed: useAppBarTabs ? 8 : 18,
                    selectedCount: selectedCount,
                    playlists: customPlaylists,
                    showPlay: _activeTab != RecentTab.searches,
                    showAddTo: _activeTab != RecentTab.searches,
                    addToSongIds: selectedOperationSongIds,
                    includeNowPlayingInAddTo: true,
                    includeFavoritesInAddTo: hasNotFavoriteSongs(
                      selectedOperationSongIds,
                      {for (final song in snapshot.songs) song.id: song},
                    ),
                    removeLabel: i18n.t('context.removeFromList'),
                    onPlay: () {
                      _playSongIds(selectedOperationSongIds);
                      setState(() {
                        _hideAfterOperation(
                          snapshot.hideMultiSelectCommandBarAfterOperation,
                        );
                      });
                    },
                    onAddToNowPlaying: () {
                      addSongsToNowPlayingWithUndo(
                        context: context,
                        ref: ref,
                        i18n: i18n,
                        songIds: selectedOperationSongIds,
                      );
                      setState(() {
                        _hideAfterOperation(
                          snapshot.hideMultiSelectCommandBarAfterOperation,
                        );
                      });
                    },
                    onToggleFavorite: () {
                      final songsById = {
                        for (final song in snapshot.songs) song.id: song,
                      };
                      setSongsFavoriteWithUndo(
                        context: context,
                        ref: ref,
                        i18n: i18n,
                        songIds: notFavoriteSongIds(
                          selectedOperationSongIds,
                          songsById,
                        ),
                        favorite: true,
                      );
                      setState(() {
                        _hideAfterOperation(
                          snapshot.hideMultiSelectCommandBarAfterOperation,
                        );
                      });
                    },
                    onCreatePlaylist: () async {
                      await createPlaylistWithSongs(
                        context: context,
                        ref: ref,
                        i18n: i18n,
                        playlists: snapshot.playlists,
                        defaultName: _selectedPlaylistDefaultName(
                          i18n,
                          snapshot.playlists,
                          recentPlaylistViews,
                          recentAlbumViews,
                          recentArtistViews,
                        ),
                        songIds: selectedOperationSongIds,
                      );
                      if (mounted) {
                        setState(() {
                          _hideAfterOperation(
                            snapshot.hideMultiSelectCommandBarAfterOperation,
                          );
                        });
                      }
                    },
                    onAddToPlaylist: (playlistId) {
                      addSongsToPlaylistWithUndo(
                        context: context,
                        ref: ref,
                        i18n: i18n,
                        playlistId: playlistId,
                        songIds: selectedOperationSongIds,
                      );
                      setState(() {
                        _hideAfterOperation(
                          snapshot.hideMultiSelectCommandBarAfterOperation,
                        );
                      });
                    },
                    onRemove:
                        _activeTab == RecentTab.added ||
                                (_activeTab == RecentTab.played &&
                                    _activePlayedFilter !=
                                        RecentPlayedFilter.songs)
                            ? null
                            : () {
                              if (_activeTab == RecentTab.searches) {
                                unawaited(
                                  _removeRecentSearchesWithUndo(
                                    selectedSearchIds,
                                  ),
                                );
                              } else {
                                ref
                                    .read(libraryRepositoryProvider)
                                    .removeRecentPlayed(selectedVisibleSongIds);
                              }
                              ref.invalidate(recentPageDataProvider);
                              setState(() {
                                _hideAfterOperation(
                                  snapshot
                                      .hideMultiSelectCommandBarAfterOperation,
                                );
                              });
                            },
                    onSelectAll: () {
                      setState(() {
                        _selectAll(
                          snapshot,
                          visibleSongs,
                          recentPlaylistViews,
                          recentAlbumViews,
                          recentArtistViews,
                        );
                      });
                    },
                    onReverseSelection: () {
                      setState(() {
                        _reverseSelection(
                          snapshot,
                          visibleSongs,
                          recentPlaylistViews,
                          recentAlbumViews,
                          recentArtistViews,
                        );
                      });
                    },
                    onClearSelection: () {
                      setState(_clearSelection);
                    },
                    onCancel: () {
                      setState(() {
                        _multiSelect = false;
                        _clearSelection();
                      });
                    },
                  ),
                  if (_musicDialog case final dialog?)
                    MusicDialog(
                      song: dialog.song,
                      initialMode: dialog.mode,
                      currentTrackId: mediaControlState.track.id,
                      isPlaying: mediaControlState.isPlaying,
                      queueSongIds: dialog.queueSongIds,
                      onPlay:
                          ref
                              .read(mediaControlControllerProvider)
                              .onTogglePlayPause,
                      onPlayTrack: (trackId, queueSongIds) {
                        final songsById = {
                          for (final song
                              in ref.read(recentPageDataProvider).value!.songs)
                            song.id: song,
                        };
                        _playSong(
                          songsById[trackId]!,
                          queueSongIds,
                          queueSongIds.indexOf(trackId),
                        );
                      },
                      onReveal: (path) {
                        unawaited(revealItemInFolder(path));
                      },
                      onSaved: () {
                        ref.invalidate(recentPageDataProvider);
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
          ),
        );
      },
    );
  }
}
