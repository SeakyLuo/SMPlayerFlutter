part of 'music_library_page.dart';

extension _MusicLibraryActions on _MusicLibraryPageState {
  void _toggleSort(MusicLibrarySortCriterion criterion) {
    final criterionChanged = _sortCriterion != criterion;
    _updateLibraryState(() {
      if (!criterionChanged) {
        _sortDirection =
            _sortDirection == MusicLibrarySortDirection.ascending
                ? MusicLibrarySortDirection.descending
                : MusicLibrarySortDirection.ascending;
      } else {
        _sortCriterion = criterion;
        _sortDirection = MusicLibrarySortDirection.ascending;
      }
    });
    if (criterionChanged) {
      unawaited(
        ref.read(libraryRepositoryProvider).updateMusicLibrarySort(criterion),
      );
    }
  }

  void _resizeColumn(_LibraryColumn column, double deltaX) {
    _updateLibraryState(() {
      _columnWidths[column] = max(
        _minColumnWidth,
        _columnWidths[column]! + deltaX,
      );
    });
  }

  void _handleScroll() {
    final nextOffset = _scrollController.offset;
    final rowHeight =
        _compactLayout ? _compactVirtualRowHeight : _wideVirtualRowHeight;
    final rowChanged =
        (_scrollOffset / rowHeight).floor() != (nextOffset / rowHeight).floor();
    if (rowChanged) {
      _updateLibraryState(() {
        _scrollOffset = nextOffset;
      });
    } else {
      _scrollOffset = nextOffset;
    }
  }

  bool _handleUserScroll(UserScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical &&
        notification.direction != ScrollDirection.idle &&
        _quickJumpPinnedKey != null) {
      _updateLibraryState(() {
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

    _updateLibraryState(() {
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
    _updateLibraryState(() {
      _selection.toggle(songId);
    });
  }

  FutureOr<void> _openSongContextMenu(
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
      _updateLibraryState(() {
        _selection.selectAll(selectedVisibleSongIds);
      });
      _showSongSelectionContextMenu(
        position,
        selectedVisibleSongs,
        customPlaylists,
      );
      return Future<void>.value();
    }

    return _showSongContextMenu(
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
    final libraryPlaylists = _effectiveLibraryPlaylists(snapshot.playlists);
    final mediaState = ref.read(mediaControlControllerProvider).state;
    final currentTrackId = mediaState.track.id;
    final preferenceLevel = await ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('song', '${song.id}');
    if (!mounted) {
      return;
    }
    await showMenuFlyout(
      context,
      position: position,
      items: buildMusicMenuFlyoutItems(
        i18n: i18n,
        songId: song.id,
        songTitle: song.title,
        isFavorite: song.favorite,
        isCurrentTrack: song.id == currentTrackId,
        isPlaying: mediaState.isPlaying,
        currentTrackId: currentTrackId,
        nowPlayingSongIds: snapshot.nowPlaying.songIds,
        songPath: song.path,
        playlists: playlists,
        onPlay: () {
          _selection.selectSingle(song.id);
          _playSongIds([song.id]);
        },
        onTogglePlayPause:
            ref.read(mediaControlControllerProvider).onTogglePlayPause,
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
            playlists: libraryPlaylists,
            defaultName: getNextPlaylistName(song.title, libraryPlaylists),
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
          _updateLibraryState(() {
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
        showSelect: true,
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
        onLocateLocal: () => locateSongInLocal(context, song.id),
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
    _updateLibraryState(() {
      _musicDialog = (song: song, mode: mode, queueSongIds: queueSongIds);
    });
  }

  void _showSongSelectionContextMenu(
    Offset position,
    List<LibrarySong> selectedSongs,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) {
    final i18n = ref.read(smPlayerI18nProvider).valueOrNull!;
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final libraryPlaylists = _effectiveLibraryPlaylists(snapshot.playlists);
    final selectedSongIds = selectedSongs.map((song) => song.id).toList();
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: selectedSongIds,
      playlists: playlists,
      includeNowPlaying: shouldShowNowPlayingAddToTarget(
        songIds: selectedSongIds,
        nowPlayingSongIds: snapshot.nowPlaying.songIds,
        isNowPlayingContext: false,
      ),
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
                setSongsFavoriteFromControl(
                  ref,
                  notFavoriteSongIds(selectedSongIds, songsById),
                  true,
                );
              }
              : null,
      onCreatePlaylist: () async {
        await createPlaylistWithSongs(
          context: context,
          ref: ref,
          i18n: i18n,
          playlists: libraryPlaylists,
          defaultName: getNextPlaylistName(
            i18n.t('common.songs'),
            libraryPlaylists,
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
    final libraryPlaylists = _effectiveLibraryPlaylists(snapshot.playlists);
    final item = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: [song.id],
      playlists: playlists,
      includeNowPlaying: shouldShowNowPlayingAddToTarget(
        songIds: [song.id],
        nowPlayingSongIds: snapshot.nowPlaying.songIds,
        isNowPlayingContext: false,
      ),
      includeFavorites: !song.favorite,
      defaultPlaylistName: getNextPlaylistName(song.title, libraryPlaylists),
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
          playlists: libraryPlaylists,
          defaultName: getNextPlaylistName(song.title, libraryPlaylists),
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
    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: snapshot,
      i18n: context.smPlayerI18n,
      songIds: queueSongIds,
      queueIndex: 0,
    );
  }

  void _playTrackInQueue(int trackId, List<int> queueSongIds) {
    final snapshot = ref.read(libraryContentDataProvider).value!;
    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: snapshot,
      i18n: context.smPlayerI18n,
      songIds: queueSongIds,
      queueIndex: queueSongIds.indexOf(trackId),
    );
  }

  void _playNext(int songId) {
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final previousSongIds = currentNowPlayingSongIds(ref, snapshot);
    final queueSongIds = previousSongIds.toList();
    final insertIndex = insertIndexAfterCurrentOccurrence(
      ref.read(mediaControlControllerProvider).state,
      queueSongIds,
    );
    queueSongIds.insert(insertIndex, songId);
    setNowPlayingQueue(ref, queueSongIds);
    final songsById = {for (final song in snapshot.songs) song.id: song};
    showPlayNextUndoNotification(
      context: context,
      i18n: context.smPlayerI18n,
      songTitle: songsById[songId]!.title,
      onUndo: () {
        setNowPlayingQueue(ref, previousSongIds);
      },
    );
  }

  void _addNextAndPlay(int songId) {
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final mediaState = ref.read(mediaControlControllerProvider).state;
    final queueSongIds = currentNowPlayingSongIds(ref, snapshot);
    var queueIndex = queueSongIds.indexOf(songId);
    if (queueIndex == -1) {
      final currentIndex = currentQueueIndexForPlaybackOccurrence(
        mediaState,
        queueSongIds,
      );
      queueIndex = currentIndex == -1 ? queueSongIds.length : currentIndex + 1;
      queueSongIds.insert(queueIndex, songId);
    }

    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: snapshot,
      i18n: context.smPlayerI18n,
      songIds: queueSongIds,
      queueIndex: queueIndex,
      showQueueUpdatedNotification: false,
    );
  }

  List<LibraryPlaylist> _effectiveLibraryPlaylists(
    List<LibraryPlaylist> playlists,
  ) {
    return applyLibraryPlaylistOverridesToPlaylists(
      playlists,
      ref.read(libraryPlaylistOverridesProvider),
      ref.read(libraryDeletedPlaylistIdsProvider),
      ref.read(libraryPlaylistOrderProvider),
    );
  }

  void _jumpToKey(Map<String, int> quickJumpMap, String key, bool compact) {
    final index = quickJumpMap[key];
    if (index == null) {
      return;
    }

    _updateLibraryState(() {
      _quickJumpPinnedKey = key;
    });
    _scrollController.jumpTo(
      index * (compact ? _compactVirtualRowHeight : _wideVirtualRowHeight),
    );
  }
}
