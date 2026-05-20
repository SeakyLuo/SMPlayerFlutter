import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';

class NowPlayingPage extends ConsumerStatefulWidget {
  const NowPlayingPage({super.key});

  @override
  ConsumerState<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends ConsumerState<NowPlayingPage> {
  static const quickPlayLimit = 100;

  final _selection = PageSelectionController<int>();
  final _listController = ScrollController();

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
      loading:
          () => const _NowPlayingPagePanel(child: _NowPlayingLoadingState()),
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
        final selectedVisibleSongIds =
            _selection.selectedItems
                .where((index) => index >= 0 && index < queueSongIds.length)
                .map((index) => queueSongIds[index])
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
                    _showMessage(i18n.t('common.myFavorites'));
                  }
                  : null,
          onCreatePlaylist: () {
            _showMessage(i18n.t('playlists.newPlaylist'));
          },
          onAddToPlaylist: (_) {
            _showMessage(i18n.t('context.addToPlaylist'));
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
                            snapshot.songs
                                .take(quickPlayLimit)
                                .map((song) => song.id)
                                .toList(),
                          );
                        },
                      ),
                      CommandBarButton(
                        icon: FluentIcons.arrow_shuffle_20_regular,
                        label: i18n.t('nowPlaying.randomPlay'),
                        disabled: snapshot.songs.isEmpty,
                        onPressed: () {
                          final shuffled = snapshot.songs.toList()..shuffle();
                          _playSongIds(
                            shuffled
                                .take(quickPlayLimit)
                                .map((song) => song.id)
                                .toList(),
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
                          _replaceQueue(const []);
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
                            : ReorderableListView.builder(
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
                              itemCount: queueSongs.length,
                              onReorder: (oldIndex, newIndex) {
                                _moveQueueSong(
                                  queueSongIds,
                                  oldIndex,
                                  newIndex,
                                );
                              },
                              itemBuilder: (context, index) {
                                final song = queueSongs[index];
                                final current =
                                    mediaControlState.selectedQueueIndex == null
                                        ? song.id == mediaControlState.track.id
                                        : index ==
                                            mediaControlState
                                                .selectedQueueIndex;
                                return ReorderableDragStartListener(
                                  key: ValueKey(
                                    'now-playing-${song.id}-$index',
                                  ),
                                  index: index,
                                  child: PlaylistControlItem(
                                    song: song,
                                    current: current,
                                    playing:
                                        current && mediaControlState.isPlaying,
                                    selected: _selection.isSelected(index),
                                    selectionMode: _selection.multiSelect,
                                    onPlayTrack: () {
                                      _playQueueTrack(
                                        song,
                                        queueSongIds,
                                        index,
                                      );
                                    },
                                    onTogglePlayPause:
                                        ref
                                            .read(
                                              mediaControlControllerProvider,
                                            )
                                            .onTogglePlayPause,
                                    onToggleSelection: () {
                                      _toggleQueueSelection(index);
                                    },
                                    onPlayNextClick: () {
                                      _playNext(queueSongIds, index);
                                    },
                                    onRemoveFromListClick: () {
                                      _removeQueueIndex(queueSongIds, index);
                                    },
                                    onOpenContextMenu: (position) {
                                      _showQueueContextMenu(
                                        position,
                                        song,
                                        queueSongIds,
                                        index,
                                        customPlaylists,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
              MultiSelectCommandBar(
                visible: _selection.multiSelect,
                selectedCount: selectedVisibleSongIds.length,
                playlists: customPlaylists,
                removeLabel: i18n.t('nowPlaying.remove'),
                onAddToPlaylist: (_) {
                  _showMessage(i18n.t('context.addToPlaylist'));
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
                          _removeSelectedQueueIndexes(queueSongIds);
                          _clearSelection();
                        },
                onSelectAll: () {
                  setState(() {
                    _selection.selectAll(
                      List.generate(queueSongIds.length, (index) => index),
                    );
                  });
                },
                onReverseSelection: () {
                  setState(() {
                    _selection.reverseSelection(
                      List.generate(queueSongIds.length, (index) => index),
                    );
                  });
                },
                onClearSelection: () {
                  setState(_selection.clearSelection);
                },
                onCancel: () {
                  setState(_selection.cancel);
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

  void _removeQueueIndex(List<int> queueSongIds, int queueIndex) {
    _replaceQueue([
      for (var index = 0; index < queueSongIds.length; index += 1)
        if (index != queueIndex) queueSongIds[index],
    ]);
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

  void _removeSelectedQueueIndexes(List<int> queueSongIds) {
    final selectedIndexes = _selection.selectedItems;
    _replaceQueue([
      for (var index = 0; index < queueSongIds.length; index += 1)
        if (!selectedIndexes.contains(index)) queueSongIds[index],
    ]);
  }

  void _showQueueContextMenu(
    Offset position,
    LibrarySong song,
    List<int> queueSongIds,
    int queueIndex,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) {
    final i18n = context.smPlayerI18n;
    final mediaState = ref.read(mediaControlControllerProvider).state;
    final currentTrackId = mediaState.track.id;
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
        showRemove: true,
        onPlay: () {
          _playQueueTrack(song, queueSongIds, queueIndex);
        },
        onPause: ref.read(mediaControlControllerProvider).onTogglePlayPause,
        onPlayNext: () {
          _playNext(queueSongIds, queueIndex);
        },
        onAddToNowPlaying: () {
          _showMessage(i18n.t('common.nowPlaying'));
        },
        onCreatePlaylist: () {
          _showMessage(i18n.t('playlists.newPlaylist'));
        },
        onAddToPlaylist: (_) {
          _showMessage(i18n.t('context.addToPlaylist'));
        },
        onRemove: () {
          _removeQueueIndex(queueSongIds, queueIndex);
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
          _showMessage(i18n.t('common.myFavorites'));
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
          hideSongFile(ref, song.id);
        },
        onSeeArtist: () {
          _showMessage(i18n.t('context.seeArtist'));
        },
        onSeeAlbum: () {
          _showMessage(i18n.t('context.seeAlbum'));
        },
        onSeeMusicInfo: () {
          _showMessage(i18n.t('context.seeMusicInfo'));
        },
        onSeeLyrics: () {
          _showMessage(i18n.t('context.seeLyrics'));
        },
        onSeeAlbumArt: () {
          _showMessage(i18n.t('context.seeAlbumArt'));
        },
        onSeeLocal: () {
          _showMessage(song.path);
        },
      ),
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
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

class _NowPlayingLoadingState extends StatelessWidget {
  const _NowPlayingLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
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
