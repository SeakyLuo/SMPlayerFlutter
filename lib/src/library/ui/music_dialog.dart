import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:url_launcher/url_launcher.dart';

enum SongDialogMode { properties, lyrics, albumArt }

class AlbumArtRecommendation {
  const AlbumArtRecommendation({
    required this.song,
    required this.artworkUrl,
    required this.sourceUrl,
    required this.sourcePath,
    required this.artistName,
  });

  final LibrarySong song;
  final String artworkUrl;
  final String sourceUrl;
  final String sourcePath;
  final String artistName;
}

class AlbumArtLibraryChoice {
  const AlbumArtLibraryChoice({
    required this.song,
    required this.artworkUrl,
    required this.sourceUrl,
    required this.sourcePath,
  });

  final LibrarySong song;
  final String artworkUrl;
  final String sourceUrl;
  final String sourcePath;
}

class MusicDialog extends ConsumerStatefulWidget {
  const MusicDialog({
    super.key,
    required this.song,
    required this.initialMode,
    required this.onClose,
    this.canPause = false,
    this.onPlay,
    this.onReveal,
    this.onSaved,
  });

  final LibrarySong song;
  final SongDialogMode initialMode;
  final VoidCallback onClose;
  final bool canPause;
  final VoidCallback? onPlay;
  final ValueChanged<String>? onReveal;
  final VoidCallback? onSaved;

  @override
  ConsumerState<MusicDialog> createState() => _MusicDialogState();
}

class _MusicDialogState extends ConsumerState<MusicDialog> {
  static const maxArtistCells = 6;

  late var _mode = widget.initialMode;
  var _loading = true;
  var _lyricsLoading = true;
  var _artworkLoading = true;
  var _saving = false;
  var _updatingControllers = false;
  var _showLyricsTimestamps = true;
  var _showArtworkDeleteConfirm = false;
  SongPropertiesSnapshot? _properties;
  SongPropertiesSnapshot? _originalProperties;
  LyricsSnapshot? _lyrics;
  String _lyricsRawText = '';
  String _originalLyricsText = '';
  String _artworkUrl = '';
  String _originalArtworkUrl = '';
  String _artworkSourcePath = '';
  var _artworkMissing = false;
  var _originalArtworkMissing = false;
  var _artworkRecommendationLoading = false;
  AlbumArtRecommendation? _artworkRecommendation;
  var _libraryArtworkPickerOpen = false;
  final _shortcutFocusNode = FocusNode(debugLabel: 'MusicDialogShortcuts');

  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _albumController = TextEditingController();
  final _albumArtistController = TextEditingController();
  final _playCountController = TextEditingController();
  final _publisherController = TextEditingController();
  final _trackNumberController = TextEditingController();
  final _yearController = TextEditingController();
  final _bitrateController = TextEditingController();
  final _composersController = TextEditingController();
  final _dateCreatedController = TextEditingController();
  final _dateModifiedController = TextEditingController();
  final _durationController = TextEditingController();
  final _fileSizeController = TextEditingController();
  final _fileTypeController = TextEditingController();
  final _genreController = TextEditingController();
  final _pathController = TextEditingController();
  final _lyricsController = TextEditingController();
  final _artistControllers = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    _addControllerListeners();
    _loadSong();
  }

  @override
  void didUpdateWidget(covariant MusicDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMode != widget.initialMode ||
        oldWidget.song.id != widget.song.id) {
      _mode = widget.initialMode;
      _loadSong();
    }
  }

  void _addControllerListeners() {
    for (final controller in [
      _titleController,
      _subtitleController,
      _albumController,
      _albumArtistController,
      _playCountController,
      _publisherController,
      _trackNumberController,
      _yearController,
      _genreController,
      _composersController,
      _lyricsController,
    ]) {
      controller.addListener(_handleEditorChanged);
    }
  }

  void _handleEditorChanged() {
    if (mounted && !_updatingControllers) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _albumController.dispose();
    _albumArtistController.dispose();
    _playCountController.dispose();
    _publisherController.dispose();
    _trackNumberController.dispose();
    _yearController.dispose();
    _bitrateController.dispose();
    _composersController.dispose();
    _dateCreatedController.dispose();
    _dateModifiedController.dispose();
    _durationController.dispose();
    _fileSizeController.dispose();
    _fileTypeController.dispose();
    _genreController.dispose();
    _pathController.dispose();
    _lyricsController.dispose();
    _shortcutFocusNode.dispose();
    for (final controller in _artistControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final librarySongs =
        ref.watch(musicLibrarySnapshotProvider).valueOrNull?.songs ??
        const <LibrarySong>[];
    if (_artworkMissing &&
        !_artworkRecommendationLoading &&
        _artworkRecommendation == null &&
        librarySongs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadArtworkRecommendation();
        }
      });
    }

    return Focus(
      autofocus: true,
      focusNode: _shortcutFocusNode,
      onKeyEvent: _handleShortcutKey,
      child: Stack(
        children: [
          PopupDialog(
            overlayClassName: 'music-dialog-overlay MusicDialogOverlay',
            className: 'music-dialog ContentDialog MusicDialog',
            navClassName: 'music-dialog-pivot MusicDialogPivot',
            navLabel: i18n.t('context.seeMusicInfo'),
            ariaLabel: widget.song.title,
            onClose: _requestClose,
            navChildren: [
              PopupDialogTab(
                label: _dialogTabLabel(i18n.t('context.seeMusicInfo')),
                icon: FluentIcons.info_20_regular,
                selected: _mode == SongDialogMode.properties,
                first: true,
                onPressed: () {
                  setState(() {
                    _mode = SongDialogMode.properties;
                  });
                },
              ),
              PopupDialogTab(
                label: _dialogTabLabel(i18n.t('context.seeLyrics')),
                icon: FluentIcons.text_quote_20_regular,
                selected: _mode == SongDialogMode.lyrics,
                onPressed: () {
                  setState(() {
                    _mode = SongDialogMode.lyrics;
                  });
                },
              ),
              PopupDialogTab(
                label: _dialogTabLabel(i18n.t('context.seeAlbumArt')),
                icon: FluentIcons.image_20_regular,
                selected: _mode == SongDialogMode.albumArt,
                last: true,
                onPressed: () {
                  setState(() {
                    _mode = SongDialogMode.albumArt;
                  });
                },
              ),
            ],
            child: switch (_mode) {
              SongDialogMode.properties => MusicInfoControl(
                loading: _loading,
                saving: _saving,
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
                canPause: widget.canPause,
                propertiesDirty: _propertiesDirty,
                onPlay: widget.onPlay,
                onSave: _saveProperties,
                onReset: _resetProperties,
                onClearPlayCount: _clearPlayCount,
                onAddArtistCell: _addArtistCell,
                onRemoveArtistCell: _removeArtistCell,
                onReveal: widget.onReveal,
              ),
              SongDialogMode.lyrics => MusicLyricsControl(
                loading: _lyricsLoading,
                saving: _saving,
                lyrics: _lyrics,
                lyricsController: _lyricsController,
                lyricsDirty: _lyricsDirty,
                showLyricsTimestamps: _showLyricsTimestamps,
                lyricsCanToggleTimestamps: _lyricsCanToggleTimestamps,
                onSearch: _searchLyrics,
                onImport: _importLyrics,
                onSave: _saveLyrics,
                onReset: _resetLyrics,
                onToggleTimestamps: _toggleLyricsTimestamps,
              ),
              SongDialogMode.albumArt => MusicAlbumArtControl(
                song: widget.song,
                loading: _artworkLoading,
                saving: _saving,
                artworkUrl: _artworkUrl,
                artworkDirty: _artworkDirty,
                recommendation: _artworkMissing ? _artworkRecommendation : null,
                showDeleteConfirm: _showArtworkDeleteConfirm,
                onApplyRecommendation: _applyAlbumArtRecommendation,
                onChangeArtwork: _changeArtwork,
                onChooseArtworkFromLibrary: () {
                  setState(() {
                    _libraryArtworkPickerOpen = true;
                  });
                },
                onSaveArtwork: _saveArtwork,
                onResetArtwork: _resetArtwork,
                onRequestDelete: () {
                  setState(() {
                    _showArtworkDeleteConfirm = true;
                  });
                },
                onConfirmDelete: _deleteArtwork,
                onCancelDelete: () {
                  setState(() {
                    _showArtworkDeleteConfirm = false;
                  });
                },
              ),
            },
          ),
          if (_libraryArtworkPickerOpen)
            _AlbumArtLibraryPickerDialog(
              albumName: widget.song.album,
              currentSong: widget.song,
              songs: librarySongs,
              onApply: _applyAlbumArtLibraryChoice,
              onClose: () {
                setState(() {
                  _libraryArtworkPickerOpen = false;
                });
              },
            ),
        ],
      ),
    );
  }

  KeyEventResult _handleShortcutKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyS) {
      unawaited(_saveActiveMode());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR) {
      _resetActiveMode();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF && _mode == SongDialogMode.lyrics) {
      unawaited(_searchLyrics());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _saveActiveMode() {
    return switch (_mode) {
      SongDialogMode.properties => _saveProperties(),
      SongDialogMode.lyrics => _saveLyrics(),
      SongDialogMode.albumArt => _saveArtwork(),
    };
  }

  void _resetActiveMode() {
    switch (_mode) {
      case SongDialogMode.properties:
        _resetProperties();
      case SongDialogMode.lyrics:
        _resetLyrics();
      case SongDialogMode.albumArt:
        _resetArtwork();
    }
  }

  Future<void> _loadSong() async {
    final repository = ref.read(libraryRepositoryProvider);
    setState(() {
      _loading = true;
      _lyricsLoading = true;
      _artworkLoading = true;
      _showArtworkDeleteConfirm = false;
      _artworkSourcePath = '';
      _artworkRecommendation = null;
      _libraryArtworkPickerOpen = false;
    });

    try {
      final results = await Future.wait<Object>([
        repository.getSongProperties(widget.song.id),
        repository.getSongLyrics(widget.song.id),
        repository.getSongArtworkSnapshot(widget.song.id),
      ]);
      if (!mounted) {
        return;
      }

      final properties = results[0] as SongPropertiesSnapshot;
      final lyrics = results[1] as LyricsSnapshot;
      final artwork = results[2] as SongArtworkSnapshot;
      _applyProperties(properties);
      _lyrics = lyrics;
      _lyricsRawText = lyrics.rawText;
      _originalLyricsText = lyrics.rawText;
      _lyricsController.text = lyrics.rawText;
      _artworkUrl = artwork.artworkUrl;
      _originalArtworkUrl = artwork.artworkUrl;
      _artworkMissing =
          artwork.source == SongArtworkSource.none ||
          artwork.artworkUrl.isEmpty;
      _originalArtworkMissing = _artworkMissing;
      _loadArtworkRecommendation();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _lyricsLoading = false;
          _artworkLoading = false;
        });
      }
    }
  }

  Future<void> _loadArtworkRecommendation() async {
    if (!_artworkMissing || _artworkRecommendationLoading) {
      _artworkRecommendation = null;
      return;
    }

    final i18n = context.smPlayerI18n;
    final songs = ref.read(musicLibrarySnapshotProvider).valueOrNull?.songs;
    if (songs == null) {
      return;
    }

    final candidates = _getAlbumArtRecommendationCandidates(widget.song, songs);
    if (candidates.isEmpty) {
      if (mounted) {
        setState(() {
          _artworkRecommendation = null;
        });
      }
      return;
    }

    setState(() {
      _artworkRecommendationLoading = true;
    });
    final snapshots = await ref
        .read(libraryRepositoryProvider)
        .getSongArtworkSnapshots(
          candidates.map((candidate) => candidate.song.id).toList(),
        );
    if (!mounted) {
      return;
    }
    if (!_artworkMissing) {
      setState(() {
        _artworkRecommendationLoading = false;
      });
      return;
    }

    final snapshotsBySongId = {
      for (final snapshot in snapshots) snapshot.songId: snapshot,
    };
    for (final candidate in candidates) {
      final snapshot = snapshotsBySongId[candidate.song.id]!;
      if (snapshot.source != SongArtworkSource.none &&
          snapshot.sourcePath.isNotEmpty &&
          snapshot.sourceUrl.isNotEmpty) {
        setState(() {
          _artworkRecommendation = AlbumArtRecommendation(
            song: candidate.song,
            artworkUrl: snapshot.artworkUrl,
            sourceUrl: snapshot.sourceUrl,
            sourcePath: snapshot.sourcePath,
            artistName: _getDisplayArtists(candidate.song, i18n),
          );
          _artworkRecommendationLoading = false;
        });
        return;
      }
    }

    setState(() {
      _artworkRecommendation = null;
      _artworkRecommendationLoading = false;
    });
  }

  void _applyProperties(SongPropertiesSnapshot properties) {
    _updatingControllers = true;
    _properties = properties;
    _originalProperties = properties;
    _titleController.text = properties.title;
    _subtitleController.text = properties.subtitle;
    _albumController.text = properties.album;
    _albumArtistController.text = properties.albumArtist;
    _playCountController.text =
        properties.playCount == 0 ? '' : properties.playCount.toString();
    _publisherController.text = properties.publisher;
    _trackNumberController.text =
        properties.trackNumber == 0 ? '' : properties.trackNumber.toString();
    _yearController.text =
        properties.year == 0 ? '' : properties.year.toString();
    _bitrateController.text =
        properties.bitrate == 0 ? '' : properties.bitrate.toString();
    _composersController.text = properties.composers;
    _dateCreatedController.text = _formatDateTime(properties.dateCreated);
    _dateModifiedController.text = _formatDateTime(properties.dateModified);
    _durationController.text = formatDuration(properties.duration.toDouble());
    _fileSizeController.text = _formatBytes(properties.fileSize);
    _fileTypeController.text = properties.fileType;
    _genreController.text = properties.genre;
    _pathController.text = properties.path;
    for (final controller in _artistControllers) {
      controller.dispose();
    }
    _artistControllers
      ..clear()
      ..addAll(
        (properties.artists.isEmpty ? [''] : properties.artists)
            .take(maxArtistCells)
            .map((artist) {
              final controller = TextEditingController(text: artist);
              controller.addListener(_handleEditorChanged);
              return controller;
            }),
      );
    _updatingControllers = false;
  }

  Future<void> _saveProperties() async {
    if (_saving || _loading || _properties == null) {
      return;
    }
    final i18n = context.smPlayerI18n;

    final artists =
        _artistControllers
            .map((controller) => controller.text.trim())
            .where((artist) => artist.isNotEmpty)
            .toSet()
            .toList();
    final nextProperties = _properties!.copyWith(
      title: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      artist: artists.join(', '),
      artists: artists,
      album: _albumController.text.trim(),
      albumArtist: _albumArtistController.text.trim(),
      publisher: _publisherController.text.trim(),
      trackNumber: int.tryParse(_trackNumberController.text) ?? 0,
      year: int.tryParse(_yearController.text) ?? 0,
      playCount: int.tryParse(_playCountController.text) ?? 0,
    );
    setState(() {
      _saving = true;
    });
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
      _notifySaved();
      _showMessage(i18n.t('song.propertiesUpdated'));
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

  Future<void> _clearPlayCount() async {
    if (_saving || _loading || _properties == null) {
      return;
    }

    setState(() {
      _saving = true;
    });
    try {
      await ref
          .read(libraryRepositoryProvider)
          .updateSongPlayCount(widget.song.id, 0);
      if (!mounted) {
        return;
      }
      final nextProperties = _properties!.copyWith(playCount: 0);
      _applyProperties(nextProperties);
      _notifySaved();
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

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

    setState(() {
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
      _lyrics = LyricsSnapshot(
        source: LyricsSource.lrcFile,
        isSynced: _lyricsCanToggleTimestamps,
        rawText: _originalLyricsText,
        lines: _parseLyricsLines(nextRawText),
      );
      _notifySaved();
      _showMessage(i18n.t('song.lyricsUpdated', {'title': widget.song.title}));
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

  Future<void> _searchLyrics() async {
    if (_saving) {
      _showMessage(context.smPlayerI18n.t('song.processingRequest'));
      return;
    }
    final i18n = context.smPlayerI18n;
    final beforeText = _lyricsController.text;
    final uri = musicLyricsSearchUri(
      locale: i18n.locale,
      title: widget.song.title,
      artist: widget.song.artist,
    );
    setState(() {
      _saving = true;
    });
    try {
      final snapshot = await ref
          .read(libraryRepositoryProvider)
          .getInternetLyrics(widget.song.id);
      if (!mounted) {
        return;
      }
      if (snapshot.rawText.trim().isNotEmpty) {
        _lyrics = snapshot;
        _lyricsRawText = snapshot.rawText;
        _lyricsController.text =
            _showLyricsTimestamps
                ? snapshot.rawText
                : _stripLyricsTimestamps(snapshot.rawText);
        _showMessage(
          beforeText == _lyricsController.text
              ? i18n.t('song.nothingChanged')
              : i18n.t('song.searchLyricsSuccessful'),
        );
        return;
      }

      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        setState(() {
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

    setState(() {
      _saving = true;
    });
    try {
      final result = await FilePicker.pickFiles(
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
      setState(() {});
    } catch (_) {
      if (mounted) {
        _showMessage(i18n.t('song.importLyricsFailed'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

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
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'mp3'],
      );
      final filePath = result?.files.single.path;
      if (filePath == null) {
        return;
      }
      sourceName = result!.files.single.name;

      final preparedPath = await ref
          .read(libraryRepositoryProvider)
          .prepareSongArtworkSource(filePath);
      if (!mounted) {
        return;
      }
      setState(() {
        _artworkUrl = preparedPath;
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
        _artworkUrl = _artworkSourcePath;
        _originalArtworkUrl = _artworkSourcePath;
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
        _artworkUrl = '';
        _originalArtworkUrl = '';
        _artworkSourcePath = '';
        _artworkMissing = true;
        _originalArtworkMissing = true;
        _artworkRecommendation = null;
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

  void _resetProperties() {
    final originalProperties = _originalProperties;
    if (originalProperties == null) {
      return;
    }

    setState(() {
      _applyProperties(originalProperties);
    });
    _showMessage(context.smPlayerI18n.t('song.propertiesReset'));
  }

  void _resetLyrics() {
    _lyricsRawText = _originalLyricsText;
    _lyricsController.text =
        _showLyricsTimestamps
            ? _originalLyricsText
            : _stripLyricsTimestamps(_originalLyricsText);
    setState(() {});
    _showMessage(context.smPlayerI18n.t('song.lyricsReset'));
  }

  void _resetArtwork() {
    setState(() {
      _artworkUrl = _originalArtworkUrl;
      _artworkSourcePath = '';
      _artworkMissing = _originalArtworkMissing;
      _showArtworkDeleteConfirm = false;
    });
    _loadArtworkRecommendation();
    _showMessage(context.smPlayerI18n.t('song.albumArtReset'));
  }

  void _toggleLyricsTimestamps(bool checked) {
    final rawText = _currentLyricsRawText;
    setState(() {
      _lyricsRawText = rawText;
      _showLyricsTimestamps = checked;
      _lyricsController.text =
          checked ? rawText : _stripLyricsTimestamps(rawText);
    });
  }

  void _applyAlbumArtRecommendation(AlbumArtRecommendation recommendation) {
    setState(() {
      _artworkUrl = recommendation.sourceUrl;
      _artworkSourcePath = recommendation.sourcePath;
      _artworkMissing = false;
      _showArtworkDeleteConfirm = false;
    });
  }

  void _applyAlbumArtLibraryChoice(AlbumArtLibraryChoice choice) {
    setState(() {
      _artworkUrl = choice.sourceUrl;
      _artworkSourcePath = choice.sourcePath;
      _artworkMissing = false;
      _artworkRecommendation = null;
      _showArtworkDeleteConfirm = false;
      _libraryArtworkPickerOpen = false;
    });
  }

  void _addArtistCell() {
    setState(() {
      final controller = TextEditingController();
      controller.addListener(_handleEditorChanged);
      _artistControllers.add(controller);
    });
  }

  void _removeArtistCell(int index) {
    setState(() {
      final controller = _artistControllers.removeAt(index);
      controller.dispose();
    });
  }

  void _requestClose() {
    if (!_lyricsDirty) {
      widget.onClose();
      return;
    }

    showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final i18n = dialogContext.smPlayerI18n;
        return AlertDialog(
          title: Text(i18n.t('common.confirm')),
          content: Text(i18n.t('song.discardLyricsConfirm')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(i18n.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(i18n.t('common.confirm')),
            ),
          ],
        );
      },
    ).then((confirmed) {
      if (confirmed == true) {
        widget.onClose();
      }
    });
  }

  void _notifySaved() {
    ref.invalidate(musicLibrarySnapshotProvider);
    widget.onSaved?.call();
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
        _playCountController.text !=
            (original.playCount == 0 ? '' : original.playCount.toString()) ||
        _artistControllers.map((controller) => controller.text).join('\n') !=
            original.artists.join('\n');
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

const _lyricsImportExtensions = [
  'lrc',
  'txt',
  'aac',
  'aiff',
  'aif',
  'alac',
  'ape',
  'flac',
  'm4a',
  'mp3',
  'mp4',
  'oga',
  'ogg',
  'opus',
  'wav',
  'wma',
];

Uri musicLyricsSearchUri({
  required String locale,
  required String title,
  required String artist,
}) {
  final isChineseLanguage = locale == 'zh-CN' || locale == 'zh-Hant';
  final keyword = isChineseLanguage ? '歌词' : 'lyrics';
  final host =
      isChineseLanguage
          ? 'https://cn.bing.com/search'
          : 'https://www.bing.com/search';
  return Uri.parse(
    '$host?q=${Uri.encodeQueryComponent([keyword, title, artist].where((value) => value.isNotEmpty).join(' '))}',
  );
}

final _lyricsTimestampRegex = RegExp(r'\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\]');
final _lyricsMetadataRegex = RegExp(
  r'^\[(ti|ar|al|by|offset):.*\]$',
  caseSensitive: false,
);
final _lyricsLineBreakRegex = RegExp(r'\r\n|[\n\r\u2028\u2029]');

String _stripLyricsTimestamps(String rawText) {
  return rawText
      .split(_lyricsLineBreakRegex)
      .map((line) {
        final trimmedLine = line.trim();
        if (_lyricsMetadataRegex.hasMatch(trimmedLine)) {
          return '';
        }

        return line.replaceAll(_lyricsTimestampRegex, '').trimLeft();
      })
      .join('\n')
      .trim();
}

String _mergePlainLyricsWithTimedRaw(String rawText, String plainText) {
  final plainLines = plainText.split(_lyricsLineBreakRegex);
  var plainLineIndex = 0;
  final mergedLines =
      rawText.split(_lyricsLineBreakRegex).map((line) {
        final timestampTags =
            _lyricsTimestampRegex
                .allMatches(line)
                .map((match) => match.group(0)!)
                .toList();
        if (timestampTags.isEmpty) {
          if (_lyricsMetadataRegex.hasMatch(line.trim()) ||
              line.trim().isEmpty) {
            return line;
          }

          final plainLine =
              plainLineIndex < plainLines.length
                  ? plainLines[plainLineIndex]
                  : line;
          plainLineIndex += 1;
          return plainLine;
        }

        final fallbackText =
            line.replaceAll(_lyricsTimestampRegex, '').trimLeft();
        final plainLine =
            plainLineIndex < plainLines.length
                ? plainLines[plainLineIndex]
                : fallbackText;
        plainLineIndex += 1;
        return '${timestampTags.join()}$plainLine';
      }).toList();

  while (plainLineIndex < plainLines.length) {
    mergedLines.add(plainLines[plainLineIndex]);
    plainLineIndex += 1;
  }

  return mergedLines.join('\n').trim();
}

List<LyricsLine> _parseLyricsLines(String rawText) {
  final lines = rawText.split(_lyricsLineBreakRegex);
  return [
    for (final entry in lines.indexed)
      LyricsLine(
        id: entry.$1,
        timestampMs: _parseLyricsTimestamp(entry.$2),
        text: entry.$2.replaceAll(_lyricsTimestampRegex, '').trim(),
      ),
  ];
}

int? _parseLyricsTimestamp(String line) {
  final match = RegExp(
    r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]',
  ).firstMatch(line);
  if (match == null) {
    return null;
  }

  final minutes = int.parse(match.group(1)!);
  final seconds = int.parse(match.group(2)!);
  final fractionText = match.group(3) ?? '0';
  final fraction = int.parse(fractionText.padRight(3, '0').substring(0, 3));
  return minutes * 60000 + seconds * 1000 + fraction;
}

class _RankedSong {
  const _RankedSong({required this.song, required this.score});

  final LibrarySong song;
  final int score;
}

List<_RankedSong> _getAlbumArtRecommendationCandidates(
  LibrarySong song,
  List<LibrarySong> songs,
) {
  final artistKeys =
      _getSongArtists(song).map((artist) => artist.toLowerCase()).toSet();
  final candidates =
      songs
          .where((candidate) => candidate.id != song.id)
          .map((candidate) {
            final sameArtist = _getSongArtists(
              candidate,
            ).any((artist) => artistKeys.contains(artist.toLowerCase()));
            if (!sameArtist) {
              return null;
            }

            final sameAlbum =
                song.album.trim().isNotEmpty && candidate.album == song.album;
            final similarTitle = _isSimilarArtworkTitle(
              song.title,
              candidate.title,
            );
            if (!sameAlbum && !similarTitle) {
              return null;
            }

            return _RankedSong(
              song: candidate,
              score:
                  (sameAlbum ? 10 : 0) +
                  (similarTitle ? 4 : 0) +
                  (candidate.playCount > 0 ? 1 : 0),
            );
          })
          .whereType<_RankedSong>()
          .toList()
        ..sort((left, right) {
          final scoreCompare = right.score.compareTo(left.score);
          if (scoreCompare != 0) {
            return scoreCompare;
          }
          return left.song.title.compareTo(right.song.title);
        });

  return candidates.take(24).toList();
}

List<_RankedSong> _getRankedArtworkSourceSongs({
  required List<LibrarySong> songs,
  required String albumName,
  required LibrarySong currentSong,
  required String normalizedQuery,
}) {
  final artistKeys =
      _getSongArtists(
        currentSong,
      ).map((artist) => artist.toLowerCase()).toSet();
  final librarySongs =
      songs.where((song) => song.id != currentSong.id).toList();
  final ranked =
      librarySongs
          .map((song) {
            final searchableText = _normalizeSearchText(
              '${song.title} ${song.album} ${_getSongArtists(song).join(' ')}',
            );
            if (normalizedQuery.isNotEmpty &&
                !searchableText.contains(normalizedQuery)) {
              return null;
            }

            final sameAlbum = albumName.isNotEmpty && song.album == albumName;
            final sameArtist = _isSameArtistSong(song, artistKeys);
            final similarTitle = _isSimilarArtworkTitle(
              currentSong.title,
              song.title,
            );
            if (normalizedQuery.isEmpty && !sameArtist) {
              return null;
            }

            return _RankedSong(
              song: song,
              score:
                  (sameAlbum ? 40 : 0) +
                  (sameArtist ? 20 : 0) +
                  (similarTitle ? 12 : 0) +
                  song.playCount.clamp(0, 5).toInt(),
            );
          })
          .whereType<_RankedSong>()
          .toList();

  if (ranked.isEmpty && normalizedQuery.isEmpty) {
    return [
      for (final entry in librarySongs.take(20).indexed)
        _RankedSong(song: entry.$2, score: 20 - entry.$1),
    ];
  }

  ranked.sort((left, right) {
    final scoreCompare = right.score.compareTo(left.score);
    if (scoreCompare != 0) {
      return scoreCompare;
    }
    return left.song.title.compareTo(right.song.title);
  });
  return ranked;
}

bool _isSameArtistSong(LibrarySong song, Set<String> artistKeys) {
  return _getSongArtists(
    song,
  ).any((artist) => artistKeys.contains(artist.toLowerCase()));
}

List<String> _getSongArtists(LibrarySong song) {
  if (song.artists.isNotEmpty) {
    return song.artists;
  }

  return song.artist
      .split(RegExp(r',|;|/'))
      .map((artist) => artist.trim())
      .where((artist) => artist.isNotEmpty)
      .toList();
}

String _getDisplayArtists(LibrarySong song, SmPlayerI18n i18n) {
  final artists = _getSongArtists(song);
  if (artists.isEmpty) {
    return i18n.t('common.artistUnknown');
  }

  return artists.join(i18n.t('common.artistSeparator'));
}

String _normalizeSearchText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

String _normalizeArtworkMatchText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
      .replaceAll(RegExp(r'[\s\-_.:/\\|]+'), '')
      .trim();
}

bool _isSimilarArtworkTitle(String left, String right) {
  final normalizedLeft = _normalizeArtworkMatchText(left);
  final normalizedRight = _normalizeArtworkMatchText(right);

  return normalizedLeft.length >= 2 &&
      normalizedRight.length >= 2 &&
      (normalizedLeft.contains(normalizedRight) ||
          normalizedRight.contains(normalizedLeft));
}

class MusicInfoControl extends StatelessWidget {
  const MusicInfoControl({
    super.key,
    required this.loading,
    required this.saving,
    required this.properties,
    required this.artistControllers,
    required this.titleController,
    required this.subtitleController,
    required this.albumController,
    required this.albumArtistController,
    required this.playCountController,
    required this.publisherController,
    required this.trackNumberController,
    required this.yearController,
    required this.bitrateController,
    required this.composersController,
    required this.dateCreatedController,
    required this.dateModifiedController,
    required this.durationController,
    required this.fileSizeController,
    required this.fileTypeController,
    required this.genreController,
    required this.pathController,
    required this.canPause,
    required this.propertiesDirty,
    required this.onPlay,
    required this.onSave,
    required this.onReset,
    required this.onClearPlayCount,
    required this.onAddArtistCell,
    required this.onRemoveArtistCell,
    required this.onReveal,
  });

  final bool loading;
  final bool saving;
  final SongPropertiesSnapshot? properties;
  final List<TextEditingController> artistControllers;
  final TextEditingController titleController;
  final TextEditingController subtitleController;
  final TextEditingController albumController;
  final TextEditingController albumArtistController;
  final TextEditingController playCountController;
  final TextEditingController publisherController;
  final TextEditingController trackNumberController;
  final TextEditingController yearController;
  final TextEditingController bitrateController;
  final TextEditingController composersController;
  final TextEditingController dateCreatedController;
  final TextEditingController dateModifiedController;
  final TextEditingController durationController;
  final TextEditingController fileSizeController;
  final TextEditingController fileTypeController;
  final TextEditingController genreController;
  final TextEditingController pathController;
  final bool canPause;
  final bool propertiesDirty;
  final VoidCallback? onPlay;
  final VoidCallback onSave;
  final VoidCallback onReset;
  final VoidCallback onClearPlayCount;
  final VoidCallback onAddArtistCell;
  final ValueChanged<int> onRemoveArtistCell;
  final ValueChanged<String>? onReveal;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return Column(
      children: [
        _MusicDialogCommandBar(
          children: [
            if (onPlay != null)
              _MusicDialogCommandButton(
                icon:
                    canPause
                        ? FluentIcons.pause_20_regular
                        : FluentIcons.play_20_regular,
                label:
                    canPause ? i18n.t('context.pause') : i18n.t('context.play'),
                onPressed: onPlay,
              ),
            _MusicDialogCommandButton(
              icon: FluentIcons.save_20_regular,
              label: i18n.t('settings.save'),
              primary: true,
              disabled: loading || saving,
              onPressed: onSave,
            ),
            if (propertiesDirty)
              _MusicDialogCommandButton(
                icon: FluentIcons.arrow_reset_20_regular,
                label: i18n.t('common.reset'),
                disabled: loading || saving,
                onPressed: onReset,
              ),
          ],
        ),
        Expanded(
          child:
              loading || properties == null
                  ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 6, 28, 44),
                    child: _MusicInfoPropertyList(
                      children: [
                        _PropertyRow(
                          label: i18n.t('table.title'),
                          child: _DialogField(controller: titleController),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.subtitle'),
                          child: _DialogField(controller: subtitleController),
                        ),
                        _PropertyRow(
                          label: i18n.t('common.artist'),
                          child: _ArtistFieldGrid(
                            controllers: artistControllers,
                            saving: saving,
                            onAddArtistCell: onAddArtistCell,
                            onRemoveArtistCell: onRemoveArtistCell,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('common.album'),
                          child: _DialogField(controller: albumController),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.albumArtist'),
                          child: _DialogField(
                            controller: albumArtistController,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('common.playCount'),
                          child: Row(
                            children: [
                              Expanded(
                                child: _DialogField(
                                  controller: playCountController,
                                  readOnly: true,
                                ),
                              ),
                              if ((properties?.playCount ?? 0) > 0) ...[
                                const SizedBox(width: 8),
                                _MusicDialogCommandButton(
                                  label: i18n.t('song.clearPlayCount'),
                                  compact: true,
                                  disabled: saving,
                                  onPressed: onClearPlayCount,
                                ),
                              ],
                            ],
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.publisher'),
                          child: _DialogField(controller: publisherController),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.trackNumber'),
                          child: _DialogField(
                            controller: trackNumberController,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.year'),
                          child: _DialogField(controller: yearController),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.bitrate'),
                          child: _DialogField(
                            controller: bitrateController,
                            readOnly: true,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.composers'),
                          child: _DialogField(
                            controller: composersController,
                            readOnly: true,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.dateCreated'),
                          child: _DialogField(
                            controller: dateCreatedController,
                            readOnly: true,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.dateModified'),
                          child: _DialogField(
                            controller: dateModifiedController,
                            readOnly: true,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('common.duration'),
                          child: _DialogField(
                            controller: durationController,
                            readOnly: true,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.fileSize'),
                          child: _DialogField(
                            controller: fileSizeController,
                            readOnly: true,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.fileType'),
                          child: _DialogField(
                            controller: fileTypeController,
                            readOnly: true,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('song.genre'),
                          child: _DialogField(
                            controller: genreController,
                            readOnly: true,
                          ),
                        ),
                        _PropertyRow(
                          label: i18n.t('local.path'),
                          child: Row(
                            children: [
                              Expanded(
                                child: _DialogField(
                                  controller: pathController,
                                  readOnly: true,
                                ),
                              ),
                              if (onReveal != null) ...[
                                const SizedBox(width: 8),
                                _MusicDialogCommandButton(
                                  label: i18n.t('song.showInExplorer'),
                                  compact: true,
                                  onPressed: () {
                                    onReveal!(pathController.text);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
        ),
      ],
    );
  }
}

class MusicLyricsControl extends StatelessWidget {
  const MusicLyricsControl({
    super.key,
    required this.loading,
    required this.saving,
    required this.lyrics,
    required this.lyricsController,
    required this.lyricsDirty,
    required this.showLyricsTimestamps,
    required this.lyricsCanToggleTimestamps,
    required this.onSearch,
    required this.onImport,
    required this.onSave,
    required this.onReset,
    required this.onToggleTimestamps,
  });

  final bool loading;
  final bool saving;
  final LyricsSnapshot? lyrics;
  final TextEditingController lyricsController;
  final bool lyricsDirty;
  final bool showLyricsTimestamps;
  final bool lyricsCanToggleTimestamps;
  final VoidCallback onSearch;
  final VoidCallback onImport;
  final VoidCallback onSave;
  final VoidCallback onReset;
  final ValueChanged<bool> onToggleTimestamps;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return Column(
      children: [
        _MusicDialogCommandBar(
          children: [
            _MusicDialogCommandButton(
              icon: FluentIcons.search_20_regular,
              label: i18n.t('common.search'),
              disabled: loading || saving,
              onPressed: onSearch,
            ),
            _MusicDialogCommandButton(
              icon: FluentIcons.arrow_import_20_regular,
              label: i18n.t('common.import'),
              disabled: loading || saving,
              onPressed: onImport,
            ),
            _MusicDialogCommandButton(
              icon: FluentIcons.save_20_regular,
              label: i18n.t('settings.save'),
              primary: true,
              disabled: loading || saving,
              onPressed: onSave,
            ),
            if (lyricsDirty)
              _MusicDialogCommandButton(
                icon: FluentIcons.arrow_reset_20_regular,
                label: i18n.t('common.reset'),
                disabled: loading || saving,
                onPressed: onReset,
              ),
            if (lyricsCanToggleTimestamps)
              _LyricsTimestampToggle(
                value: showLyricsTimestamps,
                onChanged: loading || saving ? null : onToggleTimestamps,
              ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 44),
            child:
                loading
                    ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : TextField(
                      controller: lyricsController,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      enabled: !saving,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText:
                            lyrics?.source == LyricsSource.none
                                ? i18n.t('nowPlaying.noLyrics')
                                : '',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: PopupDialogColors.fieldSurface,
                      ),
                      style: const TextStyle(height: 1.7),
                    ),
          ),
        ),
      ],
    );
  }
}

class MusicAlbumArtControl extends StatelessWidget {
  const MusicAlbumArtControl({
    super.key,
    required this.song,
    required this.loading,
    required this.saving,
    required this.artworkUrl,
    required this.artworkDirty,
    required this.recommendation,
    required this.showDeleteConfirm,
    required this.onApplyRecommendation,
    required this.onChangeArtwork,
    required this.onChooseArtworkFromLibrary,
    required this.onSaveArtwork,
    required this.onResetArtwork,
    required this.onRequestDelete,
    required this.onConfirmDelete,
    required this.onCancelDelete,
  });

  final LibrarySong song;
  final bool loading;
  final bool saving;
  final String artworkUrl;
  final bool artworkDirty;
  final AlbumArtRecommendation? recommendation;
  final bool showDeleteConfirm;
  final ValueChanged<AlbumArtRecommendation> onApplyRecommendation;
  final VoidCallback onChangeArtwork;
  final VoidCallback onChooseArtworkFromLibrary;
  final VoidCallback onSaveArtwork;
  final VoidCallback onResetArtwork;
  final VoidCallback onRequestDelete;
  final VoidCallback onConfirmDelete;
  final VoidCallback onCancelDelete;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final artworkFile = artworkUrl.isEmpty ? null : File(artworkUrl);

    return Column(
      children: [
        _MusicDialogCommandBar(
          children: [
            _ArtworkSourceButton(
              disabled: loading || saving,
              onChangeArtwork: onChangeArtwork,
              onChooseArtworkFromLibrary: onChooseArtworkFromLibrary,
            ),
            _MusicDialogCommandButton(
              icon: FluentIcons.save_20_regular,
              label: i18n.t('settings.save'),
              primary: true,
              disabled: loading || saving,
              onPressed: onSaveArtwork,
            ),
            if (artworkDirty)
              _MusicDialogCommandButton(
                icon: FluentIcons.arrow_reset_20_regular,
                label: i18n.t('common.reset'),
                disabled: loading || saving,
                onPressed: onResetArtwork,
              ),
            _MusicDialogCommandButton(
              icon: FluentIcons.delete_20_regular,
              label: i18n.t('playlists.delete'),
              disabled: loading || saving,
              onPressed: onRequestDelete,
            ),
          ],
        ),
        Expanded(
          child:
              loading
                  ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        artworkFile != null && artworkFile.existsSync()
                            ? Container(
                              width: 340,
                              height: 340,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x2932423a),
                                    blurRadius: 42,
                                    offset: Offset(0, 18),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.file(artworkFile, fit: BoxFit.cover),
                            )
                            : SizedBox.square(
                              dimension: 340,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xffe8eef5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      FluentIcons.image_24_regular,
                                      color: PopupDialogColors.textMuted,
                                      size: 46,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      i18n.t('song.noAlbumArt'),
                                      style: const TextStyle(
                                        color: PopupDialogColors.textMuted,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (recommendation != null) ...[
                                      const SizedBox(height: 12),
                                      _AlbumArtRecommendationText(
                                        recommendation: recommendation!,
                                        onApply: onApplyRecommendation,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        if (showDeleteConfirm) ...[
                          const SizedBox(height: 18),
                          _ArtworkDeleteConfirm(
                            message: i18n.t('song.removeAlbumArt', {
                              'title': song.title,
                            }),
                            onConfirm: onConfirmDelete,
                            onCancel: onCancelDelete,
                          ),
                        ],
                      ],
                    ),
                  ),
        ),
      ],
    );
  }
}

class _MusicDialogCommandBar extends StatelessWidget {
  const _MusicDialogCommandBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: 12, runSpacing: 8, children: children),
      ),
    );
  }
}

class _MusicDialogCommandButton extends StatelessWidget {
  const _MusicDialogCommandButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.disabled = false,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final bool primary;
  final bool disabled;
  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground =
        disabled
            ? const Color(0xb35e6773)
            : primary
            ? Colors.white
            : PopupDialogColors.text;
    final background =
        disabled
            ? PopupDialogColors.fieldDisabledSurface
            : primary
            ? PopupDialogColors.accent
            : PopupDialogColors.buttonSurface;

    return TextButton.icon(
      style: TextButton.styleFrom(
        minimumSize: Size(0, compact ? 38 : 40),
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18),
        foregroundColor: foreground,
        backgroundColor: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color:
                primary && !disabled
                    ? const Color(0x850078d7)
                    : PopupDialogColors.buttonBorder,
          ),
        ),
      ),
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      onPressed: disabled ? null : onPressed,
    );
  }
}

class _MusicInfoPropertyList extends StatelessWidget {
  const _MusicInfoPropertyList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(children: children);
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Padding(
              padding: const EdgeInsets.only(top: 11),
              child: Text(
                label,
                style: const TextStyle(
                  color: PopupDialogColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({required this.controller, this.readOnly = false});

  final TextEditingController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        isDense: true,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor:
            readOnly
                ? PopupDialogColors.fieldDisabledSurface
                : PopupDialogColors.fieldSurface,
      ),
    );
  }
}

class _ArtistFieldGrid extends StatelessWidget {
  const _ArtistFieldGrid({
    required this.controllers,
    required this.saving,
    required this.onAddArtistCell,
    required this.onRemoveArtistCell,
  });

  final List<TextEditingController> controllers;
  final bool saving;
  final VoidCallback onAddArtistCell;
  final ValueChanged<int> onRemoveArtistCell;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  controllers.length > 1 && constraints.maxWidth >= 420 ? 2 : 1;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in controllers.indexed)
                    SizedBox(
                      width:
                          columns == 2
                              ? (constraints.maxWidth - 8) / 2
                              : constraints.maxWidth,
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          _DialogField(controller: entry.$2),
                          if (controllers.length > 1)
                            IconButton(
                              icon: const Icon(
                                FluentIcons.dismiss_16_regular,
                                size: 14,
                              ),
                              onPressed:
                                  saving
                                      ? null
                                      : () {
                                        onRemoveArtistCell(entry.$1);
                                      },
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        _MusicDialogCommandButton(
          icon: FluentIcons.add_20_regular,
          label: context.smPlayerI18n.t('common.add'),
          compact: true,
          disabled:
              saving || controllers.length >= _MusicDialogState.maxArtistCells,
          onPressed: onAddArtistCell,
        ),
      ],
    );
  }
}

class _LyricsTimestampToggle extends StatelessWidget {
  const _LyricsTimestampToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged:
                onChanged == null
                    ? null
                    : (value) {
                      onChanged!(value ?? false);
                    },
          ),
          Text(
            context.smPlayerI18n.t('song.showLyricsTimestamps'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

enum _ArtworkSource { local, library }

class _ArtworkSourceButton extends StatelessWidget {
  const _ArtworkSourceButton({
    required this.disabled,
    required this.onChangeArtwork,
    required this.onChooseArtworkFromLibrary,
  });

  final bool disabled;
  final VoidCallback onChangeArtwork;
  final VoidCallback onChooseArtworkFromLibrary;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return PopupMenuButton<_ArtworkSource>(
      enabled: !disabled,
      onSelected: (source) {
        switch (source) {
          case _ArtworkSource.local:
            onChangeArtwork();
          case _ArtworkSource.library:
            onChooseArtworkFromLibrary();
        }
      },
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: _ArtworkSource.local,
              child: Text(i18n.t('song.chooseArtworkFromLocal')),
            ),
            PopupMenuItem(
              value: _ArtworkSource.library,
              child: Text(i18n.t('song.chooseArtworkFromLibrary')),
            ),
          ],
      child: IgnorePointer(
        child: _MusicDialogCommandButton(
          icon: FluentIcons.edit_20_regular,
          label: i18n.t('song.changeArtwork'),
          disabled: disabled,
          onPressed: () {},
        ),
      ),
    );
  }
}

class _AlbumArtRecommendationText extends StatelessWidget {
  const _AlbumArtRecommendationText({
    required this.recommendation,
    required this.onApply,
  });

  final AlbumArtRecommendation recommendation;
  final ValueChanged<AlbumArtRecommendation> onApply;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 270),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            i18n.t('song.albumArtRecommendationPrefix', {
              'artist': recommendation.artistName,
            }),
            textAlign: TextAlign.center,
            style: const TextStyle(color: PopupDialogColors.textMuted),
          ),
          TextButton(
            onPressed: () {
              onApply(recommendation);
            },
            child: Text(
              i18n.t('song.albumArtRecommendationTitle', {
                'title': recommendation.song.title,
              }),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            i18n.t('song.albumArtRecommendationSuffix'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: PopupDialogColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _AlbumArtLibraryPickerDialog extends ConsumerStatefulWidget {
  const _AlbumArtLibraryPickerDialog({
    required this.albumName,
    required this.currentSong,
    required this.songs,
    required this.onApply,
    required this.onClose,
  });

  final String albumName;
  final LibrarySong currentSong;
  final List<LibrarySong> songs;
  final ValueChanged<AlbumArtLibraryChoice> onApply;
  final VoidCallback onClose;

  @override
  ConsumerState<_AlbumArtLibraryPickerDialog> createState() =>
      _AlbumArtLibraryPickerDialogState();
}

class _AlbumArtLibraryPickerDialogState
    extends ConsumerState<_AlbumArtLibraryPickerDialog> {
  final _queryController = TextEditingController();
  final _snapshotsBySongId = <int, SongArtworkSnapshot>{};
  var _query = '';
  var _loading = true;
  int? _selectedSongId;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_handleQueryChanged);
    _loadSnapshots();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    setState(() {
      _query = _queryController.text;
    });
    _loadSnapshots();
  }

  Future<void> _loadSnapshots() async {
    final missingSongIds =
        _rankedSongs
            .take(320)
            .map((ranked) => ranked.song.id)
            .where((songId) => !_snapshotsBySongId.containsKey(songId))
            .toList();
    if (missingSongIds.isEmpty) {
      setState(() {
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
    });
    final snapshots = await ref
        .read(libraryRepositoryProvider)
        .getSongArtworkSnapshots(missingSongIds);
    if (!mounted) {
      return;
    }

    setState(() {
      for (final snapshot in snapshots) {
        _snapshotsBySongId[snapshot.songId] = snapshot;
      }
      _loading = false;
    });
  }

  List<_RankedSong> get _rankedSongs {
    return _getRankedArtworkSourceSongs(
      songs: widget.songs,
      albumName: widget.albumName,
      currentSong: widget.currentSong,
      normalizedQuery: _normalizeSearchText(_query),
    );
  }

  List<AlbumArtLibraryChoice> get _choices {
    final choices =
        _rankedSongs
            .take(320)
            .map((ranked) {
              final snapshot = _snapshotsBySongId[ranked.song.id];
              if (snapshot == null ||
                  snapshot.source == SongArtworkSource.none ||
                  snapshot.sourcePath.isEmpty ||
                  snapshot.sourceUrl.isEmpty) {
                return null;
              }

              return AlbumArtLibraryChoice(
                song: ranked.song,
                artworkUrl: snapshot.artworkUrl,
                sourceUrl: snapshot.sourceUrl,
                sourcePath: snapshot.sourcePath,
              );
            })
            .whereType<AlbumArtLibraryChoice>()
            .toList();

    return _query.trim().isEmpty ? choices : choices.take(160).toList();
  }

  AlbumArtLibraryChoice? get _selectedChoice {
    final choices = _choices;
    return choices
            .where((choice) => choice.song.id == _selectedSongId)
            .firstOrNull ??
        choices.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final choices = _choices;
    final selectedChoice = _selectedChoice;

    return PopupDialog(
      overlayClassName: 'album-art-library-picker-overlay',
      className: 'album-art-library-picker-dialog ContentDialog',
      navClassName: 'album-art-library-picker-nav',
      navLabel: i18n.t('song.chooseArtworkFromLibrary'),
      ariaLabel: i18n.t('song.chooseArtworkFromLibrary'),
      width: 860,
      height: 680,
      onClose: widget.onClose,
      navChildren: [
        Expanded(
          child: Text(
            i18n.t('song.chooseArtworkFromLibrary'),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PopupDialogColors.textStrong,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onClose,
              child: Text(i18n.t('common.cancel')),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed:
                  selectedChoice == null
                      ? null
                      : () {
                        widget.onApply(selectedChoice);
                      },
              child: Text(i18n.t('song.useSelectedArtwork')),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                prefixIcon: const Icon(FluentIcons.search_20_regular),
                suffixIcon:
                    _query.isEmpty
                        ? null
                        : IconButton(
                          icon: const Icon(FluentIcons.dismiss_20_regular),
                          onPressed: _queryController.clear,
                        ),
                hintText: i18n.t('song.searchLibraryArtwork'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child:
                        _loading
                            ? const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : choices.isEmpty
                            ? Center(
                              child: Text(i18n.t('song.noLibraryArtwork')),
                            )
                            : ListView.separated(
                              itemCount: choices.length,
                              separatorBuilder:
                                  (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final choice = choices[index];
                                final selected =
                                    selectedChoice?.song.id == choice.song.id;
                                return _AlbumArtChoiceTile(
                                  choice: choice,
                                  selected: selected,
                                  onTap: () {
                                    setState(() {
                                      _selectedSongId = choice.song.id;
                                    });
                                  },
                                  onDoubleTap: () {
                                    widget.onApply(choice);
                                  },
                                );
                              },
                            ),
                  ),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: 220,
                    child:
                        selectedChoice == null
                            ? const SizedBox.shrink()
                            : _AlbumArtChoicePreview(choice: selectedChoice),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumArtChoiceTile extends StatelessWidget {
  const _AlbumArtChoiceTile({
    required this.choice,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final AlbumArtLibraryChoice choice;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return InkWell(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              selected
                  ? PopupDialogColors.activeButtonSurface
                  : PopupDialogColors.buttonSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                selected
                    ? PopupDialogColors.activeButtonBorder
                    : PopupDialogColors.buttonBorder,
          ),
        ),
        child: Row(
          children: [
            _ArtworkImage(url: choice.artworkUrl, size: 58),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    choice.song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    _getDisplayArtists(choice.song, i18n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: PopupDialogColors.textMuted),
                  ),
                  Text(
                    choice.song.album.isEmpty
                        ? i18n.t('common.albumUnknown')
                        : choice.song.album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: PopupDialogColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumArtChoicePreview extends StatelessWidget {
  const _AlbumArtChoicePreview({required this.choice});

  final AlbumArtLibraryChoice choice;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ArtworkImage(url: choice.artworkUrl, size: 220),
        const SizedBox(height: 12),
        Text(
          choice.song.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          _getDisplayArtists(choice.song, i18n),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          choice.song.album.isEmpty
              ? i18n.t('common.albumUnknown')
              : choice.song.album,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ArtworkImage extends StatelessWidget {
  const _ArtworkImage({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child:
            File(url).existsSync()
                ? Image.file(File(url), fit: BoxFit.cover)
                : const ColoredBox(color: Color(0xffe8eef5)),
      ),
    );
  }
}

class _ArtworkDeleteConfirm extends StatelessWidget {
  const _ArtworkDeleteConfirm({
    required this.message,
    required this.onConfirm,
    required this.onCancel,
  });

  final String message;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfffff7ed),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffffd7aa)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(message)),
          const SizedBox(width: 10),
          FilledButton(onPressed: onConfirm, child: Text(i18n.t('common.yes'))),
          const SizedBox(width: 8),
          TextButton(onPressed: onCancel, child: Text(i18n.t('common.cancel'))),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
}

String _formatDateTime(String value) {
  final dateTime = DateTime.tryParse(value);
  return dateTime == null ? value : dateTime.toLocal().toString();
}
