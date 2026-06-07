import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/svg_icon.dart';
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
  var _showDeleteConfirm = false;
  var _saving = false;
  var _statusMessage = '';
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
          navChildren: [
            PopupDialogTab(
              label: i18n.t('song.albumArt'),
              iconWidget: const _AlbumArtworkDialogAlbumsIcon(),
              selected: true,
              first: true,
              last: true,
              onPressed: () {},
            ),
          ],
          afterNav:
              _statusMessage.isEmpty
                  ? null
                  : _AlbumArtworkStatusMessage(message: _statusMessage),
          child: _AlbumArtworkDialogBody(
            title: widget.albumName,
            artworkUrl: _currentArtworkUrl,
            songId: widget.songId,
            saving: _saving,
            artworkDirty: _artworkSourcePath.isNotEmpty,
            showDeleteConfirm: _showDeleteConfirm,
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
                _showDeleteConfirm = true;
              });
            },
            onConfirmDelete: _deleteArtwork,
            onCancelDelete: () {
              setState(() {
                _showDeleteConfirm = false;
              });
            },
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
      setState(() {
        _statusMessage = context.smPlayerI18n.t('song.processingRequest');
      });
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
        _showDeleteConfirm = false;
        _statusMessage = '';
      });
    } on StateError {
      if (mounted) {
        setState(() {
          _statusMessage = i18n.t('song.musicNoAlbumArt', {
            'title': sourceName,
          });
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = i18n.t('song.updateFailed');
        });
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
      setState(() {
        _statusMessage = context.smPlayerI18n.t('song.processingRequest');
      });
      return;
    }
    if (_artworkSourcePath.isEmpty) {
      setState(() {
        _statusMessage = '';
      });
      return;
    }
    final i18n = context.smPlayerI18n;

    setState(() {
      _saving = true;
    });
    try {
      await ref
          .read(libraryRepositoryProvider)
          .saveAlbumArtwork(widget.albumName, _artworkSourcePath);
      if (!mounted) {
        return;
      }
      setState(() {
        _originalArtworkUrl = _currentArtworkUrl;
        _artworkSourcePath = '';
        _statusMessage = i18n.t('song.albumArtSaved');
      });
      widget.onSaved();
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = i18n.t('song.updateFailed');
        });
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
      _showDeleteConfirm = false;
      _statusMessage = '';
      _libraryArtworkPickerOpen = false;
    });
  }

  Future<void> _deleteArtwork() async {
    if (_saving) {
      setState(() {
        _statusMessage = context.smPlayerI18n.t('song.processingRequest');
      });
      return;
    }
    final i18n = context.smPlayerI18n;

    setState(() {
      _saving = true;
    });
    try {
      await ref
          .read(libraryRepositoryProvider)
          .deleteAlbumArtwork(widget.albumName);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentArtworkUrl = '';
        _originalArtworkUrl = '';
        _artworkSourcePath = '';
        _showDeleteConfirm = false;
        _statusMessage = i18n.t('song.albumArtDeleted');
      });
      widget.onSaved();
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = i18n.t('song.updateFailed');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _resetArtwork() {
    setState(() {
      _currentArtworkUrl = _originalArtworkUrl;
      _artworkSourcePath = '';
      _showDeleteConfirm = false;
      _statusMessage = context.smPlayerI18n.t('song.albumArtReset');
    });
  }
}

class _AlbumArtworkDialogAlbumsIcon extends StatelessWidget {
  const _AlbumArtworkDialogAlbumsIcon();

  static const _svg =
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.35" stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke" xmlns="http://www.w3.org/2000/svg"><circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="0.7" fill="currentColor" stroke="none"/></svg>';

  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color ??
        Colors.black;
    return SvgIcon(
      key: const ValueKey('MusicDialog.ElectronIcon.albums'),
      svg: _svg,
      size: 16,
      color: color,
    );
  }
}

class _AlbumArtworkDialogBody extends StatelessWidget {
  const _AlbumArtworkDialogBody({
    required this.title,
    required this.artworkUrl,
    required this.songId,
    required this.saving,
    required this.artworkDirty,
    required this.showDeleteConfirm,
    required this.onChangeArtwork,
    required this.onChooseArtworkFromLibrary,
    required this.onSaveArtwork,
    required this.onResetArtwork,
    required this.onRequestDelete,
    required this.onConfirmDelete,
    required this.onCancelDelete,
  });

  final String title;
  final String artworkUrl;
  final int songId;
  final bool saving;
  final bool artworkDirty;
  final bool showDeleteConfirm;
  final VoidCallback onChangeArtwork;
  final VoidCallback onChooseArtworkFromLibrary;
  final VoidCallback onSaveArtwork;
  final VoidCallback onResetArtwork;
  final VoidCallback onRequestDelete;
  final VoidCallback onConfirmDelete;
  final VoidCallback onCancelDelete;

  @override
  Widget build(BuildContext context) {
    return AlbumArtEditorControl(
      title: title,
      saving: saving,
      showBusy: saving,
      artworkUrl: artworkUrl,
      artworkDirty: artworkDirty,
      songId: songId,
      showDeleteConfirm: showDeleteConfirm,
      onChangeArtwork: onChangeArtwork,
      onChooseArtworkFromLibrary: onChooseArtworkFromLibrary,
      onSaveArtwork: onSaveArtwork,
      onResetArtwork: artworkDirty ? onResetArtwork : null,
      onRequestDelete: onRequestDelete,
      onConfirmDelete: onConfirmDelete,
      onCancelDelete: onCancelDelete,
    );
  }
}

class _AlbumArtworkStatusMessage extends StatelessWidget {
  const _AlbumArtworkStatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return SizedBox(
      width: double.infinity,
      child: Text(
        message,
        key: const ValueKey('AlbumArtworkDialog.StatusMessage'),
        style: TextStyle(
          color: colors.text,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
