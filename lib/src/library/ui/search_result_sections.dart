part of 'search_page.dart';

class _SearchSectionData {
  const _SearchSectionData.cards({
    required this.type,
    required this.criterion,
    required this.cards,
    required this.previewLimit,
  }) : songs = const [],
       totalCount = null,
       songRows = const {},
       lyricsRows = const {},
       lyrics = const [];

  const _SearchSectionData.songs({
    required this.criterion,
    required this.songs,
    this.totalCount,
    this.songRows = const {},
    required this.previewLimit,
  }) : type = SearchResultType.songs,
       lyricsRows = const {},
       cards = const [],
       lyrics = const [];

  const _SearchSectionData.lyrics({
    required this.criterion,
    required this.lyrics,
    this.totalCount,
    this.lyricsRows = const {},
    required this.previewLimit,
  }) : type = SearchResultType.lyrics,
       songRows = const {},
       cards = const [],
       songs = const [];

  final SearchResultType type;
  final SearchSortCriterion criterion;
  final List<SearchResult> cards;
  final Map<int, SearchLyricsResult> lyricsRows;
  final int? totalCount;
  final Map<int, LibrarySong> songRows;
  final List<LibrarySong> songs;
  final List<SearchLyricsResult> lyrics;
  final int previewLimit;

  int get count => switch (type) {
    SearchResultType.songs => totalCount ?? songs.length,
    SearchResultType.lyrics => totalCount ?? lyrics.length,
    _ => cards.length,
  };

  List<String> visibleKeys({bool preview = false}) {
    final itemCount = (preview ? count.clamp(0, previewLimit) : count).toInt();
    return switch (type) {
      SearchResultType.songs => [
        for (final song in songs.take(itemCount)) _songSelectionKey(song),
      ],
      SearchResultType.lyrics => [
        for (final result in lyrics.take(itemCount))
          _songSelectionKey(result.song),
      ],
      _ => [
        for (final card in cards.take(itemCount))
          getSearchResultCardKey(type, card),
      ],
    };
  }
}

String _activeSortLabel(
  List<({SearchSortCriterion value, String label})> options,
  SearchSortCriterion criterion,
) {
  return options.firstWhere((option) => option.value == criterion).label;
}

class _SearchResultSection extends StatelessWidget {
  const _SearchResultSection({
    required this.section,
    required this.onAccessSongRow,
    required this.onAccessLyricsRow,
    required this.query,
    required this.i18n,
    required this.activeFilter,
    required this.showCount,
    required this.currentTrackId,
    required this.isPlaying,
    required this.selection,
    required this.playlists,
    required this.nowPlayingSongIds,
    required this.songsById,
    required this.folderNodes,
    required this.allPlaylists,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSortChanged,
    required this.onGetPreferenceLevel,
    required this.onSetPreference,
    required this.onUndoPreference,
    required this.onGetSongPreferenceLevel,
    required this.onSetSongPreference,
    required this.onUndoSongPreference,
    required this.onSelectionChanged,
    required this.onOpenCard,
    required this.onPlaySongs,
    required this.onPlayCard,
    required this.onPlayTrack,
    required this.onPlaySong,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onAddSongsToNowPlaying,
    required this.onAddSongsToPlaylist,
    required this.onAddCardSongsToPlaylist,
    required this.onToggleSongsFavorite,
    required this.onCreatePlaylist,
    required this.onDeleteSong,
    required this.onOpenArtist,
    required this.onOpenAlbum,
    required this.onOpenMusicDialog,
    required this.onOpenLyricsMatch,
    required this.onPreviewAlbumArt,
    required this.onSearchDirectory,
    required this.onRevealCard,
    required this.onRevealSong,
  });

  final ValueChanged<int> onAccessSongRow;
  final ValueChanged<int> onAccessLyricsRow;
  final _SearchSectionData section;
  final String query;
  final SmPlayerI18n i18n;
  final SearchFilterKey activeFilter;
  final bool showCount;
  final int? currentTrackId;
  final bool isPlaying;
  final PageSelectionController<String> selection;
  final List<MultiSelectCommandBarPlaylist> playlists;
  final List<int> nowPlayingSongIds;
  final Map<int, LibrarySong> songsById;
  final Map<String, FolderNode> folderNodes;
  final List<LibraryPlaylist> allPlaylists;
  final bool expanded;
  final ValueChanged<SearchResultType> onToggleExpanded;
  final ValueChanged<SearchSortCriterion> onSortChanged;
  final Future<String?> Function(SearchResultType, SearchResult)
  onGetPreferenceLevel;
  final Future<void> Function(SearchResultType, SearchResult, String)
  onSetPreference;
  final Future<void> Function(SearchResultType, SearchResult) onUndoPreference;
  final Future<String?> Function(LibrarySong) onGetSongPreferenceLevel;
  final Future<void> Function(LibrarySong, String) onSetSongPreference;
  final Future<void> Function(LibrarySong) onUndoSongPreference;
  final VoidCallback onSelectionChanged;
  final ValueChanged<SearchResult> onOpenCard;
  final ValueChanged<List<int>> onPlaySongs;
  final ValueChanged<SearchResult> onPlayCard;
  final void Function(LibrarySong, int) onPlayTrack;
  final ValueChanged<LibrarySong> onPlaySong;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<LibrarySong> onPlayNext;
  final Future<void> Function(List<int>) onAddSongsToNowPlaying;
  final Future<void> Function(int, List<int>) onAddSongsToPlaylist;
  final Future<void> Function(int, List<int>) onAddCardSongsToPlaylist;
  final Future<void> Function(List<int>, bool) onToggleSongsFavorite;
  final Future<void> Function(String, List<int>) onCreatePlaylist;
  final ValueChanged<LibrarySong> onDeleteSong;
  final ValueChanged<String> onOpenArtist;
  final ValueChanged<String> onOpenAlbum;
  final void Function(LibrarySong, SongDialogMode, List<int>) onOpenMusicDialog;
  final void Function(SearchLyricsResult, List<int>) onOpenLyricsMatch;
  final ValueChanged<SearchResult> onPreviewAlbumArt;
  final ValueChanged<SearchResult> onSearchDirectory;
  final Future<void> Function(SearchResult) onRevealCard;
  final Future<void> Function(LibrarySong) onRevealSong;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    final preview = activeFilter == SearchFilterKey.all;
    final visibleCount =
        preview && !expanded ? section.previewLimit : section.count;
    final showViewToggle = preview && section.count > section.previewLimit;
    final sortOptions = getSortOptions(section.type, i18n);

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _sectionTitle(section.type, section.count),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              if (showViewToggle) ...[
                _SearchSectionActionButton(
                  icon: FluentIcons.grid_20_regular,
                  label:
                      expanded
                          ? i18n.t('search.viewLess')
                          : i18n.t('search.viewAll'),
                  onPressed: () => onToggleExpanded(section.type),
                ),
                const SizedBox(width: 6),
              ],
              if (section.type != SearchResultType.lyrics || !preview)
                Builder(
                  builder: (buttonContext) {
                    return _SearchSectionActionButton(
                      icon: FluentIcons.arrow_sort_20_regular,
                      label: _activeSortLabel(sortOptions, section.criterion),
                      onPressed: () {
                        showMenuFlyout(
                          buttonContext,
                          items: [
                            for (final option in sortOptions)
                              MenuFlyoutItem(
                                key:
                                    'search-sort-${section.type}-${option.value}',
                                text: option.label,
                                icon:
                                    option.value == section.criterion
                                        ? FluentIcons.checkmark_20_regular
                                        : null,
                                onPressed: () => onSortChanged(option.value),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: header),
        if (section.type == SearchResultType.songs)
          SliverList.builder(
            itemCount: visibleCount.clamp(0, section.count),
            itemBuilder: (context, index) {
              final song = section.songRows[index];
              if (song == null) {
                onAccessSongRow(index);
                return const LibrarySongPlaceholder();
              }
              return _buildSongRow(context, song, index);
            },
          )
        else if (section.type == SearchResultType.lyrics)
          SliverList.builder(
            itemCount: visibleCount.clamp(0, section.count),
            itemBuilder: (context, index) {
              final result = section.lyricsRows[index];
              if (result == null) {
                onAccessLyricsRow(index);
                return const LibrarySongPlaceholder();
              }
              return _buildLyricsRow(context, result, index);
            },
          )
        else
          SliverToBoxAdapter(child: _buildCards(context, visibleCount)),
      ],
    );
  }

  String _sectionTitle(SearchResultType type, int count) {
    if (!showCount) {
      return switch (type) {
        SearchResultType.artists => i18n.t('common.artists'),
        SearchResultType.albums => i18n.t('common.albums'),
        SearchResultType.songs => i18n.t('common.songs'),
        SearchResultType.lyrics => i18n.t('nowPlaying.lyrics'),
        SearchResultType.playlists => i18n.t('common.playlists'),
        SearchResultType.folders => i18n.t('common.folders'),
      };
    }

    return switch (type) {
      SearchResultType.artists => i18n.t('search.artistsWithCount', {
        'count': count,
      }),
      SearchResultType.albums => i18n.t('search.albumsWithCount', {
        'count': count,
      }),
      SearchResultType.songs => i18n.t('search.songsWithCount', {
        'count': count,
      }),
      SearchResultType.lyrics => i18n.t('search.lyricsWithCount', {
        'count': count,
      }),
      SearchResultType.playlists => i18n.t('search.playlistsWithCount', {
        'count': count,
      }),
      SearchResultType.folders => i18n.t('search.foldersWithCount', {
        'count': count,
      }),
    };
  }

  Widget _buildSongRow(BuildContext context, LibrarySong song, int index) {
    return PlaylistControlItem(
      key: ValueKey('search-song-${song.id}'),
      song: song,
      current: song.id == currentTrackId,
      playing: song.id == currentTrackId && isPlaying,
      selected: selection.isSelected(_songSelectionKey(song)),
      selectionMode: selection.multiSelect,
      variant: PlaylistControlItemVariant.headeredPlaylist,
      searchQuery: query,
      showCompactPrimaryActions: true,
      keepFavoriteActionInCompact: true,
      keepAddToActionInCompact: true,
      favoriteLabel: i18n.t(
        song.favorite ? 'context.removeFavorite' : 'context.addFavorite',
      ),
      addToPlaylistLabel: i18n.t('context.addToPlaylist'),
      onToggleFavoriteClick: () {
        unawaited(onToggleSongsFavorite([song.id], !song.favorite));
      },
      onAddToPlaylistClick:
          (buttonContext) => _showSongAddToMenu(buttonContext, song),
      playNextLabel: i18n.t('context.playNext'),
      removeLabel: i18n.t('nowPlaying.remove'),
      onActivateRow: () {
        onPlayTrack(song, index);
      },
      onPlayTrack: () {
        onPlaySong(song);
      },
      onTogglePlayPause: onTogglePlayPause,
      onToggleSelection: () {
        selection.toggle(_songSelectionKey(song));
        onSelectionChanged();
      },
      onPlayNextClick: () {
        onPlayNext(song);
      },
      onSeeArtist: (artist) {
        onOpenArtist(artist);
      },
      onSeeAlbum: () {
        onOpenAlbum(song_display.displayAlbum(song, i18n));
      },
      onOpenContextMenu: (position) {
        return _showSongContextMenu(
          context,
          position,
          song,
          section.songs.map((song) => song.id).toList(),
        );
      },
    );
  }

  Widget _buildLyricsRow(
    BuildContext context,
    SearchLyricsResult result,
    int index,
  ) {
    final queueSongIds =
        section.lyrics.map((result) => result.song.id).toList();
    return Column(
      children: [
        PlaylistControlItem(
          key: ValueKey('search-lyrics-${result.song.id}'),
          song: result.song,
          current: result.song.id == currentTrackId,
          playing: result.song.id == currentTrackId && isPlaying,
          selected: selection.isSelected(_songSelectionKey(result.song)),
          selectionMode: selection.multiSelect,
          variant: PlaylistControlItemVariant.headeredPlaylist,
          searchQuery: '',
          showCompactPrimaryActions: true,
          keepFavoriteActionInCompact: true,
          keepAddToActionInCompact: true,
          favoriteLabel: i18n.t(
            result.song.favorite
                ? 'context.removeFavorite'
                : 'context.addFavorite',
          ),
          addToPlaylistLabel: i18n.t('context.addToPlaylist'),
          onToggleFavoriteClick: () {
            unawaited(
              onToggleSongsFavorite([result.song.id], !result.song.favorite),
            );
          },
          onAddToPlaylistClick:
              (buttonContext) => _showSongAddToMenu(buttonContext, result.song),
          showBottomBorder: false,
          playNextLabel: i18n.t('context.playNext'),
          removeLabel: i18n.t('nowPlaying.remove'),
          onActivateRow: () {
            onPlayTrack(result.song, index);
          },
          onPlayTrack: () {
            onPlaySong(result.song);
          },
          onTogglePlayPause: onTogglePlayPause,
          onToggleSelection: () {
            selection.toggle(_songSelectionKey(result.song));
            onSelectionChanged();
          },
          onPlayNextClick: () {
            onPlayNext(result.song);
          },
          onSeeArtist: onOpenArtist,
          onSeeAlbum: () {
            onOpenAlbum(song_display.displayAlbum(result.song, i18n));
          },
          onOpenContextMenu: (position) {
            return _showSongContextMenu(
              context,
              position,
              result.song,
              queueSongIds,
            );
          },
        ),
        _SearchLyricsExcerpt(
          key: ValueKey((result.song.id, query)),
          match: result.match,
          query: query,
          i18n: i18n,
          onTap: () {
            if (selection.multiSelect) {
              selection.toggle(_songSelectionKey(result.song));
              onSelectionChanged();
              return;
            }
            onOpenLyricsMatch(result, queueSongIds);
          },
        ),
      ],
    );
  }

  Widget _buildCards(BuildContext context, int visibleCount) {
    if (section.type == SearchResultType.albums) {
      return Wrap(
        spacing: 30,
        runSpacing: 26,
        children: [
          for (final card in section.cards.take(visibleCount))
            AlbumTile(
              album: getSearchAlbumTileData(card, songsById, i18n),
              searchQuery: query,
              multiSelect: selection.multiSelect,
              selected: selection.isSelected(
                getSearchResultCardKey(section.type, card),
              ),
              onOpenAlbum: () {
                onOpenCard(card);
              },
              onPlayAlbum: () {
                onPlayCard(card);
              },
              onAddAlbum: (position) {
                _showCardAddToMenu(context, position, card);
              },
              onToggleSelection: () {
                selection.toggle(getSearchResultCardKey(section.type, card));
                onSelectionChanged();
              },
              onOpenContextMenu: (position) {
                return _showCardContextMenu(context, position, card);
              },
            ),
        ],
      );
    }

    if (section.type == SearchResultType.playlists) {
      return _SearchResultCardGrid(
        type: section.type,
        children: [
          for (final card in section.cards.take(visibleCount))
            Builder(
              builder: (context) {
                final playlist = allPlaylists.firstWhere(
                  (playlist) => playlist.id.toString() == card.sourceId,
                );
                final playlistSongs = [
                  for (final songId in playlist.songIds)
                    if (songsById[songId] case final song?) song,
                ];
                final cardKey = getSearchResultCardKey(section.type, card);
                final selected = selection.isSelected(cardKey);
                return GridViewHolder(
                  playlist: playlist,
                  searchQuery: query,
                  songs: playlistSongs,
                  subtitle: i18n.t('playlists.songCount', {
                    'count': playlist.songCount,
                  }),
                  playTooltip: i18n.t('context.play'),
                  selected: selected,
                  selectionMode: selection.multiSelect,
                  showDragHandle: false,
                  selectedMark:
                      selection.multiSelect || selected
                          ? GridViewSelectionMark(
                            selected: selected,
                            circular: true,
                          )
                          : null,
                  onOpen: () {
                    if (selection.multiSelect) {
                      selection.toggle(cardKey);
                      onSelectionChanged();
                    } else {
                      onOpenCard(card);
                    }
                  },
                  onPlay: () {
                    onPlaySongs(playlistSongs.map((song) => song.id).toList());
                  },
                  onContextMenu: (position) {
                    return _showCardContextMenu(context, position, card);
                  },
                );
              },
            ),
        ],
      );
    }

    if (section.type == SearchResultType.folders) {
      return Wrap(
        spacing: 30,
        runSpacing: 26,
        children: [
          for (final card in section.cards.take(visibleCount))
            if (folderNodes[card.localFolderRelativePath ?? '']
                case final folder?)
              LocalFolderCard(
                folder: folder,
                searchQuery: query,
                selected: selection.isSelected(
                  getSearchResultCardKey(section.type, card),
                ),
                multiSelect: selection.multiSelect,
                nodes: folderNodes,
                songsById: songsById,
                i18n: i18n,
                onPlayFolder: (_) {
                  onPlayCard(card);
                },
                onAddFolder: (_, position) {
                  _showCardAddToMenu(context, position, card);
                },
                onRefreshFolder: (_) {},
                onSearchFolder: (_) {
                  onSearchDirectory(card);
                },
                onRevealFolder: (_) {
                  unawaited(onRevealCard(card));
                },
                onOpenFolder: (_) {
                  onOpenCard(card);
                },
                onOpenFolderMenu: (_, position) {
                  _showCardContextMenu(context, position, card);
                },
                onToggleSelection: (_) {
                  selection.toggle(getSearchResultCardKey(section.type, card));
                  onSelectionChanged();
                },
              ),
        ],
      );
    }

    final cards = section.cards.take(visibleCount).toList();
    return _SearchResultCardGrid(
      type: section.type,
      children: [
        for (final card in cards)
          Builder(
            builder: (context) {
              return _SearchResultCard(
                card: card,
                type: section.type,
                query: query,
                selected: selection.isSelected(
                  getSearchResultCardKey(section.type, card),
                ),
                multiSelect: selection.multiSelect,
                onOpen: () {
                  onOpenCard(card);
                },
                onPlay: () {
                  onPlayCard(card);
                },
                onToggleSelection: () {
                  selection.toggle(getSearchResultCardKey(section.type, card));
                  onSelectionChanged();
                },
                onOpenContextMenu: (position) {
                  return _showCardContextMenu(context, position, card);
                },
              );
            },
          ),
      ],
    );
  }

  Future<void> _showSongContextMenu(
    BuildContext context,
    Offset position,
    LibrarySong song,
    List<int> queueSongIds,
  ) async {
    final preferenceLevel = await onGetSongPreferenceLevel(song);
    if (!context.mounted) {
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
        isPlaying: isPlaying,
        currentTrackId: currentTrackId,
        songPath: song.path,
        playlists: playlists,
        preferenceLevel: preferenceLevel,
        onUndoPreference:
            preferenceLevel == null
                ? null
                : () {
                  unawaited(onUndoSongPreference(song));
                },
        onPlay: () {
          onPlaySongs([song.id]);
        },
        onTogglePlayPause: onTogglePlayPause,
        onPlayNext: () {
          onPlayNext(song);
        },
        nowPlayingSongIds: nowPlayingSongIds,
        onAddToNowPlaying: () async {
          await onAddSongsToNowPlaying([song.id]);
        },
        onCreatePlaylist: () {
          unawaited(onCreatePlaylist(song.title, [song.id]));
        },
        onAddToPlaylist: (playlistId) async {
          await onAddSongsToPlaylist(playlistId, [song.id]);
        },
        onRemove: () {},
        onSelect: () {
          selection.enterMultiSelect();
          final songKey = _songSelectionKey(song);
          selection.replaceSelection([
            for (final key in selection.selectedItems)
              if (!_isSearchSongSelectionKey(key)) key,
            songKey,
          ], selectionAnchor: songKey);
          onSelectionChanged();
        },
        onToggleFavorite: () async {
          await onToggleSongsFavorite([song.id], !song.favorite);
        },
        onSetPreference: (level) {
          unawaited(onSetSongPreference(song, level));
        },
        onDelete: () {
          onDeleteSong(song);
        },
        onSeeArtist: () {
          final artist = song_display.primaryDisplayArtist(
            song,
            context.smPlayerI18n,
          );
          onOpenArtist(artist);
        },
        onSeeAlbum: () {
          onOpenAlbum(song_display.displayAlbum(song, context.smPlayerI18n));
        },
        onSeeMusicInfo: () {
          onOpenMusicDialog(song, SongDialogMode.properties, queueSongIds);
        },
        onSeeLyrics: () {
          onOpenMusicDialog(song, SongDialogMode.lyrics, queueSongIds);
        },
        onSeeAlbumArt: () {
          onOpenMusicDialog(song, SongDialogMode.albumArt, queueSongIds);
        },
        onLocateLocal: () => locateSongInLocal(context, song.id),
        onSeeLocal: () => onRevealSong(song),
      ),
    );
  }
}
