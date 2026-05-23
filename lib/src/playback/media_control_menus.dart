part of 'media_control.dart';

List<MenuFlyoutItem> _buildPlaybackModeMenuItems({
  required SmPlayerI18n i18n,
  required PlaybackMode mode,
  required VoidCallback onToggleShuffle,
  required VoidCallback onToggleRepeat,
  required VoidCallback onToggleRepeatOne,
}) {
  return [
    MenuFlyoutItem(
      key: 'playback-mode-list',
      text: i18n.t('player.playbackModeList'),
      icon: _listPlaybackIcon,
      checked: mode == PlaybackMode.once,
      onPressed: () {
        _setPlaybackMode(
          currentMode: mode,
          targetMode: PlaybackMode.once,
          onToggleShuffle: onToggleShuffle,
          onToggleRepeat: onToggleRepeat,
          onToggleRepeatOne: onToggleRepeatOne,
        );
      },
    ),
    MenuFlyoutItem(
      key: 'playback-mode-shuffle',
      text: i18n.t('player.playbackModeShuffle'),
      icon: _shuffleIcon,
      checked: mode == PlaybackMode.shuffle,
      onPressed: () {
        _setPlaybackMode(
          currentMode: mode,
          targetMode: PlaybackMode.shuffle,
          onToggleShuffle: onToggleShuffle,
          onToggleRepeat: onToggleRepeat,
          onToggleRepeatOne: onToggleRepeatOne,
        );
      },
    ),
    MenuFlyoutItem(
      key: 'playback-mode-repeat',
      text: i18n.t('player.playbackModeRepeat'),
      icon: _repeatIcon,
      checked: mode == PlaybackMode.repeat,
      onPressed: () {
        _setPlaybackMode(
          currentMode: mode,
          targetMode: PlaybackMode.repeat,
          onToggleShuffle: onToggleShuffle,
          onToggleRepeat: onToggleRepeat,
          onToggleRepeatOne: onToggleRepeatOne,
        );
      },
    ),
    MenuFlyoutItem(
      key: 'playback-mode-repeat-one',
      text: i18n.t('player.playbackModeRepeatOne'),
      icon: _repeatOneIcon,
      checked: mode == PlaybackMode.repeatOne,
      onPressed: () {
        _setPlaybackMode(
          currentMode: mode,
          targetMode: PlaybackMode.repeatOne,
          onToggleShuffle: onToggleShuffle,
          onToggleRepeat: onToggleRepeat,
          onToggleRepeatOne: onToggleRepeatOne,
        );
      },
    ),
  ];
}

List<MenuFlyoutItem> _buildPlayerMoreMenuItems({
  required SmPlayerI18n i18n,
  required bool disabled,
  required int? trackId,
  required PlaybackMode mode,
  required bool isMuted,
  required int volumeValue,
  required VoidCallback onQuickPlay,
  required ValueChanged<int> onVolumeChange,
  required VoidCallback onToggleMute,
  required VoidCallback onToggleShuffle,
  required VoidCallback onToggleRepeat,
  required VoidCallback onToggleRepeatOne,
  required VoidCallback onToggleFavorite,
  required VoidCallback onOpenNowPlaying,
  required VoidCallback onToggleWindowFullScreen,
  required bool isWindowFullScreen,
  required VoidCallback onEnterMiniMode,
  bool isCompact = false,
  LibrarySong? currentSong,
  List<LibraryPlaylist> playlists = const [],
  String? preferenceLevel,
  VoidCallback? onAddToNowPlaying,
  VoidCallback? onCreatePlaylist,
  ValueChanged<int>? onAddToPlaylist,
  VoidCallback? onUndoPreference,
  ValueChanged<String>? onSetPreference,
  required VoidCallback onSeeArtist,
  required VoidCallback onSeeAlbum,
  required VoidCallback onSeeMusicInfo,
  required VoidCallback onSeeLyrics,
  required VoidCallback onSeeAlbumArt,
  required FutureOr<void> Function() onSeeLocal,
}) {
  final items = [
    MenuFlyoutItem(
      key: 'quick-play',
      text: i18n.t('nowPlaying.quickPlay'),
      icon: _playIcon,
      onPressed: onQuickPlay,
    ),
    if (isCompact) ...[
      MenuFlyoutItem(
        key: 'playback-mode',
        text:
            '${i18n.t('player.playbackMode')}: ${_playbackModeName(i18n, mode)}',
        icon: _playbackModeIcon(mode),
        submenu: _buildPlaybackModeMenuItems(
          i18n: i18n,
          mode: mode,
          onToggleShuffle: onToggleShuffle,
          onToggleRepeat: onToggleRepeat,
          onToggleRepeatOne: onToggleRepeatOne,
        ),
      ),
      MenuFlyoutItem(
        key: 'player-volume',
        text: i18n.t('player.volume'),
        icon: playerVolumeIcon(volumeValue, isMuted),
        contentHeight: 42,
        content: PlayerVolumeMenuItem(
          label: i18n.t('player.volume'),
          muted: isMuted,
          volumeValue: volumeValue,
          disabled: false,
          onToggleMute: onToggleMute,
          onVolumeChange: onVolumeChange,
        ),
      ),
      MenuFlyoutItem(
        key: 'player-favorite',
        text:
            currentSong?.favorite == true
                ? i18n.t('player.unlike')
                : i18n.t('player.like'),
        icon:
            currentSong?.favorite == true
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
        iconColor:
            currentSong?.favorite == true ? const Color(0xffd13438) : null,
        disabled: currentSong == null,
        onPressed: onToggleFavorite,
      ),
    ],
  ];

  if (currentSong == null) {
    return items;
  }

  final customPlaylists =
      playlists
          .where((playlist) => !playlist.isBuiltIn)
          .map(
            (playlist) => MultiSelectCommandBarPlaylist(
              id: playlist.id,
              name: playlist.name,
              songIds: playlist.songIds,
            ),
          )
          .toList();
  final addToItem = buildAddToPlaylistMenuFlyoutItem(
    i18n: i18n,
    songIds: [currentSong.id],
    playlists: customPlaylists,
    includeFavorites: !isCompact && !currentSong.favorite,
    onToggleFavorite: currentSong.favorite ? null : onToggleFavorite,
    onCreatePlaylist: onCreatePlaylist,
    onAddToPlaylist: onAddToPlaylist,
  );
  if (addToItem != null) {
    items.add(addToItem);
  }

  if (onSetPreference != null) {
    items.add(
      buildPreferenceMenuFlyoutItem(
        i18n: i18n,
        key: 'preference',
        preferenceLevel: preferenceLevel,
        onUndoPreference: onUndoPreference,
        onSetPreference: onSetPreference,
      ),
    );
  }

  items.addAll([
    MenuFlyoutItem(
      key: 'view',
      text: i18n.t('context.view'),
      icon: Icons.visibility_outlined,
      submenu: [
        MenuFlyoutItem(
          key: 'see-artist',
          text: i18n.t('context.seeArtist'),
          icon: Icons.groups_rounded,
          onPressed: onSeeArtist,
        ),
        MenuFlyoutItem(
          key: 'see-album',
          text: i18n.t('context.seeAlbum'),
          icon: Icons.album_rounded,
          onPressed: onSeeAlbum,
        ),
        MenuFlyoutItem(
          key: 'see-music-info',
          text: i18n.t('context.seeMusicInfo'),
          icon: Icons.info_outline_rounded,
          keepOpen: true,
          onPressed: onSeeMusicInfo,
        ),
        MenuFlyoutItem(
          key: 'see-lyrics',
          text: i18n.t('context.seeLyrics'),
          icon: Icons.lyrics_rounded,
          keepOpen: true,
          onPressed: onSeeLyrics,
        ),
        MenuFlyoutItem(
          key: 'see-album-art',
          text: i18n.t('context.seeAlbumArt'),
          icon: Icons.image_rounded,
          keepOpen: true,
          onPressed: onSeeAlbumArt,
        ),
        MenuFlyoutItem(
          key: 'see-local-file',
          text: i18n.t('context.seeLocalFile'),
          icon: Icons.folder_open_rounded,
          pendingText: i18n.t('context.openingLocal'),
          onPressed: onSeeLocal,
        ),
      ],
    ),
    MenuFlyoutItem(
      key: isWindowFullScreen ? 'exit-full-screen' : 'full-screen',
      text:
          isWindowFullScreen
              ? i18n.t('nowPlaying.exitFullScreenItem')
              : i18n.t('nowPlaying.fullScreen'),
      icon:
          isWindowFullScreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
      onPressed: onToggleWindowFullScreen,
    ),
    MenuFlyoutItem(
      key: 'mini-mode',
      text: i18n.t('player.miniMode'),
      icon: Icons.picture_in_picture_alt_rounded,
      onPressed: onEnterMiniMode,
    ),
  ]);

  return items;
}

void _setPlaybackMode({
  required PlaybackMode currentMode,
  required PlaybackMode targetMode,
  required VoidCallback onToggleShuffle,
  required VoidCallback onToggleRepeat,
  required VoidCallback onToggleRepeatOne,
}) {
  if (currentMode == targetMode) {
    return;
  }

  switch (targetMode) {
    case PlaybackMode.shuffle:
      onToggleShuffle();
    case PlaybackMode.repeat:
      onToggleRepeat();
    case PlaybackMode.repeatOne:
      onToggleRepeatOne();
    case PlaybackMode.once:
      switch (currentMode) {
        case PlaybackMode.shuffle:
          onToggleShuffle();
        case PlaybackMode.repeat:
          onToggleRepeat();
        case PlaybackMode.repeatOne:
          onToggleRepeatOne();
        case PlaybackMode.once:
          return;
      }
  }
}

String _playbackModeName(SmPlayerI18n i18n, PlaybackMode mode) {
  return switch (mode) {
    PlaybackMode.once => i18n.t('player.playbackModeList'),
    PlaybackMode.shuffle => i18n.t('player.playbackModeShuffle'),
    PlaybackMode.repeat => i18n.t('player.playbackModeRepeat'),
    PlaybackMode.repeatOne => i18n.t('player.playbackModeRepeatOne'),
  };
}

SmPlayerI18n _mediaControlI18n(BuildContext context) {
  return context.maybeSmPlayerI18n ??
      const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
}
