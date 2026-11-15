import '../data/library_source.dart';
import 'package:smplayer_flutter/src/remote/music_share_models.dart';
import 'package:smplayer_flutter/src/remote/music_share_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/playback_queue_actions.dart';

import 'headered_playlist_model.dart';
import 'library_storage_actions.dart';
import '../../remote/music_source_selector.dart';

List<int> notFavoriteSongIds(
  List<int> songIds,
  Map<int, LibrarySong> songsById,
) {
  return songIds
      .where((songId) => songsById[songId]?.favorite != true)
      .toList();
}

bool hasNotFavoriteSongs(List<int> songIds, Map<int, LibrarySong> songsById) {
  return songIds.any((songId) => songsById[songId]?.favorite != true);
}

void showPlayNextUndoNotification({
  required BuildContext context,
  required SmPlayerI18n i18n,
  required String songTitle,
  required VoidCallback onUndo,
}) {
  showUndoableNotification(
    context: context,
    i18n: i18n,
    message: i18n.t('notification.playNext', {'title': songTitle}),
    onUndo: onUndo,
  );
}

Future<void> addSongsToNowPlaying(WidgetRef ref, List<int> songIds) async {
  final snapshot = await _readLibraryContentData(ref);
  final nextSongIds = [...currentNowPlayingSongIds(ref, snapshot), ...songIds];
  await setNowPlayingQueue(ref, nextSongIds);
}

Future<void> addSongsToNowPlayingWithUndo({
  required BuildContext context,
  required WidgetRef ref,
  required SmPlayerI18n i18n,
  required List<int> songIds,
}) async {
  if (songIds.isEmpty) {
    return;
  }
  final snapshot = await _readLibraryContentData(ref);
  final songsById = await _notificationSongMap(ref, snapshot, songIds);
  final currentSongIds = currentNowPlayingSongIds(ref, snapshot);
  final insertedIndex = currentSongIds.length;
  final queueAfterAdd = [...currentSongIds, ...songIds];
  await setNowPlayingQueue(ref, queueAfterAdd);
  if (!context.mounted) {
    return;
  }
  showUndoableNotification(
    context: context,
    i18n: i18n,
    message: songsAddedUndoMessage(
      i18n: i18n,
      songIds: songIds,
      songsById: songsById,
      target: i18n.t('common.nowPlaying'),
    ),
    onUndo: () async {
      try {
        final currentSongIds = effectiveNowPlayingSongIds(ref, queueAfterAdd);
        final restoredSongIds =
            currentSongIds.toList()
              ..removeRange(insertedIndex, insertedIndex + songIds.length);
        await setNowPlayingQueue(ref, restoredSongIds);
      } catch (error) {
        if (context.mounted) {
          showAppNotification(
            context: context,
            message: context.smPlayerI18n.t(
              error is MusicShareException
                  ? error.messageKey
                  : 'song.updateFailed',
            ),
          );
        }
      }
    },
  );
}

Future<Map<int, LibrarySong>> _notificationSongMap(
  WidgetRef ref,
  LibraryContentData snapshot,
  List<int> songIds,
) async {
  if (songIds.length != 1) return const {};
  final songs = await ref
      .read(libraryRepositoryProvider)
      .getLibrarySongs(songIds: songIds);
  return {for (final song in songs) song.id: song};
}

Future<LibraryContentData> _readLibraryContentData(WidgetRef ref) async {
  return ref.read(libraryContentDataProvider).valueOrNull ??
      await ref.read(libraryContentDataProvider.future);
}

Future<void> addSongsToPlaylist(
  WidgetRef ref,
  int playlistId,
  List<int> songIds,
) async {
  final snapshot = await _readLibraryContentData(ref);
  if (playlistId == snapshot.favoritePlaylistId) {
    await setSongsFavorite(ref, songIds, true);
    return;
  }
  final playlist = _playlistForMutation(ref, snapshot, playlistId);
  await ref
      .read(libraryRepositoryProvider)
      .addSongsToPlaylist(playlistId, songIds);
  _patchPlaylistSongsAdded(ref, playlist, songIds);
}

Future<void> addSongsToPlaylistWithUndo({
  required BuildContext context,
  required WidgetRef ref,
  required SmPlayerI18n i18n,
  required int playlistId,
  required List<int> songIds,
  bool useSingleSongCall = false,
}) async {
  try {
    if (songIds.isEmpty) {
      return;
    }
    final snapshot = await _readLibraryContentData(ref);
    final songsById = await _notificationSongMap(ref, snapshot, songIds);
    final playlist = _playlistForMutation(ref, snapshot, playlistId);
    if (useSingleSongCall && songIds.length == 1) {
      if (playlistId == snapshot.favoritePlaylistId) {
        await setSongsFavorite(ref, songIds, true);
      } else {
        await ref
            .read(libraryRepositoryProvider)
            .addSongToPlaylist(playlistId, songIds.first);
        _patchPlaylistSongsAdded(ref, playlist, songIds);
      }
    } else {
      await addSongsToPlaylist(ref, playlistId, songIds);
    }
    if (!context.mounted) {
      return;
    }
    showUndoableNotification(
      context: context,
      i18n: i18n,
      message: songsAddedUndoMessage(
        i18n: i18n,
        songIds: songIds,
        songsById: songsById,
        target: playlist.name,
      ),
      onUndo: () async {
        try {
          if (playlistId == snapshot.favoritePlaylistId) {
            await setSongsFavorite(ref, songIds, false);
          } else {
            await ref
                .read(libraryRepositoryProvider)
                .removeSongsFromPlaylist(playlistId, songIds);
            final currentSnapshot = await _readLibraryContentData(ref);
            final currentPlaylist = _playlistForMutation(
              ref,
              currentSnapshot,
              playlistId,
            );
            _patchPlaylistSongsRemoved(ref, currentPlaylist, songIds);
          }
        } catch (error) {
          if (context.mounted) {
            showAppNotification(
              context: context,
              message: context.smPlayerI18n.t(
                error is MusicShareException
                    ? error.messageKey
                    : 'song.updateFailed',
              ),
            );
          }
        }
      },
    );
  } catch (error) {
    if (context.mounted) {
      showAppNotification(
        context: context,
        message: context.smPlayerI18n.t(
          error is MusicShareException ? error.messageKey : 'song.updateFailed',
        ),
      );
    }
  }
}

LibraryPlaylist _playlistForMutation(
  WidgetRef ref,
  LibraryContentData snapshot,
  int playlistId,
) {
  final playlists =
      playlistId < 0
          ? activeMusicShareAccess!.remotePlaylists
          : snapshot.playlists;
  return ref.read(libraryPlaylistOverridesProvider)[playlistId] ??
      playlists.firstWhere((playlist) => playlist.id == playlistId);
}

void _patchPlaylistSongsAdded(
  WidgetRef ref,
  LibraryPlaylist playlist,
  List<int> songIds,
) {
  final existingSongIds = playlist.songIds.toSet();
  final nextSongIds = [
    ...playlist.songIds,
    for (final songId in songIds)
      if (existingSongIds.add(songId)) songId,
  ];
  _patchPlaylistMutation(
    ref,
    playlist.copyWith(songCount: nextSongIds.length, songIds: nextSongIds),
  );
}

void _patchPlaylistSongsRemoved(
  WidgetRef ref,
  LibraryPlaylist playlist,
  List<int> songIds,
) {
  final removedSongIds = songIds.toSet();
  final nextSongIds =
      playlist.songIds
          .where((songId) => !removedSongIds.contains(songId))
          .toList();
  _patchPlaylistMutation(
    ref,
    playlist.copyWith(songCount: nextSongIds.length, songIds: nextSongIds),
  );
}

void _patchPlaylistMutation(WidgetRef ref, LibraryPlaylist playlist) {
  patchLibraryPlaylistOverride(ref, playlist);
}

Future<List<int>> setSongsFavorite(
  WidgetRef ref,
  List<int> songIds,
  bool favorite,
) async {
  final snapshot = await _readLibraryContentData(ref);
  final changed = await ref
      .read(libraryRepositoryProvider)
      .setSongsFavorite(songIds, favorite);
  final changedIds = songIds.toSet();
  final overrides = ref.read(librarySongOverridesProvider);
  patchLibrarySongOverrides(
    ref,
    snapshot.songs
        .where((song) => changedIds.contains(song.id))
        .map(
          (song) => (overrides[song.id] ?? song).copyWith(favorite: favorite),
        ),
  );
  patchLibraryFavoriteOverrides(ref, songIds, favorite);
  if (changed.isNotEmpty) {
    final paths = await ref
        .read(libraryRepositoryProvider)
        .songReferences(changed);
    final sources =
        paths.values
            .map((path) => LibrarySource.fromPath(path).deviceId)
            .toSet();
    for (final source in sources)
      ref.invalidate(
        libraryQueryInvalidationProvider((LibraryQueryKind.favorites, source)),
      );
  }
  final mediaController = ref.read(mediaControlControllerProvider);
  if (songIds.contains(mediaController.state.track.id) &&
      mediaController.state.track.favorite != favorite) {
    mediaController.onToggleFavorite();
  }
  return changed;
}

Future<void> setSongsFavoriteFromControl(
  WidgetRef ref,
  List<int> songIds,
  bool favorite,
) => runMusicShareAction(
  ref.context,
  () => setSongsFavorite(ref, songIds, favorite),
);

void invalidateLibraryMutationData(WidgetRef ref) {
  ref.invalidate(recentPageDataProvider);
  ref.invalidate(shellNavigationDataProvider);
}

Future<void> setSongsFavoriteWithUndo({
  required BuildContext context,
  required WidgetRef ref,
  required SmPlayerI18n i18n,
  required List<int> songIds,
  required bool favorite,
}) async {
  await runMusicShareAction(context, () async {
    if (songIds.isEmpty) {
      return;
    }
    final snapshot = await _readLibraryContentData(ref);
    songIds = await setSongsFavorite(ref, songIds, favorite);
    if (songIds.isEmpty) {
      if (context.mounted)
        showAppNotification(
          context: context,
          message: i18n.t('notification.operationDone'),
        );
      return;
    }
    final songsById = await _notificationSongMap(ref, snapshot, songIds);
    if (!context.mounted) {
      return;
    }
    showUndoableNotification(
      context: context,
      i18n: i18n,
      message:
          favorite
              ? songsAddedUndoMessage(
                i18n: i18n,
                songIds: songIds,
                songsById: songsById,
                target: i18n.t('common.myFavorites'),
              )
              : songsRemovedUndoMessage(
                i18n: i18n,
                songIds: songIds,
                songsById: songsById,
                target: i18n.t('common.myFavorites'),
              ),
      onUndo: () async {
        try {
          await setSongsFavorite(ref, songIds, !favorite);
        } catch (error) {
          if (context.mounted) {
            showAppNotification(
              context: context,
              message: context.smPlayerI18n.t(
                error is MusicShareException
                    ? error.messageKey
                    : 'song.updateFailed',
              ),
            );
          }
        }
      },
    );
  });
}

String songsAddedUndoMessage({
  required SmPlayerI18n i18n,
  required List<int> songIds,
  required Map<int, LibrarySong> songsById,
  required String target,
}) {
  return songIds.length == 1
      ? i18n.t('notification.songAddedTo', {
        'title': songsById[songIds.first]!.title,
        'target': target,
      })
      : i18n.t('notification.songsAddedTo', {
        'count': songIds.length,
        'target': target,
      });
}

String songsRemovedUndoMessage({
  required SmPlayerI18n i18n,
  required List<int> songIds,
  required Map<int, LibrarySong> songsById,
  required String target,
}) {
  return songIds.length == 1
      ? i18n.t('notification.removedFrom', {
        'title': songsById[songIds.first]!.title,
        'target': target,
      })
      : i18n.t('notification.songsRemovedFrom', {
        'count': songIds.length,
        'target': target,
      });
}

Future<void> createPlaylistWithSongs({
  required BuildContext context,
  required WidgetRef ref,
  required SmPlayerI18n i18n,
  required List<LibraryPlaylist> playlists,
  required String defaultName,
  required List<int> songIds,
}) async {
  try {
    if (!canCreateSourcePlaylist()) {
      throw const MusicShareException('share.readOnlyPermission');
    }
    final name = await requestPlaylistName(
      context: context,
      i18n: i18n,
      playlists: playlists,
      defaultName: defaultName,
    );
    if (name == null || !context.mounted) {
      return;
    }

    await createPlaylistAndSync(
      context: context,
      ref: ref,
      i18n: i18n,
      name: name,
      songIds: songIds,
    );
  } catch (error) {
    if (context.mounted) {
      showAppNotification(
        context: context,
        message: context.smPlayerI18n.t(
          error is MusicShareException ? error.messageKey : 'song.updateFailed',
        ),
      );
    }
  }
}

Future<LibraryPlaylist> createPlaylistAndSync({
  required BuildContext context,
  required WidgetRef ref,
  required SmPlayerI18n i18n,
  required String name,
  required List<int> songIds,
}) async {
  final playlist = await ref
      .read(libraryRepositoryProvider)
      .createPlaylist(
        name,
        songIds,
        LibrarySource.fromDevice(activeMusicShareAccess!.selectedSource),
      );
  _patchPlaylistMutation(ref, playlist);
  if (context.mounted) {
    showPlaylistCreatedNotification(
      context: context,
      i18n: i18n,
      playlist: playlist,
    );
  }
  return playlist;
}

void showPlaylistCreatedNotification({
  required BuildContext context,
  required SmPlayerI18n i18n,
  required LibraryPlaylist playlist,
}) {
  final router = GoRouter.of(context);
  showAppNotification(
    context: context,
    message: i18n.t('notification.playlistCreated', {'name': playlist.name}),
    duration: undoableNotificationDuration,
    actionLabel: i18n.t('context.view'),
    onAction: () {
      router.go('/playlists/${playlist.id}');
    },
  );
}

Future<void> requestDeleteSongFromDisk({
  required BuildContext context,
  required WidgetRef ref,
  required SmPlayerI18n i18n,
  required LibrarySong song,
}) async {
  final storage = LibraryStorageActions(ref);
  late final LibraryStorageChange change;
  final confirmed = await showPopupConfirmDialog(
    context: context,
    title: i18n.t('playlists.delete'),
    message: i18n.t('context.deleteSongConfirm', {'title': song.title}),
    confirmLabel: i18n.t('playlists.delete'),
    onConfirm: () async {
      change = await storage.delete(song);
    },
  );
  if (!confirmed) return;
  if (!context.mounted) {
    await change.commit();
    return;
  }
  await _finishLibraryStorageChange(
    context,
    i18n,
    change,
    i18n.t('notification.deletedFromDisk', {'title': song.title}),
  );
}

Future<void> hideSongFileWithUndo({
  required BuildContext context,
  required WidgetRef ref,
  required SmPlayerI18n i18n,
  required LibrarySong song,
}) => runLibraryStorageAction(context, () async {
  final change = await LibraryStorageActions(ref).hide(song);
  if (!context.mounted) {
    await change.commit();
    return;
  }
  await _finishLibraryStorageChange(
    context,
    i18n,
    change,
    i18n.t('notification.hiddenStorageItem', {'name': song.title}),
  );
});

Future<void> moveSongToFolder(
  WidgetRef ref,
  int songId,
  String folderPath,
) async {
  final context = ref.context;
  final storage = LibraryStorageActions(ref);
  final song =
      (await ref
          .read(libraryRepositoryProvider)
          .getLibrarySongs(songIds: [songId])).single;
  if (!context.mounted) return;
  final change = await storage.move(context, song, folderPath);
  await change.commit();
}

Future<void> moveSongToFolderWithUndo({
  required BuildContext context,
  required WidgetRef ref,
  required SmPlayerI18n i18n,
  required LibrarySong song,
  required String folderPath,
}) => runLibraryStorageAction(context, () async {
  final change = await LibraryStorageActions(
    ref,
  ).move(context, song, folderPath);
  if (!context.mounted) {
    await change.commit();
    return;
  }
  await _finishLibraryStorageChange(
    context,
    i18n,
    change,
    i18n.t('notification.movedSong', {'title': song.title}),
  );
});

Future<void> _finishLibraryStorageChange(
  BuildContext context,
  SmPlayerI18n i18n,
  LibraryStorageChange change,
  String message,
) async {
  if (!context.mounted || change.count == 0) {
    await change.commit();
    return;
  }
  final reason = await showUndoableNotification(
    context: context,
    i18n: i18n,
    message: message,
    onUndo: () => runLibraryStorageAction(context, change.undo),
  );
  if (reason != AppNotificationClosedReason.action) {
    if (context.mounted) {
      await runLibraryStorageAction(context, change.commit);
    } else {
      await change.commit();
    }
  }
}

Future<void> runLibraryStorageAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) {
      showAppNotification(
        context: context,
        message: context.smPlayerI18n.t(
          error is MusicShareException ? error.messageKey : 'song.updateFailed',
        ),
      );
    }
  }
}

Future<LocalMoveConflictResolution> requestLocalMoveConflictResolution({
  required BuildContext context,
  required SmPlayerI18n i18n,
  required String sourcePath,
  required String targetPath,
}) async {
  final result = await showScopedPopupDialog<LocalMoveConflictResolution>(
    context: context,
    builder: (dialogContext) {
      final colors = PopupDialogColors.resolve(dialogContext);
      return PopupDialog(
        navLabel: i18n.t('local.moveConflictTitle'),
        ariaLabel: i18n.t('local.moveConflictTitle'),
        width: 520,
        height: 270,
        onClose: () {
          Navigator.of(dialogContext).pop(LocalMoveConflictResolution.skip);
        },
        navChildren: [
          Expanded(child: PopupDialogTitle(i18n.t('local.moveConflictTitle'))),
        ],
        footer: PopupDialogActions(
          children: [
            PopupDialogActionButton(
              label: i18n.t('local.moveConflictReplace'),
              primary: true,
              destructive: true,
              onPressed:
                  () => Navigator.of(
                    dialogContext,
                  ).pop(LocalMoveConflictResolution.replace),
            ),
            PopupDialogActionButton(
              label: i18n.t('local.moveConflictKeepBoth'),
              onPressed:
                  () => Navigator.of(
                    dialogContext,
                  ).pop(LocalMoveConflictResolution.keepBoth),
            ),
            PopupDialogActionButton(
              label: i18n.t('local.moveConflictSkip'),
              onPressed:
                  () => Navigator.of(
                    dialogContext,
                  ).pop(LocalMoveConflictResolution.skip),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: Center(
            child: Text(
              '${i18n.t('local.moveConflictMessage', {'name': _localMoveFileName(targetPath)})}\n\n$sourcePath',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.text, fontSize: 15, height: 1.55),
            ),
          ),
        ),
      );
    },
  );
  return result ?? LocalMoveConflictResolution.skip;
}

String _localMoveFileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index < 0 ? normalized : normalized.substring(index + 1);
}

Future<String?> requestPlaylistName({
  required BuildContext context,
  required SmPlayerI18n i18n,
  required List<LibraryPlaylist> playlists,
  required String defaultName,
}) async {
  return showPopupTextDialog(
    context: context,
    title: i18n.t('playlists.createNew'),
    initialValue: defaultName,
    confirmLabel: i18n.t('playlists.create'),
    placeholder: i18n.t('playlists.namePlaceholder'),
    validate: (name) => validatePlaylistName(name, playlists, '', i18n),
  );
}

List<int> mergeVisiblePlaylistOrder(
  List<int> complete,
  List<int> visibleOrder,
) {
  final visibleIds = visibleOrder.toSet();
  final iterator = visibleOrder.iterator;
  return [
    for (final id in complete)
      if (visibleIds.contains(id)) (iterator..moveNext()).current else id,
  ];
}
