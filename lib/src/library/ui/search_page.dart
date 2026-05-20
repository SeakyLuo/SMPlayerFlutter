import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/album_tile.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/search_page_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, required this.query, required this.activeType});

  final String query;
  final String? activeType;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const _artistPreviewLimit = 10;
  static const _sectionPreviewLimit = 5;

  final _settingsController = SettingsController();
  final _selection = PageSelectionController<String>();
  var _settings = const SettingsSnapshot.defaults();
  late var _activeFilter = searchFilterKeyFromType(widget.activeType);
  String? _lastRecentSearchKey;
  LibrarySong? _dialogSong;
  SongDialogMode? _dialogMode;
  SearchResult? _albumArtPreview;

  @override
  void initState() {
    super.initState();
    _restoreSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _recordRecentSearch();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextFilter = searchFilterKeyFromType(widget.activeType);
    if (oldWidget.query != widget.query || nextFilter != _activeFilter) {
      _activeFilter = nextFilter;
      _selection.cancel();
      _recordRecentSearch();
    }
  }

  @override
  void dispose() {
    _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshotValue = ref.watch(musicLibrarySnapshotProvider);
    final mediaControlState = ref.watch(mediaControlControllerProvider).state;
    final i18n =
        ref.watch(smPlayerI18nProvider).value ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    final query = widget.query.trim();

    return snapshotValue.when(
      loading:
          () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      error: (_, _) => _SearchEmptyState(message: i18n.t('search.noResult')),
      data: (snapshot) {
        final normalizedQuery = query.toLowerCase();
        final results = buildSearchResults(
          snapshot.songs,
          snapshot.folders,
          snapshot.playlists,
          snapshot.rootPath,
          normalizedQuery,
          i18n,
        );
        final criteria = SearchCriteria(
          artists: _settings.searchArtistsCriterion,
          albums: _settings.searchAlbumsCriterion,
          songs: _settings.searchSongsCriterion,
          playlists: _settings.searchPlaylistsCriterion,
          folders: _settings.searchFoldersCriterion,
        );
        final sections = _buildSections(results, criteria);
        final visibleSections = _visibleSections(sections);
        final selectedSongIds = _selectedSongIds(results);
        final selectedKeys = _selectableKeys(sections);

        return SmPlayerI18nScope(
          i18n: i18n,
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  18,
                  24,
                  _selection.multiSelect
                      ? multiSelectCommandBarScrollSpacer
                      : 28,
                ),
                children: [
                  _SearchHeader(
                    title:
                        query.isEmpty
                            ? i18n.t('search.resultTitle')
                            : i18n.t('search.resultOf', {'query': query}),
                    summary: i18n.t('search.resultSummary', {
                      'count': _totalCount(results),
                    }),
                  ),
                  const SizedBox(height: 16),
                  _SearchFilterTabs(
                    i18n: i18n,
                    activeFilter: _activeFilter,
                    results: results,
                    onChanged: _changeFilter,
                  ),
                  const SizedBox(height: 18),
                  if (query.isEmpty)
                    _SearchEmptyState(message: i18n.t('search.enterKeyword'))
                  else if (_totalCount(results) == 0)
                    _SearchEmptyState(message: i18n.t('search.noResult'))
                  else
                    for (final section in visibleSections) ...[
                      _SearchResultSection(
                        section: section,
                        i18n: i18n,
                        showCount: snapshot.showCount,
                        mediaControlState: mediaControlState,
                        selection: _selection,
                        playlists: _customPlaylists(snapshot.playlists),
                        songsById: {
                          for (final song in snapshot.songs) song.id: song,
                        },
                        onViewAll: () {
                          _changeFilter(_filterForSection(section.type));
                        },
                        onViewLess: () {
                          _changeFilter(SearchFilterKey.all);
                        },
                        onSortChanged: (criterion) {
                          _updateSort(section.type, criterion);
                        },
                        onSelectionChanged: () {
                          setState(() {});
                        },
                        onOpenCard: (card) {
                          _openCard(section.type, card, query);
                        },
                        onPlaySongs: _playSongIds,
                        onPlayCard: (card) {
                          _playCard(section.type, card);
                        },
                        onPlayTrack: (song, index) {
                          _playTrack(
                            song,
                            index,
                            results.songs.map((item) => item.id).toList(),
                          );
                        },
                        onTogglePlayPause:
                            ref
                                .read(mediaControlControllerProvider)
                                .onTogglePlayPause,
                        onPlayNext: _playNext,
                        onAddSongsToPlaylist: _addSongsToPlaylist,
                        onToggleSongsFavorite: _toggleSongsFavorite,
                        onCreatePlaylist: _createPlaylist,
                        onOpenMusicDialog: _openMusicDialog,
                        onPreviewAlbumArt: _showAlbumArtPreview,
                        onSearchDirectory: _searchDirectory,
                        onRevealCard: _revealSearchCard,
                        onRevealSong: _revealSong,
                      ),
                      const SizedBox(height: 24),
                    ],
                ],
              ),
              MultiSelectCommandBar(
                visible: _selection.multiSelect,
                selectedCount: selectedSongIds.length,
                playlists: _customPlaylists(snapshot.playlists),
                showAddTo: true,
                onPlay:
                    selectedSongIds.isEmpty
                        ? null
                        : () {
                          _playSongIds(selectedSongIds);
                          _selection.hideAfterOperation(
                            snapshot.hideMultiSelectCommandBarAfterOperation,
                          );
                          setState(() {});
                        },
                onAddToPlaylist:
                    selectedSongIds.isEmpty
                        ? null
                        : (playlistId) {
                          _addSongsToPlaylist(playlistId, selectedSongIds);
                          _selection.hideAfterOperation(
                            snapshot.hideMultiSelectCommandBarAfterOperation,
                          );
                          setState(() {});
                        },
                onSelectAll: () {
                  setState(() {
                    _selection.selectAll(selectedKeys);
                  });
                },
                onReverseSelection: () {
                  setState(() {
                    _selection.reverseSelection(selectedKeys);
                  });
                },
                onClearSelection: () {
                  setState(_selection.clearSelection);
                },
                onCancel: () {
                  setState(_selection.cancel);
                },
              ),
              if (_dialogSong != null && _dialogMode != null)
                MusicDialog(
                  song: _dialogSong!,
                  initialMode: _dialogMode!,
                  canPause:
                      mediaControlState.isPlaying &&
                      mediaControlState.track.id == _dialogSong!.id,
                  onPlay: () {
                    if (mediaControlState.track.id == _dialogSong!.id) {
                      ref
                          .read(mediaControlControllerProvider)
                          .onTogglePlayPause();
                      return;
                    }
                    _playSongIds([_dialogSong!.id]);
                  },
                  onReveal: _revealSongPath,
                  onClose: () {
                    setState(() {
                      _dialogSong = null;
                      _dialogMode = null;
                    });
                  },
                ),
              if (_albumArtPreview != null)
                _SearchAlbumArtPreviewDialog(
                  card: _albumArtPreview!,
                  onClose: () {
                    setState(() {
                      _albumArtPreview = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  List<_SearchSectionData> _buildSections(
    SearchResults results,
    SearchCriteria criteria,
  ) {
    return [
      _SearchSectionData.cards(
        type: SearchResultType.artists,
        cards: sortSearchResults(results.artists, criteria.artists),
        previewLimit: _artistPreviewLimit,
      ),
      _SearchSectionData.cards(
        type: SearchResultType.albums,
        cards: sortSearchResults(results.albums, criteria.albums),
        previewLimit: _sectionPreviewLimit,
      ),
      _SearchSectionData.songs(
        songs: sortSearchSongs(results.songs, criteria.songs),
        previewLimit: _sectionPreviewLimit,
      ),
      _SearchSectionData.cards(
        type: SearchResultType.playlists,
        cards: sortSearchResults(results.playlists, criteria.playlists),
        previewLimit: _sectionPreviewLimit,
      ),
      _SearchSectionData.cards(
        type: SearchResultType.folders,
        cards: sortSearchResults(results.folders, criteria.folders),
        previewLimit: _sectionPreviewLimit,
      ),
    ];
  }

  List<_SearchSectionData> _visibleSections(List<_SearchSectionData> sections) {
    final filtered =
        _activeFilter == SearchFilterKey.all
            ? sections.where((section) => section.count > 0).toList()
            : sections
                .where(
                  (section) => _filterForSection(section.type) == _activeFilter,
                )
                .toList();
    if (_activeFilter == SearchFilterKey.all) {
      filtered.sort((left, right) {
        final leftEmpty = left.count == 0 ? 1 : 0;
        final rightEmpty = right.count == 0 ? 1 : 0;
        return leftEmpty.compareTo(rightEmpty);
      });
    }
    return filtered;
  }

  void _changeFilter(SearchFilterKey filter) {
    final type = searchFilterTypeValue(filter);
    final encodedQuery = Uri.encodeQueryComponent(widget.query.trim());
    setState(() {
      _activeFilter = filter;
      _selection.cancel();
    });
    context.go(
      filter == SearchFilterKey.all
          ? '/search?query=$encodedQuery'
          : '/search?query=$encodedQuery&type=$type',
    );
    _recordRecentSearch();
  }

  Future<void> _restoreSettings() async {
    await _settingsController.refresh();
    if (!mounted) {
      return;
    }

    setState(() {
      _settings = _settingsController.snapshot;
    });
  }

  Future<void> _updateSort(
    SearchResultType type,
    SearchSortCriterion criterion,
  ) async {
    final update = switch (type) {
      SearchResultType.artists => AppSettingsUpdate(
        searchArtistsCriterion: criterion,
      ),
      SearchResultType.albums => AppSettingsUpdate(
        searchAlbumsCriterion: criterion,
      ),
      SearchResultType.songs => AppSettingsUpdate(
        searchSongsCriterion: criterion,
      ),
      SearchResultType.playlists => AppSettingsUpdate(
        searchPlaylistsCriterion: criterion,
      ),
      SearchResultType.folders => AppSettingsUpdate(
        searchFoldersCriterion: criterion,
      ),
    };
    await _settingsController.updateSettings(update);
    if (!mounted) {
      return;
    }

    setState(() {
      _settings = _settingsController.snapshot;
    });
  }

  void _recordRecentSearch() {
    final query = widget.query.trim();
    if (query.isEmpty) {
      return;
    }

    final type = searchHistoryTypeForFilter(_activeFilter);
    final recentSearchKey = '$query:${type.name}';
    if (_lastRecentSearchKey == recentSearchKey) {
      return;
    }

    _lastRecentSearchKey = recentSearchKey;
    ref.read(libraryRepositoryProvider).addRecentSearch(query, type);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  int _totalCount(SearchResults results) {
    return results.artists.length +
        results.albums.length +
        results.songs.length +
        results.playlists.length +
        results.folders.length;
  }

  List<String> _selectableKeys(List<_SearchSectionData> sections) {
    return [
      for (final section in _visibleSections(sections))
        ...section.visibleKeys(_activeFilter == SearchFilterKey.all),
    ];
  }

  List<int> _selectedSongIds(SearchResults results) {
    final songIds = <int>[];
    final selectedKeys = _selection.selectedItems;
    for (final song in results.songs) {
      if (selectedKeys.contains(_songSelectionKey(song))) {
        songIds.add(song.id);
      }
    }
    for (final section in [
      (SearchResultType.artists, results.artists),
      (SearchResultType.albums, results.albums),
      (SearchResultType.playlists, results.playlists),
      (SearchResultType.folders, results.folders),
    ]) {
      for (final card in section.$2) {
        if (selectedKeys.contains(getSearchResultCardKey(section.$1, card))) {
          songIds.addAll(card.songIds);
        }
      }
    }
    return getUniqueSongIds(songIds);
  }

  void _openCard(SearchResultType type, SearchResult card, String query) {
    switch (type) {
      case SearchResultType.artists:
      case SearchResultType.albums:
      case SearchResultType.playlists:
        context.go(card.path);
      case SearchResultType.folders:
        final params = {
          'path': card.localFolderRelativePath ?? '',
          if (query.isNotEmpty) 'query': query,
        };
        context.go(Uri(path: '/local', queryParameters: params).toString());
      case SearchResultType.songs:
        break;
    }
  }

  void _playCard(SearchResultType type, SearchResult card) {
    switch (type) {
      case SearchResultType.artists:
        ref.read(libraryRepositoryProvider).recordArtistPlayed(card.title);
      case SearchResultType.albums:
        ref.read(libraryRepositoryProvider).recordAlbumPlayed(card.title);
      case SearchResultType.playlists:
        ref
            .read(libraryRepositoryProvider)
            .recordPlaylistPlayed(int.parse(card.sourceId!));
      case SearchResultType.folders:
      case SearchResultType.songs:
        break;
    }
    _playSongIds(card.songIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _playTrack(LibrarySong song, int index, List<int> songIds) {
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
          queueIndex: index,
        );
    ref.read(libraryRepositoryProvider).replaceNowPlaying(songIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _playSongIds(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }

    final songs = ref.read(musicLibrarySnapshotProvider).value!.songs;
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

  void _playNext(LibrarySong song) {
    final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
    final queueSongIds = snapshot.nowPlaying.songIds.toList();
    queueSongIds.remove(song.id);
    final selectedQueueIndex =
        ref.read(mediaControlControllerProvider).state.selectedQueueIndex;
    queueSongIds.insert(
      selectedQueueIndex == null ? 0 : selectedQueueIndex + 1,
      song.id,
    );
    ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  Future<void> _createPlaylist(String name, List<int> songIds) async {
    await ref.read(libraryRepositoryProvider).createPlaylist(name, songIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  Future<void> _addSongsToPlaylist(int playlistId, List<int> songIds) async {
    await ref
        .read(libraryRepositoryProvider)
        .addSongsToPlaylist(playlistId, songIds);
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  Future<void> _toggleSongsFavorite(List<int> songIds, bool favorite) async {
    await ref
        .read(libraryRepositoryProvider)
        .setSongsFavorite(songIds, favorite);
    final mediaController = ref.read(mediaControlControllerProvider);
    if (songIds.contains(mediaController.state.track.id) &&
        mediaController.state.track.favorite != favorite) {
      mediaController.onToggleFavorite();
    }
    ref.invalidate(musicLibrarySnapshotProvider);
  }

  void _openMusicDialog(LibrarySong song, SongDialogMode mode) {
    setState(() {
      _dialogSong = song;
      _dialogMode = mode;
      _albumArtPreview = null;
    });
  }

  void _showAlbumArtPreview(SearchResult card) {
    setState(() {
      _albumArtPreview = card;
      _dialogSong = null;
      _dialogMode = null;
    });
  }

  Future<void> _searchDirectory(SearchResult card) async {
    final i18n =
        ref.read(smPlayerI18nProvider).value ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    final query = await showPopupTextDialog(
      context: context,
      title: i18n.t('local.searchDirectoryPrompt', {'name': card.title}),
      initialValue: widget.query.trim(),
      confirmLabel: i18n.t('common.search'),
    );
    if (query == null || !mounted) {
      return;
    }

    context.go(
      Uri(
        path: '/local',
        queryParameters: {
          'path': card.localFolderRelativePath ?? '',
          if (query.isNotEmpty) 'query': query,
        },
      ).toString(),
    );
  }

  Future<void> _revealSearchCard(SearchResult card) async {
    final sourcePath = card.sourcePath!;
    if (Platform.isWindows) {
      await Process.start('explorer.exe', [sourcePath]);
      return;
    }
    if (Platform.isMacOS) {
      await Process.start('open', [sourcePath]);
      return;
    }
    await Process.start('xdg-open', [sourcePath]);
  }

  Future<void> _revealSong(LibrarySong song) async {
    await _revealSongPath(song.path);
  }

  Future<void> _revealSongPath(String songPath) async {
    if (Platform.isWindows) {
      await Process.start('explorer.exe', ['/select,$songPath']);
      return;
    }
    if (Platform.isMacOS) {
      await Process.start('open', ['-R', songPath]);
      return;
    }
    await Process.start('xdg-open', [File(songPath).parent.path]);
  }

  List<MultiSelectCommandBarPlaylist> _customPlaylists(
    List<LibraryPlaylist> playlists,
  ) {
    return playlists
        .where((playlist) => !playlist.isBuiltIn)
        .map(
          (playlist) => MultiSelectCommandBarPlaylist(
            id: playlist.id,
            name: playlist.name,
            songIds: playlist.songIds,
          ),
        )
        .toList();
  }
}

class _SearchSectionData {
  const _SearchSectionData.cards({
    required this.type,
    required this.cards,
    required this.previewLimit,
  }) : songs = const [];

  const _SearchSectionData.songs({
    required this.songs,
    required this.previewLimit,
  }) : type = SearchResultType.songs,
       cards = const [];

  final SearchResultType type;
  final List<SearchResult> cards;
  final List<LibrarySong> songs;
  final int previewLimit;

  int get count => type == SearchResultType.songs ? songs.length : cards.length;

  List<String> visibleKeys(bool preview) {
    final itemCount = (preview ? count.clamp(0, previewLimit) : count).toInt();
    return type == SearchResultType.songs
        ? [for (final song in songs.take(itemCount)) _songSelectionKey(song)]
        : [
          for (final card in cards.take(itemCount))
            getSearchResultCardKey(type, card),
        ];
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({required this.title, required this.summary});

  final String title;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _SearchColors.textStrong,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          summary,
          style: const TextStyle(
            color: _SearchColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SearchFilterTabs extends StatelessWidget {
  const _SearchFilterTabs({
    required this.i18n,
    required this.activeFilter,
    required this.results,
    required this.onChanged,
  });

  final SmPlayerI18n i18n;
  final SearchFilterKey activeFilter;
  final SearchResults results;
  final ValueChanged<SearchFilterKey> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (SearchFilterKey.all, i18n.t('common.all')),
      (
        SearchFilterKey.artists,
        i18n.t('search.artistsWithCount', {'count': results.artists.length}),
      ),
      (
        SearchFilterKey.albums,
        i18n.t('search.albumsWithCount', {'count': results.albums.length}),
      ),
      (
        SearchFilterKey.songs,
        i18n.t('search.songsWithCount', {'count': results.songs.length}),
      ),
      (
        SearchFilterKey.playlists,
        i18n.t('search.playlistsWithCount', {
          'count': results.playlists.length,
        }),
      ),
      (
        SearchFilterKey.folders,
        i18n.t('search.foldersWithCount', {'count': results.folders.length}),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs) ...[
            _SearchFilterTab(
              label: tab.$2,
              selected: tab.$1 == activeFilter,
              onPressed: () {
                onChanged(tab.$1);
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SearchFilterTab extends StatelessWidget {
  const _SearchFilterTab({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: selected ? _SearchColors.accentSoft : Colors.white,
        foregroundColor: selected ? _SearchColors.accent : _SearchColors.text,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _SearchResultSection extends StatelessWidget {
  const _SearchResultSection({
    required this.section,
    required this.i18n,
    required this.showCount,
    required this.mediaControlState,
    required this.selection,
    required this.playlists,
    required this.songsById,
    required this.onViewAll,
    required this.onViewLess,
    required this.onSortChanged,
    required this.onSelectionChanged,
    required this.onOpenCard,
    required this.onPlaySongs,
    required this.onPlayCard,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onAddSongsToPlaylist,
    required this.onToggleSongsFavorite,
    required this.onCreatePlaylist,
    required this.onOpenMusicDialog,
    required this.onPreviewAlbumArt,
    required this.onSearchDirectory,
    required this.onRevealCard,
    required this.onRevealSong,
  });

  final _SearchSectionData section;
  final SmPlayerI18n i18n;
  final bool showCount;
  final MediaControlState mediaControlState;
  final PageSelectionController<String> selection;
  final List<MultiSelectCommandBarPlaylist> playlists;
  final Map<int, LibrarySong> songsById;
  final VoidCallback onViewAll;
  final VoidCallback onViewLess;
  final ValueChanged<SearchSortCriterion> onSortChanged;
  final VoidCallback onSelectionChanged;
  final ValueChanged<SearchResult> onOpenCard;
  final ValueChanged<List<int>> onPlaySongs;
  final ValueChanged<SearchResult> onPlayCard;
  final void Function(LibrarySong, int) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<LibrarySong> onPlayNext;
  final Future<void> Function(int, List<int>) onAddSongsToPlaylist;
  final Future<void> Function(List<int>, bool) onToggleSongsFavorite;
  final Future<void> Function(String, List<int>) onCreatePlaylist;
  final void Function(LibrarySong, SongDialogMode) onOpenMusicDialog;
  final ValueChanged<SearchResult> onPreviewAlbumArt;
  final ValueChanged<SearchResult> onSearchDirectory;
  final ValueChanged<SearchResult> onRevealCard;
  final ValueChanged<LibrarySong> onRevealSong;

  @override
  Widget build(BuildContext context) {
    final preview =
        searchFilterKeyFromType(section.type.name) != SearchFilterKey.all &&
        _isAllFilter(context);
    final visibleCount = preview ? section.previewLimit : section.count;
    final showViewToggle = section.count > section.previewLimit;
    final sortOptions = getSortOptions(section.type, i18n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _sectionTitle(section.type, section.count),
              style: const TextStyle(
                color: _SearchColors.textStrong,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            PopupMenuButton<SearchSortCriterion>(
              tooltip: i18n.t('common.sort'),
              onSelected: onSortChanged,
              itemBuilder:
                  (context) => [
                    for (final option in sortOptions)
                      PopupMenuItem<SearchSortCriterion>(
                        value: option.value,
                        child: Text(option.label),
                      ),
                  ],
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(FluentIcons.arrow_sort_20_regular, size: 20),
              ),
            ),
            if (showViewToggle)
              TextButton(
                onPressed: preview ? onViewAll : onViewLess,
                child: Text(
                  preview
                      ? i18n.t('search.viewAll')
                      : i18n.t('search.viewLess'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (section.type == SearchResultType.songs)
          _buildSongs(context, visibleCount)
        else
          _buildCards(context, visibleCount),
      ],
    );
  }

  bool _isAllFilter(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    return searchFilterKeyFromType(uri.queryParameters['type']) ==
        SearchFilterKey.all;
  }

  String _sectionTitle(SearchResultType type, int count) {
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
              _showSongContextMenu(context, position, songs[index]);
            },
          ),
      ],
    );
  }

  Widget _buildCards(BuildContext context, int visibleCount) {
    if (section.type == SearchResultType.albums) {
      return Wrap(
        spacing: 10,
        runSpacing: 12,
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
              onAddAlbum: () {
                onPlaySongs(card.songIds);
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

    return Wrap(
      spacing: 10,
      runSpacing: 12,
      children: [
        for (final card in section.cards.take(visibleCount))
          _SearchResultCard(
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
          ),
      ],
    );
  }

  void _showSongContextMenu(
    BuildContext context,
    Offset position,
    LibrarySong song,
  ) {
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: [song.id],
      playlists: playlists,
      includeNowPlaying: true,
      includeFavorites: !song.favorite,
      onAddToNowPlaying: () {
        onPlayNext(song);
      },
      onToggleFavorite: () {
        onToggleSongsFavorite([song.id], true);
      },
      onCreatePlaylist: () {
        onCreatePlaylist(song.title, [song.id]);
      },
      onAddToPlaylist: (playlistId) {
        onAddSongsToPlaylist(playlistId, [song.id]);
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
            onPlaySongs([song.id]);
          },
        ),
        MenuFlyoutItem(
          key: 'play-next',
          text: i18n.t('context.playNext'),
          icon: FluentIcons.next_20_regular,
          onPressed: () {
            onPlayNext(song);
          },
        ),
        if (addToItem != null) addToItem,
        MenuFlyoutItem(
          key: 'view',
          text: i18n.t('context.view'),
          icon: FluentIcons.eye_20_regular,
          submenu: [
            MenuFlyoutItem(
              key: 'see-music-info',
              text: i18n.t('context.seeMusicInfo'),
              icon: FluentIcons.info_20_regular,
              onPressed: () {
                onOpenMusicDialog(song, SongDialogMode.properties);
              },
            ),
            MenuFlyoutItem(
              key: 'see-lyrics',
              text: i18n.t('context.seeLyrics'),
              icon: FluentIcons.text_quote_20_regular,
              onPressed: () {
                onOpenMusicDialog(song, SongDialogMode.lyrics);
              },
            ),
            MenuFlyoutItem(
              key: 'see-album-art',
              text: i18n.t('context.seeAlbumArt'),
              icon: FluentIcons.image_20_regular,
              onPressed: () {
                onOpenMusicDialog(song, SongDialogMode.albumArt);
              },
            ),
            MenuFlyoutItem(
              key: 'see-local-file',
              text: i18n.t('context.seeLocalFile'),
              icon: FluentIcons.folder_open_20_regular,
              onPressed: () {
                onRevealSong(song);
              },
            ),
          ],
        ),
        const MenuFlyoutItem.separator(key: 'selection-separator'),
        MenuFlyoutItem(
          key: 'select',
          text: i18n.t('context.select'),
          icon: FluentIcons.select_all_on_20_regular,
          onPressed: () {
            selection.enterMultiSelect();
            if (!selection.isSelected(_songSelectionKey(song))) {
              selection.toggle(_songSelectionKey(song));
            }
            onSelectionChanged();
          },
        ),
      ],
    );
  }

  void _showCardContextMenu(
    BuildContext context,
    Offset position,
    SearchResult card,
  ) {
    final cardKey = getSearchResultCardKey(section.type, card);
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: card.songIds,
      playlists: playlists,
      includeNowPlaying: true,
      includeFavorites: true,
      onAddToNowPlaying: () {
        onPlaySongs(card.songIds);
      },
      onToggleFavorite: () {
        onToggleSongsFavorite(card.songIds, true);
      },
      onCreatePlaylist: () {
        onCreatePlaylist(card.title, card.songIds);
      },
      onAddToPlaylist: (playlistId) {
        onAddSongsToPlaylist(playlistId, card.songIds);
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
            onPlayCard(card);
          },
        ),
        if (addToItem != null) addToItem,
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
            key: 'search-directory',
            text: i18n.t('local.searchDirectory'),
            icon: FluentIcons.search_20_regular,
            onPressed: () {
              onSearchDirectory(card);
            },
          ),
          MenuFlyoutItem(
            key: 'reveal',
            text: i18n.t('context.reveal'),
            icon: FluentIcons.folder_open_20_regular,
            onPressed: () {
              onRevealCard(card);
            },
          ),
        ],
        const MenuFlyoutItem.separator(key: 'selection-separator'),
        MenuFlyoutItem(
          key: 'select',
          text: i18n.t('context.select'),
          icon: FluentIcons.select_all_on_20_regular,
          onPressed: () {
            selection.enterMultiSelect();
            if (!selection.isSelected(cardKey)) {
              selection.toggle(cardKey);
            }
            onSelectionChanged();
          },
        ),
      ],
    );
  }
}

class _SearchAlbumArtPreviewDialog extends StatelessWidget {
  const _SearchAlbumArtPreviewDialog({
    required this.card,
    required this.onClose,
  });

  final SearchResult card;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final artworkFile = card.artworkUrl.isEmpty ? null : File(card.artworkUrl);

    return PopupDialog(
      overlayClassName: 'album-art-preview-overlay AlbumArtPreviewOverlay',
      className: 'album-art-preview-dialog AlbumArtPreviewDialog',
      navClassName: 'album-art-preview-nav AlbumArtPreviewNav',
      navLabel: i18n.t('context.seeAlbumArt'),
      ariaLabel: card.title,
      width: 560,
      height: 620,
      onClose: onClose,
      navChildren: [
        Expanded(
          child: Text(
            card.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PopupDialogColors.textStrong,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
      child: Center(
        child:
            artworkFile != null && artworkFile.existsSync()
                ? Container(
                  width: 420,
                  height: 420,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2932423a),
                        blurRadius: 42,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.file(artworkFile, fit: BoxFit.cover),
                )
                : SizedBox.square(
                  dimension: 420,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xffe8eef5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          FluentIcons.image_24_regular,
                          color: PopupDialogColors.textMuted,
                          size: 48,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          i18n.t('song.noAlbumArt'),
                          style: const TextStyle(
                            color: PopupDialogColors.textMuted,
                            fontWeight: FontWeight.w700,
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

class _SearchResultCard extends StatefulWidget {
  const _SearchResultCard({
    required this.card,
    required this.type,
    required this.selected,
    required this.multiSelect,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSelection,
    required this.onOpenContextMenu,
  });

  final SearchResult card;
  final SearchResultType type;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final VoidCallback onToggleSelection;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final artworkFile =
        widget.card.artworkUrl.isEmpty ? null : File(widget.card.artworkUrl);

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
      child: GestureDetector(
        onTap: widget.multiSelect ? widget.onToggleSelection : widget.onOpen,
        onSecondaryTapDown: (details) {
          widget.onOpenContextMenu(details.globalPosition);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 190,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                widget.selected || _hovered ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow:
                widget.selected
                    ? const [
                      BoxShadow(
                        color: Color(0x1f1f2a38),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ]
                    : null,
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.square(
                      dimension: 166,
                      child:
                          artworkFile != null && artworkFile.existsSync()
                              ? Image.file(artworkFile, fit: BoxFit.cover)
                              : DecoratedBox(
                                decoration: const BoxDecoration(
                                  color: _SearchColors.artwork,
                                ),
                                child: Icon(
                                  _cardIcon(widget.type),
                                  color: _SearchColors.artworkIcon,
                                  size: 42,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.card.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _SearchColors.textStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.card.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _SearchColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (_hovered && !widget.multiSelect)
                Positioned(
                  top: 116,
                  right: 8,
                  child: SizedBox.square(
                    dimension: 34,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xb81e2228),
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(FluentIcons.play_20_filled, size: 17),
                      onPressed: widget.onPlay,
                    ),
                  ),
                ),
              if (widget.multiSelect || widget.selected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color:
                          widget.selected ? _SearchColors.accent : Colors.white,
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

  IconData _cardIcon(SearchResultType type) {
    return switch (type) {
      SearchResultType.artists => FluentIcons.people_24_regular,
      SearchResultType.playlists => FluentIcons.apps_list_detail_24_regular,
      SearchResultType.folders => FluentIcons.folder_24_regular,
      SearchResultType.albums => FluentIcons.album_24_regular,
      SearchResultType.songs => FluentIcons.music_note_2_24_regular,
    };
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _SearchColors.textMuted,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
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

class _SearchColors {
  const _SearchColors._();

  static const accent = Color(0xff0063b1);
  static const accentSoft = Color(0x1a0078d7);
  static const text = Color(0xff344054);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const artwork = Color(0xffe8eef5);
  static const artworkIcon = Color(0xff607085);
}
