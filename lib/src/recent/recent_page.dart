import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';

import 'recent_page_model.dart';
import 'recent_search_list.dart';

enum RecentTab { added, played, searches }

enum RecentPlayedFilter { songs, artists, albums, playlists }

class RecentPage extends ConsumerStatefulWidget {
  const RecentPage({super.key});

  @override
  ConsumerState<RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends ConsumerState<RecentPage> {
  static const recentAddedLimit = 500;

  var _activeTab = RecentTab.added;
  var _activePlayedFilter = RecentPlayedFilter.songs;
  var _multiSelect = false;
  final _selectedSongIds = <int>{};
  final _selectedCollectionKeys = <String>{};
  final _selectedSearchIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final i18nValue = ref.watch(smPlayerI18nProvider);
    final snapshotValue = ref.watch(musicLibrarySnapshotProvider);
    final mediaControlState = ref.watch(mediaControlControllerProvider).state;

    if (i18nValue.isLoading) {
      return const _RecentPagePanel(child: _RecentLoadingState());
    }

    final i18n = i18nValue.valueOrNull;
    if (i18n == null) {
      return const _RecentPagePanel(
        child: _RecentEmptyState(title: 'Recent failed to load', message: ''),
      );
    }

    return snapshotValue.when(
      loading: () => const _RecentPagePanel(child: _RecentLoadingState()),
      error:
          (_, _) => _RecentPagePanel(
            child: _RecentEmptyState(
              title: i18n.t('recent.empty'),
              message: '',
            ),
          ),
      data: (snapshot) {
        final recentAddedSongs =
            snapshot.songs.toList()..sort(
              (left, right) =>
                  dateValue(right.dateAdded) - dateValue(left.dateAdded),
            );
        final addedSongs = recentAddedSongs.take(recentAddedLimit).toList();
        final recentPlaylistViews = buildRecentPlaylistViews(
          snapshot.playlists,
          snapshot.songs,
          snapshot.recentPlaylists,
        );
        final recentAlbumViews = buildRecentAlbumViews(
          snapshot.songs,
          snapshot.recentAlbums,
        );
        final recentArtistViews = buildRecentArtistViews(
          snapshot.songs,
          snapshot.recentArtists,
        );
        final recentPlayedCount =
            snapshot.recentSongs.length +
            snapshot.recentPlaylists.length +
            snapshot.recentAlbums.length +
            snapshot.recentArtists.length;
        final visibleSongs =
            _activeTab == RecentTab.added
                ? addedSongs
                : _activeTab == RecentTab.played &&
                    _activePlayedFilter == RecentPlayedFilter.songs
                ? snapshot.recentSongs
                : const <LibrarySong>[];
        final selectedVisibleSongIds =
            visibleSongs
                .where((song) => _selectedSongIds.contains(song.id))
                .map((song) => song.id)
                .toList();
        final selectedSearchIds =
            snapshot.recentSearches
                .where((entry) => _selectedSearchIds.contains(entry.id))
                .map((entry) => entry.id)
                .toList();
        final selectedCount =
            _activeTab == RecentTab.searches
                ? selectedSearchIds.length
                : _activePlayedFilter == RecentPlayedFilter.songs
                ? selectedVisibleSongIds.length
                : _selectedCollectionKeys.length;
        final selectedOperationSongIds =
            _activeTab == RecentTab.played &&
                    _activePlayedFilter != RecentPlayedFilter.songs
                ? _selectedCollectionSongIds(
                  recentPlaylistViews,
                  recentAlbumViews,
                  recentArtistViews,
                )
                : selectedVisibleSongIds;
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

        return _RecentPagePanel(
          child: Column(
            children: [
              _RecentTabs(
                i18n: i18n,
                activeTab: _activeTab,
                addedCount: addedSongs.length,
                playedCount: recentPlayedCount,
                searchesCount: snapshot.recentSearches.length,
                showCount: snapshot.showCount,
                onChanged: (tab) {
                  setState(() {
                    _activeTab = tab;
                    _clearSelection();
                  });
                },
              ),
              if (_activeTab == RecentTab.played)
                _RecentPlayedFilterBar(
                  i18n: i18n,
                  activeFilter: _activePlayedFilter,
                  onChanged: (filter) {
                    setState(() {
                      _activePlayedFilter = filter;
                      _clearSelection();
                    });
                  },
                ),
              CommandBar(
                children: [
                  CommandBarButton(
                    icon: FluentIcons.select_all_on_20_regular,
                    label: i18n.t('albums.multiSelect'),
                    active: _multiSelect,
                    disabled:
                        !_canSelectVisibleItems(
                          snapshot,
                          visibleSongs,
                          recentPlaylistViews,
                          recentAlbumViews,
                          recentArtistViews,
                        ),
                    onPressed: () {
                      setState(() {
                        _multiSelect = !_multiSelect;
                        _clearSelection();
                      });
                    },
                  ),
                  CommandBarButton(
                    icon: FluentIcons.dismiss_20_regular,
                    label: i18n.t('recent.clearHistory'),
                    disabled:
                        _activeTab == RecentTab.played
                            ? recentPlayedCount == 0
                            : _activeTab != RecentTab.searches ||
                                snapshot.recentSearches.isEmpty,
                    onPressed: _clearHistory,
                  ),
                ],
              ),
              Expanded(
                child:
                    _activeTab == RecentTab.searches
                        ? RecentSearchList(
                          entries: snapshot.recentSearches,
                          multiSelect: _multiSelect,
                          selectedEntryIds: _selectedSearchIds,
                          onSearch: (entry) {
                            context.go(
                              '/search?query=${Uri.encodeQueryComponent(entry.query)}',
                            );
                          },
                          onToggleSelection: _toggleSearchSelection,
                          onRemove: (entryId) {
                            ref
                                .read(libraryRepositoryProvider)
                                .removeRecentSearches([entryId]);
                            ref.invalidate(musicLibrarySnapshotProvider);
                          },
                          onOpenContextMenu: (position, entry) {
                            _showSearchContextMenu(position, entry);
                          },
                        )
                        : _activeTab == RecentTab.played
                        ? _RecentPlayedPanel(
                          filter: _activePlayedFilter,
                          songs: snapshot.recentSongs,
                          playlists: recentPlaylistViews,
                          albums: recentAlbumViews,
                          artists: recentArtistViews,
                          multiSelect: _multiSelect,
                          selectedSongIds: _selectedSongIds,
                          selectedCollectionKeys: _selectedCollectionKeys,
                          mediaControlState: mediaControlState,
                          onPlaySongs: _playSongIds,
                          onPlaySong: _playSong,
                          onToggleSongSelection: _toggleSongSelection,
                          onToggleCollectionSelection:
                              _toggleCollectionSelection,
                          onOpenAlbum: (albumName) {
                            context.go(
                              '/albums?album=${Uri.encodeQueryComponent(albumName)}',
                            );
                          },
                          onOpenArtist: (artistName) {
                            context.go(
                              '/artists?artist=${Uri.encodeQueryComponent(artistName)}',
                            );
                          },
                          onOpenPlaylist: (playlistId) {
                            context.go('/playlists/$playlistId');
                          },
                          onOpenSongContextMenu: (
                            position,
                            song,
                            queueSongIds,
                          ) {
                            _showSongContextMenu(
                              position,
                              song,
                              queueSongIds,
                              customPlaylists,
                            );
                          },
                          onOpenCollectionContextMenu: (
                            position,
                            key,
                            title,
                            songIds,
                          ) {
                            _showCollectionContextMenu(
                              position,
                              key,
                              title,
                              songIds,
                              customPlaylists,
                            );
                          },
                        )
                        : _RecentSongGrid(
                          songs: addedSongs,
                          queueSongIds:
                              addedSongs.map((song) => song.id).toList(),
                          selectedSongIds: _selectedSongIds,
                          multiSelect: _multiSelect,
                          mediaControlState: mediaControlState,
                          getTimelineDate: (song) => song.dateAdded,
                          getDetailLabel:
                              (song) => formatRecentDateTime(song.dateAdded),
                          onPlaySong: _playSong,
                          onToggleSelection: _toggleSongSelection,
                          onOpenContextMenu: (position, song, queueSongIds) {
                            _showSongContextMenu(
                              position,
                              song,
                              queueSongIds,
                              customPlaylists,
                            );
                          },
                        ),
              ),
              if (_multiSelect)
                MultiSelectCommandBar(
                  visible: _multiSelect,
                  selectedCount: selectedCount,
                  playlists: customPlaylists,
                  showAddTo: _activeTab != RecentTab.searches,
                  removeLabel: i18n.t('context.removeFromList'),
                  onPlay: () {
                    if (_activeTab == RecentTab.searches) {
                      return;
                    }
                    _playSongIds(selectedOperationSongIds);
                    setState(() {
                      _hideAfterOperation(
                        snapshot.hideMultiSelectCommandBarAfterOperation,
                      );
                    });
                  },
                  onAddToPlaylist: (_) {
                    _showMessage(i18n.t('context.addToPlaylist'));
                    setState(() {
                      _hideAfterOperation(
                        snapshot.hideMultiSelectCommandBarAfterOperation,
                      );
                    });
                  },
                  onRemove: () {
                    if (_activeTab == RecentTab.searches) {
                      ref
                          .read(libraryRepositoryProvider)
                          .removeRecentSearches(selectedSearchIds);
                    } else if (_activeTab == RecentTab.played &&
                        _activePlayedFilter == RecentPlayedFilter.songs) {
                      ref
                          .read(libraryRepositoryProvider)
                          .removeRecentPlayed(selectedVisibleSongIds);
                    }
                    ref.invalidate(musicLibrarySnapshotProvider);
                    setState(() {
                      _hideAfterOperation(
                        snapshot.hideMultiSelectCommandBarAfterOperation,
                      );
                    });
                  },
                  onSelectAll: () {
                    setState(() {
                      _selectAll(
                        snapshot,
                        visibleSongs,
                        recentPlaylistViews,
                        recentAlbumViews,
                        recentArtistViews,
                      );
                    });
                  },
                  onReverseSelection: () {
                    setState(() {
                      _reverseSelection(
                        snapshot,
                        visibleSongs,
                        recentPlaylistViews,
                        recentAlbumViews,
                        recentArtistViews,
                      );
                    });
                  },
                  onClearSelection: () {
                    setState(_clearSelection);
                  },
                  onCancel: () {
                    setState(() {
                      _multiSelect = false;
                      _clearSelection();
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  bool _canSelectVisibleItems(
    MusicLibrarySnapshot snapshot,
    List<LibrarySong> visibleSongs,
    List<RecentPlaylistView> playlists,
    List<RecentAlbumView> albums,
    List<RecentArtistView> artists,
  ) {
    if (_activeTab == RecentTab.searches) {
      return snapshot.recentSearches.isNotEmpty;
    }
    if (_activeTab == RecentTab.played) {
      return switch (_activePlayedFilter) {
        RecentPlayedFilter.songs => snapshot.recentSongs.isNotEmpty,
        RecentPlayedFilter.playlists => playlists.isNotEmpty,
        RecentPlayedFilter.albums => albums.isNotEmpty,
        RecentPlayedFilter.artists => artists.isNotEmpty,
      };
    }
    return visibleSongs.isNotEmpty;
  }

  void _playSong(LibrarySong song, List<int> queueSongIds, [int? queueIndex]) {
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
    ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _playSongIds(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }

    final songs =
        ref.read(musicLibrarySnapshotProvider).value?.songs ?? const [];
    final songsById = {for (final song in songs) song.id: song};
    _playSong(songsById[songIds.first]!, songIds, 0);
  }

  void _clearHistory() {
    if (_activeTab == RecentTab.played) {
      ref.read(libraryRepositoryProvider).clearRecentPlayed();
    } else if (_activeTab == RecentTab.searches) {
      ref.read(libraryRepositoryProvider).clearRecentSearches();
    }
    ref.invalidate(musicLibrarySnapshotProvider);
    setState(_clearSelection);
  }

  void _toggleSongSelection(int songId) {
    setState(() {
      if (_selectedSongIds.contains(songId)) {
        _selectedSongIds.remove(songId);
      } else {
        _selectedSongIds.add(songId);
      }
    });
  }

  void _toggleSearchSelection(int entryId) {
    setState(() {
      if (_selectedSearchIds.contains(entryId)) {
        _selectedSearchIds.remove(entryId);
      } else {
        _selectedSearchIds.add(entryId);
      }
    });
  }

  void _toggleCollectionSelection(String key) {
    setState(() {
      if (_selectedCollectionKeys.contains(key)) {
        _selectedCollectionKeys.remove(key);
      } else {
        _selectedCollectionKeys.add(key);
      }
    });
  }

  void _clearSelection() {
    _selectedSongIds.clear();
    _selectedCollectionKeys.clear();
    _selectedSearchIds.clear();
  }

  void _selectAll(
    MusicLibrarySnapshot snapshot,
    List<LibrarySong> visibleSongs,
    List<RecentPlaylistView> playlists,
    List<RecentAlbumView> albums,
    List<RecentArtistView> artists,
  ) {
    if (_activeTab == RecentTab.searches) {
      _selectedSearchIds
        ..clear()
        ..addAll(snapshot.recentSearches.map((entry) => entry.id));
      return;
    }
    if (_activeTab == RecentTab.played &&
        _activePlayedFilter != RecentPlayedFilter.songs) {
      _selectedCollectionKeys
        ..clear()
        ..addAll(_visibleCollectionKeys(playlists, albums, artists));
      return;
    }
    _selectedSongIds
      ..clear()
      ..addAll(visibleSongs.map((song) => song.id));
  }

  void _reverseSelection(
    MusicLibrarySnapshot snapshot,
    List<LibrarySong> visibleSongs,
    List<RecentPlaylistView> playlists,
    List<RecentAlbumView> albums,
    List<RecentArtistView> artists,
  ) {
    if (_activeTab == RecentTab.searches) {
      final current = _selectedSearchIds.toSet();
      _selectedSearchIds
        ..clear()
        ..addAll(
          snapshot.recentSearches
              .where((entry) => !current.contains(entry.id))
              .map((entry) => entry.id),
        );
      return;
    }
    if (_activeTab == RecentTab.played &&
        _activePlayedFilter != RecentPlayedFilter.songs) {
      final current = _selectedCollectionKeys.toSet();
      _selectedCollectionKeys
        ..clear()
        ..addAll(
          _visibleCollectionKeys(
            playlists,
            albums,
            artists,
          ).where((key) => !current.contains(key)),
        );
      return;
    }
    final current = _selectedSongIds.toSet();
    _selectedSongIds
      ..clear()
      ..addAll(
        visibleSongs
            .where((song) => !current.contains(song.id))
            .map((song) => song.id),
      );
  }

  List<String> _visibleCollectionKeys(
    List<RecentPlaylistView> playlists,
    List<RecentAlbumView> albums,
    List<RecentArtistView> artists,
  ) {
    return switch (_activePlayedFilter) {
      RecentPlayedFilter.playlists =>
        playlists.map((item) => 'playlists:${item.playlist.id}').toList(),
      RecentPlayedFilter.albums =>
        albums.map((item) => 'albums:${item.name}').toList(),
      RecentPlayedFilter.artists =>
        artists.map((item) => 'artists:${item.name}').toList(),
      RecentPlayedFilter.songs => const <String>[],
    };
  }

  List<int> _selectedCollectionSongIds(
    List<RecentPlaylistView> playlists,
    List<RecentAlbumView> albums,
    List<RecentArtistView> artists,
  ) {
    final songIds = <int>[];
    for (final playlist in playlists) {
      if (_selectedCollectionKeys.contains(
        'playlists:${playlist.playlist.id}',
      )) {
        songIds.addAll(playlist.songs.map((song) => song.id));
      }
    }
    for (final album in albums) {
      if (_selectedCollectionKeys.contains('albums:${album.name}')) {
        songIds.addAll(album.songIds);
      }
    }
    for (final artist in artists) {
      if (_selectedCollectionKeys.contains('artists:${artist.name}')) {
        songIds.addAll(artist.songs.map((song) => song.id));
      }
    }
    return songIds.toSet().toList();
  }

  void _hideAfterOperation(bool hideMultiSelectCommandBarAfterOperation) {
    _clearSelection();
    if (hideMultiSelectCommandBarAfterOperation) {
      _multiSelect = false;
    }
  }

  void _showSongContextMenu(
    Offset position,
    LibrarySong song,
    List<int> queueSongIds,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) {
    final i18n = context.smPlayerI18n;
    final mediaState = ref.read(mediaControlControllerProvider).state;
    final currentTrackId = mediaState.track.id;
    final canRemove =
        _activeTab == RecentTab.played &&
        _activePlayedFilter == RecentPlayedFilter.songs;
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
        showRemove: canRemove,
        onPlay: () {
          _playSong(song, queueSongIds, queueSongIds.indexOf(song.id));
        },
        onPause: ref.read(mediaControlControllerProvider).onTogglePlayPause,
        onPlayNext: () {
          _showMessage(i18n.t('context.playNext'));
        },
        onAddToNowPlaying: () {
          _showMessage(i18n.t('common.nowPlaying'));
        },
        onCreatePlaylist: () {
          _showMessage(i18n.t('playlists.newPlaylist'));
        },
        onAddToPlaylist: (_) {
          _showMessage(i18n.t('context.addToPlaylist'));
        },
        onRemove: () {
          ref.read(libraryRepositoryProvider).removeRecentPlayed([song.id]);
          ref.invalidate(musicLibrarySnapshotProvider);
        },
        onSelect: () {
          setState(() {
            _multiSelect = true;
            _selectedSongIds.add(song.id);
          });
        },
        onToggleFavorite: () {
          _showMessage(i18n.t('common.myFavorites'));
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
        onHide: () {
          hideSongFile(ref, song.id);
        },
        onSeeArtist: () {
          context.go(
            '/artists?artist=${Uri.encodeQueryComponent(displayArtists(song))}',
          );
        },
        onSeeAlbum: () {
          context.go('/albums?album=${Uri.encodeQueryComponent(song.album)}');
        },
        onSeeMusicInfo: () {
          _showMessage(i18n.t('context.seeMusicInfo'));
        },
        onSeeLyrics: () {
          _showMessage(i18n.t('context.seeLyrics'));
        },
        onSeeAlbumArt: () {
          _showMessage(i18n.t('context.seeAlbumArt'));
        },
        onSeeLocal: () {
          _showMessage(song.path);
        },
      ),
    );
  }

  void _showCollectionContextMenu(
    Offset position,
    String key,
    String title,
    List<int> songIds,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) {
    final i18n = context.smPlayerI18n;
    final songsById = {
      for (final song in ref.read(musicLibrarySnapshotProvider).value!.songs)
        song.id: song,
    };
    final hasNotFavoriteSong = songIds.any(
      (songId) => songsById[songId]!.favorite == false,
    );
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: songIds,
      playlists: playlists,
      includeNowPlaying: true,
      includeFavorites: hasNotFavoriteSong,
      onAddToNowPlaying: () {
        _showMessage(i18n.t('common.nowPlaying'));
      },
      onToggleFavorite:
          hasNotFavoriteSong
              ? () {
                _showMessage(i18n.t('common.myFavorites'));
              }
              : null,
      onCreatePlaylist: () {
        _showMessage(i18n.t('playlists.newPlaylist'));
      },
      onAddToPlaylist: (_) {
        _showMessage(i18n.t('context.addToPlaylist'));
      },
    );
    showMenuFlyout(
      context,
      position: position,
      items: [
        MenuFlyoutItem(
          key: 'play',
          text: i18n.t('context.play'),
          icon: FluentIcons.play_20_regular,
          onPressed: () {
            _playSongIds(songIds);
          },
        ),
        if (addToItem != null) addToItem,
        MenuFlyoutItem.separator(key: 'collection-actions-separator'),
        MenuFlyoutItem(
          key: 'select',
          text: i18n.t('context.select'),
          icon: FluentIcons.select_all_on_20_regular,
          onPressed: () {
            setState(() {
              _multiSelect = true;
              _selectedCollectionKeys.add(key);
            });
          },
        ),
        MenuFlyoutItem(
          key: 'open',
          text: i18n.t('common.open'),
          icon: FluentIcons.open_20_regular,
          onPressed: () {
            if (key.startsWith('playlists:')) {
              context.go('/playlists/${key.substring('playlists:'.length)}');
            } else if (key.startsWith('albums:')) {
              context.go('/albums?album=${Uri.encodeQueryComponent(title)}');
            } else {
              context.go('/artists?artist=${Uri.encodeQueryComponent(title)}');
            }
          },
        ),
      ],
    );
  }

  void _showSearchContextMenu(Offset position, SearchHistoryEntry entry) {
    final i18n = context.smPlayerI18n;
    showMenuFlyout(
      context,
      position: position,
      items: [
        MenuFlyoutItem(
          key: 'search',
          text: i18n.t('common.search'),
          icon: FluentIcons.search_20_regular,
          onPressed: () {
            context.go(
              '/search?query=${Uri.encodeQueryComponent(entry.query)}',
            );
          },
        ),
        MenuFlyoutItem(
          key: 'select',
          text: i18n.t('context.select'),
          icon: FluentIcons.select_all_on_20_regular,
          onPressed: () {
            setState(() {
              _multiSelect = true;
              _selectedSearchIds.add(entry.id);
            });
          },
        ),
        MenuFlyoutItem(
          key: 'remove-from-list',
          text: i18n.t('context.removeFromList'),
          icon: FluentIcons.delete_20_regular,
          onPressed: () {
            ref.read(libraryRepositoryProvider).removeRecentSearches([
              entry.id,
            ]);
            ref.invalidate(musicLibrarySnapshotProvider);
          },
        ),
      ],
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RecentTabs extends StatelessWidget {
  const _RecentTabs({
    required this.i18n,
    required this.activeTab,
    required this.addedCount,
    required this.playedCount,
    required this.searchesCount,
    required this.showCount,
    required this.onChanged,
  });

  final SmPlayerI18n i18n;
  final RecentTab activeTab;
  final int addedCount;
  final int playedCount;
  final int searchesCount;
  final bool showCount;
  final ValueChanged<RecentTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Expanded(
            child: _RecentTabButton(
              active: activeTab == RecentTab.added,
              label: i18n.t('recent.added'),
              count: addedCount,
              showCount: showCount,
              onPressed: () => onChanged(RecentTab.added),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _RecentTabButton(
              active: activeTab == RecentTab.played,
              label: i18n.t('recent.played'),
              count: playedCount,
              showCount: showCount,
              onPressed: () => onChanged(RecentTab.played),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _RecentTabButton(
              active: activeTab == RecentTab.searches,
              label: i18n.t('recent.searches'),
              count: searchesCount,
              showCount: showCount,
              onPressed: () => onChanged(RecentTab.searches),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTabButton extends StatelessWidget {
  const _RecentTabButton({
    required this.active,
    required this.label,
    required this.count,
    required this.showCount,
    required this.onPressed,
  });

  final bool active;
  final String label;
  final int count;
  final bool showCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor:
            active ? _RecentColors.accent : _RecentColors.textMuted,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: const RoundedRectangleBorder(),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            showCount ? '$label  $count' : label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 3,
            width: 58,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: active ? _RecentColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentPlayedFilterBar extends StatelessWidget {
  const _RecentPlayedFilterBar({
    required this.i18n,
    required this.activeFilter,
    required this.onChanged,
  });

  final SmPlayerI18n i18n;
  final RecentPlayedFilter activeFilter;
  final ValueChanged<RecentPlayedFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterButton(
            active: activeFilter == RecentPlayedFilter.songs,
            icon: FluentIcons.music_note_2_20_regular,
            label: i18n.t('common.songs'),
            onPressed: () => onChanged(RecentPlayedFilter.songs),
          ),
          _FilterButton(
            active: activeFilter == RecentPlayedFilter.artists,
            icon: FluentIcons.people_20_regular,
            label: i18n.t('recent.artists'),
            onPressed: () => onChanged(RecentPlayedFilter.artists),
          ),
          _FilterButton(
            active: activeFilter == RecentPlayedFilter.albums,
            icon: FluentIcons.album_20_regular,
            label: i18n.t('recent.albums'),
            onPressed: () => onChanged(RecentPlayedFilter.albums),
          ),
          _FilterButton(
            active: activeFilter == RecentPlayedFilter.playlists,
            icon: FluentIcons.apps_list_detail_20_regular,
            label: i18n.t('recent.playlists'),
            onPressed: () => onChanged(RecentPlayedFilter.playlists),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.active,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          minimumSize: const Size(72, 36),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          foregroundColor:
              active ? _RecentColors.accent : _RecentColors.textStrong,
          backgroundColor:
              active ? _RecentColors.accentSoft : _RecentColors.commandSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: _RecentColors.commandBorder),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        onPressed: onPressed,
      ),
    );
  }
}

class _RecentPlayedPanel extends StatelessWidget {
  const _RecentPlayedPanel({
    required this.filter,
    required this.songs,
    required this.playlists,
    required this.albums,
    required this.artists,
    required this.multiSelect,
    required this.selectedSongIds,
    required this.selectedCollectionKeys,
    required this.mediaControlState,
    required this.onPlaySongs,
    required this.onPlaySong,
    required this.onToggleSongSelection,
    required this.onToggleCollectionSelection,
    required this.onOpenAlbum,
    required this.onOpenArtist,
    required this.onOpenPlaylist,
    required this.onOpenSongContextMenu,
    required this.onOpenCollectionContextMenu,
  });

  final RecentPlayedFilter filter;
  final List<RecentLibrarySong> songs;
  final List<RecentPlaylistView> playlists;
  final List<RecentAlbumView> albums;
  final List<RecentArtistView> artists;
  final bool multiSelect;
  final Set<int> selectedSongIds;
  final Set<String> selectedCollectionKeys;
  final MediaControlState mediaControlState;
  final ValueChanged<List<int>> onPlaySongs;
  final void Function(
    LibrarySong song,
    List<int> queueSongIds, [
    int? queueIndex,
  ])
  onPlaySong;
  final ValueChanged<int> onToggleSongSelection;
  final ValueChanged<String> onToggleCollectionSelection;
  final ValueChanged<String> onOpenAlbum;
  final ValueChanged<String> onOpenArtist;
  final ValueChanged<int> onOpenPlaylist;
  final void Function(Offset position, LibrarySong song, List<int> queueSongIds)
  onOpenSongContextMenu;
  final void Function(
    Offset position,
    String key,
    String title,
    List<int> songIds,
  )
  onOpenCollectionContextMenu;

  @override
  Widget build(BuildContext context) {
    return switch (filter) {
      RecentPlayedFilter.songs => _RecentSongGrid(
        songs: songs,
        queueSongIds: songs.map((song) => song.id).toList(),
        selectedSongIds: selectedSongIds,
        multiSelect: multiSelect,
        mediaControlState: mediaControlState,
        getTimelineDate: (song) => (song as RecentLibrarySong).playedAt,
        getDetailLabel:
            (song) =>
                formatRecentDateTime((song as RecentLibrarySong).playedAt),
        onPlaySong: onPlaySong,
        onToggleSelection: onToggleSongSelection,
        onOpenContextMenu: onOpenSongContextMenu,
      ),
      RecentPlayedFilter.playlists => _RecentPlaylistGrid(
        playlists: playlists,
        multiSelect: multiSelect,
        selectedKeys: selectedCollectionKeys,
        onOpen: onOpenPlaylist,
        onPlay: (playlist) {
          onPlaySongs(playlist.songs.map((song) => song.id).toList());
        },
        onToggleSelection: onToggleCollectionSelection,
        onOpenContextMenu: (position, playlist) {
          onOpenCollectionContextMenu(
            position,
            'playlists:${playlist.playlist.id}',
            playlist.playlist.name,
            playlist.songs.map((song) => song.id).toList(),
          );
        },
      ),
      RecentPlayedFilter.albums => _RecentAlbumGrid(
        albums: albums,
        multiSelect: multiSelect,
        selectedKeys: selectedCollectionKeys,
        onOpen: onOpenAlbum,
        onPlay: (album) {
          onPlaySongs(album.songIds);
        },
        onToggleSelection: onToggleCollectionSelection,
        onOpenContextMenu: (position, album) {
          onOpenCollectionContextMenu(
            position,
            'albums:${album.name}',
            album.name,
            album.songIds,
          );
        },
      ),
      RecentPlayedFilter.artists => _RecentArtistList(
        artists: artists,
        multiSelect: multiSelect,
        selectedKeys: selectedCollectionKeys,
        onOpen: onOpenArtist,
        onPlay: (artist) {
          onPlaySongs(artist.songs.map((song) => song.id).toList());
        },
        onToggleSelection: onToggleCollectionSelection,
        onOpenContextMenu: (position, artist) {
          onOpenCollectionContextMenu(
            position,
            'artists:${artist.name}',
            artist.name,
            artist.songs.map((song) => song.id).toList(),
          );
        },
      ),
    };
  }
}

class _RecentSongGrid extends StatelessWidget {
  const _RecentSongGrid({
    required this.songs,
    required this.queueSongIds,
    required this.selectedSongIds,
    required this.multiSelect,
    required this.mediaControlState,
    required this.getTimelineDate,
    required this.getDetailLabel,
    required this.onPlaySong,
    required this.onToggleSelection,
    required this.onOpenContextMenu,
  });

  final List<LibrarySong> songs;
  final List<int> queueSongIds;
  final Set<int> selectedSongIds;
  final bool multiSelect;
  final MediaControlState mediaControlState;
  final String Function(LibrarySong song) getTimelineDate;
  final String Function(LibrarySong song) getDetailLabel;
  final void Function(
    LibrarySong song,
    List<int> queueSongIds, [
    int? queueIndex,
  ])
  onPlaySong;
  final ValueChanged<int> onToggleSelection;
  final void Function(Offset position, LibrarySong song, List<int> queueSongIds)
  onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return _RecentEmptyState(
        title: context.smPlayerI18n.t('recent.empty'),
        message: '',
      );
    }

    final groups = _groupRecentItems(songs, getTimelineDate);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth + 28) / (270 + 28))
            .floor()
            .clamp(1, 8);
        return CustomScrollView(
          slivers: [
            for (final group in groups) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                  child: Text(
                    group.label,
                    style: const TextStyle(
                      color: _RecentColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: constraints.maxWidth <= 520 ? 104 : 136,
                  crossAxisSpacing: 28,
                  mainAxisSpacing: 0,
                ),
                itemCount: group.items.length,
                itemBuilder: (context, index) {
                  final song = group.items[index];
                  return _GridViewMusicItemControl(
                    song: song,
                    detailLabel: getDetailLabel(song),
                    selected: selectedSongIds.contains(song.id),
                    current: song.id == mediaControlState.track.id,
                    playing:
                        song.id == mediaControlState.track.id &&
                        mediaControlState.isPlaying,
                    multiSelect: multiSelect,
                    onPlayTrack: () {
                      onPlaySong(
                        song,
                        queueSongIds,
                        queueSongIds.indexOf(song.id),
                      );
                    },
                    onToggleSelection: () {
                      onToggleSelection(song.id);
                    },
                    onOpenContextMenu: (position) {
                      onOpenContextMenu(position, song, queueSongIds);
                    },
                  );
                },
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 92)),
          ],
        );
      },
    );
  }
}

class _GridViewMusicItemControl extends StatefulWidget {
  const _GridViewMusicItemControl({
    required this.song,
    required this.detailLabel,
    required this.selected,
    required this.current,
    required this.playing,
    required this.multiSelect,
    required this.onPlayTrack,
    required this.onToggleSelection,
    required this.onOpenContextMenu,
  });

  final LibrarySong song;
  final String detailLabel;
  final bool selected;
  final bool current;
  final bool playing;
  final bool multiSelect;
  final VoidCallback onPlayTrack;
  final VoidCallback onToggleSelection;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  State<_GridViewMusicItemControl> createState() =>
      _GridViewMusicItemControlState();
}

class _GridViewMusicItemControlState extends State<_GridViewMusicItemControl> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final file =
        widget.song.thumbnailPath.isEmpty
            ? null
            : File(widget.song.thumbnailPath);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onSecondaryTapDown: (details) {
          widget.onOpenContextMenu(details.globalPosition);
        },
        onTap:
            widget.multiSelect ? widget.onToggleSelection : widget.onPlayTrack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.fromLTRB(3, 3, 8, 3),
          decoration: BoxDecoration(
            color:
                widget.selected || _hovered
                    ? _RecentColors.accentSoft
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox.square(
                      dimension: 110,
                      child:
                          file != null && file.existsSync()
                              ? Image.file(file, fit: BoxFit.cover)
                              : const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _RecentColors.artwork,
                                ),
                                child: Icon(
                                  FluentIcons.music_note_2_24_regular,
                                  color: _RecentColors.artworkIcon,
                                ),
                              ),
                    ),
                  ),
                  if (widget.multiSelect || widget.selected)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: _RecentColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox.square(
                          dimension: 30,
                          child:
                              widget.selected
                                  ? const Icon(
                                    FluentIcons.checkmark_16_regular,
                                    color: Colors.white,
                                    size: 17,
                                  )
                                  : null,
                        ),
                      ),
                    )
                  else if (_hovered)
                    Positioned.fill(
                      child: Center(
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: _RecentColors.overlay,
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(),
                          ),
                          icon: Icon(
                            widget.playing
                                ? FluentIcons.pause_20_filled
                                : FluentIcons.play_20_filled,
                            size: 19,
                          ),
                          onPressed: widget.onPlayTrack,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.title,
                      maxLines: widget.detailLabel.isEmpty ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            widget.current
                                ? _RecentColors.accent
                                : _RecentColors.textStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      displayArtists(widget.song),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _RecentColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    if (widget.detailLabel.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        widget.detailLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _RecentColors.textSoft,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentPlaylistGrid extends StatelessWidget {
  const _RecentPlaylistGrid({
    required this.playlists,
    required this.multiSelect,
    required this.selectedKeys,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSelection,
    required this.onOpenContextMenu,
  });

  final List<RecentPlaylistView> playlists;
  final bool multiSelect;
  final Set<String> selectedKeys;
  final ValueChanged<int> onOpen;
  final ValueChanged<RecentPlaylistView> onPlay;
  final ValueChanged<String> onToggleSelection;
  final void Function(Offset position, RecentPlaylistView playlist)
  onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    return _RecentCollectionGrid(
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        final key = 'playlists:${playlist.playlist.id}';
        return _CollectionCard(
          icon: FluentIcons.apps_list_detail_24_regular,
          title: playlist.playlist.name,
          subtitle: formatRecentDateTime(playlist.playedAt),
          selected: selectedKeys.contains(key),
          multiSelect: multiSelect,
          onOpen: () {
            if (multiSelect) {
              onToggleSelection(key);
            } else {
              onOpen(playlist.playlist.id);
            }
          },
          onPlay: () => onPlay(playlist),
          onOpenContextMenu: (position) {
            onOpenContextMenu(position, playlist);
          },
        );
      },
    );
  }
}

class _RecentAlbumGrid extends StatelessWidget {
  const _RecentAlbumGrid({
    required this.albums,
    required this.multiSelect,
    required this.selectedKeys,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSelection,
    required this.onOpenContextMenu,
  });

  final List<RecentAlbumView> albums;
  final bool multiSelect;
  final Set<String> selectedKeys;
  final ValueChanged<String> onOpen;
  final ValueChanged<RecentAlbumView> onPlay;
  final ValueChanged<String> onToggleSelection;
  final void Function(Offset position, RecentAlbumView album) onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    return _RecentCollectionGrid(
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        final key = 'albums:${album.name}';
        final firstSong = album.songs.first;
        return _CollectionCard(
          icon: FluentIcons.album_24_regular,
          title: album.name,
          subtitle: formatRecentDateTime(album.playedAt),
          imagePath: firstSong.thumbnailPath,
          selected: selectedKeys.contains(key),
          multiSelect: multiSelect,
          onOpen: () {
            if (multiSelect) {
              onToggleSelection(key);
            } else {
              onOpen(album.name);
            }
          },
          onPlay: () => onPlay(album),
          onOpenContextMenu: (position) {
            onOpenContextMenu(position, album);
          },
        );
      },
    );
  }
}

class _RecentArtistList extends StatelessWidget {
  const _RecentArtistList({
    required this.artists,
    required this.multiSelect,
    required this.selectedKeys,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSelection,
    required this.onOpenContextMenu,
  });

  final List<RecentArtistView> artists;
  final bool multiSelect;
  final Set<String> selectedKeys;
  final ValueChanged<String> onOpen;
  final ValueChanged<RecentArtistView> onPlay;
  final ValueChanged<String> onToggleSelection;
  final void Function(Offset position, RecentArtistView artist)
  onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return _RecentEmptyState(
        title: context.smPlayerI18n.t('recent.empty'),
        message: '',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 92),
      itemExtent: 72,
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        final key = 'artists:${artist.name}';
        final firstSong = artist.songs.first;
        return _ArtistRow(
          artist: artist,
          imagePath: firstSong.thumbnailPath,
          selected: selectedKeys.contains(key),
          multiSelect: multiSelect,
          onOpen: () {
            if (multiSelect) {
              onToggleSelection(key);
            } else {
              onOpen(artist.name);
            }
          },
          onPlay: () => onPlay(artist),
          onOpenContextMenu: (position) {
            onOpenContextMenu(position, artist);
          },
        );
      },
    );
  }
}

class _RecentCollectionGrid extends StatelessWidget {
  const _RecentCollectionGrid({
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return _RecentEmptyState(
        title: context.smPlayerI18n.t('recent.empty'),
        message: '',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 92),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        mainAxisExtent: 242,
        crossAxisSpacing: 30,
        mainAxisSpacing: 26,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

class _CollectionCard extends StatefulWidget {
  const _CollectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.multiSelect,
    required this.onOpen,
    required this.onPlay,
    required this.onOpenContextMenu,
    this.imagePath,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? imagePath;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final imagePath = widget.imagePath;
    final file =
        imagePath == null || imagePath.isEmpty ? null : File(imagePath);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onSecondaryTapDown: (details) {
          widget.onOpenContextMenu(details.globalPosition);
        },
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                widget.selected || _hovered ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.square(
                      dimension: 156,
                      child:
                          file != null && file.existsSync()
                              ? Image.file(file, fit: BoxFit.cover)
                              : DecoratedBox(
                                decoration: const BoxDecoration(
                                  color: _RecentColors.artwork,
                                ),
                                child: Icon(
                                  widget.icon,
                                  color: _RecentColors.artworkIcon,
                                  size: 42,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _RecentColors.textStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _RecentColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (_hovered && !widget.multiSelect)
                Positioned(
                  top: 100,
                  right: 8,
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: _RecentColors.overlay,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(FluentIcons.play_20_filled, size: 17),
                    onPressed: widget.onPlay,
                  ),
                ),
              if (widget.multiSelect || widget.selected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: _RecentColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 24,
                      child:
                          widget.selected
                              ? const Icon(
                                FluentIcons.checkmark_16_regular,
                                color: Colors.white,
                                size: 16,
                              )
                              : null,
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

class _ArtistRow extends StatelessWidget {
  const _ArtistRow({
    required this.artist,
    required this.imagePath,
    required this.selected,
    required this.multiSelect,
    required this.onOpen,
    required this.onPlay,
    required this.onOpenContextMenu,
  });

  final RecentArtistView artist;
  final String imagePath;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  Widget build(BuildContext context) {
    final file = imagePath.isEmpty ? null : File(imagePath);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onSecondaryTapDown: (details) {
          onOpenContextMenu(details.globalPosition);
        },
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? _RecentColors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox.square(
                  dimension: 52,
                  child:
                      file != null && file.existsSync()
                          ? Image.file(file, fit: BoxFit.cover)
                          : const DecoratedBox(
                            decoration: BoxDecoration(
                              color: _RecentColors.artwork,
                            ),
                            child: Icon(
                              FluentIcons.people_24_regular,
                              color: _RecentColors.artworkIcon,
                            ),
                          ),
                ),
              ),
              const SizedBox(width: 12),
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
                        color: _RecentColors.textStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatRecentDateTime(artist.playedAt),
                      style: const TextStyle(
                        color: _RecentColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (multiSelect)
                Icon(
                  selected
                      ? FluentIcons.checkmark_circle_20_filled
                      : FluentIcons.circle_20_regular,
                  color:
                      selected ? _RecentColors.accent : _RecentColors.textMuted,
                )
              else
                IconButton(
                  tooltip: context.smPlayerI18n.t('nowPlaying.randomPlay'),
                  icon: const Icon(FluentIcons.play_20_filled),
                  onPressed: onPlay,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentPagePanel extends StatelessWidget {
  const _RecentPagePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SizedBox.expand(child: child),
    );
  }
}

class _RecentLoadingState extends StatelessWidget {
  const _RecentLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
  }
}

class _RecentEmptyState extends StatelessWidget {
  const _RecentEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message.isEmpty ? title : '$title\n$message',
        textAlign: TextAlign.center,
        style: const TextStyle(color: _RecentColors.textMuted, height: 1.5),
      ),
    );
  }
}

class _RecentTimeGroup<T> {
  const _RecentTimeGroup({required this.label, required this.items});

  final String label;
  final List<T> items;
}

List<_RecentTimeGroup<T>> _groupRecentItems<T>(
  List<T> items,
  String Function(T item) getDateLabel,
) {
  final groups = <_RecentTimeGroup<T>>[];
  for (final item in items) {
    final label = categorizeRecentDate(getDateLabel(item));
    final currentGroup = groups.isEmpty ? null : groups.last;
    if (currentGroup?.label == label) {
      currentGroup!.items.add(item);
    } else {
      groups.add(_RecentTimeGroup(label: label, items: [item]));
    }
  }
  return groups;
}

class _RecentColors {
  const _RecentColors._();

  static const accent = Color(0xff0078d7);
  static const accentSoft = Color(0x1f0078d7);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const textSoft = Color(0xff8290a1);
  static const commandSurface = Color(0x8fffffff);
  static const commandBorder = Color(0x1f536379);
  static const artwork = Color(0xffe8eef5);
  static const artworkIcon = Color(0xff607085);
  static const overlay = Color(0xb81e2228);
}
