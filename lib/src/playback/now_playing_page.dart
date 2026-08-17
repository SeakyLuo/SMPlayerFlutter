import 'dart:async';
import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/exit_fullscreen_icon.dart';
import 'package:smplayer_flutter/src/app/shell_actions.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/app/loading_state.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart';
import 'package:smplayer_flutter/src/platform/desktop_feature_service.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_model.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_route.dart';
import 'package:smplayer_flutter/src/playback/now_playing_queue_view.dart';
import 'package:smplayer_flutter/src/playback/playback_queue_actions.dart';
import 'package:smplayer_flutter/src/playback/quick_play_model.dart';

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
  final _appBarPortalOwner = Object();
  String? _appBarPortalSignature;
  late final StateController<WorkspaceAppBarPortalEntry?> _appBarPortalNotifier;
  MusicDialogEntry? _songDialog;

  void _openImmersiveMode(SmPlayerShellActions? shellActions) {
    final navigate = shellActions?.onNavigate;
    if (navigate != null) {
      navigate(immersiveModeRoutePath);
      return;
    }
    context.go(immersiveModeRoutePath);
  }

  @override
  void initState() {
    super.initState();
    _appBarPortalNotifier = ref.read(workspaceAppBarPortalProvider.notifier);
  }

  @override
  void dispose() {
    _clearAppBarPortalOwner();
    _listController.dispose();
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
    required int queueLength,
    required int? currentSongId,
    required bool libraryCommandsEnabled,
  }) {
    final signature =
        '$showPortal:$routePath:$title:$queueLength:$currentSongId:$libraryCommandsEnabled:${_selection.multiSelect}';
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
    final snapshotValue = ref.watch(libraryContentDataProvider);
    final recentSongs =
        ref.watch(recentPageDataProvider).valueOrNull?.recentSongs ??
        const <RecentLibrarySong>[];
    final mediaState = ref.watch(
      mediaControlControllerProvider.select(
        (controller) => (
          trackId: controller.state.track.id,
          selectedQueueIndex: controller.state.selectedQueueIndex,
          isPlaying: controller.state.isPlaying,
        ),
      ),
    );
    final shellActions = ref.watch(smPlayerShellActionsProvider);
    final i18n = context.smPlayerI18n;

    return snapshotValue.when(
      loading: () => const _NowPlayingPagePanel(child: SmPlayerLoadingState()),
      error:
          (_, _) => _NowPlayingPagePanel(
            child: NowPlayingEmptyState(
              title: i18n.t('nowPlaying.noActiveTrack'),
            ),
          ),
      data: (snapshot) {
        final songsById = {for (final song in snapshot.songs) song.id: song};
        final queueOverride = ref.watch(nowPlayingQueueOverrideProvider);
        final sourceQueueSongIds = queueOverride ?? snapshot.nowPlaying.songIds;
        final queueSongs =
            sourceQueueSongIds
                .map((songId) => songsById[songId])
                .whereType<LibrarySong>()
                .toList();
        final queueSongIds = queueSongs.map((song) => song.id).toList();
        final queueEntries = queueSongs.indexed.toList();
        final visibleEntries =
            queueEntries
                .where((entry) => _matchesSearch(entry.$2, widget.searchQuery))
                .toList();
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
          mediaState.trackId,
          mediaState.selectedQueueIndex,
          queueSongs,
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
          currentPlaylistName: i18n.t('common.nowPlaying'),
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
        final useWorkspaceAppBar = WorkspaceNavigationAppBarScope.of(context);
        final appBarOverflowItems =
            queueSongs.isEmpty
                ? const <MenuFlyoutItem>[]
                : [
                  MenuFlyoutItem(
                    key: 'now-playing-appbar-locate-current',
                    text: i18n.t('nowPlaying.locateCurrent'),
                    icon: FluentIcons.music_note_2_20_regular,
                    disabled: currentSong == null,
                    onPressed: () {
                      _locateCurrent(
                        queueSongs,
                        mediaState.trackId,
                        mediaState.selectedQueueIndex,
                      );
                    },
                  ),
                  if (addQueueToItem != null)
                    MenuFlyoutItem(
                      key: 'now-playing-appbar-add-to-playlist',
                      text: i18n.t('context.addToPlaylist'),
                      icon: FluentIcons.add_20_regular,
                      submenu: addQueueToItem.submenu,
                    ),
                  MenuFlyoutItem(
                    key: 'now-playing-appbar-clear-queue',
                    text: i18n.t('nowPlaying.clearQueue'),
                    icon: FluentIcons.delete_20_regular,
                    onPressed: () {
                      _clearQueue(queueSongIds);
                    },
                  ),
                  MenuFlyoutItem(
                    key: 'now-playing-appbar-play-mode',
                    text: i18n.t('nowPlaying.playMode'),
                    useFullscreenIcon: true,
                    disabled: currentSong == null,
                    onPressed: () {
                      _openImmersiveMode(shellActions);
                    },
                  ),
                  MenuFlyoutItem(
                    key: 'now-playing-appbar-multi-select',
                    text: i18n.t('common.multiSelect'),
                    icon: FluentIcons.multiselect_ltr_20_regular,
                    onPressed: _toggleMultiSelect,
                  ),
                ];
        final appBarCommandBar = CommandBar(
          style: CommandBarStyleVariant.appBar,
          overflowLabel: i18n.t('player.more'),
          overflowItems: appBarOverflowItems,
          children: [
            CommandBarButton(
              icon: FluentIcons.play_20_regular,
              label: i18n.t('nowPlaying.quickPlay'),
              canOverflow: false,
              disabled: snapshot.songs.isEmpty,
              onPressed: () {
                unawaited(_quickPlay(snapshot));
              },
            ),
            CommandBarButton(
              iconWidget: const ShuffleIcon(),
              useShuffleIcon: true,
              label: i18n.t('nowPlaying.randomPlay'),
              canOverflow: false,
              disabled: snapshot.songs.isEmpty,
              onPressedWithContext: (buttonContext) {
                _showShuffleMenu(
                  buttonContext: buttonContext,
                  snapshot: snapshot,
                  queueSongs: queueSongs,
                  recentSongs: recentSongs,
                );
              },
            ),
          ],
        );
        _syncAppBarPortal(
          showPortal: true,
          routePath: '/now-playing',
          title:
              snapshot.showCount
                  ? i18n.t('nowPlaying.titleWithCount', {
                    'count': queueSongs.length,
                  })
                  : i18n.t('common.nowPlaying'),
          content: appBarCommandBar,
          queueLength: queueSongs.length,
          currentSongId: currentSong?.id,
          libraryCommandsEnabled: snapshot.songs.isNotEmpty,
        );

        final multiSelectCommandBar = MultiSelectCommandBar(
          visible: _selection.multiSelect,
          bottomInset: multiSelectCommandBarShellBottomInset,
          selectedCount: selectedVisibleSongIds.length,
          playlists: customPlaylists,
          addToSongIds: selectedVisibleSongIds,
          nowPlayingSongIds: queueSongIds,
          includeFavoritesInAddTo: selectedVisibleSongIds.any(
            (songId) => !songsById[songId]!.favorite,
          ),
          removeLabel: i18n.t('nowPlaying.remove'),
          hideAfterOperation: snapshot.hideMultiSelectCommandBarAfterOperation,
          onToggleFavorite: () {
            _addSongsToFavorites(
              selectedVisibleSongIds
                  .where((songId) => !songsById[songId]!.favorite)
                  .toList(),
              songsById,
            );
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
          },
          onPlay:
              selectedVisibleSongIds.isEmpty
                  ? null
                  : () {
                    _playSongIds(selectedVisibleSongIds);
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
        );

        return _NowPlayingPagePanel(
          overlay: multiSelectCommandBar,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  if (!useWorkspaceAppBar) ...[
                    CommandBar(
                      overflowLabel: i18n.t('player.more'),
                      children: [
                        CommandBarButton(
                          icon: FluentIcons.play_20_regular,
                          label: i18n.t('nowPlaying.quickPlay'),
                          disabled: snapshot.songs.isEmpty,
                          onPressed: () {
                            unawaited(_quickPlay(snapshot));
                          },
                        ),
                        CommandBarButton(
                          iconWidget: const ShuffleIcon(),
                          useShuffleIcon: true,
                          label: i18n.t('nowPlaying.randomPlay'),
                          disabled: snapshot.songs.isEmpty,
                          onPressedWithContext: (buttonContext) {
                            _showShuffleMenu(
                              buttonContext: buttonContext,
                              snapshot: snapshot,
                              queueSongs: queueSongs,
                              recentSongs: recentSongs,
                            );
                          },
                          onOverflowPressedWithContext: (buttonContext) {
                            unawaited(
                              showMenuFlyout(
                                buttonContext,
                                items: _buildShuffleMenuItems(
                                  snapshot: snapshot,
                                  queueSongs: queueSongs,
                                  recentSongs: recentSongs,
                                ),
                              ),
                            );
                          },
                        ),
                        if (queueSongs.isNotEmpty) ...[
                          CommandBarButton(
                            icon: FluentIcons.music_note_2_20_regular,
                            label: i18n.t('nowPlaying.locateCurrent'),
                            disabled: currentSong == null,
                            onPressed: () {
                              _locateCurrent(
                                queueSongs,
                                mediaState.trackId,
                                mediaState.selectedQueueIndex,
                              );
                            },
                          ),
                          CommandBarButton(
                            icon: FluentIcons.add_20_regular,
                            label: i18n.t('context.addToPlaylist'),
                            disabled: addQueueToItem == null,
                            onPressedWithContext: (buttonContext) {
                              if (addQueueToItem == null) {
                                return;
                              }
                              showMenuFlyout(
                                buttonContext,
                                items: addQueueToItem.submenu,
                              );
                            },
                            onOverflowPressedWithContext: (buttonContext) {
                              if (addQueueToItem == null) {
                                return;
                              }
                              unawaited(
                                showMenuFlyout(
                                  buttonContext,
                                  items: addQueueToItem.submenu,
                                ),
                              );
                            },
                          ),
                          CommandBarButton(
                            icon: FluentIcons.delete_20_regular,
                            label: i18n.t('nowPlaying.clearQueue'),
                            onPressed: () {
                              _clearQueue(queueSongIds);
                            },
                          ),
                          CommandBarButton(
                            iconWidget: const SmPlayerFullscreenIcon(),
                            label: i18n.t('nowPlaying.playMode'),
                            disabled: currentSong == null,
                            onPressed: () {
                              _openImmersiveMode(shellActions);
                            },
                          ),
                          CommandBarButton(
                            icon: FluentIcons.multiselect_ltr_20_regular,
                            label: i18n.t('common.multiSelect'),
                            active: _selection.multiSelect,
                            activeMatchesHover: true,
                            tooltip:
                                _selection.multiSelect
                                    ? i18n.t('common.exitMultiSelectTooltip')
                                    : null,
                            onPressed: _toggleMultiSelect,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: NowPlayingQueueView(
                      queueSongs: queueSongs,
                      visibleEntries: visibleEntries,
                      searchQuery: widget.searchQuery,
                      scrollController: _listController,
                      selectedQueueIndex: mediaState.selectedQueueIndex,
                      selectedTrackId: mediaState.trackId,
                      isPlaying: mediaState.isPlaying,
                      selectionMode: _selection.multiSelect,
                      isSelected: _selection.isSelected,
                      onReorderVisible: (oldIndex, newIndex) {
                        _moveVisibleQueueSongItem(
                          queueSongIds,
                          visibleQueueIndexes,
                          oldIndex,
                          newIndex,
                        );
                      },
                      onPlayQueueTrack: (song, queueIndex) {
                        _playQueueTrack(song, queueSongIds, queueIndex);
                      },
                      onTogglePlayPause:
                          ref
                              .read(mediaControlControllerProvider)
                              .onTogglePlayPause,
                      onToggleQueueSelection: _toggleQueueSelection,
                      onToggleFavorite: (song) {
                        unawaited(
                          setSongsFavorite(ref, [song.id], !song.favorite),
                        );
                      },
                      onOpenAddToPlaylist: (buttonContext, song) {
                        _showQueueAddToPlaylistMenu(
                          buttonContext,
                          song,
                          customPlaylists,
                          snapshot.playlists,
                          songsById,
                        );
                      },
                      onRemoveQueueIndex: (queueIndex, song) {
                        _removeQueueIndex(queueSongIds, queueIndex, song);
                      },
                      onOpenArtist: (artist) {
                        context.go(
                          '/artists?artist=${Uri.encodeQueryComponent(artist)}',
                        );
                      },
                      onOpenAlbum: (album) {
                        context.go(
                          '/albums?album=${Uri.encodeQueryComponent(album)}',
                        );
                      },
                      onOpenContextMenu: (position, song, queueIndex) {
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
                      compactScrollbarTrailingOffset: 8,
                    ),
                  ),
                ],
              ),
              if (_songDialog case final dialog?)
                MusicDialog(
                  song: dialog.song,
                  initialMode: dialog.mode,
                  currentTrackId: mediaState.trackId,
                  isPlaying: mediaState.isPlaying,
                  queueSongIds: dialog.queueSongIds,
                  onPlay:
                      ref
                          .read(mediaControlControllerProvider)
                          .onTogglePlayPause,
                  onPlayTrack: (trackId, nextQueueSongIds) {
                    final song = songsById[trackId]!;
                    _playQueueTrack(
                      song,
                      nextQueueSongIds,
                      nextQueueSongIds.indexOf(trackId),
                    );
                  },
                  onReveal: _revealPath,
                  onSaved: () {
                    notifyLyricsSaved(ref, dialog.song.id);
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
    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).value!,
      i18n: context.smPlayerI18n,
      songIds: queueSongIds,
      queueIndex: queueIndex,
    );
  }

  void _playSongIds(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }

    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).value!,
      i18n: context.smPlayerI18n,
      songIds: songIds,
      queueIndex: 0,
    );
  }

  Future<void> _quickPlay(LibraryContentData snapshot) async {
    final repository = ref.read(libraryRepositoryProvider);
    final preferences = await repository.getPreferenceSettings();
    if (!mounted) {
      return;
    }
    _playSongIds(
      quickPlaySongIds(
        songs: snapshot.songs,
        playlists: snapshot.playlists,
        folders: snapshot.folders,
        preferences: preferences,
        randomLimit: quickPlayLimit,
      ),
    );
  }

  void _replaceQueue(List<int> songIds) {
    final snapshot = ref.read(libraryContentDataProvider).value;
    final queueOverride = ref.read(nowPlayingQueueOverrideProvider);
    final currentSongIds = queueOverride ?? snapshot?.nowPlaying.songIds;
    if (currentSongIds != null) {
      syncMediaControlForQueueChange(
        mediaController: ref.read(mediaControlControllerProvider),
        currentSongIds: currentSongIds,
        nextSongIds: songIds,
      );
    }
    if (currentSongIds != null && _sameSongIds(currentSongIds, songIds)) {
      return;
    }
    setNowPlayingQueue(ref, songIds);
  }

  void _removeQueueIndex(
    List<int> queueSongIds,
    int queueIndex,
    LibrarySong song,
  ) {
    final before = queueSongIds.toList();
    final nextQueueSongIds = [
      for (var index = 0; index < queueSongIds.length; index += 1)
        if (index != queueIndex) queueSongIds[index],
    ];
    final nextPlayingQueueIndex = _nextQueueIndexAfterRemovingCurrentPlaying(
      queueSongIds,
      {queueIndex},
      nextQueueSongIds,
    );
    _replaceQueue(nextQueueSongIds);
    if (nextPlayingQueueIndex != null) {
      _playQueueSongAt(nextQueueSongIds, nextPlayingQueueIndex);
    }
    _showUndo(
      context.smPlayerI18n.t('notification.removedFrom', {
        'title': song.title,
        'target': context.smPlayerI18n.t('common.nowPlaying'),
      }),
      () => _replaceQueue(before),
    );
  }

  int? _nextQueueIndexAfterRemovingCurrentPlaying(
    List<int> queueSongIds,
    Set<int> removedIndexes,
    List<int> nextQueueSongIds,
  ) {
    final currentQueueIndex = _currentPlayingQueueIndex(queueSongIds);
    if (currentQueueIndex == null ||
        !removedIndexes.contains(currentQueueIndex) ||
        nextQueueSongIds.isEmpty) {
      return null;
    }
    var nextQueueIndex = 0;
    for (var index = 0; index < currentQueueIndex; index += 1) {
      if (!removedIndexes.contains(index)) {
        nextQueueIndex += 1;
      }
    }
    return nextQueueIndex < nextQueueSongIds.length ? nextQueueIndex : 0;
  }

  int? _currentPlayingQueueIndex(List<int> queueSongIds) {
    final mediaState = ref.read(mediaControlControllerProvider).state;
    if (!mediaState.isPlaying) {
      return null;
    }
    final trackId = mediaState.track.id;
    if (trackId == null) {
      return null;
    }
    final queueIndex = mediaState.selectedQueueIndex;
    if (queueIndex != null &&
        queueIndex >= 0 &&
        queueIndex < queueSongIds.length &&
        queueSongIds[queueIndex] == trackId) {
      return queueIndex;
    }
    final trackIndex = queueSongIds.indexOf(trackId);
    return trackIndex == -1 ? null : trackIndex;
  }

  void _playQueueSongAt(List<int> queueSongIds, int queueIndex) {
    playQueueIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).value!,
      i18n: context.smPlayerI18n,
      songIds: queueSongIds,
      queueIndex: queueIndex,
    );
  }

  void _moveQueueSongItem(List<int> queueSongIds, int oldIndex, int newIndex) {
    final nextSongIds = queueSongIds.toList();
    final songId = nextSongIds.removeAt(oldIndex);
    nextSongIds.insert(newIndex, songId);
    _replaceQueue(nextSongIds);
  }

  void _moveVisibleQueueSongItem(
    List<int> queueSongIds,
    List<int> visibleQueueIndexes,
    int oldVisibleIndex,
    int newVisibleIndex,
  ) {
    final oldQueueIndex = visibleQueueIndexes[oldVisibleIndex];
    final targetQueueIndex =
        newVisibleIndex >= visibleQueueIndexes.length
            ? queueSongIds.length
            : visibleQueueIndexes[newVisibleIndex];
    _moveQueueSongItem(queueSongIds, oldQueueIndex, targetQueueIndex);
  }

  void _toggleMultiSelect() {
    setState(() {
      _selection.toggleMultiSelect();
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
    final selectedIndexSet = selectedIndexes.toSet();
    final nextQueueSongIds = [
      for (var index = 0; index < queueSongIds.length; index += 1)
        if (!selectedIndexSet.contains(index)) queueSongIds[index],
    ];
    final nextPlayingQueueIndex = _nextQueueIndexAfterRemovingCurrentPlaying(
      queueSongIds,
      selectedIndexSet,
      nextQueueSongIds,
    );
    _replaceQueue(nextQueueSongIds);
    if (nextPlayingQueueIndex != null) {
      _playQueueSongAt(nextQueueSongIds, nextPlayingQueueIndex);
    }
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
        nowPlayingSongIds: queueSongIds,
        currentPlaylistName: i18n.t('common.nowPlaying'),
        songPath: song.path,
        playlists: playlists,
        folders: folders,
        showRemove: true,
        showDelete: true,
        preferenceLevel: preferenceLevel,
        onUndoPreference:
            preferenceLevel == null
                ? null
                : () {
                  unawaited(
                    ref
                        .read(libraryRepositoryProvider)
                        .removePreferenceItem('song', '${song.id}'),
                  );
                },
        onPlay: () {
          _playQueueTrack(song, queueSongIds, queueIndex);
        },
        onTogglePlayPause:
            ref.read(mediaControlControllerProvider).onTogglePlayPause,
        onPlayNext: null,
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
          final artist = primaryDisplayArtist(song, i18n);
          context.go('/artists?artist=${Uri.encodeQueryComponent(artist)}');
        },
        onSeeAlbum: () {
          final album = displayAlbum(song, i18n);
          context.go('/albums?album=${Uri.encodeQueryComponent(album)}');
        },
        onSeeMusicInfo: () {
          setState(() {
            _songDialog = (
              song: song,
              mode: SongDialogMode.properties,
              queueSongIds: queueSongIds,
            );
          });
        },
        onSeeLyrics: () {
          setState(() {
            _songDialog = (
              song: song,
              mode: SongDialogMode.lyrics,
              queueSongIds: queueSongIds,
            );
          });
        },
        onSeeAlbumArt: () {
          setState(() {
            _songDialog = (
              song: song,
              mode: SongDialogMode.albumArt,
              queueSongIds: queueSongIds,
            );
          });
        },
        onSeeLocal: () {
          _revealPath(song.path);
        },
      ),
    );
  }

  LibrarySong? _resolveCurrentSong(
    int? trackId,
    int? selectedQueueIndex,
    List<LibrarySong> queueSongs,
  ) {
    final queueIndex = selectedQueueIndex;
    if (queueIndex != null &&
        queueIndex >= 0 &&
        queueIndex < queueSongs.length) {
      return queueSongs[queueIndex];
    }

    if (trackId == null) {
      return null;
    }
    return queueSongs.where((song) => song.id == trackId).firstOrNull;
  }

  void _showShuffleMenu({
    required BuildContext buttonContext,
    required LibraryContentData snapshot,
    required List<LibrarySong> queueSongs,
    required List<LibrarySong> recentSongs,
  }) {
    showMenuFlyout(
      buttonContext,
      items: _buildShuffleMenuItems(
        snapshot: snapshot,
        queueSongs: queueSongs,
        recentSongs: recentSongs,
      ),
    );
  }

  List<MenuFlyoutItem> _buildShuffleMenuItems({
    required LibraryContentData snapshot,
    required List<LibrarySong> queueSongs,
    required List<LibrarySong> recentSongs,
  }) {
    return buildShuffleMenuFlyoutItems(
      i18n: context.smPlayerI18n,
      songs: queueSongs,
      librarySongs: snapshot.songs,
      recentSongs: recentSongs,
      playlists: snapshot.playlists,
      folders: snapshot.folders,
      randomLimit: quickPlayLimit,
      onPlaySongs: _playSongIds,
      onQuickPlay: () => _quickPlay(snapshot),
    );
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
    await addSongsToPlaylistWithUndo(
      context: context,
      ref: ref,
      i18n: context.smPlayerI18n,
      playlistId: playlistId,
      songIds: songIds,
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

  void _showQueueAddToPlaylistMenu(
    BuildContext buttonContext,
    LibrarySong song,
    List<MultiSelectCommandBarPlaylist> playlists,
    List<LibraryPlaylist> allPlaylists,
    Map<int, LibrarySong> songsById,
  ) {
    final box = buttonContext.findRenderObject() as RenderBox;
    final position = box.localToGlobal(Offset(0, box.size.height + 8));
    final i18n = context.smPlayerI18n;
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: [song.id],
      playlists: playlists,
      currentPlaylistName: i18n.t('common.nowPlaying'),
      includeFavorites: !song.favorite,
      onToggleFavorite:
          song.favorite
              ? null
              : () {
                _addSongsToFavorites([song.id], songsById);
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
    );
    showMenuFlyout(context, position: position, items: addToItem!.submenu);
  }

  Future<void> _hideQueueSongFileWithUndo(
    LibrarySong song,
    List<int> queueSongIds,
  ) async {
    final removedEntries = _queueEntriesForSong(queueSongIds, song.id);
    await ref.read(libraryRepositoryProvider).hideSong(song.id);
    ref.invalidate(libraryContentDataProvider);
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
        ref.invalidate(libraryContentDataProvider);
        final snapshot =
            await ref.read(libraryRepositoryProvider).getLibraryContentData();
        final currentQueueSongIds =
            ref.read(nowPlayingQueueOverrideProvider) ??
            snapshot.nowPlaying.songIds;
        _replaceQueue(_insertQueueEntries(currentQueueSongIds, removedEntries));
      },
    );
  }

  Future<void> _revealPath(String targetPath) async {
    await revealItemInFolder(targetPath);
  }

  void _showUndo(String message, FutureOr<void> Function() action) {
    showUndoableNotification(
      context: context,
      i18n: context.smPlayerI18n,
      message: message,
      onUndo: () async {
        if (!mounted) {
          return;
        }
        await action();
      },
    );
  }

  void _locateCurrent(
    List<LibrarySong> queueSongs,
    int? trackId,
    int? selectedQueueIndex,
  ) {
    final index =
        selectedQueueIndex ??
        queueSongs.indexWhere((song) => song.id == trackId);
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

  return searchableSongText(song).toLowerCase().contains(normalizedSearchQuery);
}

bool _sameSongIds(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
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
  const _NowPlayingPagePanel({required this.child, this.overlay});

  final Widget child;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 720;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShellThemeColors.of(context).workspaceSolidSurface,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding:
                compact
                    ? const EdgeInsets.fromLTRB(8, 0, 8, 0)
                    : const EdgeInsets.fromLTRB(14, 12, 14, 24),
            child: SizedBox.expand(child: child),
          ),
          if (overlay != null) Positioned.fill(child: overlay!),
        ],
      ),
    );
  }
}
