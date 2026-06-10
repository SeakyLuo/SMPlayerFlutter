part of 'headered_playlist_control.dart';

extension _HeaderedPlaylistControlSongMenu on _HeaderedPlaylistControlState {
  Future<void> _showSongMenu(
    BuildContext context,
    SmPlayerI18n i18n,
    Offset position,
    LibrarySong song,
    int index,
    List<int> queueSongIds,
  ) async {
    final snapshot = ref.read(libraryContentDataProvider).value!;
    final preferenceLevel = await ref
        .read(libraryRepositoryProvider)
        .getPreferenceLevel('song', '${song.id}');
    if (!context.mounted) {
      return;
    }
    final folders = _menuFolders(snapshot.folders);
    final playlists = _effectivePlaylists(snapshot.playlists);
    final currentSavedPlaylist =
        widget.type == HeaderedPlaylistType.playlist
            ? playlists.firstWhere((playlist) => playlist.name == widget.title)
            : null;
    final currentPlaylistName =
        widget.type == HeaderedPlaylistType.favorites
            ? i18n.t('common.myFavorites')
            : widget.type == HeaderedPlaylistType.playlist
            ? currentSavedPlaylist!.name
            : widget.title;
    showMenuFlyout(
      context,
      position: position,
      items: buildMusicMenuFlyoutItems(
        i18n: i18n,
        songId: song.id,
        isFavorite: song.favorite,
        isCurrentTrack: widget.selectedTrackId == song.id,
        isPlaying: widget.isPlaying,
        currentTrackId: widget.selectedTrackId,
        songPath: song.path,
        playlists:
            playlists
                .where((playlist) => !playlist.isBuiltIn)
                .map(
                  (playlist) => MultiSelectCommandBarPlaylist(
                    id: playlist.id,
                    name: playlist.name,
                    songIds: playlist.songIds,
                  ),
                )
                .toList(),
        currentPlaylistName: currentPlaylistName,
        excludePlaylistName: currentSavedPlaylist?.name,
        showRemove: widget.removable,
        removeLabel:
            widget.type == HeaderedPlaylistType.favorites
                ? i18n.t('context.removeFavorite')
                : null,
        onPlay: () {
          _playSong(
            song,
            _currentVisibleSongs().map((item) => item.id).toList(),
          );
        },
        onPause: () {
          widget.onTogglePlayPause?.call();
        },
        onPlayNext: () {
          _playNextSong(song.id);
        },
        onAddToNowPlaying: () {
          _addSongsToNowPlaying([song.id]);
        },
        onCreatePlaylist: () {
          unawaited(
            _createPlaylistFromSongs(i18n, [
              song.id,
            ], defaultSourceName: song.title),
          );
        },
        onAddToPlaylist: (playlistId) {
          unawaited(
            addSongsToPlaylistWithUndo(
              context: context,
              ref: ref,
              i18n: i18n,
              playlistId: playlistId,
              songIds: [song.id],
            ),
          );
        },
        onRemove: () {
          unawaited(_removeSongsFromCurrentPlaylist([song.id]));
        },
        onSelect: () {
          _updateState(() {
            _selection.enterMultiSelect();
            _selection.selectSingle(song.id);
          });
        },
        onToggleFavorite: () {
          _toggleSongFavoriteWithUndo(song);
        },
        onSetPreference: (level) async {
          await ref
              .read(libraryRepositoryProvider)
              .addPreferenceItem('song', '${song.id}', song.title, level);
        },
        preferenceLevel: preferenceLevel,
        onUndoPreference:
            preferenceLevel == null
                ? null
                : () async {
                  await ref
                      .read(libraryRepositoryProvider)
                      .removePreferenceItem('song', '${song.id}');
                },
        onDelete: () {
          unawaited(
            requestDeleteSongFromDisk(
              context: context,
              ref: ref,
              i18n: i18n,
              song: song,
            ),
          );
        },
        folders: folders,
        showMoveToFolder: folders.isNotEmpty,
        onMoveToFolder: (folderPath) {
          unawaited(
            moveSongToFolderWithUndo(
              context: context,
              ref: ref,
              i18n: i18n,
              song: song,
              folderPath: folderPath,
            ),
          );
        },
        showHideFile: true,
        onHide: () {
          unawaited(
            hideSongFileWithUndo(
              context: context,
              ref: ref,
              i18n: i18n,
              song: song,
            ),
          );
        },
        onSeeArtist: () {
          widget.onArtistClick?.call(_displayArtist(song, i18n));
        },
        onSeeAlbum: () {
          widget.onAlbumClick?.call(song_display.displayAlbum(song, i18n));
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
          unawaited(_revealPath(song.path));
        },
      ),
    );
  }

  List<MenuFlyoutFolder> _menuFolders(List<LibraryFolder> folders) {
    return folders
        .map(
          (folder) => MenuFlyoutFolder(
            id: folder.id,
            name: _displayPathName(folder.path),
            path: folder.path,
            parentId: folder.parentId,
          ),
        )
        .toList();
  }

  String _displayPathName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index < 0 ? normalized : normalized.substring(index + 1);
  }
}
