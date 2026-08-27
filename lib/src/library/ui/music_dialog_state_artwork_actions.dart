part of 'music_dialog.dart';

extension _MusicDialogStateArtworkActions on _MusicDialogState {
  Future<void> _changeArtwork() async {
    final sessionKey = _dialogSessionKey;
    final sessionState = ref.read(musicDialogArtworkStateProvider(sessionKey));
    if (sessionState.operation != null) {
      _showMessage(context.smPlayerI18n.t('song.processingRequest'));
      return;
    }
    final i18n = context.smPlayerI18n;
    final notifier = ref.read(
      musicDialogArtworkStateProvider(sessionKey).notifier,
    );
    notifier.begin(MusicDialogOperation.changeArtwork);
    var sourceName = '';
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: i18n.t('song.chooseAlbumArtwork'),
        type: FileType.custom,
        allowedExtensions: _artworkSourceExtensions,
      );
      final filePath = result?.files.single.path;
      if (!mounted || _dialogSessionKey != sessionKey) {
        return;
      }
      if (filePath == null) {
        notifier.finish(dirty: _artworkDirty);
        return;
      }
      sourceName = p.basenameWithoutExtension(filePath);

      final preparedPath = await ref
          .read(libraryRepositoryProvider)
          .prepareSongArtworkSource(filePath);
      if (!mounted || _dialogSessionKey != sessionKey) {
        return;
      }
      _displayArtworkUrl = preparedPath;
      _artworkSourcePath = preparedPath;
      _artworkMissing = false;
      _artworkDeletePending = false;
      _invalidateArtworkRecommendation();
      notifier.finish(dirty: true, refresh: true);
    } on StateError {
      if (mounted && _dialogSessionKey == sessionKey) {
        notifier.finish(dirty: _artworkDirty);
        _showMessage(i18n.t('song.musicNoAlbumArt', {'title': sourceName}));
      }
    } catch (_) {
      if (mounted && _dialogSessionKey == sessionKey) {
        notifier.finish(dirty: _artworkDirty);
        _showMessage(i18n.t('song.updateFailed'));
      }
    }
  }

  Future<void> _saveArtwork() async {
    final sessionKey = _dialogSessionKey;
    final sessionState = ref.read(musicDialogArtworkStateProvider(sessionKey));
    if (sessionState.operation != null) {
      _showMessage(context.smPlayerI18n.t('song.processingRequest'));
      return;
    }
    if (!_artworkDirty) {
      return;
    }
    final i18n = context.smPlayerI18n;
    final deleteArtwork = _artworkDeletePending;
    final notifier = ref.read(
      musicDialogArtworkStateProvider(sessionKey).notifier,
    );
    notifier.begin(MusicDialogOperation.saveArtwork);
    try {
      final repository = ref.read(libraryRepositoryProvider);
      if (deleteArtwork) {
        await repository.deleteSongArtwork(widget.song.id);
      } else {
        await repository.saveSongArtwork(widget.song.id, _artworkSourcePath);
      }
      if (!mounted || _dialogSessionKey != sessionKey) {
        return;
      }
      _originalDisplayArtworkUrl = _displayArtworkUrl;
      _artworkSourcePath = '';
      _artworkDeletePending = false;
      _artworkMissing = deleteArtwork;
      _originalArtworkMissing = deleteArtwork;
      _invalidateArtworkRecommendation();
      _syncSongMutation(_songWithArtwork(_displayArtworkUrl), i18n);
      _notifySaved();
      notifier.finish(dirty: false, refresh: true);
      if (_artworkMissing) {
        unawaited(_loadArtworkRecommendation(dependencyChanged: true));
      }
      _showMessage(
        i18n.t(deleteArtwork ? 'song.albumArtDeleted' : 'song.albumArtSaved'),
      );
    } catch (_) {
      if (mounted && _dialogSessionKey == sessionKey) {
        notifier.finish(dirty: _artworkDirty);
        _showMessage(i18n.t('song.updateFailed'));
      }
    }
  }

  void _deleteArtwork() {
    final state = ref.read(musicDialogArtworkStateProvider(_dialogSessionKey));
    if (state.operation != null) {
      _showMessage(context.smPlayerI18n.t('song.processingRequest'));
      return;
    }
    _displayArtworkUrl = '';
    _artworkSourcePath = '';
    _artworkDeletePending = true;
    _artworkMissing = true;
    _artworkRecommendation = null;
    _artworkRecommendationRequestKey = '';
    ref
        .read(musicDialogArtworkStateProvider(_dialogSessionKey).notifier)
        .refresh(dirty: true);
    _loadArtworkRecommendation(dependencyChanged: true);
  }
}
