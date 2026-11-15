import '../library/data/library_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/undoable_notification.dart';
import '../i18n/app_i18n.dart';
import '../library/data/library_models.dart';
import '../library/data/library_providers.dart';
import '../library/ui/artists_page_model.dart';
import '../remote/music_share_models.dart';

Future<void> playSourceGroup({
  required BuildContext context,
  required WidgetRef ref,
  required LibrarySong song,
  required bool artist,
  required ValueChanged<List<int>> onPlaySongs,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final names = getSongArtists(song);
  final artists = names.isEmpty ? [song.artist] : names;
  try {
    final adapter = container
        .read(libraryRepositoryProvider)
        .dataSource(song.source);
    final songs = await adapter.selectSongIds(
      LibrarySelectionRequest(
        artist
            ? LibrarySelectionKind.currentArtist
            : LibrarySelectionKind.currentAlbum,
        album: song.album,
        artists: artists,
      ),
    );
    final ids = songs;
    if (context.mounted && ids.isNotEmpty) onPlaySongs(ids);
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

Future<List<int>> sourceShuffleSongIds(WidgetRef ref, List<int> songIds) async {
  if (songIds.isEmpty) return const [];
  final context = ref.context;
  final container = ProviderScope.containerOf(context, listen: false);
  try {
    final repository = container.read(libraryRepositoryProvider);
    final paths = await repository.songReferences(songIds);
    final sources = paths.values.map(LibrarySource.fromPath).toSet();
    final adapter = repository.dataSource(
      sources.length == 1 ? sources.single : const LocalLibrarySource(),
    );
    final selected = await adapter.selectSongIds(
      LibrarySelectionRequest(LibrarySelectionKind.selection, songIds: songIds),
    );
    return selected;
  } catch (error) {
    if (context.mounted) {
      showAppNotification(
        context: context,
        message: context.smPlayerI18n.t(
          error is MusicShareException
              ? error.messageKey
              : 'share.connectionFailed',
        ),
      );
    }
    return const [];
  }
}
