part of 'local_page.dart';

extension _LocalPagePlaybackActions on _LocalPageState {
  void _playShuffled(FolderNode folder) {
    _playShuffledSongIds(folder.subtreeSongIds);
  }

  void _playShuffledFromToolbar(
    BuildContext buttonContext,
    FolderNode currentNode,
    List<int> queueSongIds,
    bool hasSubfolderSongs,
    SmPlayerI18n i18n,
  ) {
    if (queueSongIds.isNotEmpty && hasSubfolderSongs) {
      showMenuFlyout(
        buttonContext,
        items: _localShuffleMenuItems(currentNode, queueSongIds, i18n),
      );
      return;
    }

    _playShuffledSongIds(
      queueSongIds.isNotEmpty ? queueSongIds : currentNode.subtreeSongIds,
    );
  }

  List<MenuFlyoutItem> _localShuffleMenuItems(
    FolderNode currentNode,
    List<int> queueSongIds,
    SmPlayerI18n i18n,
  ) {
    return [
      MenuFlyoutItem(
        key: 'toolbar-shuffle-current',
        text: i18n.t('local.scopeCurrent'),
        icon: FluentIcons.arrow_shuffle_20_regular,
        onPressed: () => _playShuffledSongIds(queueSongIds),
      ),
      MenuFlyoutItem(
        key: 'toolbar-shuffle-subtree',
        text: i18n.t('local.scopeSubtree'),
        icon: FluentIcons.folder_20_regular,
        onPressed: () => _playShuffledSongIds(currentNode.subtreeSongIds),
      ),
    ];
  }

  void _playShuffledSongIds(List<int> sourceSongIds) {
    final songIds = shuffleSongIds(sourceSongIds);
    if (songIds.isEmpty) {
      final i18n = ref.read(smPlayerI18nProvider).valueOrNull!;
      _showMessage(i18n.t('local.noMusicUnderCurrentFolder'));
      return;
    }

    _playTrack(songIds.first, songIds);
  }

  void _playTrack(int trackId, List<int> queueSongIds) {
    final snapshot = ref.read(libraryViewDataProvider).value!;
    final songsById = {for (final song in snapshot.songs) song.id: song};
    final song = songsById[trackId]!;
    ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
    ref
        .read(mediaControlControllerProvider)
        .playTrack(
          mediaControlTrackForSong(song, context.smPlayerI18n),
          durationSeconds: song.duration.toDouble(),
          queueIndex: max(0, queueSongIds.indexOf(trackId)),
        );
    ref.invalidate(libraryViewDataProvider);
    _updateLocalPageState(() {
      _selectedSongIds
        ..clear()
        ..add(trackId);
      if (!_multiSelect) {
        _selectedFolderPaths.clear();
      }
    });
  }

  void _playNext(int songId) {
    final snapshot = ref.read(libraryViewDataProvider).value!;
    final queueSongIds = snapshot.nowPlaying.songIds.toList();
    final selectedQueueIndex =
        ref.read(mediaControlControllerProvider).state.selectedQueueIndex;
    final insertIndex =
        selectedQueueIndex != null && selectedQueueIndex < queueSongIds.length
            ? selectedQueueIndex + 1
            : queueSongIds.length;
    queueSongIds.insert(insertIndex, songId);
    ref.read(libraryRepositoryProvider).replaceNowPlaying(queueSongIds);
    ref.invalidate(libraryViewDataProvider);
  }

  void _jumpToSongKey(
    String key,
    Map<String, int> songQuickJumpMap, {
    required double rowExtent,
  }) {
    final index = songQuickJumpMap[key];
    if (index == null) {
      return;
    }

    _scrollController.animateTo(
      index * rowExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _showMessage(String message) {
    showAppNotification(context: context, message: message);
  }
}
