import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_app_bar_portal.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_model.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/library/ui/playlist_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
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

const _defaultHeaderArtworkColor = Color(0xff5b87b6);
const _headerArtworkColorMinValue = 10;
const _headerArtworkColorMaxValue = 205;
const _headerArtworkColorGridDivisions = 16;

@visibleForTesting
Color selectHeaderArtworkColorFromRgba(
  Uint8List rgbaPixels,
  int width,
  int height,
) {
  var selected = _defaultHeaderArtworkColor;
  var selectedDistance = -1;
  for (var xIndex = 1; xIndex < _headerArtworkColorGridDivisions; xIndex += 1) {
    for (
      var yIndex = 1;
      yIndex < _headerArtworkColorGridDivisions;
      yIndex += 1
    ) {
      final x = min(
        width - 1,
        (width * xIndex) ~/ _headerArtworkColorGridDivisions,
      );
      final y = min(
        height - 1,
        (height * yIndex) ~/ _headerArtworkColorGridDivisions,
      );
      final offset = (y * width + x) * 4;
      final red = rgbaPixels[offset];
      final green = rgbaPixels[offset + 1];
      final blue = rgbaPixels[offset + 2];
      final alpha = rgbaPixels[offset + 3];

      if (alpha == 0 ||
          red < _headerArtworkColorMinValue ||
          red > _headerArtworkColorMaxValue ||
          green < _headerArtworkColorMinValue ||
          green > _headerArtworkColorMaxValue ||
          blue < _headerArtworkColorMinValue ||
          blue > _headerArtworkColorMaxValue) {
        continue;
      }

      final distance =
          pow(red - _headerArtworkColorMinValue, 2) +
          pow(green - _headerArtworkColorMinValue, 2) +
          pow(blue - _headerArtworkColorMinValue, 2);
      if (distance > selectedDistance) {
        selected = Color.fromARGB(255, red, green, blue);
        selectedDistance = distance.toInt();
      }
    }
  }
  return selected;
}

@visibleForTesting
Color mixHeaderArtworkColors(List<Color> colors) {
  if (colors.isEmpty) {
    return _defaultHeaderArtworkColor;
  }
  var red = 0;
  var green = 0;
  var blue = 0;
  for (final color in colors) {
    red += (color.r * 255).round().clamp(0, 255);
    green += (color.g * 255).round().clamp(0, 255);
    blue += (color.b * 255).round().clamp(0, 255);
  }
  return Color.fromARGB(
    255,
    (red / colors.length).round(),
    (green / colors.length).round(),
    (blue / colors.length).round(),
  );
}

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
  late PageSelectionController<int> _selection;
  final _scrollController = ScrollController();
  List<int>? _orderedSongIds;
  PlaylistSortCriterion? _selectedSortCriterion;
  LibrarySong? _dialogSong;
  SongDialogMode? _dialogMode;
  List<String> _resolvedPlaylistArtworkUrls = const [];
  String _playlistArtworkSignature = '';
  var _playlistArtworkGeneration = 0;
  var _headerArtworkColorSignature = '';
  var _headerArtworkColorGeneration = 0;
  var _headerCoverColor = _defaultHeaderArtworkColor;
  var _scrollTop = 0.0;
  var _headerCollapsed = false;
  final _appBarPortalOwner = Object();
  String? _appBarPortalSignature;

  @override
  void initState() {
    super.initState();
    _selection = PageSelectionController<int>.stored(
      _selectionStorageKeyFor(widget),
    );
    _scrollController.addListener(_handleScroll);
    _refreshPlaylistArtwork();
    _refreshHeaderArtworkColor(_currentHeaderArtworkUrls());
  }

  @override
  void didUpdateWidget(HeaderedPlaylistControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectionStorageKeyFor(oldWidget) != _selectionStorageKeyFor(widget)) {
      _selection = PageSelectionController<int>.stored(
        _selectionStorageKeyFor(widget),
      );
    }
    if (oldWidget.songs != widget.songs) {
      _orderedSongIds = null;
      _selectedSortCriterion = null;
    }
    if (oldWidget.songs != widget.songs ||
        oldWidget.headerSongs != widget.headerSongs ||
        oldWidget.type != widget.type ||
        oldWidget.artworkUrl != widget.artworkUrl) {
      _refreshPlaylistArtwork();
      _refreshHeaderArtworkColor(_currentHeaderArtworkUrls());
    }
  }

  String _selectionStorageKeyFor(HeaderedPlaylistControl widget) {
    return 'headered-playlist:${widget.preferenceType ?? widget.type.name}:${widget.preferenceItemId ?? widget.title}';
  }

  @override
  void dispose() {
    _clearAppBarPortal();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _syncAppBarPortal({
    required bool compact,
    required List<LibrarySong> visibleSongs,
    required List<int> queueSongIds,
    required PlaylistSortCriterion activeSortCriterion,
    required SmPlayerI18n i18n,
  }) {
    final showPortal = compact && _headerCollapsed;
    final playlistSignature = widget.playlists
        .map(
          (playlist) =>
              '${playlist.id}:${playlist.name}:${playlist.songIds.length}',
        )
        .join('|');
    final signature =
        '$showPortal:${widget.title}:$activeSortCriterion:${_selection.multiSelect}:'
        '${queueSongIds.join(',')}:$playlistSignature:'
        '${widget.canRename}:${widget.canDelete}:${widget.canClear}:'
        '${widget.canEditArtwork}:${widget.canSetPreferred}';
    if (_appBarPortalSignature == signature) {
      return;
    }
    _appBarPortalSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final notifier = ref.read(headeredPlaylistAppBarPortalProvider.notifier);
      if (!showPortal) {
        final current = notifier.state;
        if (current?.owner == _appBarPortalOwner) {
          notifier.state = null;
        }
        return;
      }
      notifier.state = HeaderedPlaylistAppBarPortalEntry(
        owner: _appBarPortalOwner,
        title: widget.title,
        commandBar: _buildShyCommandBar(
          context,
          i18n,
          visibleSongs,
          queueSongIds,
          activeSortCriterion,
        ),
      );
    });
  }

  void _clearAppBarPortal() {
    final notifier = ref.read(headeredPlaylistAppBarPortalProvider.notifier);
    if (notifier.state?.owner == _appBarPortalOwner) {
      notifier.state = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final collapseDistance = compact ? 136.0 : 210.0;
    final collapseProgress = (_scrollTop / collapseDistance).clamp(0.0, 1.0);
    final songsById = {for (final song in widget.songs) song.id: song};
    final visibleSongs = _visibleSongs(songsById);
    final queueSongIds = visibleSongs.map((song) => song.id).toList();
    final activeSortCriterion =
        _selectedSortCriterion ??
        widget.sortCriterion ??
        inferSortCriterion(widget.songs);
    final headerSongs = widget.headerSongs ?? widget.songs;
    final headerArtworkUrls = _currentHeaderArtworkUrls();
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
    final currentSavedPlaylist =
        widget.type == HeaderedPlaylistType.playlist
            ? widget.playlists.firstWhere(
              (playlist) => playlist.name == widget.title,
            )
            : null;
    final currentPlaylistName =
        widget.type == HeaderedPlaylistType.favorites
            ? i18n.t('common.myFavorites')
            : widget.type == HeaderedPlaylistType.playlist
            ? currentSavedPlaylist!.name
            : widget.title;

    final colors = _HeaderedPlaylistColors.resolve(
      Theme.of(context).brightness == Brightness.dark,
    );
    _syncAppBarPortal(
      compact: compact,
      visibleSongs: visibleSongs,
      queueSongIds: queueSongIds,
      activeSortCriterion: activeSortCriterion,
      i18n: i18n,
    );

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.pageSurface),
      child: Stack(
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: CustomScrollView(
              key: const ValueKey('HeaderedPlaylist.ScrollView'),
              controller: _scrollController,
              slivers: [
                if (compact)
                  SliverToBoxAdapter(
                    child: _HeaderHero(
                      type: widget.type,
                      title: widget.title,
                      subtitle: widget.subtitle,
                      caption: widget.caption,
                      info: getHeaderPlaylistInfo(headerSongs, i18n),
                      artworkUrls: headerArtworkUrls,
                      coverColor: _headerCoverColor,
                      collapseProgress: collapseProgress,
                      commandBar: _buildCommandBar(
                        context,
                        i18n,
                        visibleSongs,
                        queueSongIds,
                        activeSortCriterion,
                        customPlaylists,
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox(height: 344)),
                _HeaderedPlaylistListSliver(
                  showAlbum: widget.showAlbum,
                  itemCount: visibleSongs.length,
                  bottomPadding:
                      _selection.multiSelect
                          ? multiSelectCommandBarScrollSpacer
                          : 56,
                  itemBuilder: (context, index) {
                    final song = visibleSongs[index];
                    final current = song.id == widget.selectedTrackId;
                    return PlaylistControlItem(
                      key: ValueKey('HeaderedPlaylist.Row.${song.id}'),
                      song: song,
                      current: current,
                      playing: current && widget.isPlaying,
                      selected: _selection.isSelected(song.id),
                      selectionMode: _selection.multiSelect,
                      showAlbum: widget.showAlbum,
                      variant: PlaylistControlItemVariant.headeredPlaylist,
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
                                widget.onToggleFavorite!(
                                  song.id,
                                  !song.favorite,
                                );
                              },
                      onAddToPlaylistClick: (buttonContext) {
                        final item = buildAddToPlaylistMenuFlyoutItem(
                          i18n: i18n,
                          songIds: [song.id],
                          playlists: customPlaylists,
                          currentPlaylistName: currentPlaylistName,
                          excludePlaylistName: currentSavedPlaylist?.name,
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
                            unawaited(
                              _createPlaylistFromSongs(i18n, [song.id]),
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
                        unawaited(
                          _showSongMenu(context, i18n, position, song, index),
                        );
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
              ],
            ),
          ),
          _HeaderedPlaylistScrollbar(
            controller: _scrollController,
            collapseProgress: collapseProgress,
          ),
          if (!compact)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _HeaderHero(
                type: widget.type,
                title: widget.title,
                subtitle: widget.subtitle,
                caption: widget.caption,
                info: getHeaderPlaylistInfo(headerSongs, i18n),
                artworkUrls: headerArtworkUrls,
                coverColor: _headerCoverColor,
                collapseProgress: collapseProgress,
                extendBackdrop: false,
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
          MultiSelectCommandBar(
            visible: _selection.multiSelect,
            selectedCount: _effectiveSelectedSongIds(queueSongIds).length,
            playlists: customPlaylists,
            addToSongIds: _effectiveSelectedSongIds(queueSongIds),
            includeNowPlayingInAddTo: true,
            includeFavoritesInAddTo:
                widget.type != HeaderedPlaylistType.favorites,
            currentPlaylistName: currentPlaylistName,
            excludePlaylistName: currentSavedPlaylist?.name,
            onAddToNowPlaying: () {
              _addSongsToNowPlaying(_effectiveSelectedSongIds(queueSongIds));
              _hideSelectionAfterOperation();
            },
            onToggleFavorite:
                widget.type == HeaderedPlaylistType.favorites
                    ? null
                    : () {
                      final songIds = _effectiveSelectedSongIds(queueSongIds);
                      unawaited(
                        setSongsFavoriteWithUndo(
                          context: context,
                          ref: ref,
                          i18n: i18n,
                          songIds: songIds,
                          favorite: true,
                        ),
                      );
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
              unawaited(
                addSongsToPlaylistWithUndo(
                  context: context,
                  ref: ref,
                  i18n: i18n,
                  playlistId: playlistId,
                  songIds: selectedSongIds,
                ),
              );
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
          if (_dialogSong != null && _dialogMode != null)
            MusicDialog(
              song: _dialogSong!,
              initialMode: _dialogMode!,
              canPause:
                  widget.isPlaying && widget.selectedTrackId == _dialogSong!.id,
              onPlay: widget.onTogglePlayPause,
              onReveal: _revealPath,
              onSaved: () {
                ref.invalidate(musicLibrarySnapshotProvider);
              },
              onClose: () {
                setState(() {
                  _dialogSong = null;
                  _dialogMode = null;
                });
              },
            ),
        ],
      ),
    );
  }

  void _handleScroll() {
    final nextScrollTop = _scrollController.offset;
    if ((nextScrollTop - _scrollTop).abs() < 0.5) {
      return;
    }
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final nextHeaderCollapsed =
        _headerCollapsed
            ? nextScrollTop > (compact ? 76.0 : 186.0)
            : nextScrollTop >= (compact ? 112.0 : 224.0);
    setState(() {
      _scrollTop = nextScrollTop;
      _headerCollapsed = nextHeaderCollapsed;
    });
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
      variant: CommandBarVariant.headeredPlaylist,
      dynamicOverflow: true,
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
          icon: FluentIcons.multiselect_ltr_20_regular,
          label: captionForHeaderedPlaylist(i18n, 'multiSelect'),
          active: _selection.multiSelect,
          disabled: visibleSongs.isEmpty,
          onPressed: () {
            setState(() {
              _selection.enterMultiSelect();
            });
          },
        ),
        if (widget.canSetPreferred && widget.onSetPreferred != null)
          Builder(
            builder:
                (_) => CommandBarButton(
                  icon: FluentIcons.star_20_regular,
                  label: captionForHeaderedPlaylist(i18n, 'preferenceSettings'),
                  onPressedWithContext: (buttonContext) {
                    unawaited(_showHeaderPreferenceMenu(buttonContext, i18n));
                  },
                ),
          ),
        Builder(
          builder:
              (buttonContext) => CommandBarButton(
                icon: FluentIcons.arrow_sort_20_regular,
                label: captionForHeaderedPlaylist(i18n, 'sort'),
                disabled: visibleSongs.isEmpty,
                overflowSubmenu: _sortMenuItems(i18n, activeSortCriterion),
                onPressed: () {
                  showMenuFlyout(
                    buttonContext,
                    items: _sortMenuItems(i18n, activeSortCriterion),
                  );
                },
              ),
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
            disabled: visibleSongs.isEmpty,
            onPressed: () {
              unawaited(_requestClear(i18n));
            },
          ),
        if (widget.canEditArtwork && widget.onEditArtwork != null)
          CommandBarButton(
            icon: FluentIcons.image_edit_20_regular,
            label: captionForHeaderedPlaylist(i18n, 'editArtwork'),
            onPressed: widget.onEditArtwork,
          ),
      ],
    );
  }

  Widget _buildShyCommandBar(
    BuildContext context,
    SmPlayerI18n i18n,
    List<LibrarySong> visibleSongs,
    List<int> queueSongIds,
    PlaylistSortCriterion activeSortCriterion,
  ) {
    return CommandBar(
      variant: CommandBarVariant.headeredPlaylistAppBar,
      dynamicOverflow: false,
      overflowItems: [
        MenuFlyoutItem(
          key: 'multi-select',
          text: captionForHeaderedPlaylist(i18n, 'multiSelect'),
          icon: FluentIcons.multiselect_ltr_20_regular,
          disabled: visibleSongs.isEmpty,
          onPressed: () {
            setState(() {
              _selection.enterMultiSelect();
            });
          },
        ),
        if (widget.canSetPreferred && widget.onSetPreferred != null)
          MenuFlyoutItem(
            key: 'preference-settings',
            text: captionForHeaderedPlaylist(i18n, 'preferenceSettings'),
            icon: FluentIcons.star_20_regular,
            onPressed: () {},
            onPressedWithContext: (buttonContext) {
              unawaited(_showHeaderPreferenceMenu(buttonContext, i18n));
            },
          ),
        MenuFlyoutItem(
          key: 'sort',
          text: captionForHeaderedPlaylist(i18n, 'sort'),
          icon: FluentIcons.arrow_sort_20_regular,
          disabled: visibleSongs.isEmpty,
          submenu: _sortMenuItems(i18n, activeSortCriterion),
        ),
        if (widget.canRename)
          MenuFlyoutItem(
            key: 'rename',
            text: captionForHeaderedPlaylist(i18n, 'rename'),
            icon: FluentIcons.edit_20_regular,
            onPressed: () {
              unawaited(_requestRename(i18n));
            },
          ),
        if (widget.canClear)
          MenuFlyoutItem(
            key: 'clear',
            text: captionForHeaderedPlaylist(i18n, 'clear'),
            icon: FluentIcons.dismiss_circle_20_regular,
            disabled: visibleSongs.isEmpty,
            onPressed: () {
              unawaited(_requestClear(i18n));
            },
          ),
        if (widget.canDelete)
          MenuFlyoutItem(
            key: 'delete',
            text: captionForHeaderedPlaylist(i18n, 'delete'),
            icon: FluentIcons.delete_20_regular,
            onPressed: () {
              unawaited(_requestDelete(i18n));
            },
          ),
        if (widget.canEditArtwork && widget.onEditArtwork != null)
          MenuFlyoutItem(
            key: 'edit-artwork',
            text: captionForHeaderedPlaylist(i18n, 'editArtwork'),
            icon: FluentIcons.image_edit_20_regular,
            onPressed: widget.onEditArtwork,
          ),
      ],
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
          icon:
              criterion == activeSortCriterion
                  ? FluentIcons.checkmark_20_regular
                  : null,
          onPressed: () {
            _commitSort(criterion, activeSortCriterion);
          },
        ),
    ];
  }

  Future<void> _showHeaderPreferenceMenu(
    BuildContext context,
    SmPlayerI18n i18n,
  ) async {
    final preferenceType = widget.preferenceType;
    final preferenceItemId = widget.preferenceItemId;
    final preferenceLevel =
        preferenceType == null || preferenceItemId == null
            ? null
            : await ref
                .read(libraryRepositoryProvider)
                .getPreferenceLevel(preferenceType, preferenceItemId);
    if (!context.mounted) {
      return;
    }

    final preferenceItem = buildPreferenceMenuFlyoutItem(
      i18n: i18n,
      key: 'preference',
      preferenceLevel: preferenceLevel,
      onUndoPreference:
          preferenceType == null ||
                  preferenceItemId == null ||
                  preferenceLevel == null
              ? null
              : () {
                ref
                    .read(libraryRepositoryProvider)
                    .removePreferenceItem(preferenceType, preferenceItemId);
                ref.invalidate(musicLibrarySnapshotProvider);
              },
      onSetPreference: (level) {
        widget.onSetPreferred?.call(level);
      },
    );
    showMenuFlyout(context, items: preferenceItem.submenu);
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

  void _refreshPlaylistArtwork() {
    if (widget.type == HeaderedPlaylistType.album) {
      _playlistArtworkSignature = '';
      _resolvedPlaylistArtworkUrls = const [];
      _refreshHeaderArtworkColor(_currentHeaderArtworkUrls());
      return;
    }

    final songs = widget.headerSongs ?? widget.songs;
    final signature = getPlaylistArtworkSignature(songs);
    if (signature == _playlistArtworkSignature) {
      return;
    }

    _playlistArtworkSignature = signature;
    final cachedArtworkUrls = getCachedPlaylistArtworkUrls(signature);
    if (cachedArtworkUrls != null) {
      _resolvedPlaylistArtworkUrls = cachedArtworkUrls;
      _refreshHeaderArtworkColor(_currentHeaderArtworkUrls());
      return;
    }

    _resolvedPlaylistArtworkUrls = const [];
    _refreshHeaderArtworkColor(_currentHeaderArtworkUrls());
    final generation = ++_playlistArtworkGeneration;
    unawaited(
      resolvePlaylistArtworkUrls(
        songs,
        ref.read(libraryRepositoryProvider),
      ).then((artworkUrls) {
        cachePlaylistArtworkUrls(signature, artworkUrls);
        if (!mounted ||
            generation != _playlistArtworkGeneration ||
            signature != _playlistArtworkSignature) {
          return;
        }
        _refreshHeaderArtworkColor(getPlaylistArtworkDisplayUrls(artworkUrls));
        setState(() {
          _resolvedPlaylistArtworkUrls = artworkUrls;
        });
      }),
    );
  }

  @override
  void reassemble() {
    super.reassemble();
    _playlistArtworkSignature = '';
    _refreshPlaylistArtwork();
  }

  List<String> _currentHeaderArtworkUrls() {
    if (widget.type == HeaderedPlaylistType.album) {
      return widget.artworkUrl.isEmpty ? const [] : [widget.artworkUrl];
    }
    return getPlaylistArtworkDisplayUrls(_resolvedPlaylistArtworkUrls);
  }

  void _refreshHeaderArtworkColor(List<String> artworkUrls) {
    final signature = artworkUrls.take(4).join('\n');
    if (signature == _headerArtworkColorSignature) {
      return;
    }
    _headerArtworkColorSignature = signature;
    if (signature.isEmpty) {
      _headerCoverColor = _defaultHeaderArtworkColor;
      return;
    }

    final generation = ++_headerArtworkColorGeneration;
    unawaited(
      Future.wait(artworkUrls.take(4).map(_extractHeaderArtworkColor)).then((
        colors,
      ) {
        if (!mounted ||
            generation != _headerArtworkColorGeneration ||
            signature != _headerArtworkColorSignature) {
          return;
        }
        final nextColor = mixHeaderArtworkColors(colors);
        if (nextColor == _headerCoverColor) {
          return;
        }
        setState(() {
          _headerCoverColor = nextColor;
        });
      }),
    );
  }

  Future<Color> _extractHeaderArtworkColor(String artworkPath) async {
    try {
      final bytes = await File(artworkPath).readAsBytes();
      final codec = await instantiateImageCodec(
        bytes,
      ).timeout(const Duration(seconds: 2));
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ImageByteFormat.rawRgba);
      final width = image.width;
      final height = image.height;
      image.dispose();
      codec.dispose();
      if (byteData == null) {
        return _defaultHeaderArtworkColor;
      }
      return selectHeaderArtworkColorFromRgba(
        byteData.buffer.asUint8List(),
        width,
        height,
      );
    } on Object {
      return _defaultHeaderArtworkColor;
    }
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
    unawaited(
      addSongsToNowPlayingWithUndo(
        context: context,
        ref: ref,
        i18n: context.smPlayerI18n,
        songIds: songIds,
      ),
    );
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
    _showUndoRemoveSongs(songIds);
    _hideSelectionAfterOperation();
  }

  void _showUndoRemoveSongs(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }
    final i18n = context.smPlayerI18n;
    final songsById = {for (final song in widget.songs) song.id: song};
    if (widget.type == HeaderedPlaylistType.favorites) {
      _showUndoSnackBar(
        () async {
          await ref
              .read(libraryRepositoryProvider)
              .setSongsFavorite(songIds, true);
          ref.invalidate(musicLibrarySnapshotProvider);
        },
        songsRemovedUndoMessage(
          i18n: i18n,
          songIds: songIds,
          songsById: songsById,
          target: i18n.t('common.myFavorites'),
        ),
      );
      return;
    }
    if (widget.type == HeaderedPlaylistType.playlist) {
      final playlist = widget.playlists.firstWhere(
        (playlist) => playlist.name == widget.title,
      );
      _showUndoSnackBar(
        () async {
          await ref
              .read(libraryRepositoryProvider)
              .addSongsToPlaylist(playlist.id, songIds);
          ref.invalidate(musicLibrarySnapshotProvider);
        },
        songsRemovedUndoMessage(
          i18n: i18n,
          songIds: songIds,
          songsById: songsById,
          target: playlist.name,
        ),
      );
    }
  }

  void _showUndoSnackBar(FutureOr<void> Function() onUndo, String message) {
    final i18n = context.smPlayerI18n;
    showUndoableSnackBar(
      context: context,
      i18n: i18n,
      message: message,
      onUndo: onUndo,
    );
  }

  void _hideSelectionAfterOperation() {
    final snapshot = ref.read(musicLibrarySnapshotProvider).valueOrNull;
    setState(() {
      _selection.hideAfterOperation(
        snapshot?.hideMultiSelectCommandBarAfterOperation ?? true,
      );
    });
  }

  Future<void> _showSongMenu(
    BuildContext context,
    SmPlayerI18n i18n,
    Offset position,
    LibrarySong song,
    int index,
  ) async {
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final preferenceLevel = await ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('song', '${song.id}');
    if (!context.mounted) {
      return;
    }
    final folders = _menuFolders(snapshot.folders);
    final currentSavedPlaylist =
        widget.type == HeaderedPlaylistType.playlist
            ? widget.playlists.firstWhere(
              (playlist) => playlist.name == widget.title,
            )
            : null;
    final currentPlaylistName =
        widget.type == HeaderedPlaylistType.favorites
            ? i18n.t('common.myFavorites')
            : widget.type == HeaderedPlaylistType.playlist
            ? currentSavedPlaylist!.name
            : widget.title;
    showMenuFlyout(
      context,
      position: position,
      items: buildMusicMenuFlyoutItems(
        i18n: i18n,
        songId: song.id,
        isFavorite: song.favorite,
        isCurrentTrack: widget.selectedTrackId == song.id,
        isPlaying: widget.isPlaying,
        currentTrackId: widget.selectedTrackId,
        songPath: song.path,
        playlists:
            snapshot.playlists
                .where((playlist) => !playlist.isBuiltIn)
                .map(
                  (playlist) => MultiSelectCommandBarPlaylist(
                    id: playlist.id,
                    name: playlist.name,
                    songIds: playlist.songIds,
                  ),
                )
                .toList(),
        currentPlaylistName: currentPlaylistName,
        excludePlaylistName: currentSavedPlaylist?.name,
        showRemove: widget.removable,
        removeLabel:
            widget.type == HeaderedPlaylistType.favorites
                ? i18n.t('context.removeFavorite')
                : null,
        onPlay: () {
          _playSong(
            song,
            _currentVisibleSongs().map((item) => item.id).toList(),
          );
        },
        onPause: () {
          widget.onTogglePlayPause?.call();
        },
        onPlayNext: () {
          if (widget.onPlayNext != null) {
            widget.onPlayNext!(song.id);
            return;
          }
          final nextQueue = snapshot.nowPlaying.songIds.toList();
          final currentIndex =
              widget.selectedTrackId == null
                  ? -1
                  : nextQueue.indexOf(widget.selectedTrackId!);
          nextQueue.insert(currentIndex < 0 ? 0 : currentIndex + 1, song.id);
          widget.onPlayTrack(widget.selectedTrackId ?? song.id, nextQueue);
        },
        onAddToNowPlaying: () {
          _addSongsToNowPlaying([song.id]);
        },
        onCreatePlaylist: () {
          unawaited(
            _createPlaylistFromSongs(i18n, [
              song.id,
            ], defaultSourceName: song.title),
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
          unawaited(_removeSongsFromCurrentPlaylist([song.id]));
        },
        onSelect: () {
          setState(() {
            _selection.enterMultiSelect();
            _selection.selectSingle(song.id);
          });
        },
        onToggleFavorite: () {
          if (widget.type == HeaderedPlaylistType.favorites && song.favorite) {
            unawaited(_removeSongsFromCurrentPlaylist([song.id]));
            return;
          }
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
        preferenceLevel: preferenceLevel,
        onUndoPreference:
            preferenceLevel == null
                ? null
                : () {
                  ref
                      .read(libraryRepositoryProvider)
                      .removePreferenceItem('song', '${song.id}');
                  ref.invalidate(musicLibrarySnapshotProvider);
                },
        onDelete: () {
          unawaited(
            requestDeleteSongFromDisk(
              context: context,
              ref: ref,
              i18n: i18n,
              song: song,
            ),
          );
        },
        folders: folders,
        showMoveToFolder: folders.isNotEmpty,
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
        showHideFile: true,
        onHide: () {
          unawaited(
            hideSongFileWithUndo(
              context: context,
              ref: ref,
              i18n: i18n,
              song: song,
            ),
          );
        },
        onSeeArtist: () {
          widget.onArtistClick?.call(_displayArtist(song, i18n));
        },
        onSeeAlbum: () {
          widget.onAlbumClick?.call(
            song.album.isEmpty ? i18n.t('common.albumUnknown') : song.album,
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
          unawaited(_revealPath(song.path));
        },
      ),
    );
  }

  List<MenuFlyoutFolder> _menuFolders(List<LibraryFolder> folders) {
    return folders
        .map(
          (folder) => MenuFlyoutFolder(
            id: folder.id,
            name: _displayPathName(folder.path),
            path: folder.path,
            parentId: folder.parentId,
          ),
        )
        .toList();
  }

  String _displayPathName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index < 0 ? normalized : normalized.substring(index + 1);
  }

  Future<void> _createPlaylistFromSongs(
    SmPlayerI18n i18n,
    List<int> songIds, {
    String? defaultSourceName,
  }) async {
    final defaultName = getNextPlaylistName(
      isBadNewPlaylistName(defaultSourceName ?? widget.title, i18n)
          ? ''
          : defaultSourceName ?? widget.title,
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

  void _openMusicDialog(LibrarySong song, SongDialogMode mode) {
    setState(() {
      _dialogSong = song;
      _dialogMode = mode;
    });
  }

  Future<void> _revealPath(String targetPath) async {
    await revealItemInFolder(targetPath);
  }

  String _displayArtist(LibrarySong song, SmPlayerI18n i18n) {
    final artists =
        song.artists.where((artist) => artist.trim().isNotEmpty).toList();
    if (artists.isNotEmpty) {
      return artists.first;
    }
    return song.artist.isEmpty ? i18n.t('common.artistUnknown') : song.artist;
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
    return showPopupTextDialog(
      context: context,
      title: title,
      initialValue: defaultName,
      confirmLabel: confirmText,
      placeholder: i18n.t('playlists.namePlaceholder'),
      validate:
          (name) =>
              validatePlaylistName(name, widget.playlists, currentName, i18n),
    );
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
    return showPopupConfirmDialog(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmText,
    );
  }
}

class _HeaderedPlaylistScrollbar extends StatefulWidget {
  const _HeaderedPlaylistScrollbar({
    required this.controller,
    required this.collapseProgress,
  });

  final ScrollController controller;
  final double collapseProgress;

  @override
  State<_HeaderedPlaylistScrollbar> createState() =>
      _HeaderedPlaylistScrollbarState();
}

class _HeaderedPlaylistScrollbarState
    extends State<_HeaderedPlaylistScrollbar> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final colors = _HeaderedPlaylistColors.resolve(
      Theme.of(context).brightness == Brightness.dark,
    );
    return Positioned(
      key: const ValueKey('HeaderedPlaylist.Scrollbar'),
      top:
          lerpDouble(
            compact ? 324 : 330,
            compact ? 142 : 130,
            widget.collapseProgress,
          )! +
          4,
      right: 2,
      bottom: 10,
      width: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              if (!widget.controller.hasClients) {
                return const SizedBox.shrink();
              }
              final position = widget.controller.position;
              final maxScrollExtent = position.maxScrollExtent;
              if (maxScrollExtent <= 0) {
                return const SizedBox.shrink();
              }

              final scrollbarHeight = max(48.0, constraints.maxHeight);
              final contentHeight = scrollbarHeight + maxScrollExtent;
              final thumbHeight = max(
                38.0,
                (scrollbarHeight / contentHeight) * scrollbarHeight,
              );
              final thumbTop =
                  (position.pixels / maxScrollExtent) *
                  (scrollbarHeight - thumbHeight);
              final thumbColor =
                  _hovered ? colors.scrollbarThumbHover : colors.scrollbarThumb;

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
                child: Stack(
                  children: [
                    Positioned(
                      top: thumbTop.clamp(0.0, scrollbarHeight - thumbHeight),
                      right: 2,
                      width: 4,
                      height: thumbHeight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (details) {
                          final trackDistance = scrollbarHeight - thumbHeight;
                          final scrollDelta =
                              details.delta.dy *
                              (maxScrollExtent / trackDistance);
                          widget.controller.jumpTo(
                            (position.pixels + scrollDelta).clamp(
                              0.0,
                              maxScrollExtent,
                            ),
                          );
                        },
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: thumbColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HeaderHero extends StatelessWidget {
  const _HeaderHero({
    required this.type,
    required this.title,
    required this.info,
    required this.artworkUrls,
    required this.coverColor,
    required this.collapseProgress,
    required this.commandBar,
    this.extendBackdrop = true,
    this.subtitle,
    this.caption,
  });

  final HeaderedPlaylistType type;
  final String title;
  final String? subtitle;
  final String? caption;
  final String info;
  final List<String> artworkUrls;
  final Color coverColor;
  final double collapseProgress;
  final Widget commandBar;
  final bool extendBackdrop;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    final colors = _HeaderedPlaylistColors.resolve(nightMode);
    final heroHeight =
        lerpDouble(compact ? 320 : 326, compact ? 138 : 126, collapseProgress)!;
    final coverSize =
        lerpDouble(compact ? 180 : 240, compact ? 68 : 86, collapseProgress)!;
    final titleSize =
        lerpDouble(compact ? 24 : 48, compact ? 20 : 26, collapseProgress)!;
    final commandMargin =
        lerpDouble(compact ? 8 : 30, compact ? 4 : 8, collapseProgress)!;
    final heroPaddingTop =
        compact ? 0.0 : lerpDouble(50, 24, collapseProgress)!;
    final horizontalPadding = compact ? 4.0 : 40.0;
    final gap =
        lerpDouble(compact ? 12 : 42, compact ? 12 : 18, collapseProgress)!;
    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            bottom: extendBackdrop ? -110 : 0,
            child: DecoratedBox(
              decoration: BoxDecoration(color: colors.pageSurface),
            ),
          ),
          Positioned.fill(
            bottom: extendBackdrop ? -110 : 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -0.56),
                  radius: 0.86,
                  colors:
                      nightMode
                          ? [
                            coverColor.withValues(alpha: 0.20),
                            coverColor.withValues(alpha: 0),
                          ]
                          : [
                            coverColor.withValues(alpha: 0.32),
                            coverColor.withValues(alpha: 0),
                          ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            bottom: extendBackdrop ? -110 : 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.78, -0.8),
                  radius: 1.0,
                  colors:
                      nightMode
                          ? [
                            coverColor.withValues(alpha: 0.10),
                            coverColor.withValues(alpha: 0),
                          ]
                          : [
                            coverColor.withValues(alpha: 0.16),
                            coverColor.withValues(alpha: 0),
                          ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              heroPaddingTop,
              horizontalPadding,
              compact ? 4 : lerpDouble(10, 4, collapseProgress)!,
            ),
            child: Flex(
              direction: compact ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment:
                  compact
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.center,
              children: [
                HeaderedPlaylistCover(
                  artworkUrls: artworkUrls,
                  title: title,
                  type: type,
                  size: coverSize,
                  collapseProgress: collapseProgress,
                ),
                SizedBox(width: compact ? 0 : gap, height: compact ? gap : 0),
                Expanded(
                  child: Column(
                    mainAxisAlignment:
                        compact
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                    crossAxisAlignment:
                        compact
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.start,
                    children: [
                      if (caption != null) ...[
                        Text(
                          caption!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        title,
                        maxLines: compact ? 2 : 3,
                        textAlign: compact ? TextAlign.center : TextAlign.start,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: titleSize,
                          height: 1.08,
                          fontWeight: FontWeight.w600,
                          fontVariations: const [FontVariation.weight(650)],
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: lerpDouble(8, 4, collapseProgress)!),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: lerpDouble(17, 14, collapseProgress)!,
                            fontWeight: FontWeight.w600,
                            fontVariations: const [FontVariation.weight(650)],
                          ),
                        ),
                      ],
                      SizedBox(height: lerpDouble(8, 4, collapseProgress)!),
                      ClipRect(
                        child: Align(
                          heightFactor: (1 - collapseProgress).clamp(0.0, 1.0),
                          child: Opacity(
                            opacity: (1 - collapseProgress).clamp(0.0, 1.0),
                            child: Text(
                              info,
                              maxLines: 1,
                              textAlign:
                                  compact ? TextAlign.center : TextAlign.start,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: lerpDouble(17, 14, collapseProgress)!,
                                fontWeight: FontWeight.w600,
                                fontVariations: const [
                                  FontVariation.weight(650),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: commandMargin),
                      Align(
                        alignment:
                            compact ? Alignment.center : Alignment.centerLeft,
                        child: SizedBox(
                          width: double.infinity,
                          child: commandBar,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
    this.size = 240,
    this.collapseProgress = 0,
  });

  final List<String> artworkUrls;
  final String title;
  final HeaderedPlaylistType type;
  final double size;
  final double collapseProgress;

  @override
  Widget build(BuildContext context) {
    final colors = _HeaderedPlaylistColors.resolve(
      Theme.of(context).brightness == Brightness.dark,
    );
    final radius = lerpDouble(14, 8, collapseProgress)!;
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: colors.coverShadow,
          offset: const Offset(0, 26),
          blurRadius: 58,
        ),
      ],
      border: Border.all(color: colors.coverInset),
    );

    final child =
        artworkUrls.length >= 3 && type != HeaderedPlaylistType.album
            ? GridView.count(
              crossAxisCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                for (final artworkUrl in artworkUrls.take(4))
                  _CoverImage(artworkUrl: artworkUrl),
                if (artworkUrls.length == 3) const _CoverMosaicFallback(),
              ],
            )
            : artworkUrls.isEmpty
            ? const _CoverFallback()
            : _CoverImage(artworkUrl: artworkUrls.first);

    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox.square(dimension: size, child: child),
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
    return const DefaultAlbumArtwork();
  }
}

class _CoverMosaicFallback extends StatelessWidget {
  const _CoverMosaicFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xff11161c)),
      child: Image.asset(
        'assets/branding/colorful_bg_wide.png',
        fit: BoxFit.cover,
      ),
    );
  }
}

class _HeaderedPlaylistListSliver extends StatelessWidget {
  const _HeaderedPlaylistListSliver({
    required this.showAlbum,
    required this.itemCount,
    required this.itemBuilder,
    required this.bottomPadding,
  });

  final bool showAlbum;
  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final colors = _HeaderedPlaylistColors.resolve(
      Theme.of(context).brightness == Brightness.dark,
    );
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        compact ? 2 : 40,
        compact ? 0 : 18,
        compact ? 2 : 40,
        bottomPadding,
      ),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: colors.listSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.listBorder),
          boxShadow: [
            BoxShadow(
              color: colors.listShadow,
              offset: const Offset(0, 14),
              blurRadius: 34,
            ),
          ],
        ),
        sliver: SliverMainAxisGroup(
          slivers: [
            if (!compact)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _HeaderedPlaylistListHeader(showAlbum: showAlbum),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 10),
              sliver: SliverList.builder(
                itemCount: itemCount,
                itemBuilder: itemBuilder,
              ),
            ),
          ],
        ),
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
    final colors = _HeaderedPlaylistColors.resolve(
      Theme.of(context).brightness == Brightness.dark,
    );
    return SizedBox(
      key: const ValueKey('HeaderedPlaylist.ListHeader'),
      height: 42,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const SizedBox(width: 64),
            const SizedBox(width: 14),
            Expanded(
              flex: 12,
              child: Text(
                i18n.t('headeredPlaylist.songArtist'),
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontVariations: const [FontVariation.weight(750)],
                ),
              ),
            ),
            if (showAlbum) ...[
              const SizedBox(width: 14),
              Expanded(
                flex: 5,
                child: Text(
                  i18n.t('table.album'),
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontVariations: const [FontVariation.weight(750)],
                  ),
                ),
              ),
            ],
            const SizedBox(width: 14),
            const SizedBox(width: 170),
            const SizedBox(width: 18),
            SizedBox(
              width: 74,
              child: Text(
                i18n.t('table.duration'),
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontVariations: const [FontVariation.weight(750)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderedPlaylistColors {
  const _HeaderedPlaylistColors({
    required this.pageSurface,
    required this.heroCover,
    required this.textStrong,
    required this.textMuted,
    required this.listSurface,
    required this.listBorder,
    required this.listShadow,
    required this.scrollbarThumb,
    required this.scrollbarThumbHover,
    required this.coverInset,
    required this.coverShadow,
    required this.coverA,
    required this.coverB,
  });

  final Color pageSurface;
  final Color heroCover;
  final Color textStrong;
  final Color textMuted;
  final Color listSurface;
  final Color listBorder;
  final Color listShadow;
  final Color scrollbarThumb;
  final Color scrollbarThumbHover;
  final Color coverInset;
  final Color coverShadow;
  final Color coverA;
  final Color coverB;

  static const day = _HeaderedPlaylistColors(
    pageSurface: Color(0xfff6f9fc),
    heroCover: Color(0xff5b87b6),
    textStrong: Color(0xff1f252b),
    textMuted: Color(0xff5f625f),
    listSurface: Color(0xc2ffffff),
    listBorder: Color(0x2e7e8b9a),
    listShadow: Color(0x14685870),
    scrollbarThumb: Color(0x705b697a),
    scrollbarThumbHover: Color(0xa6435060),
    coverInset: Color(0x9effffff),
    coverShadow: Color(0x38364456),
    coverA: Color(0xff6794c6),
    coverB: Color(0xff6f7fc8),
  );

  static const night = _HeaderedPlaylistColors(
    pageSurface: Color(0xff0f1318),
    heroCover: Color(0xff5b87b6),
    textStrong: Color(0xf0f6f9fc),
    textMuted: Color(0xadcbd5e1),
    listSurface: Color(0xc7171c22),
    listBorder: Color(0x1fd6e0ec),
    listShadow: Color(0x3d000000),
    scrollbarThumb: Color(0x5cd0dbe8),
    scrollbarThumbHover: Color(0x94dee7f2),
    coverInset: Color(0x1affffff),
    coverShadow: Color(0x61000000),
    coverA: Color(0xff2d4f72),
    coverB: Color(0xff33406d),
  );

  static _HeaderedPlaylistColors resolve(bool nightMode) {
    return nightMode ? night : day;
  }
}
