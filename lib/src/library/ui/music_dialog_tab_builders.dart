part of 'music_dialog.dart';

extension _MusicDialogStateTabBuilders on _MusicDialogState {
  Widget _buildPropertiesControl({
    required bool canPause,
    required bool canPlay,
  }) {
    return Consumer(
      builder: (context, ref, child) {
        final view = ref.watch(
          musicDialogPropertiesStateProvider(_dialogSessionKey).select(
            (state) => (
              loading: state.loading,
              saving: state.operation == MusicDialogOperation.saveProperties,
              revision: state.revision,
            ),
          ),
        );
        return MusicInfoControl(
          sessionKey: _dialogSessionKey,
          loading: view.loading,
          saving: view.saving,
          properties: _properties,
          artistControllers: _artistControllers,
          titleController: _titleController,
          subtitleController: _subtitleController,
          albumController: _albumController,
          albumArtistController: _albumArtistController,
          playCountController: _playCountController,
          publisherController: _publisherController,
          trackNumberController: _trackNumberController,
          yearController: _yearController,
          bitrateController: _bitrateController,
          composersController: _composersController,
          dateCreatedController: _dateCreatedController,
          dateModifiedController: _dateModifiedController,
          durationController: _durationController,
          fileSizeController: _fileSizeController,
          fileTypeController: _fileTypeController,
          genreController: _genreController,
          pathController: _pathController,
          canPause: canPause,
          onPlay: canPlay ? _play : null,
          onSave: _saveProperties,
          onReset: _resetProperties,
          onClearPlayCount: _clearPlayCount,
          onAddArtistCell: _addArtistCell,
          onRemoveArtistCell: _removeArtistCell,
          onReveal: widget.onReveal,
        );
      },
    );
  }

  Widget _buildLyricsControl() {
    return Consumer(
      builder: (context, ref, child) {
        final view = ref.watch(
          musicDialogLyricsStateProvider(_dialogSessionKey).select(
            (state) => (
              loading: state.loading,
              operation: state.operation,
              revision: state.revision,
            ),
          ),
        );
        return MusicLyricsControl(
          sessionKey: _dialogSessionKey,
          loading: view.loading,
          operation: view.operation,
          lyrics: _lyrics,
          lyricsController: _lyricsController,
          lyricsScrollController: _lyricsScrollController,
          onSearch: _searchLyrics,
          onImport: _importLyrics,
          onSave: _saveLyrics,
          onReset: _resetLyrics,
          onToggleTimestamps: _toggleLyricsTimestamps,
        );
      },
    );
  }

  Widget _buildAlbumArtControl() {
    return Consumer(
      builder: (context, ref, child) {
        final view = ref.watch(
          musicDialogArtworkStateProvider(_dialogSessionKey).select(
            (state) => (
              loading: state.loading,
              operation: state.operation,
              dirty: state.dirty,
              revision: state.revision,
            ),
          ),
        );
        return MusicAlbumArtControl(
          song: widget.song,
          loading: view.loading,
          operation: view.operation,
          artworkUrl: _displayArtworkUrl,
          artworkDirty: view.dirty,
          recommendation: _artworkMissing ? _artworkRecommendation : null,
          onApplyRecommendation: _applyAlbumArtRecommendation,
          onChangeArtwork: _changeArtwork,
          onChooseArtworkFromLibrary: () {
            _updateDialogStructure(() {
              _libraryArtworkPickerOpen = true;
            });
          },
          onSaveArtwork: _saveArtwork,
          onResetArtwork: _resetArtwork,
          onRequestDelete: _deleteArtwork,
        );
      },
    );
  }
}
