import '../../remote/music_share_models.dart';
import '../../remote/music_share_access.dart';
import 'song_artwork.dart';
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
  });

  final String albumName;
  final String artworkUrl;
  final int songId;
  final VoidCallback onClose;

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

    if (currentSong != null && !canEditLibrarySong(currentSong)) {
      return PopupDialog(
        navLabel: i18n.t('song.albumArt'),
        navChildren: const [],
        onClose: widget.onClose,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
            child: SongArtwork(artworkPath: currentSong.thumbnailPath),
          ),
        ),
      );
    }
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
    final container = ProviderScope.containerOf(context, listen: false);

    setState(() {
      _saving = true;
    });
    try {
      final repository = ref.read(libraryRepositoryProvider);
      if (deleteArtwork) {
        await repository.deleteAlbumArtwork(
          widget.albumName,
          songId: widget.songId,
        );
      } else {
        await repository.saveAlbumArtwork(
          widget.albumName,
          _artworkSourcePath,
          songId: widget.songId,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _originalArtworkUrl = _currentArtworkUrl;
        _artworkSourcePath = '';
        _artworkDeletePending = false;
      });
      final sourceSong =
          (await repository.getLibrarySongs(songIds: [widget.songId])).single;
      invalidateLibraryQueries(
        container.invalidate,
        source: sourceSong.source.deviceId,
        kinds: const {
          LibraryQueryKind.album,
          LibraryQueryKind.albumIndex,
          LibraryQueryKind.artistIndex,
          LibraryQueryKind.folders,
          LibraryQueryKind.playlists,
          LibraryQueryKind.playlistIndex,
          LibraryQueryKind.artist,
        },
      );
      final visible =
          container
              .read(libraryLoadedDataProvider)
              .requireValue
              .songs
              .where(
                (song) =>
                    song.album == sourceSong.album &&
                    song.source == sourceSong.source,
              )
              .map((song) => song.id)
              .toList();
      final songs = await repository.getLibrarySongs(songIds: visible);
      final overrides = container.read(librarySongOverridesProvider.notifier);
      overrides.state = {
        ...overrides.state,
        for (final song in songs) song.id: song,
      };
      if (!mounted) return;
      showAppNotification(
        context: context,
        message: i18n.t(
          deleteArtwork ? 'song.albumArtDeleted' : 'song.albumArtSaved',
        ),
      );
    } catch (error) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: i18n.t(
            error is MusicShareException
                ? error.messageKey
                : 'song.updateFailed',
          ),
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
