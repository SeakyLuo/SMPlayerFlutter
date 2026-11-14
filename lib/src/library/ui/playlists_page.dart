import '../data/library_source.dart';
import 'package:smplayer_flutter/src/remote/music_source_selector.dart';
import 'package:smplayer_flutter/src/remote/music_share_models.dart';
import 'package:smplayer_flutter/src/remote/music_share_access.dart';
import '../../remote/music_source_providers.dart';
import 'dart:async';
import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/library/ui/local_page_shell.dart'
    show LocalPageEmptyArtwork;

import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/edge_auto_hide_scrollbar.dart';
import 'package:smplayer_flutter/src/app/input_dialog.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/grid_view_holder.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_control.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_model.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/page_search_history_panel.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart'
    as song_display;
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/playback_queue_actions.dart';

part 'playlists_page_crud_actions.dart';
part 'playlists_page_drag_actions.dart';
part 'playlists_page_local_overrides.dart';
part 'playlists_page_playback_actions.dart';
part 'playlists_page_search_actions.dart';
part 'playlists_page_toolbar.dart';
part 'playlists_app_bar_actions.dart';
part 'playlists_empty_state.dart';
part 'playlists_page_grid.dart';
part 'playlists_page_helpers.dart';
part 'playlist_drop_placeholder.dart';
part 'playlists_colors.dart';

const _playlistCardWidth = gridViewHolderWidth;
const _playlistCardHeight = gridViewHolderHeight;
const _playlistGridCrossAxisSpacing = 30.0;
const _playlistDragOverlapThreshold = 0.2;

class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({
    super.key,
    this.selectedPlaylistId,
    this.searchQuery = '',
  });

  final int? selectedPlaylistId;
  final String searchQuery;

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  late var _searchDraft = widget.searchQuery.trim();
  late var _searchQuery = widget.searchQuery.trim();
  var _searchFocused = false;
  var _appBarSearchOpen = false;
  List<int>? _previewPlaylistIds;
  List<int>? _committedPlaylistIds;
  List<int>? _dragStartPlaylistIds;
  int? _draggingPlaylistId;
  var _playlistDragAccepted = false;
  Offset? _playlistDragAnchorOffset;
  final _playlistCardContexts = <int, BuildContext>{};
  int? _lastPersistedPlaylistId;
  int? _recordedBrowsePlaylistId;
  final _appBarPortalOwner = Object();
  String? _appBarPortalSignature;
  late final StateController<WorkspaceAppBarPortalEntry?> _appBarPortalNotifier;

  void _updateState(VoidCallback callback) {
    setState(callback);
  }

  @override
  void initState() {
    super.initState();
    _appBarPortalNotifier = ref.read(workspaceAppBarPortalProvider.notifier);
  }

  void _recordBrowseAfterFrame(int playlistId) {
    if (_recordedBrowsePlaylistId == playlistId) {
      return;
    }
    _recordedBrowsePlaylistId = playlistId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _recordedBrowsePlaylistId != playlistId) {
        return;
      }
      unawaited(_recordBrowse(playlistId));
    });
  }

  Future<void> _recordBrowse(int playlistId) async {
    final recentBrowses = ref.read(recentBrowsesProvider.notifier);
    final entry = await ref
        .read(libraryRepositoryProvider)
        .recordRecentBrowse(RecentBrowseType.playlist, '$playlistId');
    await recentBrowses.record(entry);
  }

  @override
  void didUpdateWidget(covariant PlaylistsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      final query = widget.searchQuery.trim();
      _searchDraft = query;
      _searchQuery = query;
    }
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
    required String title,
    required SmPlayerI18n i18n,
    required List<String> searchSuggestions,
    required List<SearchHistoryEntry> searchHistoryEntries,
    required VoidCallback? onCreatePlaylist,
  }) {
    final signature =
        '$showPortal:$routePath:$title:$_appBarSearchOpen:$_searchDraft:$_searchQuery:$_searchFocused:${searchSuggestions.length}:${searchHistoryEntries.length}';
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
        content: _PlaylistsAppBarActions(
          searchOpen: _appBarSearchOpen,
          searchDraft: _searchDraft,
          searchHasText: _searchDraft.isNotEmpty || _searchQuery.isNotEmpty,
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
          onCreatePlaylist: onCreatePlaylist,
        ),
        replacesTitle: _appBarSearchOpen,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(browsingLibraryContentDataProvider);
    final favoriteOverrides = ref.watch(libraryFavoriteOverridesProvider);
    final songOverrides = ref.watch(librarySongOverridesProvider);
    final playlistOverrides = ref.watch(libraryPlaylistOverridesProvider);
    final deletedPlaylistIds = ref.watch(libraryDeletedPlaylistIdsProvider);
    final playlistOrder = ref.watch(libraryPlaylistOrderProvider);
    final nowPlayingSongIdsOverride = ref.watch(
      nowPlayingQueueOverrideProvider,
    );

    if ((i18nValue.isLoading && !i18nValue.hasValue) ||
        (snapshotValue.isLoading && !snapshotValue.hasValue)) {
      return const SmPlayerLoadingState();
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const SizedBox.shrink();
    }

    return snapshotValue.when(
      skipLoadingOnReload: true,
      loading: () => const SmPlayerLoadingState(),
      error:
          (_, _) => Center(
            child: Text(
              i18n.t('playlists.none'),
              style: const TextStyle(color: _PlaylistsColors.textMuted),
            ),
          ),
      data: (rawSnapshot) {
        final snapshot = _applyLocalSnapshotOverrides(
          applyLibraryFavoriteOverrides(
            rawSnapshot,
            favoriteOverrides,
            songOverrides,
            playlistOverrides,
            deletedPlaylistIds,
            playlistOrder,
          ),
          nowPlayingSongIdsOverride,
        );
        final selectedPlaylist =
            snapshot.playlists
                .where((playlist) => playlist.id == widget.selectedPlaylistId)
                .firstOrNull;
        if (widget.selectedPlaylistId != null && selectedPlaylist != null) {
          _persistLastPlaylist(selectedPlaylist.id);
          _recordBrowseAfterFrame(selectedPlaylist.id);
          return _buildDetail(context, ref, i18n, snapshot, selectedPlaylist);
        }

        return _buildGrid(context, i18n, snapshot, playlistOrder);
      },
    );
  }

  Widget _buildDetail(
    BuildContext context,
    WidgetRef ref,
    SmPlayerI18n i18n,
    LibraryContentData snapshot,
    LibraryPlaylist selectedPlaylist,
  ) {
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final songs =
        selectedPlaylist.songIds
            .map((songId) => songsById[songId])
            .whereType<LibrarySong>()
            .toList();
    final mediaControl = ref.watch(
      mediaControlControllerProvider.select(
        (controller) => (
          trackId: controller.state.track.id,
          isPlaying: controller.state.isPlaying,
        ),
      ),
    );
    final artworkUrl =
        songs
            .where((song) => song.thumbnailPath.isNotEmpty)
            .map((song) => song.thumbnailPath)
            .firstOrNull ??
        '';

    return SmPlayerI18nScope(
      i18n: i18n,
      child: HeaderedPlaylistControl(
        key: ValueKey('HeaderedPlaylist.Playlist.${selectedPlaylist.id}'),
        playlistId: selectedPlaylist.id,
        routeLocation: GoRouterState.of(context).uri.toString(),
        type:
            selectedPlaylist.isBuiltIn
                ? HeaderedPlaylistType.favorites
                : HeaderedPlaylistType.playlist,
        title: selectedPlaylist.name,
        headerSongs: songs,
        songs: songs,
        selectedTrackId: mediaControl.trackId,
        isPlaying: mediaControl.isPlaying,
        playlists: snapshot.playlists,
        favoritePlaylistId: snapshot.favoritePlaylistId,
        artworkUrl: artworkUrl,
        removable: true,
        showAlbum: true,
        canRename: !selectedPlaylist.isBuiltIn,
        canDelete: !selectedPlaylist.isBuiltIn,
        canClear: songs.isNotEmpty,
        canSetPreferred: true,
        sortCriterion: selectedPlaylist.sortCriterion,
        preferenceType:
            selectedPlaylist.isBuiltIn ? 'my-favorites' : 'playlist',
        preferenceItemId:
            selectedPlaylist.isBuiltIn ? '6' : selectedPlaylist.id.toString(),
        onPlayTrack: (trackId, queueSongIds) {
          _playTrack(snapshot, i18n, trackId, queueSongIds);
        },
        onMoveToMusicOrPlay: (songId) {
          insertOrPlayNowPlayingSong(
            ref: ref,
            snapshot: snapshot,
            i18n: i18n,
            songId: songId,
          );
        },
        onPlayNext: (songId) {
          _playNext(snapshot, songId);
        },
        onTogglePlayPause:
            ref.read(mediaControlControllerProvider).onTogglePlayPause,
        onAddSongToPlaylist: (playlistId, songId) {
          unawaited(
            _addSongsToPlaylistWithoutReload(snapshot, playlistId, [songId]),
          );
        },
        onAddSongsToPlaylist: (playlistId, songIds) {
          unawaited(
            _addSongsToPlaylistWithoutReload(snapshot, playlistId, songIds),
          );
        },
        onToggleFavorite: (songId, favorite) {
          if (favorite) {
            unawaited(
              setSongsFavoriteWithUndo(
                context: context,
                ref: ref,
                i18n: i18n,
                songIds: [songId],
                favorite: true,
              ),
            );
            return;
          }
          unawaited(setSongsFavoriteFromControl(ref, [songId], false));
        },
        onRemoveSongs:
            !canEditPlaylist(selectedPlaylist)
                ? null
                : (songIds) async {
                  await ref
                      .read(libraryRepositoryProvider)
                      .removeSongsFromPlaylist(selectedPlaylist.id, songIds);
                  _patchLocalPlaylist(
                    _copyPlaylistWithSongIds(
                      selectedPlaylist,
                      selectedPlaylist.songIds
                          .where((songId) => !songIds.contains(songId))
                          .toList(),
                    ),
                  );
                },
        onRename:
            !canEditPlaylist(selectedPlaylist)
                ? null
                : (name) {
                  _renamePlaylistWithoutReload(selectedPlaylist, name);
                },
        onDelete:
            !canEditPlaylist(selectedPlaylist)
                ? null
                : () async {
                  final deleted = await _deletePlaylistWithUndo(
                    context,
                    i18n,
                    selectedPlaylist,
                  );
                  if (deleted && context.mounted) {
                    context.go('/playlists');
                  }
                },
        onClear:
            !canEditPlaylist(selectedPlaylist)
                ? null
                : () async {
                  await ref
                      .read(libraryRepositoryProvider)
                      .removeSongsFromPlaylist(
                        selectedPlaylist.id,
                        songs.map((song) => song.id).toList(),
                      );
                  _patchLocalPlaylist(
                    _copyPlaylistWithSongIds(
                      selectedPlaylist,
                      selectedPlaylist.songIds
                          .where((id) => !songs.any((song) => song.id == id))
                          .toList(),
                    ),
                  );
                },
        onSetPreferred: (level) async {
          await ref
              .read(libraryRepositoryProvider)
              .addPreferenceItem(
                selectedPlaylist.isBuiltIn ? 'my-favorites' : 'playlist',
                selectedPlaylist.isBuiltIn
                    ? '6'
                    : selectedPlaylist.id.toString(),
                selectedPlaylist.isBuiltIn
                    ? i18n.t('common.myFavorites')
                    : selectedPlaylist.name,
                level,
              );
        },
        onRecordPlay: () {
          unawaited(recordRecentPlaylistPlayback(ref, selectedPlaylist.id));
        },
        onSortSongs:
            !canEditPlaylist(selectedPlaylist)
                ? null
                : (songIds, sortCriterion) {
                  songIds = mergeVisiblePlaylistOrder(
                    selectedPlaylist.songIds,
                    songIds,
                  );
                  unawaited(
                    runMusicShareAction(context, () async {
                      await ref
                          .read(libraryRepositoryProvider)
                          .reorderPlaylistSongs(
                            selectedPlaylist.id,
                            songIds,
                            sortCriterion,
                          );
                      if (!mounted) return;
                      _patchLocalPlaylist(
                        _copyPlaylistWithSongIds(
                          selectedPlaylist,
                          songIds,
                          sortCriterion: sortCriterion,
                        ),
                      );
                    }),
                  );
                },
        onArtistClick: (artist) {
          context.go('/artists?artist=${Uri.encodeQueryComponent(artist)}');
        },
        onAlbumClick: (album) {
          context.go('/albums?album=${Uri.encodeQueryComponent(album)}');
        },
      ),
    );
  }
}
