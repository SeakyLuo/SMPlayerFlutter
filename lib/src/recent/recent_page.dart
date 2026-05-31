import 'dart:async';

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
import 'package:smplayer_flutter/src/library/ui/artwork_floating_action_button.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_model.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';
import 'package:smplayer_flutter/src/playback/playing_wave.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';

import 'recent_page_model.dart';
import 'recent_scrollbar.dart';
import 'recent_search_list.dart';

part 'recent_added_page.dart';
part 'recent_played_page.dart';
part 'recent_searches_page.dart';
part 'recent_page_selection.dart';
part 'recent_page_playback.dart';
part 'recent_page_menus.dart';

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

  var _activeTab = RecentTab.added;
  var _activePlayedFilter = RecentPlayedFilter.songs;
  var _multiSelect = false;
  var _recentAddedTimelineLabel = '';
  var _recentPlayedTimelineLabel = '';
  final _selectedSongIds = <int>{};
  final _selectedCollectionKeys = <String>{};
  final _selectedSearchIds = <int>{};
  ({LibrarySong song, SongDialogMode mode})? _musicDialog;
  final _appBarPortalOwner = Object();
  String? _appBarPortalSignature;
  late final StateController<WorkspaceAppBarPortalEntry?> _appBarPortalNotifier;

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
                            onToggleSelection: _toggleSongSelection,
                            onOpenSongContextMenu: _showSongContextMenu,
                            onTimelineLabelChange: _setRecentAddedTimelineLabel,
                          ),
                        },
                      ),
                      if (_multiSelect)
                        MultiSelectCommandBar(
                          visible: _multiSelect,
                          selectedCount: selectedCount,
                          playlists: customPlaylists,
                          showAddTo: _activeTab != RecentTab.searches,
                          addToSongIds: selectedOperationSongIds,
                          includeNowPlayingInAddTo: true,
                          includeFavoritesInAddTo: hasNotFavoriteSongs(
                            selectedOperationSongIds,
                            {for (final song in snapshot.songs) song.id: song},
                          ),
                          removeLabel: i18n.t('context.removeFromList'),
                          onPlay: () {
                            if (_activeTab == RecentTab.searches) {
                              return;
                            }
                            _playSongIds(selectedOperationSongIds);
                            setState(() {
                              _hideAfterOperation(
                                snapshot
                                    .hideMultiSelectCommandBarAfterOperation,
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
                                snapshot
                                    .hideMultiSelectCommandBarAfterOperation,
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
                                snapshot
                                    .hideMultiSelectCommandBarAfterOperation,
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
                                  snapshot
                                      .hideMultiSelectCommandBarAfterOperation,
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
                                snapshot
                                    .hideMultiSelectCommandBarAfterOperation,
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
                                          .removeRecentPlayed(
                                            selectedVisibleSongIds,
                                          );
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
                    ],
                  ),
                  if (_musicDialog case final dialog?)
                    MusicDialog(
                      song: dialog.song,
                      initialMode: dialog.mode,
                      canPause:
                          dialog.song.id == mediaControlState.track.id &&
                          mediaControlState.isPlaying,
                      onPlay: () {
                        _playSong(dialog.song, [dialog.song.id], 0);
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

class _RecentTabs extends StatelessWidget {
  const _RecentTabs({
    required this.i18n,
    required this.activeTab,
    required this.addedCount,
    required this.playedCount,
    required this.searchesCount,
    required this.showCount,
    required this.onChanged,
  });

  final SmPlayerI18n i18n;
  final RecentTab activeTab;
  final int addedCount;
  final int playedCount;
  final int searchesCount;
  final bool showCount;
  final ValueChanged<RecentTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = RecentThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 18),
      child: SizedBox(
        width: double.infinity,
        height: colors.tabsHeight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: colors.tabsSpacing,
            children: [
              _RecentTabButton(
                active: activeTab == RecentTab.added,
                label: i18n.t('recent.added'),
                count: addedCount,
                showCount: showCount,
                onPressed: () => onChanged(RecentTab.added),
              ),
              _RecentTabButton(
                active: activeTab == RecentTab.played,
                label: i18n.t('recent.played'),
                count: playedCount,
                showCount: showCount,
                onPressed: () => onChanged(RecentTab.played),
              ),
              _RecentTabButton(
                active: activeTab == RecentTab.searches,
                label: i18n.t('recent.searches'),
                count: searchesCount,
                showCount: showCount,
                onPressed: () => onChanged(RecentTab.searches),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentAppBarTabs extends StatelessWidget {
  const _RecentAppBarTabs({
    required this.i18n,
    required this.activeTab,
    required this.addedCount,
    required this.playedCount,
    required this.searchesCount,
    required this.showCount,
    required this.onChanged,
  });

  final SmPlayerI18n i18n;
  final RecentTab activeTab;
  final int addedCount;
  final int playedCount;
  final int searchesCount;
  final bool showCount;
  final ValueChanged<RecentTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('Recent.AppBarTabs'),
      builder: (context, constraints) {
        final hideCount = constraints.maxWidth <= 520;
        return SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            children: [
              _RecentAppBarTabButton(
                active: activeTab == RecentTab.added,
                label: i18n.t('recent.added'),
                count: addedCount,
                showCount: showCount && !hideCount,
                onPressed: () => onChanged(RecentTab.added),
              ),
              _RecentAppBarTabButton(
                active: activeTab == RecentTab.played,
                label: i18n.t('recent.played'),
                count: playedCount,
                showCount: showCount && !hideCount,
                onPressed: () => onChanged(RecentTab.played),
              ),
              _RecentAppBarTabButton(
                active: activeTab == RecentTab.searches,
                label: i18n.t('recent.searches'),
                count: searchesCount,
                showCount: showCount && !hideCount,
                onPressed: () => onChanged(RecentTab.searches),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentTabContent extends StatelessWidget {
  const _RecentTabContent({
    required this.label,
    required this.count,
    required this.showCount,
    required this.labelStyle,
    required this.countStyle,
  });

  final String label;
  final int count;
  final bool showCount;
  final TextStyle labelStyle;
  final TextStyle countStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 7,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        if (showCount)
          Text(
            count.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: countStyle,
          ),
      ],
    );
  }
}

ButtonStyle _recentTextButtonStyle({
  required Color foregroundColor,
  required Color backgroundColor,
  required Color borderColor,
  required double minHeight,
  required EdgeInsets padding,
  required double radius,
}) {
  return TextButton.styleFrom(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    minimumSize: Size(0, minHeight),
    padding: padding,
    foregroundColor: foregroundColor,
    backgroundColor: backgroundColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor),
    ),
    shadowColor: Colors.transparent,
  ).copyWith(
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    side: WidgetStatePropertyAll(BorderSide(color: borderColor)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor),
      ),
    ),
  );
}

class _RecentAppBarTabButton extends StatelessWidget {
  const _RecentAppBarTabButton({
    required this.active,
    required this.label,
    required this.count,
    required this.showCount,
    required this.onPressed,
  });

  final bool active;
  final String label;
  final int count;
  final bool showCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = RecentThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton(
        style: _recentTextButtonStyle(
          foregroundColor:
              active ? colors.appBarTabActiveText : colors.appBarTabText,
          backgroundColor:
              active ? colors.appBarTabActiveSurface : colors.appBarTabSurface,
          borderColor:
              active ? colors.appBarTabActiveBorder : colors.appBarTabBorder,
          minHeight: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          radius: colors.appBarTabRadius,
        ),
        onPressed: onPressed,
        child: _RecentTabContent(
          label: label,
          count: count,
          showCount: showCount,
          labelStyle: const TextStyle(fontSize: 13),
          countStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RecentTabButton extends StatelessWidget {
  const _RecentTabButton({
    required this.active,
    required this.label,
    required this.count,
    required this.showCount,
    required this.onPressed,
  });

  final bool active;
  final String label;
  final int count;
  final bool showCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = RecentThemeColors.of(context);
    if (colors.primaryTabsUsePillStyle) {
      return TextButton(
        style: _recentTextButtonStyle(
          foregroundColor:
              active ? colors.primaryTabActiveText : colors.primaryTabText,
          backgroundColor:
              active
                  ? colors.primaryTabActiveSurface
                  : colors.primaryTabSurface,
          borderColor:
              active ? colors.primaryTabActiveBorder : colors.primaryTabBorder,
          minHeight: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          radius: colors.primaryTabRadius,
        ),
        onPressed: onPressed,
        child: _RecentTabContent(
          label: label,
          count: count,
          showCount: showCount,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          countStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return TextButton(
      style: _recentTextButtonStyle(
        foregroundColor:
            active ? colors.primaryTabActiveText : colors.primaryTabText,
        backgroundColor: Colors.transparent,
        borderColor: Colors.transparent,
        minHeight: 54,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        radius: 0,
      ),
      onPressed: onPressed,
      child: SizedBox(
        height: 54,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            _RecentTabContent(
              label: label,
              count: count,
              showCount: showCount,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              countStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Positioned(
              left: -8,
              right: -8,
              bottom: 5,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: active ? _RecentColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentPlayedFilterBar extends StatelessWidget {
  const _RecentPlayedFilterBar({
    required this.i18n,
    required this.activeFilter,
    required this.onChanged,
  });

  final SmPlayerI18n i18n;
  final RecentPlayedFilter activeFilter;
  final ValueChanged<RecentPlayedFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 2),
        children: [
          _FilterButton(
            active: activeFilter == RecentPlayedFilter.songs,
            icon: const Icon(FluentIcons.music_note_2_20_regular, size: 21),
            label: i18n.t('common.songs'),
            onPressed: () => onChanged(RecentPlayedFilter.songs),
          ),
          _FilterButton(
            active: activeFilter == RecentPlayedFilter.artists,
            icon: const Icon(FluentIcons.people_24_regular, size: 21),
            label: i18n.t('recent.artists'),
            onPressed: () => onChanged(RecentPlayedFilter.artists),
          ),
          _FilterButton(
            active: activeFilter == RecentPlayedFilter.albums,
            icon: const _RecentFilterAlbumIcon(),
            label: i18n.t('recent.albums'),
            onPressed: () => onChanged(RecentPlayedFilter.albums),
          ),
          _FilterButton(
            active: activeFilter == RecentPlayedFilter.playlists,
            icon: const _RecentFilterPlaylistIcon(),
            label: i18n.t('recent.playlists'),
            onPressed: () => onChanged(RecentPlayedFilter.playlists),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.active,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool active;
  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = RecentThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_recentPlayedFilterRadius),
          boxShadow: active ? colors.playedFilterActiveShadow : const [],
        ),
        child: TextButton.icon(
          style: _recentTextButtonStyle(
            foregroundColor:
                active
                    ? colors.playedFilterActiveText
                    : colors.playedFilterText,
            backgroundColor:
                active
                    ? colors.playedFilterActiveSurface
                    : colors.playedFilterSurface,
            borderColor:
                active
                    ? colors.playedFilterActiveBorder
                    : colors.playedFilterBorder,
            minHeight: 28,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            radius: _recentPlayedFilterRadius,
          ),
          icon: icon,
          label: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _RecentFilterAlbumIcon extends StatelessWidget {
  const _RecentFilterAlbumIcon();

  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color!;
    return IconTheme(
      data: IconTheme.of(context),
      child: SizedBox.square(
        dimension: 21,
        child: CustomPaint(painter: _RecentAlbumIconPainter(color)),
      ),
    );
  }
}

class _RecentFilterPlaylistIcon extends StatelessWidget {
  const _RecentFilterPlaylistIcon();

  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color!;
    return IconTheme(
      data: IconTheme.of(context),
      child: SizedBox.square(
        dimension: 21,
        child: CustomPaint(painter: _RecentPlaylistIconPainter(color)),
      ),
    );
  }
}

class _RecentAlbumIconPainter extends CustomPainter {
  const _RecentAlbumIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final center = Offset(size.width / 2, size.height / 2);
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.65 * scale;
    canvas.drawCircle(center, 8 * scale, paint);
    canvas.drawCircle(center, 3 * scale, paint);
    canvas.drawCircle(
      center,
      1 * scale,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RecentAlbumIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _RecentPlaylistIconPainter extends CustomPainter {
  const _RecentPlaylistIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.65 * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(
      Offset(4 * scale, 6 * scale),
      Offset(14 * scale, 6 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(4 * scale, 12 * scale),
      Offset(13 * scale, 12 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(4 * scale, 18 * scale),
      Offset(10 * scale, 18 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(17 * scale, 8 * scale),
      Offset(17 * scale, 17 * scale),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(17 * scale, 8 * scale)
        ..quadraticBezierTo(20.5 * scale, 9 * scale, 21 * scale, 6.5 * scale),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(15.4 * scale, 18.1 * scale),
        width: 5.1 * scale,
        height: 4.1 * scale,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RecentPlaylistIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _RecentPlayedPanel extends StatelessWidget {
  const _RecentPlayedPanel({
    required this.filter,
    required this.songs,
    required this.playlists,
    required this.albums,
    required this.artists,
    required this.multiSelect,
    required this.selectedSongIds,
    required this.selectedCollectionKeys,
    required this.mediaControlState,
    required this.onPlaySongs,
    required this.onPlaySong,
    required this.onToggleSongSelection,
    required this.onToggleCollectionSelection,
    required this.onOpenAlbum,
    required this.onOpenArtist,
    required this.onOpenPlaylist,
    required this.onRecordPlaylistPlayed,
    required this.onRecordAlbumPlayed,
    required this.onRecordArtistPlayed,
    required this.onTimelineLabelChange,
    required this.onOpenSongContextMenu,
    required this.onOpenAlbumAddMenu,
    required this.onOpenArtistContextMenu,
  });

  final RecentPlayedFilter filter;
  final List<RecentLibrarySong> songs;
  final List<RecentPlaylistView> playlists;
  final List<RecentAlbumView> albums;
  final List<RecentArtistView> artists;
  final bool multiSelect;
  final Set<int> selectedSongIds;
  final Set<String> selectedCollectionKeys;
  final MediaControlState mediaControlState;
  final ValueChanged<List<int>> onPlaySongs;
  final void Function(
    LibrarySong song,
    List<int> queueSongIds, [
    int? queueIndex,
  ])
  onPlaySong;
  final ValueChanged<int> onToggleSongSelection;
  final ValueChanged<String> onToggleCollectionSelection;
  final ValueChanged<String> onOpenAlbum;
  final ValueChanged<String> onOpenArtist;
  final ValueChanged<int> onOpenPlaylist;
  final ValueChanged<int> onRecordPlaylistPlayed;
  final ValueChanged<String> onRecordAlbumPlayed;
  final ValueChanged<String> onRecordArtistPlayed;
  final ValueChanged<String> onTimelineLabelChange;
  final void Function(Offset position, LibrarySong song, List<int> queueSongIds)
  onOpenSongContextMenu;
  final void Function(Offset position, RecentAlbumView album)
  onOpenAlbumAddMenu;
  final void Function(Offset position, RecentArtistView artist)
  onOpenArtistContextMenu;

  @override
  Widget build(BuildContext context) {
    return switch (filter) {
      RecentPlayedFilter.songs => _RecentSongGrid(
        songs: songs,
        queueSongIds: songs.map((song) => song.id).toList(),
        selectedSongIds: selectedSongIds,
        multiSelect: multiSelect,
        mediaControlState: mediaControlState,
        getTimelineDate: (song) => (song as RecentLibrarySong).playedAt,
        getDetailLabel:
            (song) =>
                formatRecentDateTime((song as RecentLibrarySong).playedAt),
        onPlaySong: onPlaySong,
        onToggleSelection: onToggleSongSelection,
        onOpenContextMenu: onOpenSongContextMenu,
        onTimelineLabelChange: onTimelineLabelChange,
      ),
      RecentPlayedFilter.playlists => _RecentPlaylistGrid(
        playlists: playlists,
        multiSelect: multiSelect,
        selectedKeys: selectedCollectionKeys,
        onOpen: onOpenPlaylist,
        onPlay: (playlist) {
          onRecordPlaylistPlayed(playlist.playlist.id);
          onPlaySongs(playlist.songs.map((song) => song.id).toList());
        },
        onToggleSelection: onToggleCollectionSelection,
        onTimelineLabelChange: onTimelineLabelChange,
      ),
      RecentPlayedFilter.albums => _RecentAlbumGrid(
        albums: albums,
        multiSelect: multiSelect,
        selectedKeys: selectedCollectionKeys,
        onOpen: onOpenAlbum,
        onPlay: (album) {
          onRecordAlbumPlayed(album.name);
          onPlaySongs(album.songIds);
        },
        onToggleSelection: onToggleCollectionSelection,
        onTimelineLabelChange: onTimelineLabelChange,
        onOpenContextMenu: (position, album) {
          onOpenAlbumAddMenu(position, album);
        },
      ),
      RecentPlayedFilter.artists => _RecentArtistList(
        artists: artists,
        multiSelect: multiSelect,
        selectedKeys: selectedCollectionKeys,
        onOpen: onOpenArtist,
        onPlay: (artist) {
          onRecordArtistPlayed(artist.name);
          onPlaySongs(artist.songs.map((song) => song.id).toList()..shuffle());
        },
        onToggleSelection: onToggleCollectionSelection,
        onTimelineLabelChange: onTimelineLabelChange,
        onOpenContextMenu: (position, artist) {
          onOpenArtistContextMenu(position, artist);
        },
      ),
    };
  }
}

class _RecentSongGrid extends StatelessWidget {
  const _RecentSongGrid({
    required this.songs,
    required this.queueSongIds,
    required this.selectedSongIds,
    required this.multiSelect,
    required this.mediaControlState,
    required this.getTimelineDate,
    required this.getDetailLabel,
    required this.onPlaySong,
    required this.onToggleSelection,
    required this.onOpenContextMenu,
    required this.onTimelineLabelChange,
  });

  final List<LibrarySong> songs;
  final List<int> queueSongIds;
  final Set<int> selectedSongIds;
  final bool multiSelect;
  final MediaControlState mediaControlState;
  final String Function(LibrarySong song) getTimelineDate;
  final String Function(LibrarySong song) getDetailLabel;
  final void Function(
    LibrarySong song,
    List<int> queueSongIds, [
    int? queueIndex,
  ])
  onPlaySong;
  final ValueChanged<int> onToggleSelection;
  final ValueChanged<String> onTimelineLabelChange;
  final void Function(Offset position, LibrarySong song, List<int> queueSongIds)
  onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return _RecentEmptyState(
        title: context.smPlayerI18n.t('recent.empty'),
        message: '',
      );
    }

    final groups = _groupRecentItems(
      songs,
      getTimelineDate,
      context.smPlayerI18n,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _RecentSongTileMetrics.forWidth(constraints.maxWidth);
        final columns = ((constraints.maxWidth + _recentSongTileColumnGap) /
                (_recentSongTileWidth + _recentSongTileColumnGap))
            .floor()
            .clamp(1, 8);
        return RecentScrollbar(
          builder:
              (controller) => _RecentTimelineScrollView(
                controller: controller,
                groups: groups,
                contentExtentForGroup:
                    (group) =>
                        ((group.items.length + columns - 1) ~/ columns) *
                        metrics.rowExtent,
                onTimelineLabelChange: onTimelineLabelChange,
                slivers: [
                  for (final group in groups) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                        child: Text(
                          group.label,
                          style: const TextStyle(
                            color: _RecentColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: metrics.rowExtent,
                        crossAxisSpacing: _recentSongTileColumnGap,
                        mainAxisSpacing: 0,
                      ),
                      itemCount: group.items.length,
                      itemBuilder: (context, index) {
                        final song = group.items[index];
                        return LayoutBuilder(
                          builder:
                              (context, constraints) => Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  child: _GridViewMusicItemControl(
                                    song: song,
                                    detailLabel: getDetailLabel(song),
                                    selected: selectedSongIds.contains(song.id),
                                    current:
                                        song.id == mediaControlState.track.id,
                                    playing:
                                        song.id == mediaControlState.track.id &&
                                        mediaControlState.isPlaying,
                                    multiSelect: multiSelect,
                                    metrics: metrics,
                                    onPlayTrack: () {
                                      onPlaySong(
                                        song,
                                        queueSongIds,
                                        queueSongIds.indexOf(song.id),
                                      );
                                    },
                                    onToggleSelection: () {
                                      onToggleSelection(song.id);
                                    },
                                    onOpenContextMenu: (position) {
                                      onOpenContextMenu(
                                        position,
                                        song,
                                        queueSongIds,
                                      );
                                    },
                                  ),
                                ),
                              ),
                        );
                      },
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 92)),
                ],
              ),
        );
      },
    );
  }
}

class _GridViewMusicItemControl extends StatefulWidget {
  const _GridViewMusicItemControl({
    required this.song,
    required this.detailLabel,
    required this.selected,
    required this.current,
    required this.playing,
    required this.multiSelect,
    required this.metrics,
    required this.onPlayTrack,
    required this.onToggleSelection,
    required this.onOpenContextMenu,
  });

  final LibrarySong song;
  final String detailLabel;
  final bool selected;
  final bool current;
  final bool playing;
  final bool multiSelect;
  final _RecentSongTileMetrics metrics;
  final VoidCallback onPlayTrack;
  final VoidCallback onToggleSelection;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  State<_GridViewMusicItemControl> createState() =>
      _GridViewMusicItemControlState();
}

class _GridViewMusicItemControlState extends State<_GridViewMusicItemControl> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = _RecentSongTileColors.of(context);
    final active = widget.selected || _hovered;
    final textColor = widget.current ? colors.currentText : colors.textStrong;
    final artistColor = widget.current ? colors.currentMuted : colors.textMuted;
    final detailColor = widget.current ? colors.currentSoft : colors.textSoft;
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onSecondaryTapDown: (details) {
          widget.onOpenContextMenu(details.globalPosition);
        },
        onTap:
            widget.multiSelect ? widget.onToggleSelection : widget.onPlayTrack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.ease,
          height: widget.metrics.tileExtent,
          padding: widget.metrics.padding,
          decoration: BoxDecoration(
            color: active ? colors.activeSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active ? colors.activeShadow : const [],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox.square(
                      dimension: widget.metrics.artworkSize,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.artworkSurface,
                          border: Border.all(color: colors.artworkBorder),
                          boxShadow: active ? colors.artworkShadow : const [],
                        ),
                        child: SongArtwork(
                          artworkPath: widget.song.thumbnailPath,
                        ),
                      ),
                    ),
                  ),
                  if (widget.multiSelect || widget.selected)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _RecentColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.selectionMarkBorder,
                            width: 2,
                          ),
                          boxShadow: colors.selectionMarkShadow,
                        ),
                        child: SizedBox.square(
                          dimension: 30,
                          child:
                              widget.selected
                                  ? const Icon(
                                    FluentIcons.checkmark_16_regular,
                                    color: Colors.white,
                                    size: 17,
                                  )
                                  : null,
                        ),
                      ),
                    )
                  else if (_hovered)
                    Positioned.fill(
                      child: Center(
                        child: ArtworkFloatingActionButton(
                          tooltip: context.smPlayerI18n.t('context.play'),
                          size: 48,
                          iconSize: 19,
                          icon:
                              widget.playing
                                  ? const SmPlayerPauseIcon(
                                    size: 19,
                                    color: Colors.white,
                                  )
                                  : const SmPlayerPlayIcon(
                                    size: 19,
                                    color: Colors.white,
                                  ),
                          onPressed: widget.onPlayTrack,
                        ),
                      ),
                    ),
                  if (widget.current && !_hovered && !widget.multiSelect)
                    Positioned.fill(
                      child: SmPlayerPlayingWaveGlass(
                        playing: widget.playing,
                        dimension: 48,
                        keyPrefix: 'RecentSong.Playing.${widget.song.id}',
                      ),
                    ),
                ],
              ),
              SizedBox(width: widget.metrics.copyGap),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.title,
                      maxLines: widget.detailLabel.isEmpty ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        height: 1.32,
                        fontVariations: const [FontVariation('wght', 650)],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      displayArtists(widget.song, context.smPlayerI18n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: artistColor, fontSize: 13),
                    ),
                    if (widget.detailLabel.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        widget.detailLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: detailColor,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentPlaylistGrid extends StatelessWidget {
  const _RecentPlaylistGrid({
    required this.playlists,
    required this.multiSelect,
    required this.selectedKeys,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSelection,
    required this.onTimelineLabelChange,
  });

  final List<RecentPlaylistView> playlists;
  final bool multiSelect;
  final Set<String> selectedKeys;
  final ValueChanged<int> onOpen;
  final ValueChanged<RecentPlaylistView> onPlay;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<String> onTimelineLabelChange;

  @override
  Widget build(BuildContext context) {
    return _RecentCollectionGrid<RecentPlaylistView>(
      items: playlists,
      playedAt: (playlist) => playlist.playedAt,
      onTimelineLabelChange: onTimelineLabelChange,
      itemBuilder: (context, playlist) {
        final key = 'playlists:${playlist.playlist.id}';
        return _CollectionCard(
          icon: FluentIcons.apps_list_detail_24_regular,
          title: playlist.playlist.name,
          subtitle: formatRecentDateTime(playlist.playedAt),
          selected: selectedKeys.contains(key),
          multiSelect: multiSelect,
          onOpen: () {
            if (multiSelect) {
              onToggleSelection(key);
            } else {
              onOpen(playlist.playlist.id);
            }
          },
          onPlay: () => onPlay(playlist),
        );
      },
    );
  }
}

class _RecentAlbumGrid extends StatelessWidget {
  const _RecentAlbumGrid({
    required this.albums,
    required this.multiSelect,
    required this.selectedKeys,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSelection,
    required this.onTimelineLabelChange,
    required this.onOpenContextMenu,
  });

  final List<RecentAlbumView> albums;
  final bool multiSelect;
  final Set<String> selectedKeys;
  final ValueChanged<String> onOpen;
  final ValueChanged<RecentAlbumView> onPlay;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<String> onTimelineLabelChange;
  final void Function(Offset position, RecentAlbumView album) onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    return _RecentCollectionGrid<RecentAlbumView>(
      items: albums,
      playedAt: (album) => album.playedAt,
      onTimelineLabelChange: onTimelineLabelChange,
      itemBuilder: (context, album) {
        final key = 'albums:${album.name}';
        final firstSong = album.songs.first;
        return _CollectionCard(
          icon: FluentIcons.album_24_regular,
          title: album.name,
          subtitle: formatRecentDateTime(album.playedAt),
          imagePath: firstSong.thumbnailPath,
          selected: selectedKeys.contains(key),
          multiSelect: multiSelect,
          onOpen: () {
            if (multiSelect) {
              onToggleSelection(key);
            } else {
              onOpen(album.name);
            }
          },
          onPlay: () => onPlay(album),
          onOpenContextMenu: (position) {
            onOpenContextMenu(position, album);
          },
        );
      },
    );
  }
}

class _RecentArtistList extends StatelessWidget {
  const _RecentArtistList({
    required this.artists,
    required this.multiSelect,
    required this.selectedKeys,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSelection,
    required this.onTimelineLabelChange,
    required this.onOpenContextMenu,
  });

  final List<RecentArtistView> artists;
  final bool multiSelect;
  final Set<String> selectedKeys;
  final ValueChanged<String> onOpen;
  final ValueChanged<RecentArtistView> onPlay;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<String> onTimelineLabelChange;
  final void Function(Offset position, RecentArtistView artist)
  onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return _RecentEmptyState(
        title: context.smPlayerI18n.t('recent.empty'),
        message: '',
      );
    }

    final groups = _groupRecentItems(
      artists,
      (artist) => artist.playedAt,
      context.smPlayerI18n,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _recentArtistColumnCount(constraints.maxWidth);
        return RecentScrollbar(
          builder:
              (controller) => _RecentTimelineScrollView(
                controller: controller,
                groups: groups,
                contentExtentForGroup: (group) {
                  final rows = (group.items.length + columns - 1) ~/ columns;
                  return rows * _recentArtistRowHeight +
                      (rows > 0 ? rows - 1 : 0) * _recentArtistRowGap;
                },
                onTimelineLabelChange: onTimelineLabelChange,
                slivers: [
                  for (final group in groups) ...[
                    _RecentTimeGroupHeader(label: group.label),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 14, 0),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: _recentArtistRowHeight,
                          crossAxisSpacing: _recentArtistColumnGap,
                          mainAxisSpacing: _recentArtistRowGap,
                        ),
                        itemCount: group.items.length,
                        itemBuilder: (context, index) {
                          final artist = group.items[index];
                          final key = 'artists:${artist.name}';
                          final firstSong = artist.songs.first;
                          return _ArtistRow(
                            artist: artist,
                            imagePath: firstSong.thumbnailPath,
                            selected: selectedKeys.contains(key),
                            multiSelect: multiSelect,
                            onOpen: () {
                              if (multiSelect) {
                                onToggleSelection(key);
                              } else {
                                onOpen(artist.name);
                              }
                            },
                            onPlay: () => onPlay(artist),
                            onOpenContextMenu: (position) {
                              onOpenContextMenu(position, artist);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 92)),
                ],
              ),
        );
      },
    );
  }
}

class _RecentCollectionGrid<T> extends StatelessWidget {
  const _RecentCollectionGrid({
    required this.items,
    required this.playedAt,
    required this.onTimelineLabelChange,
    required this.itemBuilder,
  });

  final List<T> items;
  final String Function(T item) playedAt;
  final ValueChanged<String> onTimelineLabelChange;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _RecentEmptyState(
        title: context.smPlayerI18n.t('recent.empty'),
        message: '',
      );
    }

    final groups = _groupRecentItems(items, playedAt, context.smPlayerI18n);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _recentCollectionColumnCount(constraints.maxWidth);
        return RecentScrollbar(
          builder:
              (controller) => _RecentTimelineScrollView(
                controller: controller,
                groups: groups,
                contentExtentForGroup:
                    (group) =>
                        ((group.items.length + columns - 1) ~/ columns) *
                            (_recentCollectionTileHeight +
                                _recentCollectionRowGap) +
                        22,
                onTimelineLabelChange: onTimelineLabelChange,
                slivers: [
                  for (final group in groups) ...[
                    _RecentTimeGroupHeader(label: group.label),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 14, 22),
                      sliver: SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: _recentCollectionTileWidth,
                              mainAxisExtent: _recentCollectionTileHeight,
                              crossAxisSpacing: _recentCollectionColumnGap,
                              mainAxisSpacing: _recentCollectionRowGap,
                            ),
                        itemCount: group.items.length,
                        itemBuilder:
                            (context, index) =>
                                itemBuilder(context, group.items[index]),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 70)),
                ],
              ),
        );
      },
    );
  }
}

class _RecentTimeGroupHeader extends StatelessWidget {
  const _RecentTimeGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 0, 10),
        child: Text(
          label,
          style: const TextStyle(
            color: _RecentColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CollectionCard extends StatefulWidget {
  const _CollectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.multiSelect,
    required this.onOpen,
    required this.onPlay,
    this.onOpenContextMenu,
    this.imagePath,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? imagePath;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final ValueChanged<Offset>? onOpenContextMenu;

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final imagePath = widget.imagePath;
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onSecondaryTapDown: (details) {
          widget.onOpenContextMenu?.call(details.globalPosition);
        },
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                widget.selected || _hovered
                    ? _RecentColors.accentSoft
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.square(
                      dimension: 156,
                      child: SongArtwork(
                        artworkPath: imagePath,
                        fallback: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: _RecentColors.artwork,
                          ),
                          child: Icon(
                            widget.icon,
                            color: _RecentColors.artworkIcon,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _RecentColors.textStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _RecentColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (_hovered && !widget.multiSelect)
                Positioned(
                  top: 100,
                  right: 8,
                  child: ArtworkFloatingActionButton(
                    tooltip: context.smPlayerI18n.t('context.play'),
                    size: 40,
                    iconSize: 17,
                    icon: const SmPlayerPlayIcon(size: 17, color: Colors.white),
                    onPressed: widget.onPlay,
                  ),
                ),
              if (widget.multiSelect || widget.selected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: _RecentColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 24,
                      child:
                          widget.selected
                              ? const Icon(
                                FluentIcons.checkmark_16_regular,
                                color: Colors.white,
                                size: 16,
                              )
                              : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistRow extends StatelessWidget {
  const _ArtistRow({
    required this.artist,
    required this.imagePath,
    required this.selected,
    required this.multiSelect,
    required this.onOpen,
    required this.onPlay,
    required this.onOpenContextMenu,
  });

  final RecentArtistView artist;
  final String imagePath;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onSecondaryTapDown: (details) {
          onOpenContextMenu(details.globalPosition);
        },
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? _RecentColors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox.square(
                  dimension: 52,
                  child: SongArtwork(artworkPath: imagePath),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _RecentColors.textStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatRecentDateTime(artist.playedAt),
                      style: const TextStyle(
                        color: _RecentColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (multiSelect)
                Icon(
                  selected
                      ? FluentIcons.checkmark_circle_20_filled
                      : FluentIcons.circle_20_regular,
                  color:
                      selected ? _RecentColors.accent : _RecentColors.textMuted,
                )
              else
                IconButton(
                  tooltip: context.smPlayerI18n.t('nowPlaying.randomPlay'),
                  icon: const SmPlayerPlayIcon(),
                  onPressed: onPlay,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentPagePanel extends StatelessWidget {
  const _RecentPagePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimal = constraints.maxWidth < _recentMinimalContentBreakpoint;
        return Padding(
          padding:
              minimal
                  ? const EdgeInsets.fromLTRB(8, 6, 8, 0)
                  : const EdgeInsets.fromLTRB(24, 24, 18, 0),
          child: SizedBox.expand(child: child),
        );
      },
    );
  }
}

class _RecentCommandBarTimelineLabel extends StatelessWidget {
  const _RecentCommandBarTimelineLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final minimal =
        MediaQuery.sizeOf(context).width < _recentMinimalContentBreakpoint;
    final color =
        Theme.of(context).brightness == Brightness.dark
            ? _RecentColors.nightText
            : _RecentColors.textStrong;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: SizedBox(
        height: minimal ? 24 : 29,
        child:
            label.isEmpty
                ? const SizedBox.shrink()
                : Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: minimal ? 18 : 22,
                    fontVariations: const [FontVariation('wght', 760)],
                  ),
                ),
      ),
    );
  }
}

class _RecentEmptyState extends StatelessWidget {
  const _RecentEmptyState({required String title, required String message});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _RecentTimelineScrollView<T> extends StatefulWidget {
  const _RecentTimelineScrollView({
    required this.controller,
    required this.groups,
    required this.contentExtentForGroup,
    required this.onTimelineLabelChange,
    required this.slivers,
  });

  final ScrollController controller;
  final List<_RecentTimeGroup<T>> groups;
  final double Function(_RecentTimeGroup<T> group) contentExtentForGroup;
  final ValueChanged<String> onTimelineLabelChange;
  final List<Widget> slivers;

  @override
  State<_RecentTimelineScrollView<T>> createState() =>
      _RecentTimelineScrollViewState<T>();
}

class _RecentTimelineScrollViewState<T>
    extends State<_RecentTimelineScrollView<T>> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncTimelineLabel();
      }
    });
  }

  @override
  void didUpdateWidget(_RecentTimelineScrollView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncTimelineLabel();
      }
    });
  }

  void _syncTimelineLabel() {
    final offset =
        widget.controller.hasClients ? widget.controller.position.pixels : 0.0;
    widget.onTimelineLabelChange(_timelineLabelForOffset(offset + 1));
  }

  String _timelineLabelForOffset(double offset) {
    var groupStart = 0.0;
    for (final group in widget.groups) {
      final headerEnd = groupStart + _recentTimeGroupHeaderExtent;
      final groupEnd = headerEnd + widget.contentExtentForGroup(group);
      if (offset < headerEnd) {
        return '';
      }
      if (offset < groupEnd) {
        return group.label;
      }
      groupStart = groupEnd;
    }
    return widget.groups.isEmpty ? '' : widget.groups.last.label;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical) {
          _syncTimelineLabel();
        }
        return false;
      },
      child: CustomScrollView(
        controller: widget.controller,
        slivers: widget.slivers,
      ),
    );
  }
}

class _RecentTimeGroup<T> {
  const _RecentTimeGroup({required this.label, required this.items});

  final String label;
  final List<T> items;
}

List<_RecentTimeGroup<T>> _groupRecentItems<T>(
  List<T> items,
  String Function(T item) getDateLabel,
  SmPlayerI18n i18n,
) {
  final groups = <_RecentTimeGroup<T>>[];
  for (final item in items) {
    final label = categorizeRecentDate(getDateLabel(item), i18n);
    final currentGroup = groups.isEmpty ? null : groups.last;
    if (currentGroup?.label == label) {
      currentGroup!.items.add(item);
    } else {
      groups.add(_RecentTimeGroup(label: label, items: [item]));
    }
  }
  return groups;
}

const _recentTimeGroupHeaderExtent = 36.0;

class _RecentSongTileMetrics {
  const _RecentSongTileMetrics({
    required this.rowExtent,
    required this.tileExtent,
    required this.artworkSize,
    required this.padding,
    required this.copyGap,
  });

  final double rowExtent;
  final double tileExtent;
  final double artworkSize;
  final EdgeInsets padding;
  final double copyGap;

  static _RecentSongTileMetrics forWidth(double width) {
    if (width <= 520) {
      return const _RecentSongTileMetrics(
        rowExtent: 104,
        tileExtent: 78,
        artworkSize: 72,
        padding: EdgeInsets.fromLTRB(2, 2, 8, 2),
        copyGap: 10,
      );
    }
    if (width < _recentMinimalContentBreakpoint) {
      return const _RecentSongTileMetrics(
        rowExtent: 104,
        tileExtent: 92,
        artworkSize: 84,
        padding: EdgeInsets.fromLTRB(2, 2, 6, 2),
        copyGap: 10,
      );
    }
    return const _RecentSongTileMetrics(
      rowExtent: 136,
      tileExtent: 116,
      artworkSize: 110,
      padding: EdgeInsets.fromLTRB(3, 3, 8, 3),
      copyGap: 12,
    );
  }
}

class _RecentSongTileColors {
  const _RecentSongTileColors({
    required this.activeSurface,
    required this.activeShadow,
    required this.artworkSurface,
    required this.artworkBorder,
    required this.artworkShadow,
    required this.artworkIcon,
    required this.selectionMarkBorder,
    required this.selectionMarkShadow,
    required this.textStrong,
    required this.textMuted,
    required this.textSoft,
    required this.currentText,
    required this.currentMuted,
    required this.currentSoft,
  });

  final Color activeSurface;
  final List<BoxShadow> activeShadow;
  final Color artworkSurface;
  final Color artworkBorder;
  final List<BoxShadow> artworkShadow;
  final Color artworkIcon;
  final Color selectionMarkBorder;
  final List<BoxShadow> selectionMarkShadow;
  final Color textStrong;
  final Color textMuted;
  final Color textSoft;
  final Color currentText;
  final Color currentMuted;
  final Color currentSoft;

  static const light = _RecentSongTileColors(
    activeSurface: Color(0x140078d7),
    activeShadow: [
      BoxShadow(color: Color(0x1a1d2a3c), blurRadius: 18, offset: Offset(0, 8)),
      BoxShadow(color: Color(0x290078d7), spreadRadius: 1),
    ],
    artworkSurface: Color(0xc2ffffff),
    artworkBorder: Color(0x2e748499),
    artworkShadow: [
      BoxShadow(color: Color(0x47202d3f), blurRadius: 10, offset: Offset(2, 2)),
    ],
    artworkIcon: Color(0xff0078d7),
    selectionMarkBorder: Color(0xebffffff),
    selectionMarkShadow: [
      BoxShadow(color: Color(0x471f56a8), blurRadius: 16, offset: Offset(0, 8)),
    ],
    textStrong: _RecentColors.textStrong,
    textMuted: _RecentColors.textMuted,
    textSoft: _RecentColors.textSoft,
    currentText: _RecentColors.accentStrong,
    currentMuted: Color(0xff226ba4),
    currentSoft: Color(0xff4f7fa7),
  );

  static const dark = _RecentSongTileColors(
    activeSurface: Color(0x240078d7),
    activeShadow: [
      BoxShadow(color: Color(0x38000000), blurRadius: 18, offset: Offset(0, 8)),
      BoxShadow(color: Color(0x3d0078d7), spreadRadius: 1),
    ],
    artworkSurface: Color(0x14ffffff),
    artworkBorder: _RecentColors.nightBorder,
    artworkShadow: [
      BoxShadow(color: Color(0x38000000), blurRadius: 10, offset: Offset(2, 2)),
    ],
    artworkIcon: _RecentColors.nightAccentText,
    selectionMarkBorder: Color(0xb8f6f9fc),
    selectionMarkShadow: [
      BoxShadow(color: Color(0x57000000), blurRadius: 18, offset: Offset(0, 8)),
    ],
    textStrong: _RecentColors.nightText,
    textMuted: _RecentColors.nightMuted,
    textSoft: _RecentColors.nightSubtle,
    currentText: _RecentColors.nightAccentText,
    currentMuted: Color(0xc2459de2),
    currentSoft: Color(0x9e459de2),
  );

  static _RecentSongTileColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

int _recentCollectionColumnCount(double width) {
  final available = (width - 22).clamp(0.0, double.infinity);
  return ((available + _recentCollectionColumnGap) /
          (_recentCollectionTileWidth + _recentCollectionColumnGap))
      .floor()
      .clamp(1, 8);
}

int _recentArtistColumnCount(double width) {
  final available = (width - 22).clamp(0.0, double.infinity);
  return ((available + _recentArtistColumnGap) /
          (_recentArtistMinColumnWidth + _recentArtistColumnGap))
      .floor()
      .clamp(1, 8);
}

class _RecentColors {
  const _RecentColors._();

  static const accent = Color(0xff0078d7);
  static const accentStrong = Color(0xff0063b1);
  static const accentSoft = Color(0x1f0078d7);
  static const textStrong = Color(0xff111827);
  static const textRootMuted = Color(0xff5f625f);
  static const textMuted = Color(0xff5b697a);
  static const textSoft = Color(0xff8290a1);
  static const appBarTabSurface = Color(0x80ffffff);
  static const appBarTabBorder = Color(0x24536379);
  static const appBarTabActiveBorder = Color(0x380078d7);
  static const playedFilterBorder = Color(0x1f536379);
  static const playedFilterActiveBorder = Color(0x6b0078d7);
  static const playedFilterActiveSurface = Color(0x240078d7);
  static const playedFilterActiveRing = SmPlayerInteractionColors.hoverSurface;
  static const artwork = Color(0xffe8eef5);
  static const artworkIcon = Color(0xff607085);
  static const nightText = Color(0xfff6f9fc);
  static const nightMuted = Color(0xadcbd5e1);
  static const nightSubtle = Color(0x75cbd5e1);
  static const nightBorder = Color(0x1fd6e0ec);
  static const nightAccentText = Color(0xff459de2);
  static const nightControlSurface = Color(0x0effffff);
  static const nightRecentTabSurface = Color(0x09ffffff);
  static const nightAppBarTabActiveSurface = Color(0x290078d7);
  static const nightAppBarTabActiveBorder = Color(0x570078d7);
  static const nightRecentTabActiveSurface = Color(0x3d0078d7);
  static const nightRecentTabActiveBorder = Color(0x7a0078d7);
  static const nightPlayedFilterActiveSurface = Color(0x2e0078d7);
  static const nightPlayedFilterActiveBorder = Color(0x610078d7);
}

class RecentThemeColors extends ThemeExtension<RecentThemeColors> {
  const RecentThemeColors({
    required this.tabsHeight,
    required this.tabsSpacing,
    required this.appBarTabText,
    required this.appBarTabActiveText,
    required this.appBarTabSurface,
    required this.appBarTabActiveSurface,
    required this.appBarTabBorder,
    required this.appBarTabActiveBorder,
    required this.appBarTabRadius,
    required this.primaryTabsUsePillStyle,
    required this.primaryTabText,
    required this.primaryTabActiveText,
    required this.primaryTabSurface,
    required this.primaryTabActiveSurface,
    required this.primaryTabBorder,
    required this.primaryTabActiveBorder,
    required this.primaryTabRadius,
    required this.playedFilterText,
    required this.playedFilterActiveText,
    required this.playedFilterSurface,
    required this.playedFilterActiveSurface,
    required this.playedFilterBorder,
    required this.playedFilterActiveBorder,
    required this.playedFilterActiveShadow,
  });

  final double tabsHeight;
  final double tabsSpacing;
  final Color appBarTabText;
  final Color appBarTabActiveText;
  final Color appBarTabSurface;
  final Color appBarTabActiveSurface;
  final Color appBarTabBorder;
  final Color appBarTabActiveBorder;
  final double appBarTabRadius;
  final bool primaryTabsUsePillStyle;
  final Color primaryTabText;
  final Color primaryTabActiveText;
  final Color primaryTabSurface;
  final Color primaryTabActiveSurface;
  final Color primaryTabBorder;
  final Color primaryTabActiveBorder;
  final double primaryTabRadius;
  final Color playedFilterText;
  final Color playedFilterActiveText;
  final Color playedFilterSurface;
  final Color playedFilterActiveSurface;
  final Color playedFilterBorder;
  final Color playedFilterActiveBorder;
  final List<BoxShadow> playedFilterActiveShadow;

  static const light = RecentThemeColors(
    tabsHeight: 54,
    tabsSpacing: 34,
    appBarTabText: _RecentColors.textStrong,
    appBarTabActiveText: _RecentColors.accentStrong,
    appBarTabSurface: _RecentColors.appBarTabSurface,
    appBarTabActiveSurface: _RecentColors.accentSoft,
    appBarTabBorder: _RecentColors.appBarTabBorder,
    appBarTabActiveBorder: _RecentColors.appBarTabActiveBorder,
    appBarTabRadius: 10,
    primaryTabsUsePillStyle: false,
    primaryTabText: _RecentColors.textRootMuted,
    primaryTabActiveText: _RecentColors.accent,
    primaryTabSurface: Colors.transparent,
    primaryTabActiveSurface: Colors.transparent,
    primaryTabBorder: Colors.transparent,
    primaryTabActiveBorder: Colors.transparent,
    primaryTabRadius: 0,
    playedFilterText: _RecentColors.textStrong,
    playedFilterActiveText: _RecentColors.accent,
    playedFilterSurface: _RecentColors.appBarTabSurface,
    playedFilterActiveSurface: _RecentColors.playedFilterActiveSurface,
    playedFilterBorder: _RecentColors.playedFilterBorder,
    playedFilterActiveBorder: _RecentColors.playedFilterActiveBorder,
    playedFilterActiveShadow: [
      BoxShadow(color: _RecentColors.playedFilterActiveRing, spreadRadius: 2),
    ],
  );

  static const dark = RecentThemeColors(
    tabsHeight: 46,
    tabsSpacing: 10,
    appBarTabText: _RecentColors.nightText,
    appBarTabActiveText: _RecentColors.nightAccentText,
    appBarTabSurface: _RecentColors.nightControlSurface,
    appBarTabActiveSurface: _RecentColors.nightAppBarTabActiveSurface,
    appBarTabBorder: _RecentColors.nightBorder,
    appBarTabActiveBorder: _RecentColors.nightAppBarTabActiveBorder,
    appBarTabRadius: 999,
    primaryTabsUsePillStyle: true,
    primaryTabText: _RecentColors.nightMuted,
    primaryTabActiveText: _RecentColors.nightAccentText,
    primaryTabSurface: _RecentColors.nightRecentTabSurface,
    primaryTabActiveSurface: _RecentColors.nightRecentTabActiveSurface,
    primaryTabBorder: _RecentColors.nightBorder,
    primaryTabActiveBorder: _RecentColors.nightRecentTabActiveBorder,
    primaryTabRadius: 999,
    playedFilterText: _RecentColors.nightText,
    playedFilterActiveText: _RecentColors.nightAccentText,
    playedFilterSurface: _RecentColors.nightControlSurface,
    playedFilterActiveSurface: _RecentColors.nightPlayedFilterActiveSurface,
    playedFilterBorder: _RecentColors.nightBorder,
    playedFilterActiveBorder: _RecentColors.nightPlayedFilterActiveBorder,
    playedFilterActiveShadow: [],
  );

  static RecentThemeColors of(BuildContext context) {
    return Theme.of(context).extension<RecentThemeColors>()!;
  }

  @override
  RecentThemeColors copyWith() {
    return this;
  }

  @override
  RecentThemeColors lerp(ThemeExtension<RecentThemeColors>? other, double t) {
    return t < 0.5 || other is! RecentThemeColors ? this : other;
  }
}

String _displayAlbum(LibrarySong song, SmPlayerI18n i18n) {
  return displayAlbum(song, i18n);
}
