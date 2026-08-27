part of 'music_dialog.dart';

extension _MusicDialogStateLyricsActions on _MusicDialogState {
  Future<void> _saveLyrics() async {
    final sessionKey = _dialogSessionKey;
    final sessionState = ref.read(musicDialogLyricsStateProvider(sessionKey));
    if (sessionState.operation != null || _lyricsSearchInProgress) {
      _showMessage(context.smPlayerI18n.t('song.processingRequest'));
      return;
    }
    if (!_lyricsDirty) {
      _showMessage(context.smPlayerI18n.t('song.nothingChanged'));
      return;
    }
    final i18n = context.smPlayerI18n;
    final nextRawText = _currentLyricsRawText;
    final notifier = ref.read(
      musicDialogLyricsStateProvider(sessionKey).notifier,
    );
    notifier.begin(MusicDialogOperation.saveLyrics);
    try {
      await ref
          .read(libraryRepositoryProvider)
          .saveSongLyrics(widget.song.id, nextRawText);
      if (!mounted || _dialogSessionKey != sessionKey) {
        return;
      }
      _lyricsRawText = nextRawText;
      _originalLyricsText = nextRawText;
      _lyrics = _lyricsWithRawText(_lyrics, nextRawText);
      _notifySaved();
      notifyLyricsSaved(ref, widget.song.id);
      notifier.finish(dirty: false, refresh: true);
      _showMessage(i18n.t('song.lyricsUpdated', {'title': widget.song.title}));
    } catch (_) {
      if (mounted && _dialogSessionKey == sessionKey) {
        notifier.finish(dirty: _lyricsDirty);
        _showMessage(i18n.t('song.updateFailed'));
      }
    }
  }

  void _queuePendingLyricsNotificationIfNeeded({
    required int songId,
    required String title,
    required String rawLyrics,
    required bool refreshLatestLyrics,
  }) {
    final sessionKey = _dialogSessionKey;
    final dirty = ref.read(musicDialogLyricsStateProvider(sessionKey)).dirty;
    if (_mode != SongDialogMode.lyrics || !dirty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _showPendingLyricsNotification(
        songId: songId,
        title: title,
        rawLyrics: rawLyrics,
        refreshLatestLyrics: refreshLatestLyrics,
        sessionKey: sessionKey,
      );
    });
  }

  void _showPendingLyricsNotification({
    required int songId,
    required String title,
    required String rawLyrics,
    required bool refreshLatestLyrics,
    required MusicDialogSessionKey sessionKey,
  }) {
    final i18n = context.smPlayerI18n;
    showAppNotification(
      context: context,
      message: i18n.t('song.pendingSaveLyrics', {'title': title}),
      duration: undoableNotificationDuration,
      actions: [
        AppNotificationAction(
          label: i18n.t('song.saveImmediately'),
          onPressed: () {
            return _savePendingLyricsSnapshot(
              songId: songId,
              title: title,
              rawLyrics: rawLyrics,
              refreshLatestLyrics: refreshLatestLyrics,
              sessionKey: sessionKey,
            );
          },
        ),
        AppNotificationAction(
          label: i18n.t('song.discardChanges'),
          onPressed: () {
            if (mounted &&
                _dialogSessionKey == sessionKey &&
                songId == widget.song.id) {
              _updatingControllers = true;
              _lyricsRawText = _originalLyricsText;
              _lyricsController.text =
                  _showLyricsTimestamps
                      ? _originalLyricsText
                      : _stripLyricsTimestamps(_originalLyricsText);
              _updatingControllers = false;
              ref
                  .read(musicDialogLyricsStateProvider(sessionKey).notifier)
                  .updateLyricsEditor(
                    dirty: false,
                    canToggleTimestamps: _lyricsCanToggleTimestamps,
                    refresh: true,
                  );
            }
          },
        ),
      ],
    );
  }

  Future<void> _savePendingLyricsSnapshot({
    required int songId,
    required String title,
    required String rawLyrics,
    required bool refreshLatestLyrics,
    required MusicDialogSessionKey sessionKey,
  }) async {
    final i18n = context.smPlayerI18n;
    try {
      await ref
          .read(libraryRepositoryProvider)
          .saveSongLyrics(songId, rawLyrics);
      if (!mounted) {
        return;
      }
      if (_dialogSessionKey == sessionKey && songId == widget.song.id) {
        _lyricsRawText = rawLyrics;
        _originalLyricsText = rawLyrics;
        _lyrics = _lyricsWithRawText(_lyrics, rawLyrics);
        widget.onSaved?.call();
        ref
            .read(musicDialogLyricsStateProvider(sessionKey).notifier)
            .updateLyricsEditor(
              dirty: _lyricsDirty,
              canToggleTimestamps: _lyricsCanToggleTimestamps,
              refresh: true,
            );
      }
      notifyLyricsSaved(ref, songId);
      if (refreshLatestLyrics) {
        _showMessage(
          i18n.t('song.lyricsUpdatedAndRefreshed', {
            'savedTitle': title,
            'currentTitle': _currentTrackTitle(),
          }),
        );
      } else {
        _showMessage(i18n.t('song.lyricsUpdated', {'title': title}));
      }
    } catch (_) {
      if (mounted) {
        _showMessage(i18n.t('song.updateFailed'));
      }
    }
  }

  Future<void> _searchLyrics() async {
    final sessionKey = _dialogSessionKey;
    final lyricsState = ref.read(musicDialogLyricsStateProvider(sessionKey));
    if (lyricsState.operation != null || _lyricsSearchInProgress) {
      _showMessage(context.smPlayerI18n.t('song.processingRequest'));
      return;
    }
    final i18n = context.smPlayerI18n;
    final songId = widget.song.id;
    try {
      final repository = ref.read(libraryRepositoryProvider);
      late final List<InternetLyricsCandidate> candidates;
      try {
        candidates =
            await ref
                .read(
                  internetLyricsCandidateSearchProvider(sessionKey).notifier,
                )
                .search();
      } catch (_) {
        if (!mounted ||
            _dialogSessionKey != sessionKey ||
            widget.song.id != songId) {
          return;
        }
        _showMessage(i18n.t('song.searchLyricsRequestFailed'));
        return;
      }
      if (!mounted ||
          _dialogSessionKey != sessionKey ||
          widget.song.id != songId) {
        return;
      }
      if (candidates.length == 1) {
        await _applyInternetLyricsCandidate(candidates.single);
        return;
      }
      if (candidates.isNotEmpty) {
        _updateDialogStructure(() {
          _lyricsSearchCandidates = candidates;
          _lyricsSearchPickerOpen = true;
        });
        return;
      }

      await repository.openLyricsSearchInBrowser(songId);
      if (mounted &&
          _dialogSessionKey == sessionKey &&
          widget.song.id == songId) {
        _showMessage(i18n.t('song.openBrowserSuccessful'));
      }
    } catch (_) {
      if (mounted &&
          _dialogSessionKey == sessionKey &&
          widget.song.id == songId) {
        _showMessage(i18n.t('song.searchLyricsRequestFailed'));
      }
    }
  }

  Future<void> _applyInternetLyricsCandidate(
    InternetLyricsCandidate candidate,
  ) async {
    final sessionKey = _dialogSessionKey;
    final songId = widget.song.id;
    final i18n = context.smPlayerI18n;
    final snapshot = candidate.lyrics;
    final nextText =
        _showLyricsTimestamps
            ? snapshot.rawText
            : _stripLyricsTimestamps(snapshot.rawText);
    if (_lyricsController.text == nextText) {
      if (_dialogSessionKey != sessionKey || widget.song.id != songId) {
        return;
      }
      _updateDialogStructure(() {
        _lyricsSearchPickerOpen = false;
      });
      _showMessage(i18n.t('song.nothingChanged'));
      return;
    }
    if (_lyricsDirty) {
      final confirmed = await showPopupConfirmDialog(
        context: context,
        title: i18n.t('song.replaceUnsavedLyricsTitle'),
        message: i18n.t('song.replaceUnsavedLyricsMessage'),
        confirmLabel: i18n.t('common.confirm'),
        i18n: i18n,
      );
      if (!mounted ||
          !confirmed ||
          _dialogSessionKey != sessionKey ||
          widget.song.id != songId) {
        return;
      }
    }
    if (!mounted ||
        _dialogSessionKey != sessionKey ||
        widget.song.id != songId) {
      return;
    }

    _updatingControllers = true;
    _lyrics = snapshot;
    _lyricsRawText = snapshot.rawText;
    _lyricsController.text = nextText;
    _updatingControllers = false;
    ref
        .read(musicDialogLyricsStateProvider(sessionKey).notifier)
        .updateLyricsEditor(
          dirty: _lyricsDirty,
          canToggleTimestamps: _lyricsCanToggleTimestamps,
          refresh: true,
        );
    _updateDialogStructure(() {
      _lyricsSearchPickerOpen = false;
    });
    _scrollLyricsToTop();
    _showMessage(i18n.t('song.searchLyricsSuccessful'));
  }

  Future<void> _importLyrics() async {
    final sessionKey = _dialogSessionKey;
    final sessionState = ref.read(musicDialogLyricsStateProvider(sessionKey));
    if (sessionState.operation != null || _lyricsSearchInProgress) {
      _showMessage(context.smPlayerI18n.t('song.processingRequest'));
      return;
    }
    final i18n = context.smPlayerI18n;
    final notifier = ref.read(
      musicDialogLyricsStateProvider(sessionKey).notifier,
    );
    notifier.begin(MusicDialogOperation.importLyrics);
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: i18n.t('song.importLyrics'),
        type: FileType.custom,
        allowedExtensions: _lyricsImportExtensions,
      );
      final filePath = result?.files.single.path;
      if (!mounted || _dialogSessionKey != sessionKey) {
        return;
      }
      if (filePath == null) {
        notifier.finish(dirty: _lyricsDirty);
        return;
      }

      final rawText = await ref
          .read(libraryRepositoryProvider)
          .readLyricsFromFile(filePath);
      if (!mounted || _dialogSessionKey != sessionKey) {
        return;
      }
      _updatingControllers = true;
      _lyricsRawText = rawText;
      _lyricsController.text =
          _showLyricsTimestamps ? rawText : _stripLyricsTimestamps(rawText);
      _updatingControllers = false;
      _scrollLyricsToTop();
      notifier.finish(dirty: _lyricsDirty, refresh: true);
      notifier.updateLyricsEditor(
        dirty: _lyricsDirty,
        canToggleTimestamps: _lyricsCanToggleTimestamps,
      );
    } catch (_) {
      if (mounted && _dialogSessionKey == sessionKey) {
        notifier.finish(dirty: _lyricsDirty);
        _showMessage(i18n.t('song.importLyricsFailed'));
      }
    }
  }
}
