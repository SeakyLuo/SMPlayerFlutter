import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_interaction_colors.dart';
import '../../app/loading_state.dart';
import '../../app/smplayer_vector_icons.dart';
import '../../app/undoable_notification.dart';
import '../../app/workspace_app_bar_portal.dart';
import '../../i18n/app_i18n.dart';
import '../../playback/media_control_provider.dart';
import '../../playback/media_control_track_factory.dart';
import '../../playback/playing_wave.dart';
import '../data/library_models.dart';
import '../data/library_time_codec.dart';
import '../data/library_providers.dart';
import 'artwork_floating_action_button.dart';
import 'artists_page_model.dart'
    show compareArtistText, getArtistQuickJumpBucket, getSongArtists;
import 'command_bar.dart';
import 'menu_flyout.dart';
import 'menu_flyout_helpers.dart';
import 'headered_playlist_model.dart' show getNextPlaylistName;
import 'library_page_actions.dart';
import 'music_dialog.dart';
import 'page_selection_store.dart';
import 'quick_jump_tooltip.dart';
import 'song_display_helpers.dart' as song_display;
import 'song_artwork.dart';
import '../../platform/desktop_feature_service.dart';

part 'music_library_table.dart';
part 'music_library_rows.dart';
part 'music_library_quick_jump.dart';
part 'music_library_helpers.dart';

const _quickJumpKeys = [
  '#',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];
const _wideVirtualRowHeight = 58.0;
const _compactVirtualRowHeight = 76.0;
const _minColumnWidth = 86.0;

enum _LibraryColumn {
  artwork,
  title,
  artist,
  album,
  duration,
  favorite,
  playCount,
  dateAdded,
}

const _defaultColumnWidths = {
  _LibraryColumn.artwork: 66.0,
  _LibraryColumn.title: 280.0,
  _LibraryColumn.artist: 200.0,
  _LibraryColumn.album: 240.0,
  _LibraryColumn.duration: 110.0,
  _LibraryColumn.favorite: 96.0,
  _LibraryColumn.playCount: 120.0,
  _LibraryColumn.dateAdded: 170.0,
};

class MusicLibraryPage extends ConsumerStatefulWidget {
  const MusicLibraryPage({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  ConsumerState<MusicLibraryPage> createState() => _MusicLibraryPageState();
}

class _MusicLibraryPageState extends ConsumerState<MusicLibraryPage> {
  var _sortCriterion = MusicLibrarySortCriterion.title;
  var _snapshotSortCriterion = MusicLibrarySortCriterion.title;
  var _sortDirection = MusicLibrarySortDirection.ascending;
  var _quickJumpPanelOpen = false;
  String? _quickJumpPinnedKey;
  var _scrollOffset = 0.0;
  final _columnWidths = {..._defaultColumnWidths};
  final _scrollController = ScrollController();
  final _selection = PageSelectionController<int>.stored('music-library');
  final _appBarPortalOwner = Object();
  String? _appBarPortalSignature;
  late final StateController<WorkspaceAppBarPortalEntry?> _appBarPortalNotifier;
  MusicDialogEntry? _musicDialog;

  @override
  void initState() {
    super.initState();
    _appBarPortalNotifier = ref.read(workspaceAppBarPortalProvider.notifier);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _clearAppBarPortalOwner();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
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
    required bool active,
  }) {
    final signature = '$showPortal:$routePath:$title:$active';
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
        content: CommandBar(
          style: CommandBarStyleVariant.appBar,
          dynamicOverflow: false,
          children: [
            CommandBarButton(
              key: const ValueKey('MusicLibrary.QuickJumpToggle'),
              label: '#-Z',
              active: active,
              canOverflow: false,
              minWidth: 40,
              maxWidth: 40,
              horizontalPadding: 0,
              onPressed: () {
                setState(() {
                  _quickJumpPanelOpen = !_quickJumpPanelOpen;
                });
              },
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(libraryContentDataProvider);
    final favoriteOverrides = ref.watch(libraryFavoriteOverridesProvider);
    final songOverrides = ref.watch(librarySongOverridesProvider);

    if (i18nValue.isLoading) {
      return const _LibraryScaffold(child: SmPlayerLoadingState());
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const _LibraryScaffold(child: SmPlayerLoadingState());
    }

    return snapshotValue.when(
      loading: () => const _LibraryScaffold(child: SmPlayerLoadingState()),
      error:
          (_, _) => _LibraryScaffold(
            child: _EmptyState(
              title: i18n.t('remoteShare.libraryLoadFailed'),
              message: i18n.t('library.scanHelp'),
            ),
          ),
      data: (snapshot) {
        if (_snapshotSortCriterion != snapshot.sortCriterion) {
          _snapshotSortCriterion = snapshot.sortCriterion;
          _sortCriterion = snapshot.sortCriterion;
          _sortDirection = MusicLibrarySortDirection.ascending;
        }

        if (snapshot.songs.isEmpty) {
          return _LibraryScaffold(
            child: _EmptyState(
              title:
                  snapshot.hasLibrary
                      ? i18n.t('library.noSearchMatch', {
                        'query': widget.searchQuery,
                      })
                      : i18n.t('library.scanToBegin'),
              message:
                  snapshot.hasLibrary
                      ? i18n.t('library.tryAnotherSearch')
                      : i18n.t('library.scanHelp'),
            ),
          );
        }

        final songs = applyFavoriteOverridesToSongs(
          snapshot.songs,
          favoriteOverrides,
          songOverrides,
        );
        final sortedSongs = _sortSongs(songs, i18n);
        final mediaState = ref.watch(mediaControlControllerProvider).state;
        final quickJumpMap = _buildQuickJumpMap(
          sortedSongs,
          _sortCriterion,
          i18n,
        );

        return SmPlayerI18nScope(
          i18n: i18n,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final colors = _LibraryPalette.of(context);
              final compact = constraints.maxWidth < 720;
              final useWorkspaceAppBar = WorkspaceNavigationAppBarScope.of(
                context,
              );
              _syncAppBarPortal(
                showPortal: true,
                routePath: '/songs',
                title:
                    snapshot.showCount
                        ? i18n.t('library.allSongsWithCount', {
                          'count': sortedSongs.length,
                        })
                        : i18n.t('library.allSongs'),
                active: _quickJumpPanelOpen,
              );
              if (!compact && _quickJumpPanelOpen) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _quickJumpPanelOpen = false;
                    });
                  }
                });
              }
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
              final activeQuickJumpKey = _activeQuickJumpKey(
                sortedSongs,
                compact,
                i18n,
              );
              return Stack(
                children: [
                  _LibraryScaffold(
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.escape): () {
                          if (_quickJumpPanelOpen) {
                            setState(() {
                              _quickJumpPanelOpen = false;
                            });
                          }
                        },
                      },
                      child: Focus(
                        child: NotificationListener<UserScrollNotification>(
                          onNotification: _handleUserScroll,
                          child: Stack(
                            children: [
                              DecoratedBox(
                                key: const ValueKey(
                                  'MusicLibrary.ContentShell',
                                ),
                                decoration: BoxDecoration(
                                  color: colors.panel,
                                  gradient: colors.panelGradient,
                                  borderRadius: BorderRadius.circular(
                                    compact ? 10 : 14,
                                  ),
                                  border: Border.all(color: colors.panelBorder),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.panelShadow,
                                      offset: Offset(0, 22),
                                      blurRadius: 52,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    compact ? 10 : 14,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(compact ? 4 : 10),
                                    child: Row(
                                      children: [
                                        if (!compact)
                                          _QuickJumpRail(
                                            activeKey: activeQuickJumpKey,
                                            keys: _quickJumpKeysForDirection(
                                              _sortDirection,
                                            ),
                                            enabledKeys:
                                                quickJumpMap.keys.toSet(),
                                            targetName: i18n.t('common.songs'),
                                            basisName:
                                                _libraryQuickJumpBasisName(
                                                  _sortCriterion,
                                                  i18n,
                                                ),
                                            i18n: i18n,
                                            onJump: (key) {
                                              _jumpToKey(
                                                quickJumpMap,
                                                key,
                                                compact,
                                              );
                                            },
                                          ),
                                        Expanded(
                                          child:
                                              compact
                                                  ? _CompactSongList(
                                                    songs: sortedSongs,
                                                    scrollController:
                                                        _scrollController,
                                                    sortCriterion:
                                                        _sortCriterion,
                                                    sortDirection:
                                                        _sortDirection,
                                                    selectedSongIds:
                                                        _selection
                                                            .selectedItems,
                                                    selectedTrackId:
                                                        mediaState.track.id,
                                                    isPlaying:
                                                        mediaState.isPlaying,
                                                    multiSelect:
                                                        _selection.multiSelect,
                                                    i18n: i18n,
                                                    onSort: _toggleSort,
                                                    onSelected: (songId) {
                                                      _selectSongFromPointer(
                                                        songId,
                                                        sortedSongs.map(
                                                          (song) => song.id,
                                                        ),
                                                      );
                                                    },
                                                    onAddNextAndPlay: (songId) {
                                                      _addNextAndPlay(songId);
                                                    },
                                                    onTogglePlayPause:
                                                        ref
                                                            .read(
                                                              mediaControlControllerProvider,
                                                            )
                                                            .onTogglePlayPause,
                                                    onToggleSelection:
                                                        _toggleSongSelection,
                                                    onToggleFavorite: (songId) {
                                                      final song = sortedSongs
                                                          .firstWhere(
                                                            (song) =>
                                                                song.id ==
                                                                songId,
                                                          );
                                                      setSongsFavorite(ref, [
                                                        songId,
                                                      ], !song.favorite);
                                                    },
                                                    onPlayNext: _playNext,
                                                    onOpenAddToPlaylistMenu: (
                                                      buttonContext,
                                                      song,
                                                    ) {
                                                      _showSongAddToMenu(
                                                        buttonContext,
                                                        song,
                                                        customPlaylists,
                                                      );
                                                    },
                                                    onOpenContextMenu: (
                                                      position,
                                                      song,
                                                    ) {
                                                      _openSongContextMenu(
                                                        position,
                                                        song,
                                                        sortedSongs,
                                                        customPlaylists,
                                                      );
                                                    },
                                                  )
                                                  : _WideSongTable(
                                                    songs: sortedSongs,
                                                    sortCriterion:
                                                        _sortCriterion,
                                                    sortDirection:
                                                        _sortDirection,
                                                    scrollController:
                                                        _scrollController,
                                                    selectedSongIds:
                                                        _selection
                                                            .selectedItems,
                                                    selectedTrackId:
                                                        mediaState.track.id,
                                                    isPlaying:
                                                        mediaState.isPlaying,
                                                    multiSelect:
                                                        _selection.multiSelect,
                                                    i18n: i18n,
                                                    columnWidths: _columnWidths,
                                                    onSort: _toggleSort,
                                                    onResizeColumn:
                                                        _resizeColumn,
                                                    onSelected: (songId) {
                                                      _selectSongFromPointer(
                                                        songId,
                                                        sortedSongs.map(
                                                          (song) => song.id,
                                                        ),
                                                      );
                                                    },
                                                    onAddNextAndPlay: (songId) {
                                                      _addNextAndPlay(songId);
                                                    },
                                                    onTogglePlayPause:
                                                        ref
                                                            .read(
                                                              mediaControlControllerProvider,
                                                            )
                                                            .onTogglePlayPause,
                                                    onToggleSelection:
                                                        _toggleSongSelection,
                                                    onToggleFavorite: (songId) {
                                                      final song = sortedSongs
                                                          .firstWhere(
                                                            (song) =>
                                                                song.id ==
                                                                songId,
                                                          );
                                                      setSongsFavorite(ref, [
                                                        songId,
                                                      ], !song.favorite);
                                                    },
                                                    onPlayNext: _playNext,
                                                    onOpenAddToPlaylistMenu: (
                                                      buttonContext,
                                                      song,
                                                    ) {
                                                      _showSongAddToMenu(
                                                        buttonContext,
                                                        song,
                                                        customPlaylists,
                                                      );
                                                    },
                                                    onOpenContextMenu: (
                                                      position,
                                                      song,
                                                    ) {
                                                      _openSongContextMenu(
                                                        position,
                                                        song,
                                                        sortedSongs,
                                                        customPlaylists,
                                                      );
                                                    },
                                                  ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (!compact)
                                Positioned(
                                  top: 54,
                                  right: 2,
                                  bottom: 10,
                                  width: 10,
                                  child: _MusicLibraryTableScrollbar(
                                    controller: _scrollController,
                                  ),
                                ),
                              if (compact && !useWorkspaceAppBar)
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: _CompactQuickJumpButton(
                                    active: _quickJumpPanelOpen,
                                    onPressed: () {
                                      setState(() {
                                        _quickJumpPanelOpen =
                                            !_quickJumpPanelOpen;
                                      });
                                    },
                                  ),
                                ),
                              if (_musicDialog case final dialog?)
                                MusicDialog(
                                  song: dialog.song,
                                  initialMode: dialog.mode,
                                  currentTrackId:
                                      ref
                                          .watch(mediaControlControllerProvider)
                                          .state
                                          .track
                                          .id,
                                  isPlaying:
                                      ref
                                          .watch(mediaControlControllerProvider)
                                          .state
                                          .isPlaying,
                                  queueSongIds: dialog.queueSongIds,
                                  onPlay:
                                      ref
                                          .read(mediaControlControllerProvider)
                                          .onTogglePlayPause,
                                  onPlayTrack: (trackId, queueSongIds) {
                                    _playTrackInQueue(trackId, queueSongIds);
                                  },
                                  onReveal: (path) {
                                    unawaited(revealItemInFolder(path));
                                  },
                                  onSaved: () {
                                    notifyLyricsSaved(ref, dialog.song.id);
                                  },
                                  onClose: () {
                                    setState(() {
                                      _musicDialog = null;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (compact && _quickJumpPanelOpen)
                    Positioned.fill(
                      child: GestureDetector(
                        key: const ValueKey(
                          'MusicLibrary.QuickJumpDismissBarrier',
                        ),
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          setState(() {
                            _quickJumpPanelOpen = false;
                          });
                        },
                      ),
                    ),
                  if (compact && _quickJumpPanelOpen)
                    _QuickJumpPanel(
                      activeKey: activeQuickJumpKey,
                      keys: _quickJumpKeysForDirection(_sortDirection),
                      enabledKeys: quickJumpMap.keys.toSet(),
                      targetName: i18n.t('common.songs'),
                      basisName: _libraryQuickJumpBasisName(
                        _sortCriterion,
                        i18n,
                      ),
                      i18n: i18n,
                      underWorkspaceAppBar: useWorkspaceAppBar,
                      onJump: (key) {
                        _jumpToKey(quickJumpMap, key, compact);
                        setState(() {
                          _quickJumpPanelOpen = false;
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

  List<LibrarySong> _sortSongs(List<LibrarySong> songs, SmPlayerI18n i18n) {
    final direction =
        _sortDirection == MusicLibrarySortDirection.ascending ? 1 : -1;
    final sorted = songs.toList();
    sorted.sort((left, right) {
      final result = _compareSongs(left, right, _sortCriterion, i18n);
      return direction *
          (result != 0
              ? result
              : (_compareText(left.title, right.title) != 0
                  ? _compareText(left.title, right.title)
                  : left.id.compareTo(right.id)));
    });
    return sorted;
  }

  void _toggleSort(MusicLibrarySortCriterion criterion) {
    setState(() {
      if (_sortCriterion == criterion) {
        _sortDirection =
            _sortDirection == MusicLibrarySortDirection.ascending
                ? MusicLibrarySortDirection.descending
                : MusicLibrarySortDirection.ascending;
      } else {
        _sortCriterion = criterion;
        _sortDirection = MusicLibrarySortDirection.ascending;
      }
    });
    ref.read(libraryRepositoryProvider).updateMusicLibrarySort(criterion);
  }

  void _resizeColumn(_LibraryColumn column, double deltaX) {
    setState(() {
      _columnWidths[column] = max(
        _minColumnWidth,
        _columnWidths[column]! + deltaX,
      );
    });
  }

  void _handleScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  bool _handleUserScroll(UserScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical &&
        notification.direction != ScrollDirection.idle &&
        _quickJumpPinnedKey != null) {
      setState(() {
        _quickJumpPinnedKey = null;
      });
    }
    return false;
  }

  String _activeQuickJumpKey(
    List<LibrarySong> songs,
    bool compact,
    SmPlayerI18n i18n,
  ) {
    if (_quickJumpPinnedKey case final key?) {
      return key;
    }
    final rowHeight =
        compact ? _compactVirtualRowHeight : _wideVirtualRowHeight;
    final index = min(
      songs.length - 1,
      max(0, (_scrollOffset / rowHeight).floor()),
    );
    return _quickJumpBucket(songs[index], _sortCriterion, i18n);
  }

  void _selectSongFromPointer(int songId, Iterable<int> orderedSongIds) {
    final keyboard = HardwareKeyboard.instance;
    final extendSelection =
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.control) ||
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.controlLeft) ||
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.controlRight) ||
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.meta) ||
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.metaLeft) ||
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.metaRight);
    final rangeSelection =
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.shift) ||
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.shiftLeft) ||
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.shiftRight);

    setState(() {
      if (extendSelection || rangeSelection) {
        _selection.selectWithModifiers(
          songId,
          orderedSongIds,
          extendSelection: extendSelection,
          rangeSelection: rangeSelection,
        );
      } else {
        _selection.selectSingle(songId);
      }
    });
  }

  void _toggleSongSelection(int songId) {
    setState(() {
      _selection.toggle(songId);
    });
  }

  void _openSongContextMenu(
    Offset position,
    LibrarySong song,
    List<LibrarySong> sortedSongs,
    List<MultiSelectCommandBarPlaylist> customPlaylists,
  ) {
    final selectedVisibleSongIds =
        sortedSongs
            .map((song) => song.id)
            .where((songId) => _selection.isSelected(songId))
            .toList();
    if (_selection.isSelected(song.id) && selectedVisibleSongIds.length > 1) {
      final selectedVisibleSongs =
          sortedSongs
              .where((song) => selectedVisibleSongIds.contains(song.id))
              .toList();
      setState(() {
        _selection.selectAll(selectedVisibleSongIds);
      });
      _showSongSelectionContextMenu(
        position,
        selectedVisibleSongs,
        customPlaylists,
      );
      return;
    }

    _showSongContextMenu(
      position,
      song,
      sortedSongs.map((song) => song.id).toList(),
      customPlaylists,
    );
  }

  Future<void> _showSongContextMenu(
    Offset position,
    LibrarySong song,
    List<int> queueSongIds,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) async {
    final i18n = ref.read(smPlayerI18nProvider).valueOrNull!;
    final snapshot = ref.read(libraryContentDataProvider).value!;
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
        songPath: song.path,
        playlists: playlists,
        onPlay: () {
          _selection.selectSingle(song.id);
          _playSongIds([song.id]);
        },
        onPause: ref.read(mediaControlControllerProvider).onTogglePlayPause,
        onPlayNext: () {
          _playNext(song.id);
        },
        onAddToNowPlaying: () {
          unawaited(
            addSongsToNowPlayingWithUndo(
              context: context,
              ref: ref,
              i18n: i18n,
              songIds: [song.id],
            ),
          );
        },
        onCreatePlaylist: () async {
          await createPlaylistWithSongs(
            context: context,
            ref: ref,
            i18n: i18n,
            playlists: snapshot.playlists,
            defaultName: getNextPlaylistName(song.title, snapshot.playlists),
            songIds: [song.id],
          );
        },
        onAddToPlaylist: (playlistId) {
          unawaited(
            addSongsToPlaylistWithUndo(
              context: context,
              ref: ref,
              i18n: i18n,
              playlistId: playlistId,
              songIds: [song.id],
            ),
          );
        },
        onRemove: () {
          _showMessage(i18n.t('context.removeFromList'));
        },
        onSelect: () {
          setState(() {
            _selection.enterMultiSelect();
            if (!_selection.isSelected(song.id)) {
              _selection.toggle(song.id);
            }
          });
        },
        onToggleFavorite: () {
          unawaited(
            setSongsFavoriteWithUndo(
              context: context,
              ref: ref,
              i18n: i18n,
              songIds: [song.id],
              favorite: !song.favorite,
            ),
          );
        },
        onSetPreference: (level) async {
          await ref
              .read(libraryRepositoryProvider)
              .addPreferenceItem('song', '${song.id}', song.title, level);
        },
        preferenceLevel: preferenceLevel,
        showSelect: false,
        onUndoPreference:
            preferenceLevel == null
                ? null
                : () async {
                  await ref
                      .read(libraryRepositoryProvider)
                      .removePreferenceItem('song', '${song.id}');
                },
        onMoveToFolder: (folderPath) {
          moveSongToFolderWithUndo(
            context: context,
            ref: ref,
            i18n: i18n,
            song: song,
            folderPath: folderPath,
          );
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
          hideSongFileWithUndo(
            context: context,
            ref: ref,
            i18n: i18n,
            song: song,
          );
        },
        onSeeArtist: () {
          final artists = getSongArtists(song);
          final artist =
              artists.isEmpty ? i18n.t('common.artistUnknown') : artists.first;
          context.go('/artists?artist=${Uri.encodeQueryComponent(artist)}');
        },
        onSeeAlbum: () {
          context.go(
            '/albums?album=${Uri.encodeQueryComponent(_displayAlbum(song, i18n))}',
          );
        },
        onSeeMusicInfo: () {
          _openMusicDialog(song, SongDialogMode.properties, queueSongIds);
        },
        onSeeLyrics: () {
          _openMusicDialog(song, SongDialogMode.lyrics, queueSongIds);
        },
        onSeeAlbumArt: () {
          _openMusicDialog(song, SongDialogMode.albumArt, queueSongIds);
        },
        onSeeLocal: () {
          unawaited(revealItemInFolder(song.path));
        },
      ),
    );
  }

  void _openMusicDialog(
    LibrarySong song,
    SongDialogMode mode,
    List<int> queueSongIds,
  ) {
    setState(() {
      _musicDialog = (song: song, mode: mode, queueSongIds: queueSongIds);
    });
  }

  void _showSongSelectionContextMenu(
    Offset position,
    List<LibrarySong> selectedSongs,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) {
    final i18n = ref.read(smPlayerI18nProvider).valueOrNull!;
    final selectedSongIds = selectedSongs.map((song) => song.id).toList();
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: selectedSongIds,
      playlists: playlists,
      includeNowPlaying: true,
      includeFavorites: selectedSongs.any((song) => !song.favorite),
      onAddToNowPlaying: () {
        addSongsToNowPlaying(ref, selectedSongIds);
      },
      onToggleFavorite:
          selectedSongs.any((song) => !song.favorite)
              ? () {
                final songsById = {
                  for (final selectedSong in selectedSongs)
                    selectedSong.id: selectedSong,
                };
                setSongsFavorite(
                  ref,
                  notFavoriteSongIds(selectedSongIds, songsById),
                  true,
                );
              }
              : null,
      onCreatePlaylist: () async {
        final snapshot = ref.read(libraryContentDataProvider).value!;
        await createPlaylistWithSongs(
          context: context,
          ref: ref,
          i18n: i18n,
          playlists: snapshot.playlists,
          defaultName: getNextPlaylistName(
            i18n.t('common.songs'),
            snapshot.playlists,
          ),
          songIds: selectedSongIds,
        );
      },
      onAddToPlaylist: (playlistId) {
        addSongsToPlaylist(ref, playlistId, selectedSongIds);
      },
    );
    showMenuFlyout(
      context,
      position: position,
      items: [
        MenuFlyoutItem(
          key: 'shuffle',
          text: i18n.t('nowPlaying.randomPlay'),
          useShuffleIcon: true,
          onPressed: () {
            _playSongIds(selectedSongIds, shuffle: true);
          },
        ),
        if (addToItem != null) addToItem,
      ],
    );
  }

  Future<void> _showSongAddToMenu(
    BuildContext buttonContext,
    LibrarySong song,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) async {
    final i18n = ref.read(smPlayerI18nProvider).valueOrNull!;
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final item = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: [song.id],
      playlists: playlists,
      includeNowPlaying: true,
      includeFavorites: !song.favorite,
      defaultPlaylistName: getNextPlaylistName(song.title, snapshot.playlists),
      onAddToNowPlaying: () {
        unawaited(
          addSongsToNowPlayingWithUndo(
            context: context,
            ref: ref,
            i18n: i18n,
            songIds: [song.id],
          ),
        );
      },
      onToggleFavorite:
          !song.favorite
              ? () {
                unawaited(
                  setSongsFavoriteWithUndo(
                    context: context,
                    ref: ref,
                    i18n: i18n,
                    songIds: [song.id],
                    favorite: true,
                  ),
                );
              }
              : null,
      onCreatePlaylist: () async {
        await createPlaylistWithSongs(
          context: context,
          ref: ref,
          i18n: i18n,
          playlists: snapshot.playlists,
          defaultName: getNextPlaylistName(song.title, snapshot.playlists),
          songIds: [song.id],
        );
      },
      onAddToPlaylist: (playlistId) {
        unawaited(
          addSongsToPlaylistWithUndo(
            context: context,
            ref: ref,
            i18n: i18n,
            playlistId: playlistId,
            songIds: [song.id],
            useSingleSongCall: true,
          ),
        );
      },
    );
    if (item == null) {
      return;
    }
    await showMenuFlyout(
      buttonContext,
      avoidPlayerBar: false,
      items: item.submenu,
    );
  }

  void _showMessage(String message) {
    showAppNotification(context: context, message: message);
  }

  void _playSongIds(List<int> songIds, {bool shuffle = false}) {
    if (songIds.isEmpty) {
      return;
    }

    final queueSongIds = songIds.toList();
    if (shuffle) {
      queueSongIds.shuffle(Random());
    }
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final firstSong = songsById[queueSongIds.first]!;
    ref.read(nowPlayingQueueOverrideProvider.notifier).state = queueSongIds;
    unawaited(
      ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds),
    );
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          mediaControlTrackForSong(firstSong, context.smPlayerI18n),
          durationSeconds: firstSong.duration.toDouble(),
          queueIndex: 0,
        );
  }

  void _playTrackInQueue(int trackId, List<int> queueSongIds) {
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final song = songsById[trackId]!;
    ref.read(nowPlayingQueueOverrideProvider.notifier).state = queueSongIds;
    unawaited(
      ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds),
    );
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          mediaControlTrackForSong(song, context.smPlayerI18n),
          durationSeconds: song.duration.toDouble(),
          queueIndex: queueSongIds.indexOf(trackId),
        );
  }

  void _playNext(int songId) {
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final queueSongIds =
        (ref.read(nowPlayingQueueOverrideProvider) ??
                snapshot.nowPlaying.songIds)
            .toList();
    final selectedQueueIndex =
        ref.read(mediaControlControllerProvider).state.selectedQueueIndex;
    final insertIndex =
        selectedQueueIndex != null && selectedQueueIndex < queueSongIds.length
            ? selectedQueueIndex + 1
            : queueSongIds.length;
    queueSongIds.insert(insertIndex, songId);
    ref.read(nowPlayingQueueOverrideProvider.notifier).state = queueSongIds;
    unawaited(
      ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds),
    );
  }

  void _addNextAndPlay(int songId) {
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final song = songsById[songId]!;
    final mediaState = ref.read(mediaControlControllerProvider).state;
    final queueSongIds =
        (ref.read(nowPlayingQueueOverrideProvider) ??
                snapshot.nowPlaying.songIds)
            .toList();
    var queueIndex = queueSongIds.indexOf(songId);
    if (queueIndex == -1) {
      final currentIndex =
          mediaState.selectedQueueIndex ??
          (mediaState.track.id == null
              ? -1
              : queueSongIds.indexOf(mediaState.track.id!));
      queueIndex = currentIndex == -1 ? queueSongIds.length : currentIndex + 1;
      queueSongIds.insert(queueIndex, songId);
    }

    ref.read(nowPlayingQueueOverrideProvider.notifier).state = queueSongIds;
    unawaited(
      ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds),
    );
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          mediaControlTrackForSong(song, context.smPlayerI18n),
          durationSeconds: song.duration.toDouble(),
          queueIndex: queueIndex,
        );
  }

  void _jumpToKey(Map<String, int> quickJumpMap, String key, bool compact) {
    final index = quickJumpMap[key];
    if (index == null) {
      return;
    }

    setState(() {
      _quickJumpPinnedKey = key;
    });
    _scrollController.jumpTo(
      index * (compact ? _compactVirtualRowHeight : _wideVirtualRowHeight),
    );
  }
}
