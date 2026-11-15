import 'library_scope_access.dart';
import '../../playback/source_group_play.dart';
import '../data/library_repository.dart';
import '../../remote/music_source_selector.dart';
import 'library_song_placeholder.dart';
import '../../app/loading_state.dart';
import '../../remote/music_source_providers.dart';
import '../../remote/remote_directory_provider.dart';
import 'local_page_remote.dart';
import 'library_load_failure.dart';
import 'dart:async';
import 'dart:io';

import 'library_page_data_cache.dart';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/edge_auto_hide_scrollbar.dart';
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
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    hide MusicLibrarySortCriterion;

part 'search_page_data.dart';
part 'search_page_queries.dart';
part 'search_page_lyrics_search.dart';
part 'search_lyrics_window.dart';
part 'search_page_content.dart';
part 'search_filter_tabs.dart';
part 'search_page_shell.dart';
part 'search_result_cards.dart';
part 'search_result_sections.dart';
part 'search_result_card_menus.dart';
part 'search_song_hover_actions.dart';
part 'search_lyrics_excerpt.dart';
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
  var _lyricsSearchLoading = false;
  LocalLyricsIndexProgress? _lyricsIndexProgress;
  String? _lyricsSearchSignature;
  var _lyricsSearchGeneration = 0;
  final _dataCache = LibraryPageDataCache();
  final _searchCache = _SearchPageDataCache();
  String? _selectionSource;
  LibraryDataQuery? _songQuery;
  LibraryDataQuery? _lyricsQuery;
  final _attemptedLyricsWindows = <int>{};
  final _attemptedSongWindows = <int>{};

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
        '${results.albums.length}:${results.songCount}:'
        '${results.lyricsCount}:${_lyricsIndexProgress != null}:'
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
          source: ref.read(musicShareProvider).selectedSource,
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
          source: ref.read(musicShareProvider).selectedSource,
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
          source: ref.read(musicShareProvider).selectedSource,
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
    return results.artists.length +
        results.albums.length +
        results.songCount +
        results.lyricsCount +
        results.playlists.length +
        results.folders.length;
  }

  List<String> _selectableKeys(List<_SearchSectionData> sections) {
    return [
      for (final section in _visibleSections(sections))
        ...section.visibleKeys(),
    ];
  }

  int _selectedItemCount(List<_SearchSectionData> sections) =>
      _selection.selectedItems.length;

  List<int> _selectedSongIds(List<_SearchSectionData> sections) {
    final source = ref.read(selectedLibraryDataSourceProvider).source.deviceId;
    final ids = {
      for (final key in _selection.selectedItems.where(
        _isSearchSongSelectionKey,
      ))
        int.parse(key.substring('songs:'.length)),
    };
    final artists = <String>[], albums = <String>[], folders = <String>[];
    for (final section in sections) {
      for (final card in section.cards) {
        if (!_selection.isSelected(getSearchResultCardKey(section.type, card)))
          continue;
        final scope = card.scope;
        if (scope == null) {
          ids.addAll(card.songIds);
          continue;
        }
        switch (section.type) {
          case SearchResultType.artists:
            artists.addAll(scope.artists);
          case SearchResultType.albums:
            albums.add(scope.album);
          case SearchResultType.folders:
            folders.add(scope.folder!);
          default:
            break;
        }
      }
    }
    // Resolve each selected aggregation dimension with one set query.
    if (artists.isNotEmpty)
      ids.addAll(
        watchLibraryScopeIds(
              ref,
              LibraryDataQuery(
                LibraryQueryKind.artist,
                source: source,
                artists: artists,
                folder: _songQuery!.folder,
              ),
            ).valueOrNull ??
            const [],
      );
    if (albums.isNotEmpty)
      ids.addAll(
        watchLibraryScopeIds(
              ref,
              LibraryDataQuery(
                LibraryQueryKind.album,
                source: source,
                albumNames: albums,
                folder: _songQuery!.folder,
              ),
            ).valueOrNull ??
            const [],
      );
    if (folders.isNotEmpty)
      ids.addAll(
        watchLibraryScopeIds(
              ref,
              LibraryDataQuery(
                LibraryQueryKind.songs,
                source: source,
                recursiveFolders: folders,
              ),
            ).valueOrNull ??
            const [],
      );
    return ids.toList();
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

  Future<void> _playCard(SearchResultType type, SearchResult card) =>
      runMusicShareAction(context, () async {
        final ids = await _cardIds(card);
        if (!mounted) return;
        if (type == SearchResultType.artists)
          await recordRecentArtistPlayback(ref, card.title);
        _playSongIds(await sourceShuffleSongIds(ref, ids));
      });

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

  Future<void> _showAlbumArtPreview(SearchResult card) async {
    final ids = await _cardIds(card);
    if (!mounted) return;
    card = card.withIds(ids);
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
