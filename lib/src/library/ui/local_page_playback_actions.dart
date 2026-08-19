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
        useShuffleIcon: true,
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

    _playTrack(songIds.first, songIds, queueIndex: 0);
  }

  void _playTrack(int trackId, List<int> queueSongIds, {int? queueIndex}) {
    final snapshot = ref.read(libraryContentDataProvider).value!;
    replaceNowPlayingQueueAndPlayIndex(
      ref: ref,
      snapshot: snapshot,
      i18n: context.smPlayerI18n,
      songIds: queueSongIds,
      queueIndex: queueIndex ?? queueSongIds.indexOf(trackId),
    );
    _updateLocalPageState(() {
      _selectedSongIds
        ..clear()
        ..add(trackId);
      if (!_multiSelect) {
        _selectedFolderPaths.clear();
      }
    });
  }

  void _playSongImmediately(int songId) {
    insertOrPlayNowPlayingSong(
      ref: ref,
      snapshot: ref.read(libraryContentDataProvider).value!,
      i18n: context.smPlayerI18n,
      songId: songId,
    );
  }

  void _playNext(int songId) {
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final previousSongIds = currentNowPlayingSongIds(ref, snapshot);
    final queueSongIds = previousSongIds.toList();
    final insertIndex = insertIndexAfterCurrentOccurrence(
      ref.read(mediaControlControllerProvider).state,
      queueSongIds,
    );
    queueSongIds.insert(insertIndex, songId);
    setNowPlayingQueue(ref, queueSongIds);
    final songsById = {for (final song in snapshot.songs) song.id: song};
    showPlayNextUndoNotification(
      context: context,
      i18n: context.smPlayerI18n,
      songTitle: songsById[songId]!.title,
      onUndo: () {
        setNowPlayingQueue(ref, previousSongIds);
      },
    );
  }

  void _jumpToSongKey(
    String key,
    Map<String, int> songQuickJumpMap,
    List<LibrarySong> currentSongs,
  ) {
    final index = songQuickJumpMap[key];
    if (index == null) {
      return;
    }

    final song = currentSongs[index];
    final targetContext = GlobalObjectKey(song).currentContext!;
    final targetBox = targetContext.findRenderObject()! as RenderBox;
    final firstSongContext =
        GlobalObjectKey(currentSongs.first).currentContext!;
    final firstSongBox = firstSongContext.findRenderObject()! as RenderBox;
    final contentTop =
        firstSongBox.localToGlobal(Offset.zero).dy + _scrollController.offset;
    final targetScrollOffset = (_scrollController.offset +
            targetBox.localToGlobal(Offset.zero).dy -
            contentTop)
        .clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        );
    _scrollController.animateTo(
      targetScrollOffset,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _showMessage(String message) {
    showAppNotification(context: context, message: message);
  }
}
