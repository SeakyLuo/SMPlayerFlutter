import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/loading_state.dart';
import '../../i18n/app_i18n.dart';
import '../../playback/media_control_model.dart';
import '../../playback/media_control_provider.dart';
import '../data/library_models.dart';
import '../data/library_providers.dart';
import 'artists_page_model.dart'
    show compareArtistText, getArtistQuickJumpBucket, getSongArtists;
import 'command_bar.dart';
import 'headered_playlist_model.dart' show getNextPlaylistName;
import 'library_page_actions.dart';
import 'music_dialog.dart';
import 'page_selection_store.dart';
import 'quick_jump_tooltip.dart';
import '../../platform/desktop_features.dart';

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
  var _sortDirection = MusicLibrarySortDirection.ascending;
  var _quickJumpPanelOpen = false;
  var _scrollOffset = 0.0;
  final _columnWidths = {..._defaultColumnWidths};
  final _scrollController = ScrollController();
  final _selection = PageSelectionController<int>.stored('music-library');
  ({LibrarySong song, SongDialogMode mode})? _musicDialog;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(musicLibrarySnapshotProvider);

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
        if (_sortCriterion != snapshot.sortCriterion) {
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

        final sortedSongs = _sortSongs(snapshot.songs, i18n);
        final quickJumpMap = _buildQuickJumpMap(
          sortedSongs,
          _sortCriterion,
          i18n,
        );

        return SmPlayerI18nScope(
          i18n: i18n,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
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
              final songsById = {
                for (final song in snapshot.songs) song.id: song,
              };
              final activeQuickJumpKey = _activeQuickJumpKey(
                sortedSongs,
                compact,
                i18n,
              );
              final selectedSongIds =
                  sortedSongs
                      .map((song) => song.id)
                      .where(_selection.selectedItems.contains)
                      .toList();
              return _LibraryScaffold(
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
                    autofocus: true,
                    child: Stack(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: _LibraryColors.panel,
                            borderRadius: BorderRadius.circular(
                              compact ? 10 : 14,
                            ),
                            border: Border.all(
                              color: _LibraryColors.panelBorder,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: _LibraryColors.panelShadow,
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
                                      enabledKeys: quickJumpMap.keys.toSet(),
                                      targetName: i18n.t('common.songs'),
                                      basisName: _libraryQuickJumpBasisName(
                                        _sortCriterion,
                                        i18n,
                                      ),
                                      i18n: i18n,
                                      onJump: (key) {
                                        _jumpToKey(quickJumpMap, key, compact);
                                      },
                                    ),
                                  Expanded(
                                    child:
                                        compact
                                            ? _CompactSongList(
                                              songs: sortedSongs,
                                              scrollController:
                                                  _scrollController,
                                              sortCriterion: _sortCriterion,
                                              sortDirection: _sortDirection,
                                              selectedSongIds:
                                                  _selection.selectedItems,
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
                                              onToggleSelection:
                                                  _toggleSongSelection,
                                              onToggleFavorite: (songId) {
                                                setSongsFavorite(ref, [
                                                  songId,
                                                ], false);
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
                                              sortCriterion: _sortCriterion,
                                              sortDirection: _sortDirection,
                                              scrollController:
                                                  _scrollController,
                                              selectedSongIds:
                                                  _selection.selectedItems,
                                              multiSelect:
                                                  _selection.multiSelect,
                                              i18n: i18n,
                                              columnWidths: _columnWidths,
                                              onSort: _toggleSort,
                                              onResizeColumn: _resizeColumn,
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
                                              onToggleSelection:
                                                  _toggleSongSelection,
                                              onToggleFavorite: (songId) {
                                                setSongsFavorite(ref, [
                                                  songId,
                                                ], false);
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
                        if (compact)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: _CompactQuickJumpButton(
                              active: _quickJumpPanelOpen,
                              onPressed: () {
                                setState(() {
                                  _quickJumpPanelOpen = !_quickJumpPanelOpen;
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
                            onJump: (key) {
                              _jumpToKey(quickJumpMap, key, compact);
                              setState(() {
                                _quickJumpPanelOpen = false;
                              });
                            },
                          ),
                        MultiSelectCommandBar(
                          visible: _selection.multiSelect,
                          selectedCount: selectedSongIds.length,
                          playlists: customPlaylists,
                          addToSongIds: selectedSongIds,
                          includeNowPlayingInAddTo: true,
                          includeFavoritesInAddTo: hasNotFavoriteSongs(
                            selectedSongIds,
                            songsById,
                          ),
                          onAddToNowPlaying:
                              selectedSongIds.isEmpty
                                  ? null
                                  : () {
                                    addSongsToNowPlaying(ref, selectedSongIds);
                                    _hideSelectionAfterOperation(
                                      snapshot
                                          .hideMultiSelectCommandBarAfterOperation,
                                    );
                                  },
                          onToggleFavorite:
                              selectedSongIds.isEmpty
                                  ? null
                                  : () {
                                    setSongsFavorite(
                                      ref,
                                      notFavoriteSongIds(
                                        selectedSongIds,
                                        songsById,
                                      ),
                                      true,
                                    );
                                    _hideSelectionAfterOperation(
                                      snapshot
                                          .hideMultiSelectCommandBarAfterOperation,
                                    );
                                  },
                          onCreatePlaylist:
                              selectedSongIds.isEmpty
                                  ? null
                                  : () async {
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
                                    if (mounted) {
                                      _hideSelectionAfterOperation(
                                        snapshot
                                            .hideMultiSelectCommandBarAfterOperation,
                                      );
                                    }
                                  },
                          onPlay:
                              selectedSongIds.isEmpty
                                  ? null
                                  : () {
                                    _playSongIds(selectedSongIds);
                                    _hideSelectionAfterOperation(
                                      snapshot
                                          .hideMultiSelectCommandBarAfterOperation,
                                    );
                                  },
                          onAddToPlaylist: (playlistId) {
                            addSongsToPlaylist(
                              ref,
                              playlistId,
                              selectedSongIds,
                            );
                            _hideSelectionAfterOperation(
                              snapshot.hideMultiSelectCommandBarAfterOperation,
                            );
                          },
                          onSelectAll: () {
                            setState(() {
                              _selection.selectAll(
                                sortedSongs.map((song) => song.id),
                              );
                            });
                          },
                          onReverseSelection: () {
                            setState(() {
                              _selection.reverseSelection(
                                sortedSongs.map((song) => song.id),
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
                        if (_musicDialog case final dialog?)
                          MusicDialog(
                            song: dialog.song,
                            initialMode: dialog.mode,
                            canPause:
                                dialog.song.id ==
                                    ref
                                        .read(mediaControlControllerProvider)
                                        .state
                                        .track
                                        .id &&
                                ref
                                    .read(mediaControlControllerProvider)
                                    .state
                                    .isPlaying,
                            onPlay: () {
                              _playSongIds([dialog.song.id]);
                            },
                            onReveal: (path) {
                              unawaited(revealItemInFolder(path));
                            },
                            onSaved: () {
                              ref.invalidate(musicLibrarySnapshotProvider);
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

  String _activeQuickJumpKey(
    List<LibrarySong> songs,
    bool compact,
    SmPlayerI18n i18n,
  ) {
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
      } else if (_selection.multiSelect) {
        _selection.toggle(songId);
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

  void _hideSelectionAfterOperation(
    bool hideMultiSelectCommandBarAfterOperation,
  ) {
    setState(() {
      _selection.hideAfterOperation(hideMultiSelectCommandBarAfterOperation);
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

    _showSongContextMenu(position, song, customPlaylists);
  }

  void _showSongContextMenu(
    Offset position,
    LibrarySong song,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) {
    final i18n = ref.read(smPlayerI18nProvider).valueOrNull!;
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final mediaState = ref.read(mediaControlControllerProvider).state;
    final currentTrackId = mediaState.track.id;
    final folders =
        snapshot.folders
            .map(
              (folder) => MenuFlyoutFolder(
                id: folder.id,
                name: _displayFolderName(folder.path),
                path: folder.path,
                parentId: folder.parentId,
              ),
            )
            .toList();
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
        folders: folders,
        showMoveToFolder: folders.isNotEmpty,
        showHideFile: true,
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
          ref.invalidate(musicLibrarySnapshotProvider);
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
          _openMusicDialog(song, SongDialogMode.properties);
        },
        onSeeLyrics: () {
          _openMusicDialog(song, SongDialogMode.lyrics);
        },
        onSeeAlbumArt: () {
          _openMusicDialog(song, SongDialogMode.albumArt);
        },
        onSeeLocal: () {
          unawaited(revealItemInFolder(song.path));
        },
      ),
    );
  }

  void _openMusicDialog(LibrarySong song, SongDialogMode mode) {
    setState(() {
      _musicDialog = (song: song, mode: mode);
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
        final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
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
          key: 'shuffle-selected',
          text: i18n.t('nowPlaying.randomPlay'),
          icon: FluentIcons.arrow_shuffle_20_regular,
          onPressed: () {
            _playSongIds(selectedSongIds, shuffle: true);
          },
        ),
        const MenuFlyoutItem.separator(key: 'add-selection-separator'),
        if (addToItem != null) addToItem,
      ],
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _playSongIds(List<int> songIds, {bool shuffle = false}) {
    if (songIds.isEmpty) {
      return;
    }

    final queueSongIds = songIds.toList();
    if (shuffle) {
      queueSongIds.shuffle(Random());
    }
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final firstSong = songsById[queueSongIds.first]!;
    ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
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
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _playNext(int songId) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final queueSongIds = snapshot.nowPlaying.songIds.toList();
    final selectedQueueIndex =
        ref.read(mediaControlControllerProvider).state.selectedQueueIndex;
    final insertIndex =
        selectedQueueIndex != null && selectedQueueIndex < queueSongIds.length
            ? selectedQueueIndex + 1
            : queueSongIds.length;
    queueSongIds.insert(insertIndex, songId);
    ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _addNextAndPlay(int songId) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final song = songsById[songId]!;
    final mediaState = ref.read(mediaControlControllerProvider).state;
    final queueSongIds = snapshot.nowPlaying.songIds.toList();
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
          queueIndex: queueIndex,
        );
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _jumpToKey(Map<String, int> quickJumpMap, String key, bool compact) {
    final index = quickJumpMap[key];
    if (index == null) {
      return;
    }

    _scrollController.animateTo(
      index * (compact ? _compactVirtualRowHeight : _wideVirtualRowHeight),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }
}

class _LibraryScaffold extends StatelessWidget {
  const _LibraryScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SizedBox.expand(child: child),
    );
  }
}

class _WideSongTable extends StatelessWidget {
  const _WideSongTable({
    required this.songs,
    required this.sortCriterion,
    required this.sortDirection,
    required this.scrollController,
    required this.selectedSongIds,
    required this.multiSelect,
    required this.i18n,
    required this.columnWidths,
    required this.onSort,
    required this.onResizeColumn,
    required this.onSelected,
    required this.onAddNextAndPlay,
    required this.onToggleSelection,
    required this.onToggleFavorite,
    required this.onOpenContextMenu,
  });

  final List<LibrarySong> songs;
  final MusicLibrarySortCriterion sortCriterion;
  final MusicLibrarySortDirection sortDirection;
  final ScrollController scrollController;
  final Set<int> selectedSongIds;
  final bool multiSelect;
  final SmPlayerI18n i18n;
  final Map<_LibraryColumn, double> columnWidths;
  final ValueChanged<MusicLibrarySortCriterion> onSort;
  final void Function(_LibraryColumn column, double deltaX) onResizeColumn;
  final ValueChanged<int> onSelected;
  final ValueChanged<int> onAddNextAndPlay;
  final ValueChanged<int> onToggleSelection;
  final ValueChanged<int> onToggleFavorite;
  final void Function(Offset position, LibrarySong song) onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: scrollController,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _tableWidth(columnWidths),
            child: Column(
              children: [
                _TableHeader(
                  sortCriterion: sortCriterion,
                  sortDirection: sortDirection,
                  i18n: i18n,
                  columnWidths: columnWidths,
                  onSort: onSort,
                  onResizeColumn: onResizeColumn,
                ),
                ...songs.map(
                  (song) => _WideSongRow(
                    song: song,
                    selected: selectedSongIds.contains(song.id),
                    selectionMode: multiSelect,
                    i18n: i18n,
                    columnWidths: columnWidths,
                    onSelected: () {
                      onSelected(song.id);
                    },
                    onAddNextAndPlay: () {
                      onAddNextAndPlay(song.id);
                    },
                    onToggleSelection: () {
                      onToggleSelection(song.id);
                    },
                    onToggleFavorite:
                        song.favorite
                            ? () {
                              onToggleFavorite(song.id);
                            }
                            : null,
                    onOpenContextMenu: (position) {
                      onOpenContextMenu(position, song);
                    },
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

double _tableWidth(Map<_LibraryColumn, double> columnWidths) {
  return _LibraryColumn.values.fold<double>(
    0,
    (total, column) => total + columnWidths[column]!,
  );
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.sortCriterion,
    required this.sortDirection,
    required this.i18n,
    required this.columnWidths,
    required this.onSort,
    required this.onResizeColumn,
  });

  final MusicLibrarySortCriterion sortCriterion;
  final MusicLibrarySortDirection sortDirection;
  final SmPlayerI18n i18n;
  final Map<_LibraryColumn, double> columnWidths;
  final ValueChanged<MusicLibrarySortCriterion> onSort;
  final void Function(_LibraryColumn column, double deltaX) onResizeColumn;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: _LibraryColors.panel,
      child: Row(
        children: [
          _StaticHeaderCell(
            column: _LibraryColumn.artwork,
            width: columnWidths[_LibraryColumn.artwork]!,
            label: '',
            onResizeColumn: onResizeColumn,
          ),
          _HeaderCell(
            column: _LibraryColumn.title,
            width: columnWidths[_LibraryColumn.title]!,
            label: i18n.t('musicLibrary.titleHeader'),
            criterion: MusicLibrarySortCriterion.title,
            sortCriterion: sortCriterion,
            sortDirection: sortDirection,
            onSort: onSort,
            onResizeColumn: onResizeColumn,
          ),
          _HeaderCell(
            column: _LibraryColumn.artist,
            width: columnWidths[_LibraryColumn.artist]!,
            label: i18n.t('common.artist'),
            criterion: MusicLibrarySortCriterion.artist,
            sortCriterion: sortCriterion,
            sortDirection: sortDirection,
            onSort: onSort,
            onResizeColumn: onResizeColumn,
          ),
          _HeaderCell(
            column: _LibraryColumn.album,
            width: columnWidths[_LibraryColumn.album]!,
            label: i18n.t('common.album'),
            criterion: MusicLibrarySortCriterion.album,
            sortCriterion: sortCriterion,
            sortDirection: sortDirection,
            onSort: onSort,
            onResizeColumn: onResizeColumn,
          ),
          _HeaderCell(
            column: _LibraryColumn.duration,
            width: columnWidths[_LibraryColumn.duration]!,
            label: i18n.t('common.duration'),
            criterion: MusicLibrarySortCriterion.duration,
            sortCriterion: sortCriterion,
            sortDirection: sortDirection,
            onSort: onSort,
            onResizeColumn: onResizeColumn,
          ),
          _StaticHeaderCell(
            column: _LibraryColumn.favorite,
            width: columnWidths[_LibraryColumn.favorite]!,
            label: i18n.t('table.favorite'),
            onResizeColumn: onResizeColumn,
          ),
          _HeaderCell(
            column: _LibraryColumn.playCount,
            width: columnWidths[_LibraryColumn.playCount]!,
            label: i18n.t('common.playCount'),
            criterion: MusicLibrarySortCriterion.playCount,
            sortCriterion: sortCriterion,
            sortDirection: sortDirection,
            onSort: onSort,
            onResizeColumn: onResizeColumn,
          ),
          _HeaderCell(
            column: _LibraryColumn.dateAdded,
            width: columnWidths[_LibraryColumn.dateAdded]!,
            label: i18n.t('common.dateAdded'),
            criterion: MusicLibrarySortCriterion.dateAdded,
            sortCriterion: sortCriterion,
            sortDirection: sortDirection,
            onSort: onSort,
            onResizeColumn: onResizeColumn,
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.column,
    required this.width,
    required this.label,
    required this.criterion,
    required this.sortCriterion,
    required this.sortDirection,
    required this.onSort,
    required this.onResizeColumn,
  });

  final _LibraryColumn column;
  final double width;
  final String label;
  final MusicLibrarySortCriterion criterion;
  final MusicLibrarySortCriterion sortCriterion;
  final MusicLibrarySortDirection sortDirection;
  final ValueChanged<MusicLibrarySortCriterion> onSort;
  final void Function(_LibraryColumn column, double deltaX) onResizeColumn;

  @override
  Widget build(BuildContext context) {
    final sorted = sortCriterion == criterion;
    return SizedBox(
      key: ValueKey('MusicLibrary.Header.${column.name}'),
      width: width,
      child: Stack(
        children: [
          Positioned.fill(
            child: TextButton(
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor:
                    sorted
                        ? _LibraryColors.textStrong
                        : _LibraryColors.headerText,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const RoundedRectangleBorder(),
              ),
              onPressed: () {
                onSort(criterion);
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (sorted)
                    Icon(
                      sortDirection == MusicLibrarySortDirection.ascending
                          ? FluentIcons.chevron_up_16_regular
                          : FluentIcons.chevron_down_16_regular,
                      size: 14,
                      color: _LibraryColors.accentStrong,
                    ),
                ],
              ),
            ),
          ),
          _ColumnResizer(column: column, onResizeColumn: onResizeColumn),
        ],
      ),
    );
  }
}

class _StaticHeaderCell extends StatelessWidget {
  const _StaticHeaderCell({
    required this.column,
    required this.width,
    required this.label,
    required this.onResizeColumn,
  });

  final _LibraryColumn column;
  final double width;
  final String label;
  final void Function(_LibraryColumn column, double deltaX) onResizeColumn;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey('MusicLibrary.Header.${column.name}'),
      width: width,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: const TextStyle(
                  color: _LibraryColors.headerText,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          _ColumnResizer(column: column, onResizeColumn: onResizeColumn),
        ],
      ),
    );
  }
}

class _ColumnResizer extends StatelessWidget {
  const _ColumnResizer({required this.column, required this.onResizeColumn});

  final _LibraryColumn column;
  final void Function(_LibraryColumn column, double deltaX) onResizeColumn;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          key: ValueKey('MusicLibrary.ColumnResizer.${column.name}'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            onResizeColumn(column, details.delta.dx);
          },
          child: const SizedBox(width: 8),
        ),
      ),
    );
  }
}

class _WideSongRow extends StatelessWidget {
  const _WideSongRow({
    required this.song,
    required this.selected,
    required this.selectionMode,
    required this.i18n,
    required this.columnWidths,
    required this.onSelected,
    required this.onAddNextAndPlay,
    required this.onToggleSelection,
    required this.onToggleFavorite,
    required this.onOpenContextMenu,
  });

  final LibrarySong song;
  final bool selected;
  final bool selectionMode;
  final SmPlayerI18n i18n;
  final Map<_LibraryColumn, double> columnWidths;
  final VoidCallback onSelected;
  final VoidCallback onAddNextAndPlay;
  final VoidCallback onToggleSelection;
  final VoidCallback? onToggleFavorite;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      onDoubleTap: selectionMode ? null : onAddNextAndPlay,
      onSecondaryTapDown: (details) {
        onOpenContextMenu(details.globalPosition);
      },
      hoverColor: _LibraryColors.rowHover,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: selected ? _LibraryColors.rowSelected : Colors.transparent,
          border: const Border(
            top: BorderSide(color: _LibraryColors.rowBorder),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: columnWidths[_LibraryColumn.artwork]!,
              child: Center(
                child:
                    selectionMode
                        ? _SelectionMark(selected: selected)
                        : LibraryRowArtwork(
                          song: song,
                          size: 42,
                          onPlay: onAddNextAndPlay,
                        ),
              ),
            ),
            _SongTextCell(
              width: columnWidths[_LibraryColumn.title]!,
              text: song.title,
              strong: true,
            ),
            _ArtistLinksCell(
              width: columnWidths[_LibraryColumn.artist]!,
              song: song,
              i18n: i18n,
            ),
            _RouteTextCell(
              width: columnWidths[_LibraryColumn.album]!,
              text: _displayAlbum(song, i18n),
              onTap: () {
                context.go(
                  '/albums?album=${Uri.encodeQueryComponent(_displayAlbum(song, i18n))}',
                );
              },
            ),
            _SongTextCell(
              width: columnWidths[_LibraryColumn.duration]!,
              text: _formatDuration(song.duration),
            ),
            SizedBox(
              width: columnWidths[_LibraryColumn.favorite]!,
              child: Center(
                child:
                    song.favorite
                        ? IconButton(
                          tooltip: i18n.t('common.favorite'),
                          icon: const Icon(
                            FluentIcons.heart_16_filled,
                            color: _LibraryColors.favorite,
                            size: 18,
                          ),
                          onPressed: onToggleFavorite,
                        )
                        : const SizedBox.shrink(),
              ),
            ),
            _SongTextCell(
              width: columnWidths[_LibraryColumn.playCount]!,
              text: song.playCount == 0 ? '' : song.playCount.toString(),
            ),
            _SongTextCell(
              width: columnWidths[_LibraryColumn.dateAdded]!,
              text: _formatDateTime(song.dateAdded),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongTextCell extends StatelessWidget {
  const _SongTextCell({
    required this.width,
    required this.text,
    this.strong = false,
  });

  final double width;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color:
                strong ? _LibraryColors.textStrong : _LibraryColors.textMuted,
            fontSize: 14,
            fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _ArtistLinksCell extends StatelessWidget {
  const _ArtistLinksCell({
    required this.width,
    required this.song,
    required this.i18n,
  });

  final double width;
  final LibrarySong song;
  final SmPlayerI18n i18n;

  @override
  Widget build(BuildContext context) {
    final artists = getSongArtists(song);
    final displayArtists =
        artists.isEmpty ? [i18n.t('common.artistUnknown')] : artists;
    final separator = i18n.t('common.artistSeparator');

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Wrap(
          spacing: 0,
          runSpacing: 0,
          children: [
            for (var index = 0; index < displayArtists.length; index += 1) ...[
              if (index > 0)
                Text(
                  separator,
                  style: const TextStyle(
                    color: _LibraryColors.textMuted,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              _InlineRouteText(
                key: ValueKey(
                  'MusicLibrary.ArtistLink.${displayArtists[index]}',
                ),
                text: displayArtists[index],
                onTap: () {
                  context.go(
                    '/artists?artist=${Uri.encodeQueryComponent(displayArtists[index])}',
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteTextCell extends StatelessWidget {
  const _RouteTextCell({
    required this.width,
    required this.text,
    required this.onTap,
  });

  final double width;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _InlineRouteText(
            key: ValueKey('MusicLibrary.AlbumLink.$text'),
            text: text,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

class _InlineRouteText extends StatelessWidget {
  const _InlineRouteText({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerUp: (_) {
          onTap();
        },
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _LibraryColors.textMuted,
            fontSize: 14,
            height: 1.35,
            decoration: TextDecoration.underline,
            decorationColor: _LibraryColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _CompactSongList extends StatelessWidget {
  const _CompactSongList({
    required this.songs,
    required this.scrollController,
    required this.sortCriterion,
    required this.sortDirection,
    required this.selectedSongIds,
    required this.multiSelect,
    required this.i18n,
    required this.onSort,
    required this.onSelected,
    required this.onAddNextAndPlay,
    required this.onToggleSelection,
    required this.onToggleFavorite,
    required this.onOpenContextMenu,
  });

  final List<LibrarySong> songs;
  final ScrollController scrollController;
  final MusicLibrarySortCriterion sortCriterion;
  final MusicLibrarySortDirection sortDirection;
  final Set<int> selectedSongIds;
  final bool multiSelect;
  final SmPlayerI18n i18n;
  final ValueChanged<MusicLibrarySortCriterion> onSort;
  final ValueChanged<int> onSelected;
  final ValueChanged<int> onAddNextAndPlay;
  final ValueChanged<int> onToggleSelection;
  final ValueChanged<int> onToggleFavorite;
  final void Function(Offset position, LibrarySong song) onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CompactSortBar(
          sortCriterion: sortCriterion,
          sortDirection: sortDirection,
          i18n: i18n,
          onSort: onSort,
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemExtent: 76,
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return _CompactSongRow(
                song: song,
                selected: selectedSongIds.contains(song.id),
                selectionMode: multiSelect,
                i18n: i18n,
                onSelected: () {
                  onSelected(song.id);
                },
                onAddNextAndPlay: () {
                  onAddNextAndPlay(song.id);
                },
                onToggleSelection: () {
                  onToggleSelection(song.id);
                },
                onToggleFavorite:
                    song.favorite
                        ? () {
                          onToggleFavorite(song.id);
                        }
                        : null,
                onOpenContextMenu: (position) {
                  onOpenContextMenu(position, song);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CompactSortBar extends StatelessWidget {
  const _CompactSortBar({
    required this.sortCriterion,
    required this.sortDirection,
    required this.i18n,
    required this.onSort,
  });

  final MusicLibrarySortCriterion sortCriterion;
  final MusicLibrarySortDirection sortDirection;
  final SmPlayerI18n i18n;
  final ValueChanged<MusicLibrarySortCriterion> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      decoration: const BoxDecoration(
        color: _LibraryColors.panel,
        border: Border(bottom: BorderSide(color: _LibraryColors.rowBorder)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _CompactSortButton(
            label: i18n.t('musicLibrary.titleHeader'),
            criterion: MusicLibrarySortCriterion.title,
            activeCriterion: sortCriterion,
            direction: sortDirection,
            onSort: onSort,
          ),
          _CompactSortButton(
            label: i18n.t('common.artist'),
            criterion: MusicLibrarySortCriterion.artist,
            activeCriterion: sortCriterion,
            direction: sortDirection,
            onSort: onSort,
          ),
          _CompactSortButton(
            label: i18n.t('common.album'),
            criterion: MusicLibrarySortCriterion.album,
            activeCriterion: sortCriterion,
            direction: sortDirection,
            onSort: onSort,
          ),
          _CompactSortButton(
            label: i18n.t('common.duration'),
            criterion: MusicLibrarySortCriterion.duration,
            activeCriterion: sortCriterion,
            direction: sortDirection,
            onSort: onSort,
          ),
          _CompactSortButton(
            label: i18n.t('common.playCount'),
            criterion: MusicLibrarySortCriterion.playCount,
            activeCriterion: sortCriterion,
            direction: sortDirection,
            onSort: onSort,
          ),
          _CompactSortButton(
            label: i18n.t('common.dateAdded'),
            criterion: MusicLibrarySortCriterion.dateAdded,
            activeCriterion: sortCriterion,
            direction: sortDirection,
            onSort: onSort,
          ),
        ],
      ),
    );
  }
}

class _CompactSortButton extends StatelessWidget {
  const _CompactSortButton({
    required this.label,
    required this.criterion,
    required this.activeCriterion,
    required this.direction,
    required this.onSort,
  });

  final String label;
  final MusicLibrarySortCriterion criterion;
  final MusicLibrarySortCriterion activeCriterion;
  final MusicLibrarySortDirection direction;
  final ValueChanged<MusicLibrarySortCriterion> onSort;

  @override
  Widget build(BuildContext context) {
    final active = criterion == activeCriterion;
    return TextButton.icon(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 28),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor:
            active ? _LibraryColors.accentStrong : _LibraryColors.textMuted,
        backgroundColor:
            active ? _LibraryColors.accentSoft : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: () {
        onSort(criterion);
      },
      icon:
          active
              ? Icon(
                direction == MusicLibrarySortDirection.ascending
                    ? FluentIcons.chevron_up_16_regular
                    : FluentIcons.chevron_down_16_regular,
                size: 13,
              )
              : const SizedBox.shrink(),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _CompactSongRow extends StatelessWidget {
  const _CompactSongRow({
    required this.song,
    required this.selected,
    required this.selectionMode,
    required this.i18n,
    required this.onSelected,
    required this.onAddNextAndPlay,
    required this.onToggleSelection,
    required this.onToggleFavorite,
    required this.onOpenContextMenu,
  });

  final LibrarySong song;
  final bool selected;
  final bool selectionMode;
  final SmPlayerI18n i18n;
  final VoidCallback onSelected;
  final VoidCallback onAddNextAndPlay;
  final VoidCallback onToggleSelection;
  final VoidCallback? onToggleFavorite;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      onDoubleTap: selectionMode ? null : onAddNextAndPlay,
      onSecondaryTapDown: (details) {
        onOpenContextMenu(details.globalPosition);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 8, 8, 8),
        decoration: BoxDecoration(
          color: selected ? _LibraryColors.rowSelected : Colors.transparent,
          border: const Border(
            top: BorderSide(color: _LibraryColors.rowBorder),
          ),
        ),
        child: Row(
          children: [
            selectionMode
                ? SizedBox(width: 46, child: _SelectionMark(selected: selected))
                : LibraryRowArtwork(
                  song: song,
                  size: 46,
                  onPlay: onAddNextAndPlay,
                ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _LibraryColors.textStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _InlineRouteText(
                      text: _displayArtists(song, i18n),
                      onTap: () {
                        final artists = getSongArtists(song);
                        final artist =
                            artists.isEmpty
                                ? i18n.t('common.artistUnknown')
                                : artists.first;
                        context.go(
                          '/artists?artist=${Uri.encodeQueryComponent(artist)}',
                        );
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _InlineRouteText(
                      text: _displayAlbum(song, i18n),
                      onTap: () {
                        context.go(
                          '/albums?album=${Uri.encodeQueryComponent(_displayAlbum(song, i18n))}',
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 42,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (song.favorite)
                    IconButton(
                      tooltip: i18n.t('common.favorite'),
                      icon: const Icon(
                        FluentIcons.heart_16_filled,
                        color: _LibraryColors.favorite,
                        size: 16,
                      ),
                      onPressed: onToggleFavorite,
                    ),
                  Text(
                    _formatDuration(song.duration),
                    style: const TextStyle(
                      color: _LibraryColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LibraryRowArtwork extends StatefulWidget {
  const LibraryRowArtwork({
    super.key,
    required this.song,
    required this.size,
    required this.onPlay,
  });

  final LibrarySong song;
  final double size;
  final VoidCallback onPlay;

  @override
  State<LibraryRowArtwork> createState() => _LibraryRowArtworkState();
}

class _LibraryRowArtworkState extends State<LibraryRowArtwork> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final file =
        widget.song.thumbnailPath.isEmpty
            ? null
            : File(widget.song.thumbnailPath);
    return MouseRegion(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox.square(
          dimension: widget.size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              file != null && file.existsSync()
                  ? Image.file(file, fit: BoxFit.cover)
                  : const DecoratedBox(
                    decoration: BoxDecoration(color: _LibraryColors.artwork),
                    child: Icon(
                      FluentIcons.music_note_2_24_regular,
                      color: _LibraryColors.artworkIcon,
                    ),
                  ),
              IgnorePointer(
                ignoring: !_hovered,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _hovered ? 1 : 0,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey(
                        'MusicLibrary.ArtworkPlay.${widget.song.id}',
                      ),
                      onTap: widget.onPlay,
                      child: Center(
                        child: Container(
                          width: widget.size - 8,
                          height: widget.size - 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _LibraryColors.overlayPlay,
                          ),
                          child: const Icon(
                            FluentIcons.play_20_filled,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color:
              selected
                  ? _LibraryColors.accentStrong
                  : _LibraryColors.selectionMark,
          shape: BoxShape.circle,
          border: Border.all(
            color:
                selected
                    ? _LibraryColors.accentStrong
                    : _LibraryColors.selectionBorder,
          ),
        ),
        child:
            selected
                ? const Icon(
                  FluentIcons.checkmark_16_regular,
                  color: Colors.white,
                  size: 16,
                )
                : null,
      ),
    );
  }
}

class _QuickJumpRail extends StatelessWidget {
  const _QuickJumpRail({
    required this.activeKey,
    required this.keys,
    required this.enabledKeys,
    required this.targetName,
    required this.basisName,
    required this.i18n,
    required this.onJump,
  });

  final String activeKey;
  final List<String> keys;
  final Set<String> enabledKeys;
  final String targetName;
  final String basisName;
  final SmPlayerI18n i18n;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      padding: const EdgeInsets.fromLTRB(10, 42, 16, 16),
      decoration: const BoxDecoration(
        color: _LibraryColors.panel,
        border: Border(
          right: BorderSide(color: _LibraryColors.quickJumpBorder),
        ),
      ),
      child: Column(
        children:
            keys.map((key) {
              final enabled = enabledKeys.contains(key);
              final active = activeKey == key;
              return Expanded(
                child: Center(
                  child: SizedBox(
                    width: 22,
                    child: Tooltip(
                      message: getQuickJumpTooltip(
                        key: key,
                        enabled: enabled,
                        targetName: targetName,
                        basisName: basisName,
                        i18n: i18n,
                      ),
                      child: TextButton(
                        key: ValueKey('MusicLibrary.QuickJumpRail.$key'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(22, 0),
                          foregroundColor:
                              enabled
                                  ? active
                                      ? _LibraryColors.accentStrong
                                      : _LibraryColors.textMuted
                                  : _LibraryColors.disabled,
                          backgroundColor:
                              active
                                  ? _LibraryColors.accentSoft
                                  : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed:
                            enabled
                                ? () {
                                  onJump(key);
                                }
                                : null,
                        child: Text(
                          key,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _QuickJumpPanel extends StatelessWidget {
  const _QuickJumpPanel({
    required this.activeKey,
    required this.keys,
    required this.enabledKeys,
    required this.targetName,
    required this.basisName,
    required this.i18n,
    required this.onJump,
  });

  final String activeKey;
  final List<String> keys;
  final Set<String> enabledKeys;
  final String targetName;
  final String basisName;
  final SmPlayerI18n i18n;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: const ValueKey('MusicLibrary.QuickJumpPanel'),
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: _LibraryColors.quickJumpPanel,
            boxShadow: [
              BoxShadow(
                color: _LibraryColors.quickJumpPanelShadow,
                offset: Offset(0, 18),
                blurRadius: 36,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 50, 18, 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.2,
                children:
                    keys.map((key) {
                      final enabled = enabledKeys.contains(key);
                      final active = activeKey == key;
                      return Tooltip(
                        message: getQuickJumpTooltip(
                          key: key,
                          enabled: enabled,
                          targetName: targetName,
                          basisName: basisName,
                          i18n: i18n,
                        ),
                        child: TextButton(
                          key: ValueKey('MusicLibrary.QuickJumpPanel.$key'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(42, 40),
                            foregroundColor:
                                enabled
                                    ? active
                                        ? _LibraryColors.accentStrong
                                        : _LibraryColors.textMuted
                                    : _LibraryColors.disabled,
                            backgroundColor:
                                active
                                    ? _LibraryColors.accentSoft
                                    : _LibraryColors.quickJumpPanelButton,
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(
                                color:
                                    _LibraryColors.quickJumpPanelButtonBorder,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed:
                              enabled
                                  ? () {
                                    onJump(key);
                                  }
                                  : null,
                          child: Text(
                            key,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactQuickJumpButton extends StatelessWidget {
  const _CompactQuickJumpButton({
    required this.active,
    required this.onPressed,
  });

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '#-Z',
      child: Material(
        color: Colors.transparent,
        child: IconButton(
          key: const ValueKey('MusicLibrary.QuickJumpToggle'),
          style: IconButton.styleFrom(
            backgroundColor:
                active ? _LibraryColors.accentSoft : _LibraryColors.panel,
            foregroundColor:
                active
                    ? _LibraryColors.accentStrong
                    : _LibraryColors.textStrong,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: _LibraryColors.panelBorder),
            ),
            elevation: 6,
            shadowColor: _LibraryColors.panelShadow,
          ),
          icon: const Icon(FluentIcons.apps_list_detail_24_regular),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

List<String> _quickJumpKeysForDirection(MusicLibrarySortDirection direction) {
  return direction == MusicLibrarySortDirection.descending
      ? _quickJumpKeys.reversed.toList()
      : _quickJumpKeys;
}

String _libraryQuickJumpBasisName(
  MusicLibrarySortCriterion criterion,
  SmPlayerI18n i18n,
) {
  switch (criterion) {
    case MusicLibrarySortCriterion.artist:
      return i18n.t('common.artist');
    case MusicLibrarySortCriterion.album:
      return i18n.t('common.album');
    case MusicLibrarySortCriterion.duration:
      return i18n.t('common.duration');
    case MusicLibrarySortCriterion.playCount:
      return i18n.t('common.playCount');
    case MusicLibrarySortCriterion.dateAdded:
      return i18n.t('common.dateAdded');
    case MusicLibrarySortCriterion.title:
      return i18n.t('musicLibrary.titleHeader');
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _LibraryColors.emptyStateSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _LibraryColors.emptyStateBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _LibraryColors.textStrong,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: _LibraryColors.textMuted,
                    fontSize: 14,
                    height: 1.65,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Map<String, int> _buildQuickJumpMap(
  List<LibrarySong> songs,
  MusicLibrarySortCriterion criterion,
  SmPlayerI18n i18n,
) {
  final indexes = <String, int>{};
  for (var index = 0; index < songs.length; index += 1) {
    final bucket = _quickJumpBucket(songs[index], criterion, i18n);
    indexes.putIfAbsent(bucket, () => index);
  }
  return indexes;
}

String _quickJumpBucket(
  LibrarySong song,
  MusicLibrarySortCriterion criterion,
  SmPlayerI18n i18n,
) {
  final value = _quickJumpValue(song, criterion, i18n).trim();
  if (value.isEmpty) {
    return '#';
  }

  return getArtistQuickJumpBucket(value);
}

String _quickJumpValue(
  LibrarySong song,
  MusicLibrarySortCriterion criterion,
  SmPlayerI18n i18n,
) {
  switch (criterion) {
    case MusicLibrarySortCriterion.artist:
      return _displayArtists(song, i18n);
    case MusicLibrarySortCriterion.album:
      return _displayAlbum(song, i18n);
    case MusicLibrarySortCriterion.duration:
      return _formatDuration(song.duration);
    case MusicLibrarySortCriterion.playCount:
      return song.playCount.toString();
    case MusicLibrarySortCriterion.dateAdded:
      return _formatDateTime(song.dateAdded);
    case MusicLibrarySortCriterion.title:
      return song.title;
  }
}

int _compareSongs(
  LibrarySong left,
  LibrarySong right,
  MusicLibrarySortCriterion criterion,
  SmPlayerI18n i18n,
) {
  switch (criterion) {
    case MusicLibrarySortCriterion.artist:
      return _compareText(
        _displayArtists(left, i18n),
        _displayArtists(right, i18n),
      );
    case MusicLibrarySortCriterion.album:
      return _compareText(left.album, right.album);
    case MusicLibrarySortCriterion.duration:
      return left.duration.compareTo(right.duration);
    case MusicLibrarySortCriterion.playCount:
      return left.playCount.compareTo(right.playCount);
    case MusicLibrarySortCriterion.dateAdded:
      return _parseDate(left.dateAdded).compareTo(_parseDate(right.dateAdded));
    case MusicLibrarySortCriterion.title:
      return _compareText(left.title, right.title);
  }
}

int _compareText(String left, String right) {
  return compareArtistText(left, right);
}

String _displayArtists(LibrarySong song, SmPlayerI18n i18n) {
  final artists = getSongArtists(song);
  return artists.isEmpty
      ? i18n.t('common.artistUnknown')
      : artists.join(i18n.t('common.artistSeparator'));
}

String _displayAlbum(LibrarySong song, SmPlayerI18n i18n) {
  return song.album.isEmpty ? i18n.t('common.albumUnknown') : song.album;
}

String _displayFolderName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index >= 0 ? normalized.substring(index + 1) : normalized;
}

String _formatDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final remainingSeconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

String _formatDateTime(String value) {
  final date = _parseDate(value);
  if (date == DateTime.fromMillisecondsSinceEpoch(0)) {
    return '';
  }

  return '${date.year}/${date.month}/${date.day} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

DateTime _parseDate(String value) {
  return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

class _LibraryColors {
  const _LibraryColors._();

  static const panel = Color(0xffffffff);
  static const panelBorder = Color(0x29677486);
  static const emptyStateSurface = Color(0x94ffffff);
  static const emptyStateBorder = Color(0x94ffffff);
  static const panelShadow = Color(0x1f1f2a38);
  static const quickJumpPanel = Color(0xf5f4f6f9);
  static const quickJumpPanelShadow = Color(0x1f2a384e);
  static const quickJumpPanelButton = Color(0xadffffff);
  static const quickJumpPanelButtonBorder = Color(0x1a677486);
  static const quickJumpBorder = Color(0x1a677486);
  static const rowBorder = Color(0x21727e8c);
  static const rowHover = Color(0x0e0078d7);
  static const rowSelected = Color(0xf5ffffff);
  static const selectionMark = Color(0xdfffffff);
  static const selectionBorder = Color(0x55677486);
  static const accentStrong = Color(0xff0063b1);
  static const accentSoft = Color(0x1a0078d7);
  static const favorite = Color(0xffd13438);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const headerText = Color(0xff565656);
  static const disabled = Color(0x3d5b697a);
  static const artwork = Color(0xffe8eef5);
  static const artworkIcon = Color(0xff607085);
  static const overlayPlay = Color(0xb81e2228);
}
