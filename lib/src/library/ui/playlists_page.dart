import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/input_dialog.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_floating_action_button.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_control.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_model.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/playlist_artwork.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';

const _playlistCardWidth = 180.0;
const _playlistCardHeight = 232.0;

class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({super.key, this.selectedPlaylistId});

  final int? selectedPlaylistId;

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  List<int>? _previewPlaylistIds;
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
      data: (snapshot) {
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
          _playTrack(ref, snapshot, i18n, trackId, queueSongIds);
        },
        onMoveToMusicOrPlay: (songId) {
          _playTrack(
            ref,
            snapshot,
            i18n,
            songId,
            songs.map((song) => song.id).toList(),
          );
        },
        onPlayNext: (songId) {
          _playNext(ref, snapshot, songId);
        },
        onTogglePlayPause:
            ref.read(mediaControlControllerProvider).onTogglePlayPause,
        onAddSongToPlaylist: (playlistId, songId) {
          unawaited(
            addSongsToPlaylistWithUndo(
              context: context,
              ref: ref,
              i18n: i18n,
              playlistId: playlistId,
              songIds: [songId],
            ),
          );
        },
        onAddSongsToPlaylist: (playlistId, songIds) {
          unawaited(
            addSongsToPlaylistWithUndo(
              context: context,
              ref: ref,
              i18n: i18n,
              playlistId: playlistId,
              songIds: songIds,
            ),
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
          ref.read(libraryRepositoryProvider).setSongFavorite(songId, false);
          ref.invalidate(libraryContentDataProvider);
        },
        onRemoveSongs: (songIds) async {
          await ref
              .read(libraryRepositoryProvider)
              .removeSongsFromPlaylist(selectedPlaylist.id, songIds);
          ref.invalidate(libraryContentDataProvider);
        },
        onRename: (name) {
          ref
              .read(libraryRepositoryProvider)
              .renamePlaylist(selectedPlaylist.id, name);
          ref.invalidate(libraryContentDataProvider);
        },
        onDelete: () {
          ref
              .read(libraryRepositoryProvider)
              .deletePlaylist(selectedPlaylist.id);
          ref.invalidate(libraryContentDataProvider);
          context.go('/playlists');
        },
        onClear: () {
          ref
              .read(libraryRepositoryProvider)
              .removeSongsFromPlaylist(
                selectedPlaylist.id,
                songs.map((song) => song.id).toList(),
              );
          ref.invalidate(libraryContentDataProvider);
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
          ref.invalidate(libraryContentDataProvider);
        },
        onRecordPlay: () {
          ref
              .read(libraryRepositoryProvider)
              .recordPlaylistPlayed(selectedPlaylist.id);
        },
        onSortSongs: (songIds, sortCriterion) {
          ref
              .read(libraryRepositoryProvider)
              .reorderPlaylistSongs(
                selectedPlaylist.id,
                songIds,
                sortCriterion,
              );
          ref.invalidate(libraryContentDataProvider);
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
    final orderedIds =
        _previewPlaylistIds ??
        customPlaylists.map((playlist) => playlist.id).toList();
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
                        return GridView.builder(
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
                            return Builder(
                              builder: (targetContext) {
                                _playlistCardContexts[playlist.id] =
                                    targetContext;
                                return DragTarget<int>(
                                  onWillAcceptWithDetails: (details) {
                                    return details.data != playlist.id;
                                  },
                                  onMove: (details) {
                                    _previewPlaylistMoveToPoint(
                                      customPlaylists
                                          .map((item) => item.id)
                                          .toList(),
                                      _playlistDragCardCenter(details.offset),
                                    );
                                  },
                                  onAcceptWithDetails: (_) {
                                    _playlistDragAccepted = true;
                                    _commitPlaylistPreview();
                                  },
                                  builder: (context, _, __) {
                                    if (_draggingPlaylistId == playlist.id) {
                                      return _PlaylistDropPlaceholder(
                                        i18n: i18n,
                                      );
                                    }

                                    return Draggable<int>(
                                      data: playlist.id,
                                      feedback: Material(
                                        color: Colors.transparent,
                                        child: SizedBox(
                                          width: _playlistCardWidth,
                                          height: _playlistCardHeight,
                                          child: _PlaylistCard(
                                            playlist: playlist,
                                            songs: playlistSongs,
                                            i18n: i18n,
                                            dragging: true,
                                            sorting: true,
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
                                              customPlaylists
                                                  .map((item) => item.id)
                                                  .toList();
                                          _dragStartPlaylistIds = playlistIds;
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
                                          customPlaylists
                                              .map((item) => item.id)
                                              .toList(),
                                          _playlistDragCardCenter(
                                            details.globalPosition,
                                          ),
                                        );
                                      },
                                      onDragEnd: (_) {
                                        if (_playlistDragAccepted) {
                                          return;
                                        }
                                        _commitPlaylistPreview();
                                      },
                                      child: Listener(
                                        onPointerDown: (event) {
                                          final renderObject =
                                              targetContext.findRenderObject()
                                                  as RenderBox;
                                          _playlistDragAnchorOffset =
                                              renderObject.globalToLocal(
                                                event.position,
                                              );
                                        },
                                        child: _PlaylistCard(
                                          playlist: playlist,
                                          songs: playlistSongs,
                                          i18n: i18n,
                                          dragging: false,
                                          sorting: _draggingPlaylistId != null,
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
                                                ref,
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
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
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
    ref.invalidate(libraryContentDataProvider);
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
      await ref
          .read(libraryRepositoryProvider)
          .renamePlaylist(playlist.id, name);
      ref.invalidate(libraryContentDataProvider);
    }
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
      ref.invalidate(libraryContentDataProvider);
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
    await ref
        .read(libraryRepositoryProvider)
        .createPlaylist(
          getNextPlaylistName(playlist.name, snapshot.playlists),
          playlist.songIds,
        );
    ref.invalidate(libraryContentDataProvider);
  }

  void _previewPlaylistMoveToPoint(
    List<int> currentPlaylistIds,
    Offset globalPosition,
  ) {
    final draggedPlaylistId = _draggingPlaylistId;
    if (draggedPlaylistId == null) {
      return;
    }

    final currentPreview = _previewPlaylistIds ?? currentPlaylistIds;
    final targetSlots =
        currentPreview.indexed
            .map((entry) {
              final visualIndex = entry.$1;
              final playlistId = entry.$2;
              final context = _playlistCardContexts[playlistId];
              final renderObject = context?.findRenderObject();
              if (renderObject is! RenderBox) {
                return null;
              }
              final topLeft = renderObject.localToGlobal(Offset.zero);
              return (
                playlistId: playlistId,
                visualIndex: visualIndex,
                rect: topLeft & renderObject.size,
              );
            })
            .whereType<({int playlistId, int visualIndex, Rect rect})>()
            .toList();
    if (targetSlots.isEmpty) {
      return;
    }
    final nearestSlot = targetSlots.reduce((left, right) {
      final leftDistance = (left.rect.center - globalPosition).distanceSquared;
      final rightDistance =
          (right.rect.center - globalPosition).distanceSquared;
      return leftDistance <= rightDistance ? left : right;
    });
    final nextIds =
        currentPreview
            .where((playlistId) => playlistId != draggedPlaylistId)
            .toList();
    nextIds.insert(
      nearestSlot.visualIndex.clamp(0, nextIds.length),
      draggedPlaylistId,
    );
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
      ref.read(libraryRepositoryProvider).reorderPlaylists(nextPlaylistIds);
      ref.invalidate(libraryContentDataProvider);
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

  Offset _playlistDragCardCenter(Offset pointerPosition) {
    final anchor =
        _playlistDragAnchorOffset ??
        const Offset(_playlistCardWidth / 2, _playlistCardHeight / 2);
    return pointerPosition -
        anchor +
        const Offset(_playlistCardWidth / 2, _playlistCardHeight / 2);
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

void _playTrack(
  WidgetRef ref,
  LibraryContentData snapshot,
  SmPlayerI18n i18n,
  int trackId,
  List<int> queueSongIds,
) {
  final songsById = {for (final song in snapshot.songs) song.id: song};
  final song = songsById[trackId]!;
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

void _playNext(WidgetRef ref, LibraryContentData snapshot, int songId) {
  final queueSongIds = snapshot.nowPlaying.songIds.toList();
  final currentTrackId =
      ref.read(mediaControlControllerProvider).state.track.id;
  final currentIndex =
      currentTrackId == null ? -1 : queueSongIds.indexOf(currentTrackId);
  queueSongIds.insert(currentIndex < 0 ? 0 : currentIndex + 1, songId);
  ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
  ref.invalidate(libraryContentDataProvider);
}

bool _idsEqual(List<int> left, List<int> right) {
  return left.length == right.length &&
      left.indexed.every((entry) => entry.$2 == right[entry.$1]);
}

class _PlaylistCard extends StatefulWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.songs,
    required this.i18n,
    required this.dragging,
    required this.sorting,
    required this.onOpen,
    required this.onPlay,
    required this.onContextMenu,
  });

  final LibraryPlaylist playlist;
  final List<LibrarySong> songs;
  final SmPlayerI18n i18n;
  final bool dragging;
  final bool sorting;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final ValueChanged<Offset> onContextMenu;

  @override
  State<_PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends State<_PlaylistCard> {
  var _hovered = false;

  @override
  void didUpdateWidget(_PlaylistCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sorting && _hovered) {
      _hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PlaylistCardColors.forBrightness(
      Theme.of(context).brightness,
    );
    final active = widget.dragging || (!widget.sorting && _hovered);
    final showHoverControls = _hovered && !widget.sorting;
    final showDragHandle = widget.dragging || (_hovered && !widget.sorting);
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
      child: Align(
        alignment: Alignment.topLeft,
        child: GestureDetector(
          onTap: widget.onOpen,
          onSecondaryTapDown: (details) {
            widget.onContextMenu(details.globalPosition);
          },
          child: AnimatedContainer(
            key: const ValueKey('Playlists.PlaylistCard'),
            duration: const Duration(milliseconds: 120),
            width: _playlistCardWidth,
            constraints: const BoxConstraints(minHeight: 232),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  widget.dragging
                      ? colors.dragSurface
                      : active
                      ? colors.hoverSurface
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow:
                  widget.dragging
                      ? [
                        BoxShadow(
                          color: colors.dragShadow,
                          blurRadius: 70,
                          offset: const Offset(0, 26),
                        ),
                      ]
                      : active
                      ? [
                        BoxShadow(
                          color: colors.hoverShadow,
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ]
                      : null,
            ),
            foregroundDecoration:
                widget.dragging
                    ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.dragBorder),
                    )
                    : active
                    ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.hoverBorder),
                    )
                    : null,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox.square(
                      dimension: 160,
                      child: DecoratedBox(
                        key: const ValueKey('Playlists.ArtworkSurface'),
                        decoration: BoxDecoration(
                          color: colors.artworkSurface,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: colors.artworkShadow,
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _PlaylistArtwork(songs: widget.songs),
                        ),
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
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.i18n.t('playlists.songCount', {
                        'count': widget.playlist.songCount,
                      }),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
                if (showHoverControls)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 56,
                    child: Center(
                      child: ArtworkFloatingActionButton(
                        tooltip: widget.i18n.t('context.play'),
                        size: 48,
                        icon: const SmPlayerPlayIcon(color: Colors.white),
                        onPressed: widget.songs.isEmpty ? null : widget.onPlay,
                      ),
                    ),
                  ),
                _PlaylistDragHandle(
                  visible: showDragHandle,
                  tooltip: widget.i18n.t('playlists.dragToSort'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistDragHandle extends StatelessWidget {
  const _PlaylistDragHandle({required this.visible, required this.tooltip});

  final bool visible;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      top: 2,
      right: 2,
      child:
          visible
              ? Tooltip(
                message: tooltip,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: AnimatedOpacity(
                    opacity: 1,
                    duration: const Duration(milliseconds: 120),
                    child: AnimatedSlide(
                      offset: Offset.zero,
                      duration: const Duration(milliseconds: 120),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x291e2a3a),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color:
                                    night
                                        ? const Color(0xc7181e26)
                                        : const Color(0xd1ffffff),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      night
                                          ? const Color(0x1fffffff)
                                          : const Color(0x9effffff),
                                ),
                              ),
                              child: SizedBox.square(
                                dimension: 32,
                                child: CustomPaint(
                                  painter: _PlaylistGripPainter(
                                    color:
                                        night
                                            ? const Color(0xf0f6f9fc)
                                            : const Color(0xc7313f54),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              : const SizedBox.shrink(),
    );
  }
}

class _PlaylistGripPainter extends CustomPainter {
  const _PlaylistGripPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    final iconLeft = (size.width - 18) / 2;
    final iconTop = (size.height - 18) / 2;
    const scale = 18 / 24;
    const xPositions = [8.0, 12.0, 16.0];
    const yPositions = [6.0, 12.0, 18.0];
    for (final y in yPositions) {
      for (final x in xPositions) {
        canvas.drawCircle(
          Offset(iconLeft + x * scale, iconTop + y * scale),
          1 * scale,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PlaylistGripPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PlaylistArtwork extends ConsumerStatefulWidget {
  const _PlaylistArtwork({required this.songs});

  final List<LibrarySong> songs;

  @override
  ConsumerState<_PlaylistArtwork> createState() => _PlaylistArtworkState();
}

class _PlaylistArtworkState extends ConsumerState<_PlaylistArtwork> {
  var _signature = '';
  List<String> _artworkUrls = const [];
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _refreshArtwork();
  }

  @override
  void didUpdateWidget(_PlaylistArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songs != widget.songs) {
      _refreshArtwork();
    }
  }

  @override
  Widget build(BuildContext context) {
    final artworkUrls = getPlaylistArtworkDisplayUrls(_artworkUrls);

    if (artworkUrls.isEmpty) {
      return const _PlaylistArtworkFallback();
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
        if (artworkUrls.length == 3) const _PlaylistArtworkFallback(),
      ],
    );
  }

  void _refreshArtwork() {
    final signature = getPlaylistArtworkSignature(widget.songs);
    if (signature == _signature) {
      return;
    }

    _signature = signature;
    final cachedArtworkUrls = getCachedPlaylistArtworkUrls(signature);
    if (cachedArtworkUrls != null) {
      _artworkUrls = cachedArtworkUrls;
      return;
    }

    _artworkUrls = const [];
    final generation = ++_generation;
    unawaited(
      resolvePlaylistArtworkUrls(
        widget.songs,
        ref.read(libraryRepositoryProvider),
      ).then((artworkUrls) {
        cachePlaylistArtworkUrls(signature, artworkUrls);
        if (!mounted || generation != _generation || signature != _signature) {
          return;
        }
        setState(() {
          _artworkUrls = artworkUrls;
        });
      }),
    );
  }
}

class _PlaylistArtworkFallback extends StatelessWidget {
  const _PlaylistArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return const DefaultAlbumArtwork();
  }
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

class _PlaylistCardColors {
  const _PlaylistCardColors._();

  static _PlaylistCardColorSet forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  static const light = _PlaylistCardColorSet(
    hoverSurface: Color(0x140078d7),
    hoverShadow: Color(0x1f1e2a3a),
    hoverBorder: Color(0x290078d7),
    dragSurface: Color(0xfafaFCff),
    dragShadow: Color(0x2435495f),
    dragBorder: Color(0xadffffff),
    artworkSurface: Color(0xb8ffffff),
    artworkShadow: Color(0x21202d3f),
    textStrong: Color(0xff1f252b),
    textMuted: Color(0xff5f625f),
  );

  static const dark = _PlaylistCardColorSet(
    hoverSurface: Color(0x240078d7),
    hoverShadow: Color(0x3d000000),
    hoverBorder: Color(0x380078d7),
    dragSurface: Color(0xfa161c24),
    dragShadow: Color(0x57000000),
    dragBorder: Color(0x1fD6e0ec),
    artworkSurface: Color(0x14ffffff),
    artworkShadow: Color(0x4d000000),
    textStrong: Color(0xf0f6f9fc),
    textMuted: Color(0xadcbd5e1),
  );
}

class _PlaylistCardColorSet {
  const _PlaylistCardColorSet({
    required this.hoverSurface,
    required this.hoverShadow,
    required this.hoverBorder,
    required this.dragSurface,
    required this.dragShadow,
    required this.dragBorder,
    required this.artworkSurface,
    required this.artworkShadow,
    required this.textStrong,
    required this.textMuted,
  });

  final Color hoverSurface;
  final Color hoverShadow;
  final Color hoverBorder;
  final Color dragSurface;
  final Color dragShadow;
  final Color dragBorder;
  final Color artworkSurface;
  final Color artworkShadow;
  final Color textStrong;
  final Color textMuted;
}
