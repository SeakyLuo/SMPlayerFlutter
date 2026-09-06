import 'dart:async';
import 'dart:io';

import 'library_page_data_cache.dart';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/album_artwork_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/album_tile.dart';
import 'package:smplayer_flutter/src/library/ui/artwork_floating_action_button.dart';
import 'package:smplayer_flutter/src/library/ui/grid_artwork_card_content.dart';
import 'package:smplayer_flutter/src/library/ui/grid_view_holder.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/multi_select_command_bar.dart';
import 'package:smplayer_flutter/src/library/ui/library_page_actions.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_card.dart';
import 'package:smplayer_flutter/src/library/ui/local_folder_model.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/page_selection_store.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/search_artist_card.dart';
import 'package:smplayer_flutter/src/library/ui/search_match_text.dart';
import 'package:smplayer_flutter/src/library/ui/search_page_model.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart'
    as song_display;
import 'package:smplayer_flutter/src/library/ui/song_artwork.dart';
import 'package:smplayer_flutter/src/platform/desktop_feature_service.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/playback_queue_actions.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

part 'search_page_data.dart';
part 'search_page_content.dart';
part 'search_filter_tabs.dart';
part 'search_page_shell.dart';
part 'search_result_cards.dart';
part 'search_result_sections.dart';
part 'search_theme.dart';

const _searchPageHorizontalInset = 8.0;

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({
    super.key,
    required this.query,
    required this.activeType,
    this.folderRelativePath,
  });

  final String query;
  final String? activeType;
  final String? folderRelativePath;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const _artistPreviewLimit = 10;
  static const _sectionPreviewLimit = 5;
  static const _lyricsSearchRevision = 3;

  late final SettingsController _settingsController;
  final _selection = PageSelectionController<String>.stored('search');
  final _appBarPortalOwner = Object();
  String? _appBarPortalSignature;
  late final VoidCallback _clearAppBarPortalOwner;
  var _settings = const SettingsSnapshot.defaults();
  late var _activeFilter = searchFilterKeyFromType(widget.activeType);
  MusicDialogEntry? _musicDialog;
  String? _musicDialogLyricsMatch;
  SearchResult? _albumArtPreview;
  final _expandedSections = <SearchResultType>{};
  var _lyricsCriterion = SearchSortCriterion.defaultCriterion;
  var _lyricsMatches = const <LocalLyricsSearchMatch>[];
  var _lyricsSearchLoading = false;
  LocalLyricsIndexProgress? _lyricsIndexProgress;
  String? _lyricsSearchSignature;
  var _lyricsSearchGeneration = 0;
  final _dataCache = LibraryPageDataCache();
  final _searchCache = _SearchPageDataCache();

  void _updateSearchPageState(VoidCallback update) => setState(update);

  @override
  void initState() {
    super.initState();
    final appBarPortalNotifier = ref.read(
      workspaceAppBarPortalProvider.notifier,
    );
    _clearAppBarPortalOwner = () {
      clearWorkspaceAppBarPortalOwnerAfterDispose(
        appBarPortalNotifier,
        _appBarPortalOwner,
      );
    };
    _settingsController = SettingsController(
      null,
      ref.read(libraryRepositoryProvider),
    );
    _restoreSettings();
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextFilter = searchFilterKeyFromType(widget.activeType);
    if (oldWidget.query != widget.query ||
        oldWidget.folderRelativePath != widget.folderRelativePath) {
      _expandedSections.clear();
      _selection.cancel();
      _activeFilter = SearchFilterKey.all;
      _musicDialog = null;
      _musicDialogLyricsMatch = null;
      _albumArtPreview = null;
      _lyricsSearchSignature = null;
      _lyricsSearchGeneration += 1;
      _lyricsMatches = const [];
      _lyricsSearchLoading = false;
      _lyricsIndexProgress = null;
      return;
    }
    if (nextFilter != _activeFilter) {
      _activeFilter = nextFilter;
      _selection.cancel();
    }
  }

  @override
  void dispose() {
    _clearAppBarPortalOwner();
    _settingsController.dispose();
    super.dispose();
  }

  void _syncAppBarPortal({
    required bool showPortal,
    required SmPlayerI18n i18n,
    required String title,
    required SearchResults results,
  }) {
    final signature =
        '$showPortal:$title:$_activeFilter:${results.artists.length}:'
        '${results.albums.length}:${results.songs.length}:'
        '${results.lyrics.length}:${_lyricsIndexProgress != null}:'
        '${results.playlists.length}:${results.folders.length}';
    if (_appBarPortalSignature == signature) {
      return;
    }
    _appBarPortalSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final notifier = ref.read(workspaceAppBarPortalProvider.notifier);
      if (!showPortal) {
        if (notifier.state?.owner == _appBarPortalOwner) {
          notifier.state = null;
        }
        return;
      }
      notifier.state = WorkspaceAppBarPortalEntry(
        owner: _appBarPortalOwner,
        routePath: '/search',
        title: title,
        content: const SizedBox.shrink(),
        bottomContent: _SearchHeaderSurface(
          child: _SearchFilterTabs(
            i18n: i18n,
            activeFilter: _activeFilter,
            results: results,
            lyricsIndexing: _lyricsIndexProgress != null,
            onChanged: _changeFilter,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => _buildSearchPage(context);

  List<_SearchSectionData> _visibleSections(List<_SearchSectionData> sections) {
    final filtered =
        _activeFilter == SearchFilterKey.all
            ? sections.where((section) => section.count > 0).toList()
            : sections
                .where(
                  (section) =>
                      section.count > 0 &&
                      _filterForSection(section.type) == _activeFilter,
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
    setState(() {
      _activeFilter = filter;
      _selection.cancel();
    });
    context.go(
      Uri(
        path: '/search',
        queryParameters: {
          'query': widget.query.trim(),
          if (filter != SearchFilterKey.all) 'type': type,
          if (widget.folderRelativePath?.isNotEmpty == true)
            'folder': widget.folderRelativePath!,
        },
      ).toString(),
    );
  }

  String _searchTitle(SmPlayerI18n i18n) {
    final query = widget.query.trim();
    final folder = widget.folderRelativePath ?? '';
    if (query.isNotEmpty && folder.isNotEmpty) {
      return i18n.t('search.directoryResultOf', {
        'query': query,
        'folder': folder.split('/').last,
      });
    }
    return query.isNotEmpty
        ? i18n.t('search.resultOf', {'query': query})
        : i18n.t('search.resultTitle');
  }

  bool _isSectionExpanded(SearchResultType type) {
    return _activeFilter != SearchFilterKey.all ||
        _expandedSections.contains(type);
  }

  void _toggleExpandedSection(SearchResultType type) {
    setState(() {
      if (_expandedSections.contains(type)) {
        _expandedSections.remove(type);
      } else {
        _expandedSections.add(type);
      }
    });
  }

  void _syncLocalLyricsSearch({
    required String query,
    required String folderPath,
    required int lyricsSavedRevision,
    required int librarySnapshotIdentity,
  }) {
    final signature =
        '$_lyricsSearchRevision\u0000$query\u0000$folderPath\u0000'
        '$lyricsSavedRevision\u0000'
        '$librarySnapshotIdentity';
    if (_lyricsSearchSignature == signature) {
      return;
    }
    _lyricsSearchSignature = signature;
    _lyricsMatches = const [];
    final generation = ++_lyricsSearchGeneration;
    final queryLength = query.trim().runes.length;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || generation != _lyricsSearchGeneration) {
        return;
      }
      if (queryLength < 2) {
        setState(() {
          _lyricsMatches = const [];
          _lyricsSearchLoading = false;
          _lyricsIndexProgress = null;
        });
        _leaveEmptyLyricsFilter();
        return;
      }

      setState(() {
        _lyricsMatches = const [];
        _lyricsSearchLoading = true;
        _lyricsIndexProgress = null;
      });
      final repository = ref.read(libraryRepositoryProvider);
      try {
        final matches = await repository.searchLocalLyrics(
          query,
          folderPath: folderPath,
        );
        if (!mounted || generation != _lyricsSearchGeneration) {
          return;
        }
        setState(() {
          _lyricsMatches = matches;
          _lyricsSearchLoading = false;
        });
      } catch (_) {
        if (!mounted || generation != _lyricsSearchGeneration) {
          return;
        }
        setState(() {
          _lyricsMatches = const [];
          _lyricsSearchLoading = false;
          _lyricsIndexProgress = null;
        });
        _leaveEmptyLyricsFilter();
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t('search.lyricsSearchFailed'),
        );
        return;
      }

      try {
        await repository.indexMissingLocalLyrics(
          onProgress: (progress) {
            if (!mounted || generation != _lyricsSearchGeneration) {
              return;
            }
            setState(() {
              _lyricsIndexProgress = progress;
            });
          },
        );
        if (!mounted || generation != _lyricsSearchGeneration) {
          return;
        }
        setState(() {
          _lyricsIndexProgress = null;
        });
      } catch (_) {
        if (!mounted || generation != _lyricsSearchGeneration) {
          return;
        }
        setState(() {
          _lyricsIndexProgress = null;
        });
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t('search.lyricsSearchFailed'),
        );
      }
    });
  }

  void _leaveEmptyLyricsFilter() {
    if (_activeFilter == SearchFilterKey.lyrics) {
      _changeFilter(SearchFilterKey.all);
    }
  }

  bool _showSearchStatus(
    SearchResults results,
    List<_SearchSectionData> visibleSections,
  ) {
    if (_activeFilter != SearchFilterKey.all &&
        _activeFilter != SearchFilterKey.lyrics) {
      return visibleSections.isEmpty;
    }
    if (widget.query.trim().runes.length < 2) {
      return _activeFilter == SearchFilterKey.lyrics;
    }
    if (_lyricsSearchLoading &&
        (_activeFilter == SearchFilterKey.all ||
            _activeFilter == SearchFilterKey.lyrics)) {
      return false;
    }
    if (_activeFilter == SearchFilterKey.lyrics &&
        _lyricsIndexProgress != null) {
      return false;
    }
    return _activeFilter == SearchFilterKey.lyrics
        ? results.lyrics.isEmpty
        : _totalCount(results) == 0;
  }

  String _lyricsSearchStatusMessage(SmPlayerI18n i18n, String query) {
    if (query.trim().runes.length < 2) {
      return i18n.t('search.lyricsMinimumQuery');
    }
    return i18n.t('search.noResult');
  }

  String _lyricsIndexProgressMessage(SmPlayerI18n i18n) {
    final progress = _lyricsIndexProgress!;
    return i18n.t('search.lyricsPreparingProgress', {
      'current': progress.current,
      'total': progress.total,
    });
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
    late final AppSettingsUpdate update;
    switch (type) {
      case SearchResultType.lyrics:
        setState(() {
          _lyricsCriterion = criterion;
        });
        return;
      case SearchResultType.artists:
        update = AppSettingsUpdate(searchArtistsCriterion: criterion);
      case SearchResultType.albums:
        update = AppSettingsUpdate(searchAlbumsCriterion: criterion);
      case SearchResultType.songs:
        update = AppSettingsUpdate(searchSongsCriterion: criterion);
      case SearchResultType.playlists:
        update = AppSettingsUpdate(searchPlaylistsCriterion: criterion);
      case SearchResultType.folders:
        update = AppSettingsUpdate(searchFoldersCriterion: criterion);
    }
    await _settingsController.updateSettings(update);
    if (!mounted) {
      return;
    }

    setState(() {
      _settings = _settingsController.snapshot;
    });
  }

  Future<String?> _getSearchResultPreferenceLevel(
    SearchResultType type,
    SearchResult card,
  ) async {
    final preferenceType = _searchResultPreferenceType(type);
    if (preferenceType == null) {
      return null;
    }
    return ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel(
          preferenceType,
          _searchResultPreferenceId(preferenceType, card),
        );
  }

  Future<void> _setSearchResultPreference(
    SearchResultType type,
    SearchResult card,
    String level,
  ) async {
    final preferenceType = _searchResultPreferenceType(type);
    if (preferenceType == null) {
      return;
    }
    await ref
        .read(libraryRepositoryProvider)
        .addPreferenceItem(
          preferenceType,
          _searchResultPreferenceId(preferenceType, card),
          card.title,
          level,
        );
  }

  Future<void> _undoSearchResultPreference(
    SearchResultType type,
    SearchResult card,
  ) async {
    final preferenceType = _searchResultPreferenceType(type);
    if (preferenceType == null) {
      return;
    }
    await ref
        .read(libraryRepositoryProvider)
        .removePreferenceItem(
          preferenceType,
          _searchResultPreferenceId(preferenceType, card),
        );
  }

  Future<String?> _getSongPreferenceLevel(LibrarySong song) {
    return ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('song', '${song.id}');
  }

  Future<void> _setSongPreference(LibrarySong song, String level) async {
    await ref
        .read(libraryRepositoryProvider)
        .addPreferenceItem('song', '${song.id}', song.title, level);
  }

  Future<void> _undoSongPreference(LibrarySong song) async {
    await ref
        .read(libraryRepositoryProvider)
        .removePreferenceItem('song', '${song.id}');
  }

  int _totalCount(SearchResults results) {
    final metadataSongIds = results.songs.map((song) => song.id).toSet();
    return results.artists.length +
        results.albums.length +
        results.songs.length +
        results.lyrics
            .where((result) => !metadataSongIds.contains(result.song.id))
            .length +
        results.playlists.length +
        results.folders.length;
  }

  List<String> _selectableKeys(List<_SearchSectionData> sections) {
    return [
      for (final section in _visibleSections(sections))
        ...section.visibleKeys(),
    ];
  }

  int _selectedItemCount(List<_SearchSectionData> visibleSections) {
    final selectedKeys = _selection.selectedItems;
    var count = 0;
    for (final section in visibleSections) {
      if (section.type == SearchResultType.songs) {
        for (final song in section.songs) {
          if (selectedKeys.contains(_songSelectionKey(song))) {
            count += 1;
          }
        }
      } else if (section.type == SearchResultType.lyrics) {
        for (final result in section.lyrics) {
          if (selectedKeys.contains(_songSelectionKey(result.song))) {
            count += 1;
          }
        }
      } else {
        for (final card in section.cards) {
          if (selectedKeys.contains(
            getSearchResultCardKey(section.type, card),
          )) {
            count += 1;
          }
        }
      }
    }
    return count;
  }

  List<int> _selectedSongIds(List<_SearchSectionData> visibleSections) {
    final songIds = <int>[];
    final selectedKeys = _selection.selectedItems;
    for (final section in visibleSections) {
      if (section.type == SearchResultType.songs) {
        for (final song in section.songs) {
          if (selectedKeys.contains(_songSelectionKey(song))) {
            songIds.add(song.id);
          }
        }
      } else if (section.type == SearchResultType.lyrics) {
        for (final result in section.lyrics) {
          if (selectedKeys.contains(_songSelectionKey(result.song))) {
            songIds.add(result.song.id);
          }
        }
      } else {
        for (final card in section.cards) {
          if (selectedKeys.contains(
            getSearchResultCardKey(section.type, card),
          )) {
            songIds.addAll(card.songIds);
          }
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
        final params = {'path': card.localFolderRelativePath ?? ''};
        context.go(Uri(path: '/local', queryParameters: params).toString());
      case SearchResultType.songs:
      case SearchResultType.lyrics:
        break;
    }
  }

  void _playCard(SearchResultType type, SearchResult card) {
    if (type == SearchResultType.artists) {
      unawaited(recordRecentArtistPlayback(ref, card.title));
    }
    _playSongIds(shuffleSearchSongIds(card.songIds));
  }

  void _playTrack(LibrarySong song, int index, List<int> songIds) {
    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).value!,
      i18n: context.smPlayerI18n,
      songIds: songIds,
      queueIndex: index,
    );
  }

  void _playSongIds(List<int> songIds) {
    if (songIds.isEmpty) {
      return;
    }

    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).value!,
      i18n: context.smPlayerI18n,
      songIds: songIds,
      queueIndex: 0,
    );
  }

  void _playNext(LibrarySong song) {
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final previousSongIds = currentNowPlayingSongIds(ref, snapshot);
    final queueSongIds = previousSongIds.toList();
    queueSongIds.remove(song.id);
    final insertIndex = insertIndexAfterCurrentOccurrence(
      ref.read(mediaControlControllerProvider).state,
      queueSongIds,
    );
    queueSongIds.insert(insertIndex, song.id);
    setNowPlayingQueue(ref, queueSongIds);
    showPlayNextUndoNotification(
      context: context,
      i18n: context.smPlayerI18n,
      songTitle: song.title,
      onUndo: () {
        setNowPlayingQueue(ref, previousSongIds);
      },
    );
  }

  Future<void> _createPlaylist(String name, List<int> songIds) async {
    await createPlaylistAndSync(
      context: context,
      ref: ref,
      i18n: context.smPlayerI18n,
      name: name,
      songIds: songIds,
    );
  }

  void _openMusicDialog(
    LibrarySong song,
    SongDialogMode mode,
    List<int> queueSongIds,
  ) {
    setState(() {
      _musicDialog = (song: song, mode: mode, queueSongIds: queueSongIds);
      _musicDialogLyricsMatch = null;
      _albumArtPreview = null;
    });
  }

  void _openLyricsMatch(SearchLyricsResult result, List<int> queueSongIds) {
    setState(() {
      _musicDialog = (
        song: result.song,
        mode: SongDialogMode.lyrics,
        queueSongIds: queueSongIds,
      );
      _musicDialogLyricsMatch = result.match.snippet;
      _albumArtPreview = null;
    });
  }

  void _showAlbumArtPreview(SearchResult card) {
    setState(() {
      _albumArtPreview = card;
      _musicDialog = null;
      _musicDialogLyricsMatch = null;
    });
  }

  Future<void> _searchDirectory(SearchResult card) async {
    final i18n =
        ref.read(smPlayerI18nProvider).value ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    final query = await showPopupTextDialog(
      context: context,
      title: i18n.t('local.searchDirectoryPrompt', {'name': card.title}),
      initialValue: '',
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
    await openFolderInShell(card.sourcePath!);
  }

  Future<void> _revealSong(LibrarySong song) async {
    await _revealSongPath(song.path);
  }

  Future<void> _revealSongPath(String songPath) async {
    await revealItemInFolder(songPath);
  }

  void _deleteSong(LibrarySong song) {
    unawaited(
      requestDeleteSongFromDisk(
        context: context,
        ref: ref,
        i18n: context.smPlayerI18n,
        song: song,
      ),
    );
  }

  void _openArtist(String artist) {
    context.go('/artists?artist=${Uri.encodeQueryComponent(artist)}');
  }

  void _openAlbum(String album) {
    final albumName =
        album.isEmpty ? context.smPlayerI18n.t('common.albumUnknown') : album;
    context.go('/albums?album=${Uri.encodeQueryComponent(albumName)}');
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

String _searchFolderPath(String rootPath, String? folderRelativePath) {
  final relativePath = folderRelativePath ?? '';
  if (relativePath.isEmpty) {
    return '';
  }

  final separator = rootPath.contains('\\') ? '\\' : '/';
  final normalizedRoot = rootPath.replaceFirst(RegExp(r'[\\/]+$'), '');
  return '$normalizedRoot$separator${relativePath.split('/').join(separator)}';
}
