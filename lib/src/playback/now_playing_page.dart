import '../library/data/library_repository.dart';
import '../library/data/library_source.dart';
import 'package:smplayer_flutter/src/remote/music_source_selector.dart';
import 'package:smplayer_flutter/src/remote/music_share_models.dart';
import 'source_random_play.dart';
import 'package:smplayer_flutter/src/playback/source_quick_play.dart';
import 'package:smplayer_flutter/src/library/ui/library_load_failure.dart';
import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:smplayer_flutter/src/playback/immersive_mode_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/now_playing_queue_view.dart';
import 'package:smplayer_flutter/src/playback/playback_queue_actions.dart';

part 'now_playing_page_actions.dart';
part 'now_playing_page_query.dart';

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
  final _attemptedWindows = <int>{};

  @override
  void initState() {
    super.initState();
    _appBarPortalNotifier = ref.read(workspaceAppBarPortalProvider.notifier);
    _listController.addListener(_attemptedWindows.clear);
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
    required bool compact,
  }) {
    final signature =
        '$showPortal:$routePath:$title:$queueLength:$currentSongId:$libraryCommandsEnabled:$compact:${_selection.multiSelect}';
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

  void _updateNowPlayingPageState(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) {
    final queueOverride = ref.watch(nowPlayingQueueOverrideProvider);
    final contextValue = ref.watch(libraryContentDataProvider);
    if (!contextValue.hasValue) {
      return contextValue.hasError
          ? LibraryLoadFailure(
            onRetry: () => ref.invalidate(libraryLoadedDataProvider),
          )
          : const SmPlayerLoadingState();
    }
    final allQueueIds =
        queueOverride ?? contextValue.requireValue.nowPlaying.songIds;
    final searchQuery = LibraryDataQuery(
      LibraryQueryKind.queue,
      songIds: allQueueIds,
      text: widget.searchQuery,
    );
    final searchValue =
        widget.searchQuery.isEmpty
            ? AsyncData(allQueueIds)
            : ref.watch(_queueSearchIdsProvider(searchQuery));
    if (!searchValue.hasValue)
      return searchValue.hasError
          ? LibraryLoadFailure(
            onRetry: () => ref.invalidate(_queueSearchIdsProvider(searchQuery)),
          )
          : const SmPlayerLoadingState();
    final matchingIds = searchValue.requireValue.toSet();
    final matchingIndexes = [
      for (var index = 0; index < allQueueIds.length; index++)
        if (matchingIds.contains(allQueueIds[index])) index,
    ];
    final query = LibraryDataQuery(
      LibraryQueryKind.queue,
      limit: 200,
      useSongIds: true,
      songIds: [for (final index in matchingIndexes) allQueueIds[index]],
    );
    final snapshotValue = ref.watch(libraryPagedQueryProvider(query));
    final recentSongs = ref.watch(recentSongsProvider);
    ref.watch(libraryPlaylistOverridesProvider);
    ref.watch(libraryDeletedPlaylistIdsProvider);
    ref.watch(libraryPlaylistOrderProvider);
    final mediaState = ref.watch(
      mediaControlControllerProvider.select(
        (controller) => (
          trackId: controller.state.track.id,
          selectedQueueIndex: controller.state.selectedQueueIndex,
          isPlaying: controller.state.isPlaying,
        ),
      ),
    );
    final i18n = context.smPlayerI18n;
    final compact = MediaQuery.sizeOf(context).width <= 720;

    return snapshotValue.when(
      skipLoadingOnReload: true,
      skipError: true,
      loading: () => const _NowPlayingPagePanel(child: SmPlayerLoadingState()),
      error: (_, _) => const _NowPlayingPagePanel(child: LibraryLoadFailure()),
      data: (snapshot) {
        final songsById = {for (final song in snapshot.songs) song.id: song};
        final sourceQueueSongIds = allQueueIds;
        final queueSongs = snapshot.songs;
        final queueSongIds = sourceQueueSongIds;
        final queueEntries =
            snapshot.songRows.entries
                .map((entry) => (matchingIndexes[entry.key], entry.value))
                .toList();
        final visibleEntries = queueEntries;
        final visibleQueueIndexes = matchingIndexes;
        final selectedVisibleQueueIndexes =
            visibleQueueIndexes.where(_selection.isSelected).toList();
        final selectedVisibleSongIds =
            selectedVisibleQueueIndexes
                .map((index) => queueSongIds[index])
                .toList();
        final currentSong = _resolveCurrentSong(
          mediaState.trackId,
          mediaState.selectedQueueIndex,
          contextValue.requireValue.songs,
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
            _effectivePlaylists(snapshot.playlists)
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
          includeFavorites: queueSongIds.isNotEmpty,
          onToggleFavorite:
              queueSongIds.isNotEmpty
                  ? () {
                    _addSongsToFavorites(queueSongIds, songsById);
                  }
                  : null,
          onCreatePlaylist: () {
            unawaited(
              createPlaylistWithSongs(
                context: context,
                ref: ref,
                i18n: i18n,
                playlists: _effectivePlaylists(snapshot.playlists),
                defaultName: getDefaultNewPlaylistName(
                  i18n,
                  _effectivePlaylists(snapshot.playlists),
                ),
                songIds: queueSongIds,
              ),
            );
          },
          onAddToPlaylist: (playlistId) async {
            await _addSongsToPlaylistWithUndo(
              playlistId,
              queueSongIds,
              _effectivePlaylists(snapshot.playlists),
              songsById,
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
                    icon: FluentIcons.headphones_20_regular,
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
                    icon: FluentIcons.broom_20_regular,
                    onPressed: () {
                      _clearQueue(queueSongIds);
                    },
                  ),
                  MenuFlyoutItem(
                    key: 'now-playing-appbar-multi-select',
                    text: i18n.t('common.multiSelect'),
                    icon: FluentIcons.multiselect_ltr_20_regular,
                    onPressed: _toggleMultiSelect,
                  ),
                ];
        final appBarCommandBar =
            snapshot.songs.isEmpty
                ? const SizedBox.shrink()
                : CommandBar(
                  style: CommandBarStyleVariant.appBar,
                  overflowLabel: i18n.t('player.more'),
                  overflowItems: appBarOverflowItems,
                  children: [
                    CommandBarButton(
                      icon: FluentIcons.play_20_regular,
                      label: i18n.t('nowPlaying.quickPlay'),
                      canOverflow: false,
                      showLabel: !compact,
                      onPressed: () {
                        unawaited(_quickPlay());
                      },
                    ),
                    CommandBarButton(
                      iconWidget: const ShuffleIcon(),
                      useShuffleIcon: true,
                      label: i18n.t('nowPlaying.randomPlay'),
                      canOverflow: false,
                      showLabel: !compact,
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
                    'count': queueSongIds.length,
                  })
                  : i18n.t('common.nowPlaying'),
          content: appBarCommandBar,
          queueLength: queueSongIds.length,
          currentSongId: currentSong?.id,
          libraryCommandsEnabled: snapshot.songs.isNotEmpty,
          compact: compact,
        );

        final multiSelectCommandBar = MultiSelectCommandBar(
          visible: _selection.multiSelect,
          bottomInset: multiSelectCommandBarShellBottomInset,
          selectedCount: selectedVisibleSongIds.length,
          showPlay: false,
          playlists: customPlaylists,
          addToSongIds: selectedVisibleSongIds,
          nowPlayingSongIds: queueSongIds,
          includeFavoritesInAddTo: selectedVisibleSongIds.isNotEmpty,
          removeLabel: i18n.t('nowPlaying.remove'),
          hideAfterOperation: snapshot.hideMultiSelectCommandBarAfterOperation,
          onToggleFavorite: () {
            _addSongsToFavorites(selectedVisibleSongIds, songsById);
          },
          onCreatePlaylist: () {
            unawaited(
              createPlaylistWithSongs(
                context: context,
                ref: ref,
                i18n: i18n,
                playlists: _effectivePlaylists(snapshot.playlists),
                defaultName: getDefaultNewPlaylistName(
                  i18n,
                  _effectivePlaylists(snapshot.playlists),
                ),
                songIds: selectedVisibleSongIds,
              ),
            );
          },
          onAddToPlaylist: (playlistId) async {
            await _addSongsToPlaylistWithUndo(
              playlistId,
              selectedVisibleSongIds,
              _effectivePlaylists(snapshot.playlists),
              songsById,
            );
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
                  if (!useWorkspaceAppBar && snapshot.songs.isNotEmpty) ...[
                    CommandBar(
                      overflowLabel: i18n.t('player.more'),
                      children: [
                        CommandBarButton(
                          icon: FluentIcons.play_20_regular,
                          label: i18n.t('nowPlaying.quickPlay'),
                          onPressed: () {
                            unawaited(_quickPlay());
                          },
                        ),
                        CommandBarButton(
                          iconWidget: const ShuffleIcon(),
                          useShuffleIcon: true,
                          label: i18n.t('nowPlaying.randomPlay'),
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
                              _showShuffleMenu(
                                buttonContext: buttonContext,
                                snapshot: snapshot,
                                queueSongs: queueSongs,
                                recentSongs: recentSongs,
                              ),
                            );
                          },
                        ),
                        if (queueSongs.isNotEmpty) ...[
                          CommandBarButton(
                            icon: FluentIcons.headphones_20_regular,
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
                            icon: FluentIcons.broom_20_regular,
                            label: i18n.t('nowPlaying.clearQueue'),
                            onPressed: () {
                              _clearQueue(queueSongIds);
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
                      totalCount: matchingIndexes.length,
                      queueIndexAt: (index) => matchingIndexes[index],
                      songAt: (index) => snapshot.songRows[index],
                      onAccessRow: (index) {
                        final offset = index ~/ 200 * 200;
                        if (!_attemptedWindows.add(offset)) return;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          unawaited(
                            runMusicShareAction(context, () async {
                              await ref
                                  .read(
                                    libraryPagedQueryProvider(query).notifier,
                                  )
                                  .loadWindow(index);
                            }),
                          );
                        });
                      },
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
                      onToggleFavorite: (song) async {
                        await setSongsFavoriteFromControl(ref, [
                          song.id,
                        ], !song.favorite);
                      },
                      onOpenAddToPlaylist: (buttonContext, song) {
                        return _showQueueAddToPlaylistMenu(
                          buttonContext,
                          song,
                          customPlaylists,
                          _effectivePlaylists(snapshot.playlists),
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
                        return _showQueueContextMenu(
                          position,
                          song,
                          queueSongIds,
                          queueIndex,
                          customPlaylists,
                          folders,
                          _effectivePlaylists(snapshot.playlists),
                          songsById,
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
                    replaceNowPlayingQueueAndPlayIndex(
                      ref: ref,
                      snapshot: snapshot,
                      i18n: i18n,
                      songIds: nextQueueSongIds,
                      queueIndex: nextQueueSongIds.indexOf(trackId),
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
