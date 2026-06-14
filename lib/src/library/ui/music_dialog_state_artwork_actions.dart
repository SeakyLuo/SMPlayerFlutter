part of 'music_dialog.dart';

extension _MusicDialogStateArtworkActions on _MusicDialogState {
  Future<void> _changeArtwork() async {
    if (_saving) {
      _showMessage(context.smPlayerI18n.t('song.processingRequest'));
      return;
    }
    final i18n = context.smPlayerI18n;

    setState(() {
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
      setState(() {
        _displayArtworkUrl = preparedPath;
        _artworkSourcePath = preparedPath;
        _artworkMissing = false;
        _artworkRecommendation = null;
        _showArtworkDeleteConfirm = false;
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
        setState(() {
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
    if (_artworkSourcePath.isEmpty) {
      return;
    }
    final i18n = context.smPlayerI18n;

    setState(() {
      _saving = true;
    });
    try {
      await ref
          .read(libraryRepositoryProvider)
          .saveSongArtwork(widget.song.id, _artworkSourcePath);
      if (!mounted) {
        return;
      }
      setState(() {
        _originalDisplayArtworkUrl = _displayArtworkUrl;
        _artworkSourcePath = '';
        _artworkMissing = false;
        _originalArtworkMissing = false;
        _artworkRecommendation = null;
      });
      _notifySaved();
      _showMessage(i18n.t('song.albumArtSaved'));
    } catch (_) {
      if (mounted) {
        _showMessage(i18n.t('song.updateFailed'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _deleteArtwork() async {
    if (_saving) {
      _showMessage(context.smPlayerI18n.t('song.processingRequest'));
      return;
    }
    final i18n = context.smPlayerI18n;

    setState(() {
      _saving = true;
    });
    try {
      await ref
          .read(libraryRepositoryProvider)
          .deleteSongArtwork(widget.song.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _displayArtworkUrl = '';
        _originalDisplayArtworkUrl = '';
        _artworkSourcePath = '';
        _artworkMissing = true;
        _originalArtworkMissing = true;
        _artworkRecommendation = null;
        _artworkRecommendationRequestKey = '';
        _showArtworkDeleteConfirm = false;
      });
      _loadArtworkRecommendation();
      _notifySaved();
      _showMessage(i18n.t('song.albumArtDeleted'));
    } catch (_) {
      if (mounted) {
        _showMessage(i18n.t('song.updateFailed'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }
}
