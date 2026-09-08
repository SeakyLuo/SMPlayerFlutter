part of 'local_page.dart';

extension _LocalPageSongLocation on _LocalPageState {
  void _revealLocatedSong(LocalSongLocation location) {
    if (!mounted ||
        _handledSongLocation != location ||
        widget.currentRelativePath != location.folderPath) {
      return;
    }
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final songs =
        _dataCache
            .snapshot(
              snapshot,
              ref.read(librarySongOverridesProvider),
              ref.read(libraryPlaylistOverridesProvider),
              ref.read(libraryDeletedPlaylistIdsProvider),
              ref.read(libraryPlaylistOrderProvider),
            )
            .songs;
    final song = songs.where((song) => song.id == location.songId).firstOrNull;
    final target = song == null ? null : GlobalObjectKey(song).currentContext;
    if (target == null) {
      showAppNotification(
        context: context,
        message: context.smPlayerI18n.t('local.cannotLocateSong'),
      );
      return;
    }
    Scrollable.ensureVisible(
      target,
      alignment: 0.35,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    ref.read(localSongLocationProvider.notifier).state = null;
    _songLocationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _updateLocalPageState(() => _locatedSongId = null);
      }
    });
  }
}
