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
import 'package:smplayer_flutter/src/app/auto_hide_scrollbar_visibility.dart';
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
part 'music_dialog_command_bar.dart';
part 'music_dialog_save_progress.dart';
part 'song_dialog_loading.dart';
part 'song_dialog_scrollable_body.dart';
part 'music_dialog_command_button.dart';
part 'music_info_property_list.dart';
part 'music_dialog_fields.dart';
part 'music_dialog_icon_button.dart';
part 'lyrics_timestamp_toggle.dart';
part 'artwork_source_button.dart';
part 'music_dialog_electron_icon.dart';
part 'album_art_recommendation_text.dart';
part 'album_art_library_picker_dialog.dart';
part 'music_dialog_state_helpers.dart';
part 'music_dialog_state_shortcut_actions.dart';
part 'music_dialog_state_load_actions.dart';
part 'music_dialog_state_property_actions.dart';
part 'music_dialog_state_lyrics_actions.dart';
part 'music_dialog_state_artwork_actions.dart';
part 'music_dialog_state_reset_actions.dart';

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
}
