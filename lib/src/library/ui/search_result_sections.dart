part of 'search_page.dart';

class _SearchSectionData {
  const _SearchSectionData.cards({
    required this.type,
    required this.criterion,
    required this.cards,
    required this.previewLimit,
  }) : songs = const [];

  const _SearchSectionData.songs({
    required this.criterion,
    required this.songs,
    required this.previewLimit,
  }) : type = SearchResultType.songs,
       cards = const [];

  final SearchResultType type;
  final SearchSortCriterion criterion;
  final List<SearchResult> cards;
  final List<LibrarySong> songs;
  final int previewLimit;

  int get count => type == SearchResultType.songs ? songs.length : cards.length;

  List<String> visibleKeys({bool preview = false}) {
    final itemCount = (preview ? count.clamp(0, previewLimit) : count).toInt();
    return type == SearchResultType.songs
        ? [for (final song in songs.take(itemCount)) _songSelectionKey(song)]
        : [
          for (final card in cards.take(itemCount))
            getSearchResultCardKey(type, card),
        ];
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
    required this.i18n,
    required this.activeFilter,
    required this.showCount,
    required this.mediaControlState,
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
    required this.onPreviewAlbumArt,
    required this.onSearchDirectory,
    required this.onRevealCard,
    required this.onRevealSong,
  });

  final _SearchSectionData section;
  final SmPlayerI18n i18n;
  final SearchFilterKey activeFilter;
  final bool showCount;
  final MediaControlState mediaControlState;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
        if (section.type == SearchResultType.songs)
          _buildSongs(context, visibleCount)
        else
          _buildCards(context, visibleCount),
      ],
    );
  }

  String _sectionTitle(SearchResultType type, int count) {
    if (!showCount) {
      return switch (type) {
        SearchResultType.artists => i18n.t('common.artists'),
        SearchResultType.albums => i18n.t('common.albums'),
        SearchResultType.songs => i18n.t('common.songs'),
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
      SearchResultType.playlists => i18n.t('search.playlistsWithCount', {
        'count': count,
      }),
      SearchResultType.folders => i18n.t('search.foldersWithCount', {
        'count': count,
      }),
    };
  }

  Widget _buildSongs(BuildContext context, int visibleCount) {
    final songs = section.songs.take(visibleCount).toList();
    return Column(
      children: [
        for (var index = 0; index < songs.length; index += 1)
          PlaylistControlItem(
            key: ValueKey('search-song-${songs[index].id}'),
            song: songs[index],
            current: songs[index].id == mediaControlState.track.id,
            playing:
                songs[index].id == mediaControlState.track.id &&
                mediaControlState.isPlaying,
            selected: selection.isSelected(_songSelectionKey(songs[index])),
            selectionMode: selection.multiSelect,
            playNextLabel: i18n.t('context.playNext'),
            removeLabel: i18n.t('nowPlaying.remove'),
            onPlayTrack: () {
              onPlayTrack(songs[index], index);
            },
            onTogglePlayPause: onTogglePlayPause,
            onToggleSelection: () {
              selection.toggle(_songSelectionKey(songs[index]));
              onSelectionChanged();
            },
            onPlayNextClick: () {
              onPlayNext(songs[index]);
            },
            onRemoveFromListClick: () {},
            onOpenContextMenu: (position) {
              _showSongContextMenu(
                context,
                position,
                songs[index],
                songs.map((song) => song.id).toList(),
              );
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
                _showCardContextMenu(context, position, card);
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
                    _showCardContextMenu(context, position, card);
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
                  _showCardContextMenu(context, position, card);
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
    final mediaState = mediaControlState;
    final preferenceLevel = await onGetSongPreferenceLevel(song);
    if (!context.mounted) {
      return;
    }
    showMenuFlyout(
      context,
      position: position,
      items: buildMusicMenuFlyoutItems(
        i18n: i18n,
        songId: song.id,
        isFavorite: song.favorite,
        isCurrentTrack: song.id == mediaState.track.id,
        isPlaying: mediaState.isPlaying,
        currentTrackId: mediaState.track.id,
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
        onPause: onTogglePlayPause,
        onPlayNext: () {
          onPlayNext(song);
        },
        nowPlayingSongIds: nowPlayingSongIds,
        onAddToNowPlaying: () {
          unawaited(onAddSongsToNowPlaying([song.id]));
        },
        onCreatePlaylist: () {
          unawaited(onCreatePlaylist(song.title, [song.id]));
        },
        onAddToPlaylist: (playlistId) {
          unawaited(onAddSongsToPlaylist(playlistId, [song.id]));
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
        onToggleFavorite: () {
          unawaited(onToggleSongsFavorite([song.id], !song.favorite));
        },
        onSetPreference: (level) {
          unawaited(onSetSongPreference(song, level));
        },
        onDelete: () {
          onDeleteSong(song);
        },
        onHide: () {},
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
        onSeeLocal: () => onRevealSong(song),
      ),
    );
  }

  Future<void> _showCardContextMenu(
    BuildContext context,
    Offset position,
    SearchResult card,
  ) async {
    final cardKey = getSearchResultCardKey(section.type, card);
    final preferenceLevel = await onGetPreferenceLevel(section.type, card);
    if (!context.mounted) {
      return;
    }
    final favoriteSongIds = [
      for (final songId in card.songIds)
        if (songsById[songId]?.favorite != true) songId,
    ];
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: card.songIds,
      playlists: playlists,
      includeNowPlaying: shouldShowNowPlayingAddToTarget(
        songIds: card.songIds,
        nowPlayingSongIds: nowPlayingSongIds,
        isNowPlayingContext: false,
      ),
      includeFavorites: favoriteSongIds.isNotEmpty,
      onAddToNowPlaying: () {
        onAddSongsToNowPlaying(card.songIds);
      },
      onToggleFavorite: () {
        onToggleSongsFavorite(favoriteSongIds, true);
      },
      onCreatePlaylist: () {
        onCreatePlaylist(card.title, card.songIds);
      },
      onAddToPlaylist: (playlistId) {
        onAddCardSongsToPlaylist(playlistId, card.songIds);
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
            onPlayCard(card);
          },
        ),
        if (addToItem != null) addToItem,
        MenuFlyoutItem(
          key: 'select',
          text: i18n.t('context.select'),
          icon: FluentIcons.multiselect_ltr_20_regular,
          onPressed: () {
            selection.enterMultiSelect();
            selection.replaceSelection([
              for (final key in selection.selectedItems)
                if (_isSearchSongSelectionKey(key)) key,
              cardKey,
            ], selectionAnchor: cardKey);
            onSelectionChanged();
          },
        ),
        if (_searchResultPreferenceType(section.type) != null)
          _buildSearchResultPreferenceMenuItem(card, preferenceLevel),
        if (section.type == SearchResultType.albums)
          MenuFlyoutItem(
            key: 'see-album-art',
            text: i18n.t('context.seeAlbumArt'),
            icon: FluentIcons.image_20_regular,
            onPressed: () {
              onPreviewAlbumArt(card);
            },
          ),
        if (section.type == SearchResultType.folders) ...[
          MenuFlyoutItem(
            key: 'show-in-explorer',
            text: i18n.t('context.reveal'),
            pendingText: i18n.t('context.openingLocal'),
            icon: FluentIcons.folder_open_20_regular,
            onPressed: () => onRevealCard(card),
          ),
          MenuFlyoutItem(
            key: 'search-directory',
            text: i18n.t('local.searchDirectory'),
            icon: FluentIcons.search_20_regular,
            onPressed: () {
              onSearchDirectory(card);
            },
          ),
        ],
      ],
    );
  }

  void _showCardAddToMenu(
    BuildContext context,
    Offset position,
    SearchResult card,
  ) {
    final favoriteSongIds = [
      for (final songId in card.songIds)
        if (songsById[songId]?.favorite != true) songId,
    ];
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: card.songIds,
      playlists: playlists,
      includeNowPlaying: shouldShowNowPlayingAddToTarget(
        songIds: card.songIds,
        nowPlayingSongIds: nowPlayingSongIds,
        isNowPlayingContext: false,
      ),
      includeFavorites: favoriteSongIds.isNotEmpty,
      onAddToNowPlaying: () {
        onAddSongsToNowPlaying(card.songIds);
      },
      onToggleFavorite: () {
        onToggleSongsFavorite(favoriteSongIds, true);
      },
      onCreatePlaylist: () {
        onCreatePlaylist(card.title, card.songIds);
      },
      onAddToPlaylist: (playlistId) {
        onAddSongsToPlaylist(playlistId, card.songIds);
      },
    );
    if (addToItem == null) {
      return;
    }

    showMenuFlyout(context, position: position, items: addToItem.submenu);
  }

  MenuFlyoutItem _buildSearchResultPreferenceMenuItem(
    SearchResult card,
    String? preferenceLevel,
  ) {
    return buildPreferenceMenuFlyoutItem(
      i18n: i18n,
      key: 'preference',
      preferenceLevel: preferenceLevel,
      onUndoPreference:
          preferenceLevel == null
              ? null
              : () {
                onUndoPreference(section.type, card);
              },
      onSetPreference: (level) {
        onSetPreference(section.type, card, level);
      },
    );
  }
}

class _SearchSectionActionButton extends StatelessWidget {
  const _SearchSectionActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SmPlayerTextIconButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
    );
  }
}

String? _searchResultPreferenceType(SearchResultType type) {
  return switch (type) {
    SearchResultType.artists => 'artist',
    SearchResultType.albums => 'album',
    SearchResultType.playlists => 'playlist',
    SearchResultType.folders => 'folder',
    SearchResultType.songs => null,
  };
}

String _searchResultPreferenceId(String preferenceType, SearchResult card) {
  return preferenceType == 'folder' || preferenceType == 'playlist'
      ? card.sourceId!
      : card.title;
}

SearchFilterKey _filterForSection(SearchResultType type) {
  return switch (type) {
    SearchResultType.artists => SearchFilterKey.artists,
    SearchResultType.albums => SearchFilterKey.albums,
    SearchResultType.songs => SearchFilterKey.songs,
    SearchResultType.playlists => SearchFilterKey.playlists,
    SearchResultType.folders => SearchFilterKey.folders,
  };
}

String _songSelectionKey(LibrarySong song) {
  return 'songs:${song.id}';
}

bool _isSearchSongSelectionKey(String key) {
  return key.startsWith('songs:');
}
