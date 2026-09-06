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
import 'package:smplayer_flutter/src/app/smplayer_auto_hide_scrollbar.dart';
import 'package:smplayer_flutter/src/app/svg_icon.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar_colors.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog_session_providers.dart';
import 'package:smplayer_flutter/src/library/ui/page_search_history_panel.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart'
    as song_display;
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart'
    show LyricsRequestMode;
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
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
part 'lyrics_search_picker_dialog.dart';
part 'music_dialog_state_helpers.dart';
part 'music_dialog_state_shortcut_actions.dart';
part 'music_dialog_state_load_actions.dart';
part 'music_dialog_state_property_actions.dart';
part 'music_dialog_state_lyrics_actions.dart';
part 'music_dialog_state_artwork_actions.dart';
part 'music_dialog_state_reset_actions.dart';
part 'music_dialog_tab_builders.dart';

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
    this.initialLyricsMatch,
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
  final String? initialLyricsMatch;

  @override
  ConsumerState<MusicDialog> createState() => _MusicDialogState();
}

class _MusicDialogState extends ConsumerState<MusicDialog> {
  static const maxArtistCells = 6;

  void _updateDialogStructure(VoidCallback callback) {
    setState(callback);
  }

  late var _mode = widget.initialMode;
  var _dialogSession = Object();
  late MusicDialogSessionKey _dialogSessionKey;
  var _updatingControllers = false;
  var _showLyricsTimestamps = true;
  var _artworkDeletePending = false;
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
  var _artworkRecommendationRequestKey = '';
  var _artworkRecommendationGeneration = 0;
  AlbumArtRecommendation? _artworkRecommendation;
  var _libraryArtworkPickerOpen = false;
  var _lyricsSearchPickerOpen = false;
  var _lyricsSearchCandidates = const <InternetLyricsCandidate>[];
  var _loadGeneration = 0;
  final _requestedModes = <SongDialogMode>{};
  int? _scheduledBrowseSongId;
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
    _dialogSessionKey = (session: _dialogSession, songId: widget.song.id);
    _addControllerListeners();
    _recordBrowseAfterFrame(widget.song.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesInitialized) {
      return;
    }
    _dependenciesInitialized = true;
    _scheduleLoadSong(_dialogSessionKey);
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
    if (oldWidget.song.id == widget.song.id &&
        oldWidget.initialMode != widget.initialMode) {
      _mode = widget.initialMode;
      unawaited(_loadCurrentMode());
    }
    if (oldWidget.song.id != widget.song.id) {
      _mode = widget.initialMode;
      _dialogSession = Object();
      _dialogSessionKey = (session: _dialogSession, songId: widget.song.id);
      _recordBrowseAfterFrame(widget.song.id);
      _scheduleLoadSong(_dialogSessionKey);
    }
  }

  void _scheduleLoadSong(MusicDialogSessionKey sessionKey) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dialogSessionKey != sessionKey) {
        return;
      }
      unawaited(_loadSong());
    });
  }

  void _recordBrowseAfterFrame(int songId) {
    if (_scheduledBrowseSongId == songId) {
      return;
    }
    _scheduledBrowseSongId = songId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.song.id != songId ||
          _scheduledBrowseSongId != songId) {
        return;
      }
      unawaited(_recordBrowse(songId));
    });
  }

  Future<void> _recordBrowse(int songId) async {
    final recentBrowses = ref.read(recentBrowsesProvider.notifier);
    final entry = await ref
        .read(libraryRepositoryProvider)
        .recordRecentBrowse(RecentBrowseType.song, '$songId');
    await recentBrowses.record(entry);
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
      ref
          .read(musicDialogPropertiesStateProvider(_dialogSessionKey).notifier)
          .setDirty(_propertiesDirty);
    }
  }

  void _handleLyricsEditorChanged() {
    if (mounted && !_updatingControllers) {
      if (_showLyricsTimestamps) {
        _lyricsRawText = _lyricsController.text;
      }
      ref
          .read(musicDialogLyricsStateProvider(_dialogSessionKey).notifier)
          .updateLyricsEditor(
            dirty: _lyricsDirty,
            canToggleTimestamps: _lyricsCanToggleTimestamps,
          );
    }
  }

  void _setPlayCountText(String value) {
    _playCountController.text = value;
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
    ref.watch(
      musicDialogPropertiesStateProvider(_dialogSessionKey).select((_) => null),
    );
    ref.watch(
      musicDialogLyricsStateProvider(_dialogSessionKey).select((_) => null),
    );
    ref.watch(
      musicDialogArtworkStateProvider(_dialogSessionKey).select((_) => null),
    );
    ref.watch(
      internetLyricsCandidateSearchProvider(
        _dialogSessionKey,
      ).select((_) => null),
    );
    final i18n = context.smPlayerI18n;
    ref.listen(libraryContentDataProvider, (previous, next) {
      if (next.hasValue && _requestedModes.contains(SongDialogMode.albumArt)) {
        unawaited(_loadArtworkRecommendation(librarySnapshotChanged: true));
      }
    });
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
                onPressed: () => _selectMode(SongDialogMode.properties),
              ),
              PopupDialogTab(
                label: _dialogTabLabel(i18n.t('context.seeLyrics')),
                iconWidget: const _ElectronIcon(_ElectronIconName.lyrics),
                selected: _mode == SongDialogMode.lyrics,
                onPressed: () => _selectMode(SongDialogMode.lyrics),
              ),
              PopupDialogTab(
                label: _dialogTabLabel(i18n.t('context.seeAlbumArt')),
                iconWidget: const _ElectronIcon(_ElectronIconName.pictures),
                selected: _mode == SongDialogMode.albumArt,
                last: true,
                onPressed: () => _selectMode(SongDialogMode.albumArt),
              ),
            ],
            child: switch (_mode) {
              SongDialogMode.properties => _buildPropertiesControl(
                canPause: canPause,
                canPlay: canPlay,
              ),
              SongDialogMode.lyrics => _buildLyricsControl(),
              SongDialogMode.albumArt => _buildAlbumArtControl(),
            },
          ),
          if (_libraryArtworkPickerOpen)
            Consumer(
              builder: (context, ref, child) {
                final librarySongs =
                    ref.watch(libraryContentDataProvider).valueOrNull?.songs ??
                    const <LibrarySong>[];
                return AlbumArtLibraryPickerDialog(
                  albumName: widget.song.album,
                  currentSong: widget.song,
                  songs: librarySongs,
                  onApply: _applyAlbumArtLibraryChoice,
                  onClose: () {
                    setState(() {
                      _libraryArtworkPickerOpen = false;
                    });
                  },
                );
              },
            ),
          if (_lyricsSearchPickerOpen)
            LyricsSearchPickerDialog(
              song: widget.song,
              candidates: _lyricsSearchCandidates,
              onApply: (candidate) {
                unawaited(_applyInternetLyricsCandidate(candidate));
              },
              onClose: () {
                setState(() {
                  _lyricsSearchPickerOpen = false;
                });
              },
            ),
        ],
      ),
    );
  }
}
