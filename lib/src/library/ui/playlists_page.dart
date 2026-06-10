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

  Future<void> _createPlaylist(
    BuildContext context,
    SmPlayerI18n i18n,
    LibraryContentData snapshot, [
    List<int> songIds = const [],
  ]) async {
    final name = await _requestPlaylistName(
      context: context,
      i18n: i18n,
      title: i18n.t('playlists.createNew'),
      defaultName: getNextPlaylistName(
        i18n.t('common.playlist'),
        snapshot.playlists,
      ),
      confirmText: i18n.t('playlists.create'),
      playlists: snapshot.playlists,
      currentName: '',
    );
    if (name == null) {
      return;
    }

    final playlist = await ref
        .read(libraryRepositoryProvider)
        .createPlaylist(name, songIds);
    _addLocalPlaylist(playlist);
    if (context.mounted) {
      _persistLastPlaylist(playlist.id);
      context.go('/playlists/${playlist.id}');
    }
  }

  void _persistLastPlaylist(int playlistId) {
    if (_lastPersistedPlaylistId == playlistId) {
      return;
    }
    _lastPersistedPlaylistId = playlistId;
    unawaited(_saveLastPlaylist(playlistId));
  }

  Future<void> _saveLastPlaylist(int playlistId) async {
    await ref
        .read(libraryRepositoryProvider)
        .saveViewState(lastPlaylistId: playlistId);
  }

  Future<void> _renamePlaylist(
    BuildContext context,
    SmPlayerI18n i18n,
    LibraryContentData snapshot,
    LibraryPlaylist playlist,
  ) async {
    final name = await _requestPlaylistName(
      context: context,
      i18n: i18n,
      title: i18n.t('playlists.rename'),
      defaultName: playlist.name,
      confirmText: i18n.t('playlists.rename'),
      playlists: snapshot.playlists,
      currentName: playlist.name,
    );
    if (name != null && name != playlist.name) {
      _renamePlaylistWithoutReload(playlist, name);
    }
  }

  void _renamePlaylistWithoutReload(LibraryPlaylist playlist, String name) {
    _patchLocalPlaylist(_copyPlaylistWithName(playlist, name));
    unawaited(
      ref.read(libraryRepositoryProvider).renamePlaylist(playlist.id, name),
    );
  }

  Future<void> _addSongsToPlaylistWithoutReload(
    LibraryContentData snapshot,
    int playlistId,
    List<int> songIds,
  ) async {
    if (playlistId == snapshot.favoritePlaylistId) {
      await setSongsFavorite(ref, songIds, true);
      return;
    }
    await ref
        .read(libraryRepositoryProvider)
        .addSongsToPlaylist(playlistId, songIds);
    final playlist = snapshot.playlists.firstWhere(
      (playlist) => playlist.id == playlistId,
    );
    _patchLocalPlaylist(
      _copyPlaylistWithSongIds(
        playlist,
        _addUniqueSongIds(playlist.songIds, songIds),
      ),
    );
  }

  Future<void> _deletePlaylist(
    BuildContext context,
    SmPlayerI18n i18n,
    LibraryPlaylist playlist,
  ) async {
    final confirmed = await showSmPlayerConfirmDialog(
      context: context,
      i18n: i18n,
      title: i18n.t('playlists.delete'),
      message: i18n.t('headeredPlaylist.deleteConfirm', {
        'name': playlist.name,
      }),
      confirmText: i18n.t('playlists.delete'),
    );
    if (confirmed) {
      await ref.read(libraryRepositoryProvider).deletePlaylist(playlist.id);
      _removeLocalPlaylist(playlist.id);
    }
  }

  void _showPlaylistMenu(
    BuildContext context,
    SmPlayerI18n i18n,
    LibraryContentData snapshot,
    LibraryPlaylist playlist,
    Offset position,
  ) {
    showMenuFlyout(
      context,
      position: position,
      items: [
        MenuFlyoutItem(
          key: 'rename-playlist',
          text: i18n.t('playlists.rename'),
          icon: FluentIcons.edit_20_regular,
          onPressed: () {
            unawaited(_renamePlaylist(context, i18n, snapshot, playlist));
          },
        ),
        MenuFlyoutItem(
          key: 'duplicate-playlist',
          text: i18n.t('playlists.duplicate'),
          icon: FluentIcons.copy_20_regular,
          onPressed: () {
            unawaited(_duplicatePlaylist(snapshot, playlist));
          },
        ),
        MenuFlyoutItem(
          key: 'delete-playlist',
          text: i18n.t('playlists.delete'),
          icon: FluentIcons.delete_20_regular,
          onPressed: () {
            unawaited(_deletePlaylist(context, i18n, playlist));
          },
        ),
      ],
    );
  }

  Future<void> _duplicatePlaylist(
    LibraryContentData snapshot,
    LibraryPlaylist playlist,
  ) async {
    final duplicatedPlaylist = await ref
        .read(libraryRepositoryProvider)
        .createPlaylist(
          getNextPlaylistName(playlist.name, snapshot.playlists),
          playlist.songIds,
        );
    _addLocalPlaylist(duplicatedPlaylist);
  }

  void _previewPlaylistMoveToPoint(
    List<int> currentPlaylistIds,
    Offset pointerPosition,
  ) {
    _previewPlaylistMoveToDragRect(
      currentPlaylistIds,
      _playlistDragRectFor(pointerPosition),
    );
  }

  void _previewPlaylistMoveToDragRect(
    List<int> currentPlaylistIds,
    Rect dragRect,
  ) {
    final draggedPlaylistId = _draggingPlaylistId;
    if (draggedPlaylistId == null) {
      return;
    }

    final currentPreview = _previewPlaylistIds ?? currentPlaylistIds;
    final draggedIndex = currentPreview.indexOf(draggedPlaylistId);
    if (draggedIndex == -1) {
      return;
    }
    final targetSlots =
        currentPreview.indexed
            .where((entry) => entry.$2 != draggedPlaylistId)
            .map((entry) {
              final playlistId = entry.$2;
              final context = _playlistCardContexts[playlistId];
              final renderObject = context?.findRenderObject();
              if (renderObject is! RenderBox) {
                return null;
              }
              final topLeft = renderObject.localToGlobal(Offset.zero);
              return (
                playlistId: playlistId,
                rect: topLeft & renderObject.size,
              );
            })
            .whereType<({int playlistId, Rect rect})>()
            .toList();
    final nextIds =
        currentPreview
            .where((playlistId) => playlistId != draggedPlaylistId)
            .toList();
    final insertIndex = _playlistInsertIndexFromDragOverlap(
      nextIds: nextIds,
      targetSlots: targetSlots,
      dragRect: dragRect,
    );
    if (insertIndex == null) {
      return;
    }
    nextIds.insert(insertIndex, draggedPlaylistId);
    if (_idsEqual(currentPreview, nextIds)) {
      return;
    }

    setState(() {
      _previewPlaylistIds = nextIds;
    });
  }

  void _commitPlaylistPreview() {
    final nextPlaylistIds = _previewPlaylistIds;
    final startPlaylistIds = _dragStartPlaylistIds;
    if (nextPlaylistIds != null &&
        startPlaylistIds != null &&
        !_idsEqual(startPlaylistIds, nextPlaylistIds)) {
      _committedPlaylistIds = nextPlaylistIds;
      unawaited(
        ref.read(libraryRepositoryProvider).reorderPlaylists(nextPlaylistIds),
      );
    }
    _clearPlaylistDrag();
  }

  void _clearPlaylistDrag() {
    setState(() {
      _draggingPlaylistId = null;
      _previewPlaylistIds = null;
      _dragStartPlaylistIds = null;
      _playlistDragAccepted = false;
      _playlistDragAnchorOffset = null;
    });
  }

  List<int>? _committedPlaylistIdsFor(List<int> currentPlaylistIds) {
    final committedPlaylistIds = _committedPlaylistIds;
    if (committedPlaylistIds == null) {
      return null;
    }
    if (!_idsContainSameItems(committedPlaylistIds, currentPlaylistIds)) {
      _committedPlaylistIds = null;
      return null;
    }
    return committedPlaylistIds;
  }

  void _patchLocalPlaylist(LibraryPlaylist playlist) {
    setState(() {
      _deletedPlaylistIds.remove(playlist.id);
      _playlistOverrides[playlist.id] = playlist;
    });
  }

  void _addLocalPlaylist(LibraryPlaylist playlist) {
    _patchLocalPlaylist(playlist);
  }

  void _removeLocalPlaylist(int playlistId) {
    setState(() {
      _deletedPlaylistIds.add(playlistId);
      _playlistOverrides.remove(playlistId);
      _committedPlaylistIds =
          _committedPlaylistIds
              ?.where(
                (committedPlaylistId) => committedPlaylistId != playlistId,
              )
              .toList();
    });
  }

  void _patchNowPlaying(List<int> songIds) {
    final patchedSongIds = songIds.toList();
    setState(() {
      _nowPlayingSongIdsOverride = patchedSongIds;
    });
    ref.read(nowPlayingQueueOverrideProvider.notifier).state = patchedSongIds;
  }

  void _playTrack(
    LibraryContentData snapshot,
    SmPlayerI18n i18n,
    int trackId,
    List<int> queueSongIds,
  ) {
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final song = songsById[trackId]!;
    _patchNowPlaying(queueSongIds);
    unawaited(
      ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds),
    );
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          mediaControlTrackForSong(song, i18n),
          durationSeconds: song.duration.toDouble(),
          queueIndex: queueSongIds.indexOf(trackId),
        );
  }

  void _playNext(LibraryContentData snapshot, int songId) {
    final queueSongIds = snapshot.nowPlaying.songIds.toList();
    final currentTrackId =
        ref.read(mediaControlControllerProvider).state.track.id;
    final currentIndex =
        currentTrackId == null ? -1 : queueSongIds.indexOf(currentTrackId);
    queueSongIds.insert(currentIndex < 0 ? 0 : currentIndex + 1, songId);
    _patchNowPlaying(queueSongIds);
    unawaited(
      ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds),
    );
  }

  LibraryContentData _applyLocalSnapshotOverrides(LibraryContentData snapshot) {
    if (_playlistOverrides.isEmpty &&
        _deletedPlaylistIds.isEmpty &&
        _nowPlayingSongIdsOverride == null) {
      return snapshot;
    }
    var playlists =
        snapshot.playlists
            .where((playlist) => !_deletedPlaylistIds.contains(playlist.id))
            .map((playlist) => _playlistOverrides[playlist.id] ?? playlist)
            .toList();
    final playlistIds = playlists.map((playlist) => playlist.id).toSet();
    for (final playlist in _playlistOverrides.values) {
      if (playlistIds.contains(playlist.id) ||
          _deletedPlaylistIds.contains(playlist.id)) {
        continue;
      }
      playlists = _insertCustomPlaylistFirst(playlists, playlist);
      playlistIds.add(playlist.id);
    }
    return _copySnapshotWithPlaylists(
      snapshot,
      playlists,
      nowPlaying:
          _nowPlayingSongIdsOverride == null
              ? snapshot.nowPlaying
              : _copyNowPlayingWithSongIds(
                snapshot.nowPlaying,
                _nowPlayingSongIdsOverride!,
              ),
    );
  }

  Rect _playlistDragRectFor(Offset pointerPosition) {
    final anchor =
        _playlistDragAnchorOffset ??
        const Offset(_playlistCardWidth / 2, _playlistCardHeight / 2);
    return (pointerPosition - anchor) &
        const Size(_playlistCardWidth, _playlistCardHeight);
  }

  int? _playlistInsertIndexFromDragOverlap({
    required List<int> nextIds,
    required List<({int playlistId, Rect rect})> targetSlots,
    required Rect dragRect,
  }) {
    ({int playlistId, Rect rect, double ratio})? bestOverlap;
    for (final slot in targetSlots) {
      if (!dragRect.overlaps(slot.rect)) {
        continue;
      }
      final overlap = dragRect.intersect(slot.rect);
      final area = overlap.width * overlap.height;
      final ratio = area / (slot.rect.width * slot.rect.height);
      if (ratio < _playlistDragOverlapThreshold) {
        continue;
      }
      if (bestOverlap == null || ratio > bestOverlap.ratio) {
        bestOverlap = (
          playlistId: slot.playlistId,
          rect: slot.rect,
          ratio: ratio,
        );
      }
    }
    if (bestOverlap == null) {
      return null;
    }

    final nextIndex = nextIds.indexOf(bestOverlap.playlistId);
    if (nextIndex == -1) {
      return null;
    }
    final insertAfter =
        dragRect.center.dy >= bestOverlap.rect.top &&
                dragRect.center.dy <= bestOverlap.rect.bottom
            ? dragRect.center.dx > bestOverlap.rect.center.dx
            : dragRect.center.dy > bestOverlap.rect.center.dy;
    return insertAfter ? nextIndex + 1 : nextIndex;
  }
}

Future<String?> _requestPlaylistName({
  required BuildContext context,
  required SmPlayerI18n i18n,
  required String title,
  required String defaultName,
  required String confirmText,
  required List<LibraryPlaylist> playlists,
  required String currentName,
}) {
  return showSmPlayerInputDialog(
    context: context,
    i18n: i18n,
    title: title,
    defaultValue: defaultName,
    placeholder: i18n.t('playlists.namePlaceholder'),
    confirmText: confirmText,
    validate: (name) {
      return validatePlaylistName(name, playlists, currentName, i18n);
    },
  );
}

bool _idsEqual(List<int> left, List<int> right) {
  return left.length == right.length &&
      left.indexed.every((entry) => entry.$2 == right[entry.$1]);
}

bool _idsContainSameItems(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  final rightIds = right.toSet();
  return left.every(rightIds.contains);
}

List<int> _addUniqueSongIds(List<int> currentSongIds, List<int> songIds) {
  final nextSongIds = currentSongIds.toList();
  for (final songId in songIds) {
    if (!nextSongIds.contains(songId)) {
      nextSongIds.add(songId);
    }
  }
  return nextSongIds;
}

LibraryPlaylist _copyPlaylistWithName(LibraryPlaylist playlist, String name) {
  return LibraryPlaylist(
    id: playlist.id,
    name: name,
    priority: playlist.priority,
    songCount: playlist.songCount,
    songIds: playlist.songIds,
    sortCriterion: playlist.sortCriterion,
    isBuiltIn: playlist.isBuiltIn,
  );
}

LibraryPlaylist _copyPlaylistWithSongIds(
  LibraryPlaylist playlist,
  List<int> songIds, {
  PlaylistSortCriterion? sortCriterion,
}) {
  return LibraryPlaylist(
    id: playlist.id,
    name: playlist.name,
    priority: playlist.priority,
    songCount: songIds.length,
    songIds: songIds,
    sortCriterion: sortCriterion ?? playlist.sortCriterion,
    isBuiltIn: playlist.isBuiltIn,
  );
}

NowPlayingSnapshot _copyNowPlayingWithSongIds(
  NowPlayingSnapshot snapshot,
  List<int> songIds,
) {
  return NowPlayingSnapshot(playlistId: snapshot.playlistId, songIds: songIds);
}

List<LibraryPlaylist> _insertCustomPlaylistFirst(
  List<LibraryPlaylist> playlists,
  LibraryPlaylist playlist,
) {
  final index = playlists.indexWhere((item) => !item.isBuiltIn);
  final nextPlaylists = playlists.toList();
  nextPlaylists.insert(index == -1 ? nextPlaylists.length : index, playlist);
  return nextPlaylists;
}

LibraryContentData _copySnapshotWithPlaylists(
  LibraryContentData snapshot,
  List<LibraryPlaylist> playlists, {
  required NowPlayingSnapshot nowPlaying,
}) {
  return LibraryContentData(
    songs: snapshot.songs,
    recentSongs: snapshot.recentSongs,
    recentPlaylists: snapshot.recentPlaylists,
    recentAlbums: snapshot.recentAlbums,
    recentArtists: snapshot.recentArtists,
    recentSearches: snapshot.recentSearches,
    playlists: playlists,
    folders: snapshot.folders,
    favoritePlaylistId: snapshot.favoritePlaylistId,
    nowPlaying: nowPlaying,
    hasLibrary: snapshot.hasLibrary,
    sortCriterion: snapshot.sortCriterion,
    albumsSort: snapshot.albumsSort,
    showCount: snapshot.showCount,
    hideMultiSelectCommandBarAfterOperation:
        snapshot.hideMultiSelectCommandBarAfterOperation,
    localViewMode: snapshot.localViewMode,
    rootPath: snapshot.rootPath,
    databasePath: snapshot.databasePath,
  );
}

class _PlaylistDropPlaceholder extends StatelessWidget {
  const _PlaylistDropPlaceholder({required this.i18n});

  final SmPlayerI18n i18n;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor =
        night
            ? Color.lerp(
              _PlaylistsColors.accentStrong,
              const Color(0xfff5fbff),
              0.28,
            )!
            : _PlaylistsColors.accentStrong;
    final borderColor = _PlaylistsColors.accentStrong.withValues(
      alpha: night ? 0.74 : 0.76,
    );
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        key: const ValueKey('Playlists.DropPlaceholder'),
        width: _playlistCardWidth,
        height: _playlistCardHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: night ? const Color(0x0cffffff) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow:
                night
                    ? [
                      BoxShadow(
                        color: const Color(0x0effffff),
                        spreadRadius: -1,
                      ),
                    ]
                    : null,
          ),
          child: CustomPaint(
            painter: _PlaylistDropPlaceholderPainter(color: borderColor),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 30,
                    child: CustomPaint(
                      painter: _PlaylistDropPlusPainter(color: foregroundColor),
                    ),
                  ),
                  const SizedBox(height: 13),
                  SizedBox(
                    width: 92,
                    child: Text(
                      i18n.t('playlists.dropHere'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 16,
                        fontVariations: const [FontVariation.weight(650)],
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistDropPlusPainter extends CustomPainter {
  const _PlaylistDropPlusPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, (size.shortestSide - 2) / 2, strokePaint);

    const plusHalfLength = 7.0;
    canvas
      ..drawLine(
        center.translate(-plusHalfLength, 0),
        center.translate(plusHalfLength, 0),
        strokePaint,
      )
      ..drawLine(
        center.translate(0, -plusHalfLength),
        center.translate(0, plusHalfLength),
        strokePaint,
      );
  }

  @override
  bool shouldRepaint(covariant _PlaylistDropPlusPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PlaylistDropPlaceholderPainter extends CustomPainter {
  const _PlaylistDropPlaceholderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    final path =
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Offset.zero & size,
            const Radius.circular(12),
          ),
        );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 9.0;
      const gap = 6.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PlaylistDropPlaceholderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PlaylistsColors {
  const _PlaylistsColors._();

  static const accentStrong = Color(0xff0063b1);
  static const textMuted = Color(0xff607085);
}
