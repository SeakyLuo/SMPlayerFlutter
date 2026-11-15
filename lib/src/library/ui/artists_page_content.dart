part of 'artists_page.dart';

extension _ArtistsPageContent on _ArtistsPageState {
  Widget _buildArtistsPage(BuildContext context) {
    final selectionSource =
        ref.watch(selectedLibraryDataSourceProvider).source.deviceId;
    if (_selectionSource != selectionSource) {
      _selectionSource = selectionSource;
      _selection.cancel();
    }
    if (!TickerMode.valuesOf(context).enabled) return const SizedBox.shrink();
    _listenForArtistsListRequests(this);
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(
      browsingLibraryPageProvider(
        const LibraryDataQuery(LibraryQueryKind.artistIndex),
      ),
    );
    final songOverrides = ref.watch(librarySongOverridesProvider);
    final mediaState = ref.watch(
      mediaControlControllerProvider.select(
        (controller) => (
          trackId: controller.state.track.id,
          isPlaying: controller.state.isPlaying,
        ),
      ),
    );

    if (i18nValue.isLoading) {
      return const _ArtistsPagePanel(
        child: SmPlayerLoadingState(layout: SmPlayerLoadingLayout.artists),
      );
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const _ArtistsPagePanel(
        child: SmPlayerLoadingState(layout: SmPlayerLoadingLayout.artists),
      );
    }

    return snapshotValue.when(
      skipLoadingOnReload: true,
      loading: () {
        final useWorkspaceAppBar = WorkspaceNavigationAppBarScope.of(context);
        _syncAppBarPortal(
          showPortal: true,
          routePath: '/artists',
          content:
              widget.targetArtistName != null
                  ? const SizedBox.shrink()
                  : _ArtistsAppBarSearchActions(
                    searchOpen: _appBarSearchOpen,
                    artistSearch: _artistSearch,
                    sortCriterion: _artistSortCriterion,
                    i18n: i18n,
                    searchFocused: _artistSearchFocused,
                    searchSuggestions: const [],
                    searchHistoryEntries: const [],
                    onOpenSearch: () {
                      _updateArtistsPageState(() {
                        _appBarSearchOpen = true;
                        _artistSearchFocused = true;
                      });
                    },
                    onCloseSearch: () {
                      _updateArtistsPageState(() {
                        _appBarSearchOpen = false;
                        _artistSearchFocused = false;
                      });
                    },
                    onSearchChanged: (value) {
                      _updateArtistsPageState(() {
                        _artistSearch = value;
                      });
                    },
                    onSearchFocusChanged: _changeArtistSearchFocus,
                    onSearchSubmitted: _recordLoadingArtistSearch,
                    onClearSearch: () {
                      _updateArtistsPageState(() {
                        _artistSearch = '';
                      });
                    },
                    onSelectSearchSuggestion: _selectArtistSearchQuery,
                    onRemoveRecentSearch: _removeArtistRecentSearch,
                    onClearRecentSearches: _clearArtistRecentSearches,
                    onChangeArtistSort: _changeArtistSort,
                  ),
          compactTitle: i18n.t('library.allArtists'),
          layoutSignature: 'loading',
          searchSuggestionCount: 0,
          searchHistoryCount: 0,
        );
        final master = _ArtistsLoadingMaster(
          showSearch: !useWorkspaceAppBar,
          artistSearch: _artistSearch,
          scrollController: _artistListController,
          i18n: i18n,
          searchFocused: _artistSearchFocused,
          onChanged: (value) {
            _updateArtistsPageState(() {
              _artistSearch = value;
            });
          },
          onFocusChanged: _changeArtistSearchFocus,
          onSubmitted: _recordLoadingArtistSearch,
        );
        return _ArtistsPagePanel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth <= 860) return master;
              return Row(
                children: [
                  SizedBox(width: 300, child: master),
                  const Expanded(child: _ArtistsDetailLoadingState()),
                ],
              );
            },
          ),
        );
      },
      error: (_, _) => const _ArtistsPagePanel(child: LibraryLoadFailure()),
      data: (rawSnapshot) {
        final libraryData = ref.watch(
          _artistsLibraryDataProvider((
            snapshot: rawSnapshot,
            songOverrides: songOverrides,
            i18n: i18n,
          )),
        );
        final snapshot = libraryData.snapshot;
        final artistGroups = libraryData.artistGroups;
        final sortedArtistGroups = ref.watch(
          _sortedArtistGroupsProvider((
            artistGroups: artistGroups,
            criterion: _artistSortCriterion,
          )),
        );
        var visibleArtists =
            _reverseArtistDisplayOrder
                ? sortedArtistGroups.reversed.toList()
                : sortedArtistGroups;
        if (widget.targetArtistName != null) {
          final target = widget.targetArtistName!;
          final targetIndex = visibleArtists.indexWhere(
            (artist) => artist.name == target,
          );
          if (targetIndex >= 0 && _appliedTargetArtistName != target) {
            _appliedTargetArtistName = target;
            _notifiedMissingTargetArtistName = null;
            _selectedArtistName = target;
            _artistSearch = target;
            _selection.cancel();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              if (_artistListController.hasClients) {
                _artistListController.jumpTo(targetIndex * artistRowHeight);
              }
              if (_artistDetailController.hasClients) {
                _artistDetailController.jumpTo(0);
              }
            });
          } else if (targetIndex < 0 &&
              _notifiedMissingTargetArtistName != target) {
            _notifiedMissingTargetArtistName = target;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              showAppNotification(
                context: context,
                message: i18n.t('collection.artistNotFound'),
                duration: const Duration(milliseconds: 3200),
              );
            });
          }
        }

        final targetArtistName = widget.targetArtistName;
        final targetArtistAvailable =
            targetArtistName != null &&
            visibleArtists.any((artist) => artist.name == targetArtistName);
        final compactLayout = _isArtistsPageCompactWorkspace(context);
        var targetArtist =
            targetArtistAvailable
                ? visibleArtists.firstWhere(
                  (artist) => artist.name == targetArtistName,
                )
                : null;
        if (targetArtist != null) {
          _recordBrowseAfterFrame(targetArtist.name);
        }
        if (!targetArtistAvailable &&
            !visibleArtists.any(
              (artist) => artist.name == _selectedArtistName,
            )) {
          _selection.cancel();
          _selectedArtistName =
              compactLayout || visibleArtists.isEmpty
                  ? ''
                  : visibleArtists.first.name;
        }
        final detailSummary =
            (targetArtist != null
                    ? [targetArtist]
                    : visibleArtists
                        .where((artist) => artist.name == _selectedArtistName)
                        .toList())
                .firstOrNull;
        _detailArtistSource = detailSummary?.sourceName;
        final detailSongs = const <LibrarySong>[];
        if (detailSummary != null) {
          final loaded = detailSummary.withSongs(detailSongs);
          visibleArtists = [
            for (final artist in visibleArtists)
              artist.name == loaded.name ? loaded : artist,
          ];
          if (targetArtist?.name == loaded.name) targetArtist = loaded;
        }
        final artistSearchSuggestions =
            _artistSearch.trim().isEmpty
                ? const <String>[]
                : searchArtists(
                  artistGroups,
                  _artistSearch,
                ).take(8).map((artist) => artist.name).toList();
        final artistSearchHistoryEntries = latestSearchHistoryEntries(
          ref.watch(recentSearchesProvider).valueOrNull ??
              snapshot.recentSearches,
          SearchHistoryType.artists,
        );
        final matchingSelectedArtists =
            visibleArtists
                .where((artist) => artist.name == _selectedArtistName)
                .toList();
        final wideSelectedArtist =
            matchingSelectedArtists.isNotEmpty
                ? matchingSelectedArtists.first
                : (visibleArtists.isEmpty ? null : visibleArtists.first);
        final compactSelectedArtist =
            targetArtist ??
            (matchingSelectedArtists.isNotEmpty
                ? matchingSelectedArtists.first
                : null);
        final artistQuickJumpKeys = artistQuickJumpKeysForSort(
          _artistSortCriterion,
        );
        final artistQuickJumpMap = buildArtistQuickJumpMap(
          visibleArtists,
          _artistSortCriterion,
        );
        final activeArtistQuickJumpKey = _getActiveArtistQuickJumpKey(
          visibleArtists,
          _artistSortCriterion,
        );

        final selectedArtistForSelection =
            compactSelectedArtist ?? wideSelectedArtist;
        final selectedArtistSongIds =
            selectedArtistForSelection == null || !_selection.multiSelect
                ? const <int>[]
                : watchLibraryScopeIds(
                      ref,
                      LibraryDataQuery(
                        LibraryQueryKind.artist,
                        source:
                            ref
                                .read(selectedLibraryDataSourceProvider)
                                .source
                                .deviceId,
                        artists: [selectedArtistForSelection.sourceName],
                      ),
                    ).valueOrNull ??
                    const <int>[];
        final selectedVisibleSongIds =
            selectedArtistSongIds
                .where((songId) => _selection.selectedItems.contains(songId))
                .toList();
        final songsById = {
          for (final song
              in ref.watch(libraryContentDataProvider).requireValue.songs)
            song.id: song,
        };
        final customLibraryPlaylists =
            snapshot.playlists
                .where((playlist) => !playlist.isBuiltIn)
                .toList();
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
        final useWorkspaceAppBar = WorkspaceNavigationAppBarScope.of(context);
        return Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth <= 720;
                final compactAppBarTitle =
                    compact
                        ? compactSelectedArtist?.name ??
                            _allArtistsTitle(snapshot, artistGroups, i18n)
                        : _allArtistsTitle(snapshot, artistGroups, i18n);
                final compactAppBarDetailControls =
                    useWorkspaceAppBar &&
                            compact &&
                            compactSelectedArtist != null
                        ? DecoratedBox(
                          key: const ValueKey(
                            'Artists.DetailHeader.AppBarShadow',
                          ),
                          decoration:
                              _ArtistsColors.compactDetailHeaderDecoration(
                                Theme.of(context).brightness,
                              ),
                          child: _ArtistDetailCompactCommandRow(
                            artist: compactSelectedArtist,
                            i18n: i18n,
                            workspaceAppBarBottom: true,
                            onPlaySongs: () {
                              _playShuffledSongIds(
                                compactSelectedArtist.songs
                                    .map((song) => song.id)
                                    .toList(),
                                artistName: compactSelectedArtist.name,
                              );
                            },
                            onOpenArtistMenu: (position) {
                              return _showGroupContextMenu(
                                position: position,
                                type: _ArtistGroupMenuType.artist,
                                label: compactSelectedArtist.name,
                                songs: compactSelectedArtist.songs,
                                showLocateArtist: true,
                              );
                            },
                          ),
                        )
                        : null;
                _syncAppBarPortal(
                  showPortal: true,
                  routePath: '/artists',
                  content:
                      targetArtist != null
                          ? const SizedBox.shrink()
                          : _ArtistsAppBarSearchActions(
                            searchOpen: _appBarSearchOpen,
                            artistSearch: _artistSearch,
                            sortCriterion: _artistSortCriterion,
                            i18n: i18n,
                            searchFocused: _artistSearchFocused,
                            searchSuggestions: artistSearchSuggestions,
                            searchHistoryEntries: artistSearchHistoryEntries,
                            onOpenSearch: () {
                              _updateArtistsPageState(() {
                                _appBarSearchOpen = true;
                                _artistSearchFocused = true;
                              });
                            },
                            onCloseSearch: () {
                              _updateArtistsPageState(() {
                                _appBarSearchOpen = false;
                                _artistSearchFocused = false;
                              });
                            },
                            onSearchChanged: (value) {
                              _updateArtistsPageState(() {
                                _artistSearch = value;
                              });
                            },
                            onSearchFocusChanged: _changeArtistSearchFocus,
                            onSearchSubmitted: () {
                              _submitArtistSearch();
                              _updateArtistsPageState(() {
                                _appBarSearchOpen = false;
                              });
                            },
                            onClearSearch: () {
                              _updateArtistsPageState(() {
                                _artistSearch = '';
                              });
                            },
                            onSelectSearchSuggestion: (query) {
                              _selectArtistSearchQuery(query);
                              _updateArtistsPageState(() {
                                _appBarSearchOpen = false;
                              });
                            },
                            onRemoveRecentSearch: _removeArtistRecentSearch,
                            onClearRecentSearches: _clearArtistRecentSearches,
                            onChangeArtistSort: _changeArtistSort,
                          ),
                  compactTitle: compactAppBarTitle,
                  titleTooltip: compact ? compactSelectedArtist?.name : null,
                  layoutSignature:
                      compact
                          ? 'compact:${compactSelectedArtist?.name ?? ''}'
                          : 'wide',
                  searchSuggestionCount: artistSearchSuggestions.length,
                  searchHistoryCount: artistSearchHistoryEntries.length,
                  bottomContent: compactAppBarDetailControls,
                );
                return _ArtistsPagePanel(
                  child: _ArtistsMasterDetail(
                    compact: compact,
                    artistSearch: _artistSearch,
                    compactSelectedArtist: compactSelectedArtist,
                    wideSelectedArtist: wideSelectedArtist,
                    visibleArtists: visibleArtists,
                    sortCriterion: _artistSortCriterion,
                    artistQuickJumpKeys: artistQuickJumpKeys,
                    artistQuickJumpMap: artistQuickJumpMap,
                    activeArtistQuickJumpKey: activeArtistQuickJumpKey,
                    locatedArtistName: _locatedArtistName,
                    locateArtistPulse: _locateArtistPulse,
                    artistListController: _artistListController,
                    artistDetailController: _artistDetailController,
                    multiSelect: _selection.multiSelect,
                    selectedSongIds: _selection.selectedItems,
                    i18n: i18n,
                    showSearch: !useWorkspaceAppBar,
                    searchFocused: _artistSearchFocused,
                    searchSuggestions: artistSearchSuggestions,
                    searchHistoryEntries: artistSearchHistoryEntries,
                    selectedArtistSongIds: selectedArtistSongIds,
                    customPlaylists: customPlaylists,
                    selectedTrackId: mediaState.trackId,
                    isPlaying: mediaState.isPlaying,
                    onSearchChanged: (value) {
                      _updateArtistsPageState(() {
                        _artistSearch = value;
                      });
                    },
                    onSearchFocusChanged: _changeArtistSearchFocus,
                    onSearchSubmitted: _submitArtistSearch,
                    onSelectSearchSuggestion: _selectArtistSearchQuery,
                    onRemoveRecentSearch: _removeArtistRecentSearch,
                    onClearRecentSearches: _clearArtistRecentSearches,
                    onChangeArtistSort: _changeArtistSort,
                    onOpenArtistDetail: _openArtistDetail,
                    onPlayArtist: (artist) {
                      unawaited(_playArtistSummary(artist));
                    },
                    onOpenArtistMenu:
                        ({required position, required artist}) =>
                            _showArtistSummaryMenu(position, artist),
                    onOpenArtistDetailMenu: ({
                      required position,
                      required artist,
                      required showLocateArtist,
                    }) {
                      _showGroupContextMenu(
                        position: position,
                        type: _ArtistGroupMenuType.artist,
                        label: artist.name,
                        songs: artist.songs,
                        showLocateArtist: showLocateArtist,
                      );
                    },
                    onOpenAlbumMenu: ({required position, required album}) {
                      _showGroupContextMenu(
                        position: position,
                        type: _ArtistGroupMenuType.album,
                        label: album.name,
                        songs: album.songs,
                      );
                    },
                    onJumpToArtistKey: _jumpToArtistKey,
                    onPlaySongs: _playShuffledSongIds,
                    onPlayTrack: _playTrackInQueue,
                    onPlaySong: _moveToMusicOrPlay,
                    onTogglePlayPause:
                        ref
                            .read(mediaControlControllerProvider)
                            .onTogglePlayPause,
                    onPlayNext: _playNext,
                    onToggleFavorite: (songId, favorite) {
                      setSongsFavoriteFromControl(ref, [songId], favorite);
                    },
                    onOpenSongAddToMenu: _showSongAddToMenu,
                    onToggleSongSelection: _toggleSongSelection,
                    onOpenSongContextMenu: (position, song) {
                      return _showSongContextMenu(
                        position,
                        song,
                        selectedArtistSongIds,
                        customPlaylists,
                      );
                    },
                  ),
                );
              },
            ),
            MultiSelectCommandBar(
              visible: _selection.multiSelect,
              bottomInset: multiSelectCommandBarShellBottomInset,
              selectedCount: selectedVisibleSongIds.length,
              playlists: customPlaylists,
              addToSongIds: selectedVisibleSongIds,
              nowPlayingSongIds: snapshot.nowPlaying.songIds,
              includeNowPlayingInAddTo: true,
              includeFavoritesInAddTo: hasNotFavoriteSongs(
                selectedVisibleSongIds,
                songsById,
              ),
              onAddToNowPlaying:
                  selectedVisibleSongIds.isEmpty
                      ? null
                      : () {
                        addSongsToNowPlayingWithUndo(
                          context: context,
                          ref: ref,
                          i18n: i18n,
                          songIds: selectedVisibleSongIds,
                        );
                      },
              onToggleFavorite:
                  selectedVisibleSongIds.isEmpty
                      ? null
                      : () {
                        setSongsFavoriteWithUndo(
                          context: context,
                          ref: ref,
                          i18n: i18n,
                          songIds: notFavoriteSongIds(
                            selectedVisibleSongIds,
                            songsById,
                          ),
                          favorite: true,
                        );
                      },
              onCreatePlaylist:
                  selectedVisibleSongIds.isEmpty
                      ? null
                      : () async {
                        await createPlaylistWithSongs(
                          context: context,
                          ref: ref,
                          i18n: i18n,
                          playlists: customLibraryPlaylists,
                          defaultName:
                              selectedArtistForSelection?.name ??
                              i18n.t('common.artists'),
                          songIds: selectedVisibleSongIds,
                        );
                      },
              onPlay: () {
                _playSongIds(selectedVisibleSongIds);
                _updateArtistsPageState(() {
                  _selection.hideAfterOperation(
                    snapshot.hideMultiSelectCommandBarAfterOperation,
                  );
                });
              },
              onAddToPlaylist: (playlistId) async {
                await addSongsToPlaylistWithUndo(
                  context: context,
                  ref: ref,
                  i18n: i18n,
                  playlistId: playlistId,
                  songIds: selectedVisibleSongIds,
                );
              },
              onSelectAll:
                  () => unawaited(
                    _selectArtistScope(
                      selectedArtistForSelection!,
                      reverse: false,
                    ),
                  ),
              onReverseSelection:
                  () => unawaited(
                    _selectArtistScope(
                      selectedArtistForSelection!,
                      reverse: true,
                    ),
                  ),
              onClearSelection: () {
                _updateArtistsPageState(_selection.clearSelection);
              },
              onCancel: () {
                _updateArtistsPageState(_selection.cancel);
              },
            ),
            if (_musicDialog case final dialog?)
              MusicDialog(
                song: dialog.song,
                initialMode: dialog.mode,
                currentTrackId: mediaState.trackId,
                isPlaying: mediaState.isPlaying,
                queueSongIds: dialog.queueSongIds,
                onPlay:
                    ref.read(mediaControlControllerProvider).onTogglePlayPause,
                onPlayTrack: _playTrackInQueue,
                onReveal: (path) {
                  unawaited(revealItemInFolder(path));
                },
                onSaved: () {
                  notifyLyricsSaved(ref, dialog.song.id);
                },
                onClose: () {
                  _updateArtistsPageState(() {
                    _musicDialog = null;
                  });
                },
              ),
          ],
        );
      },
    );
  }
}
