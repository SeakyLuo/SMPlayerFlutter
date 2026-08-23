import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:path/path.dart' as p;

const _albumArtworkSourceExtensions = [
  'jpg',
  'png',
  'jpeg',
  'webp',
  'bmp',
  'aac',
  'aiff',
  'alac',
  'ape',
  'flac',
  'm4a',
  'mp3',
  'ogg',
  'opus',
  'wav',
  'wma',
];

class AlbumArtworkDialog extends ConsumerStatefulWidget {
  const AlbumArtworkDialog({
    super.key,
    required this.albumName,
    required this.artworkUrl,
    required this.songId,
    required this.onClose,
    required this.onSaved,
  });

  final String albumName;
  final String artworkUrl;
  final int songId;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  @override
  ConsumerState<AlbumArtworkDialog> createState() => _AlbumArtworkDialogState();
}

class _AlbumArtworkDialogState extends ConsumerState<AlbumArtworkDialog> {
  var _currentArtworkUrl = '';
  var _originalArtworkUrl = '';
  var _artworkSourcePath = '';
  var _artworkDeletePending = false;
  var _saving = false;
  var _libraryArtworkPickerOpen = false;

  @override
  void initState() {
    super.initState();
    _currentArtworkUrl = widget.artworkUrl;
    _originalArtworkUrl = widget.artworkUrl;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final librarySongs =
        ref.watch(libraryContentDataProvider).valueOrNull?.songs ??
        const <LibrarySong>[];
    final currentSong =
        librarySongs.where((song) => song.id == widget.songId).firstOrNull;

    return Stack(
      children: [
        PopupDialog(
          overlayClassName: 'music-dialog-overlay AlbumDialogOverlay',
          className: 'album-artwork-dialog ContentDialog AlbumDialog',
          navClassName: 'music-dialog-pivot AlbumDialogPivot',
          navLabel: i18n.t('song.albumArt'),
          ariaLabel: i18n.t('song.albumArt'),
          onClose: widget.onClose,
          navChildren: const [],
          child: _AlbumArtworkDialogBody(
            artworkUrl: _currentArtworkUrl,
            songId: widget.songId,
            saving: _saving,
            artworkDirty:
                _artworkSourcePath.isNotEmpty || _artworkDeletePending,
            onChangeArtwork: _changeArtwork,
            onChooseArtworkFromLibrary: () {
              setState(() {
                _libraryArtworkPickerOpen = true;
              });
            },
            onSaveArtwork: _saveArtwork,
            onResetArtwork: _resetArtwork,
            onRequestDelete: _deleteArtwork,
          ),
        ),
        if (_libraryArtworkPickerOpen)
          AlbumArtLibraryPickerDialog(
            albumName: widget.albumName,
            currentSong: currentSong,
            songs: librarySongs,
            onApply: _applyLibraryArtwork,
            onClose: () {
              setState(() {
                _libraryArtworkPickerOpen = false;
              });
            },
          ),
      ],
    );
  }

  Future<void> _changeArtwork() async {
    if (_saving) {
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
        allowedExtensions: _albumArtworkSourceExtensions,
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
        _currentArtworkUrl = preparedPath;
        _artworkSourcePath = preparedPath;
        _artworkDeletePending = false;
      });
    } on StateError {
      if (mounted) {
        showAppNotification(
          context: context,
          message: i18n.t('song.musicNoAlbumArt', {'title': sourceName}),
        );
      }
    } catch (_) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: i18n.t('song.updateFailed'),
        );
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
      return;
    }
    if (_artworkSourcePath.isEmpty && !_artworkDeletePending) {
      return;
    }
    final i18n = context.smPlayerI18n;
    final deleteArtwork = _artworkDeletePending;

    setState(() {
      _saving = true;
    });
    try {
      final repository = ref.read(libraryRepositoryProvider);
      if (deleteArtwork) {
        await repository.deleteAlbumArtwork(widget.albumName);
      } else {
        await repository.saveAlbumArtwork(widget.albumName, _artworkSourcePath);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _originalArtworkUrl = _currentArtworkUrl;
        _artworkSourcePath = '';
        _artworkDeletePending = false;
      });
      widget.onSaved();
      showAppNotification(
        context: context,
        message: i18n.t(
          deleteArtwork ? 'song.albumArtDeleted' : 'song.albumArtSaved',
        ),
      );
    } catch (_) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: i18n.t('song.updateFailed'),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _applyLibraryArtwork(AlbumArtLibraryChoice choice) {
    setState(() {
      _currentArtworkUrl = choice.sourceUrl;
      _artworkSourcePath = choice.sourcePath;
      _artworkDeletePending = false;
      _libraryArtworkPickerOpen = false;
    });
  }

  void _deleteArtwork() {
    if (_saving) {
      return;
    }
    setState(() {
      _currentArtworkUrl = '';
      _artworkSourcePath = '';
      _artworkDeletePending = true;
    });
  }

  void _resetArtwork() {
    setState(() {
      _currentArtworkUrl = _originalArtworkUrl;
      _artworkSourcePath = '';
      _artworkDeletePending = false;
    });
  }
}

class _AlbumArtworkDialogBody extends StatelessWidget {
  const _AlbumArtworkDialogBody({
    required this.artworkUrl,
    required this.songId,
    required this.saving,
    required this.artworkDirty,
    required this.onChangeArtwork,
    required this.onChooseArtworkFromLibrary,
    required this.onSaveArtwork,
    required this.onResetArtwork,
    required this.onRequestDelete,
  });

  final String artworkUrl;
  final int songId;
  final bool saving;
  final bool artworkDirty;
  final VoidCallback onChangeArtwork;
  final VoidCallback onChooseArtworkFromLibrary;
  final VoidCallback onSaveArtwork;
  final VoidCallback onResetArtwork;
  final VoidCallback onRequestDelete;

  @override
  Widget build(BuildContext context) {
    return AlbumArtEditorControl(
      saving: saving,
      showBusy: saving,
      artworkUrl: artworkUrl,
      artworkDirty: artworkDirty,
      songId: songId,
      onChangeArtwork: onChangeArtwork,
      onChooseArtworkFromLibrary: onChooseArtworkFromLibrary,
      onSaveArtwork: onSaveArtwork,
      onResetArtwork: artworkDirty ? onResetArtwork : null,
      onRequestDelete: onRequestDelete,
    );
  }
}
