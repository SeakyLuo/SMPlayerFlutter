part of 'music_dialog.dart';

extension _MusicDialogStatePropertyActions on _MusicDialogState {
  void _applyProperties(SongPropertiesSnapshot properties) {
    _updatingControllers = true;
    _properties = properties;
    _originalProperties = properties;
    _titleController.text = properties.title;
    _subtitleController.text = properties.subtitle;
    _albumController.text = properties.album;
    _albumArtistController.text = properties.albumArtist;
    _playCountController.text = properties.playCount.toString();
    _publisherController.text = properties.publisher;
    _trackNumberController.text =
        properties.trackNumber == 0 ? '' : properties.trackNumber.toString();
    _yearController.text =
        properties.year == 0 ? '' : properties.year.toString();
    _bitrateController.text =
        properties.bitrate == 0 ? '' : properties.bitrate.toString();
    _composersController.text = _formatTagList(properties.composers);
    _dateCreatedController.text = _formatDateTime(properties.dateCreated);
    _dateModifiedController.text = _formatDateTime(properties.dateModified);
    _durationController.text = formatDuration(properties.duration.toDouble());
    _fileSizeController.text = _formatBytes(properties.fileSize);
    _fileTypeController.text = properties.fileType;
    _genreController.text = _formatTagList(properties.genre);
    _pathController.text = properties.path;
    for (final controller in _artistControllers) {
      controller.dispose();
    }
    _artistControllers
      ..clear()
      ..addAll(
        (properties.artists.isEmpty ? [''] : properties.artists)
            .take(_MusicDialogState.maxArtistCells)
            .map((artist) {
              final controller = TextEditingController(text: artist);
              controller.addListener(_handleEditorChanged);
              return controller;
            }),
      );
    _updatingControllers = false;
  }

  Future<void> _saveProperties() async {
    if (_saving ||
        _loading ||
        _properties == null ||
        _originalProperties == null) {
      return;
    }
    final i18n = context.smPlayerI18n;

    final artists =
        _normalizeArtists(
          _artistControllers.map((controller) => controller.text).toList(),
        ).take(_MusicDialogState.maxArtistCells).toList();
    final nextProperties = _properties!.copyWith(
      title: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      artist: artists.join(', '),
      artists: artists,
      album: _albumController.text.trim(),
      albumArtist: _albumArtistController.text.trim(),
      publisher: _publisherController.text.trim(),
      trackNumber: _parseElectronNumericField(_trackNumberController.text),
      year: _parseElectronNumericField(_yearController.text),
      playCount: int.tryParse(_playCountController.text) ?? 0,
    );
    if (!_isPropertiesModified(nextProperties, _originalProperties!)) {
      _applyProperties(nextProperties);
      _showMessage(i18n.t('song.propertiesUpdated'));
      return;
    }
    _setSaving(true);
    try {
      await ref
          .read(libraryRepositoryProvider)
          .updateSongProperties(
            widget.song.id,
            SongPropertiesUpdate(
              title: nextProperties.title,
              subtitle: nextProperties.subtitle,
              artist: nextProperties.artist,
              artists: nextProperties.artists,
              album: nextProperties.album,
              albumArtist: nextProperties.albumArtist,
              publisher: nextProperties.publisher,
              trackNumber: nextProperties.trackNumber,
              year: nextProperties.year,
              playCount: nextProperties.playCount,
            ),
          );
      if (!mounted) {
        return;
      }
      _applyProperties(nextProperties);
      patchLibrarySongOverride(ref, _songWithProperties(nextProperties));
      _notifySaved();
      _showMessage(i18n.t('song.propertiesUpdated'));
    } catch (_) {
      if (mounted) {
        _showMessage(i18n.t('song.updateFailed'));
      }
    } finally {
      if (mounted) {
        _setSaving(false);
      }
    }
  }

  void _clearPlayCount() {
    if (_saving || _loading || _properties == null) {
      return;
    }

    _setPlayCountText('0');
  }
}
