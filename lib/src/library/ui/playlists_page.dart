import 'dart:async';
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/input_dialog.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_control.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_model.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';

class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({super.key, this.selectedPlaylistId});

  final int? selectedPlaylistId;

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  List<int>? _previewPlaylistIds;
  int? _draggingPlaylistId;
  int? _lastPersistedPlaylistId;

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(musicLibrarySnapshotProvider);

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
    MusicLibrarySnapshot snapshot,
    LibraryPlaylist selectedPlaylist,
  ) {
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final songs =
        selectedPlaylist.songIds
            .map((songId) => songsById[songId])
            .whereType<LibrarySong>()
            .toList();
    final mediaControl = ref.watch(mediaControlControllerProvider).state;
    final artworkUrl =
        songs
            .where((song) => song.thumbnailPath.isNotEmpty)
            .map((song) => song.thumbnailPath)
            .firstOrNull ??
        '';

    return SmPlayerI18nScope(
      i18n: i18n,
      child: HeaderedPlaylistControl(
        type:
            selectedPlaylist.isBuiltIn
                ? HeaderedPlaylistType.favorites
                : HeaderedPlaylistType.playlist,
        title: selectedPlaylist.name,
        headerSongs: songs,
        songs: songs,
        selectedTrackId: mediaControl.track.id,
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
          _playTrack(ref, snapshot, trackId, queueSongIds);
        },
        onMoveToMusicOrPlay: (songId) {
          _playTrack(
            ref,
            snapshot,
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
          ref.invalidate(musicLibrarySnapshotProvider);
        },
        onRemoveSongs: (songIds) async {
          await ref
              .read(libraryRepositoryProvider)
              .removeSongsFromPlaylist(selectedPlaylist.id, songIds);
          ref.invalidate(musicLibrarySnapshotProvider);
        },
        onRename: (name) {
          ref
              .read(libraryRepositoryProvider)
              .renamePlaylist(selectedPlaylist.id, name);
          ref.invalidate(musicLibrarySnapshotProvider);
        },
        onDelete: () {
          ref
              .read(libraryRepositoryProvider)
              .deletePlaylist(selectedPlaylist.id);
          ref.invalidate(musicLibrarySnapshotProvider);
          context.go('/playlists');
        },
        onClear: () {
          ref
              .read(libraryRepositoryProvider)
              .removeSongsFromPlaylist(
                selectedPlaylist.id,
                songs.map((song) => song.id).toList(),
              );
          ref.invalidate(musicLibrarySnapshotProvider);
        },
        onSetPreferred: (level) {
          ref
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
          ref.invalidate(musicLibrarySnapshotProvider);
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
          ref.invalidate(musicLibrarySnapshotProvider);
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
    MusicLibrarySnapshot snapshot,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          CommandBar(
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
          ),
          const SizedBox(height: 18),
          Expanded(
            child:
                orderedPlaylists.isEmpty
                    ? _PlaylistsEmptyState(i18n: i18n)
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
                                mainAxisExtent: 232,
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
                            return DragTarget<int>(
                              onWillAcceptWithDetails: (details) {
                                _previewPlaylistMove(
                                  customPlaylists
                                      .map((item) => item.id)
                                      .toList(),
                                  details.data,
                                  playlist.id,
                                );
                                return true;
                              },
                              onAcceptWithDetails: (_) {
                                _commitPlaylistPreview();
                              },
                              builder: (context, _, __) {
                                if (_draggingPlaylistId == playlist.id) {
                                  return _PlaylistDropPlaceholder(i18n: i18n);
                                }

                                return LongPressDraggable<int>(
                                  data: playlist.id,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: SizedBox(
                                      width: 180,
                                      height: 232,
                                      child: _PlaylistCard(
                                        playlist: playlist,
                                        songs: playlistSongs,
                                        i18n: i18n,
                                        dragging: true,
                                        onOpen: () {},
                                        onPlay: () {},
                                        onContextMenu: (_) {},
                                      ),
                                    ),
                                  ),
                                  onDragStarted: () {
                                    setState(() {
                                      _draggingPlaylistId = playlist.id;
                                      _previewPlaylistIds =
                                          customPlaylists
                                              .map((item) => item.id)
                                              .toList();
                                    });
                                  },
                                  onDraggableCanceled: (_, __) {
                                    _clearPlaylistDrag();
                                  },
                                  onDragEnd: (_) {
                                    _clearPlaylistDrag();
                                  },
                                  child: _PlaylistCard(
                                    playlist: playlist,
                                    songs: playlistSongs,
                                    i18n: i18n,
                                    dragging: false,
                                    onOpen: () {
                                      _persistLastPlaylist(playlist.id);
                                      context.go('/playlists/${playlist.id}');
                                    },
                                    onPlay: () {
                                      if (playlistSongs.isNotEmpty) {
                                        ref
                                            .read(libraryRepositoryProvider)
                                            .recordPlaylistPlayed(playlist.id);
                                        _playTrack(
                                          ref,
                                          snapshot,
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
                                        playlistSongs,
                                        position,
                                      );
                                    },
                                  ),
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
    MusicLibrarySnapshot snapshot, [
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
    ref.invalidate(musicLibrarySnapshotProvider);
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
    MusicLibrarySnapshot snapshot,
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
      ref.invalidate(musicLibrarySnapshotProvider);
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
      ref.invalidate(musicLibrarySnapshotProvider);
    }
  }

  void _showPlaylistMenu(
    BuildContext context,
    SmPlayerI18n i18n,
    MusicLibrarySnapshot snapshot,
    LibraryPlaylist playlist,
    List<LibrarySong> songs,
    Offset position,
  ) {
    showMenuFlyout(
      context,
      position: position,
      items: [
        MenuFlyoutItem(
          key: 'play',
          text: i18n.t('context.play'),
          icon: FluentIcons.play_20_regular,
          disabled: songs.isEmpty,
          onPressed: () {
            ref
                .read(libraryRepositoryProvider)
                .recordPlaylistPlayed(playlist.id);
            _playTrack(
              ref,
              snapshot,
              songs.first.id,
              songs.map((song) => song.id).toList(),
            );
          },
        ),
        MenuFlyoutItem(
          key: 'duplicate',
          text: i18n.t('playlists.duplicate'),
          icon: FluentIcons.copy_20_regular,
          onPressed: () {
            unawaited(
              _createPlaylist(context, i18n, snapshot, playlist.songIds),
            );
          },
        ),
        MenuFlyoutItem(
          key: 'rename',
          text: i18n.t('playlists.rename'),
          icon: FluentIcons.edit_20_regular,
          onPressed: () {
            unawaited(_renamePlaylist(context, i18n, snapshot, playlist));
          },
        ),
        MenuFlyoutItem(
          key: 'delete',
          text: i18n.t('playlists.delete'),
          icon: FluentIcons.delete_20_regular,
          onPressed: () {
            unawaited(_deletePlaylist(context, i18n, playlist));
          },
        ),
      ],
    );
  }

  void _previewPlaylistMove(
    List<int> currentPlaylistIds,
    int draggedPlaylistId,
    int targetPlaylistId,
  ) {
    final currentPreview = _previewPlaylistIds ?? currentPlaylistIds;
    final nextIds =
        currentPreview
            .where((playlistId) => playlistId != draggedPlaylistId)
            .toList();
    final targetIndex = nextIds.indexOf(targetPlaylistId);
    nextIds.insert(
      targetIndex < 0 ? nextIds.length : targetIndex,
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
    if (nextPlaylistIds != null) {
      ref.read(libraryRepositoryProvider).reorderPlaylists(nextPlaylistIds);
      ref.invalidate(musicLibrarySnapshotProvider);
    }
    _clearPlaylistDrag();
  }

  void _clearPlaylistDrag() {
    setState(() {
      _draggingPlaylistId = null;
      _previewPlaylistIds = null;
    });
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
  MusicLibrarySnapshot snapshot,
  int trackId,
  List<int> queueSongIds,
) {
  final songsById = {for (final song in snapshot.songs) song.id: song};
  final song = songsById[trackId]!;
  ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
  ref
      .read(mediaControlControllerProvider)
      .playTrack(
        MediaControlTrack(
          id: song.id,
          title: song.title,
          artist: song.artist,
          artworkUrl: song.thumbnailPath,
          isLoading: false,
          favorite: song.favorite,
        ),
        durationSeconds: song.duration.toDouble(),
        queueIndex: queueSongIds.indexOf(trackId),
      );
  ref.invalidate(musicLibrarySnapshotProvider);
}

void _playNext(WidgetRef ref, MusicLibrarySnapshot snapshot, int songId) {
  final queueSongIds = snapshot.nowPlaying.songIds.toList();
  final currentTrackId =
      ref.read(mediaControlControllerProvider).state.track.id;
  final currentIndex =
      currentTrackId == null ? -1 : queueSongIds.indexOf(currentTrackId);
  queueSongIds.insert(currentIndex < 0 ? 0 : currentIndex + 1, songId);
  ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
  ref.invalidate(musicLibrarySnapshotProvider);
}

bool _idsEqual(List<int> left, List<int> right) {
  return left.length == right.length &&
      left.indexed.every((entry) => entry.$2 == right[entry.$1]);
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.songs,
    required this.i18n,
    required this.dragging,
    required this.onOpen,
    required this.onPlay,
    required this.onContextMenu,
  });

  final LibraryPlaylist playlist;
  final List<LibrarySong> songs;
  final SmPlayerI18n i18n;
  final bool dragging;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final ValueChanged<Offset> onContextMenu;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 180,
        height: 232,
        child: AnimatedOpacity(
          opacity: dragging ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          child: Material(
            color: dragging ? _PlaylistsColors.cardHover : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              hoverColor: _PlaylistsColors.cardHover,
              focusColor: _PlaylistsColors.cardHover,
              onTap: onOpen,
              onSecondaryTapDown: (details) {
                onContextMenu(details.globalPosition);
              },
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox.square(
                          dimension: 160,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _PlaylistArtwork(songs: songs),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _PlaylistsColors.textStrong,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          i18n.t('playlists.songCount', {
                            'count': playlist.songCount,
                          }),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _PlaylistsColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: IconButton.filledTonal(
                        tooltip: i18n.t('playlists.dragToSort'),
                        icon: const Icon(
                          FluentIcons.re_order_dots_vertical_20_regular,
                          size: 18,
                        ),
                        onPressed: () {},
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 60,
                      child: IconButton.filled(
                        tooltip: i18n.t('context.play'),
                        icon: const Icon(FluentIcons.play_20_filled),
                        onPressed: songs.isEmpty ? null : onPlay,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistArtwork extends StatelessWidget {
  const _PlaylistArtwork({required this.songs});

  final List<LibrarySong> songs;

  @override
  Widget build(BuildContext context) {
    final thumbnailPaths = <String>[];
    for (final song in songs) {
      if (song.thumbnailPath.isNotEmpty &&
          File(song.thumbnailPath).existsSync() &&
          !thumbnailPaths.contains(song.thumbnailPath)) {
        thumbnailPaths.add(song.thumbnailPath);
      }
      if (thumbnailPaths.length == 4) {
        break;
      }
    }

    if (thumbnailPaths.isEmpty) {
      return const _PlaylistArtworkFallback();
    }

    if (thumbnailPaths.length == 1) {
      return Image.file(File(thumbnailPaths.first), fit: BoxFit.cover);
    }

    return GridView.count(
      crossAxisCount: 2,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final thumbnailPath in thumbnailPaths)
          Image.file(File(thumbnailPath), fit: BoxFit.cover),
        if (thumbnailPaths.length == 3) const _PlaylistArtworkFallback(),
      ],
    );
  }
}

class _PlaylistArtworkFallback extends StatelessWidget {
  const _PlaylistArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_PlaylistsColors.coverA, _PlaylistsColors.coverB],
        ),
      ),
      child: Icon(
        FluentIcons.apps_list_detail_24_regular,
        color: Colors.white,
        size: 56,
      ),
    );
  }
}

class _PlaylistDropPlaceholder extends StatelessWidget {
  const _PlaylistDropPlaceholder({required this.i18n});

  final SmPlayerI18n i18n;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 180,
        height: 232,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _PlaylistsColors.accentStrong, width: 2),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  FluentIcons.add_circle_24_regular,
                  color: _PlaylistsColors.accentStrong,
                  size: 30,
                ),
                const SizedBox(height: 13),
                SizedBox(
                  width: 92,
                  child: Text(
                    i18n.t('playlists.dropHere'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _PlaylistsColors.accentStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistsEmptyState extends StatelessWidget {
  const _PlaylistsEmptyState({required this.i18n});

  final SmPlayerI18n i18n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '${i18n.t('playlists.none')}\n${i18n.t('playlists.noneCopy')}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: _PlaylistsColors.textMuted, height: 1.5),
      ),
    );
  }
}

class _PlaylistsColors {
  const _PlaylistsColors._();

  static const cardHover = Color(0xf2ffffff);
  static const accentStrong = Color(0xff0063b1);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff607085);
  static const coverA = Color(0xff6794c6);
  static const coverB = Color(0xff6f7fc8);
}
