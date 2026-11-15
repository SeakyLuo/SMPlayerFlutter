part of 'search_page.dart';

class _SearchPageDataCache {
  (LibraryContentData, String, String, SmPlayerI18n)? _metadataKey;
  late SearchResults _metadata;
  (SearchResults, _LyricsWindow)? _lyricsKey;
  late SearchResults _results;
  (
    SearchResults,
    SearchFilterKey,
    SearchSortCriterion,
    SearchSortCriterion,
    SearchSortCriterion,
    SearchSortCriterion,
    SearchSortCriterion,
    SearchSortCriterion,
  )?
  _sectionsKey;
  late List<_SearchSectionData> _sections;

  void updateMetadata(
    LibraryContentData snapshot,
    String query,
    String folder,
    SmPlayerI18n i18n,
    Map<int, String>? songFolderPaths,
  ) {
    final key = (snapshot, query, folder, i18n);
    if (_metadataKey == key) return;
    final folders =
        folder.isEmpty
            ? snapshot.folders
            : snapshot.folders
                .where((item) => isFolderUnderFolder(item.path, folder))
                .toList();
    final legacy = buildSearchResults(
      const [],
      folders,
      buildSearchablePlaylists(snapshot.playlists),
      snapshot.rootPath,
      query,
      i18n,
      snapshot.favoritePlaylistId,
      snapshot.nowPlaying.playlistId,
    );
    SearchResult artistCard(LibraryArtistSummary item) {
      final title =
          item.name.isEmpty ? i18n.t('common.artistUnknown') : item.name;
      return SearchResult(
        title: title,
        subtitle: i18n.t('artists.artistSummary', {
          'albums': item.albumCount,
          'songs': item.songCount,
        }),
        artworkUrl: item.artworkPath,
        path: '/artists?artist=${Uri.encodeQueryComponent(title)}',
        score: evaluateString(title, query),
        songCount: item.songCount,
        playCount: item.playCount,
        duration: item.duration,
        albumCount: item.albumCount,
        songIds: const [],
        scope: LibraryDataQuery(
          LibraryQueryKind.artist,
          artists: [item.name],
          folder: folder.isEmpty ? null : folder,
        ),
      );
    }

    SearchResult albumCard(LibraryAlbumSummary item) {
      final title =
          item.name.isEmpty ? i18n.t('common.albumUnknown') : item.name;
      final artistScore = item.artists
          .map((name) => evaluateString(name, query) - 10)
          .fold(0, (a, b) => a > b ? a : b);
      final titleScore = evaluateString(title, query);
      return SearchResult(
        title: title,
        subtitle: item.artists.join(', '),
        artworkUrl: item.artworkPath,
        path: '/albums?album=${Uri.encodeQueryComponent(title)}',
        score: titleScore > artistScore ? titleScore : artistScore,
        songCount: item.songCount,
        playCount: item.playCount,
        duration: item.duration,
        albumCount: 0,
        songIds: const [],
        scope: LibraryDataQuery(
          LibraryQueryKind.album,
          album: item.name,
          folder: folder.isEmpty ? null : folder,
        ),
      );
    }

    _metadata = SearchResults(
      artists: [
        for (final item in snapshot.artistSummaries)
          if ((item.name.isEmpty ? i18n.t('common.artistUnknown') : item.name)
              .toLowerCase()
              .contains(query))
            artistCard(item),
      ]..sort((a, b) => b.score.compareTo(a.score)),
      albums: [
        for (final item in snapshot.albumSummaries)
          if ((item.name.isEmpty ? i18n.t('common.albumUnknown') : item.name)
                  .toLowerCase()
                  .contains(query) ||
              item.artists.any((name) => name.toLowerCase().contains(query)))
            albumCard(item),
      ]..sort((a, b) => b.score.compareTo(a.score)),
      songs: snapshot.songs,
      totalSongs: snapshot.totalSongCount,
      songRows: snapshot.songRows,
      lyrics: const [],
      playlists: [
        for (final card in legacy.playlists)
          SearchResult(
            title: card.title,
            subtitle: card.subtitle,
            artworkUrl: card.artworkUrl,
            path: card.path,
            score: card.score,
            songCount: card.songCount,
            playCount:
                snapshot.playlists
                    .firstWhere((p) => '${p.id}' == card.sourceId)
                    .playCount,
            duration:
                snapshot.playlists
                    .firstWhere((p) => '${p.id}' == card.sourceId)
                    .duration,
            albumCount: 0,
            sourceId: card.sourceId,
            songIds:
                snapshot.playlists
                    .firstWhere((p) => '${p.id}' == card.sourceId)
                    .songIds,
          ),
      ],
      folders: [
        for (final item in snapshot.folderSummaries)
          if (evaluateString(getPathLabel(item.path), query) > 0 ||
              evaluateString(item.path, query) > 0)
            SearchResult(
              title: getPathLabel(item.path),
              subtitle: i18n.t('cards.songCount', {'count': item.songCount}),
              artworkUrl: item.artworkPaths.firstOrNull ?? '',
              path: '/local',
              score: evaluateString(getPathLabel(item.path), query),
              songCount: item.songCount,
              playCount: item.playCount,
              duration: item.duration,
              albumCount: 0,
              songIds: const [],
              sourceId:
                  snapshot.folders
                      .where((folder) => folder.path == item.path)
                      .firstOrNull
                      ?.id
                      .toString(),
              sourcePath: item.path,
              localFolderRelativePath: getRelativeFolderPath(
                item.path,
                snapshot.rootPath,
              ),
              scope: LibraryDataQuery(
                LibraryQueryKind.songs,
                folder: item.path,
              ),
            ),
      ],
    );
    _metadataKey = key;
  }

  SearchResults results(_LyricsWindow window) {
    final key = (_metadata, window);
    if (_lyricsKey != key) {
      _results = SearchResults(
        artists: _metadata.artists,
        albums: _metadata.albums,
        songs: _metadata.songs,
        totalSongs: _metadata.totalSongs,
        songRows: _metadata.songRows,
        lyrics: window.rows.values.toList(),
        totalLyrics: window.total,
        lyricsRows: window.rows,
        playlists: _metadata.playlists,
        folders: _metadata.folders,
      );
      _lyricsKey = key;
    }
    return _results;
  }

  List<_SearchSectionData> sections(
    SearchResults results,
    SearchCriteria criteria,
    SearchFilterKey filter,
    List<_SearchSectionData> Function() build,
  ) {
    final key = (
      results,
      filter,
      criteria.artists,
      criteria.albums,
      criteria.songs,
      criteria.lyrics,
      criteria.playlists,
      criteria.folders,
    );
    if (_sectionsKey != key) {
      _sections = build();
      _sectionsKey = key;
    }
    return _sections;
  }
}
