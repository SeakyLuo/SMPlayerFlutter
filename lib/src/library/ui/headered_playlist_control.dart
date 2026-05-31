import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/app/window_drag_provider.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_app_bar_portal.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_model.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_shell_metrics.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/library/ui/playlist_artwork.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart'
    as song_display;
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';

part 'headered_playlist_actions.dart';
part 'headered_playlist_artwork.dart';
part 'headered_playlist_command_bar.dart';
part 'headered_playlist_cover.dart';
part 'headered_playlist_hero.dart';
part 'headered_playlist_layout.dart';
part 'headered_playlist_list.dart';
part 'headered_playlist_portal.dart';
part 'headered_playlist_song_menu.dart';
part 'headered_playlist_theme.dart';

enum HeaderedPlaylistType { album, playlist, favorites }

const _compactHeaderTopInset =
    SmPlayerShellMetrics.minimalTitlebarHeight + 40.0;

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
    this.routeLocation,
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
  final String? routeLocation;
  final HeaderedPlaylistTrackHandler onPlayTrack;
  final VoidCallback? onTogglePlayPause;
  final void Function(int playlistId, int songId) onAddSongToPlaylist;
  final void Function(int playlistId, List<int> songIds)? onAddSongsToPlaylist;
  final HeaderedPlaylistSongsHandler? onRemoveSongs;
  final ValueChanged<String>? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onClear;
  final VoidCallback? onEditArtwork;
  final FutureOr<void> Function(String level)? onSetPreferred;
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
  late final VoidCallback _clearAppBarPortalOwner;

  @override
  void initState() {
    super.initState();
    _selection = PageSelectionController<int>.stored(
      _selectionStorageKeyFor(widget),
    );
    final appBarPortalNotifier = ref.read(
      headeredPlaylistAppBarPortalProvider.notifier,
    );
    _clearAppBarPortalOwner = () {
      clearHeaderedPlaylistAppBarPortalOwnerAfterDispose(
        appBarPortalNotifier,
        _appBarPortalOwner,
      );
    };
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

  @override
  Widget build(BuildContext context) {
    return _buildBody(context);
  }

  @override
  void reassemble() {
    super.reassemble();
    _playlistArtworkSignature = '';
    _refreshPlaylistArtwork();
  }

  void _updateState(VoidCallback fn) {
    setState(fn);
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
    _updateState(() {
      _scrollTop = nextScrollTop;
      _headerCollapsed = nextHeaderCollapsed;
    });
  }
}
