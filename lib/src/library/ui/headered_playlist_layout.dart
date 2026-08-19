part of 'headered_playlist_control.dart';

extension _HeaderedPlaylistControlLayout on _HeaderedPlaylistControlState {
  Widget _buildBody(BuildContext context) {
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
    final windowDragCallbacks = ref.watch(smPlayerWindowDragProvider);
    final hideMultiSelectCommandBarAfterOperation =
        ref.watch(
          libraryContentDataProvider.select(
            (value) =>
                value.valueOrNull?.hideMultiSelectCommandBarAfterOperation,
          ),
        ) ??
        true;
    final playlists = _effectivePlaylists(widget.playlists);
    final customPlaylists =
        playlists
            .where((playlist) => !playlist.isBuiltIn)
            .map(
              (playlist) => MultiSelectCommandBarPlaylist(
                id: playlist.id,
                name: playlist.name,
                songIds: playlist.songIds,
              ),
            )
            .toList();
    final nowPlayingSongIds =
        ref.read(nowPlayingQueueOverrideProvider) ??
        ref.read(libraryContentDataProvider).valueOrNull!.nowPlaying.songIds;
    final currentSavedPlaylist =
        widget.type == HeaderedPlaylistType.playlist
            ? playlists.firstWhere((playlist) => playlist.name == widget.title)
            : null;
    final currentPlaylistName =
        widget.type == HeaderedPlaylistType.favorites
            ? i18n.t('common.myFavorites')
            : widget.type == HeaderedPlaylistType.playlist
            ? currentSavedPlaylist!.name
            : widget.title;

    final colors = HeaderedPlaylistThemeColors.of(context);
    _syncAppBarPortal(
      compact: compact,
      visibleSongs: visibleSongs,
      queueSongIds: queueSongIds,
      activeSortCriterion: activeSortCriterion,
      i18n: i18n,
      coverColor: _headerCoverColor,
      collapseProgress: collapseProgress,
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
                      info: getHeaderPlaylistInfo(headerSongs, i18n),
                      artworkUrls: headerArtworkUrls,
                      coverColor: _headerCoverColor,
                      collapseProgress: 0,
                      windowDragCallbacks: windowDragCallbacks,
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
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _HeaderHeroSliverDelegate(
                      type: widget.type,
                      title: widget.title,
                      info: getHeaderPlaylistInfo(headerSongs, i18n),
                      artworkUrls: headerArtworkUrls,
                      coverColor: _headerCoverColor,
                      windowDragCallbacks: windowDragCallbacks,
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
                _HeaderedPlaylistListSliver(
                  showAlbum: widget.showAlbum,
                  bottomPadding:
                      _selection.multiSelect
                          ? multiSelectCommandBarScrollSpacer
                          : 56,
                  entries: [
                    for (var index = 0; index < visibleSongs.length; index += 1)
                      _playlistControlEntryFor(
                        context: context,
                        i18n: i18n,
                        song: visibleSongs[index],
                        queueSongIds: queueSongIds,
                        nowPlayingSongIds: nowPlayingSongIds,
                        index: index,
                        customPlaylists: customPlaylists,
                        currentPlaylistName: currentPlaylistName,
                        currentSavedPlaylist: currentSavedPlaylist,
                      ),
                  ],
                ),
              ],
            ),
          ),
          _HeaderedPlaylistScrollbar(
            controller: _scrollController,
            collapseProgress: collapseProgress,
            bottomOffset: ref.watch(headeredPlaylistScrollbarBottomProvider),
          ),
          MultiSelectCommandBar(
            visible: _selection.multiSelect,
            bottomInset: multiSelectCommandBarShellBottomInset,
            selectedCount: _effectiveSelectedSongIds(queueSongIds).length,
            playlists: customPlaylists,
            addToSongIds: _effectiveSelectedSongIds(queueSongIds),
            nowPlayingSongIds: nowPlayingSongIds,
            includeNowPlayingInAddTo: true,
            includeFavoritesInAddTo:
                widget.type != HeaderedPlaylistType.favorites,
            currentPlaylistName: currentPlaylistName,
            excludePlaylistName: currentSavedPlaylist?.name,
            onAddToNowPlaying: () {
              _addSongsToNowPlaying(_effectiveSelectedSongIds(queueSongIds));
              _hideSelectionAfterOperation(
                hideMultiSelectCommandBarAfterOperation,
              );
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
                      _hideSelectionAfterOperation(
                        hideMultiSelectCommandBarAfterOperation,
                      );
                    },
            onCreatePlaylist: () {
              unawaited(
                _createPlaylistFromSongs(
                  i18n,
                  _effectiveSelectedSongIds(queueSongIds),
                ),
              );
              _hideSelectionAfterOperation(
                hideMultiSelectCommandBarAfterOperation,
              );
            },
            removeLabel:
                widget.type == HeaderedPlaylistType.favorites
                    ? i18n.t('context.removeFavorite')
                    : i18n.t('playlists.removeSelected'),
            onPlay: () {
              final selectedSongIds = _effectiveSelectedSongIds(queueSongIds);
              widget.onPlayTrack(selectedSongIds.first, selectedSongIds);
              _hideSelectionAfterOperation(
                hideMultiSelectCommandBarAfterOperation,
              );
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
              _hideSelectionAfterOperation(
                hideMultiSelectCommandBarAfterOperation,
              );
            },
            onRemove:
                widget.removable
                    ? () {
                      final selectedSongIds = _effectiveSelectedSongIds(
                        queueSongIds,
                      );
                      unawaited(
                        _removeSongsFromCurrentPlaylist(selectedSongIds),
                      );
                      _updateState(() {
                        _selection.clearSelection();
                      });
                    }
                    : null,
            onSelectAll: () {
              _updateState(() {
                _selection.selectAll(queueSongIds);
              });
            },
            onReverseSelection: () {
              _updateState(() {
                _selection.reverseSelection(queueSongIds);
              });
            },
            onClearSelection: () {
              _updateState(() {
                _selection.clearSelection();
              });
            },
            onCancel: () {
              _updateState(() {
                _selection.cancel();
              });
            },
          ),
          if (_musicDialog case final dialog?)
            MusicDialog(
              song: dialog.song,
              initialMode: dialog.mode,
              currentTrackId: widget.selectedTrackId,
              isPlaying: widget.isPlaying,
              queueSongIds: dialog.queueSongIds,
              onPlay: widget.onTogglePlayPause,
              onPlayTrack: widget.onPlayTrack,
              onReveal: _revealPath,
              onSaved: () {
                notifyLyricsSaved(ref, dialog.song.id);
              },
              onClose: () {
                _updateState(() {
                  _musicDialog = null;
                });
              },
            ),
        ],
      ),
    );
  }

  PlaylistControlEntry _playlistControlEntryFor({
    required BuildContext context,
    required SmPlayerI18n i18n,
    required LibrarySong song,
    required List<int> queueSongIds,
    required List<int> nowPlayingSongIds,
    required int index,
    required List<MultiSelectCommandBarPlaylist> customPlaylists,
    required String currentPlaylistName,
    required LibraryPlaylist? currentSavedPlaylist,
  }) {
    final current = song.id == widget.selectedTrackId;
    return PlaylistControlEntry(
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
      favoriteAsHoverAction: widget.type == HeaderedPlaylistType.favorites,
      favoriteLoading:
          widget.type == HeaderedPlaylistType.favorites &&
          _pendingFavoriteSongIds.contains(song.id),
      onActivateRow: () {
        widget.onPlayTrack(song.id, queueSongIds);
      },
      onPlayTrack: () {
        _playSong(song, queueSongIds);
      },
      onTogglePlayPause:
          widget.onTogglePlayPause ??
          () {
            _playSong(song, queueSongIds);
          },
      onToggleSelection: () {
        _updateState(() {
          _selection.toggle(song.id);
        });
      },
      onToggleFavoriteClick:
          widget.onToggleFavorite == null
              ? null
              : () {
                _toggleSongFavoriteWithUndo(song);
              },
      onAddToPlaylistClick: (buttonContext) {
        final item = buildAddToPlaylistMenuFlyoutItem(
          i18n: i18n,
          songIds: [song.id],
          playlists: customPlaylists,
          currentPlaylistName: currentPlaylistName,
          excludePlaylistName: currentSavedPlaylist?.name,
          includeNowPlaying: shouldShowNowPlayingAddToTarget(
            songIds: [song.id],
            nowPlayingSongIds: nowPlayingSongIds,
            isNowPlayingContext:
                currentPlaylistName == i18n.t('common.nowPlaying'),
          ),
          includeFavorites: widget.type != HeaderedPlaylistType.favorites,
          onAddToNowPlaying: () {
            _addSongsToNowPlaying([song.id]);
          },
          onToggleFavorite:
              widget.onToggleFavorite == null
                  ? null
                  : () {
                    unawaited(
                      setSongsFavoriteWithUndo(
                        context: context,
                        ref: ref,
                        i18n: i18n,
                        songIds: [song.id],
                        favorite: true,
                      ),
                    );
                  },
          onCreatePlaylist: () {
            unawaited(_createPlaylistFromSongs(i18n, [song.id]));
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
                unawaited(_removeSongsFromCurrentPlaylist([song.id]));
              }
              : null,
      onPlayNextClick: () {
        _playNextSong(song.id);
      },
      onOpenContextMenu: (position) {
        unawaited(
          _showSongMenu(context, i18n, position, song, index, queueSongIds),
        );
      },
      onSeeArtist: widget.onArtistClick,
      onSeeAlbum:
          widget.onAlbumClick == null
              ? null
              : () {
                widget.onAlbumClick!(song_display.displayAlbum(song, i18n));
              },
    );
  }
}
