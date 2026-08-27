part of 'music_dialog.dart';

extension _MusicDialogStateResetActions on _MusicDialogState {
  void _resetProperties() {
    final state = ref.read(
      musicDialogPropertiesStateProvider(_dialogSessionKey),
    );
    final originalProperties = _originalProperties;
    if (state.loading ||
        state.operation != null ||
        originalProperties == null ||
        !state.dirty) {
      return;
    }

    _applyProperties(originalProperties);
    ref
        .read(musicDialogPropertiesStateProvider(_dialogSessionKey).notifier)
        .refresh(dirty: false);
    _showMessage(context.smPlayerI18n.t('song.propertiesReset'));
  }

  void _resetLyrics() {
    final state = ref.read(musicDialogLyricsStateProvider(_dialogSessionKey));
    if (state.loading || state.operation != null || !state.dirty) {
      return;
    }
    _updatingControllers = true;
    _lyricsRawText = _originalLyricsText;
    _lyricsController.text =
        _showLyricsTimestamps
            ? _originalLyricsText
            : _stripLyricsTimestamps(_originalLyricsText);
    _updatingControllers = false;
    _scrollLyricsToTop();
    ref
        .read(musicDialogLyricsStateProvider(_dialogSessionKey).notifier)
        .updateLyricsEditor(
          dirty: false,
          canToggleTimestamps: _lyricsCanToggleTimestamps,
          refresh: true,
        );
    _showMessage(context.smPlayerI18n.t('song.lyricsReset'));
  }

  void _resetArtwork() {
    final state = ref.read(musicDialogArtworkStateProvider(_dialogSessionKey));
    if (state.loading || state.operation != null || !state.dirty) {
      return;
    }
    _displayArtworkUrl = _originalDisplayArtworkUrl;
    _artworkSourcePath = '';
    _artworkDeletePending = false;
    _artworkMissing = _originalArtworkMissing;
    _artworkRecommendation = null;
    _artworkRecommendationRequestKey = '';
    ref
        .read(musicDialogArtworkStateProvider(_dialogSessionKey).notifier)
        .refresh(dirty: false);
    _loadArtworkRecommendation(dependencyChanged: true);
  }

  void _toggleLyricsTimestamps(bool checked) {
    final rawText = _currentLyricsRawText;
    _updatingControllers = true;
    _lyricsRawText = rawText;
    _showLyricsTimestamps = checked;
    _lyricsController.text =
        checked ? rawText : _stripLyricsTimestamps(rawText);
    _updatingControllers = false;
    ref
        .read(musicDialogLyricsStateProvider(_dialogSessionKey).notifier)
        .updateLyricsEditor(
          dirty: _lyricsDirty,
          canToggleTimestamps: _lyricsCanToggleTimestamps,
          showTimestamps: checked,
          refresh: true,
        );
  }

  void _applyAlbumArtRecommendation(AlbumArtRecommendation recommendation) {
    final state = ref.read(musicDialogArtworkStateProvider(_dialogSessionKey));
    if (state.operation != null) {
      return;
    }
    _displayArtworkUrl = recommendation.sourceUrl;
    _artworkSourcePath = recommendation.sourcePath;
    _artworkDeletePending = false;
    _artworkMissing = false;
    _invalidateArtworkRecommendation();
    ref
        .read(musicDialogArtworkStateProvider(_dialogSessionKey).notifier)
        .refresh(dirty: true);
  }

  void _applyAlbumArtLibraryChoice(AlbumArtLibraryChoice choice) {
    final state = ref.read(musicDialogArtworkStateProvider(_dialogSessionKey));
    if (state.operation != null) {
      return;
    }
    _displayArtworkUrl = choice.sourceUrl;
    _artworkSourcePath = choice.sourcePath;
    _artworkDeletePending = false;
    _artworkMissing = false;
    _invalidateArtworkRecommendation();
    ref
        .read(musicDialogArtworkStateProvider(_dialogSessionKey).notifier)
        .refresh(dirty: true);
    _updateDialogStructure(() {
      _libraryArtworkPickerOpen = false;
    });
  }

  void _addArtistCell() {
    final controller = TextEditingController();
    controller.addListener(_handleEditorChanged);
    _artistControllers.add(controller);
    ref
        .read(musicDialogPropertiesStateProvider(_dialogSessionKey).notifier)
        .refresh(dirty: _propertiesDirty);
  }

  void _removeArtistCell(int index) {
    final controller = _artistControllers.removeAt(index);
    controller.dispose();
    ref
        .read(musicDialogPropertiesStateProvider(_dialogSessionKey).notifier)
        .refresh(dirty: _propertiesDirty);
  }
}
