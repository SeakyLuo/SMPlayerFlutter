part of 'library_providers.dart';

final recentPageDataProvider =
    AsyncNotifierProvider.autoDispose<RecentPageNotifier, RecentPageData>(
      RecentPageNotifier.new,
    );

class RecentPageNotifier extends AutoDisposeAsyncNotifier<RecentPageData> {
  @override
  Future<RecentPageData> build() {
    final repository = ref.watch(libraryRepositoryProvider);
    final source = ref.watch(
      musicShareProvider.select((share) => share.selectedSource),
    );
    final changes = libraryHistoryChanges.stream.listen((change) {
      if (change.device != source) return;
      if (change.scope == recentHistoryScope) {
        ref.invalidateSelf();
      } else if (change.scope == playedHistoryScope ||
          change.scope == browsedHistoryScope) {
        unawaited(_refreshHistory(repository, source, change.scope));
      }
    });
    ref.onDispose(() {
      _queueHistoryRevision++;
      _historyReads.clear();
      changes.cancel();
    });
    return repository
        .dataSource(LibrarySource.fromDevice(source))
        .readRecentData();
  }

  final _historyReads = <String, Object>{};

  Future<void> _refreshHistory(
    LibraryRepository repository,
    String source,
    String scope,
  ) async {
    final request = Object();
    _historyReads[scope] = request;
    try {
      if (scope == browsedHistoryScope) {
        final data = await readRecentBrowseSection(repository, source);
        if (!identical(_historyReads[scope], request)) return;
        await future;
        if (!identical(_historyReads[scope], request)) return;
        state = state.whenData(
          (snapshot) => snapshot.copyWith(
            recentBrowses: data.entries,
            recentBrowseSongs: data.songs,
          ),
        );
      } else {
        final data = await readRecentPlayedSection(repository, source);
        if (!identical(_historyReads[scope], request)) return;
        await future;
        if (!identical(_historyReads[scope], request)) return;
        state = state.whenData(
          (snapshot) => snapshot.copyWith(
            recentSongs: data.songs,
            recentPlaylists: data.playlists,
            recentAlbums: data.albums,
            recentArtists: data.artists,
            recentNowPlaying: data.nowPlaying,
          ),
        );
      }
    } catch (error, stack) {
      SystemLog.error(
        'Recent history section could not be updated',
        error,
        stack,
      );
    } finally {
      if (identical(_historyReads[scope], request)) _historyReads.remove(scope);
    }
  }

  ({
    List<LibrarySong> songs,
    List<RecentLibrarySong> recentSongs,
    List<LibrarySong> recentQueueSongs,
    List<LibrarySong> recentBrowseSongs,
  })?
  removeDeletedSongs(Set<int> ids, Set<String> paths) {
    final current = state.valueOrNull;
    if (current == null) return null;
    bool deleted(LibrarySong song) =>
        ids.contains(song.id) || paths.contains(song.path);
    final played = ref.read(recentSongsProvider);
    final removed = (
      songs: current.songs.where(deleted).toList(),
      recentSongs: played.where(deleted).toList(),
      recentQueueSongs: current.recentQueueSongs.where(deleted).toList(),
      recentBrowseSongs: current.recentBrowseSongs.where(deleted).toList(),
    );
    if (removed.songs.isEmpty &&
        removed.recentSongs.isEmpty &&
        removed.recentQueueSongs.isEmpty &&
        removed.recentBrowseSongs.isEmpty) {
      return null;
    }
    state = state.whenData(
      (data) => data.copyWith(
        songs: data.songs.where((song) => !deleted(song)).toList(),
        recentSongs: played.where((song) => !deleted(song)).toList(),
        recentQueueSongs:
            data.recentQueueSongs.where((song) => !deleted(song)).toList(),
        recentBrowseSongs:
            data.recentBrowseSongs.where((song) => !deleted(song)).toList(),
      ),
    );
    return removed;
  }

  void restoreDeletedSongs({
    required List<LibrarySong> songs,
    required List<RecentLibrarySong> recentSongs,
    required List<LibrarySong> recentQueueSongs,
    required List<LibrarySong> recentBrowseSongs,
  }) {
    final played = ref.read(recentSongsProvider);
    state = state.whenData(
      (data) => data.copyWith(
        songs:
            {
              for (final song in songs) song.id: song,
              for (final song in data.songs) song.id: song,
            }.values.toList(),
        recentSongs:
            {
                for (final song in recentSongs) song.id: song,
                for (final song in played) song.id: song,
              }.values.toList()
              ..sort(
                (left, right) => int.parse(
                  right.playedAt,
                ).compareTo(int.parse(left.playedAt)),
              ),
        recentQueueSongs:
            {
              for (final song in recentQueueSongs) song.id: song,
              for (final song in data.recentQueueSongs) song.id: song,
            }.values.toList(),
        recentBrowseSongs:
            {
              for (final song in recentBrowseSongs) song.id: song,
              for (final song in data.recentBrowseSongs) song.id: song,
            }.values.toList(),
      ),
    );
  }

  Future<void> updateQueueHistory(RecentNowPlayingSnapshot record) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final currentSongs = {
      for (final song in current.songs) song.id,
      for (final song in current.recentQueueSongs) song.id,
    };
    final missing = record.songIds.take(4).toSet().difference(currentSongs);
    final revision = _queueHistoryRevision;
    final songs =
        missing.isEmpty
            ? const <LibrarySong>[]
            : await ref
                .read(libraryRepositoryProvider)
                .getLibrarySongs(songIds: missing.toList());
    if (revision != _queueHistoryRevision) return;
    state = state.whenData((data) {
      final ordered = [record, ...data.recentNowPlaying]
        ..sort((left, right) => right.id.compareTo(left.id));
      final seen = <int>{};
      final history =
          ordered
              .where((entry) => seen.add(entry.playlistId))
              .take(RecentNowPlayingSnapshot.limit)
              .toList();
      final previews = {for (final entry in history) ...entry.songIds.take(4)};
      return data.copyWith(
        recentNowPlaying: history,
        recentQueueSongs:
            {
              for (final song in [...songs, ...data.recentQueueSongs])
                if (previews.contains(song.id)) song.id: song,
            }.values.toList(),
      );
    });
  }

  int _queueHistoryRevision = 0;

  void clearPlayedHistory() {
    _queueHistoryRevision++;
    state = state.whenData(
      (data) => data.copyWith(
        recentSongs: const [],
        recentPlaylists: const [],
        recentAlbums: const [],
        recentArtists: const [],
        recentNowPlaying: const [],
        recentQueueSongs: const [],
      ),
    );
  }

  void updateSongDetails(List<LibrarySong> songs) {
    final byId = {for (final song in songs) song.id: song};
    final played = ref.read(recentSongsProvider);
    state = state.whenData(
      (data) => data.copyWith(
        songs: [for (final song in data.songs) byId[song.id] ?? song],
        recentSongs: [
          for (final song in played)
            if (byId[song.id] case final updated?)
              RecentLibrarySong.fromSong(updated, playedAt: song.playedAt)
            else
              song,
        ],
        recentQueueSongs: [
          for (final song in data.recentQueueSongs) byId[song.id] ?? song,
        ],
        recentBrowseSongs: [
          for (final song in data.recentBrowseSongs) byId[song.id] ?? song,
        ],
      ),
    );
  }
}
