part of 'music_dialog.dart';

extension _MusicDialogStateResetActions on _MusicDialogState {
  void _resetProperties() {
    final originalProperties = _originalProperties;
    if (originalProperties == null || !_propertiesDirty) {
      return;
    }

    _updateState(() {
      _applyProperties(originalProperties);
    });
    _showMessage(context.smPlayerI18n.t('song.propertiesReset'));
  }

  void _resetLyrics() {
    if (!_lyricsDirty) {
      return;
    }
    _lyricsRawText = _originalLyricsText;
    _lyricsController.text =
        _showLyricsTimestamps
            ? _originalLyricsText
            : _stripLyricsTimestamps(_originalLyricsText);
    _scrollLyricsToTop();
    _updateState(() {});
    _showMessage(context.smPlayerI18n.t('song.lyricsReset'));
  }

  void _resetArtwork() {
    if (!_artworkDirty) {
      return;
    }
    _updateState(() {
      _displayArtworkUrl = _originalDisplayArtworkUrl;
      _artworkSourcePath = '';
      _artworkDeletePending = false;
      _artworkMissing = _originalArtworkMissing;
      _artworkRecommendation = null;
      _artworkRecommendationRequestKey = '';
    });
    _loadArtworkRecommendation();
  }

  void _toggleLyricsTimestamps(bool checked) {
    final rawText = _currentLyricsRawText;
    _updateState(() {
      _lyricsRawText = rawText;
      _showLyricsTimestamps = checked;
      _lyricsController.text =
          checked ? rawText : _stripLyricsTimestamps(rawText);
    });
  }

  void _applyAlbumArtRecommendation(AlbumArtRecommendation recommendation) {
    _updateState(() {
      _displayArtworkUrl = recommendation.sourceUrl;
      _artworkSourcePath = recommendation.sourcePath;
      _artworkDeletePending = false;
      _artworkMissing = false;
      _artworkRecommendation = null;
    });
  }

  void _applyAlbumArtLibraryChoice(AlbumArtLibraryChoice choice) {
    _updateState(() {
      _displayArtworkUrl = choice.sourceUrl;
      _artworkSourcePath = choice.sourcePath;
      _artworkDeletePending = false;
      _artworkMissing = false;
      _artworkRecommendation = null;
      _libraryArtworkPickerOpen = false;
    });
  }

  void _addArtistCell() {
    _updateState(() {
      final controller = TextEditingController();
      controller.addListener(_handleEditorChanged);
      _artistControllers.add(controller);
    });
  }

  void _removeArtistCell(int index) {
    _updateState(() {
      final controller = _artistControllers.removeAt(index);
      controller.dispose();
    });
  }
}
