part of 'music_dialog.dart';

extension _MusicDialogStateHelpers on _MusicDialogState {
  List<String> _normalizeArtists(List<String> values) {
    final seen = <String>{};
    final artists = <String>[];
    for (final value in values) {
      for (final artist in value
          .split(RegExp(r'\s*(?:;|；|、|\|)\s*'))
          .map((artist) => artist.trim())
          .where((artist) => artist.isNotEmpty)) {
        final key = artist.toLowerCase();
        if (seen.add(key)) {
          artists.add(artist);
        }
      }
    }
    return artists;
  }

  int _parseElectronNumericField(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  void _requestClose() {
    if (!_lyricsDirty) {
      widget.onClose();
      return;
    }
    if (_discardLyricsConfirmOpen) {
      return;
    }

    unawaited(_confirmDiscardLyricsAndClose());
  }

  Future<void> _confirmDiscardLyricsAndClose() async {
    final i18n = context.smPlayerI18n;
    _discardLyricsConfirmOpen = true;
    try {
      final confirmed = await showPopupConfirmDialog(
        context: context,
        title: i18n.t('common.confirm'),
        message: i18n.t('song.discardLyricsConfirm'),
        confirmLabel: i18n.t('common.confirm'),
        i18n: i18n,
      );
      if (mounted && confirmed) {
        widget.onClose();
      }
    } finally {
      _discardLyricsConfirmOpen = false;
    }
  }

  void _play() {
    final currentTrackId = widget.currentTrackId;
    final isCurrentSong =
        currentTrackId == widget.song.id ||
        (currentTrackId == null && widget.canPause);
    if (isCurrentSong) {
      widget.onPlay?.call();
      return;
    }

    widget.onPlayTrack?.call(widget.song.id, _playQueueSongIds);
  }

  List<int> get _playQueueSongIds {
    if (widget.queueSongIds.contains(widget.song.id)) {
      return widget.queueSongIds;
    }
    return [...widget.queueSongIds, widget.song.id];
  }

  void _notifySaved() {
    ref.invalidate(libraryContentDataProvider);
    ref.invalidate(recentPageDataProvider);
    widget.onSaved?.call();
  }

  void _syncSongMutation(LibrarySong song, SmPlayerI18n i18n) {
    patchLibrarySongOverride(ref, song);
    ref
        .read(mediaControlControllerProvider)
        .updateTrackMetadata(mediaControlTrackForSong(song, i18n));
  }

  LibrarySong _songWithProperties(SongPropertiesSnapshot properties) {
    final song =
        ref.read(librarySongOverridesProvider)[widget.song.id] ?? widget.song;
    return song.copyWith(
      title: properties.title,
      artist: properties.artist,
      artists: properties.artists,
      album: properties.album,
      playCount: properties.playCount,
    );
  }

  LibrarySong _songWithArtwork(String thumbnailPath) {
    final song =
        ref.read(librarySongOverridesProvider)[widget.song.id] ?? widget.song;
    return song.copyWith(thumbnailPath: thumbnailPath);
  }

  void _scrollLyricsToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_lyricsScrollController.hasClients) {
        return;
      }
      _lyricsScrollController.jumpTo(0);
    });
  }

  String _currentTrackTitle() {
    final currentTrackId = widget.currentTrackId;
    if (currentTrackId == null) {
      return widget.song.title;
    }
    final songs =
        ref.read(libraryContentDataProvider).valueOrNull?.songs ??
        const <LibrarySong>[];
    return songs
            .where((song) => song.id == currentTrackId)
            .firstOrNull
            ?.title ??
        widget.song.title;
  }

  bool get _propertiesDirty {
    final original = _originalProperties;
    if (original == null) {
      return false;
    }

    return _titleController.text != original.title ||
        _subtitleController.text != original.subtitle ||
        _albumController.text != original.album ||
        _albumArtistController.text != original.albumArtist ||
        _publisherController.text != original.publisher ||
        _trackNumberController.text !=
            (original.trackNumber == 0
                ? ''
                : original.trackNumber.toString()) ||
        _yearController.text !=
            (original.year == 0 ? '' : original.year.toString()) ||
        _playCountController.text != original.playCount.toString() ||
        _artistControllers.map((controller) => controller.text).join('\n') !=
            original.artists.join('\n');
  }

  bool _isPropertiesModified(
    SongPropertiesSnapshot current,
    SongPropertiesSnapshot original,
  ) {
    return current.title != original.title ||
        current.subtitle != original.subtitle ||
        current.artist != original.artist ||
        current.artists.join('\n') != original.artists.join('\n') ||
        current.album != original.album ||
        current.albumArtist != original.albumArtist ||
        current.publisher != original.publisher ||
        current.trackNumber != original.trackNumber ||
        current.year != original.year ||
        current.playCount != original.playCount;
  }

  String get _currentLyricsRawText {
    return _showLyricsTimestamps
        ? _lyricsController.text
        : _mergePlainLyricsWithTimedRaw(_lyricsRawText, _lyricsController.text);
  }

  bool get _lyricsDirty => _currentLyricsRawText != _originalLyricsText;

  bool get _artworkDirty => _artworkSourcePath.isNotEmpty;

  bool get _lyricsCanToggleTimestamps {
    return RegExp(
      r'\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\]',
    ).hasMatch(_lyricsRawText);
  }

  String _dialogTabLabel(String label) {
    return label
        .replaceFirst(RegExp(r'^查看\s*'), '')
        .replaceFirst(RegExp(r'^See\s+', caseSensitive: false), '');
  }

  void _showMessage(String message) {
    showAppNotification(context: context, message: message);
  }

  String _formatTagList(String value) {
    return value.split(', ').join(context.smPlayerI18n.t('common.comma'));
  }
}
