import 'dart:math';
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/app_i18n.dart';
import '../../playback/media_control_model.dart' hide formatDuration;
import '../../playback/media_control_provider.dart';
import '../../playback/playlist_control_item.dart';
import '../data/library_models.dart';
import '../data/library_providers.dart';
import 'album_tile.dart' show getAlbumArtworkSong;
import 'artists_page_model.dart';
import 'command_bar.dart';
import 'headered_playlist_model.dart' show getNextPlaylistName;
import 'library_page_actions.dart';
import 'page_selection_store.dart';
import 'page_search_history_panel.dart';
import 'quick_jump_tooltip.dart';

class ArtistsPage extends ConsumerStatefulWidget {
  const ArtistsPage({super.key, this.searchQuery = '', this.targetArtistName});

  final String searchQuery;
  final String? targetArtistName;

  @override
  ConsumerState<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends ConsumerState<ArtistsPage> {
  var _artistSearch = '';
  var _artistSearchFocused = false;
  var _selectedArtistName = '';
  String? _appliedTargetArtistName;
  String? _notifiedMissingTargetArtistName;
  var _artistScrollTop = 0.0;
  final _selection = PageSelectionController<int>.stored('artists');
  final _artistListController = ScrollController();
  final _artistDetailController = ScrollController();

  @override
  void initState() {
    super.initState();
    _artistListController.addListener(_handleArtistListScroll);
  }

  @override
  void didUpdateWidget(ArtistsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetArtistName != widget.targetArtistName) {
      _appliedTargetArtistName = null;
      _notifiedMissingTargetArtistName = null;
      if (widget.targetArtistName == null) {
        _selectedArtistName = '';
      }
    }
  }

  @override
  void dispose() {
    _artistListController.removeListener(_handleArtistListScroll);
    _artistListController.dispose();
    _artistDetailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(musicLibrarySnapshotProvider);
    final mediaState = ref.watch(mediaControlControllerProvider).state;

    if (i18nValue.isLoading) {
      return const _ArtistsPagePanel(child: _ArtistsLoadingState());
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const _ArtistsPagePanel(child: _ArtistsLoadingState());
    }

    return snapshotValue.when(
      loading: () => const _ArtistsPagePanel(child: _ArtistsLoadingState()),
      error:
          (_, _) => _ArtistsPagePanel(
            child: _ArtistsEmptyState(
              title: i18n.t('collection.artistNotFound'),
              message: i18n.t('library.scanHelp'),
            ),
          ),
      data: (snapshot) {
        final artistGroups = buildArtistGroups(snapshot.songs, i18n);
        if (widget.targetArtistName != null) {
          final target = Uri.decodeComponent(widget.targetArtistName!);
          final targetIndex = artistGroups.indexWhere(
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
              ref
                  .read(libraryRepositoryProvider)
                  .addRecentSearch(target, SearchHistoryType.artists);
              ref.invalidate(musicLibrarySnapshotProvider);
              if (_artistListController.hasClients) {
                _artistListController.jumpTo(targetIndex * artistRowHeight);
              }
            });
          } else if (targetIndex < 0 &&
              _notifiedMissingTargetArtistName != target) {
            _notifiedMissingTargetArtistName = target;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(i18n.t('collection.artistNotFound'))),
              );
            });
          }
        }

        final visibleArtists = artistGroups;
        final targetArtistName =
            widget.targetArtistName == null
                ? null
                : Uri.decodeComponent(widget.targetArtistName!);
        final targetArtistAvailable =
            targetArtistName != null &&
            visibleArtists.any((artist) => artist.name == targetArtistName);
        if (!targetArtistAvailable &&
            !visibleArtists.any(
              (artist) => artist.name == _selectedArtistName,
            )) {
          _selection.cancel();
          _selectedArtistName =
              MediaQuery.sizeOf(context).width < 720 || visibleArtists.isEmpty
                  ? ''
                  : visibleArtists.first.name;
        }
        final artistSearchSuggestions =
            _artistSearch.trim().isEmpty
                ? const <String>[]
                : searchArtists(
                  artistGroups,
                  _artistSearch,
                ).take(8).map((artist) => artist.name).toList();
        final artistSearchHistoryEntries =
            snapshot.recentSearches
                .where((entry) => entry.type == SearchHistoryType.artists)
                .take(10)
                .toList();
        final matchingSelectedArtists =
            visibleArtists
                .where((artist) => artist.name == _selectedArtistName)
                .toList();
        final wideSelectedArtist =
            matchingSelectedArtists.isNotEmpty
                ? matchingSelectedArtists.first
                : (visibleArtists.isEmpty ? null : visibleArtists.first);
        final compactSelectedArtist =
            matchingSelectedArtists.isNotEmpty
                ? matchingSelectedArtists.first
                : null;
        final artistQuickJumpMap = buildArtistQuickJumpMap(visibleArtists);
        final activeArtistQuickJumpKey = _getActiveArtistQuickJumpKey(
          visibleArtists,
        );

        final selectedArtistForSelection =
            compactSelectedArtist ?? wideSelectedArtist;
        final selectedArtistSongIds =
            selectedArtistForSelection?.songs.map((song) => song.id).toList() ??
            const <int>[];
        final selectedVisibleSongIds =
            selectedArtistSongIds
                .where((songId) => _selection.selectedItems.contains(songId))
                .toList();
        final songsById = {for (final song in snapshot.songs) song.id: song};
        final customPlaylists =
            snapshot.playlists
                .where((playlist) => !playlist.isBuiltIn)
                .map(
                  (playlist) => MultiSelectCommandBarPlaylist(
                    id: playlist.id,
                    name: playlist.name,
                    songIds: playlist.songIds,
                  ),
                )
                .toList();

        if (visibleArtists.isEmpty) {
          return _ArtistsPagePanel(
            child: Column(
              children: [
                _ArtistsSearchBox(
                  artistSearch: _artistSearch,
                  i18n: i18n,
                  searchFocused: _artistSearchFocused,
                  searchSuggestions: artistSearchSuggestions,
                  searchHistoryEntries: artistSearchHistoryEntries,
                  onChanged: (value) {
                    setState(() {
                      _artistSearch = value;
                    });
                  },
                  onFocusChanged: _changeArtistSearchFocus,
                  onSubmitted: _submitArtistSearch,
                  onSelectSearchSuggestion: _selectArtistSearchQuery,
                  onRemoveRecentSearch: _removeArtistRecentSearch,
                  onClearRecentSearches: _clearArtistRecentSearches,
                ),
                Expanded(
                  child: _ArtistsEmptyState(
                    title:
                        _artistSearch.isEmpty
                            ? i18n.t('collection.noArtists')
                            : i18n.t('collection.noItemsMatch', {
                              'query': _artistSearch,
                            }),
                    message:
                        _artistSearch.isEmpty
                            ? i18n.t('artists.emptyCopy')
                            : i18n.t('library.tryAnotherSearch'),
                  ),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                return _ArtistsPagePanel(
                  child:
                      compact
                          ? _CompactArtistsPage(
                            artistSearch: _artistSearch,
                            selectedArtist: compactSelectedArtist,
                            visibleArtists: visibleArtists,
                            artistQuickJumpMap: artistQuickJumpMap,
                            activeArtistQuickJumpKey: activeArtistQuickJumpKey,
                            scrollController: _artistListController,
                            multiSelect: _selection.multiSelect,
                            selectedSongIds: _selection.selectedItems,
                            i18n: i18n,
                            searchFocused: _artistSearchFocused,
                            searchSuggestions: artistSearchSuggestions,
                            searchHistoryEntries: artistSearchHistoryEntries,
                            onSearchChanged: (value) {
                              setState(() {
                                _artistSearch = value;
                              });
                            },
                            onSearchFocusChanged: _changeArtistSearchFocus,
                            onSearchSubmitted: _submitArtistSearch,
                            onSelectSearchSuggestion: _selectArtistSearchQuery,
                            onRemoveRecentSearch: _removeArtistRecentSearch,
                            onClearRecentSearches: _clearArtistRecentSearches,
                            onOpenArtistDetail: _openArtistDetail,
                            onPlayArtist: (artist) {
                              _playShuffledSongIds(
                                artist.songs.map((song) => song.id).toList(),
                                artistName: artist.name,
                              );
                            },
                            onOpenArtistMenu: (position, artist) {
                              _showGroupContextMenu(
                                position: position,
                                type: _ArtistGroupMenuType.artist,
                                label: artist.name,
                                songs: artist.songs,
                              );
                            },
                            onOpenAlbumMenu: (position, album) {
                              _showGroupContextMenu(
                                position: position,
                                type: _ArtistGroupMenuType.album,
                                label: album.name,
                                songs: album.songs,
                              );
                            },
                            onJumpToArtistKey: _jumpToArtistKey,
                            onReturnToArtistList: () {
                              _returnToArtistList();
                            },
                            onPlaySongs: _playShuffledSongIds,
                            selectedTrackId: mediaState.track.id,
                            isPlaying: mediaState.isPlaying,
                            onPlayTrack: _playTrackInQueue,
                            onTogglePlayPause:
                                ref
                                    .read(mediaControlControllerProvider)
                                    .onTogglePlayPause,
                            onPlayNext: _playNext,
                            onToggleFavorite: (songId, favorite) {
                              setSongsFavorite(ref, [songId], favorite);
                            },
                            onOpenSongAddToMenu: (buttonContext, song) {
                              _showSongAddToMenu(buttonContext, song);
                            },
                            onToggleSongSelection: _toggleSongSelection,
                            onOpenSongContextMenu: (position, song) {
                              _showSongContextMenu(
                                position,
                                song,
                                selectedArtistSongIds,
                                customPlaylists,
                              );
                            },
                          )
                          : Row(
                            children: [
                              _ArtistsMaster(
                                artistSearch: _artistSearch,
                                visibleArtists: visibleArtists,
                                selectedArtistName:
                                    wideSelectedArtist?.name ?? '',
                                artistQuickJumpMap: artistQuickJumpMap,
                                activeArtistQuickJumpKey:
                                    activeArtistQuickJumpKey,
                                scrollController: _artistListController,
                                i18n: i18n,
                                searchFocused: _artistSearchFocused,
                                searchSuggestions: artistSearchSuggestions,
                                searchHistoryEntries:
                                    artistSearchHistoryEntries,
                                onSearchChanged: (value) {
                                  setState(() {
                                    _artistSearch = value;
                                  });
                                },
                                onSearchFocusChanged: _changeArtistSearchFocus,
                                onSearchSubmitted: _submitArtistSearch,
                                onSelectSearchSuggestion:
                                    _selectArtistSearchQuery,
                                onRemoveRecentSearch: _removeArtistRecentSearch,
                                onClearRecentSearches:
                                    _clearArtistRecentSearches,
                                onOpenArtistDetail: _openArtistDetail,
                                onPlayArtist: (artist) {
                                  _playShuffledSongIds(
                                    artist.songs
                                        .map((song) => song.id)
                                        .toList(),
                                    artistName: artist.name,
                                  );
                                },
                                onOpenArtistMenu: (position, artist) {
                                  _showGroupContextMenu(
                                    position: position,
                                    type: _ArtistGroupMenuType.artist,
                                    label: artist.name,
                                    songs: artist.songs,
                                  );
                                },
                                onJumpToArtistKey: _jumpToArtistKey,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _ArtistsDetail(
                                  selectedArtist: wideSelectedArtist,
                                  scrollController: _artistDetailController,
                                  multiSelect: _selection.multiSelect,
                                  selectedSongIds: _selection.selectedItems,
                                  i18n: i18n,
                                  onPlaySongs: _playShuffledSongIds,
                                  onOpenArtistMenu: (
                                    position,
                                    artist, {
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
                                  onOpenAlbumMenu: (position, album) {
                                    _showGroupContextMenu(
                                      position: position,
                                      type: _ArtistGroupMenuType.album,
                                      label: album.name,
                                      songs: album.songs,
                                    );
                                  },
                                  selectedTrackId: mediaState.track.id,
                                  isPlaying: mediaState.isPlaying,
                                  onPlayTrack: _playTrackInQueue,
                                  onTogglePlayPause:
                                      ref
                                          .read(mediaControlControllerProvider)
                                          .onTogglePlayPause,
                                  onPlayNext: _playNext,
                                  onToggleFavorite: (songId, favorite) {
                                    setSongsFavorite(ref, [songId], favorite);
                                  },
                                  onOpenSongAddToMenu: (buttonContext, song) {
                                    _showSongAddToMenu(buttonContext, song);
                                  },
                                  onToggleSongSelection: _toggleSongSelection,
                                  onOpenSongContextMenu: (position, song) {
                                    _showSongContextMenu(
                                      position,
                                      song,
                                      selectedArtistSongIds,
                                      customPlaylists,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                );
              },
            ),
            if (_selection.multiSelect)
              MultiSelectCommandBar(
                visible: _selection.multiSelect,
                selectedCount: selectedVisibleSongIds.length,
                playlists: customPlaylists,
                addToSongIds: selectedVisibleSongIds,
                includeNowPlayingInAddTo: true,
                includeFavoritesInAddTo: hasNotFavoriteSongs(
                  selectedVisibleSongIds,
                  songsById,
                ),
                onAddToNowPlaying:
                    selectedVisibleSongIds.isEmpty
                        ? null
                        : () {
                          addSongsToNowPlaying(ref, selectedVisibleSongIds);
                          setState(() {
                            _hideAfterOperation(
                              snapshot.hideMultiSelectCommandBarAfterOperation,
                            );
                          });
                        },
                onToggleFavorite:
                    selectedVisibleSongIds.isEmpty
                        ? null
                        : () {
                          setSongsFavorite(
                            ref,
                            notFavoriteSongIds(
                              selectedVisibleSongIds,
                              songsById,
                            ),
                            true,
                          );
                          setState(() {
                            _hideAfterOperation(
                              snapshot.hideMultiSelectCommandBarAfterOperation,
                            );
                          });
                        },
                onCreatePlaylist:
                    selectedVisibleSongIds.isEmpty
                        ? null
                        : () async {
                          await createPlaylistWithSongs(
                            context: context,
                            ref: ref,
                            i18n: i18n,
                            playlists: snapshot.playlists,
                            defaultName: getNextPlaylistName(
                              selectedArtistForSelection?.name ??
                                  i18n.t('common.artists'),
                              snapshot.playlists,
                            ),
                            songIds: selectedVisibleSongIds,
                          );
                          if (mounted) {
                            setState(() {
                              _hideAfterOperation(
                                snapshot
                                    .hideMultiSelectCommandBarAfterOperation,
                              );
                            });
                          }
                        },
                onPlay: () {
                  _playSongIds(selectedVisibleSongIds);
                  setState(() {
                    _hideAfterOperation(
                      snapshot.hideMultiSelectCommandBarAfterOperation,
                    );
                  });
                },
                onAddToPlaylist: (playlistId) {
                  addSongsToPlaylist(ref, playlistId, selectedVisibleSongIds);
                  setState(() {
                    _hideAfterOperation(
                      snapshot.hideMultiSelectCommandBarAfterOperation,
                    );
                  });
                },
                onSelectAll: () {
                  setState(() {
                    _selection.selectAll(selectedArtistSongIds);
                  });
                },
                onReverseSelection: () {
                  setState(() {
                    _selection.reverseSelection(selectedArtistSongIds);
                  });
                },
                onClearSelection: () {
                  setState(_selection.clearSelection);
                },
                onCancel: () {
                  setState(_selection.cancel);
                },
              ),
          ],
        );
      },
    );
  }

  void _openArtistDetail(String artistName) {
    setState(() {
      _selectedArtistName = artistName;
      _selection.cancel();
    });
    if (MediaQuery.sizeOf(context).width < 720) {
      context.go('/artists?artist=${Uri.encodeQueryComponent(artistName)}');
    }
    if (_artistDetailController.hasClients) {
      _artistDetailController.jumpTo(0);
    }
  }

  void _submitArtistSearch() {
    final query = _artistSearch.trim();
    if (query.isEmpty) {
      return;
    }

    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final i18n = ref.read(smPlayerI18nProvider).valueOrNull!;
    final artistGroups = buildArtistGroups(snapshot.songs, i18n);
    final suggestions = searchArtists(artistGroups, query);
    final exactMatches =
        artistGroups.where((artist) => artist.name == query).toList();
    final targetArtist =
        exactMatches.isNotEmpty
            ? exactMatches.first
            : (suggestions.isEmpty ? null : suggestions.first);
    if (targetArtist != null) {
      ref
          .read(libraryRepositoryProvider)
          .addRecentSearch(targetArtist.name, SearchHistoryType.artists);
      ref.invalidate(musicLibrarySnapshotProvider);
      setState(() {
        _artistSearch = targetArtist.name;
      });
      _openArtistDetail(targetArtist.name);
    } else {
      ref
          .read(libraryRepositoryProvider)
          .addRecentSearch(query, SearchHistoryType.artists);
      ref.invalidate(musicLibrarySnapshotProvider);
    }
  }

  void _selectArtistSearchQuery(String query) {
    setState(() {
      _artistSearch = query;
      _artistSearchFocused = false;
    });
    ref
        .read(libraryRepositoryProvider)
        .addRecentSearch(query, SearchHistoryType.artists);
    ref.invalidate(musicLibrarySnapshotProvider);
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final i18n = ref.read(smPlayerI18nProvider).valueOrNull!;
    final artistGroups = buildArtistGroups(snapshot.songs, i18n);
    final exactMatches =
        artistGroups.where((artist) => artist.name == query).toList();
    final suggestions = searchArtists(artistGroups, query);
    final targetArtist =
        exactMatches.isNotEmpty
            ? exactMatches.first
            : (suggestions.isEmpty ? null : suggestions.first);
    if (targetArtist != null) {
      _openArtistDetail(targetArtist.name);
    }
  }

  void _changeArtistSearchFocus(bool focused) {
    setState(() {
      _artistSearchFocused = focused;
    });
  }

  void _removeArtistRecentSearch(int entryId) {
    ref.read(libraryRepositoryProvider).removeRecentSearches([entryId]);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _clearArtistRecentSearches() {
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final entryIds =
        snapshot.recentSearches
            .where((entry) => entry.type == SearchHistoryType.artists)
            .map((entry) => entry.id)
            .toList();
    ref.read(libraryRepositoryProvider).removeRecentSearches(entryIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _returnToArtistList() {
    setState(() {
      _selectedArtistName = '';
      _selection.cancel();
    });
    context.go('/artists');
  }

  void _jumpToArtistKey(Map<String, int> artistQuickJumpMap, String key) {
    final targetIndex = artistQuickJumpMap[key];
    if (targetIndex == null) {
      return;
    }

    _artistListController.animateTo(
      targetIndex * artistRowHeight,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToArtist(String artistName) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final i18n = ref.read(smPlayerI18nProvider).valueOrNull!;
    final artistGroups = buildArtistGroups(snapshot.songs, i18n);
    final artistIndex = artistGroups.indexWhere(
      (artist) => artist.name == artistName,
    );
    if (artistIndex < 0 || !_artistListController.hasClients) {
      return;
    }

    _artistListController.animateTo(
      artistIndex * artistRowHeight,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleArtistListScroll() {
    final nextScrollTop = _artistListController.offset;
    if (nextScrollTop == _artistScrollTop) {
      return;
    }

    setState(() {
      _artistScrollTop = nextScrollTop;
    });
  }

  String _getActiveArtistQuickJumpKey(List<ArtistGroup> visibleArtists) {
    if (visibleArtists.isEmpty) {
      return '';
    }

    final activeIndex = min(
      visibleArtists.length - 1,
      max(0, (_artistScrollTop / artistRowHeight).floor()),
    );
    return getArtistQuickJumpBucket(visibleArtists[activeIndex].name);
  }

  void _toggleSongSelection(int songId) {
    setState(() {
      _selection.toggle(songId);
    });
  }

  void _playSongIds(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }

    final songs =
        ref.read(musicLibrarySnapshotProvider).value?.songs ?? const [];
    final songsById = {for (final song in songs) song.id: song};
    final firstSong = songsById[songIds.first]!;
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          MediaControlTrack(
            id: firstSong.id,
            title: firstSong.title,
            artist: firstSong.artist,
            artworkUrl: firstSong.thumbnailPath,
            isLoading: false,
            favorite: firstSong.favorite,
          ),
          durationSeconds: firstSong.duration.toDouble(),
          queueIndex: 0,
        );
    ref.read(libraryRepositoryProvider).replaceNowPlaying(songIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _playTrackInQueue(int songId, List<int> queueSongIds) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final song = songsById[songId]!;
    final queueIndex = queueSongIds.indexOf(songId);
    ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          MediaControlTrack(
            id: song.id,
            title: song.title,
            artist: song.artist,
            artworkUrl: song.thumbnailPath,
            isLoading: false,
            favorite: song.favorite,
          ),
          durationSeconds: song.duration.toDouble(),
          queueIndex: queueIndex,
        );
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _playNext(int songId) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final queueSongIds = snapshot.nowPlaying.songIds.toList();
    final selectedQueueIndex =
        ref.read(mediaControlControllerProvider).state.selectedQueueIndex;
    final insertIndex =
        selectedQueueIndex != null && selectedQueueIndex < queueSongIds.length
            ? selectedQueueIndex + 1
            : queueSongIds.length;
    queueSongIds.insert(insertIndex, songId);
    ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _playShuffledSongIds(
    List<int> songIds, {
    String? artistName,
    String? albumName,
  }) {
    if (artistName != null) {
      ref.read(libraryRepositoryProvider).recordArtistPlayed(artistName);
    }
    if (albumName != null) {
      ref.read(libraryRepositoryProvider).recordAlbumPlayed(albumName);
    }
    final queueSongIds = songIds.toList()..shuffle(Random());
    _playSongIds(queueSongIds);
  }

  void _hideAfterOperation(bool hideMultiSelectCommandBarAfterOperation) {
    _selection.hideAfterOperation(hideMultiSelectCommandBarAfterOperation);
  }

  void _showGroupContextMenu({
    required Offset position,
    required _ArtistGroupMenuType type,
    required String label,
    required List<LibrarySong> songs,
    bool showLocateArtist = false,
  }) {
    final i18n = context.smPlayerI18n;
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final songIds = songs.map((song) => song.id).toList();
    final customPlaylists =
        snapshot.playlists
            .where((playlist) => !playlist.isBuiltIn)
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
      includeNowPlaying: true,
      includeFavorites: notFavoriteIds.isNotEmpty,
      onAddToNowPlaying: () {
        addSongsToNowPlaying(ref, songIds);
      },
      onToggleFavorite:
          notFavoriteIds.isEmpty
              ? null
              : () {
                setSongsFavorite(ref, notFavoriteIds, true);
              },
      onCreatePlaylist: () async {
        await createPlaylistWithSongs(
          context: context,
          ref: ref,
          i18n: i18n,
          playlists: snapshot.playlists,
          defaultName: getNextPlaylistName(label, snapshot.playlists),
          songIds: songIds,
        );
      },
      onAddToPlaylist: (playlistId) {
        addSongsToPlaylist(ref, playlistId, songIds);
      },
    );

    showMenuFlyout(
      context,
      position: position,
      items: [
        MenuFlyoutItem(
          key: 'shuffle',
          text: i18n.t('nowPlaying.randomPlay'),
          icon: FluentIcons.arrow_shuffle_20_regular,
          onPressed: () {
            _playShuffledSongIds(
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
          icon: FluentIcons.select_all_on_20_regular,
          onPressed: () {
            setState(() {
              if (type == _ArtistGroupMenuType.artist) {
                _selection.enterMultiSelect();
                _selection.clearSelection();
              } else {
                _selection.selectAll(songIds);
              }
            });
          },
        ),
        _buildGroupPreferenceMenuItem(i18n, type, label),
        if (type == _ArtistGroupMenuType.artist && showLocateArtist)
          MenuFlyoutItem(
            key: 'locate-artist',
            text: i18n.t('artists.locateArtist'),
            icon: FluentIcons.music_note_2_20_regular,
            onPressed: () {
              _scrollToArtist(label);
            },
          ),
        if (type == _ArtistGroupMenuType.album)
          MenuFlyoutItem(
            key: 'see-album',
            text: i18n.t('context.seeAlbum'),
            icon: FluentIcons.album_20_regular,
            onPressed: () {
              context.go('/albums?album=${Uri.encodeQueryComponent(label)}');
            },
          ),
      ],
    );
  }

  MenuFlyoutItem _buildGroupPreferenceMenuItem(
    SmPlayerI18n i18n,
    _ArtistGroupMenuType type,
    String label,
  ) {
    final preferenceType =
        type == _ArtistGroupMenuType.artist ? 'artist' : 'album';
    return MenuFlyoutItem(
      key: 'preference',
      text: i18n.t('settings.preferenceSettings'),
      icon: FluentIcons.star_20_regular,
      submenu: [
        for (final level in const [
          'do-not-appear',
          'dislike',
          'normal',
          'high',
          'higher',
          'very-high',
        ])
          MenuFlyoutItem(
            key: 'preference-$level',
            text: i18n.t('preferences.level.$level'),
            onPressed: () async {
              await ref
                  .read(libraryRepositoryProvider)
                  .addPreferenceItem(preferenceType, label, label, level);
              ref.invalidate(musicLibrarySnapshotProvider);
            },
          ),
      ],
    );
  }

  void _showSongContextMenu(
    Offset position,
    LibrarySong song,
    List<int> queueSongIds,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) {
    final i18n = context.smPlayerI18n;
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final mediaState = ref.read(mediaControlControllerProvider).state;
    final currentTrackId = mediaState.track.id;
    showMenuFlyout(
      context,
      position: position,
      items: buildMusicMenuFlyoutItems(
        i18n: i18n,
        songId: song.id,
        isFavorite: song.favorite,
        isCurrentTrack: song.id == currentTrackId,
        isPlaying: mediaState.isPlaying,
        currentTrackId: currentTrackId,
        songPath: song.path,
        playlists: playlists,
        onPlay: () {
          _playSongIds(queueSongIds);
        },
        onPause: ref.read(mediaControlControllerProvider).onTogglePlayPause,
        onPlayNext: () {
          _playNext(song.id);
        },
        onAddToNowPlaying: () {
          addSongsToNowPlaying(ref, [song.id]);
        },
        onCreatePlaylist: () async {
          await createPlaylistWithSongs(
            context: context,
            ref: ref,
            i18n: i18n,
            playlists: snapshot.playlists,
            defaultName: getNextPlaylistName(song.title, snapshot.playlists),
            songIds: [song.id],
          );
        },
        onAddToPlaylist: (playlistId) {
          addSongsToPlaylist(ref, playlistId, [song.id]);
        },
        onRemove: () {},
        onSelect: () {
          setState(() {
            _selection.enterMultiSelect();
            if (!_selection.isSelected(song.id)) {
              _selection.toggle(song.id);
            }
          });
        },
        onToggleFavorite: () {
          setSongsFavorite(ref, [song.id], true);
        },
        onSetPreference: (level) async {
          await ref
              .read(libraryRepositoryProvider)
              .addPreferenceItem('song', '${song.id}', song.title, level);
          ref.invalidate(musicLibrarySnapshotProvider);
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
            '/albums?album=${Uri.encodeQueryComponent(displayAlbum(song, i18n))}',
          );
        },
        onSeeMusicInfo: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(i18n.t('context.seeMusicInfo'))),
          );
        },
        onSeeLyrics: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(i18n.t('context.seeLyrics'))));
        },
        onSeeAlbumArt: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(i18n.t('context.seeAlbumArt'))),
          );
        },
        onSeeLocal: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(song.path)));
        },
      ),
    );
  }

  void _showSongAddToMenu(BuildContext buttonContext, LibrarySong song) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final i18n = context.smPlayerI18n;
    final playlists =
        snapshot.playlists
            .where((playlist) => !playlist.isBuiltIn)
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
      includeNowPlaying: true,
      includeFavorites: !song.favorite,
      onAddToNowPlaying: () {
        addSongsToNowPlaying(ref, [song.id]);
      },
      onToggleFavorite:
          song.favorite
              ? null
              : () {
                setSongsFavorite(ref, [song.id], true);
              },
      onCreatePlaylist: () async {
        await createPlaylistWithSongs(
          context: context,
          ref: ref,
          i18n: i18n,
          playlists: snapshot.playlists,
          defaultName: getNextPlaylistName(song.title, snapshot.playlists),
          songIds: [song.id],
        );
      },
      onAddToPlaylist: (playlistId) {
        addSongsToPlaylist(ref, playlistId, [song.id]);
      },
    );
    if (addToItem == null) {
      return;
    }
    showMenuFlyout(buttonContext, items: addToItem.submenu);
  }
}

enum _ArtistGroupMenuType { artist, album }

class _CompactArtistsPage extends StatelessWidget {
  const _CompactArtistsPage({
    required this.artistSearch,
    required this.selectedArtist,
    required this.visibleArtists,
    required this.artistQuickJumpMap,
    required this.activeArtistQuickJumpKey,
    required this.scrollController,
    required this.multiSelect,
    required this.selectedSongIds,
    required this.i18n,
    required this.searchFocused,
    required this.searchSuggestions,
    required this.searchHistoryEntries,
    required this.onSearchChanged,
    required this.onSearchFocusChanged,
    required this.onSearchSubmitted,
    required this.onSelectSearchSuggestion,
    required this.onRemoveRecentSearch,
    required this.onClearRecentSearches,
    required this.onOpenArtistDetail,
    required this.onPlayArtist,
    required this.onOpenArtistMenu,
    required this.onOpenAlbumMenu,
    required this.onJumpToArtistKey,
    required this.onReturnToArtistList,
    required this.onPlaySongs,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onOpenSongAddToMenu,
    required this.onToggleSongSelection,
    required this.onOpenSongContextMenu,
  });

  final String artistSearch;
  final ArtistGroup? selectedArtist;
  final List<ArtistGroup> visibleArtists;
  final Map<String, int> artistQuickJumpMap;
  final String activeArtistQuickJumpKey;
  final ScrollController scrollController;
  final bool multiSelect;
  final Set<int> selectedSongIds;
  final SmPlayerI18n i18n;
  final bool searchFocused;
  final List<String> searchSuggestions;
  final List<SearchHistoryEntry> searchHistoryEntries;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onSearchFocusChanged;
  final VoidCallback onSearchSubmitted;
  final ValueChanged<String> onSelectSearchSuggestion;
  final ValueChanged<int> onRemoveRecentSearch;
  final VoidCallback onClearRecentSearches;
  final ValueChanged<String> onOpenArtistDetail;
  final ValueChanged<ArtistGroup> onPlayArtist;
  final void Function(Offset position, ArtistGroup artist) onOpenArtistMenu;
  final void Function(Offset position, AlbumGroup album) onOpenAlbumMenu;
  final void Function(Map<String, int> artistQuickJumpMap, String key)
  onJumpToArtistKey;
  final VoidCallback onReturnToArtistList;
  final void Function(
    List<int> songIds, {
    String? artistName,
    String? albumName,
  })
  onPlaySongs;
  final int? selectedTrackId;
  final bool isPlaying;
  final void Function(int songId, List<int> queueSongIds) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onPlayNext;
  final void Function(int songId, bool favorite) onToggleFavorite;
  final void Function(BuildContext context, LibrarySong song)
  onOpenSongAddToMenu;
  final ValueChanged<int> onToggleSongSelection;
  final void Function(Offset position, LibrarySong song) onOpenSongContextMenu;

  @override
  Widget build(BuildContext context) {
    if (selectedArtist != null) {
      return _ArtistsDetail(
        selectedArtist: selectedArtist,
        scrollController: ScrollController(),
        multiSelect: multiSelect,
        selectedSongIds: selectedSongIds,
        compact: true,
        i18n: i18n,
        onPlaySongs: onPlaySongs,
        onOpenArtistMenu: (position, artist, {required showLocateArtist}) {
          onOpenArtistMenu(position, artist);
        },
        onOpenAlbumMenu: (position, album) {
          onOpenAlbumMenu(position, album);
        },
        selectedTrackId: selectedTrackId,
        isPlaying: isPlaying,
        onPlayTrack: onPlayTrack,
        onTogglePlayPause: onTogglePlayPause,
        onPlayNext: onPlayNext,
        onToggleFavorite: onToggleFavorite,
        onOpenSongAddToMenu: onOpenSongAddToMenu,
        onToggleSongSelection: onToggleSongSelection,
        onOpenSongContextMenu: onOpenSongContextMenu,
        onReturnToArtistList: onReturnToArtistList,
      );
    }

    return Column(
      children: [
        _ArtistsSearchBox(
          artistSearch: artistSearch,
          i18n: i18n,
          searchFocused: searchFocused,
          searchSuggestions: searchSuggestions,
          searchHistoryEntries: searchHistoryEntries,
          onChanged: onSearchChanged,
          onFocusChanged: onSearchFocusChanged,
          onSubmitted: onSearchSubmitted,
          onSelectSearchSuggestion: onSelectSearchSuggestion,
          onRemoveRecentSearch: onRemoveRecentSearch,
          onClearRecentSearches: onClearRecentSearches,
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemExtent: artistRowHeight,
                  itemCount: visibleArtists.length,
                  itemBuilder: (context, index) {
                    final artist = visibleArtists[index];
                    return _ArtistListItem(
                      artist: artist,
                      active: false,
                      i18n: i18n,
                      onPressed: () {
                        onOpenArtistDetail(artist.name);
                      },
                      onPlay: () {
                        onPlayArtist(artist);
                      },
                      onOpenContextMenu: (position) {
                        onOpenArtistMenu(position, artist);
                      },
                    );
                  },
                ),
              ),
              _ArtistQuickJump(
                activeKey: activeArtistQuickJumpKey,
                enabledKeys: artistQuickJumpMap.keys.toSet(),
                i18n: i18n,
                onJump: (key) {
                  onJumpToArtistKey(artistQuickJumpMap, key);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArtistsMaster extends StatelessWidget {
  const _ArtistsMaster({
    required this.artistSearch,
    required this.visibleArtists,
    required this.selectedArtistName,
    required this.artistQuickJumpMap,
    required this.activeArtistQuickJumpKey,
    required this.scrollController,
    required this.i18n,
    required this.searchFocused,
    required this.searchSuggestions,
    required this.searchHistoryEntries,
    required this.onSearchChanged,
    required this.onSearchFocusChanged,
    required this.onSearchSubmitted,
    required this.onSelectSearchSuggestion,
    required this.onRemoveRecentSearch,
    required this.onClearRecentSearches,
    required this.onOpenArtistDetail,
    required this.onPlayArtist,
    required this.onOpenArtistMenu,
    required this.onJumpToArtistKey,
  });

  final String artistSearch;
  final List<ArtistGroup> visibleArtists;
  final String selectedArtistName;
  final Map<String, int> artistQuickJumpMap;
  final String activeArtistQuickJumpKey;
  final ScrollController scrollController;
  final SmPlayerI18n i18n;
  final bool searchFocused;
  final List<String> searchSuggestions;
  final List<SearchHistoryEntry> searchHistoryEntries;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onSearchFocusChanged;
  final VoidCallback onSearchSubmitted;
  final ValueChanged<String> onSelectSearchSuggestion;
  final ValueChanged<int> onRemoveRecentSearch;
  final VoidCallback onClearRecentSearches;
  final ValueChanged<String> onOpenArtistDetail;
  final ValueChanged<ArtistGroup> onPlayArtist;
  final void Function(Offset position, ArtistGroup artist) onOpenArtistMenu;
  final void Function(Map<String, int> artistQuickJumpMap, String key)
  onJumpToArtistKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: _ArtistsColors.panelBorder)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _ArtistsSearchBox(
                      artistSearch: artistSearch,
                      i18n: i18n,
                      searchFocused: searchFocused,
                      searchSuggestions: searchSuggestions,
                      searchHistoryEntries: searchHistoryEntries,
                      onChanged: onSearchChanged,
                      onFocusChanged: onSearchFocusChanged,
                      onSubmitted: onSearchSubmitted,
                      onSelectSearchSuggestion: onSelectSearchSuggestion,
                      onRemoveRecentSearch: onRemoveRecentSearch,
                      onClearRecentSearches: onClearRecentSearches,
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemExtent: artistRowHeight,
                        itemCount: visibleArtists.length,
                        itemBuilder: (context, index) {
                          final artist = visibleArtists[index];
                          return _ArtistListItem(
                            artist: artist,
                            active: artist.name == selectedArtistName,
                            i18n: i18n,
                            onPressed: () {
                              onOpenArtistDetail(artist.name);
                            },
                            onPlay: () {
                              onPlayArtist(artist);
                            },
                            onOpenContextMenu: (position) {
                              onOpenArtistMenu(position, artist);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _ArtistQuickJump(
                activeKey: activeArtistQuickJumpKey,
                enabledKeys: artistQuickJumpMap.keys.toSet(),
                i18n: i18n,
                onJump: (key) {
                  onJumpToArtistKey(artistQuickJumpMap, key);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistsSearchBox extends StatelessWidget {
  const _ArtistsSearchBox({
    required this.artistSearch,
    required this.i18n,
    required this.searchFocused,
    required this.searchSuggestions,
    required this.searchHistoryEntries,
    required this.onChanged,
    required this.onFocusChanged,
    required this.onSubmitted,
    required this.onSelectSearchSuggestion,
    required this.onRemoveRecentSearch,
    required this.onClearRecentSearches,
  });

  final String artistSearch;
  final SmPlayerI18n i18n;
  final bool searchFocused;
  final List<String> searchSuggestions;
  final List<SearchHistoryEntry> searchHistoryEntries;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onFocusChanged;
  final VoidCallback onSubmitted;
  final ValueChanged<String> onSelectSearchSuggestion;
  final ValueChanged<int> onRemoveRecentSearch;
  final VoidCallback onClearRecentSearches;

  @override
  Widget build(BuildContext context) {
    final showSuggestions = searchFocused && searchSuggestions.isNotEmpty;
    final showHistory =
        searchFocused &&
        artistSearch.trim().isEmpty &&
        searchHistoryEntries.isNotEmpty;
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: Focus(
            onFocusChange: onFocusChanged,
            child: TextField(
              controller: TextEditingController(text: artistSearch)
                ..selection = TextSelection.collapsed(
                  offset: artistSearch.length,
                ),
              onTap: () {
                onFocusChanged(true);
              },
              onChanged: onChanged,
              onSubmitted: (_) {
                onSubmitted();
              },
              decoration: InputDecoration(
                hintText: i18n.t('artists.searchArtistsPlaceholder'),
                prefixIcon: const Icon(FluentIcons.search_20_regular),
                suffixIcon:
                    artistSearch.isEmpty
                        ? null
                        : IconButton(
                          icon: const Icon(FluentIcons.dismiss_20_regular),
                          onPressed: () {
                            onChanged('');
                          },
                        ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: _ArtistsColors.searchSurface,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        if (showSuggestions || showHistory)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child:
                showSuggestions
                    ? PageSearchSuggestionPanel(
                      labels: searchSuggestions,
                      onSelect: onSelectSearchSuggestion,
                    )
                    : PageSearchHistoryPanel(
                      entries: searchHistoryEntries,
                      i18n: i18n,
                      onSelect: onSelectSearchSuggestion,
                      onRemove: onRemoveRecentSearch,
                      onClear: onClearRecentSearches,
                    ),
          ),
      ],
    );
  }
}

class _ArtistListItem extends StatelessWidget {
  const _ArtistListItem({
    required this.artist,
    required this.active,
    required this.i18n,
    required this.onPressed,
    required this.onPlay,
    required this.onOpenContextMenu,
  });

  final ArtistGroup artist;
  final bool active;
  final SmPlayerI18n i18n;
  final VoidCallback onPressed;
  final VoidCallback onPlay;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        onSecondaryTapDown: (details) {
          onOpenContextMenu(details.globalPosition);
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: active ? _ArtistsColors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                ArtistListArtwork(artist: artist, onPlay: onPlay),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ArtistsColors.textStrong,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _formatArtistSummary(
                          i18n,
                          artist.albumCount,
                          artist.songs.length,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ArtistsColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ArtistListArtwork extends StatefulWidget {
  const ArtistListArtwork({
    super.key,
    required this.artist,
    required this.onPlay,
  });

  final ArtistGroup artist;
  final VoidCallback onPlay;

  @override
  State<ArtistListArtwork> createState() => _ArtistListArtworkState();
}

class _ArtistListArtworkState extends State<ArtistListArtwork> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final song = widget.artist.songs.firstWhere(
      (song) => song.id == widget.artist.artworkSongId,
    );
    final file = song.thumbnailPath.isEmpty ? null : File(song.thumbnailPath);
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 48,
          child: Stack(
            fit: StackFit.expand,
            children: [
              file != null && file.existsSync()
                  ? Image.file(file, fit: BoxFit.cover)
                  : const DecoratedBox(
                    decoration: BoxDecoration(color: _ArtistsColors.artwork),
                    child: Icon(
                      FluentIcons.person_24_regular,
                      color: _ArtistsColors.artworkIcon,
                    ),
                  ),
              IgnorePointer(
                ignoring: !_hovered,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _hovered ? 1 : 0,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey(
                        'Artists.ArtworkPlay.${widget.artist.name}',
                      ),
                      onTap: widget.onPlay,
                      child: Center(
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _ArtistsColors.overlayPlay,
                          ),
                          child: const Icon(
                            FluentIcons.play_20_filled,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistsDetail extends StatelessWidget {
  const _ArtistsDetail({
    required this.selectedArtist,
    required this.scrollController,
    required this.multiSelect,
    required this.selectedSongIds,
    required this.i18n,
    required this.onPlaySongs,
    required this.onOpenArtistMenu,
    required this.onOpenAlbumMenu,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onOpenSongAddToMenu,
    required this.onToggleSongSelection,
    required this.onOpenSongContextMenu,
    this.compact = false,
    this.onReturnToArtistList,
  });

  final ArtistGroup? selectedArtist;
  final ScrollController scrollController;
  final bool multiSelect;
  final Set<int> selectedSongIds;
  final SmPlayerI18n i18n;
  final void Function(
    List<int> songIds, {
    String? artistName,
    String? albumName,
  })
  onPlaySongs;
  final void Function(
    Offset position,
    ArtistGroup artist, {
    required bool showLocateArtist,
  })
  onOpenArtistMenu;
  final void Function(Offset position, AlbumGroup album) onOpenAlbumMenu;
  final int? selectedTrackId;
  final bool isPlaying;
  final void Function(int songId, List<int> queueSongIds) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onPlayNext;
  final void Function(int songId, bool favorite) onToggleFavorite;
  final void Function(BuildContext context, LibrarySong song)
  onOpenSongAddToMenu;
  final ValueChanged<int> onToggleSongSelection;
  final void Function(Offset position, LibrarySong song) onOpenSongContextMenu;
  final bool compact;
  final VoidCallback? onReturnToArtistList;

  @override
  Widget build(BuildContext context) {
    final artist = selectedArtist;
    if (artist == null) {
      return _ArtistsEmptyState(
        title: i18n.t('artists.selectArtist'),
        message: '',
      );
    }

    final albums = buildAlbumGroups(artist.songs, i18n);
    return ColoredBox(
      color: _ArtistsColors.detailBackground,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: _ArtistDetailHeader(
              artist: artist,
              compact: compact,
              i18n: i18n,
              onReturnToArtistList: onReturnToArtistList,
              onPlaySongs: () {
                onPlaySongs(
                  artist.songs.map((song) => song.id).toList(),
                  artistName: artist.name,
                );
              },
              onOpenArtistMenu: (position) {
                onOpenArtistMenu(position, artist, showLocateArtist: true);
              },
            ),
          ),
          SliverList.builder(
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return _ArtistAlbumSection(
                album: album,
                multiSelect: multiSelect,
                selectedSongIds: selectedSongIds,
                i18n: i18n,
                queueSongIds: artist.songs.map((song) => song.id).toList(),
                selectedTrackId: selectedTrackId,
                isPlaying: isPlaying,
                onPlaySongs: () {
                  onPlaySongs(
                    album.songs.map((song) => song.id).toList(),
                    albumName: album.name,
                  );
                },
                onOpenAlbumMenu: (position) {
                  onOpenAlbumMenu(position, album);
                },
                onPlayTrack: onPlayTrack,
                onTogglePlayPause: onTogglePlayPause,
                onPlayNext: onPlayNext,
                onToggleFavorite: onToggleFavorite,
                onOpenSongAddToMenu: onOpenSongAddToMenu,
                onToggleSongSelection: onToggleSongSelection,
                onOpenSongContextMenu: onOpenSongContextMenu,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ArtistDetailHeader extends StatelessWidget {
  const _ArtistDetailHeader({
    required this.artist,
    required this.compact,
    required this.i18n,
    required this.onReturnToArtistList,
    required this.onPlaySongs,
    required this.onOpenArtistMenu,
  });

  final ArtistGroup artist;
  final bool compact;
  final SmPlayerI18n i18n;
  final VoidCallback? onReturnToArtistList;
  final VoidCallback onPlaySongs;
  final ValueChanged<Offset> onOpenArtistMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 28, 22, 28, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact)
            IconButton(
              tooltip: i18n.t('sidebar.back'),
              icon: const Icon(FluentIcons.arrow_left_24_regular),
              onPressed: onReturnToArtistList,
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ArtistsColors.textStrong,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatArtistSummary(
                        i18n,
                        artist.albumCount,
                        artist.songs.length,
                      ),
                      style: const TextStyle(
                        color: _ArtistsColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: i18n.t('nowPlaying.randomPlay'),
                icon: const Icon(FluentIcons.arrow_shuffle_24_regular),
                onPressed: onPlaySongs,
              ),
              Builder(
                builder: (buttonContext) {
                  return IconButton(
                    tooltip: i18n.t('player.more'),
                    icon: const Icon(FluentIcons.more_horizontal_24_regular),
                    onPressed: () {
                      final button =
                          buttonContext.findRenderObject()! as RenderBox;
                      onOpenArtistMenu(
                        button.localToGlobal(Offset(0, button.size.height + 4)),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArtistAlbumSection extends StatelessWidget {
  const _ArtistAlbumSection({
    required this.album,
    required this.multiSelect,
    required this.selectedSongIds,
    required this.i18n,
    required this.queueSongIds,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.onPlaySongs,
    required this.onOpenAlbumMenu,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onOpenSongAddToMenu,
    required this.onToggleSongSelection,
    required this.onOpenSongContextMenu,
  });

  final AlbumGroup album;
  final bool multiSelect;
  final Set<int> selectedSongIds;
  final SmPlayerI18n i18n;
  final List<int> queueSongIds;
  final int? selectedTrackId;
  final bool isPlaying;
  final VoidCallback onPlaySongs;
  final ValueChanged<Offset> onOpenAlbumMenu;
  final void Function(int songId, List<int> queueSongIds) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onPlayNext;
  final void Function(int songId, bool favorite) onToggleFavorite;
  final void Function(BuildContext context, LibrarySong song)
  onOpenSongAddToMenu;
  final ValueChanged<int> onToggleSongSelection;
  final void Function(Offset position, LibrarySong song) onOpenSongContextMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _ArtistsColors.albumSection,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _ArtistsColors.panelBorder),
          boxShadow: const [
            BoxShadow(
              color: _ArtistsColors.albumShadow,
              offset: Offset(0, 16),
              blurRadius: 38,
            ),
          ],
        ),
        child: Column(
          children: [
            _ArtistAlbumHeader(
              album: album,
              i18n: i18n,
              onPlaySongs: onPlaySongs,
              onOpenAlbumMenu: onOpenAlbumMenu,
            ),
            ...album.songs.map(
              (song) => PlaylistControlItem(
                key: ValueKey('artist-song-${song.id}'),
                song: song,
                current: song.id == selectedTrackId,
                playing: song.id == selectedTrackId && isPlaying,
                selected: selectedSongIds.contains(song.id),
                selectionMode: multiSelect,
                showAlbum: false,
                playNextLabel: i18n.t('context.playNext'),
                addToPlaylistLabel: i18n.t('context.addToPlaylist'),
                favoriteLabel: i18n.t('common.favorite'),
                moreLabel: i18n.t('player.more'),
                onPlayTrack: () {
                  onPlayTrack(song.id, queueSongIds);
                },
                onTogglePlayPause: onTogglePlayPause,
                onToggleSelection: () {
                  onToggleSongSelection(song.id);
                },
                onToggleFavoriteClick: () {
                  onToggleFavorite(song.id, !song.favorite);
                },
                onAddToPlaylistClick: (buttonContext) {
                  onOpenSongAddToMenu(buttonContext, song);
                },
                onPlayNextClick: () {
                  onPlayNext(song.id);
                },
                onOpenContextMenu: (position) {
                  onOpenSongContextMenu(position, song);
                },
                onSeeAlbum: () {
                  context.go(
                    '/albums?album=${Uri.encodeQueryComponent(displayAlbum(song, i18n))}',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistAlbumHeader extends StatelessWidget {
  const _ArtistAlbumHeader({
    required this.album,
    required this.i18n,
    required this.onPlaySongs,
    required this.onOpenAlbumMenu,
  });

  final AlbumGroup album;
  final SmPlayerI18n i18n;
  final VoidCallback onPlaySongs;
  final ValueChanged<Offset> onOpenAlbumMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AlbumArtwork(album: album),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    context.go(
                      '/albums?album=${Uri.encodeQueryComponent(album.name)}',
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      album.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ArtistsColors.textStrong,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  i18n.t('artists.albumSummary', {
                    'songs': album.songs.length,
                    'duration': formatDuration(album.duration),
                  }),
                  style: const TextStyle(
                    color: _ArtistsColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: i18n.t('nowPlaying.randomPlay'),
            icon: const Icon(FluentIcons.arrow_shuffle_24_regular),
            onPressed: onPlaySongs,
          ),
          Builder(
            builder: (buttonContext) {
              return IconButton(
                tooltip: i18n.t('player.more'),
                icon: const Icon(FluentIcons.more_horizontal_24_regular),
                onPressed: () {
                  final button = buttonContext.findRenderObject()! as RenderBox;
                  onOpenAlbumMenu(
                    button.localToGlobal(Offset(0, button.size.height + 4)),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class AlbumArtwork extends StatelessWidget {
  const AlbumArtwork({super.key, required this.album});

  final AlbumGroup album;

  @override
  Widget build(BuildContext context) {
    final firstSong = getAlbumArtworkSong(album.songs);
    final file =
        firstSong.thumbnailPath.isEmpty ? null : File(firstSong.thumbnailPath);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: 72,
        child:
            file != null && file.existsSync()
                ? Image.file(file, fit: BoxFit.cover)
                : const DecoratedBox(
                  decoration: BoxDecoration(color: _ArtistsColors.artwork),
                  child: Icon(
                    FluentIcons.album_24_regular,
                    color: _ArtistsColors.artworkIcon,
                  ),
                ),
      ),
    );
  }
}

class _ArtistQuickJump extends StatelessWidget {
  const _ArtistQuickJump({
    required this.activeKey,
    required this.enabledKeys,
    required this.i18n,
    required this.onJump,
  });

  final String activeKey;
  final Set<String> enabledKeys;
  final SmPlayerI18n i18n;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      child: Column(
        children:
            artistQuickJumpKeys.map((key) {
              final enabled = enabledKeys.contains(key);
              final active = activeKey == key;
              return Expanded(
                child: Tooltip(
                  message: getQuickJumpTooltip(
                    key: key,
                    enabled: enabled,
                    targetName: i18n.t('common.artists'),
                    basisName: i18n.t('common.artist'),
                    i18n: i18n,
                  ),
                  child: TextButton(
                    key: ValueKey('Artists.QuickJump.$key'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor:
                          enabled
                              ? active
                                  ? _ArtistsColors.accentStrong
                                  : _ArtistsColors.textMuted
                              : _ArtistsColors.disabled,
                      backgroundColor:
                          active
                              ? _ArtistsColors.accentSoft
                              : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed:
                        enabled
                            ? () {
                              onJump(key);
                            }
                            : null,
                    child: Text(
                      key,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _ArtistsPagePanel extends StatelessWidget {
  const _ArtistsPagePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: SizedBox.expand(child: child),
    );
  }
}

class _ArtistsLoadingState extends StatelessWidget {
  const _ArtistsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
  }
}

class _ArtistsEmptyState extends StatelessWidget {
  const _ArtistsEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message.isEmpty ? title : '$title\n$message',
        textAlign: TextAlign.center,
        style: const TextStyle(color: _ArtistsColors.textMuted, height: 1.5),
      ),
    );
  }
}

String _formatArtistSummary(SmPlayerI18n i18n, int albums, int songs) {
  return i18n.t('artists.artistSummary', {'albums': albums, 'songs': songs});
}

class _ArtistsColors {
  const _ArtistsColors._();

  static const detailBackground = Color(0xfff8fbfe);
  static const albumSection = Color(0xa3ffffff);
  static const albumShadow = Color(0x14685870);
  static const panelBorder = Color(0x2e7e8b9a);
  static const searchSurface = Color(0x0f0d1826);
  static const accentStrong = Color(0xff0063b1);
  static const accentSoft = Color(0x1a0078d7);
  static const overlayPlay = Color(0xb81e2228);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const disabled = Color(0x3d5b697a);
  static const artwork = Color(0xffe8eef5);
  static const artworkIcon = Color(0xff607085);
}
