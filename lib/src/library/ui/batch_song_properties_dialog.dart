import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/smplayer_switch.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_artist_tag_normalizer.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/media_control_track_factory.dart';

Future<bool> showBatchSongPropertiesDialog({
  required BuildContext context,
  required WidgetRef ref,
  required List<int> songIds,
}) async {
  final i18n = context.smPlayerI18n;
  final container = ProviderScope.containerOf(context, listen: false);
  final result = await showDialog<_BatchSongPropertiesCommit>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: false,
    builder: (_) => _BatchSongPropertiesDialog(songIds: songIds),
  );
  if (result == null) {
    return false;
  }
  await Future<void>.delayed(popupConfirmDialogDismissDelay);
  if (!context.mounted) {
    return true;
  }
  final failedCount = result.failedSongIds.length;
  if (result.updatedSongIds.isEmpty) {
    showAppNotification(
      context: context,
      message: i18n.t('song.batchEditFailed'),
    );
    return true;
  }
  final message =
      failedCount == 0
          ? i18n.t('song.batchEditUpdated', {
            'count': result.updatedSongIds.length,
          })
          : i18n.t('song.batchEditUpdatedWithFailures', {
            'count': result.updatedSongIds.length,
            'failed': failedCount,
          });
  unawaited(
    showUndoableAppNotification(
      i18n: i18n,
      message: message,
      onUndo: () async {
        final updates = {
          for (final songId in result.updatedSongIds)
            songId: _updateFromSnapshot(result.beforeProperties[songId]!),
        };
        final undoResult = await container
            .read(libraryRepositoryProvider)
            .updateSongPropertiesBatch(updates);
        final restoredSongs = {
          for (final songId in undoResult.updatedSongIds)
            songId: result.beforeSongs[songId]!,
        };
        _applySongOverrides(container, restoredSongs, i18n);
        _invalidateSongMetadata(container);
      },
    ),
  );
  return true;
}

class _BatchSongPropertiesDialog extends ConsumerStatefulWidget {
  const _BatchSongPropertiesDialog({required this.songIds});

  final List<int> songIds;

  @override
  ConsumerState<_BatchSongPropertiesDialog> createState() =>
      _BatchSongPropertiesDialogState();
}

class _BatchSongPropertiesDialogState
    extends ConsumerState<_BatchSongPropertiesDialog> {
  final _artistControllers = <TextEditingController>[];
  final _albumController = TextEditingController();
  final _albumArtistController = TextEditingController();
  final _yearController = TextEditingController();
  final _publisherController = TextEditingController();

  List<SongPropertiesSnapshot>? _properties;
  var _loading = true;
  var _saving = false;
  var _artistEnabled = false;
  var _albumEnabled = false;
  var _albumArtistEnabled = false;
  var _yearEnabled = false;
  var _publisherEnabled = false;
  var _artistMixed = false;
  var _albumMixed = false;
  var _albumArtistMixed = false;
  var _yearMixed = false;
  var _publisherMixed = false;
  var _updatingArtistControllers = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final controller in _artistControllers) {
      controller.dispose();
    }
    _albumController.dispose();
    _albumArtistController.dispose();
    _yearController.dispose();
    _publisherController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final properties = await ref
          .read(libraryRepositoryProvider)
          .getSongPropertiesBatch(widget.songIds);
      final artists = _commonValue(
        properties.map((item) => item.artists.join('\u0000')).toList(),
      );
      final album = _commonValue(properties.map((item) => item.album).toList());
      final albumArtist = _commonValue(
        properties.map((item) => item.albumArtist).toList(),
      );
      final year = _commonValue(properties.map((item) => item.year).toList());
      final publisher = _commonValue(
        properties.map((item) => item.publisher).toList(),
      );
      _artistMixed = artists.mixed;
      _albumMixed = album.mixed;
      _albumArtistMixed = albumArtist.mixed;
      _yearMixed = year.mixed;
      _publisherMixed = publisher.mixed;
      _replaceArtistControllers(
        artists.mixed ? const [''] : artists.value.split('\u0000'),
      );
      _albumController.text = album.mixed ? '' : album.value;
      _albumArtistController.text = albumArtist.mixed ? '' : albumArtist.value;
      _yearController.text =
          year.mixed || year.value == 0 ? '' : year.value.toString();
      _publisherController.text = publisher.mixed ? '' : publisher.value;
      _artistEnabled = !artists.mixed;
      _albumEnabled = !album.mixed;
      _albumArtistEnabled = !albumArtist.mixed;
      _yearEnabled = !year.mixed;
      _publisherEnabled = !publisher.mixed;
      if (mounted) {
        setState(() {
          _properties = properties;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop();
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t('song.batchEditLoadFailed'),
        );
      }
    }
  }

  void _replaceArtistControllers(List<String> artists) {
    _updatingArtistControllers = true;
    for (final controller in _artistControllers) {
      controller.dispose();
    }
    _artistControllers
      ..clear()
      ..addAll(
        (artists.isEmpty ? const [''] : artists).map((artist) {
          final controller = TextEditingController(text: artist);
          controller.addListener(_handleArtistChanged);
          return controller;
        }),
      );
    _updatingArtistControllers = false;
  }

  void _handleArtistChanged() {
    if (_updatingArtistControllers) {
      return;
    }
    setState(() {});
  }

  void _addArtist() {
    setState(() {
      final controller = TextEditingController();
      controller.addListener(_handleArtistChanged);
      _artistControllers.add(controller);
    });
  }

  void _removeArtist(int index) {
    setState(() {
      _artistControllers.removeAt(index).dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    final title = i18n.t('song.batchEditTitle', {
      'count': widget.songIds.length,
    });
    return PopupDialog(
      overlayClassName: 'batch-song-properties-overlay',
      className: 'batch-song-properties-dialog ContentDialog',
      navClassName: 'batch-song-properties-nav',
      navLabel: title,
      ariaLabel: title,
      width: 640,
      height: 720,
      verticalInset: 32,
      onClose: _saving ? () {} : () => Navigator.of(context).pop(),
      navChildren: [Expanded(child: PopupDialogTitle(title))],
      footer: PopupDialogActions(
        children: [
          PopupDialogActionButton(
            label:
                _saving
                    ? i18n.t('song.batchEditing')
                    : i18n.t('song.batchEditConfirm'),
            primary: true,
            loading: _saving,
            onPressed: _canSubmit ? _submit : null,
          ),
          PopupDialogActionButton(
            label: i18n.t('common.cancel'),
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
      child:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  mobile ? 12 : 28,
                  mobile ? 4 : 8,
                  mobile ? 12 : 28,
                  18,
                ),
                child: _buildFields(i18n),
              ),
    );
  }

  Widget _buildFields(SmPlayerI18n i18n) {
    final colors = PopupDialogColors.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          i18n.t('song.batchEditHint'),
          style: TextStyle(color: colors.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 18),
        _BatchPropertySection(
          label: i18n.t('common.artist'),
          enabled: _artistEnabled,
          mixed: _artistMixed,
          onEnabledChanged:
              (value) => setState(() {
                _artistEnabled = value;
              }),
          child: IgnorePointer(
            ignoring: !_artistEnabled || _saving,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: _artistEnabled ? 1 : 0.58,
              child: MusicDialogArtistFieldGrid(
                controllers: _artistControllers,
                saving: _saving,
                showActions: _artistEnabled,
                onAddArtistCell: _addArtist,
                onRemoveArtistCell: _removeArtist,
              ),
            ),
          ),
        ),
        _BatchPropertySection(
          label: i18n.t('common.album'),
          enabled: _albumEnabled,
          mixed: _albumMixed,
          onEnabledChanged:
              (value) => setState(() {
                _albumEnabled = value;
              }),
          child: PopupDialogTextField(
            controller: _albumController,
            enabled: _albumEnabled,
            placeholder:
                _albumMixed ? i18n.t('song.batchEditDifferentValues') : null,
            onChanged: (_) => setState(() {}),
          ),
        ),
        _BatchPropertySection(
          label: i18n.t('song.albumArtist'),
          enabled: _albumArtistEnabled,
          mixed: _albumArtistMixed,
          onEnabledChanged:
              (value) => setState(() {
                _albumArtistEnabled = value;
              }),
          child: PopupDialogTextField(
            controller: _albumArtistController,
            enabled: _albumArtistEnabled,
            placeholder:
                _albumArtistMixed
                    ? i18n.t('song.batchEditDifferentValues')
                    : null,
            onChanged: (_) => setState(() {}),
          ),
        ),
        _BatchPropertySection(
          label: i18n.t('song.year'),
          enabled: _yearEnabled,
          mixed: _yearMixed,
          onEnabledChanged:
              (value) => setState(() {
                _yearEnabled = value;
              }),
          child: PopupDialogTextField(
            controller: _yearController,
            enabled: _yearEnabled,
            placeholder:
                _yearMixed ? i18n.t('song.batchEditDifferentValues') : null,
            errorText: !_validYear ? i18n.t('song.batchEditInvalidYear') : '',
            onChanged: (_) => setState(() {}),
          ),
        ),
        _BatchPropertySection(
          label: i18n.t('song.publisher'),
          enabled: _publisherEnabled,
          mixed: _publisherMixed,
          onEnabledChanged:
              (value) => setState(() {
                _publisherEnabled = value;
              }),
          child: PopupDialogTextField(
            controller: _publisherController,
            enabled: _publisherEnabled,
            placeholder:
                _publisherMixed
                    ? i18n.t('song.batchEditDifferentValues')
                    : null,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  bool get _validYear {
    final text = _yearController.text.trim();
    if (!_yearEnabled || text.isEmpty) {
      return true;
    }
    final year = int.tryParse(text);
    return year != null && year > 0 && year <= 9999;
  }

  List<String> get _editedArtists =>
      normalizeArtists(
        _artistControllers.map((controller) => controller.text).toList(),
      ).take(6).toList();

  int get _editedYear {
    final text = _yearController.text.trim();
    return text.isEmpty ? 0 : int.parse(text);
  }

  bool get _canSubmit {
    if (_loading || _saving || !_validYear) {
      return false;
    }
    final artists = _editedArtists;
    final album = _albumController.text.trim();
    final albumArtist = _albumArtistController.text.trim();
    final year = _editedYear;
    final publisher = _publisherController.text.trim();
    return _properties!.any(
      (item) =>
          (_artistEnabled && !listEquals(item.artists, artists)) ||
          (_albumEnabled && item.album != album) ||
          (_albumArtistEnabled && item.albumArtist != albumArtist) ||
          (_yearEnabled && item.year != year) ||
          (_publisherEnabled && item.publisher != publisher),
    );
  }

  Future<void> _submit() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final i18n = context.smPlayerI18n;
    setState(() {
      _saving = true;
    });
    final properties = _properties!;
    final artists = _editedArtists;
    final year = _editedYear;
    final nextBySongId = {
      for (final item in properties)
        item.songId: item.copyWith(
          artist: _artistEnabled ? artists.join(', ') : item.artist,
          artists: _artistEnabled ? artists : item.artists,
          album: _albumEnabled ? _albumController.text.trim() : item.album,
          albumArtist:
              _albumArtistEnabled
                  ? _albumArtistController.text.trim()
                  : item.albumArtist,
          publisher:
              _publisherEnabled
                  ? _publisherController.text.trim()
                  : item.publisher,
          year: _yearEnabled ? year : item.year,
        ),
    };
    final changedBySongId = {
      for (final item in properties)
        if (_batchEditablePropertiesChanged(item, nextBySongId[item.songId]!))
          item.songId: nextBySongId[item.songId]!,
    };
    if (changedBySongId.isEmpty) {
      Navigator.of(context).pop();
      showAppNotification(
        context: context,
        message: context.smPlayerI18n.t('song.batchEditNoChanges'),
      );
      return;
    }
    try {
      final result = await ref
          .read(libraryRepositoryProvider)
          .updateSongPropertiesBatch({
            for (final entry in changedBySongId.entries)
              entry.key: _updateFromSnapshot(entry.value),
          });
      final library = ref.read(libraryContentDataProvider).value!;
      final songsById = {for (final song in library.songs) song.id: song};
      final beforeSongs = {
        for (final songId in result.updatedSongIds) songId: songsById[songId]!,
      };
      final afterSongs = {
        for (final songId in result.updatedSongIds)
          songId: songsById[songId]!.copyWith(
            artist: nextBySongId[songId]!.artist,
            artists: nextBySongId[songId]!.artists,
            album: nextBySongId[songId]!.album,
          ),
      };
      _applySongOverrides(container, afterSongs, i18n);
      _invalidateSongMetadata(container);
      if (mounted) {
        Navigator.of(context).pop(
          _BatchSongPropertiesCommit(
            updatedSongIds: result.updatedSongIds,
            failedSongIds: result.failedSongIds,
            beforeProperties: {
              for (final item in properties) item.songId: item,
            },
            beforeSongs: beforeSongs,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
        });
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t('song.batchEditFailed'),
        );
      }
    }
  }
}

class _BatchPropertySection extends StatelessWidget {
  const _BatchPropertySection({
    required this.label,
    required this.enabled,
    required this.mixed,
    required this.onEnabledChanged,
    required this.child,
  });

  final String label;
  final bool enabled;
  final bool mixed;
  final ValueChanged<bool> onEnabledChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (mixed) ...[
                      const SizedBox(height: 2),
                      Text(
                        i18n.t('song.batchEditDifferentValues'),
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                enabled
                    ? i18n.t('song.batchEditModify')
                    : i18n.t('song.batchEditKeep'),
                style: TextStyle(
                  color: enabled ? colors.accentStrong : colors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              SmPlayerSwitch(
                value: enabled,
                onChanged: onEnabledChanged,
                trackKey: ValueKey('batch-$label-switch-track'),
                thumbKey: ValueKey('batch-$label-switch-thumb'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _CommonValue<T> {
  const _CommonValue({required this.value, required this.mixed});

  final T value;
  final bool mixed;
}

_CommonValue<T> _commonValue<T>(List<T> values) {
  final value = values.first;
  return _CommonValue(
    value: value,
    mixed: values.skip(1).any((candidate) => candidate != value),
  );
}

class _BatchSongPropertiesCommit {
  const _BatchSongPropertiesCommit({
    required this.updatedSongIds,
    required this.failedSongIds,
    required this.beforeProperties,
    required this.beforeSongs,
  });

  final List<int> updatedSongIds;
  final List<int> failedSongIds;
  final Map<int, SongPropertiesSnapshot> beforeProperties;
  final Map<int, LibrarySong> beforeSongs;
}

SongPropertiesUpdate _updateFromSnapshot(SongPropertiesSnapshot properties) {
  return SongPropertiesUpdate(
    title: properties.title,
    subtitle: properties.subtitle,
    artist: properties.artist,
    artists: properties.artists,
    album: properties.album,
    albumArtist: properties.albumArtist,
    publisher: properties.publisher,
    trackNumber: properties.trackNumber,
    year: properties.year,
    genre: properties.genre,
    composers: properties.composers,
    playCount: properties.playCount,
  );
}

bool _batchEditablePropertiesChanged(
  SongPropertiesSnapshot before,
  SongPropertiesSnapshot after,
) {
  return before.artists.join('\u0000') != after.artists.join('\u0000') ||
      before.album != after.album ||
      before.albumArtist != after.albumArtist ||
      before.year != after.year ||
      before.publisher != after.publisher;
}

void _applySongOverrides(
  ProviderContainer container,
  Map<int, LibrarySong> songs,
  SmPlayerI18n i18n,
) {
  final notifier = container.read(librarySongOverridesProvider.notifier);
  notifier.state = {...notifier.state, ...songs};
  final mediaController = container.read(mediaControlControllerProvider);
  final currentSong = songs[mediaController.state.track.id];
  if (currentSong != null) {
    mediaController.updateTrackMetadata(
      mediaControlTrackForSong(currentSong, i18n),
    );
  }
}

void _invalidateSongMetadata(ProviderContainer container) {
  container.invalidate(libraryContentDataProvider);
  container.invalidate(recentPageDataProvider);
  container.invalidate(shellNavigationDataProvider);
}
