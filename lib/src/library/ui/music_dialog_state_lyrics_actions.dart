part of 'music_dialog.dart';

extension _MusicDialogStateLyricsActions on _MusicDialogState {
  Future<void> _saveLyrics() async {
    if (_saving) {
      _showMessage(context.smPlayerI18n.t('song.processingRequest'));
      return;
    }
    if (!_lyricsDirty) {
      _showMessage(context.smPlayerI18n.t('song.nothingChanged'));
      return;
    }
    final i18n = context.smPlayerI18n;
    final nextRawText = _currentLyricsRawText;

    _updateState(() {
      _saving = true;
    });
    try {
      await ref
          .read(libraryRepositoryProvider)
          .saveSongLyrics(widget.song.id, nextRawText);
      if (!mounted) {
        return;
      }
      _lyricsRawText = nextRawText;
      _originalLyricsText = nextRawText;
      _lyrics = _lyricsWithRawText(_lyrics, nextRawText);
      _notifySaved();
      notifyLyricsSaved(ref, widget.song.id);
      _showMessage(i18n.t('song.lyricsUpdated', {'title': widget.song.title}));
    } catch (_) {
      if (mounted) {
        _showMessage(i18n.t('song.updateFailed'));
      }
    } finally {
      if (mounted) {
        _updateState(() {
          _saving = false;
        });
      }
    }
  }

  void _queuePendingLyricsNotificationIfNeeded({
    required int songId,
    required String title,
    required String rawLyrics,
    required bool refreshLatestLyrics,
  }) {
    if (_mode != SongDialogMode.lyrics || !_lyricsDirty) {
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
      );
    });
  }

  void _showPendingLyricsNotification({
    required int songId,
    required String title,
    required String rawLyrics,
    required bool refreshLatestLyrics,
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
            );
          },
        ),
        AppNotificationAction(
          label: i18n.t('song.discardChanges'),
          onPressed: () {
            if (mounted && songId == widget.song.id) {
              _updateState(() {
                _lyricsRawText = _originalLyricsText;
                _lyricsController.text =
                    _showLyricsTimestamps
                        ? _originalLyricsText
                        : _stripLyricsTimestamps(_originalLyricsText);
              });
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
  }) async {
    final i18n = context.smPlayerI18n;
    _updateState(() {
      _saving = true;
    });
    try {
      await ref
          .read(libraryRepositoryProvider)
          .saveSongLyrics(songId, rawLyrics);
      if (!mounted) {
        return;
      }
      if (songId == widget.song.id) {
        _lyricsRawText = rawLyrics;
        _originalLyricsText = rawLyrics;
        _lyrics = _lyricsWithRawText(_lyrics, rawLyrics);
        widget.onSaved?.call();
        _updateState(() {});
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
    } finally {
      if (mounted) {
        _updateState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _searchLyrics() async {
    if (_saving) {
      _showMessage(context.smPlayerI18n.t('song.processingRequest'));
      return;
    }
    final i18n = context.smPlayerI18n;
    final beforeText = _lyricsController.text;
    _updateState(() {
      _saving = true;
    });
    try {
      final repository = ref.read(libraryRepositoryProvider);
      late final LyricsSnapshot snapshot;
      try {
        snapshot = await repository.getInternetLyrics(widget.song.id);
      } catch (_) {
        await repository.openLyricsSearchInBrowser(widget.song.id);
        if (!mounted) {
          return;
        }
        _showMessage(i18n.t('song.openBrowserSuccessful'));
        return;
      }
      if (!mounted) {
        return;
      }
      if (snapshot.rawText.trim().isNotEmpty) {
        final nextText =
            _showLyricsTimestamps
                ? snapshot.rawText
                : _stripLyricsTimestamps(snapshot.rawText);
        final unchanged = beforeText == nextText;
        _lyrics = snapshot;
        _lyricsRawText = snapshot.rawText;
        _lyricsController.text = nextText;
        if (!unchanged) {
          _scrollLyricsToTop();
        }
        _showMessage(
          unchanged
              ? i18n.t('song.nothingChanged')
              : i18n.t('song.searchLyricsSuccessful'),
        );
        return;
      }

      await repository.openLyricsSearchInBrowser(widget.song.id);
      if (!mounted) {
        return;
      }
      _showMessage(i18n.t('song.openBrowserSuccessful'));
    } catch (_) {
      if (mounted) {
        _showMessage(i18n.t('song.searchLyricsFailed'));
      }
    } finally {
      if (mounted) {
        _updateState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _importLyrics() async {
    if (_saving) {
      _showMessage(context.smPlayerI18n.t('song.processingRequest'));
      return;
    }
    final i18n = context.smPlayerI18n;

    _updateState(() {
      _saving = true;
    });
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: i18n.t('song.importLyrics'),
        type: FileType.custom,
        allowedExtensions: _lyricsImportExtensions,
      );
      final filePath = result?.files.single.path;
      if (filePath == null) {
        return;
      }

      final rawText = await ref
          .read(libraryRepositoryProvider)
          .readLyricsFromFile(filePath);
      if (!mounted) {
        return;
      }
      _lyricsRawText = rawText;
      _lyricsController.text =
          _showLyricsTimestamps ? rawText : _stripLyricsTimestamps(rawText);
      _scrollLyricsToTop();
      _updateState(() {});
    } catch (_) {
      if (mounted) {
        _showMessage(i18n.t('song.importLyricsFailed'));
      }
    } finally {
      if (mounted) {
        _updateState(() {
          _saving = false;
        });
      }
    }
  }
}
