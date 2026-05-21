import 'dart:async';
import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/now_playing_full_model.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';

class NowPlayingPage extends ConsumerStatefulWidget {
  const NowPlayingPage({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  ConsumerState<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends ConsumerState<NowPlayingPage> {
  static const quickPlayLimit = 100;

  final _selection = PageSelectionController<int>.stored('now-playing');
  final _listController = ScrollController();
  ({LibrarySong song, SongDialogMode mode})? _songDialog;

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshotValue = ref.watch(musicLibrarySnapshotProvider);
    final mediaControlState = ref.watch(mediaControlControllerProvider).state;
    final i18n = context.smPlayerI18n;

    return snapshotValue.when(
      loading: () => const _NowPlayingPagePanel(child: SmPlayerLoadingState()),
      error:
          (_, _) => _NowPlayingPagePanel(
            child: _NowPlayingEmptyState(
              title: i18n.t('nowPlaying.noActiveTrack'),
              message: i18n.t('nowPlaying.noActiveTrackCopy'),
            ),
          ),
      data: (snapshot) {
        final songsById = {for (final song in snapshot.songs) song.id: song};
        final queueSongs =
            snapshot.nowPlaying.songIds
                .map((songId) => songsById[songId])
                .whereType<LibrarySong>()
                .toList();
        final queueSongIds = queueSongs.map((song) => song.id).toList();
        final queueEntries = queueSongs.indexed.toList();
        final visibleEntries =
            queueEntries
                .where((entry) => _matchesSearch(entry.$2, widget.searchQuery))
                .toList();
        final visibleQueueSongs =
            visibleEntries.map((entry) => entry.$2).toList();
        final visibleQueueIndexes =
            visibleEntries.map((entry) => entry.$1).toList();
        final selectedVisibleSongIds =
            visibleEntries
                .where((entry) => _selection.isSelected(entry.$1))
                .map((entry) => entry.$2.id)
                .toList();
        final selectedVisibleQueueIndexes =
            visibleQueueIndexes
                .where((index) => _selection.isSelected(index))
                .toList();
        final currentSong = _resolveCurrentSong(
          mediaControlState,
          queueSongs,
          songsById,
        );
        final folders =
            snapshot.folders
                .map(
                  (folder) => MenuFlyoutFolder(
                    id: folder.id,
                    name: _displayPathName(folder.path),
                    path: folder.path,
                    parentId: folder.parentId,
                  ),
                )
                .toList();
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
        final addQueueToItem = buildAddToPlaylistMenuFlyoutItem(
          i18n: i18n,
          songIds: queueSongIds,
          playlists: customPlaylists,
          includeFavorites: queueSongs.any((song) => !song.favorite),
          onToggleFavorite:
              queueSongs.any((song) => !song.favorite)
                  ? () {
                    _addSongsToFavorites(
                      queueSongs
                          .where((song) => !song.favorite)
                          .map((song) => song.id)
                          .toList(),
                      songsById,
                    );
                  }
                  : null,
          onCreatePlaylist: () {
            unawaited(
              createPlaylistWithSongs(
                context: context,
                ref: ref,
                i18n: i18n,
                playlists: snapshot.playlists,
                defaultName: getDefaultNewPlaylistName(
                  i18n,
                  snapshot.playlists,
                ),
                songIds: queueSongIds,
              ),
            );
          },
          onAddToPlaylist: (playlistId) {
            unawaited(
              _addSongsToPlaylistWithUndo(
                playlistId,
                queueSongIds,
                snapshot.playlists,
                songsById,
              ),
            );
          },
        );

        return _NowPlayingPagePanel(
          child: Stack(
            children: [
              Column(
                children: [
                  CommandBar(
                    overflowLabel: i18n.t('player.more'),
                    children: [
                      CommandBarButton(
                        icon: FluentIcons.play_20_filled,
                        label: i18n.t('nowPlaying.quickPlay'),
                        disabled: snapshot.songs.isEmpty,
                        onPressed: () {
                          _playSongIds(
                            _randomLibrary(snapshot.songs, quickPlayLimit),
                          );
                        },
                      ),
                      CommandBarButton(
                        icon: FluentIcons.arrow_shuffle_20_regular,
                        label: i18n.t('nowPlaying.randomPlay'),
                        disabled: snapshot.songs.isEmpty,
                        onPressed: () {
                          _showShuffleMenu(
                            snapshot: snapshot,
                            queueSongs: queueSongs,
                          );
                        },
                      ),
                      CommandBarButton(
                        icon: FluentIcons.music_note_2_20_regular,
                        label: i18n.t('nowPlaying.locateCurrent'),
                        disabled: queueSongs.isEmpty,
                        onPressed: () {
                          _locateCurrent(queueSongs, mediaControlState);
                        },
                      ),
                      CommandBarButton(
                        icon: FluentIcons.add_20_regular,
                        label: i18n.t('context.addToPlaylist'),
                        disabled:
                            queueSongIds.isEmpty || addQueueToItem == null,
                        onPressed: () {
                          if (addQueueToItem == null) {
                            return;
                          }
                          showMenuFlyout(
                            context,
                            items: addQueueToItem.submenu,
                          );
                        },
                      ),
                      CommandBarButton(
                        icon: FluentIcons.dismiss_20_regular,
                        label: i18n.t('nowPlaying.clearQueue'),
                        disabled: queueSongs.isEmpty,
                        onPressed: () {
                          _clearQueue(queueSongIds);
                        },
                      ),
                      CommandBarButton(
                        icon: FluentIcons.full_screen_maximize_20_regular,
                        label: i18n.t('nowPlaying.playMode'),
                        disabled: currentSong == null,
                        onPressed: () {
                          context.go('/now-playing/full');
                        },
                      ),
                      CommandBarButton(
                        icon: FluentIcons.select_all_on_20_regular,
                        label: i18n.t('common.multiSelect'),
                        active: _selection.multiSelect,
                        disabled: queueSongs.isEmpty,
                        onPressed: _toggleMultiSelect,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child:
                        queueSongs.isEmpty
                            ? _NowPlayingEmptyState(
                              title: i18n.t('nowPlaying.queueEmpty'),
                              message: i18n.t('nowPlaying.queueEmptyHelp'),
                            )
                            : visibleQueueSongs.isEmpty
                            ? _NowPlayingEmptyState(
                              title: i18n.t('nowPlaying.noQueueMatch', {
                                'query': widget.searchQuery,
                              }),
                              message: i18n.t('nowPlaying.queueSearchHelp'),
                            )
                            : Scrollbar(
                              controller: _listController,
                              child: ReorderableListView.builder(
                                scrollController: _listController,
                                padding: EdgeInsets.fromLTRB(
                                  0,
                                  0,
                                  14,
                                  _selection.multiSelect
                                      ? multiSelectCommandBarScrollSpacer
                                      : 18,
                                ),
                                buildDefaultDragHandles: false,
                                itemCount: visibleEntries.length,
                                onReorder: (oldIndex, newIndex) {
                                  _moveVisibleQueueSong(
                                    queueSongIds,
                                    visibleQueueIndexes,
                                    oldIndex,
                                    newIndex,
                                  );
                                },
                                itemBuilder: (context, visibleIndex) {
                                  final queueIndex =
                                      visibleEntries[visibleIndex].$1;
                                  final song = visibleEntries[visibleIndex].$2;
                                  final current =
                                      mediaControlState.selectedQueueIndex ==
                                              null
                                          ? song.id ==
                                              mediaControlState.track.id
                                          : queueIndex ==
                                              mediaControlState
                                                  .selectedQueueIndex;
                                  return ReorderableDragStartListener(
                                    key: ValueKey(
                                      'now-playing-${song.id}-$queueIndex',
                                    ),
                                    index: visibleIndex,
                                    child: PlaylistControlItem(
                                      song: song,
                                      current: current,
                                      playing:
                                          current &&
                                          mediaControlState.isPlaying,
                                      selected: _selection.isSelected(
                                        queueIndex,
                                      ),
                                      selectionMode: _selection.multiSelect,
                                      onPlayTrack: () {
                                        _playQueueTrack(
                                          song,
                                          queueSongIds,
                                          queueIndex,
                                        );
                                      },
                                      onTogglePlayPause:
                                          ref
                                              .read(
                                                mediaControlControllerProvider,
                                              )
                                              .onTogglePlayPause,
                                      onToggleSelection: () {
                                        _toggleQueueSelection(queueIndex);
                                      },
                                      onPlayNextClick: () {
                                        _playNext(queueSongIds, queueIndex);
                                      },
                                      onRemoveFromListClick: () {
                                        _removeQueueIndex(
                                          queueSongIds,
                                          queueIndex,
                                          song,
                                        );
                                      },
                                      onOpenContextMenu: (position) {
                                        unawaited(
                                          _showQueueContextMenu(
                                            position,
                                            song,
                                            queueSongIds,
                                            queueIndex,
                                            customPlaylists,
                                            folders,
                                            snapshot.playlists,
                                            songsById,
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                  ),
                ],
              ),
              MultiSelectCommandBar(
                visible: _selection.multiSelect,
                selectedCount: selectedVisibleSongIds.length,
                playlists: customPlaylists,
                addToSongIds: selectedVisibleSongIds,
                includeFavoritesInAddTo: selectedVisibleSongIds.any(
                  (songId) => !songsById[songId]!.favorite,
                ),
                removeLabel: i18n.t('nowPlaying.remove'),
                onToggleFavorite: () {
                  _addSongsToFavorites(
                    selectedVisibleSongIds
                        .where((songId) => !songsById[songId]!.favorite)
                        .toList(),
                    songsById,
                  );
                  _clearSelection();
                },
                onCreatePlaylist: () {
                  unawaited(
                    createPlaylistWithSongs(
                      context: context,
                      ref: ref,
                      i18n: i18n,
                      playlists: snapshot.playlists,
                      defaultName: getDefaultNewPlaylistName(
                        i18n,
                        snapshot.playlists,
                      ),
                      songIds: selectedVisibleSongIds,
                    ),
                  );
                  _clearSelection();
                },
                onAddToPlaylist: (playlistId) {
                  unawaited(
                    _addSongsToPlaylistWithUndo(
                      playlistId,
                      selectedVisibleSongIds,
                      snapshot.playlists,
                      songsById,
                    ),
                  );
                  _clearSelection();
                },
                onPlay:
                    selectedVisibleSongIds.isEmpty
                        ? null
                        : () {
                          _playSongIds(selectedVisibleSongIds);
                          _clearSelection();
                        },
                onRemove:
                    selectedVisibleSongIds.isEmpty
                        ? null
                        : () {
                          _removeSelectedQueueIndexes(
                            queueSongIds,
                            selectedVisibleQueueIndexes,
                            selectedVisibleSongIds,
                            songsById,
                          );
                          _clearSelection();
                        },
                onSelectAll: () {
                  setState(() {
                    _selection.selectAll(visibleQueueIndexes);
                  });
                },
                onReverseSelection: () {
                  setState(() {
                    _selection.reverseSelection(visibleQueueIndexes);
                  });
                },
                onClearSelection: () {
                  setState(_selection.clearSelection);
                },
                onCancel: () {
                  setState(_selection.cancel);
                },
              ),
              if (_songDialog case final dialog?)
                MusicDialog(
                  song: dialog.song,
                  initialMode: dialog.mode,
                  canPause:
                      mediaControlState.isPlaying &&
                      mediaControlState.track.id == dialog.song.id,
                  onPlay:
                      ref
                          .read(mediaControlControllerProvider)
                          .onTogglePlayPause,
                  onReveal: _revealPath,
                  onSaved: () {
                    ref.invalidate(musicLibrarySnapshotProvider);
                  },
                  onClose: () {
                    setState(() {
                      _songDialog = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _playQueueTrack(
    LibrarySong song,
    List<int> queueSongIds,
    int queueIndex,
  ) {
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
          queueIndex: queueIndex,
        );
    _replaceQueue(queueSongIds);
  }

  void _playSongIds(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }

    final songs =
        ref.read(musicLibrarySnapshotProvider).value?.songs ?? const [];
    final songsById = {for (final song in songs) song.id: song};
    final firstSong = songsById[songIds.first]!;
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          MediaControlTrack(
            id: firstSong.id,
            title: firstSong.title,
            artist: firstSong.artist,
            artworkUrl: firstSong.thumbnailPath,
            isLoading: false,
            favorite: firstSong.favorite,
          ),
          durationSeconds: firstSong.duration.toDouble(),
          queueIndex: 0,
        );
    _replaceQueue(songIds);
  }

  void _replaceQueue(List<int> songIds) {
    ref.read(libraryRepositoryProvider).replaceNowPlaying(songIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _removeQueueIndex(
    List<int> queueSongIds,
    int queueIndex,
    LibrarySong song,
  ) {
    final before = queueSongIds.toList();
    _replaceQueue([
      for (var index = 0; index < queueSongIds.length; index += 1)
        if (index != queueIndex) queueSongIds[index],
    ]);
    _showUndo(
      context.smPlayerI18n.t('notification.removedFrom', {
        'title': song.title,
        'target': context.smPlayerI18n.t('common.nowPlaying'),
      }),
      () => _replaceQueue(before),
    );
  }

  void _playNext(List<int> queueSongIds, int queueIndex) {
    final nextSongIds = queueSongIds.toList();
    final songId = nextSongIds.removeAt(queueIndex);
    nextSongIds.insert(
      ref.read(mediaControlControllerProvider).state.selectedQueueIndex == null
          ? 0
          : ref.read(mediaControlControllerProvider).state.selectedQueueIndex! +
              1,
      songId,
    );
    _replaceQueue(nextSongIds);
  }

  void _moveQueueSong(List<int> queueSongIds, int oldIndex, int newIndex) {
    final nextSongIds = queueSongIds.toList();
    final insertIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final songId = nextSongIds.removeAt(oldIndex);
    nextSongIds.insert(insertIndex, songId);
    _replaceQueue(nextSongIds);
  }

  void _moveVisibleQueueSong(
    List<int> queueSongIds,
    List<int> visibleQueueIndexes,
    int oldVisibleIndex,
    int newVisibleIndex,
  ) {
    final oldQueueIndex = visibleQueueIndexes[oldVisibleIndex];
    final normalizedVisibleIndex =
        newVisibleIndex > oldVisibleIndex
            ? newVisibleIndex - 1
            : newVisibleIndex;
    final targetQueueIndex =
        normalizedVisibleIndex >= visibleQueueIndexes.length
            ? queueSongIds.length
            : visibleQueueIndexes[normalizedVisibleIndex];
    _moveQueueSong(queueSongIds, oldQueueIndex, targetQueueIndex);
  }

  void _toggleMultiSelect() {
    setState(() {
      if (_selection.multiSelect) {
        _selection.cancel();
      } else {
        _selection.enterMultiSelect();
      }
    });
  }

  void _toggleQueueSelection(int queueIndex) {
    setState(() {
      _selection.toggle(queueIndex);
    });
  }

  void _clearSelection() {
    setState(() {
      _selection.clearSelection();
    });
  }

  void _removeSelectedQueueIndexes(
    List<int> queueSongIds,
    List<int> selectedIndexes,
    List<int> selectedSongIds,
    Map<int, LibrarySong> songsById,
  ) {
    final before = queueSongIds.toList();
    _replaceQueue([
      for (var index = 0; index < queueSongIds.length; index += 1)
        if (!selectedIndexes.contains(index)) queueSongIds[index],
    ]);
    final i18n = context.smPlayerI18n;
    _showUndo(
      selectedSongIds.length == 1
          ? i18n.t('notification.removedFrom', {
            'title': songsById[selectedSongIds.first]!.title,
            'target': i18n.t('common.nowPlaying'),
          })
          : i18n.t('notification.songsRemovedFrom', {
            'count': selectedSongIds.length,
            'target': i18n.t('common.nowPlaying'),
          }),
      () => _replaceQueue(before),
    );
  }

  Future<void> _showQueueContextMenu(
    Offset position,
    LibrarySong song,
    List<int> queueSongIds,
    int queueIndex,
    List<MultiSelectCommandBarPlaylist> playlists,
    List<MenuFlyoutFolder> folders,
    List<LibraryPlaylist> allPlaylists,
    Map<int, LibrarySong> songsById,
  ) async {
    final i18n = context.smPlayerI18n;
    final mediaState = ref.read(mediaControlControllerProvider).state;
    final currentTrackId = mediaState.track.id;
    final preferenceLevel = await ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('song', '${song.id}');
    if (!mounted) {
      return;
    }
    showMenuFlyout(
      context,
      position: position,
      items: buildMusicMenuFlyoutItems(
        i18n: i18n,
        songId: song.id,
        isFavorite: song.favorite,
        isCurrentTrack: song.id == currentTrackId,
        isPlaying: mediaState.isPlaying,
        currentTrackId: currentTrackId,
        currentPlaylistName: i18n.t('common.nowPlaying'),
        songPath: song.path,
        playlists: playlists,
        folders: folders,
        showRemove: true,
        showDelete: true,
        showHideFile: true,
        showMoveToFolder: true,
        preferenceLevel: preferenceLevel,
        onUndoPreference:
            preferenceLevel == null
                ? null
                : () {
                  unawaited(
                    ref
                        .read(libraryRepositoryProvider)
                        .removePreferenceItem('song', '${song.id}')
                        .then((_) {
                          ref.invalidate(musicLibrarySnapshotProvider);
                        }),
                  );
                },
        onPlay: () {
          _playQueueTrack(song, queueSongIds, queueIndex);
        },
        onPause: ref.read(mediaControlControllerProvider).onTogglePlayPause,
        onPlayNext: () {
          _playNext(queueSongIds, queueIndex);
        },
        onAddToNowPlaying: () {
          final before = queueSongIds.toList();
          _replaceQueue([...queueSongIds, song.id]);
          _showUndo(
            i18n.t('notification.songAddedTo', {
              'title': song.title,
              'target': i18n.t('common.nowPlaying'),
            }),
            () => _replaceQueue(before),
          );
        },
        onCreatePlaylist: () {
          unawaited(
            createPlaylistWithSongs(
              context: context,
              ref: ref,
              i18n: i18n,
              playlists: allPlaylists,
              defaultName: getNextPlaylistName(song.title, allPlaylists),
              songIds: [song.id],
            ),
          );
        },
        onAddToPlaylist: (playlistId) {
          unawaited(
            _addSongsToPlaylistWithUndo(
              playlistId,
              [song.id],
              allPlaylists,
              songsById,
            ),
          );
        },
        onRemove: () {
          _removeQueueIndex(queueSongIds, queueIndex, song);
        },
        onSelect: () {
          setState(() {
            _selection.enterMultiSelect();
            if (!_selection.isSelected(queueIndex)) {
              _selection.toggle(queueIndex);
            }
          });
        },
        onToggleFavorite: () {
          _addSongsToFavorites([song.id], songsById);
        },
        onSetPreference: (level) async {
          await ref
              .read(libraryRepositoryProvider)
              .addPreferenceItem('song', '${song.id}', song.title, level);
          ref.invalidate(musicLibrarySnapshotProvider);
        },
        onDelete: () {
          requestDeleteSongFromDisk(
            context: context,
            ref: ref,
            i18n: i18n,
            song: song,
          );
        },
        onHide: () {
          unawaited(_hideQueueSongFileWithUndo(song, queueSongIds));
        },
        onMoveToFolder: (folderPath) {
          unawaited(
            moveSongToFolderWithUndo(
              context: context,
              ref: ref,
              i18n: i18n,
              song: song,
              folderPath: folderPath,
            ),
          );
        },
        onSeeArtist: () {
          final artist =
              song.artists.isEmpty ? song.artist : song.artists.first;
          context.go('/artists?artist=${Uri.encodeQueryComponent(artist)}');
        },
        onSeeAlbum: () {
          final album =
              song.album.isEmpty ? i18n.t('common.albumUnknown') : song.album;
          context.go('/albums?album=${Uri.encodeQueryComponent(album)}');
        },
        onSeeMusicInfo: () {
          setState(() {
            _songDialog = (song: song, mode: SongDialogMode.properties);
          });
        },
        onSeeLyrics: () {
          setState(() {
            _songDialog = (song: song, mode: SongDialogMode.lyrics);
          });
        },
        onSeeAlbumArt: () {
          setState(() {
            _songDialog = (song: song, mode: SongDialogMode.albumArt);
          });
        },
        onSeeLocal: () {
          _revealPath(song.path);
        },
      ),
    );
  }

  LibrarySong? _resolveCurrentSong(
    MediaControlState mediaControlState,
    List<LibrarySong> queueSongs,
    Map<int, LibrarySong> songsById,
  ) {
    final queueIndex = mediaControlState.selectedQueueIndex;
    if (queueIndex != null &&
        queueIndex >= 0 &&
        queueIndex < queueSongs.length) {
      return queueSongs[queueIndex];
    }

    final trackId = mediaControlState.track.id;
    return trackId == null ? null : songsById[trackId];
  }

  void _showShuffleMenu({
    required MusicLibrarySnapshot snapshot,
    required List<LibrarySong> queueSongs,
  }) {
    showMenuFlyout(
      context,
      items: _buildShuffleMenuItems(snapshot: snapshot, queueSongs: queueSongs),
    );
  }

  List<MenuFlyoutItem> _buildShuffleMenuItems({
    required MusicLibrarySnapshot snapshot,
    required List<LibrarySong> queueSongs,
  }) {
    final i18n = context.smPlayerI18n;
    final items = <MenuFlyoutItem>[
      MenuFlyoutItem(
        key: 'quick',
        text: i18n.t('nowPlaying.quickPlay'),
        icon: FluentIcons.play_20_regular,
        onPressed: () {
          _playSongIds(_randomLibrary(snapshot.songs, quickPlayLimit));
        },
      ),
    ];

    if (queueSongs.isNotEmpty) {
      items.addAll([
        const MenuFlyoutItem.separator(key: 'now-playing-separator'),
        MenuFlyoutItem(
          key: 'now-playing',
          text: i18n.t('common.nowPlaying'),
          icon: FluentIcons.music_note_2_20_regular,
          onPressed: () {
            _playSongIds(_shuffleSongIds(queueSongs));
          },
        ),
      ]);
    }

    if (snapshot.songs.isEmpty) {
      return items;
    }

    items.addAll([
      const MenuFlyoutItem.separator(key: 'shuffle-library-separator'),
      MenuFlyoutItem(
        key: 'library',
        text: i18n.t('random.musicLibrary'),
        icon: FluentIcons.library_20_regular,
        onPressed: () {
          _playSongIds(_randomLibrary(snapshot.songs, quickPlayLimit));
        },
      ),
      MenuFlyoutItem(
        key: 'artist',
        text: i18n.t('common.artist'),
        icon: FluentIcons.person_20_regular,
        onPressed: () {
          _playSongIds(_randomArtist(snapshot.songs, quickPlayLimit));
        },
      ),
      MenuFlyoutItem(
        key: 'album',
        text: i18n.t('common.album'),
        icon: FluentIcons.album_20_regular,
        onPressed: () {
          _playSongIds(_randomAlbum(snapshot.songs, quickPlayLimit));
        },
      ),
    ]);

    final playablePlaylists =
        snapshot.playlists
            .where((playlist) => playlist.songIds.isNotEmpty)
            .toList();
    if (playablePlaylists.isNotEmpty) {
      items.add(
        MenuFlyoutItem(
          key: 'playlist',
          text: i18n.t('common.playlist'),
          icon: FluentIcons.apps_list_detail_20_regular,
          onPressed: () {
            _playSongIds(
              _randomPlaylist(
                snapshot.songs,
                playablePlaylists,
                quickPlayLimit,
              ),
            );
          },
        ),
      );
    }

    final playableFolders =
        snapshot.folders
            .where(
              (folder) => snapshot.songs.any(
                (song) => _isSongDirectlyInFolder(song, folder.path),
              ),
            )
            .toList();
    if (playableFolders.isNotEmpty) {
      items.add(
        MenuFlyoutItem(
          key: 'folder',
          text: i18n.t('random.localFolder'),
          icon: FluentIcons.folder_20_regular,
          onPressed: () {
            _playSongIds(
              _randomFolder(snapshot.songs, playableFolders, quickPlayLimit),
            );
          },
        ),
      );
    }

    items.add(
      MenuFlyoutItem(
        key: 'recent-added',
        text: i18n.t('common.recentAdded'),
        icon: FluentIcons.history_20_regular,
        onPressed: () {
          _playSongIds(_randomRecentAdded(snapshot.songs, quickPlayLimit));
        },
      ),
    );

    if (snapshot.recentSongs.isNotEmpty) {
      items.add(
        MenuFlyoutItem(
          key: 'recent-played',
          text: i18n.t('random.recentPlayed'),
          icon: FluentIcons.history_20_regular,
          onPressed: () {
            _playSongIds(_shuffleSongIds(snapshot.recentSongs));
          },
        ),
      );
    }

    if (snapshot.songs.length > quickPlayLimit) {
      items.addAll([
        const MenuFlyoutItem.separator(key: 'shuffle-history-separator'),
        MenuFlyoutItem(
          key: 'most-played',
          text: i18n.t('random.mostPlayed'),
          icon: FluentIcons.top_speed_20_regular,
          onPressed: () {
            _playSongIds(_randomMostPlayed(snapshot.songs, quickPlayLimit));
          },
        ),
        MenuFlyoutItem(
          key: 'least-played',
          text: i18n.t('random.leastPlayed'),
          icon: FluentIcons.arrow_trending_lines_20_regular,
          onPressed: () {
            _playSongIds(_randomLeastPlayed(snapshot.songs, quickPlayLimit));
          },
        ),
      ]);
    }

    return items;
  }

  void _addSongsToFavorites(
    List<int> songIds,
    Map<int, LibrarySong> songsById,
  ) {
    if (songIds.isEmpty) {
      return;
    }
    unawaited(setSongsFavorite(ref, songIds, true));
    final i18n = context.smPlayerI18n;
    _showUndo(
      songIds.length == 1
          ? i18n.t('notification.songAddedTo', {
            'title': songsById[songIds.first]!.title,
            'target': i18n.t('common.myFavorites'),
          })
          : i18n.t('notification.songsAddedTo', {
            'count': songIds.length,
            'target': i18n.t('common.myFavorites'),
          }),
      () => setSongsFavorite(ref, songIds, false),
    );
  }

  Future<void> _addSongsToPlaylistWithUndo(
    int playlistId,
    List<int> songIds,
    List<LibraryPlaylist> playlists,
    Map<int, LibrarySong> songsById,
  ) async {
    final i18n = context.smPlayerI18n;
    await addSongsToPlaylist(ref, playlistId, songIds);
    if (!mounted) {
      return;
    }
    final targetPlaylist = playlists.firstWhere(
      (playlist) => playlist.id == playlistId,
    );
    _showUndo(
      songIds.length == 1
          ? i18n.t('notification.songAddedTo', {
            'title': songsById[songIds.first]!.title,
            'target': targetPlaylist.name,
          })
          : i18n.t('notification.songsAddedTo', {
            'count': songIds.length,
            'target': targetPlaylist.name,
          }),
      () async {
        await ref
            .read(libraryRepositoryProvider)
            .removeSongsFromPlaylist(playlistId, songIds);
        ref.invalidate(musicLibrarySnapshotProvider);
      },
    );
  }

  void _clearQueue(List<int> queueSongIds) {
    final before = queueSongIds.toList();
    _replaceQueue(const []);
    _showUndo(
      context.smPlayerI18n.t('nowPlaying.clearQueue'),
      () => _replaceQueue(before),
    );
  }

  Future<void> _hideQueueSongFileWithUndo(
    LibrarySong song,
    List<int> queueSongIds,
  ) async {
    final removedEntries = _queueEntriesForSong(queueSongIds, song.id);
    await ref.read(libraryRepositoryProvider).hideSong(song.id);
    ref.invalidate(musicLibrarySnapshotProvider);
    _replaceQueue([
      for (final songId in queueSongIds)
        if (songId != song.id) songId,
    ]);
    if (!mounted) {
      return;
    }
    _showUndo(
      context.smPlayerI18n.t('notification.hiddenStorageItem', {
        'name': song.title,
      }),
      () async {
        await ref.read(libraryRepositoryProvider).unhideSong(song.id);
        ref.invalidate(musicLibrarySnapshotProvider);
        final snapshot =
            await ref.read(libraryRepositoryProvider).getMusicLibrarySnapshot();
        _replaceQueue(
          _insertQueueEntries(snapshot.nowPlaying.songIds, removedEntries),
        );
      },
    );
  }

  Future<void> _revealPath(String targetPath) async {
    await revealItemInFolder(targetPath);
  }

  void _showUndo(String message, FutureOr<void> Function() action) {
    showUndoableSnackBar(
      context: context,
      i18n: context.smPlayerI18n,
      message: message,
      onUndo: action,
    );
  }

  void _locateCurrent(
    List<LibrarySong> queueSongs,
    MediaControlState mediaControlState,
  ) {
    final index =
        mediaControlState.selectedQueueIndex ??
        queueSongs.indexWhere((song) => song.id == mediaControlState.track.id);
    if (index < 0) {
      return;
    }

    _listController.animateTo(
      (index * 82.0).clamp(0, _listController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }
}

bool _matchesSearch(LibrarySong song, String searchQuery) {
  final normalizedSearchQuery = searchQuery.trim().toLowerCase();
  if (normalizedSearchQuery.isEmpty) {
    return true;
  }

  return [
    song.title,
    song.artist,
    ...song.artists,
    song.album,
    song.path,
  ].join(' ').toLowerCase().contains(normalizedSearchQuery);
}

List<int> _randomLibrary(List<LibrarySong> songs, int randomLimit) {
  return _randomItems(songs, randomLimit).map((song) => song.id).toList();
}

List<int> _shuffleSongIds(List<LibrarySong> songs) {
  final shuffled = songs.toList()..shuffle(Random());
  return shuffled.map((song) => song.id).toList();
}

List<int> _randomArtist(List<LibrarySong> songs, int randomLimit) {
  final songsByArtist = <String, List<LibrarySong>>{};
  for (final song in songs) {
    final artists = song.artists.isEmpty ? [song.artist] : song.artists;
    for (final artist in artists) {
      songsByArtist[artist] = [...(songsByArtist[artist] ?? []), song];
    }
  }
  final group = _randomItem(songsByArtist.values.toList());
  return _randomItems(group, randomLimit).map((song) => song.id).toList();
}

List<int> _randomAlbum(List<LibrarySong> songs, int randomLimit) {
  return _randomItems(
    _randomSongGroup(songs, (song) => song.album),
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomPlaylist(
  List<LibrarySong> songs,
  List<LibraryPlaylist> playlists,
  int randomLimit,
) {
  final songsById = {for (final song in songs) song.id: song};
  final playlist = _randomItem(playlists);
  final playlistSongs =
      playlist.songIds
          .map((songId) => songsById[songId])
          .whereType<LibrarySong>()
          .toList();
  return _randomItems(
    playlistSongs,
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomFolder(
  List<LibrarySong> songs,
  List<LibraryFolder> folders,
  int randomLimit,
) {
  final playableFolders =
      folders
          .map(
            (folder) => (
              folder: folder,
              songs:
                  songs
                      .where(
                        (song) => _isSongDirectlyInFolder(song, folder.path),
                      )
                      .toList(),
            ),
          )
          .where((entry) => entry.songs.isNotEmpty)
          .toList();
  if (playableFolders.isEmpty) {
    return const [];
  }
  return _randomItems(
    _randomItem(playableFolders).songs,
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomRecentAdded(List<LibrarySong> songs, int randomLimit) {
  final sorted =
      songs.toList()
        ..sort((left, right) => right.dateAdded.compareTo(left.dateAdded));
  return _randomItems(
    sorted.take(500).toList(),
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomMostPlayed(List<LibrarySong> songs, int randomLimit) {
  final sorted =
      songs.toList()
        ..sort((left, right) => right.playCount.compareTo(left.playCount));
  return _randomItems(
    sorted.take(randomLimit).toList(),
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomLeastPlayed(List<LibrarySong> songs, int randomLimit) {
  final sorted =
      songs.toList()
        ..sort((left, right) => left.playCount.compareTo(right.playCount));
  return _randomItems(
    sorted.take(randomLimit).toList(),
    randomLimit,
  ).map((song) => song.id).toList();
}

List<LibrarySong> _randomSongGroup(
  List<LibrarySong> songs,
  String Function(LibrarySong song) getKey,
) {
  final groups = <String, List<LibrarySong>>{};
  for (final song in songs) {
    final key = getKey(song);
    groups[key] = [...(groups[key] ?? []), song];
  }
  final group = _randomItem(groups.values.toList()).toList()..shuffle(Random());
  return group;
}

List<T> _randomItems<T>(List<T> items, int count) {
  if (items.length <= count) {
    return items.toList()..shuffle(Random());
  }

  final indices = <int>{};
  final random = Random();
  while (indices.length < count) {
    indices.add(random.nextInt(items.length));
  }
  return [for (final index in indices) items[index]];
}

T _randomItem<T>(List<T> items) {
  return items[Random().nextInt(items.length)];
}

bool _isSongDirectlyInFolder(LibrarySong song, String folderPath) {
  return _getFileParentPath(song.path) == folderPath;
}

String _getFileParentPath(String path) {
  final separatorIndex = max(path.lastIndexOf('\\'), path.lastIndexOf('/'));
  return separatorIndex > -1 ? path.substring(0, separatorIndex) : '';
}

String _displayPathName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index >= 0 ? normalized.substring(index + 1) : normalized;
}

List<({int index, int songId})> _queueEntriesForSong(
  List<int> queueSongIds,
  int songId,
) {
  return [
    for (var index = 0; index < queueSongIds.length; index += 1)
      if (queueSongIds[index] == songId) (index: index, songId: songId),
  ];
}

List<int> _insertQueueEntries(
  List<int> queueSongIds,
  List<({int index, int songId})> entries,
) {
  var nextQueueSongIds = queueSongIds.toList();
  for (final entry in entries) {
    final index = max(0, min(entry.index, nextQueueSongIds.length));
    nextQueueSongIds = [
      ...nextQueueSongIds.take(index),
      entry.songId,
      ...nextQueueSongIds.skip(index),
    ];
  }
  return nextQueueSongIds;
}

class _NowPlayingPagePanel extends StatelessWidget {
  const _NowPlayingPagePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SizedBox.expand(child: child),
    );
  }
}

class _NowPlayingEmptyState extends StatelessWidget {
  const _NowPlayingEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title\n$message',
        textAlign: TextAlign.center,
        style: const TextStyle(color: _NowPlayingColors.textMuted, height: 1.5),
      ),
    );
  }
}

class _NowPlayingColors {
  const _NowPlayingColors._();

  static const textMuted = Color(0xff5b697a);
}
