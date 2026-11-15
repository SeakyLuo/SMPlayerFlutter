part of 'search_page.dart';

extension _SearchPageContent on _SearchPageState {
  Widget _buildSearchPage(BuildContext context) {
    if (!TickerMode.valuesOf(context).enabled) return const SizedBox.shrink();
    if (widget.query.trim().isEmpty) {
      final i18n = context.smPlayerI18n;
      _syncAppBarPortal(
        showPortal: true,
        i18n: i18n,
        title: _searchTitle(i18n),
        results: const SearchResults.empty(),
      );
      return _SearchPageSurface(
        child: _SearchEmptyState(message: i18n.t('search.enterKeyword')),
      );
    }
    final selectedSource =
        ref.watch(selectedLibraryDataSourceProvider).source.deviceId;
    if (_selectionSource != selectedSource) {
      _selectionSource = selectedSource;
      _selection.cancel();
    }
    final contextValue = ref.watch(
      libraryPageQueryProvider(
        const LibraryDataQuery(LibraryQueryKind.context),
      ),
    );
    if (!contextValue.hasValue)
      return contextValue.hasError
          ? LibraryLoadFailure(
            onRetry:
                () => ref.invalidate(
                  libraryPageQueryProvider(
                    const LibraryDataQuery(LibraryQueryKind.context),
                  ),
                ),
          )
          : const SmPlayerLoadingState();
    final root =
        selectedSource == 'local'
            ? contextValue.requireValue.rootPath
            : 'smplayer-music://$selectedSource';
    final relative = widget.folderRelativePath;
    final folder =
        relative == null || relative.isEmpty ? null : '$root/$relative';
    final songQuery = _queryForSongs(selectedSource, folder);
    if (_songQuery != songQuery) _attemptedSongWindows.clear();
    _songQuery = songQuery;
    final songsValue = ref.watch(libraryPagedQueryProvider(songQuery));
    final indexValue = ref.watch(
      _searchIndexProvider(
        LibraryDataQuery(
          LibraryQueryKind.context,
          source: selectedSource,
          folder: folder,
        ),
      ),
    );
    var snapshotValue = indexValue.whenData((index) {
      final songs = songsValue.valueOrNull;
      return index.withPage(
        songs: songs?.songs ?? const [],
        songRows: songs?.songRows ?? const {},
        totalSongCount: songs?.totalSongCount ?? 0,
        totalDuration: songs?.totalDuration ?? 0,
      );
    });
    if (!songsValue.hasValue)
      snapshotValue =
          songsValue.hasError
              ? AsyncError(songsValue.error!, songsValue.stackTrace!)
              : const AsyncLoading();
    Map<int, String>? songFolderPaths;
    final source = ref.watch(
      musicShareProvider.select((share) => share.selectedSource),
    );
    if (source != 'local') {
      final directory = ref.watch(remoteDirectoryProvider(source));
      if (directory.isLoading) {
        snapshotValue = const AsyncLoading();
      } else if (directory.hasError) {
        snapshotValue = AsyncError(directory.error!, directory.stackTrace!);
      } else {
        snapshotValue = snapshotValue.whenData((snapshot) {
          final data = remoteDirectorySnapshot(
            snapshot,
            directory.requireValue,
            source,
          );
          songFolderPaths = data.songFolderPaths;
          return data;
        });
      }
    }
    final songOverrides = ref.watch(librarySongOverridesProvider);
    final mediaState = ref.watch(
      mediaControlControllerProvider.select(
        (controller) => (
          trackId: controller.state.track.id,
          isPlaying: controller.state.isPlaying,
        ),
      ),
    );
    final i18n =
        ref.watch(smPlayerI18nProvider).value ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    final query = widget.query.trim();

    return snapshotValue.when(
      loading: () {
        _syncAppBarPortal(
          showPortal: true,
          i18n: i18n,
          title: _searchTitle(i18n),
          results: const SearchResults.empty(),
        );
        return _SearchPageSurface(
          child:
              query.isEmpty
                  ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _searchPageHorizontalInset,
                      6,
                      _searchPageHorizontalInset,
                      22,
                    ),
                    child: _SearchEmptyState(
                      message: i18n.t('search.enterKeyword'),
                    ),
                  )
                  : const SmPlayerLoadingState(),
        );
      },
      error: (_, _) {
        _syncAppBarPortal(
          showPortal: true,
          i18n: i18n,
          title: _searchTitle(i18n),
          results: const SearchResults.empty(),
        );
        return _SearchPageSurface(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _searchPageHorizontalInset,
              6,
              _searchPageHorizontalInset,
              22,
            ),
            child: const LibraryLoadFailure(),
          ),
        );
      },
      data: (rawSnapshot) {
        final snapshot = _dataCache.snapshot(
          rawSnapshot,
          songOverrides,
          ref.watch(libraryPlaylistOverridesProvider),
          ref.watch(libraryDeletedPlaylistIdsProvider),
          ref.watch(libraryPlaylistOrderProvider),
        );
        final normalizedQuery = query.toLowerCase();
        final searchFolderPath = _searchFolderPath(
          snapshot.rootPath,
          widget.folderRelativePath,
        );
        final lyricsSavedRevision =
            ref.watch(lyricsSavedEventProvider)?.revision ?? 0;
        _syncLocalLyricsSearch(
          query: query,
          folderPath: searchFolderPath,
          lyricsSavedRevision: lyricsSavedRevision,
        );
        _searchCache.updateMetadata(
          snapshot,
          normalizedQuery,
          searchFolderPath,
          i18n,
          songFolderPaths,
        );
        final lyricsQuery = _queryForLyrics(selectedSource, folder);
        if (_lyricsQuery != lyricsQuery) _attemptedLyricsWindows.clear();
        _lyricsQuery = lyricsQuery;
        final lyricsValue = ref.watch(_lyricsWindowProvider(lyricsQuery));
        _lyricsSearchLoading = lyricsValue.isLoading;
        ref.listen(_lyricsWindowProvider(lyricsQuery), (previous, next) {
          if (next.hasError && !identical(previous?.error, next.error))
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted)
                showAppNotification(
                  context: context,
                  message: i18n.t('search.lyricsSearchFailed'),
                );
            });
        });
        final results = _searchCache.results(
          lyricsValue.valueOrNull ?? const _LyricsWindow(0, {}),
        );
        final showNavigationAppBar = WorkspaceNavigationAppBarScope.of(context);
        _syncAppBarPortal(
          showPortal: true,
          i18n: i18n,
          title: _searchTitle(i18n),
          results: results,
        );
        final criteria = SearchCriteria(
          artists: _settings.searchArtistsCriterion,
          albums: _settings.searchAlbumsCriterion,
          songs: _settings.searchSongsCriterion,
          lyrics: _lyricsCriterion,
          playlists: _settings.searchPlaylistsCriterion,
          folders: _settings.searchFoldersCriterion,
        );
        final sections = _searchCache.sections(
          results,
          criteria,
          _activeFilter,
          () => _buildSections(results, criteria),
        );
        final visibleSections = _visibleSections(sections);
        final selectedSongIds = _selectedSongIds(visibleSections);
        final selectedItemCount = _selectedItemCount(visibleSections);
        final selectedKeys = _selectableKeys(sections);
        final folderIndex = _dataCache.folders(snapshot);

        return SmPlayerI18nScope(
          i18n: i18n,
          child: _SearchPageSurface(
            child: Stack(
              children: [
                EdgeAutoHideScrollbar(
                  crossAxisMargin: 1,
                  thickness: 6,
                  hoverThickness: 6,
                  builder:
                      (
                        scrollController,
                      ) => NotificationListener<ScrollUpdateNotification>(
                        onNotification: (notification) {
                          _attemptedSongWindows.clear();
                          _attemptedLyricsWindows.clear();
                          return false;
                        },
                        child: CustomScrollView(
                          controller: scrollController,
                          slivers: [
                            if (query.isEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  _searchPageHorizontalInset,
                                  6,
                                  _searchPageHorizontalInset,
                                  22,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: _SearchEmptyState(
                                    message: i18n.t('search.enterKeyword'),
                                  ),
                                ),
                              )
                            else ...[
                              if (!showNavigationAppBar)
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: _SearchResultToolbarDelegate(
                                    child: _SearchFilterTabs(
                                      i18n: i18n,
                                      activeFilter: _activeFilter,
                                      results: results,
                                      lyricsIndexing:
                                          _lyricsIndexProgress != null,
                                      onChanged: _changeFilter,
                                    ),
                                  ),
                                ),
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                  _searchPageHorizontalInset,
                                  18,
                                  _searchPageHorizontalInset,
                                  _selection.multiSelect
                                      ? multiSelectCommandBarScrollSpacer
                                      : 22,
                                ),
                                sliver: SliverMainAxisGroup(
                                  slivers: [
                                    if (_activeFilter ==
                                            SearchFilterKey.lyrics &&
                                        _lyricsIndexProgress != null) ...[
                                      SliverToBoxAdapter(
                                        child: _SearchLoadingState(
                                          message: _lyricsIndexProgressMessage(
                                            i18n,
                                          ),
                                        ),
                                      ),
                                      const SliverToBoxAdapter(
                                        child: SizedBox(height: 18),
                                      ),
                                    ],
                                    if (lyricsValue.hasError &&
                                        _activeFilter == SearchFilterKey.lyrics)
                                      SliverToBoxAdapter(
                                        child: LibraryLoadFailure(
                                          onRetry:
                                              () => ref.invalidate(
                                                _lyricsWindowProvider(
                                                  lyricsQuery,
                                                ),
                                              ),
                                        ),
                                      ),
                                    if (!(lyricsValue.hasError &&
                                            _activeFilter ==
                                                SearchFilterKey.lyrics) &&
                                        _showSearchStatus(
                                          results,
                                          visibleSections,
                                        )) ...[
                                      SliverToBoxAdapter(
                                        child: _SearchEmptyState(
                                          message: _lyricsSearchStatusMessage(
                                            i18n,
                                            query,
                                          ),
                                        ),
                                      ),
                                      const SliverToBoxAdapter(
                                        child: SizedBox(height: 18),
                                      ),
                                    ],
                                    for (final section in visibleSections) ...[
                                      _SearchResultSection(
                                        section: section,
                                        onAccessSongRow: _accessSearchRow,
                                        onAccessLyricsRow: _accessLyricsRow,
                                        query: query,
                                        i18n: i18n,
                                        activeFilter: _activeFilter,
                                        showCount: snapshot.showCount,
                                        currentTrackId: mediaState.trackId,
                                        isPlaying: mediaState.isPlaying,
                                        selection: _selection,
                                        playlists: _customPlaylists(
                                          snapshot.playlists,
                                        ),
                                        nowPlayingSongIds:
                                            snapshot.nowPlaying.songIds,
                                        songsById: {
                                          for (final song in snapshot.songs)
                                            song.id: song,
                                        },
                                        folderNodes: folderIndex.nodes,
                                        allPlaylists: snapshot.playlists,
                                        expanded: _isSectionExpanded(
                                          section.type,
                                        ),
                                        onToggleExpanded:
                                            _toggleExpandedSection,
                                        onSortChanged: (criterion) {
                                          _updateSort(section.type, criterion);
                                        },
                                        onGetPreferenceLevel:
                                            _getSearchResultPreferenceLevel,
                                        onSetPreference:
                                            _setSearchResultPreference,
                                        onUndoPreference:
                                            _undoSearchResultPreference,
                                        onGetSongPreferenceLevel:
                                            _getSongPreferenceLevel,
                                        onSetSongPreference: _setSongPreference,
                                        onUndoSongPreference:
                                            _undoSongPreference,
                                        onSelectionChanged: () {
                                          _updateSearchPageState(() {});
                                        },
                                        onOpenCard: (card) {
                                          _openCard(section.type, card, query);
                                        },
                                        onPlaySongs: _playSongIds,
                                        onPlayCard: (card) {
                                          _playCard(section.type, card);
                                        },
                                        onPlayTrack: (song, index) async {
                                          final ids = await ref
                                              .read(
                                                selectedLibraryDataSourceProvider,
                                              )
                                              .resolveSongIds(
                                                section.type ==
                                                        SearchResultType.lyrics
                                                    ? lyricsQuery
                                                    : songQuery,
                                              );
                                          if (mounted)
                                            _playTrack(
                                              song,
                                              ids.indexOf(song.id),
                                              ids,
                                            );
                                        },
                                        onPlaySong: (song) {
                                          insertOrPlayNowPlayingSong(
                                            ref: ref,
                                            snapshot: snapshot,
                                            i18n: i18n,
                                            songId: song.id,
                                          );
                                        },
                                        onTogglePlayPause:
                                            ref
                                                .read(
                                                  mediaControlControllerProvider,
                                                )
                                                .onTogglePlayPause,
                                        onPlayNext: _playNext,
                                        onAddSongsToNowPlaying: (songIds) {
                                          return addSongsToNowPlayingWithUndo(
                                            context: context,
                                            ref: ref,
                                            i18n: i18n,
                                            songIds: songIds,
                                          );
                                        },
                                        onAddSongsToPlaylist: (
                                          playlistId,
                                          songIds,
                                        ) {
                                          return addSongsToPlaylistWithUndo(
                                            context: context,
                                            ref: ref,
                                            i18n: i18n,
                                            playlistId: playlistId,
                                            songIds: songIds,
                                            useSingleSongCall: true,
                                          );
                                        },
                                        onAddCardSongsToPlaylist: (
                                          playlistId,
                                          songIds,
                                        ) {
                                          return addSongsToPlaylistWithUndo(
                                            context: context,
                                            ref: ref,
                                            i18n: i18n,
                                            playlistId: playlistId,
                                            songIds: songIds,
                                          );
                                        },
                                        onToggleSongsFavorite: (
                                          songIds,
                                          favorite,
                                        ) {
                                          return setSongsFavoriteWithUndo(
                                            context: context,
                                            ref: ref,
                                            i18n: i18n,
                                            songIds: songIds,
                                            favorite: favorite,
                                          );
                                        },
                                        onCreatePlaylist: _createPlaylist,
                                        onDeleteSong: _deleteSong,
                                        onOpenArtist: _openArtist,
                                        onOpenAlbum: _openAlbum,
                                        onOpenMusicDialog: _openMusicDialog,
                                        onOpenLyricsMatch: _openLyricsMatch,
                                        onPreviewAlbumArt: _showAlbumArtPreview,
                                        onSearchDirectory: _searchDirectory,
                                        onRevealCard: _revealSearchCard,
                                        onRevealSong: _revealSong,
                                      ),
                                      const SliverToBoxAdapter(
                                        child: SizedBox(height: 18),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                ),
                MultiSelectCommandBar(
                  visible: _selection.multiSelect,
                  bottomInset: multiSelectCommandBarShellBottomInset,
                  selectedCount: selectedItemCount,
                  playlists: _customPlaylists(snapshot.playlists),
                  showAddTo: true,
                  addToSongIds: selectedSongIds,
                  nowPlayingSongIds: snapshot.nowPlaying.songIds,
                  includeNowPlayingInAddTo: true,
                  includeFavoritesInAddTo: hasNotFavoriteSongs(
                    selectedSongIds,
                    {for (final song in snapshot.songs) song.id: song},
                  ),
                  onPlay: () {
                    _playSongIds(shuffleSearchSongIds(selectedSongIds));
                    _selection.hideAfterOperation(
                      snapshot.hideMultiSelectCommandBarAfterOperation,
                    );
                    _updateSearchPageState(() {});
                  },
                  onAddToNowPlaying: () async {
                    await addSongsToNowPlayingWithUndo(
                      context: context,
                      ref: ref,
                      i18n: i18n,
                      songIds: selectedSongIds,
                    );
                    _selection.hideAfterOperation(
                      snapshot.hideMultiSelectCommandBarAfterOperation,
                    );
                    _updateSearchPageState(() {});
                  },
                  onToggleFavorite: () {
                    final songsById = {
                      for (final song in snapshot.songs) song.id: song,
                    };
                    setSongsFavoriteWithUndo(
                      context: context,
                      ref: ref,
                      i18n: i18n,
                      songIds: notFavoriteSongIds(selectedSongIds, songsById),
                      favorite: true,
                    );
                    _selection.hideAfterOperation(
                      snapshot.hideMultiSelectCommandBarAfterOperation,
                    );
                    _updateSearchPageState(() {});
                  },
                  onCreatePlaylist: () async {
                    await createPlaylistWithSongs(
                      context: context,
                      ref: ref,
                      i18n: i18n,
                      playlists: snapshot.playlists,
                      defaultName:
                          query.isEmpty ? i18n.t('common.songs') : query,
                      songIds: selectedSongIds,
                    );
                    if (!mounted) {
                      return;
                    }
                    _selection.hideAfterOperation(
                      snapshot.hideMultiSelectCommandBarAfterOperation,
                    );
                    _updateSearchPageState(() {});
                  },
                  onAddToPlaylist: (playlistId) async {
                    await addSongsToPlaylistWithUndo(
                      context: context,
                      ref: ref,
                      i18n: i18n,
                      playlistId: playlistId,
                      songIds: selectedSongIds,
                      useSingleSongCall: true,
                    );
                    _selection.hideAfterOperation(
                      snapshot.hideMultiSelectCommandBarAfterOperation,
                    );
                    _updateSearchPageState(() {});
                  },
                  onSelectAll: () {
                    unawaited(_selectSearchScope(selectedKeys, reverse: false));
                  },
                  onReverseSelection: () {
                    unawaited(_selectSearchScope(selectedKeys, reverse: true));
                  },
                  onClearSelection: () {
                    _updateSearchPageState(_selection.clearSelection);
                  },
                  onCancel: () {
                    _updateSearchPageState(_selection.cancel);
                  },
                ),
                if (_musicDialog case final dialog?)
                  MusicDialog(
                    song: dialog.song,
                    initialMode: dialog.mode,
                    initialLyricsMatch: _musicDialogLyricsMatch,
                    currentTrackId: mediaState.trackId,
                    isPlaying: mediaState.isPlaying,
                    queueSongIds: dialog.queueSongIds,
                    onPlay:
                        ref
                            .read(mediaControlControllerProvider)
                            .onTogglePlayPause,
                    onPlayTrack: (trackId, queueSongIds) {
                      final songsById = {
                        for (final song
                            in ref
                                .read(libraryContentDataProvider)
                                .value!
                                .songs)
                          song.id: song,
                      };
                      _playTrack(
                        songsById[trackId]!,
                        queueSongIds.indexOf(trackId),
                        queueSongIds,
                      );
                    },
                    onReveal: _revealSongPath,
                    onClose: () {
                      _updateSearchPageState(() {
                        _musicDialog = null;
                        _musicDialogLyricsMatch = null;
                      });
                    },
                  ),
                if (_albumArtPreview case final album?)
                  AlbumArtworkDialog(
                    albumName: album.title,
                    artworkUrl: album.artworkUrl,
                    songId: album.songIds.first,
                    onClose: () {
                      _updateSearchPageState(() {
                        _albumArtPreview = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_SearchSectionData> _buildSections(
    SearchResults results,
    SearchCriteria criteria,
  ) {
    final lyricsCriterion =
        _activeFilter == SearchFilterKey.all
            ? SearchSortCriterion.defaultCriterion
            : criteria.lyrics;
    return [
      _SearchSectionData.cards(
        type: SearchResultType.artists,
        criterion: criteria.artists,
        cards: sortSearchResults(results.artists, criteria.artists),
        previewLimit: _SearchPageState._artistPreviewLimit,
      ),
      _SearchSectionData.cards(
        type: SearchResultType.albums,
        criterion: criteria.albums,
        cards: sortSearchResults(results.albums, criteria.albums),
        previewLimit: _SearchPageState._sectionPreviewLimit,
      ),
      _SearchSectionData.songs(
        criterion: criteria.songs,
        songs: results.songs,
        totalCount: results.songCount,
        songRows: results.songRows,
        previewLimit: _SearchPageState._sectionPreviewLimit,
      ),
      _SearchSectionData.lyrics(
        criterion: lyricsCriterion,
        lyrics: results.lyrics,
        totalCount: results.lyricsCount,
        lyricsRows: results.lyricsRows,
        previewLimit: 2,
      ),
      _SearchSectionData.cards(
        type: SearchResultType.playlists,
        criterion: criteria.playlists,
        cards: sortSearchResults(results.playlists, criteria.playlists),
        previewLimit: _SearchPageState._sectionPreviewLimit,
      ),
      _SearchSectionData.cards(
        type: SearchResultType.folders,
        criterion: criteria.folders,
        cards: sortSearchResults(results.folders, criteria.folders),
        previewLimit: _SearchPageState._sectionPreviewLimit,
      ),
    ];
  }
}
