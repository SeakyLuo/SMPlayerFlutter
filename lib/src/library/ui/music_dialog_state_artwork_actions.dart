part of 'music_dialog.dart';

extension _MusicDialogStateArtworkActions on _MusicDialogState {
  Future<void> _changeArtwork() async {
    if (_saving) {
      _showMessage(context.smPlayerI18n.t('song.processingRequest'));
      return;
    }
    final i18n = context.smPlayerI18n;

    _updateState(() {
      _saving = true;
    });
    var sourceName = '';
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: i18n.t('song.chooseAlbumArtwork'),
        type: FileType.custom,
        allowedExtensions: _artworkSourceExtensions,
      );
      final filePath = result?.files.single.path;
      if (filePath == null) {
        return;
      }
      sourceName = p.basenameWithoutExtension(filePath);

      final preparedPath = await ref
          .read(libraryRepositoryProvider)
          .prepareSongArtworkSource(filePath);
      if (!mounted) {
        return;
      }
      _updateState(() {
        _displayArtworkUrl = preparedPath;
        _artworkSourcePath = preparedPath;
        _artworkMissing = false;
        _artworkDeletePending = false;
        _artworkRecommendation = null;
      });
    } on StateError {
      if (mounted) {
        _showMessage(i18n.t('song.musicNoAlbumArt', {'title': sourceName}));
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

  Future<void> _saveArtwork() async {
    if (_saving) {
      _showMessage(context.smPlayerI18n.t('song.processingRequest'));
      return;
    }
    if (!_artworkDirty) {
      return;
    }
    final i18n = context.smPlayerI18n;
    final deleteArtwork = _artworkDeletePending;

    _updateState(() {
      _saving = true;
    });
    try {
      final repository = ref.read(libraryRepositoryProvider);
      if (deleteArtwork) {
        await repository.deleteSongArtwork(widget.song.id);
      } else {
        await repository.saveSongArtwork(widget.song.id, _artworkSourcePath);
      }
      if (!mounted) {
        return;
      }
      _updateState(() {
        _originalDisplayArtworkUrl = _displayArtworkUrl;
        _artworkSourcePath = '';
        _artworkDeletePending = false;
        _artworkMissing = deleteArtwork;
        _originalArtworkMissing = deleteArtwork;
        _artworkRecommendation = null;
      });
      _syncSongMutation(_songWithArtwork(_displayArtworkUrl), i18n);
      _notifySaved();
      _showMessage(
        i18n.t(deleteArtwork ? 'song.albumArtDeleted' : 'song.albumArtSaved'),
      );
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

  void _deleteArtwork() {
    if (_saving) {
      _showMessage(context.smPlayerI18n.t('song.processingRequest'));
      return;
    }
    _updateState(() {
      _displayArtworkUrl = '';
      _artworkSourcePath = '';
      _artworkDeletePending = true;
      _artworkMissing = true;
      _artworkRecommendation = null;
      _artworkRecommendationRequestKey = '';
    });
    _loadArtworkRecommendation();
  }
}
