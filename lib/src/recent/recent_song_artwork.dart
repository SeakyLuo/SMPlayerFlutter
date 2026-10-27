part of 'recent_page.dart';

class _RecentSongArtwork extends ConsumerStatefulWidget {
  const _RecentSongArtwork({required this.song});

  final LibrarySong song;

  @override
  ConsumerState<_RecentSongArtwork> createState() => _RecentSongArtworkState();
}

class _RecentSongArtworkState extends ConsumerState<_RecentSongArtwork> {
  Future<String>? _artworkFuture;

  @override
  void initState() {
    super.initState();
    _syncArtworkFuture();
  }

  @override
  void didUpdateWidget(covariant _RecentSongArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id ||
        oldWidget.song.thumbnailPath != widget.song.thumbnailPath) {
      _syncArtworkFuture();
    }
  }

  @override
  Widget build(BuildContext context) {
    final artworkPath = widget.song.thumbnailPath;
    if (artworkPath.isNotEmpty && File(artworkPath).existsSync()) {
      return SongArtwork(artworkPath: artworkPath);
    }
    final future = _artworkFuture;
    if (future == null) {
      return const SongArtwork(artworkPath: '');
    }
    return FutureBuilder<String>(
      future: future,
      builder: (context, snapshot) {
        final path = snapshot.data ?? '';
        return SongArtwork(artworkPath: path);
      },
    );
  }

  void _syncArtworkFuture() {
    final thumbnailPath = widget.song.thumbnailPath;
    if (thumbnailPath.isNotEmpty && File(thumbnailPath).existsSync()) {
      _artworkFuture = null;
      return;
    }
    _artworkFuture = _recentArtworkResolver.resolve(
      ref.read(libraryRepositoryProvider),
      widget.song.id,
    );
  }
}

final _recentArtworkResolver = _RecentArtworkResolver();

class _RecentArtworkResolver {
  final _cache = <String, String>{};
  final _pending = <LibraryRepository, Map<int, Completer<String>>>{};
  Timer? _flushTimer;

  Future<String> resolve(LibraryRepository repository, int songId) {
    final key = _cacheKey(repository, songId);
    final cached = _cache[key];
    if (cached != null) {
      return Future.value(cached);
    }

    final repositoryPending =
        _pending[repository] ?? <int, Completer<String>>{};
    _pending[repository] = repositoryPending;
    final existing = repositoryPending[songId];
    if (existing != null) {
      return existing.future;
    }

    final completer = Completer<String>();
    repositoryPending[songId] = completer;
    _flushTimer ??= Timer(Duration.zero, _flush);
    return completer.future;
  }

  void _flush() {
    _flushTimer = null;
    final pending = Map<LibraryRepository, Map<int, Completer<String>>>.from(
      _pending,
    );
    _pending.clear();
    for (final entry in pending.entries) {
      unawaited(_resolveBatch(entry.key, entry.value));
    }
  }

  Future<void> _resolveBatch(
    LibraryRepository repository,
    Map<int, Completer<String>> completersBySongId,
  ) async {
    final songIds = completersBySongId.keys.toList();
    try {
      final snapshots = await repository.getSongArtworkSnapshots(songIds);
      final pathsBySongId = {
        for (final snapshot in snapshots) snapshot.songId: snapshot.artworkUrl,
      };
      for (final songId in songIds) {
        final path = pathsBySongId[songId] ?? '';
        _cache[_cacheKey(repository, songId)] = path;
        completersBySongId[songId]!.complete(path);
      }
    } on Object catch (error, stackTrace) {
      for (final completer in completersBySongId.values) {
        completer.completeError(error, stackTrace);
      }
    }
  }

  String _cacheKey(LibraryRepository repository, int songId) {
    return '${identityHashCode(repository)}:$songId';
  }
}
