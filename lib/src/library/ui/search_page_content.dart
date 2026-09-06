part of 'search_page.dart';

extension _SearchPageContent on _SearchPageState {
  Widget _buildSearchPage(BuildContext context) {
    final snapshotValue = ref.watch(libraryContentDataProvider);
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
                  : _SearchLoadingState(message: i18n.t('nowPlaying.loading')),
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
            child: _SearchEmptyState(message: i18n.t('search.noResult')),
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
          librarySnapshotIdentity: identityHashCode(rawSnapshot),
        );
        _searchCache.updateMetadata(
          snapshot,
          normalizedQuery,
          searchFolderPath,
          i18n,
        );
        final results = _searchCache.results(_lyricsMatches);
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
                CustomScrollView(
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
                              lyricsIndexing: _lyricsIndexProgress != null,
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
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            if (_activeFilter == SearchFilterKey.lyrics &&
                                _lyricsIndexProgress != null) ...[
                              _SearchLoadingState(
                                message: _lyricsIndexProgressMessage(i18n),
                              ),
                              const SizedBox(height: 18),
                            ],
                            if (_showSearchStatus(
                              results,
                              visibleSections,
                            )) ...[
                              _SearchEmptyState(
                                message: _lyricsSearchStatusMessage(
                                  i18n,
                                  query,
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                            for (final section in visibleSections) ...[
                              _SearchResultSection(
                                section: section,
                                query: query,
                                i18n: i18n,
                                activeFilter: _activeFilter,
                                showCount: snapshot.showCount,
                                currentTrackId: mediaState.trackId,
                                isPlaying: mediaState.isPlaying,
                                selection: _selection,
                                playlists: _customPlaylists(snapshot.playlists),
                                nowPlayingSongIds: snapshot.nowPlaying.songIds,
                                songsById: {
                                  for (final song in snapshot.songs)
                                    song.id: song,
                                },
                                folderNodes: folderIndex.nodes,
                                allPlaylists: snapshot.playlists,
                                expanded: _isSectionExpanded(section.type),
                                onToggleExpanded: _toggleExpandedSection,
                                onSortChanged: (criterion) {
                                  _updateSort(section.type, criterion);
                                },
                                onGetPreferenceLevel:
                                    _getSearchResultPreferenceLevel,
                                onSetPreference: _setSearchResultPreference,
                                onUndoPreference: _undoSearchResultPreference,
                                onGetSongPreferenceLevel:
                                    _getSongPreferenceLevel,
                                onSetSongPreference: _setSongPreference,
                                onUndoSongPreference: _undoSongPreference,
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
                                onPlayTrack: (song, index) {
                                  final queueSongIds =
                                      section.type == SearchResultType.lyrics
                                          ? section.lyrics
                                              .map((item) => item.song.id)
                                              .toList()
                                          : section.songs
                                              .map((item) => item.id)
                                              .toList();
                                  _playTrack(song, index, queueSongIds);
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
                                        .read(mediaControlControllerProvider)
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
                                onAddSongsToPlaylist: (playlistId, songIds) {
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
                                onToggleSongsFavorite: (songIds, favorite) {
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
                              const SizedBox(height: 18),
                            ],
                          ]),
                        ),
                      ),
                    ],
                  ],
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
                  onAddToNowPlaying: () {
                    addSongsToNowPlayingWithUndo(
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
                  onAddToPlaylist: (playlistId) {
                    addSongsToPlaylistWithUndo(
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
                    _updateSearchPageState(() {
                      _selection.selectAll(selectedKeys);
                    });
                  },
                  onReverseSelection: () {
                    _updateSearchPageState(() {
                      _selection.reverseSelection(selectedKeys);
                    });
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
                    onSaved: () {
                      ref.invalidate(libraryContentDataProvider);
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
    final metadataSongIds = results.songs.map((song) => song.id).toSet();
    final visibleLyrics =
        _activeFilter == SearchFilterKey.all
            ? results.lyrics
                .where((result) => !metadataSongIds.contains(result.song.id))
                .toList()
            : results.lyrics;
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
        songs: sortSearchSongs(results.songs, criteria.songs),
        previewLimit: _SearchPageState._sectionPreviewLimit,
      ),
      _SearchSectionData.lyrics(
        criterion: lyricsCriterion,
        lyrics: sortSearchLyrics(visibleLyrics, lyricsCriterion),
        previewLimit: _SearchPageState._sectionPreviewLimit,
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
