part of 'albums_page.dart';

extension _AlbumsPagePlaybackActions on _AlbumsPageState {
  Future<void> _playSongIds(List<int> songIds, {bool shuffle = false}) async {
    if (songIds.isEmpty) {
      return;
    }

    final queueSongIds =
        shuffle ? await sourceShuffleSongIds(ref, songIds) : songIds.toList();
    if (!mounted || queueSongIds.isEmpty) return;
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final i18n = context.smPlayerI18n;
    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: snapshot,
      i18n: i18n,
      songIds: queueSongIds,
      queueIndex: 0,
    );
  }

  Future<void> _addSongsToNowPlayingWithUndo(List<int> songIds) async {
    await addSongsToNowPlayingWithUndo(
      context: context,
      ref: ref,
      i18n: context.smPlayerI18n,
      songIds: songIds,
    );
  }

  Future<void> _addSongsToPlaylistWithUndo(
    int playlistId,
    List<int> songIds,
  ) async {
    await addSongsToPlaylistWithUndo(
      context: context,
      ref: ref,
      i18n: context.smPlayerI18n,
      playlistId: playlistId,
      songIds: songIds,
    );
  }

  Future<void> _setSongsFavoriteWithUndo(List<int> songIds, bool favorite) =>
      setSongsFavoriteWithUndo(
        context: context,
        ref: ref,
        i18n: context.smPlayerI18n,
        songIds: songIds,
        favorite: favorite,
      );
}
