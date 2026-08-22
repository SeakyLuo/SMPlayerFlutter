part of 'artists_page.dart';

double _artistsPageWorkspaceWidth(BuildContext context) {
  final windowWidth = MediaQuery.sizeOf(context).width;
  final navigationMode = SmPlayerShellMetrics.navigationModeForWidth(
    windowWidth,
  );
  return navigationMode == SmPlayerNavigationMode.minimal
      ? windowWidth
      : windowWidth - SmPlayerShellMetrics.collapsedSidebarWidth;
}

bool _isArtistsPageCompactWorkspace(BuildContext context) {
  return _artistsPageWorkspaceWidth(context) <= 720;
}

void _listenForArtistsListRequests(_ArtistsPageState state) {
  state.ref.listen(artistsListRequestProvider, (_, _) {
    if (state._selectedArtistName.isEmpty) {
      return;
    }
    // ignore: invalid_use_of_protected_member
    state.setState(() {
      state._selectedArtistName = '';
      state._selection.cancel();
    });
  });
}

void _clearArtistsAppBarPortalOwner(_ArtistsPageState state) {
  clearWorkspaceAppBarPortalOwnerAfterDispose(
    state._appBarPortalNotifier,
    state._appBarPortalOwner,
  );
}

void _syncArtistsAppBarPortal(
  _ArtistsPageState state, {
  required bool showPortal,
  required String routePath,
  required Widget content,
  required String compactTitle,
  String? titleTooltip,
  required String layoutSignature,
  required int searchSuggestionCount,
  required int searchHistoryCount,
  Widget? bottomContent,
}) {
  final signature =
      '$showPortal:$routePath:$layoutSignature:${state._appBarSearchOpen}:${state._artistSearch}:${state._artistSearchFocused}:${state._artistSortCriterion}:${state._reverseArtistDisplayOrder}:$compactTitle:$titleTooltip:$searchSuggestionCount:$searchHistoryCount:${bottomContent != null}';
  if (state._appBarPortalSignature == signature) {
    return;
  }
  state._appBarPortalSignature = signature;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!state.mounted) {
      return;
    }
    final notifier = state.ref.read(workspaceAppBarPortalProvider.notifier);
    if (!showPortal) {
      if (notifier.state?.owner == state._appBarPortalOwner) {
        notifier.state = null;
      }
      return;
    }
    notifier.state = WorkspaceAppBarPortalEntry(
      owner: state._appBarPortalOwner,
      routePath: routePath,
      content: content,
      title: compactTitle.isEmpty ? null : compactTitle,
      titleTooltip: titleTooltip,
      bottomContent: bottomContent,
      replacesTitle: state._appBarSearchOpen,
    );
  });
}

void _recordLoadingArtistSearchForArtistsPage(_ArtistsPageState state) {
  final query = state._artistSearch.trim();
  if (query.isEmpty) {
    return;
  }

  final recentSearches = state.ref.read(recentSearchesProvider.notifier);
  unawaited(
    state.ref
        .read(libraryRepositoryProvider)
        .addRecentSearch(query, SearchHistoryType.artists)
        .then((entry) {
          if (entry != null) {
            return recentSearches.record(entry);
          }
        }),
  );
}

void _changeArtistSearchFocusForArtistsPage(
  _ArtistsPageState state,
  bool focused,
) {
  // ignore: invalid_use_of_protected_member
  state.setState(() {
    state._artistSearchFocused = focused;
  });
}

void _removeArtistRecentSearchForArtistsPage(
  _ArtistsPageState state,
  int entryId,
) {
  final recentSearches = state.ref.read(recentSearchesProvider.notifier);
  unawaited(
    state.ref
        .read(libraryRepositoryProvider)
        .removeRecentSearches([entryId])
        .then((_) {
          return recentSearches.remove([entryId]);
        }),
  );
}

void _clearArtistRecentSearchesForArtistsPage(_ArtistsPageState state) {
  final entryIds =
      state.ref
          .read(recentSearchesProvider)
          .value!
          .where((entry) => entry.type == SearchHistoryType.artists)
          .map((entry) => entry.id)
          .toList();
  final recentSearches = state.ref.read(recentSearchesProvider.notifier);
  unawaited(
    state.ref
        .read(libraryRepositoryProvider)
        .removeRecentSearches(entryIds)
        .then((_) {
          return recentSearches.remove(entryIds);
        }),
  );
}

void _openArtistDetailForArtistsPage(
  _ArtistsPageState state,
  String artistName,
) {
  // ignore: invalid_use_of_protected_member
  state.setState(() {
    state._selectedArtistName = artistName;
    state._selection.cancel();
  });
  state._recordBrowseAfterFrame(artistName);
  if (_isArtistsPageCompactWorkspace(state.context)) {
    state._pendingOpenedArtistRoute = artistName;
    state.context.go('/artists?artist=${Uri.encodeQueryComponent(artistName)}');
  }
  if (state._artistDetailController.hasClients) {
    state._artistDetailController.jumpTo(0);
  }
}

void _jumpToArtistKeyForArtistsPage(
  _ArtistsPageState state,
  Map<String, int> artistQuickJumpMap,
  String key,
) {
  final targetIndex = artistQuickJumpMap[key];
  if (targetIndex == null) {
    return;
  }

  // ignore: invalid_use_of_protected_member
  state.setState(() {
    state._artistQuickJumpPinnedKey = key;
    state._artistQuickJumpJumping = true;
  });
  state._artistListController.jumpTo(targetIndex * artistRowHeight);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (state.mounted) {
      // ignore: invalid_use_of_protected_member
      state.setState(() {
        state._artistQuickJumpJumping = false;
      });
    }
  });
}

void _scrollToArtistForArtistsPage(_ArtistsPageState state, String artistName) {
  final snapshot = state.ref.read(libraryContentDataProvider).value!;
  final i18n = state.ref.read(smPlayerI18nProvider).valueOrNull!;
  final artistGroups = state._readArtistGroups(snapshot, i18n);
  final artistIndex = artistGroups.indexWhere(
    (artist) => artist.name == artistName,
  );
  if (artistIndex < 0 || !state._artistListController.hasClients) {
    return;
  }

  state._artistListController.animateTo(
    artistIndex * artistRowHeight,
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
  );
}

void _locateArtistForArtistsPage(_ArtistsPageState state, String artistName) {
  void triggerHighlight() {
    // ignore: invalid_use_of_protected_member
    state.setState(() {
      state._locatedArtistName = artistName;
      state._locateArtistPulse += 1;
    });
  }

  final currentUri = GoRouterState.of(state.context).uri;
  final shouldOpenArtistList =
      currentUri.path != '/artists' ||
      currentUri.queryParameters.containsKey('artist');
  if (!shouldOpenArtistList) {
    triggerHighlight();
    state._scrollToArtist(artistName);
    return;
  }

  // ignore: invalid_use_of_protected_member
  state.setState(() {
    state._selectedArtistName = '';
    state._selection.cancel();
  });
  state.context.go('/artists');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (state.mounted) {
      triggerHighlight();
      state._scrollToArtist(artistName);
    }
  });
}

void _handleArtistListScrollForArtistsPage(_ArtistsPageState state) {
  if (state._artistListController.positions.length != 1) {
    return;
  }
  final nextScrollTop = state._artistListController.offset;
  if (nextScrollTop == state._artistScrollTop) {
    return;
  }

  // ignore: invalid_use_of_protected_member
  state.setState(() {
    state._artistScrollTop = nextScrollTop;
    if (!state._artistQuickJumpJumping) {
      state._artistQuickJumpPinnedKey = null;
    }
  });
}

String _getActiveArtistQuickJumpKeyForArtistsPage(
  _ArtistsPageState state,
  List<ArtistGroup> visibleArtists,
  ArtistSortCriterion sortCriterion,
) {
  if (visibleArtists.isEmpty) {
    return '';
  }
  if (state._artistQuickJumpPinnedKey case final key?) {
    return key;
  }

  final activeIndex = min(
    visibleArtists.length - 1,
    max(0, (state._artistScrollTop / artistRowHeight).floor()),
  );
  return getArtistQuickJumpBucketForSort(
    visibleArtists[activeIndex],
    sortCriterion,
  );
}

void _playSongIdsForArtistsPage(_ArtistsPageState state, List<int> songIds) {
  if (songIds.isEmpty) {
    return;
  }

  replaceNowPlayingQueueAndPlayIndex(
    ref: state.ref,
    snapshot: state.ref.read(libraryContentDataProvider).value!,
    i18n: state.context.smPlayerI18n,
    songIds: songIds,
    queueIndex: 0,
  );
}

void _playTrackInQueueForArtistsPage(
  _ArtistsPageState state,
  int songId,
  List<int> queueSongIds,
) {
  final snapshot = state.ref.read(libraryContentDataProvider).value!;
  final mediaState = state.ref.read(mediaControlControllerProvider).state;
  final currentSongIds = currentNowPlayingSongIds(state.ref, snapshot);
  final queueChanged =
      !_sameSongIdsForArtistsPage(queueSongIds, currentSongIds);
  final resolvedQueueSongIds =
      queueChanged && mediaState.mode == PlaybackMode.shuffle
          ? shufflePlaybackQueueForCurrentTrack(queueSongIds, songId)
          : (queueChanged ? queueSongIds.toList() : currentSongIds.toList());
  final queueIndex = resolvedQueueSongIds.indexOf(songId);
  replaceNowPlayingQueueAndPlayIndex(
    ref: state.ref,
    snapshot: snapshot,
    i18n: state.context.smPlayerI18n,
    songIds: resolvedQueueSongIds,
    queueIndex: queueIndex,
  );
}

bool _sameSongIdsForArtistsPage(List<int> left, List<int> right) {
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

void _playNextForArtistsPage(_ArtistsPageState state, int songId) {
  final snapshot = state.ref.read(libraryContentDataProvider).value!;
  final previousSongIds = currentNowPlayingSongIds(state.ref, snapshot);
  final activeIndex = currentQueueIndexForPlaybackOccurrence(
    state.ref.read(mediaControlControllerProvider).state,
    previousSongIds,
  );
  final nextSongIds = previousSongIds.toList()..insert(activeIndex + 1, songId);
  setNowPlayingQueue(state.ref, nextSongIds);
  final songsById = {for (final song in snapshot.songs) song.id: song};
  showPlayNextUndoNotification(
    context: state.context,
    i18n: state.context.smPlayerI18n,
    songTitle: songsById[songId]!.title,
    onUndo: () {
      setNowPlayingQueue(state.ref, previousSongIds);
    },
  );
}

void _moveToMusicOrPlayForArtistsPage(_ArtistsPageState state, int songId) {
  final snapshot = state.ref.read(libraryContentDataProvider).value!;
  insertOrPlayNowPlayingSong(
    ref: state.ref,
    snapshot: snapshot,
    i18n: state.context.smPlayerI18n,
    songId: songId,
  );
}

void _playShuffledSongIdsForArtistsPage(
  _ArtistsPageState state,
  List<int> songIds, {
  String? artistName,
  String? albumName,
}) {
  if (artistName != null) {
    state.ref.read(libraryRepositoryProvider).recordArtistPlayed(artistName);
  }
  if (albumName != null) {
    state.ref.read(libraryRepositoryProvider).recordAlbumPlayed(albumName);
  }
  final queueSongIds = songIds.toList()..shuffle(Random());
  state._playSongIds(queueSongIds);
}

Future<void> _showGroupContextMenuForArtistsPage(
  _ArtistsPageState state, {
  required Offset position,
  required _ArtistGroupMenuType type,
  required String label,
  required List<LibrarySong> songs,
  bool showLocateArtist = false,
}) async {
  final i18n = state.context.smPlayerI18n;
  final preferenceType =
      type == _ArtistGroupMenuType.artist ? 'artist' : 'album';
  final preferenceLevel = await state.ref
      .read(libraryRepositoryProvider)
      .getPreferenceLevel(preferenceType, label);
  if (!state.mounted) {
    return;
  }
  final snapshot = state.ref.read(libraryContentDataProvider).value!;
  final songIds = songs.map((song) => song.id).toList();
  final customLibraryPlaylists =
      snapshot.playlists.where((playlist) => !playlist.isBuiltIn).toList();
  final customPlaylists =
      customLibraryPlaylists
          .map(
            (playlist) => MultiSelectCommandBarPlaylist(
              id: playlist.id,
              name: playlist.name,
              songIds: playlist.songIds,
            ),
          )
          .toList();
  final notFavoriteIds =
      songs.where((song) => !song.favorite).map((song) => song.id).toList();
  final addToItem = buildAddToPlaylistMenuFlyoutItem(
    i18n: i18n,
    songIds: songIds,
    playlists: customPlaylists,
    includeNowPlaying: shouldShowNowPlayingAddToTarget(
      songIds: songIds,
      nowPlayingSongIds: snapshot.nowPlaying.songIds,
      isNowPlayingContext: false,
    ),
    includeFavorites: notFavoriteIds.isNotEmpty,
    onAddToNowPlaying: () {
      addSongsToNowPlayingWithUndo(
        context: state.context,
        ref: state.ref,
        i18n: i18n,
        songIds: songIds,
      );
    },
    onToggleFavorite:
        notFavoriteIds.isEmpty
            ? null
            : () {
              setSongsFavoriteWithUndo(
                context: state.context,
                ref: state.ref,
                i18n: i18n,
                songIds: notFavoriteIds,
                favorite: true,
              );
            },
    onCreatePlaylist: () async {
      await createPlaylistWithSongs(
        context: state.context,
        ref: state.ref,
        i18n: i18n,
        playlists: customLibraryPlaylists,
        defaultName: label,
        songIds: songIds,
      );
    },
    onAddToPlaylist: (playlistId) {
      addSongsToPlaylistWithUndo(
        context: state.context,
        ref: state.ref,
        i18n: i18n,
        playlistId: playlistId,
        songIds: songIds,
      );
    },
  );

  showMenuFlyout(
    state.context,
    position: position,
    items: [
      MenuFlyoutItem(
        key: 'shuffle',
        text: i18n.t('nowPlaying.randomPlay'),
        useShuffleIcon: true,
        onPressed: () {
          state._playShuffledSongIds(
            songIds,
            artistName: type == _ArtistGroupMenuType.artist ? label : null,
            albumName: type == _ArtistGroupMenuType.album ? label : null,
          );
        },
      ),
      if (addToItem != null) addToItem,
      MenuFlyoutItem(
        key: type == _ArtistGroupMenuType.artist ? 'multi-select' : 'select',
        text:
            type == _ArtistGroupMenuType.artist
                ? i18n.t('common.multiSelect')
                : i18n.t('context.select'),
        icon: FluentIcons.multiselect_ltr_20_regular,
        onPressed: () {
          // ignore: invalid_use_of_protected_member
          state.setState(() {
            if (type == _ArtistGroupMenuType.artist) {
              state._selection.enterMultiSelect();
              state._selection.clearSelection();
            } else {
              state._selection.selectAll(songIds);
            }
          });
        },
      ),
      state._buildGroupPreferenceMenuItem(i18n, type, label, preferenceLevel),
      if (type == _ArtistGroupMenuType.artist && showLocateArtist)
        MenuFlyoutItem(
          key: 'locate-artist',
          text: i18n.t('artists.locateArtist'),
          icon: FluentIcons.apps_list_detail_20_regular,
          onPressed: () {
            state._locateArtist(label);
          },
        ),
      if (type == _ArtistGroupMenuType.album)
        MenuFlyoutItem(
          key: 'see-album',
          text: i18n.t('context.seeAlbum'),
          useAlbumIcon: true,
          onPressed: () {
            state.context.go(
              '/albums?album=${Uri.encodeQueryComponent(label)}',
            );
          },
        ),
    ],
  );
}

MenuFlyoutItem _buildGroupPreferenceMenuItemForArtistsPage(
  _ArtistsPageState state,
  SmPlayerI18n i18n,
  _ArtistGroupMenuType type,
  String label,
  String? preferenceLevel,
) {
  final preferenceType =
      type == _ArtistGroupMenuType.artist ? 'artist' : 'album';
  return buildPreferenceMenuFlyoutItem(
    i18n: i18n,
    key: 'preference',
    preferenceLevel: preferenceLevel,
    onUndoPreference:
        preferenceLevel == null
            ? null
            : () async {
              await state.ref
                  .read(libraryRepositoryProvider)
                  .removePreferenceItem(preferenceType, label);
            },
    onSetPreference: (level) async {
      await state.ref
          .read(libraryRepositoryProvider)
          .addPreferenceItem(preferenceType, label, label, level);
    },
  );
}

Future<void> _showSongContextMenuForArtistsPage(
  _ArtistsPageState state,
  Offset position,
  LibrarySong song,
  List<int> queueSongIds,
  List<MultiSelectCommandBarPlaylist> playlists,
) async {
  final i18n = state.context.smPlayerI18n;
  final snapshot = state.ref.read(libraryContentDataProvider).value!;
  final mediaState = state.ref.read(mediaControlControllerProvider).state;
  final currentTrackId = mediaState.track.id;
  final preferenceLevel = await state.ref
      .read(libraryRepositoryProvider)
      .getPreferenceLevel('song', '${song.id}');
  if (!state.mounted) {
    return;
  }
  showMenuFlyout(
    state.context,
    position: position,
    items: buildMusicMenuFlyoutItems(
      i18n: i18n,
      songId: song.id,
      isFavorite: song.favorite,
      isCurrentTrack: song.id == currentTrackId,
      isPlaying: mediaState.isPlaying,
      currentTrackId: currentTrackId,
      nowPlayingSongIds: snapshot.nowPlaying.songIds,
      songPath: song.path,
      playlists: playlists,
      preferenceLevel: preferenceLevel,
      onUndoPreference:
          preferenceLevel == null
              ? null
              : () async {
                await state.ref
                    .read(libraryRepositoryProvider)
                    .removePreferenceItem('song', '${song.id}');
              },
      onPlay: () {
        state._moveToMusicOrPlay(song.id);
      },
      onTogglePlayPause:
          state.ref.read(mediaControlControllerProvider).onTogglePlayPause,
      onPlayNext: () {
        state._playNext(song.id);
      },
      onAddToNowPlaying: () {
        addSongsToNowPlayingWithUndo(
          context: state.context,
          ref: state.ref,
          i18n: i18n,
          songIds: [song.id],
        );
      },
      onRequestCreatePlaylist: () {
        unawaited(_requestSongContextPlaylistForArtistsPage(state, i18n, song));
      },
      onCreatePlaylist: () async {
        await createPlaylistAndSync(
          context: state.context,
          ref: state.ref,
          i18n: i18n,
          name: song.title,
          songIds: [song.id],
        );
      },
      onAddToPlaylist: (playlistId) {
        addSongsToPlaylistWithUndo(
          context: state.context,
          ref: state.ref,
          i18n: i18n,
          playlistId: playlistId,
          songIds: [song.id],
        );
      },
      onRemove: () {},
      onSelect: () {
        // ignore: invalid_use_of_protected_member
        state.setState(() {
          state._selection.enterMultiSelect();
          state._selection.selectSingle(song.id);
        });
      },
      onToggleFavorite: () {
        setSongsFavoriteWithUndo(
          context: state.context,
          ref: state.ref,
          i18n: i18n,
          songIds: [song.id],
          favorite: true,
        );
      },
      onSetPreference: (level) async {
        await state.ref
            .read(libraryRepositoryProvider)
            .addPreferenceItem('song', '${song.id}', song.title, level);
      },
      onDelete: () {
        requestDeleteSongFromDisk(
          context: state.context,
          ref: state.ref,
          i18n: i18n,
          song: song,
        );
      },
      onSeeArtist: () {
        final artists = getSongArtists(song);
        final artist =
            artists.isEmpty ? i18n.t('common.artistUnknown') : artists.first;
        state.context.go('/artists?artist=${Uri.encodeQueryComponent(artist)}');
      },
      onSeeAlbum: () {
        state.context.go(
          '/albums?album=${Uri.encodeQueryComponent(displayAlbum(song, i18n))}',
        );
      },
      onSeeMusicInfo: () {
        state._openMusicDialog(song, SongDialogMode.properties, queueSongIds);
      },
      onSeeLyrics: () {
        state._openMusicDialog(song, SongDialogMode.lyrics, queueSongIds);
      },
      onSeeAlbumArt: () {
        state._openMusicDialog(song, SongDialogMode.albumArt, queueSongIds);
      },
      onSeeLocal: () {
        unawaited(revealItemInFolder(song.path));
      },
    ),
  );
}

Future<void> _requestSongContextPlaylistForArtistsPage(
  _ArtistsPageState state,
  SmPlayerI18n i18n,
  LibrarySong song,
) async {
  final context = state.context;
  await Future<void>.delayed(Duration.zero);
  if (!context.mounted) {
    return;
  }
  final name = await showSmPlayerInputDialog(
    context: context,
    i18n: i18n,
    title: i18n.t('playlists.newName'),
    defaultValue: song.title,
    placeholder: i18n.t('playlists.namePlaceholder'),
    confirmText: i18n.t('common.confirm'),
  );
  if (name == null || !context.mounted) {
    return;
  }
  await createPlaylistAndSync(
    context: context,
    ref: state.ref,
    i18n: i18n,
    name: name,
    songIds: [song.id],
  );
}

void _showSongAddToMenuForArtistsPage(
  _ArtistsPageState state,
  BuildContext buttonContext,
  LibrarySong song,
) {
  final snapshot = state.ref.read(libraryContentDataProvider).value!;
  final customLibraryPlaylists =
      snapshot.playlists.where((playlist) => !playlist.isBuiltIn).toList();
  final i18n = state.context.smPlayerI18n;
  final playlists =
      customLibraryPlaylists
          .map(
            (playlist) => MultiSelectCommandBarPlaylist(
              id: playlist.id,
              name: playlist.name,
              songIds: playlist.songIds,
            ),
          )
          .toList();
  final addToItem = buildAddToPlaylistMenuFlyoutItem(
    i18n: i18n,
    songIds: [song.id],
    playlists: playlists,
    includeNowPlaying: shouldShowNowPlayingAddToTarget(
      songIds: [song.id],
      nowPlayingSongIds: snapshot.nowPlaying.songIds,
      isNowPlayingContext: false,
    ),
    includeFavorites: !song.favorite,
    onAddToNowPlaying: () {
      addSongsToNowPlayingWithUndo(
        context: state.context,
        ref: state.ref,
        i18n: i18n,
        songIds: [song.id],
      );
    },
    onToggleFavorite:
        song.favorite
            ? null
            : () {
              setSongsFavoriteWithUndo(
                context: state.context,
                ref: state.ref,
                i18n: i18n,
                songIds: [song.id],
                favorite: true,
              );
            },
    onCreatePlaylist: () async {
      await createPlaylistWithSongs(
        context: state.context,
        ref: state.ref,
        i18n: i18n,
        playlists: customLibraryPlaylists,
        defaultName: song.title,
        songIds: [song.id],
      );
    },
    onAddToPlaylist: (playlistId) {
      addSongsToPlaylistWithUndo(
        context: state.context,
        ref: state.ref,
        i18n: i18n,
        playlistId: playlistId,
        songIds: [song.id],
      );
    },
  );
  if (addToItem == null) {
    return;
  }
  showMenuFlyout(buttonContext, items: addToItem.submenu);
}
