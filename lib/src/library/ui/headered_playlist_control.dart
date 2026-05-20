import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_model.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';

enum HeaderedPlaylistType { album, playlist, favorites }

typedef HeaderedPlaylistTrackHandler =
    void Function(int trackId, List<int> queueSongIds);
typedef HeaderedPlaylistSongsHandler =
    FutureOr<void> Function(List<int> songIds);
typedef HeaderedPlaylistSortHandler =
    FutureOr<void> Function(
      List<int> songIds,
      PlaylistSortCriterion sortCriterion,
    );

class HeaderedPlaylistControl extends ConsumerStatefulWidget {
  const HeaderedPlaylistControl({
    super.key,
    required this.type,
    required this.title,
    required this.songs,
    required this.selectedTrackId,
    required this.playlists,
    required this.favoritePlaylistId,
    required this.artworkUrl,
    required this.onPlayTrack,
    required this.onAddSongToPlaylist,
    this.subtitle,
    this.caption,
    this.headerSongs,
    this.isPlaying = false,
    this.removable = false,
    this.showAlbum = false,
    this.canRename = false,
    this.canDelete = false,
    this.canClear = false,
    this.canEditArtwork = false,
    this.canSetPreferred = false,
    this.sortCriterion,
    this.preferenceType,
    this.preferenceItemId,
    this.onTogglePlayPause,
    this.onAddSongsToPlaylist,
    this.onRemoveSongs,
    this.onRename,
    this.onDelete,
    this.onClear,
    this.onEditArtwork,
    this.onSetPreferred,
    this.onSortSongs,
    this.onArtistClick,
    this.onAlbumClick,
    this.onToggleFavorite,
    this.onMoveToMusicOrPlay,
    this.onPlayNext,
    this.onRecordPlay,
  });

  final HeaderedPlaylistType type;
  final String title;
  final String? subtitle;
  final String? caption;
  final List<LibrarySong>? headerSongs;
  final List<LibrarySong> songs;
  final int? selectedTrackId;
  final bool isPlaying;
  final List<LibraryPlaylist> playlists;
  final int favoritePlaylistId;
  final String artworkUrl;
  final bool removable;
  final bool showAlbum;
  final bool canRename;
  final bool canDelete;
  final bool canClear;
  final bool canEditArtwork;
  final bool canSetPreferred;
  final PlaylistSortCriterion? sortCriterion;
  final String? preferenceType;
  final String? preferenceItemId;
  final HeaderedPlaylistTrackHandler onPlayTrack;
  final VoidCallback? onTogglePlayPause;
  final void Function(int playlistId, int songId) onAddSongToPlaylist;
  final void Function(int playlistId, List<int> songIds)? onAddSongsToPlaylist;
  final HeaderedPlaylistSongsHandler? onRemoveSongs;
  final ValueChanged<String>? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onClear;
  final VoidCallback? onEditArtwork;
  final ValueChanged<String>? onSetPreferred;
  final HeaderedPlaylistSortHandler? onSortSongs;
  final ValueChanged<String>? onArtistClick;
  final ValueChanged<String>? onAlbumClick;
  final void Function(int songId, bool favorite)? onToggleFavorite;
  final ValueChanged<int>? onMoveToMusicOrPlay;
  final ValueChanged<int>? onPlayNext;
  final VoidCallback? onRecordPlay;

  @override
  ConsumerState<HeaderedPlaylistControl> createState() =>
      _HeaderedPlaylistControlState();
}

class _HeaderedPlaylistControlState
    extends ConsumerState<HeaderedPlaylistControl> {
  final _selection = PageSelectionController<int>();
  List<int>? _orderedSongIds;
  PlaylistSortCriterion? _selectedSortCriterion;

  @override
  void didUpdateWidget(HeaderedPlaylistControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songs != widget.songs) {
      _orderedSongIds = null;
      _selectedSortCriterion = null;
      _selection.clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final songsById = {for (final song in widget.songs) song.id: song};
    final visibleSongs = _visibleSongs(songsById);
    final queueSongIds = visibleSongs.map((song) => song.id).toList();
    final activeSortCriterion =
        _selectedSortCriterion ??
        widget.sortCriterion ??
        inferSortCriterion(widget.songs);
    final headerSongs = widget.headerSongs ?? widget.songs;
    final customPlaylists =
        widget.playlists
            .where((playlist) => !playlist.isBuiltIn)
            .map(
              (playlist) => MultiSelectCommandBarPlaylist(
                id: playlist.id,
                name: playlist.name,
                songIds: playlist.songIds,
              ),
            )
            .toList();

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _HeaderHero(
                type: widget.type,
                title: widget.title,
                subtitle: widget.subtitle,
                caption: widget.caption,
                info: getHeaderPlaylistInfo(headerSongs, i18n),
                artworkUrls: _headerArtworkUrls(headerSongs),
                commandBar: _buildCommandBar(
                  context,
                  i18n,
                  visibleSongs,
                  queueSongIds,
                  activeSortCriterion,
                  customPlaylists,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
                child: _HeaderedPlaylistListHeader(showAlbum: widget.showAlbum),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                _selection.multiSelect ? multiSelectCommandBarScrollSpacer : 28,
              ),
              sliver: SliverList.builder(
                itemCount: visibleSongs.length,
                itemBuilder: (context, index) {
                  final song = visibleSongs[index];
                  final current = song.id == widget.selectedTrackId;
                  return PlaylistControlItem(
                    song: song,
                    current: current,
                    playing: current && widget.isPlaying,
                    selected: _selection.isSelected(song.id),
                    selectionMode: _selection.multiSelect,
                    showAlbum: widget.showAlbum,
                    playNextLabel: i18n.t('context.playNext'),
                    removeLabel:
                        widget.type == HeaderedPlaylistType.favorites
                            ? i18n.t('context.removeFavorite')
                            : i18n.t('context.removeFromList'),
                    addToPlaylistLabel: i18n.t('context.addToPlaylist'),
                    favoriteLabel: i18n.t('common.favorite'),
                    moreLabel: i18n.t('player.more'),
                    onPlayTrack: () {
                      _playSong(song, queueSongIds);
                    },
                    onTogglePlayPause:
                        widget.onTogglePlayPause ??
                        () {
                          _playSong(song, queueSongIds);
                        },
                    onToggleSelection: () {
                      setState(() {
                        _selection.toggle(song.id);
                      });
                    },
                    onToggleFavoriteClick:
                        widget.onToggleFavorite == null
                            ? null
                            : () {
                              widget.onToggleFavorite!(song.id, !song.favorite);
                            },
                    onAddToPlaylistClick: (buttonContext) {
                      final item = buildAddToPlaylistMenuFlyoutItem(
                        i18n: i18n,
                        songIds: [song.id],
                        playlists: customPlaylists,
                        includeNowPlaying: true,
                        includeFavorites:
                            widget.type != HeaderedPlaylistType.favorites,
                        onAddToNowPlaying: () {
                          _addSongsToNowPlaying([song.id]);
                        },
                        onToggleFavorite:
                            widget.onToggleFavorite == null
                                ? null
                                : () {
                                  widget.onToggleFavorite!(song.id, true);
                                },
                        onCreatePlaylist: () {
                          unawaited(_createPlaylistFromSongs(i18n, [song.id]));
                        },
                        onAddToPlaylist: (playlistId) {
                          widget.onAddSongToPlaylist(playlistId, song.id);
                        },
                      );
                      if (item != null) {
                        showMenuFlyout(buttonContext, items: item.submenu);
                      }
                    },
                    onRemoveFromListClick:
                        widget.removable
                            ? () {
                              unawaited(
                                _removeSongsFromCurrentPlaylist([song.id]),
                              );
                            }
                            : null,
                    onPlayNextClick: () {
                      widget.onPlayNext?.call(song.id);
                    },
                    onOpenContextMenu: (position) {
                      _showSongMenu(context, i18n, position, song, index);
                    },
                    onSeeArtist: widget.onArtistClick,
                    onSeeAlbum:
                        widget.onAlbumClick == null
                            ? null
                            : () {
                              widget.onAlbumClick!(
                                song.album.isEmpty
                                    ? i18n.t('common.albumUnknown')
                                    : song.album,
                              );
                            },
                  );
                },
              ),
            ),
          ],
        ),
        MultiSelectCommandBar(
          visible: _selection.multiSelect,
          selectedCount: _effectiveSelectedSongIds(queueSongIds).length,
          playlists: customPlaylists,
          addToSongIds: _effectiveSelectedSongIds(queueSongIds),
          includeNowPlayingInAddTo: true,
          includeFavoritesInAddTo:
              widget.type != HeaderedPlaylistType.favorites,
          onAddToNowPlaying: () {
            _addSongsToNowPlaying(_effectiveSelectedSongIds(queueSongIds));
            _hideSelectionAfterOperation();
          },
          onToggleFavorite:
              widget.type == HeaderedPlaylistType.favorites
                  ? null
                  : () {
                    final songIds = _effectiveSelectedSongIds(queueSongIds);
                    ref
                        .read(libraryRepositoryProvider)
                        .setSongsFavorite(songIds, true);
                    ref.invalidate(musicLibrarySnapshotProvider);
                    _hideSelectionAfterOperation();
                  },
          onCreatePlaylist: () {
            unawaited(
              _createPlaylistFromSongs(
                i18n,
                _effectiveSelectedSongIds(queueSongIds),
              ),
            );
            _hideSelectionAfterOperation();
          },
          removeLabel:
              widget.type == HeaderedPlaylistType.favorites
                  ? i18n.t('context.removeFavorite')
                  : i18n.t('playlists.removeSelected'),
          onPlay: () {
            final selectedSongIds = _effectiveSelectedSongIds(queueSongIds);
            widget.onPlayTrack(selectedSongIds.first, selectedSongIds);
            _hideSelectionAfterOperation();
          },
          onAddToPlaylist: (playlistId) {
            final selectedSongIds = _effectiveSelectedSongIds(queueSongIds);
            widget.onAddSongsToPlaylist?.call(playlistId, selectedSongIds);
            _hideSelectionAfterOperation();
          },
          onRemove: () {
            unawaited(
              _removeSongsFromCurrentPlaylist(
                _effectiveSelectedSongIds(queueSongIds),
              ),
            );
          },
          onSelectAll: () {
            setState(() {
              _selection.selectAll(queueSongIds);
            });
          },
          onReverseSelection: () {
            setState(() {
              _selection.reverseSelection(queueSongIds);
            });
          },
          onClearSelection: () {
            setState(() {
              _selection.clearSelection();
            });
          },
          onCancel: () {
            setState(() {
              _selection.cancel();
            });
          },
        ),
      ],
    );
  }

  Widget _buildCommandBar(
    BuildContext context,
    SmPlayerI18n i18n,
    List<LibrarySong> visibleSongs,
    List<int> queueSongIds,
    PlaylistSortCriterion activeSortCriterion,
    List<MultiSelectCommandBarPlaylist> customPlaylists,
  ) {
    return CommandBar(
      dynamicOverflow: true,
      overflowItems: _sortMenuItems(i18n, activeSortCriterion),
      overflowLabel: i18n.t('player.more'),
      children: [
        CommandBarButton(
          icon: FluentIcons.arrow_shuffle_20_regular,
          label: captionForHeaderedPlaylist(i18n, 'shuffle'),
          disabled: visibleSongs.isEmpty,
          onPressed: () {
            _shuffle(queueSongIds);
          },
        ),
        CommandBarButton(
          icon: FluentIcons.checkbox_checked_20_regular,
          label: captionForHeaderedPlaylist(i18n, 'multiSelect'),
          active: _selection.multiSelect,
          disabled: visibleSongs.isEmpty,
          onPressed: () {
            setState(() {
              _selection.enterMultiSelect();
            });
          },
        ),
        if (widget.canSetPreferred)
          CommandBarButton(
            icon: FluentIcons.star_20_regular,
            label: captionForHeaderedPlaylist(i18n, 'preferenceSettings'),
            onPressed: () {
              showMenuFlyout(
                context,
                items: [
                  for (final level in const [
                    'do-not-appear',
                    'dislike',
                    'normal',
                    'high',
                    'higher',
                    'very-high',
                  ])
                    MenuFlyoutItem(
                      key: 'preference-$level',
                      text: i18n.t('preferences.level.$level'),
                      onPressed: () {
                        widget.onSetPreferred?.call(level);
                      },
                    ),
                ],
              );
            },
          ),
        CommandBarButton(
          icon: FluentIcons.arrow_sort_20_regular,
          label: captionForHeaderedPlaylist(i18n, 'sort'),
          disabled: visibleSongs.isEmpty,
          active: widget.sortCriterion == activeSortCriterion,
          onPressed: () {
            showMenuFlyout(
              context,
              items: _sortMenuItems(i18n, activeSortCriterion),
            );
          },
        ),
        if (widget.canRename)
          CommandBarButton(
            icon: FluentIcons.edit_20_regular,
            label: captionForHeaderedPlaylist(i18n, 'rename'),
            onPressed: () {
              unawaited(_requestRename(i18n));
            },
          ),
        if (widget.canDelete)
          CommandBarButton(
            icon: FluentIcons.delete_20_regular,
            label: captionForHeaderedPlaylist(i18n, 'delete'),
            onPressed: () {
              unawaited(_requestDelete(i18n));
            },
          ),
        if (widget.canClear)
          CommandBarButton(
            icon: FluentIcons.dismiss_circle_20_regular,
            label: captionForHeaderedPlaylist(i18n, 'clear'),
            onPressed: () {
              unawaited(_requestClear(i18n));
            },
          ),
        if (widget.canEditArtwork)
          CommandBarButton(
            icon: FluentIcons.image_edit_20_regular,
            label: captionForHeaderedPlaylist(i18n, 'editArtwork'),
            onPressed: widget.onEditArtwork,
          ),
      ],
    );
  }

  List<MenuFlyoutItem> _sortMenuItems(
    SmPlayerI18n i18n,
    PlaylistSortCriterion activeSortCriterion,
  ) {
    return [
      MenuFlyoutItem(
        key: 'reverse',
        text: captionForHeaderedPlaylist(i18n, 'sort.reverse'),
        onPressed: _reverseSort,
      ),
      const MenuFlyoutItem.separator(key: 'sort-separator'),
      for (final criterion in sortOptions)
        MenuFlyoutItem(
          key: criterion.name,
          text: captionForHeaderedPlaylist(i18n, sortCaptionKey(criterion)),
          checked: criterion == activeSortCriterion,
          onPressed: () {
            _commitSort(criterion, activeSortCriterion);
          },
        ),
    ];
  }

  List<LibrarySong> _visibleSongs(Map<int, LibrarySong> songsById) {
    final orderedSongIds = _orderedSongIds;
    if (orderedSongIds == null) {
      return widget.songs;
    }

    final orderedSongIdSet = orderedSongIds.toSet();
    return [
      ...orderedSongIds
          .map((songId) => songsById[songId])
          .whereType<LibrarySong>(),
      ...widget.songs.where((song) => !orderedSongIdSet.contains(song.id)),
    ];
  }

  List<String> _headerArtworkUrls(List<LibrarySong> headerSongs) {
    if (widget.type == HeaderedPlaylistType.album) {
      return widget.artworkUrl.isEmpty ? const [] : [widget.artworkUrl];
    }

    final urls = <String>[];
    for (final song in headerSongs) {
      if (song.thumbnailPath.isNotEmpty && !urls.contains(song.thumbnailPath)) {
        urls.add(song.thumbnailPath);
      }
    }
    if (urls.isEmpty && widget.artworkUrl.isNotEmpty) {
      urls.add(widget.artworkUrl);
    }
    return urls;
  }

  void _playSong(LibrarySong song, List<int> queueSongIds) {
    if (widget.onMoveToMusicOrPlay != null) {
      widget.onMoveToMusicOrPlay!(song.id);
      return;
    }

    widget.onPlayTrack(song.id, queueSongIds);
  }

  void _shuffle(List<int> queueSongIds) {
    final shuffledSongIds = shuffleSongIds(queueSongIds);
    widget.onRecordPlay?.call();
    widget.onPlayTrack(shuffledSongIds.first, shuffledSongIds);
  }

  void _addSongsToNowPlaying(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }

    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    ref.read(libraryRepositoryProvider).replaceNowPlaying([
      ...snapshot.nowPlaying.songIds,
      ...songIds,
    ]);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _commitSort(
    PlaylistSortCriterion criterion,
    PlaylistSortCriterion activeSortCriterion,
  ) {
    final sortedSongs =
        criterion == activeSortCriterion
            ? _currentVisibleSongs().reversed.toList()
            : sortSongs(widget.songs, criterion);
    final sortedSongIds = sortedSongs.map((song) => song.id).toList();
    setState(() {
      _orderedSongIds = sortedSongIds;
      _selectedSortCriterion = criterion;
    });
    widget.onSortSongs?.call(sortedSongIds, criterion);
  }

  void _reverseSort() {
    final activeSortCriterion =
        _selectedSortCriterion ??
        widget.sortCriterion ??
        inferSortCriterion(widget.songs);
    final reversedSongs = _currentVisibleSongs().reversed.toList();
    final reversedSongIds = reversedSongs.map((song) => song.id).toList();
    setState(() {
      _orderedSongIds = reversedSongIds;
      _selectedSortCriterion = activeSortCriterion;
    });
    widget.onSortSongs?.call(reversedSongIds, activeSortCriterion);
  }

  List<LibrarySong> _currentVisibleSongs() {
    return _visibleSongs({for (final song in widget.songs) song.id: song});
  }

  List<int> _effectiveSelectedSongIds(List<int> queueSongIds) {
    final queueSongIdSet = queueSongIds.toSet();
    return _selection.selectedItems
        .where((songId) => queueSongIdSet.contains(songId))
        .toList();
  }

  Future<void> _removeSongsFromCurrentPlaylist(List<int> songIds) async {
    await widget.onRemoveSongs?.call(songIds);
    _hideSelectionAfterOperation();
  }

  void _hideSelectionAfterOperation() {
    final snapshot = ref.read(musicLibrarySnapshotProvider).valueOrNull;
    setState(() {
      _selection.hideAfterOperation(
        snapshot?.hideMultiSelectCommandBarAfterOperation ?? true,
      );
    });
  }

  void _showSongMenu(
    BuildContext context,
    SmPlayerI18n i18n,
    Offset position,
    LibrarySong song,
    int index,
  ) {
    showMenuFlyout(
      context,
      position: position,
      items: [
        MenuFlyoutItem(
          key: 'play',
          text:
              widget.selectedTrackId == song.id && widget.isPlaying
                  ? i18n.t('context.pause')
                  : i18n.t('context.play'),
          icon:
              widget.selectedTrackId == song.id && widget.isPlaying
                  ? FluentIcons.pause_20_regular
                  : FluentIcons.play_20_regular,
          onPressed: () {
            if (widget.selectedTrackId == song.id && widget.isPlaying) {
              widget.onTogglePlayPause?.call();
              return;
            }
            _playSong(
              song,
              _currentVisibleSongs().map((item) => item.id).toList(),
            );
          },
        ),
        MenuFlyoutItem(
          key: 'play-next',
          text: i18n.t('context.playNext'),
          icon: FluentIcons.next_20_regular,
          onPressed: () {
            widget.onPlayNext?.call(song.id);
          },
        ),
        MenuFlyoutItem(
          key: 'select',
          text: i18n.t('context.select'),
          icon: FluentIcons.checkbox_checked_20_regular,
          onPressed: () {
            setState(() {
              _selection.enterMultiSelect();
              _selection.selectSingle(song.id);
            });
          },
        ),
        if (widget.onArtistClick != null)
          MenuFlyoutItem(
            key: 'artist',
            text: i18n.t('context.seeArtist'),
            icon: FluentIcons.person_20_regular,
            onPressed: () {
              widget.onArtistClick?.call(song.artist);
            },
          ),
        if (widget.onAlbumClick != null)
          MenuFlyoutItem(
            key: 'album',
            text: i18n.t('context.seeAlbum'),
            icon: FluentIcons.album_20_regular,
            onPressed: () {
              widget.onAlbumClick?.call(song.album);
            },
          ),
        MenuFlyoutItem(
          key: 'favorite',
          text:
              song.favorite
                  ? i18n.t('context.removeFavorite')
                  : i18n.t('context.addFavorite'),
          icon:
              song.favorite
                  ? FluentIcons.heart_20_filled
                  : FluentIcons.heart_20_regular,
          onPressed: () {
            if (widget.type == HeaderedPlaylistType.favorites &&
                song.favorite) {
              unawaited(_removeSongsFromCurrentPlaylist([song.id]));
              return;
            }
            widget.onToggleFavorite?.call(song.id, !song.favorite);
          },
        ),
        if (widget.removable)
          MenuFlyoutItem(
            key: 'remove',
            text:
                widget.type == HeaderedPlaylistType.favorites
                    ? i18n.t('context.removeFavorite')
                    : i18n.t('context.removeFromList'),
            icon: FluentIcons.delete_20_regular,
            onPressed: () {
              unawaited(_removeSongsFromCurrentPlaylist([song.id]));
            },
          ),
      ],
    );
  }

  Future<void> _createPlaylistFromSongs(
    SmPlayerI18n i18n,
    List<int> songIds,
  ) async {
    final defaultName = getNextPlaylistName(
      isBadNewPlaylistName(widget.title, i18n) ? '' : widget.title,
      widget.playlists,
    );
    final name = await _requestPlaylistName(
      i18n: i18n,
      title: i18n.t('playlists.createNew'),
      defaultName: defaultName,
      confirmText: i18n.t('playlists.create'),
      currentName: '',
    );
    if (name == null) {
      return;
    }

    await ref.read(libraryRepositoryProvider).createPlaylist(name, songIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  Future<void> _requestRename(SmPlayerI18n i18n) async {
    final name = await _requestPlaylistName(
      i18n: i18n,
      title: i18n.t('playlists.rename'),
      defaultName: widget.title,
      confirmText: i18n.t('playlists.rename'),
      currentName: widget.title,
    );
    if (name != null && name != widget.title) {
      widget.onRename?.call(name);
    }
  }

  Future<String?> _requestPlaylistName({
    required SmPlayerI18n i18n,
    required String title,
    required String defaultName,
    required String confirmText,
    required String currentName,
  }) {
    final controller = TextEditingController(text: defaultName);
    var errorText = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: i18n.t('playlists.namePlaceholder'),
                  errorText: errorText.isEmpty ? null : errorText,
                ),
                onSubmitted: (_) {
                  _confirmPlaylistName(
                    context,
                    controller,
                    currentName,
                    i18n,
                    setDialogState,
                    (value) {
                      errorText = value;
                    },
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(i18n.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    _confirmPlaylistName(
                      context,
                      controller,
                      currentName,
                      i18n,
                      setDialogState,
                      (value) {
                        errorText = value;
                      },
                    );
                  },
                  child: Text(confirmText),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  void _confirmPlaylistName(
    BuildContext dialogContext,
    TextEditingController controller,
    String currentName,
    SmPlayerI18n i18n,
    StateSetter setDialogState,
    ValueChanged<String> setErrorText,
  ) {
    final name = controller.text.trim();
    final error = validatePlaylistName(
      name,
      widget.playlists,
      currentName,
      i18n,
    );
    if (error.isNotEmpty) {
      setDialogState(() {
        setErrorText(error);
      });
      return;
    }

    Navigator.of(dialogContext).pop(name);
  }

  Future<void> _requestDelete(SmPlayerI18n i18n) async {
    final confirmed = await _requestConfirm(
      title: captionForHeaderedPlaylist(i18n, 'delete'),
      message: i18n.t('headeredPlaylist.deleteConfirm', {'name': widget.title}),
      confirmText: captionForHeaderedPlaylist(i18n, 'delete'),
    );
    if (confirmed) {
      widget.onDelete?.call();
    }
  }

  Future<void> _requestClear(SmPlayerI18n i18n) async {
    final confirmed = await _requestConfirm(
      title: captionForHeaderedPlaylist(i18n, 'clear'),
      message: i18n.t('headeredPlaylist.clearConfirm', {'name': widget.title}),
      confirmText: captionForHeaderedPlaylist(i18n, 'clear'),
    );
    if (confirmed) {
      widget.onClear?.call();
    }
  }

  Future<bool> _requestConfirm({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final i18n = context.smPlayerI18n;
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: Text(i18n.t('common.cancel')),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: Text(confirmText),
                  ),
                ],
              ),
        ) ??
        false;
  }
}

class _HeaderHero extends StatelessWidget {
  const _HeaderHero({
    required this.type,
    required this.title,
    required this.info,
    required this.artworkUrls,
    required this.commandBar,
    this.subtitle,
    this.caption,
  });

  final HeaderedPlaylistType type;
  final String title;
  final String? subtitle;
  final String? caption;
  final String info;
  final List<String> artworkUrls;
  final Widget commandBar;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 326),
      padding: const EdgeInsets.fromLTRB(32, 58, 32, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _HeaderedPlaylistColors.heroTint,
            _HeaderedPlaylistColors.heroSurface,
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth <= 720;
                  final copy = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (caption != null) ...[
                        Text(
                          caption!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _HeaderedPlaylistColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        title,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _HeaderedPlaylistColors.textStrong,
                          fontSize: compact ? 30 : 46,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _HeaderedPlaylistColors.textMuted,
                            fontSize: 15,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        info,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _HeaderedPlaylistColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                  return Flex(
                    direction: compact ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      HeaderedPlaylistCover(
                        artworkUrls: artworkUrls,
                        title: title,
                        type: type,
                      ),
                      SizedBox(
                        width: compact ? 0 : 28,
                        height: compact ? 18 : 0,
                      ),
                      if (compact) copy else Expanded(child: copy),
                    ],
                  );
                },
              ),
              const SizedBox(height: 30),
              commandBar,
            ],
          ),
        ),
      ),
    );
  }
}

class HeaderedPlaylistCover extends StatelessWidget {
  const HeaderedPlaylistCover({
    super.key,
    required this.artworkUrls,
    required this.title,
    required this.type,
  });

  final List<String> artworkUrls;
  final String title;
  final HeaderedPlaylistType type;

  @override
  Widget build(BuildContext context) {
    if (artworkUrls.length >= 3 && type != HeaderedPlaylistType.album) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox.square(
          dimension: 240,
          child: GridView.count(
            crossAxisCount: 2,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              for (final artworkUrl in artworkUrls.take(4))
                _CoverImage(artworkUrl: artworkUrl),
              if (artworkUrls.length == 3) const _CoverFallback(),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox.square(
        dimension: 240,
        child:
            artworkUrls.isEmpty
                ? const _CoverFallback()
                : _CoverImage(artworkUrl: artworkUrls.first),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.artworkUrl});

  final String artworkUrl;

  @override
  Widget build(BuildContext context) {
    final file = File(artworkUrl);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }

    return const _CoverFallback();
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _HeaderedPlaylistColors.coverA,
            _HeaderedPlaylistColors.coverB,
          ],
        ),
      ),
      child: Icon(
        FluentIcons.music_note_2_24_regular,
        color: Colors.white,
        size: 58,
      ),
    );
  }
}

class _HeaderedPlaylistListHeader extends StatelessWidget {
  const _HeaderedPlaylistListHeader({required this.showAlbum});

  final bool showAlbum;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _HeaderedPlaylistColors.listBorder),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 12,
            child: Text(
              i18n.t('headeredPlaylist.songArtist'),
              style: const TextStyle(
                color: _HeaderedPlaylistColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (showAlbum) ...[
            const SizedBox(width: 14),
            Expanded(
              flex: 5,
              child: Text(
                i18n.t('table.album'),
                style: const TextStyle(
                  color: _HeaderedPlaylistColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(width: 14),
          SizedBox(
            width: 148,
            child: Text(
              i18n.t('table.duration'),
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: _HeaderedPlaylistColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderedPlaylistColors {
  const _HeaderedPlaylistColors._();

  static const heroTint = Color(0xeaf1f7ff);
  static const heroSurface = Color(0xdffafcff);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff607085);
  static const listBorder = Color(0x297e8b9a);
  static const coverA = Color(0xff6794c6);
  static const coverB = Color(0xff6f7fc8);
}
