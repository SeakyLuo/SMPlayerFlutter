part of 'headered_playlist_control.dart';

extension _HeaderedPlaylistControlPortal on _HeaderedPlaylistControlState {
  void _syncAppBarPortal({
    required bool compact,
    required List<LibrarySong> visibleSongs,
    required List<int> queueSongIds,
    required PlaylistSortCriterion activeSortCriterion,
    required SmPlayerI18n i18n,
    required Color coverColor,
    required double collapseProgress,
  }) {
    final showPortal = compact;
    final playlistSignature = widget.playlists
        .map(
          (playlist) =>
              '${playlist.id}:${playlist.name}:${playlist.songIds.length}',
        )
        .join('|');
    final signature =
        '$showPortal:${widget.routeLocation}:${widget.title}:'
        '$activeSortCriterion:${_selection.multiSelect}:'
        '${queueSongIds.join(',')}:$playlistSignature:'
        '${widget.canRename}:${widget.canDelete}:${widget.canClear}:$coverColor:'
        '$_headerCollapsed:${collapseProgress.toStringAsFixed(3)}:'
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
      final portalTitle = _headerCollapsed ? widget.title : '';
      notifier.state = HeaderedPlaylistAppBarPortalEntry(
        owner: _appBarPortalOwner,
        routeLocation: widget.routeLocation,
        title: portalTitle,
        coverColor: coverColor,
        collapseProgress: collapseProgress,
        commandBarBuilder:
            _headerCollapsed
                ? (_) {
                  return _buildShyCommandBar(
                    context,
                    i18n,
                    visibleSongs,
                    queueSongIds,
                    activeSortCriterion,
                  );
                }
                : null,
      );
    });
  }

  void _clearAppBarPortal() {
    _clearAppBarPortalOwner();
  }
}
