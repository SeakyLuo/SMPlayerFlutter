part of 'recent_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _RecentPageMenus on _RecentPageState {
  Future<void> _showSongContextMenu(
    Offset position,
    LibrarySong song,
    List<int> queueSongIds,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) async {
    final i18n = context.smPlayerI18n;
    final mediaState = ref.read(mediaControlControllerProvider).state;
    final currentTrackId = mediaState.track.id;
    final snapshot = ref.read(recentPageDataProvider).value!;
    final preferenceLevel = await ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('song', '${song.id}');
    if (!mounted) {
      return;
    }
    final canRemove =
        _activeTab == RecentTab.played &&
        _activePlayedFilter == RecentPlayedFilter.songs;
    showMenuFlyout(
      context,
      position: position,
      items: buildMusicMenuFlyoutItems(
        i18n: i18n,
        songId: song.id,
        isFavorite: song.favorite,
        isCurrentTrack: song.id == currentTrackId,
        isPlaying: mediaState.isPlaying,
        currentTrackId: currentTrackId,
        nowPlayingSongIds: snapshot.nowPlaying.songIds,
        songPath: song.path,
        playlists: playlists,
        preferenceLevel: preferenceLevel,
        onUndoPreference:
            preferenceLevel == null
                ? null
                : () async {
                  await ref
                      .read(libraryRepositoryProvider)
                      .removePreferenceItem('song', '${song.id}');
                  ref.invalidate(recentPageDataProvider);
                },
        showRemove: canRemove,
        onPlay: () {
          _playSong(song, queueSongIds, queueSongIds.indexOf(song.id));
        },
        onTogglePlayPause:
            ref.read(mediaControlControllerProvider).onTogglePlayPause,
        onPlayNext: () {
          _playNext(song.id);
        },
        onAddToNowPlaying: () {
          addSongsToNowPlayingWithUndo(
            context: context,
            ref: ref,
            i18n: i18n,
            songIds: [song.id],
          );
        },
        onCreatePlaylist: () async {
          await createPlaylistWithSongs(
            context: context,
            ref: ref,
            i18n: i18n,
            playlists: snapshot.playlists,
            defaultName: getNextPlaylistName(song.title, snapshot.playlists),
            songIds: [song.id],
          );
        },
        onAddToPlaylist: (playlistId) {
          addSongsToPlaylistWithUndo(
            context: context,
            ref: ref,
            i18n: i18n,
            playlistId: playlistId,
            songIds: [song.id],
          );
        },
        onRemove: () {
          _removeRecentPlayedWithUndo([song.id]);
        },
        onSelect: () {
          setState(() {
            _multiSelect = true;
            _selectedSongIds.add(song.id);
          });
        },
        onToggleFavorite: () {
          unawaited(
            setSongsFavoriteWithUndo(
              context: context,
              ref: ref,
              i18n: i18n,
              songIds: [song.id],
              favorite: !song.favorite,
            ),
          );
        },
        onSetPreference: (level) async {
          await ref
              .read(libraryRepositoryProvider)
              .addPreferenceItem('song', '${song.id}', song.title, level);
          ref.invalidate(recentPageDataProvider);
        },
        onMoveToFolder: (folderPath) {
          moveSongToFolderWithUndo(
            context: context,
            ref: ref,
            i18n: i18n,
            song: song,
            folderPath: folderPath,
          );
        },
        onDelete: () {
          requestDeleteSongFromDisk(
            context: context,
            ref: ref,
            i18n: i18n,
            song: song,
          );
        },
        onSeeArtist: () {
          context.go(
            '/artists?artist=${Uri.encodeQueryComponent(displayArtists(song, i18n))}',
          );
        },
        onSeeAlbum: () {
          context.go(
            '/albums?album=${Uri.encodeQueryComponent(_displayAlbum(song, i18n))}',
          );
        },
        onSeeMusicInfo: () {
          _openMusicDialog(song, SongDialogMode.properties, queueSongIds);
        },
        onSeeLyrics: () {
          _openMusicDialog(song, SongDialogMode.lyrics, queueSongIds);
        },
        onSeeAlbumArt: () {
          _openMusicDialog(song, SongDialogMode.albumArt, queueSongIds);
        },
        onSeeLocal: () {
          unawaited(revealItemInFolder(song.path));
        },
      ),
    );
  }

  void _openMusicDialog(
    LibrarySong song,
    SongDialogMode mode,
    List<int> queueSongIds,
  ) {
    setState(() {
      _musicDialog = (song: song, mode: mode, queueSongIds: queueSongIds);
    });
  }

  void _showCollectionAddToMenu(
    Offset position,
    String title,
    List<int> songIds,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) {
    final i18n = context.smPlayerI18n;
    final songsById = {
      for (final song in ref.read(recentPageDataProvider).value!.songs)
        song.id: song,
    };
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: songIds,
      playlists: playlists,
      includeNowPlaying: shouldShowNowPlayingAddToTarget(
        songIds: songIds,
        nowPlayingSongIds:
            ref.read(recentPageDataProvider).value!.nowPlaying.songIds,
        isNowPlayingContext: false,
      ),
      includeFavorites: hasNotFavoriteSongs(songIds, songsById),
      onAddToNowPlaying: () {
        addSongsToNowPlayingWithUndo(
          context: context,
          ref: ref,
          i18n: i18n,
          songIds: songIds,
        );
      },
      onToggleFavorite: () {
        setSongsFavoriteWithUndo(
          context: context,
          ref: ref,
          i18n: i18n,
          songIds: notFavoriteSongIds(songIds, songsById),
          favorite: true,
        );
      },
      onCreatePlaylist: () async {
        final snapshot = ref.read(recentPageDataProvider).value!;
        await createPlaylistWithSongs(
          context: context,
          ref: ref,
          i18n: i18n,
          playlists: snapshot.playlists,
          defaultName: getNextPlaylistName(title, snapshot.playlists),
          songIds: songIds,
        );
      },
      onAddToPlaylist: (playlistId) {
        addSongsToPlaylistWithUndo(
          context: context,
          ref: ref,
          i18n: i18n,
          playlistId: playlistId,
          songIds: songIds,
        );
      },
    );
    if (addToItem == null) {
      return;
    }

    showMenuFlyout(context, position: position, items: addToItem.submenu);
  }

  Future<void> _showArtistContextMenu(
    Offset position,
    RecentArtistView artist,
    List<MultiSelectCommandBarPlaylist> playlists,
  ) async {
    final i18n = context.smPlayerI18n;
    final snapshot = ref.read(recentPageDataProvider).value!;
    final songIds = artist.songs.map((song) => song.id).toList();
    final favoriteSongIds =
        artist.songs
            .where((song) => !song.favorite)
            .map((song) => song.id)
            .toList();
    final preferenceLevel = await ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('artist', artist.name);
    if (!mounted) {
      return;
    }
    final addToItem = buildAddToPlaylistMenuFlyoutItem(
      i18n: i18n,
      songIds: songIds,
      playlists: playlists,
      includeNowPlaying: shouldShowNowPlayingAddToTarget(
        songIds: songIds,
        nowPlayingSongIds: snapshot.nowPlaying.songIds,
        isNowPlayingContext: false,
      ),
      includeFavorites: favoriteSongIds.isNotEmpty,
      onAddToNowPlaying: () {
        addSongsToNowPlayingWithUndo(
          context: context,
          ref: ref,
          i18n: i18n,
          songIds: songIds,
        );
      },
      onToggleFavorite:
          favoriteSongIds.isEmpty
              ? null
              : () {
                setSongsFavoriteWithUndo(
                  context: context,
                  ref: ref,
                  i18n: i18n,
                  songIds: favoriteSongIds,
                  favorite: true,
                );
              },
      onCreatePlaylist: () async {
        await createPlaylistWithSongs(
          context: context,
          ref: ref,
          i18n: i18n,
          playlists: snapshot.playlists,
          defaultName: getNextPlaylistName(artist.name, snapshot.playlists),
          songIds: songIds,
        );
      },
      onAddToPlaylist: (playlistId) {
        addSongsToPlaylistWithUndo(
          context: context,
          ref: ref,
          i18n: i18n,
          playlistId: playlistId,
          songIds: songIds,
        );
      },
    );

    showMenuFlyout(
      context,
      position: position,
      items: [
        MenuFlyoutItem(
          key: 'shuffle',
          text: i18n.t('nowPlaying.randomPlay'),
          useShuffleIcon: true,
          onPressed: () {
            _recordRecentCollectionPlayed(
              (repository) => repository.recordArtistPlayed(artist.name),
            );
            _playShuffledSongIds(songIds);
          },
        ),
        if (addToItem != null) addToItem,
        MenuFlyoutItem(
          key: 'multi-select',
          text: i18n.t('common.multiSelect'),
          icon: FluentIcons.multiselect_ltr_20_regular,
          onPressed: () {
            setState(() {
              _multiSelect = true;
              _selectedCollectionKeys.add('artists:${artist.name}');
            });
          },
        ),
        buildPreferenceMenuFlyoutItem(
          i18n: i18n,
          key: 'preference',
          preferenceLevel: preferenceLevel,
          onUndoPreference:
              preferenceLevel == null
                  ? null
                  : () async {
                    await ref
                        .read(libraryRepositoryProvider)
                        .removePreferenceItem('artist', artist.name);
                    ref.invalidate(recentPageDataProvider);
                  },
          onSetPreference: (level) async {
            await ref
                .read(libraryRepositoryProvider)
                .addPreferenceItem('artist', artist.name, artist.name, level);
            ref.invalidate(recentPageDataProvider);
          },
        ),
      ],
    );
  }

  Future<void> _removeRecentSearchesWithUndo(List<int> entryIds) async {
    final entryIdSet = entryIds.toSet();
    final entries =
        ref
            .read(recentPageDataProvider)
            .value!
            .recentSearches
            .where((entry) => entryIdSet.contains(entry.id))
            .toList();
    await ref.read(libraryRepositoryProvider).removeRecentSearches(entryIds);
    invalidateRecentSearchData(ref);
    if (!mounted) {
      return;
    }
    showUndoableNotification(
      context: context,
      i18n: context.smPlayerI18n,
      message: context.smPlayerI18n.t('notification.operationDone'),
      onUndo: () async {
        await ref
            .read(libraryRepositoryProvider)
            .restoreRecentSearches(entries);
        invalidateRecentSearchData(ref);
      },
    );
  }

  Future<void> _removeRecentPlayedWithUndo(List<int> songIds) async {
    await ref.read(libraryRepositoryProvider).removeRecentPlayed(songIds);
    ref.invalidate(recentPageDataProvider);
    if (!mounted) {
      return;
    }
    showUndoableNotification(
      context: context,
      i18n: context.smPlayerI18n,
      message: context.smPlayerI18n.t('notification.operationDone'),
      onUndo: () async {
        await ref.read(libraryRepositoryProvider).restoreRecentPlayed(songIds);
        ref.invalidate(recentPageDataProvider);
      },
    );
  }
}
