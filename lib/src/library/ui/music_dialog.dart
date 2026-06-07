import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
// ignore: unnecessary_import
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
// ignore: unused_import
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:smplayer_flutter/src/app/app_interaction_colors.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/app/svg_icon.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar_colors.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/page_search_history_panel.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart'
    as song_display;
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LyricsRequestMode;
import 'package:path/path.dart' as p;

part 'music_dialog_helpers.dart';
part 'music_info_control.dart';
part 'music_lyrics_control.dart';
part 'music_album_art_control.dart';
part 'music_dialog_controls.dart';
part 'album_art_library_picker_dialog.dart';
part 'music_dialog_state_helpers.dart';

typedef MusicDialogPlayTrackCallback =
    void Function(int trackId, List<int> queueSongIds);
typedef MusicDialogEntry =
    ({LibrarySong song, SongDialogMode mode, List<int> queueSongIds});

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
  var _discardLyricsConfirmOpen = false;
  SongPropertiesSnapshot? _properties;
  SongPropertiesSnapshot? _originalProperties;
  LyricsSnapshot? _lyrics;
  String _lyricsRawText = '';
  String _originalLyricsText = '';
  String _displayArtworkUrl = '';
  String _originalDisplayArtworkUrl = '';
  String _artworkSourcePath = '';
  var _artworkMissing = false;
  var _originalArtworkMissing = false;
  var _artworkRecommendationLoading = false;
  var _artworkRecommendationRequestKey = '';
  AlbumArtRecommendation? _artworkRecommendation;
  var _libraryArtworkPickerOpen = false;
  var _loadGeneration = 0;
  var _dependenciesInitialized = false;
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
  final _lyricsScrollController = ScrollController();
  final _artistControllers = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    _addControllerListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesInitialized) {
      return;
    }
    _dependenciesInitialized = true;
    _loadSong();
  }

  @override
  void didUpdateWidget(covariant MusicDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _queuePendingLyricsNotificationIfNeeded(
        songId: oldWidget.song.id,
        title: oldWidget.song.title,
        rawLyrics: _currentLyricsRawText,
        refreshLatestLyrics: true,
      );
    } else if (oldWidget.currentTrackId == oldWidget.song.id &&
        widget.currentTrackId != widget.song.id) {
      _queuePendingLyricsNotificationIfNeeded(
        songId: widget.song.id,
        title: widget.song.title,
        rawLyrics: _currentLyricsRawText,
        refreshLatestLyrics: true,
      );
    }
    if (oldWidget.initialMode != widget.initialMode) {
      _mode = widget.initialMode;
    }
    if (oldWidget.song.id != widget.song.id) {
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
    ]) {
      controller.addListener(_handleEditorChanged);
    }
    _lyricsController.addListener(_handleLyricsEditorChanged);
  }

  void _handleEditorChanged() {
    if (mounted && !_updatingControllers) {
      setState(() {});
    }
  }

  void _handleLyricsEditorChanged() {
    if (mounted && !_updatingControllers) {
      if (_showLyricsTimestamps) {
        _lyricsRawText = _lyricsController.text;
      }
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
    _lyricsScrollController.dispose();
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
    final artworkRecommendationRequestKey =
        _artworkMissing &&
                !_artworkRecommendationLoading &&
                _artworkRecommendation == null &&
                librarySongs.isNotEmpty
            ? _albumArtRecommendationRequestKey(widget.song, librarySongs)
            : '';
    if (_artworkMissing &&
        !_artworkRecommendationLoading &&
        _artworkRecommendation == null &&
        librarySongs.isNotEmpty &&
        artworkRecommendationRequestKey != _artworkRecommendationRequestKey) {
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
                iconWidget: const _ElectronIcon(_ElectronIconName.info),
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
                iconWidget: const _ElectronIcon(_ElectronIconName.lyrics),
                selected: _mode == SongDialogMode.lyrics,
                onPressed: () {
                  setState(() {
                    _mode = SongDialogMode.lyrics;
                  });
                },
              ),
              PopupDialogTab(
                label: _dialogTabLabel(i18n.t('context.seeAlbumArt')),
                iconWidget: const _ElectronIcon(_ElectronIconName.pictures),
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
                lyricsScrollController: _lyricsScrollController,
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
                artworkUrl: _displayArtworkUrl,
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
            AlbumArtLibraryPickerDialog(
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
    final generation = ++_loadGeneration;
    final songId = widget.song.id;
    final repository = ref.read(libraryRepositoryProvider);
    setState(() {
      _loading = true;
      _lyricsLoading = true;
      _artworkLoading = true;
      _showArtworkDeleteConfirm = false;
      _artworkSourcePath = '';
      _artworkRecommendation = null;
      _artworkRecommendationLoading = false;
      _artworkRecommendationRequestKey = '';
      _libraryArtworkPickerOpen = false;
    });

    await Future.wait<void>([
      _loadProperties(repository, songId, generation),
      _loadLyrics(repository, songId, generation),
      _loadArtwork(repository, songId, generation),
    ]);
  }

  Future<void> _loadProperties(
    LibraryRepository repository,
    int songId,
    int generation,
  ) async {
    try {
      final properties = await repository.getSongProperties(songId);
      if (!_isActiveLoad(songId, generation)) {
        return;
      }

      setState(() {
        _applyProperties(properties);
        _loading = false;
      });
    } catch (_) {}
  }

  Future<void> _loadLyrics(
    LibraryRepository repository,
    int songId,
    int generation,
  ) async {
    final i18n = context.smPlayerI18n;
    try {
      final lyrics = await repository.getSongLyrics(
        songId,
        mode: LyricsRequestMode.embedded,
      );
      if (!_isActiveLoad(songId, generation)) {
        return;
      }

      setState(() {
        _lyrics = lyrics;
        _lyricsRawText = lyrics.rawText;
        _originalLyricsText = lyrics.rawText;
        _lyricsController.text = lyrics.rawText;
        _lyricsLoading = false;
      });
    } catch (_) {
      if (_isActiveLoad(songId, generation)) {
        setState(() {
          _lyricsLoading = false;
        });
        _showMessage(i18n.t('song.getLyricsFailed'));
      }
    }
  }

  Future<void> _loadArtwork(
    LibraryRepository repository,
    int songId,
    int generation,
  ) async {
    try {
      final artwork = await repository.getSongArtworkSnapshot(songId);
      if (!_isActiveLoad(songId, generation)) {
        return;
      }

      setState(() {
        _displayArtworkUrl = artwork.artworkUrl;
        _originalDisplayArtworkUrl = artwork.artworkUrl;
        _artworkMissing =
            artwork.source == SongArtworkSource.none ||
            artwork.artworkUrl.isEmpty;
        _originalArtworkMissing = _artworkMissing;
        _artworkLoading = false;
      });
      await _resolveDisplayArtwork(repository, songId, generation);
      await _loadArtworkRecommendation();
    } catch (_) {
      if (_isActiveLoad(songId, generation)) {
        setState(() {
          _artworkLoading = false;
        });
      }
    }
  }

  Future<void> _resolveDisplayArtwork(
    LibraryRepository repository,
    int songId,
    int generation,
  ) async {
    if (!_artworkMissing || _displayArtworkUrl.isNotEmpty) {
      return;
    }
    final snapshots = await repository.getSongArtworkSnapshots([songId]);
    if (!_isActiveLoad(songId, generation)) {
      return;
    }
    final snapshot = snapshots.single;
    if (snapshot.artworkUrl.isEmpty) {
      return;
    }
    setState(() {
      _displayArtworkUrl = snapshot.artworkUrl;
      _originalDisplayArtworkUrl = snapshot.artworkUrl;
    });
  }

  bool _isActiveLoad(int songId, int generation) {
    return mounted && _loadGeneration == generation && widget.song.id == songId;
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

    final requestKey = _albumArtRecommendationRequestKey(widget.song, songs);
    if (requestKey == _artworkRecommendationRequestKey) {
      return;
    }
    _artworkRecommendationRequestKey = requestKey;

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
    if (_artworkRecommendationRequestKey != requestKey) {
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
        ).take(maxArtistCells).toList();
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
    if (!_isPropertiesModified(nextProperties, _originalProperties!)) {
      _applyProperties(nextProperties);
      _showMessage(i18n.t('song.propertiesUpdated'));
      return;
    }
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

    await ref
        .read(libraryRepositoryProvider)
        .updateSongPlayCount(widget.song.id, 0);
    if (!mounted) {
      return;
    }
    final nextProperties = _properties!.copyWith(playCount: 0);
    setState(() {
      _applyProperties(nextProperties);
    });
    _notifySaved();
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
        setState(() {
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
              setState(() {
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
    setState(() {
      _saving = true;
    });
    try {
      await ref
          .read(libraryRepositoryProvider)
          .saveSongLyrics(songId, rawLyrics);
      if (!mounted) {
        return;
      }
      ref.invalidate(libraryContentDataProvider);
      if (songId == widget.song.id) {
        _lyricsRawText = rawLyrics;
        _originalLyricsText = rawLyrics;
        _lyrics = _lyricsWithRawText(_lyrics, rawLyrics);
        widget.onSaved?.call();
        setState(() {});
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
    setState(() {
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

  void _resetProperties() {
    final originalProperties = _originalProperties;
    if (originalProperties == null || !_propertiesDirty) {
      return;
    }

    setState(() {
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
    setState(() {});
    _showMessage(context.smPlayerI18n.t('song.lyricsReset'));
  }

  void _resetArtwork() {
    if (_artworkSourcePath.isEmpty) {
      return;
    }
    setState(() {
      _displayArtworkUrl = _originalDisplayArtworkUrl;
      _artworkSourcePath = '';
      _artworkMissing = _originalArtworkMissing;
      _artworkRecommendation = null;
      _artworkRecommendationRequestKey = '';
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
      _displayArtworkUrl = recommendation.sourceUrl;
      _artworkSourcePath = recommendation.sourcePath;
      _artworkMissing = false;
      _artworkRecommendation = null;
      _showArtworkDeleteConfirm = false;
    });
  }

  void _applyAlbumArtLibraryChoice(AlbumArtLibraryChoice choice) {
    setState(() {
      _displayArtworkUrl = choice.sourceUrl;
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
}
