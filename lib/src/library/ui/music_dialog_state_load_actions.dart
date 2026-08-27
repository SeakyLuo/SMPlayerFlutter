part of 'music_dialog.dart';

extension _MusicDialogStateLoadActions on _MusicDialogState {
  Future<void> _loadSong() async {
    final generation = ++_loadGeneration;
    _artworkRecommendationGeneration += 1;
    final songId = widget.song.id;
    final repository = ref.read(libraryRepositoryProvider);
    ref
        .read(musicDialogPropertiesStateProvider(_dialogSessionKey).notifier)
        .reset();
    ref
        .read(musicDialogLyricsStateProvider(_dialogSessionKey).notifier)
        .reset();
    ref
        .read(musicDialogArtworkStateProvider(_dialogSessionKey).notifier)
        .reset();
    _properties = null;
    _originalProperties = null;
    _lyrics = null;
    _lyricsRawText = '';
    _originalLyricsText = '';
    _showLyricsTimestamps = true;
    _updatingControllers = true;
    _lyricsController.clear();
    _updatingControllers = false;
    _displayArtworkUrl = '';
    _originalDisplayArtworkUrl = '';
    _artworkMissing = false;
    _originalArtworkMissing = false;
    _artworkDeletePending = false;
    _artworkSourcePath = '';
    _artworkRecommendation = null;
    _artworkRecommendationRequestKey = '';
    _libraryArtworkPickerOpen = false;
    _lyricsSearchPickerOpen = false;
    _lyricsSearchCandidates = const [];

    await Future.wait<void>([
      _loadProperties(repository, songId, generation),
      _loadLyrics(repository, songId, generation),
      _loadArtwork(repository, songId, generation),
    ]);
  }

  Future<void> _loadProperties(
    LibraryRepository repository,
    int songId,
    int generation,
  ) async {
    final i18n = context.smPlayerI18n;
    try {
      final properties = await repository.getSongProperties(songId);
      if (!_isActiveLoad(songId, generation)) {
        return;
      }

      _applyProperties(properties);
      ref
          .read(musicDialogPropertiesStateProvider(_dialogSessionKey).notifier)
          .loaded();
    } catch (_) {
      if (_isActiveLoad(songId, generation)) {
        ref
            .read(
              musicDialogPropertiesStateProvider(_dialogSessionKey).notifier,
            )
            .loaded();
        _showMessage(i18n.t('song.batchEditLoadFailed'));
      }
    }
  }

  Future<void> _loadLyrics(
    LibraryRepository repository,
    int songId,
    int generation,
  ) async {
    final i18n = context.smPlayerI18n;
    try {
      final lyrics = await repository.getSongLyrics(
        songId,
        mode:
            widget.initialLyricsMatch == null
                ? LyricsRequestMode.embedded
                : LyricsRequestMode.local,
      );
      if (!_isActiveLoad(songId, generation)) {
        return;
      }

      _updatingControllers = true;
      _lyrics = lyrics;
      _lyricsRawText = lyrics.rawText;
      _originalLyricsText = lyrics.rawText;
      _showLyricsTimestamps = true;
      _lyricsController.text = lyrics.rawText;
      _updatingControllers = false;
      ref
          .read(musicDialogLyricsStateProvider(_dialogSessionKey).notifier)
          .loaded(
            showLyricsTimestamps: true,
            lyricsCanToggleTimestamps: _lyricsCanToggleTimestamps,
          );
      _selectInitialLyricsMatch();
    } catch (_) {
      if (_isActiveLoad(songId, generation)) {
        ref
            .read(musicDialogLyricsStateProvider(_dialogSessionKey).notifier)
            .loaded(showLyricsTimestamps: true);
        _showMessage(i18n.t('song.getLyricsFailed'));
      }
    }
  }

  void _selectInitialLyricsMatch() {
    final match = widget.initialLyricsMatch;
    if (match == null) {
      return;
    }
    final start = _lyricsController.text.toLowerCase().indexOf(
      match.toLowerCase(),
    );
    if (start < 0) {
      return;
    }
    _lyricsController.selection = TextSelection(
      baseOffset: start,
      extentOffset: start + match.length,
    );
    final textBeforeMatch = _lyricsController.text.substring(0, start);
    final lineIndex = '\n'.allMatches(textBeforeMatch).length;
    final lineCount = '\n'.allMatches(_lyricsController.text).length + 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_lyricsScrollController.hasClients) {
        return;
      }
      final position = _lyricsScrollController.position;
      final target = position.maxScrollExtent * lineIndex / lineCount;
      _lyricsScrollController.animateTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadArtwork(
    LibraryRepository repository,
    int songId,
    int generation,
  ) async {
    try {
      final artwork = await repository.getSongArtworkSnapshot(songId);
      if (!_isActiveLoad(songId, generation)) {
        return;
      }

      _displayArtworkUrl = artwork.artworkUrl;
      _originalDisplayArtworkUrl = artwork.artworkUrl;
      _artworkMissing =
          artwork.source == SongArtworkSource.none ||
          artwork.artworkUrl.isEmpty;
      _originalArtworkMissing = _artworkMissing;
      ref
          .read(musicDialogArtworkStateProvider(_dialogSessionKey).notifier)
          .loaded();
      await _resolveDisplayArtwork(repository, songId, generation);
      await _loadArtworkRecommendation(dependencyChanged: true);
    } catch (_) {
      if (_isActiveLoad(songId, generation)) {
        ref
            .read(musicDialogArtworkStateProvider(_dialogSessionKey).notifier)
            .loaded();
      }
    }
  }

  Future<void> _resolveDisplayArtwork(
    LibraryRepository repository,
    int songId,
    int generation,
  ) async {
    if (!_artworkMissing || _displayArtworkUrl.isNotEmpty) {
      return;
    }
    final snapshots = await repository.getSongArtworkSnapshots([songId]);
    if (!_isActiveLoad(songId, generation)) {
      return;
    }
    final snapshot = snapshots.single;
    if (snapshot.artworkUrl.isEmpty) {
      return;
    }
    _displayArtworkUrl = snapshot.artworkUrl;
    _originalDisplayArtworkUrl = snapshot.artworkUrl;
    ref
        .read(musicDialogArtworkStateProvider(_dialogSessionKey).notifier)
        .refresh();
  }

  bool _isActiveLoad(int songId, int generation) {
    return mounted && _loadGeneration == generation && widget.song.id == songId;
  }

  Future<void> _loadArtworkRecommendation({
    bool dependencyChanged = false,
    bool librarySnapshotChanged = false,
  }) async {
    final recommendationGeneration =
        dependencyChanged || librarySnapshotChanged
            ? ++_artworkRecommendationGeneration
            : _artworkRecommendationGeneration;
    final sessionKey = _dialogSessionKey;
    if (dependencyChanged || librarySnapshotChanged) {
      _artworkRecommendation = null;
      _artworkRecommendationRequestKey = '';
    }
    final state = ref.read(musicDialogArtworkStateProvider(sessionKey));
    if (!_artworkMissing) {
      _artworkRecommendation = null;
      _artworkRecommendationRequestKey = '';
      ref
          .read(musicDialogArtworkStateProvider(sessionKey).notifier)
          .setRecommendationLoading(false, refresh: true);
      return;
    }
    if (state.recommendationLoading &&
        !dependencyChanged &&
        !librarySnapshotChanged) {
      return;
    }

    final i18n = context.smPlayerI18n;
    final songs = ref.read(libraryContentDataProvider).valueOrNull?.songs;
    if (songs == null) {
      return;
    }

    final requestKey = _albumArtRecommendationRequestKey(widget.song, songs);
    if (!dependencyChanged &&
        !librarySnapshotChanged &&
        requestKey == _artworkRecommendationRequestKey) {
      return;
    }
    _artworkRecommendationRequestKey = requestKey;

    final candidates = _getAlbumArtRecommendationCandidates(widget.song, songs);
    if (candidates.isEmpty) {
      if (mounted &&
          _dialogSessionKey == sessionKey &&
          _artworkRecommendationGeneration == recommendationGeneration) {
        _artworkRecommendation = null;
        ref
            .read(musicDialogArtworkStateProvider(sessionKey).notifier)
            .setRecommendationLoading(false, refresh: true);
      }
      return;
    }

    ref
        .read(musicDialogArtworkStateProvider(sessionKey).notifier)
        .setRecommendationLoading(
          true,
          refresh: dependencyChanged || librarySnapshotChanged,
        );
    late final List<SongArtworkSnapshot> snapshots;
    try {
      snapshots = await ref
          .read(libraryRepositoryProvider)
          .getSongArtworkSnapshots(
            candidates.map((candidate) => candidate.song.id).toList(),
          );
    } catch (_) {
      if (mounted &&
          _dialogSessionKey == sessionKey &&
          _artworkRecommendationGeneration == recommendationGeneration) {
        ref
            .read(musicDialogArtworkStateProvider(sessionKey).notifier)
            .setRecommendationLoading(false);
      }
      return;
    }
    if (!mounted ||
        _dialogSessionKey != sessionKey ||
        _artworkRecommendationGeneration != recommendationGeneration) {
      return;
    }
    if (!_artworkMissing) {
      ref
          .read(musicDialogArtworkStateProvider(sessionKey).notifier)
          .setRecommendationLoading(false);
      return;
    }

    final snapshotsBySongId = {
      for (final snapshot in snapshots) snapshot.songId: snapshot,
    };
    for (final candidate in candidates) {
      final snapshot = snapshotsBySongId[candidate.song.id]!;
      if (snapshot.source != SongArtworkSource.none &&
          snapshot.sourcePath.isNotEmpty &&
          snapshot.sourceUrl.isNotEmpty) {
        _artworkRecommendation = AlbumArtRecommendation(
          song: candidate.song,
          artworkUrl: snapshot.artworkUrl,
          sourceUrl: snapshot.sourceUrl,
          sourcePath: snapshot.sourcePath,
          artistName: _getDisplayArtists(candidate.song, i18n),
        );
        ref
            .read(musicDialogArtworkStateProvider(sessionKey).notifier)
            .setRecommendationLoading(false, refresh: true);
        return;
      }
    }

    _artworkRecommendation = null;
    ref
        .read(musicDialogArtworkStateProvider(sessionKey).notifier)
        .setRecommendationLoading(false, refresh: true);
  }

  void _invalidateArtworkRecommendation() {
    _artworkRecommendationGeneration += 1;
    _artworkRecommendationRequestKey = '';
    _artworkRecommendation = null;
    ref
        .read(musicDialogArtworkStateProvider(_dialogSessionKey).notifier)
        .setRecommendationLoading(false, refresh: true);
  }
}
