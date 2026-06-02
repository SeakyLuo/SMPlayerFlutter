import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart'
    as song_display;
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:url_launcher/url_launcher.dart';

part 'music_dialog_helpers.dart';
part 'music_info_control.dart';
part 'music_lyrics_control.dart';
part 'music_album_art_control.dart';
part 'music_dialog_controls.dart';
part 'album_art_library_picker_dialog.dart';

typedef MusicDialogPlayTrackCallback =
    void Function(int trackId, List<int> queueSongIds);

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
    this.currentTrackId,
    this.isPlaying = false,
    this.queueSongIds = const <int>[],
    this.onPlayTrack,
    this.onReveal,
    this.onSaved,
  });

  final LibrarySong song;
  final SongDialogMode initialMode;
  final VoidCallback onClose;
  final bool canPause;
  final VoidCallback? onPlay;
  final int? currentTrackId;
  final bool isPlaying;
  final List<int> queueSongIds;
  final MusicDialogPlayTrackCallback? onPlayTrack;
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
    final currentTrackId = widget.currentTrackId;
    final isCurrentSong =
        currentTrackId == null
            ? widget.canPause
            : currentTrackId == widget.song.id;
    final canPause =
        currentTrackId == null
            ? widget.canPause
            : isCurrentSong && widget.isPlaying;
    final canPlay = widget.onPlay != null || widget.onPlayTrack != null;
    final librarySongs =
        ref.watch(libraryContentDataProvider).valueOrNull?.songs ??
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
                canPause: canPause,
                propertiesDirty: _propertiesDirty,
                onPlay: canPlay ? _play : null,
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
              albumName: song_display.canonicalAlbumName(widget.song),
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
    final songs = ref.read(libraryContentDataProvider).valueOrNull?.songs;
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
      artist: song_display.displayArtists(widget.song, i18n),
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

  void _play() {
    final currentTrackId = widget.currentTrackId;
    if (currentTrackId == null || currentTrackId == widget.song.id) {
      widget.onPlay?.call();
      return;
    }

    widget.onPlayTrack?.call(widget.song.id, _playQueueSongIds);
  }

  List<int> get _playQueueSongIds {
    if (widget.queueSongIds.contains(widget.song.id)) {
      return widget.queueSongIds;
    }
    return [...widget.queueSongIds, widget.song.id];
  }

  void _notifySaved() {
    ref.invalidate(libraryContentDataProvider);
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
    showAppNotification(context: context, message: message);
  }
}
