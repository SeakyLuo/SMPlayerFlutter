import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/undoable_notification.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';

import 'headered_playlist_model.dart';

List<int> notFavoriteSongIds(
  List<int> songIds,
  Map<int, LibrarySong> songsById,
) {
  return songIds.where((songId) => !songsById[songId]!.favorite).toList();
}

bool hasNotFavoriteSongs(List<int> songIds, Map<int, LibrarySong> songsById) {
  return songIds.any((songId) => !songsById[songId]!.favorite);
}

Future<void> addSongsToNowPlaying(WidgetRef ref, List<int> songIds) async {
  final snapshot = await _readLibraryContentData(ref);
  await ref.read(libraryRepositoryProvider).replaceNowPlaying([
    ...snapshot.nowPlaying.songIds,
    ...songIds,
  ]);
  ref.invalidate(libraryContentDataProvider);
  ref.invalidate(recentPageDataProvider);
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
  final songsById = {for (final song in snapshot.songs) song.id: song};
  final insertedIndex = snapshot.nowPlaying.songIds.length;
  await ref.read(libraryRepositoryProvider).replaceNowPlaying([
    ...snapshot.nowPlaying.songIds,
    ...songIds,
  ]);
  ref.invalidate(libraryContentDataProvider);
  ref.invalidate(recentPageDataProvider);
  if (!context.mounted) {
    return;
  }
  showUndoableSnackBar(
    context: context,
    i18n: i18n,
    message: songsAddedUndoMessage(
      i18n: i18n,
      songIds: songIds,
      songsById: songsById,
      target: i18n.t('common.nowPlaying'),
    ),
    onUndo: () async {
      final currentSnapshot =
          await ref.read(libraryRepositoryProvider).getLibraryContentData();
      final currentSongIds = currentSnapshot.nowPlaying.songIds;
      final nextSongIds =
          currentSongIds.toList()
            ..removeRange(insertedIndex, insertedIndex + songIds.length);
      await ref.read(libraryRepositoryProvider).replaceNowPlaying(nextSongIds);
      ref.invalidate(libraryContentDataProvider);
    },
  );
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
  await ref
      .read(libraryRepositoryProvider)
      .addSongsToPlaylist(playlistId, songIds);
  ref.invalidate(libraryContentDataProvider);
}

Future<void> addSongsToPlaylistWithUndo({
  required BuildContext context,
  required WidgetRef ref,
  required SmPlayerI18n i18n,
  required int playlistId,
  required List<int> songIds,
  bool useSingleSongCall = false,
}) async {
  if (songIds.isEmpty) {
    return;
  }
  final snapshot = ref.read(libraryContentDataProvider).value!;
  final songsById = {for (final song in snapshot.songs) song.id: song};
  final playlist = snapshot.playlists.firstWhere(
    (playlist) => playlist.id == playlistId,
  );
  if (useSingleSongCall && songIds.length == 1) {
    await ref
        .read(libraryRepositoryProvider)
        .addSongToPlaylist(playlistId, songIds.first);
    ref.invalidate(libraryContentDataProvider);
  } else {
    await addSongsToPlaylist(ref, playlistId, songIds);
  }
  if (!context.mounted) {
    return;
  }
  showUndoableSnackBar(
    context: context,
    i18n: i18n,
    message: songsAddedUndoMessage(
      i18n: i18n,
      songIds: songIds,
      songsById: songsById,
      target: playlist.name,
    ),
    onUndo: () async {
      await ref
          .read(libraryRepositoryProvider)
          .removeSongsFromPlaylist(playlistId, songIds);
      ref.invalidate(libraryContentDataProvider);
    },
  );
}

Future<void> setSongsFavorite(
  WidgetRef ref,
  List<int> songIds,
  bool favorite,
) async {
  await ref.read(libraryRepositoryProvider).setSongsFavorite(songIds, favorite);
  final mediaController = ref.read(mediaControlControllerProvider);
  if (songIds.contains(mediaController.state.track.id) &&
      mediaController.state.track.favorite != favorite) {
    mediaController.onToggleFavorite();
  }
  ref.invalidate(libraryContentDataProvider);
}

Future<void> setSongsFavoriteWithUndo({
  required BuildContext context,
  required WidgetRef ref,
  required SmPlayerI18n i18n,
  required List<int> songIds,
  required bool favorite,
}) async {
  if (songIds.isEmpty) {
    return;
  }
  final snapshot = ref.read(libraryContentDataProvider).value!;
  final songsById = {for (final song in snapshot.songs) song.id: song};
  await setSongsFavorite(ref, songIds, favorite);
  if (!context.mounted) {
    return;
  }
  showUndoableSnackBar(
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
      await setSongsFavorite(ref, songIds, !favorite);
    },
  );
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
  final name = await requestPlaylistName(
    context: context,
    i18n: i18n,
    playlists: playlists,
    defaultName: defaultName,
  );
  if (name == null) {
    return;
  }

  await ref.read(libraryRepositoryProvider).createPlaylist(name, songIds);
  ref.invalidate(libraryContentDataProvider);
}

Future<void> requestDeleteSongFromDisk({
  required BuildContext context,
  required WidgetRef ref,
  required SmPlayerI18n i18n,
  required LibrarySong song,
}) async {
  final confirmed = await showPopupConfirmDialog(
    context: context,
    title: i18n.t('playlists.delete'),
    message: i18n.t('context.deleteSongConfirm', {'title': song.title}),
    confirmLabel: i18n.t('playlists.delete'),
  );

  if (!confirmed) {
    return;
  }

  final pendingDelete = await ref
      .read(libraryRepositoryProvider)
      .beginDeleteSongFromDisk(song.id);
  ref.invalidate(libraryContentDataProvider);
  if (!context.mounted) {
    await ref
        .read(libraryRepositoryProvider)
        .commitDeleteSongFromDisk(pendingDelete.id);
    return;
  }

  final closedReason = await showUndoableSnackBar(
    context: context,
    i18n: i18n,
    message: i18n.t('notification.deletedFromDisk', {'title': song.title}),
    onUndo: () async {
      await ref
          .read(libraryRepositoryProvider)
          .undoDeleteSongFromDisk(pendingDelete.id);
      ref.invalidate(libraryContentDataProvider);
    },
  );
  if (closedReason != SnackBarClosedReason.action) {
    await ref
        .read(libraryRepositoryProvider)
        .commitDeleteSongFromDisk(pendingDelete.id);
  }
}

Future<void> hideSongFile(WidgetRef ref, int songId) async {
  await ref.read(libraryRepositoryProvider).hideSong(songId);
  ref.invalidate(libraryContentDataProvider);
}

Future<void> hideSongFileWithUndo({
  required BuildContext context,
  required WidgetRef ref,
  required SmPlayerI18n i18n,
  required LibrarySong song,
}) async {
  await ref.read(libraryRepositoryProvider).hideSong(song.id);
  ref.invalidate(libraryContentDataProvider);
  if (!context.mounted) {
    return;
  }
  showUndoableSnackBar(
    context: context,
    i18n: i18n,
    message: i18n.t('notification.hiddenStorageItem', {'name': song.title}),
    onUndo: () async {
      await ref.read(libraryRepositoryProvider).unhideSong(song.id);
      ref.invalidate(libraryContentDataProvider);
    },
  );
}

Future<void> moveSongToFolder(
  WidgetRef ref,
  int songId,
  String folderPath,
) async {
  await ref
      .read(libraryRepositoryProvider)
      .moveSongToFolder(songId, folderPath);
  ref.invalidate(libraryContentDataProvider);
}

Future<void> moveSongToFolderWithUndo({
  required BuildContext context,
  required WidgetRef ref,
  required SmPlayerI18n i18n,
  required LibrarySong song,
  required String folderPath,
}) async {
  final result = await ref
      .read(libraryRepositoryProvider)
      .moveSongToFolder(
        song.id,
        folderPath,
        resolveConflict:
            (sourcePath, targetPath) => requestLocalMoveConflictResolution(
              context: context,
              i18n: i18n,
              sourcePath: sourcePath,
              targetPath: targetPath,
            ),
      );
  ref.invalidate(libraryContentDataProvider);
  if (!context.mounted || result.itemCount == 0) {
    return;
  }
  showUndoableSnackBar(
    context: context,
    i18n: i18n,
    message: i18n.t('notification.movedSong', {'title': song.title}),
    onUndo: () async {
      await ref.read(libraryRepositoryProvider).undoMoveLocalItems(result);
      ref.invalidate(libraryContentDataProvider);
    },
  );
}

Future<LocalMoveConflictResolution> requestLocalMoveConflictResolution({
  required BuildContext context,
  required SmPlayerI18n i18n,
  required String sourcePath,
  required String targetPath,
}) async {
  final result = await showDialog<LocalMoveConflictResolution>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: false,
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
    confirmLabel: i18n.t('common.confirm'),
    placeholder: i18n.t('playlists.namePlaceholder'),
    validate: (name) => validatePlaylistName(name, playlists, '', i18n),
  );
}
