import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/input_dialog.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
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
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';

part 'playlists_page_crud_actions.dart';
part 'playlists_page_drag_actions.dart';
part 'playlists_page_local_overrides.dart';
part 'playlists_page_playback_actions.dart';
part 'playlists_page_helpers.dart';
part 'playlist_drop_placeholder.dart';
part 'playlists_colors.dart';

const _playlistCardWidth = gridViewHolderWidth;
const _playlistCardHeight = gridViewHolderHeight;
const _playlistDragOverlapThreshold = 0.2;

class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({super.key, this.selectedPlaylistId});

  final int? selectedPlaylistId;

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  List<int>? _previewPlaylistIds;
  List<int>? _committedPlaylistIds;
  final _playlistOverrides = <int, LibraryPlaylist>{};
  final _deletedPlaylistIds = <int>{};
  List<int>? _nowPlayingSongIdsOverride;
  List<int>? _dragStartPlaylistIds;
  int? _draggingPlaylistId;
  var _playlistDragAccepted = false;
  Offset? _playlistDragAnchorOffset;
  final _playlistCardContexts = <int, BuildContext>{};
  int? _lastPersistedPlaylistId;
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
    required String title,
    required Widget content,
  }) {
    final signature = '$showPortal:$routePath:$title';
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
        content: content,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(libraryContentDataProvider);
    final favoriteOverrides = ref.watch(libraryFavoriteOverridesProvider);
    final songOverrides = ref.watch(librarySongOverridesProvider);
    final playlistOverrides = ref.watch(libraryPlaylistOverridesProvider);
    final deletedPlaylistIds = ref.watch(libraryDeletedPlaylistIdsProvider);

    if (i18nValue.isLoading || snapshotValue.isLoading) {
      return const SmPlayerLoadingState();
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const SizedBox.shrink();
    }

    return snapshotValue.when(
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
          ),
        );
        final selectedPlaylist =
            snapshot.playlists
                .where((playlist) => playlist.id == widget.selectedPlaylistId)
                .firstOrNull;
        if (widget.selectedPlaylistId != null && selectedPlaylist != null) {
          _persistLastPlaylist(selectedPlaylist.id);
          return _buildDetail(context, ref, i18n, snapshot, selectedPlaylist);
        }

        return _buildGrid(context, i18n, snapshot);
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
        routeLocation: '/playlists/${selectedPlaylist.id}',
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
          _playTrack(
            snapshot,
            i18n,
            songId,
            songs.map((song) => song.id).toList(),
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
          unawaited(setSongsFavorite(ref, [songId], false));
        },
        onRemoveSongs: (songIds) async {
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
        onRename: (name) {
          _renamePlaylistWithoutReload(selectedPlaylist, name);
        },
        onDelete: () async {
          await ref
              .read(libraryRepositoryProvider)
              .deletePlaylist(selectedPlaylist.id);
          _removeLocalPlaylist(selectedPlaylist.id);
          if (context.mounted) {
            context.go('/playlists');
          }
        },
        onClear: () async {
          await ref
              .read(libraryRepositoryProvider)
              .removeSongsFromPlaylist(
                selectedPlaylist.id,
                songs.map((song) => song.id).toList(),
              );
          _patchLocalPlaylist(
            _copyPlaylistWithSongIds(selectedPlaylist, const []),
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
          ref
              .read(libraryRepositoryProvider)
              .recordPlaylistPlayed(selectedPlaylist.id);
        },
        onSortSongs: (songIds, sortCriterion) {
          unawaited(
            ref
                .read(libraryRepositoryProvider)
                .reorderPlaylistSongs(
                  selectedPlaylist.id,
                  songIds,
                  sortCriterion,
                ),
          );
          _patchLocalPlaylist(
            _copyPlaylistWithSongIds(
              selectedPlaylist,
              songIds,
              sortCriterion: sortCriterion,
            ),
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

  Widget _buildGrid(
    BuildContext context,
    SmPlayerI18n i18n,
    LibraryContentData snapshot,
  ) {
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final customPlaylists =
        snapshot.playlists
            .where(
              (playlist) =>
                  !playlist.isBuiltIn &&
                  playlist.name != i18n.t('common.nowPlaying') &&
                  playlist.name != 'Now Playing',
            )
            .toList();
    final customPlaylistIds =
        customPlaylists.map((playlist) => playlist.id).toList();
    final orderedIds =
        _previewPlaylistIds ??
        _committedPlaylistIdsFor(customPlaylistIds) ??
        customPlaylistIds;
    final playlistById = {
      for (final playlist in customPlaylists) playlist.id: playlist,
    };
    final orderedPlaylists =
        orderedIds
            .map((playlistId) => playlistById[playlistId])
            .whereType<LibraryPlaylist>()
            .toList();
    final useWorkspaceAppBar = WorkspaceNavigationAppBarScope.of(context);
    final createButton = CommandBar(
      overflowLabel: i18n.t('player.more'),
      children: [
        CommandBarButton(
          icon: FluentIcons.add_20_regular,
          label: i18n.t('playlists.newName'),
          canOverflow: false,
          onPressed: () {
            unawaited(_createPlaylist(context, i18n, snapshot));
          },
        ),
      ],
    );
    final createAppBarButton = CommandBar(
      style: CommandBarStyleVariant.appBar,
      overflowLabel: i18n.t('player.more'),
      children: [
        CommandBarButton(
          key: const ValueKey('Playlists.AppBar.Create'),
          icon: FluentIcons.add_20_regular,
          label: i18n.t('playlists.newName'),
          showLabel: false,
          canOverflow: false,
          onPressed: () {
            unawaited(_createPlaylist(context, i18n, snapshot));
          },
        ),
      ],
    );
    _syncAppBarPortal(
      showPortal: true,
      routePath: '/playlists',
      title:
          snapshot.showCount
              ? i18n.t('search.playlistsWithCount', {
                'count':
                    snapshot.playlists
                        .where((playlist) => !playlist.isBuiltIn)
                        .length,
              })
              : i18n.t('common.playlists'),
      content: createAppBarButton,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          if (!useWorkspaceAppBar) ...[
            createButton,
            const SizedBox(height: 18),
          ],
          Expanded(
            child:
                orderedPlaylists.isEmpty
                    ? const SizedBox.shrink()
                    : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            constraints.maxWidth < 720
                                ? 2
                                : ((constraints.maxWidth + 30) / 210)
                                    .floor()
                                    .clamp(1, 8);
                        return Listener(
                          onPointerMove: (event) {
                            if (_draggingPlaylistId == null) {
                              return;
                            }
                            _previewPlaylistMoveToPoint(
                              customPlaylistIds,
                              event.position,
                            );
                          },
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 8, 8, 92),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisExtent: 250,
                                  crossAxisSpacing: 30,
                                  mainAxisSpacing: 26,
                                ),
                            itemCount: orderedPlaylists.length,
                            itemBuilder: (context, index) {
                              final playlist = orderedPlaylists[index];
                              final playlistSongs =
                                  playlist.songIds
                                      .map((songId) => songsById[songId])
                                      .whereType<LibrarySong>()
                                      .toList();
                              return KeyedSubtree(
                                key: ValueKey(
                                  'Playlists.PlaylistGridItem.${playlist.id}',
                                ),
                                child: Builder(
                                  builder: (targetContext) {
                                    _playlistCardContexts[playlist.id] =
                                        targetContext;
                                    return DragTarget<int>(
                                      onWillAcceptWithDetails: (details) {
                                        return details.data != playlist.id;
                                      },
                                      onMove: (details) {
                                        _previewPlaylistMoveToPoint(
                                          customPlaylistIds,
                                          details.offset,
                                        );
                                      },
                                      onAcceptWithDetails: (_) {
                                        _playlistDragAccepted = true;
                                        _commitPlaylistPreview();
                                      },
                                      builder: (context, _, __) {
                                        if (_draggingPlaylistId ==
                                            playlist.id) {
                                          return _PlaylistDropPlaceholder(
                                            i18n: i18n,
                                          );
                                        }

                                        return Draggable<int>(
                                          data: playlist.id,
                                          dragAnchorStrategy: (
                                            draggable,
                                            context,
                                            position,
                                          ) {
                                            final renderObject =
                                                context.findRenderObject()
                                                    as RenderBox;
                                            _playlistDragAnchorOffset =
                                                renderObject.globalToLocal(
                                                  position,
                                                );
                                            return _playlistDragAnchorOffset!;
                                          },
                                          feedback: Material(
                                            color: Colors.transparent,
                                            child: SizedBox(
                                              width: _playlistCardWidth,
                                              height: _playlistCardHeight,
                                              child: GridViewHolder(
                                                playlist: playlist,
                                                songs: playlistSongs,
                                                subtitle: i18n.t(
                                                  'playlists.songCount',
                                                  {'count': playlist.songCount},
                                                ),
                                                playTooltip: i18n.t(
                                                  'context.play',
                                                ),
                                                dragTooltip: i18n.t(
                                                  'playlists.dragToSort',
                                                ),
                                                cardKey: const ValueKey(
                                                  'Playlists.PlaylistCard',
                                                ),
                                                artworkKey: const ValueKey(
                                                  'Playlists.ArtworkSurface',
                                                ),
                                                dragging: true,
                                                sorting: true,
                                                selected: false,
                                                onOpen: () {},
                                                onPlay: () {},
                                                onContextMenu: (_) {},
                                              ),
                                            ),
                                          ),
                                          onDragStarted: () {
                                            setState(() {
                                              _draggingPlaylistId = playlist.id;
                                              _playlistDragAccepted = false;
                                              final playlistIds =
                                                  customPlaylistIds;
                                              _dragStartPlaylistIds =
                                                  playlistIds;
                                              _previewPlaylistIds = playlistIds;
                                            });
                                          },
                                          onDraggableCanceled: (_, __) {
                                            if (_playlistDragAccepted) {
                                              return;
                                            }
                                            _commitPlaylistPreview();
                                          },
                                          onDragUpdate: (details) {
                                            _previewPlaylistMoveToPoint(
                                              customPlaylistIds,
                                              details.globalPosition,
                                            );
                                          },
                                          onDragEnd: (details) {
                                            if (_playlistDragAccepted) {
                                              return;
                                            }
                                            _previewPlaylistMoveToPoint(
                                              customPlaylistIds,
                                              details.offset,
                                            );
                                            _commitPlaylistPreview();
                                          },
                                          child: GridViewHolder(
                                            playlist: playlist,
                                            songs: playlistSongs,
                                            subtitle: i18n.t(
                                              'playlists.songCount',
                                              {'count': playlist.songCount},
                                            ),
                                            playTooltip: i18n.t('context.play'),
                                            dragTooltip: i18n.t(
                                              'playlists.dragToSort',
                                            ),
                                            cardKey: const ValueKey(
                                              'Playlists.PlaylistCard',
                                            ),
                                            artworkKey: const ValueKey(
                                              'Playlists.ArtworkSurface',
                                            ),
                                            dragging: false,
                                            sorting:
                                                _draggingPlaylistId != null,
                                            selected: false,
                                            onOpen: () {
                                              _persistLastPlaylist(playlist.id);
                                              context.go(
                                                '/playlists/${playlist.id}',
                                              );
                                            },
                                            onPlay: () {
                                              if (playlistSongs.isNotEmpty) {
                                                ref
                                                    .read(
                                                      libraryRepositoryProvider,
                                                    )
                                                    .recordPlaylistPlayed(
                                                      playlist.id,
                                                    );
                                                _playTrack(
                                                  snapshot,
                                                  i18n,
                                                  playlistSongs.first.id,
                                                  playlistSongs
                                                      .map((song) => song.id)
                                                      .toList(),
                                                );
                                              }
                                            },
                                            onContextMenu: (position) {
                                              _showPlaylistMenu(
                                                context,
                                                i18n,
                                                snapshot,
                                                playlist,
                                                position,
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
