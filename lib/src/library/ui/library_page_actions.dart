import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
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
  final snapshot = ref.read(musicLibrarySnapshotProvider).value!;
  await ref.read(libraryRepositoryProvider).replaceNowPlaying([
    ...snapshot.nowPlaying.songIds,
    ...songIds,
  ]);
  ref.invalidate(musicLibrarySnapshotProvider);
}

Future<void> addSongsToPlaylist(
  WidgetRef ref,
  int playlistId,
  List<int> songIds,
) async {
  await ref
      .read(libraryRepositoryProvider)
      .addSongsToPlaylist(playlistId, songIds);
  ref.invalidate(musicLibrarySnapshotProvider);
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
  ref.invalidate(musicLibrarySnapshotProvider);
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
  ref.invalidate(musicLibrarySnapshotProvider);
}

Future<void> requestDeleteSongFromDisk({
  required BuildContext context,
  required WidgetRef ref,
  required SmPlayerI18n i18n,
  required LibrarySong song,
}) async {
  final confirmed =
      await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: Text(i18n.t('playlists.delete')),
              content: Text(
                i18n.t('context.deleteSongConfirm', {'title': song.title}),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(i18n.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(i18n.t('playlists.delete')),
                ),
              ],
            ),
      ) ??
      false;

  if (!confirmed) {
    return;
  }

  await ref.read(libraryRepositoryProvider).deleteSongFromDisk(song.id);
  ref.invalidate(musicLibrarySnapshotProvider);
}

Future<void> hideSongFile(WidgetRef ref, int songId) async {
  await ref.read(libraryRepositoryProvider).hideSong(songId);
  ref.invalidate(musicLibrarySnapshotProvider);
}

Future<void> moveSongToFolder(
  WidgetRef ref,
  int songId,
  String folderPath,
) async {
  await ref
      .read(libraryRepositoryProvider)
      .moveSongToFolder(songId, folderPath);
  ref.invalidate(musicLibrarySnapshotProvider);
}

Future<String?> requestPlaylistName({
  required BuildContext context,
  required SmPlayerI18n i18n,
  required List<LibraryPlaylist> playlists,
  required String defaultName,
}) async {
  final controller = TextEditingController(text: defaultName);
  String? errorText;
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void submit() {
            final name = controller.text.trim();
            final validation = validatePlaylistName(name, playlists, '', i18n);
            if (validation.isNotEmpty) {
              setDialogState(() {
                errorText = validation;
              });
              return;
            }

            Navigator.of(dialogContext).pop(name);
          }

          return AlertDialog(
            title: Text(i18n.t('playlists.createNew')),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: i18n.t('playlists.namePlaceholder'),
                errorText: errorText,
              ),
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(i18n.t('common.cancel')),
              ),
              FilledButton(
                onPressed: submit,
                child: Text(i18n.t('playlists.create')),
              ),
            ],
          );
        },
      );
    },
  );
  controller.dispose();
  return result;
}
