part of 'music_dialog.dart';

extension _MusicDialogStateLoadActions on _MusicDialogState {
  Future<void> _loadSong() async {
    final generation = ++_loadGeneration;
    final songId = widget.song.id;
    final repository = ref.read(libraryRepositoryProvider);
    _updateState(() {
      _loading = true;
      _lyricsLoading = true;
      _artworkLoading = true;
      _artworkDeletePending = false;
      _artworkSourcePath = '';
      _artworkRecommendation = null;
      _artworkRecommendationLoading = false;
      _artworkRecommendationRequestKey = '';
      _libraryArtworkPickerOpen = false;
    });

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
    try {
      final properties = await repository.getSongProperties(songId);
      if (!_isActiveLoad(songId, generation)) {
        return;
      }

      _updateState(() {
        _applyProperties(properties);
        _loading = false;
      });
    } catch (_) {}
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

      _updateState(() {
        _lyrics = lyrics;
        _lyricsRawText = lyrics.rawText;
        _originalLyricsText = lyrics.rawText;
        _lyricsController.text = lyrics.rawText;
        _lyricsLoading = false;
      });
      _selectInitialLyricsMatch();
    } catch (_) {
      if (_isActiveLoad(songId, generation)) {
        _updateState(() {
          _lyricsLoading = false;
        });
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

      _updateState(() {
        _displayArtworkUrl = artwork.artworkUrl;
        _originalDisplayArtworkUrl = artwork.artworkUrl;
        _artworkMissing =
            artwork.source == SongArtworkSource.none ||
            artwork.artworkUrl.isEmpty;
        _originalArtworkMissing = _artworkMissing;
        _artworkLoading = false;
      });
      await _resolveDisplayArtwork(repository, songId, generation);
      await _loadArtworkRecommendation();
    } catch (_) {
      if (_isActiveLoad(songId, generation)) {
        _updateState(() {
          _artworkLoading = false;
        });
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
    _updateState(() {
      _displayArtworkUrl = snapshot.artworkUrl;
      _originalDisplayArtworkUrl = snapshot.artworkUrl;
    });
  }

  bool _isActiveLoad(int songId, int generation) {
    return mounted && _loadGeneration == generation && widget.song.id == songId;
  }

  Future<void> _loadArtworkRecommendation() async {
    if (!_artworkMissing || _artworkRecommendationLoading) {
      _artworkRecommendation = null;
      return;
    }

    final i18n = context.smPlayerI18n;
    final songs = ref.read(libraryContentDataProvider).valueOrNull?.songs;
    if (songs == null) {
      return;
    }

    final requestKey = _albumArtRecommendationRequestKey(widget.song, songs);
    if (requestKey == _artworkRecommendationRequestKey) {
      return;
    }
    _artworkRecommendationRequestKey = requestKey;

    final candidates = _getAlbumArtRecommendationCandidates(widget.song, songs);
    if (candidates.isEmpty) {
      if (mounted) {
        _updateState(() {
          _artworkRecommendation = null;
        });
      }
      return;
    }

    _updateState(() {
      _artworkRecommendationLoading = true;
    });
    final snapshots = await ref
        .read(libraryRepositoryProvider)
        .getSongArtworkSnapshots(
          candidates.map((candidate) => candidate.song.id).toList(),
        );
    if (!mounted) {
      return;
    }
    if (_artworkRecommendationRequestKey != requestKey) {
      return;
    }
    if (!_artworkMissing) {
      _updateState(() {
        _artworkRecommendationLoading = false;
      });
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
        _updateState(() {
          _artworkRecommendation = AlbumArtRecommendation(
            song: candidate.song,
            artworkUrl: snapshot.artworkUrl,
            sourceUrl: snapshot.sourceUrl,
            sourcePath: snapshot.sourcePath,
            artistName: _getDisplayArtists(candidate.song, i18n),
          );
          _artworkRecommendationLoading = false;
        });
        return;
      }
    }

    _updateState(() {
      _artworkRecommendation = null;
      _artworkRecommendationLoading = false;
    });
  }
}
