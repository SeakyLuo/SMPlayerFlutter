part of 'search_page.dart';

class _SearchPageDataCache {
  (LibraryContentData, String, String, SmPlayerI18n)? _metadataKey;
  late SearchResults _metadata;
  late Map<int, LibrarySong> _songsById;
  (SearchResults, List<LocalLyricsSearchMatch>)? _lyricsKey;
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
  ) {
    final key = (snapshot, query, folder, i18n);
    if (_metadataKey == key) return;
    final songs =
        folder.isEmpty
            ? snapshot.songs
            : snapshot.songs
                .where((song) => isSongUnderFolder(song.path, folder))
                .toList();
    final folders =
        folder.isEmpty
            ? snapshot.folders
            : snapshot.folders
                .where((item) => isFolderUnderFolder(item.path, folder))
                .toList();
    _metadata = buildSearchResults(
      songs,
      folders,
      buildSearchablePlaylists(snapshot.playlists),
      snapshot.rootPath,
      query,
      i18n,
      snapshot.favoritePlaylistId,
      snapshot.nowPlaying.playlistId,
    );
    _songsById = {for (final song in songs) song.id: song};
    _metadataKey = key;
  }

  SearchResults results(List<LocalLyricsSearchMatch> matches) {
    final key = (_metadata, matches);
    if (_lyricsKey != key) {
      _results = SearchResults(
        artists: _metadata.artists,
        albums: _metadata.albums,
        songs: _metadata.songs,
        lyrics: [
          for (final match in matches)
            SearchLyricsResult(song: _songsById[match.songId]!, match: match),
        ],
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
