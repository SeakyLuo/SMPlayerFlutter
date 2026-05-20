import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';

class AlbumArtworkDialog extends ConsumerStatefulWidget {
  const AlbumArtworkDialog({
    super.key,
    required this.albumName,
    required this.storedAlbumName,
    required this.artworkUrl,
    required this.songId,
    required this.onClose,
    required this.onSaved,
  });

  final String albumName;
  final String storedAlbumName;
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

  @override
  void initState() {
    super.initState();
    _currentArtworkUrl = widget.artworkUrl;
    _originalArtworkUrl = widget.artworkUrl;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return PopupDialog(
      overlayClassName: 'music-dialog-overlay AlbumDialogOverlay',
      className: 'album-artwork-dialog ContentDialog AlbumDialog',
      navClassName: 'music-dialog-pivot AlbumDialogPivot',
      navLabel: i18n.t('song.albumArt'),
      ariaLabel: i18n.t('song.albumArt'),
      width: 760,
      height: 720,
      onClose: widget.onClose,
      navChildren: [
        PopupDialogTab(
          label: i18n.t('song.albumArt'),
          icon: FluentIcons.album_20_regular,
          selected: true,
          onPressed: () {},
        ),
      ],
      afterNav:
          _statusMessage.isEmpty
              ? null
              : Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: _AlbumArtworkDialogColors.status,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
      child: _AlbumArtworkDialogBody(
        title: widget.albumName,
        artworkUrl: _currentArtworkUrl,
        saving: _saving,
        artworkDirty: _artworkSourcePath.isNotEmpty,
        showDeleteConfirm: _showDeleteConfirm,
        onChangeArtwork: _changeArtwork,
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
          .saveAlbumArtwork(widget.storedAlbumName, _artworkSourcePath);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentArtworkUrl = _artworkSourcePath;
        _originalArtworkUrl = _artworkSourcePath;
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
          .deleteAlbumArtwork(widget.storedAlbumName);
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

class _AlbumArtworkDialogBody extends StatelessWidget {
  const _AlbumArtworkDialogBody({
    required this.title,
    required this.artworkUrl,
    required this.saving,
    required this.artworkDirty,
    required this.showDeleteConfirm,
    required this.onChangeArtwork,
    required this.onSaveArtwork,
    required this.onResetArtwork,
    required this.onRequestDelete,
    required this.onConfirmDelete,
    required this.onCancelDelete,
  });

  final String title;
  final String artworkUrl;
  final bool saving;
  final bool artworkDirty;
  final bool showDeleteConfirm;
  final VoidCallback onChangeArtwork;
  final VoidCallback onSaveArtwork;
  final VoidCallback onResetArtwork;
  final VoidCallback onRequestDelete;
  final VoidCallback onConfirmDelete;
  final VoidCallback onCancelDelete;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final artworkFile = artworkUrl.isEmpty ? null : File(artworkUrl);
    final controlsDisabled = saving;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DialogActionButton(
                icon: FluentIcons.edit_20_regular,
                label: i18n.t('song.changeArtwork'),
                disabled: controlsDisabled,
                onPressed: onChangeArtwork,
              ),
              _DialogActionButton(
                icon: FluentIcons.save_20_regular,
                label: i18n.t('settings.save'),
                disabled: controlsDisabled || !artworkDirty,
                onPressed: onSaveArtwork,
              ),
              _DialogActionButton(
                icon: FluentIcons.arrow_reset_20_regular,
                label: i18n.t('common.reset'),
                disabled: controlsDisabled || !artworkDirty,
                onPressed: onResetArtwork,
              ),
              _DialogActionButton(
                icon: FluentIcons.delete_20_regular,
                label: i18n.t('playlists.delete'),
                disabled: controlsDisabled,
                onPressed: onRequestDelete,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _AlbumArtworkDialogColors.artworkSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _AlbumArtworkDialogColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child:
                    artworkFile != null && artworkFile.existsSync()
                        ? Image.file(artworkFile, fit: BoxFit.contain)
                        : Center(
                          child: Text(
                            i18n.t('song.noAlbumArt'),
                            style: const TextStyle(
                              color: _AlbumArtworkDialogColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
              ),
            ),
          ),
          if (showDeleteConfirm) ...[
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: _AlbumArtworkDialogColors.warningSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _AlbumArtworkDialogColors.warning),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        i18n.t('song.removeAlbumArt', {'title': title}),
                        style: const TextStyle(
                          color: _AlbumArtworkDialogColors.text,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: controlsDisabled ? null : onConfirmDelete,
                      child: Text(i18n.t('common.yes')),
                    ),
                    TextButton(
                      onPressed: controlsDisabled ? null : onCancelDelete,
                      child: Text(i18n.t('common.cancel')),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({
    required this.icon,
    required this.label,
    required this.disabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: disabled ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(label)],
      ),
    );
  }
}

class _AlbumArtworkDialogColors {
  static const text = Color(0xff273142);
  static const textMuted = Color(0xff617188);
  static const status = Color(0xff2f5f9f);
  static const border = Color(0xffd6e0ec);
  static const artworkSurface = Color(0xfff4f7fb);
  static const warning = Color(0xffffc36a);
  static const warningSurface = Color(0xfffff7e8);
}
