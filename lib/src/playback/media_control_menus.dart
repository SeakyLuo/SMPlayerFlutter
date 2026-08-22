part of 'media_control.dart';

List<MenuFlyoutItem> buildPlaybackModeMenuFlyoutItems({
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
      usePlaylistIcon: true,
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
      useShuffleIcon: true,
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

Future<void> showMediaControlMoreMenu({
  required BuildContext context,
  required SmPlayerI18n i18n,
  required bool isMuted,
  required int volumeValue,
  bool desktopLyricsEnabled = false,
  VoidCallback? onToggleDesktopLyrics,
  required VoidCallback onQuickPlay,
  bool alwaysShowQuickPlay = false,
  List<MenuFlyoutItem>? randomPlaySubmenu,
  bool randomPlayDisabled = false,
  required ValueChanged<int> onVolumeChange,
  required VoidCallback onToggleMute,
  required VoidCallback onToggleFavorite,
  VoidCallback? onToggleWindowFullScreen,
  required bool isWindowFullScreen,
  VoidCallback? onEnterMiniMode,
  bool isCompact = false,
  LibrarySong? currentSong,
  List<int> nowPlayingSongIds = const [],
  List<LibraryPlaylist> playlists = const [],
  String? preferenceLevel,
  FutureOr<String?> Function()? onResolvePreferenceLevel,
  VoidCallback? onAddToNowPlaying,
  ValueChanged<String>? onCreatePlaylist,
  ValueChanged<int>? onAddToPlaylist,
  VoidCallback? onUndoPreference,
  ValueChanged<String>? onSetPreference,
  VoidCallback? onPlayArtist,
  VoidCallback? onPlayAlbum,
  bool showFavoriteWhenUnavailable = false,
  VoidCallback? onSeeArtist,
  VoidCallback? onSeeAlbum,
  VoidCallback? onSeeMusicInfo,
  VoidCallback? onSeeLyrics,
  VoidCallback? onSeeAlbumArt,
  FutureOr<void> Function()? onSeeLocal,
}) async {
  if (!context.mounted) {
    return;
  }

  List<MenuFlyoutItem> buildItems(String? resolvedPreferenceLevel) {
    return _buildPlayerMoreMenuItems(
      i18n: i18n,
      isMuted: isMuted,
      volumeValue: volumeValue,
      desktopLyricsEnabled: desktopLyricsEnabled,
      onToggleDesktopLyrics: onToggleDesktopLyrics,
      onQuickPlay: onQuickPlay,
      alwaysShowQuickPlay: alwaysShowQuickPlay,
      randomPlaySubmenu: randomPlaySubmenu,
      randomPlayDisabled: randomPlayDisabled,
      onVolumeChange: onVolumeChange,
      onToggleMute: onToggleMute,
      onToggleFavorite: onToggleFavorite,
      onToggleWindowFullScreen: onToggleWindowFullScreen,
      isWindowFullScreen: isWindowFullScreen,
      onEnterMiniMode: onEnterMiniMode,
      isCompact: isCompact,
      currentSong: currentSong,
      nowPlayingSongIds: nowPlayingSongIds,
      playlists: playlists,
      preferenceLevel: resolvedPreferenceLevel,
      onAddToNowPlaying: onAddToNowPlaying,
      onCreatePlaylist: onCreatePlaylist,
      onAddToPlaylist: onAddToPlaylist,
      onUndoPreference: onUndoPreference,
      onSetPreference: onSetPreference,
      onPlayArtist: onPlayArtist,
      onPlayAlbum: onPlayAlbum,
      showFavoriteWhenUnavailable: showFavoriteWhenUnavailable,
      onSeeArtist: onSeeArtist,
      onSeeAlbum: onSeeAlbum,
      onSeeMusicInfo: onSeeMusicInfo,
      onSeeLyrics: onSeeLyrics,
      onSeeAlbumArt: onSeeAlbumArt,
      onSeeLocal: onSeeLocal,
    );
  }

  final itemsNotifier = ValueNotifier<List<MenuFlyoutItem>>(
    buildItems(preferenceLevel),
  );
  var menuClosed = false;
  if (onResolvePreferenceLevel != null) {
    unawaited(
      Future.sync(onResolvePreferenceLevel).then((resolvedPreferenceLevel) {
        if (!menuClosed) {
          itemsNotifier.value = buildItems(resolvedPreferenceLevel);
        }
      }),
    );
  }
  await showMenuFlyout(
    context,
    anchorPlacement: MenuFlyoutAnchorPlacement.above,
    avoidPlayerBar: false,
    items: itemsNotifier.value,
    itemsListenable: itemsNotifier,
  );
  menuClosed = true;
  itemsNotifier.dispose();
}

List<MenuFlyoutItem> _buildPlayerMoreMenuItems({
  required SmPlayerI18n i18n,
  required bool isMuted,
  required int volumeValue,
  bool desktopLyricsEnabled = false,
  VoidCallback? onToggleDesktopLyrics,
  required VoidCallback onQuickPlay,
  bool alwaysShowQuickPlay = false,
  List<MenuFlyoutItem>? randomPlaySubmenu,
  bool randomPlayDisabled = false,
  required ValueChanged<int> onVolumeChange,
  required VoidCallback onToggleMute,
  required VoidCallback onToggleFavorite,
  VoidCallback? onToggleWindowFullScreen,
  required bool isWindowFullScreen,
  VoidCallback? onEnterMiniMode,
  bool isCompact = false,
  LibrarySong? currentSong,
  List<int> nowPlayingSongIds = const [],
  List<LibraryPlaylist> playlists = const [],
  String? preferenceLevel,
  VoidCallback? onAddToNowPlaying,
  ValueChanged<String>? onCreatePlaylist,
  ValueChanged<int>? onAddToPlaylist,
  VoidCallback? onUndoPreference,
  ValueChanged<String>? onSetPreference,
  VoidCallback? onPlayArtist,
  VoidCallback? onPlayAlbum,
  bool showFavoriteWhenUnavailable = false,
  VoidCallback? onSeeArtist,
  VoidCallback? onSeeAlbum,
  VoidCallback? onSeeMusicInfo,
  VoidCallback? onSeeLyrics,
  VoidCallback? onSeeAlbumArt,
  FutureOr<void> Function()? onSeeLocal,
}) {
  final currentScopeItems = <MenuFlyoutItem>[
    if (onPlayArtist != null)
      MenuFlyoutItem(
        key: 'random-current-artist',
        text: i18n.t('random.currentArtist'),
        icon: FluentIcons.people_20_regular,
        onPressed: onPlayArtist,
      ),
    if (onPlayAlbum != null)
      MenuFlyoutItem(
        key: 'random-current-album',
        text: i18n.t('random.currentAlbum'),
        useAlbumIcon: true,
        onPressed: onPlayAlbum,
      ),
  ];
  final mergedRandomPlaySubmenu = <MenuFlyoutItem>[
    ...currentScopeItems,
    if (currentScopeItems.isNotEmpty && randomPlaySubmenu?.isNotEmpty == true)
      const MenuFlyoutItem.separator(key: 'random-current-separator'),
    ...?randomPlaySubmenu,
  ];
  final items = [
    if (currentSong != null || alwaysShowQuickPlay)
      MenuFlyoutItem(
        key: 'quick-play',
        text: i18n.t('nowPlaying.quickPlay'),
        icon: _playIcon,
        onPressed: onQuickPlay,
      ),
    if (mergedRandomPlaySubmenu.isNotEmpty)
      MenuFlyoutItem(
        key: 'random-play',
        text: i18n.t('nowPlaying.randomPlay'),
        useShuffleIcon: true,
        disabled: randomPlayDisabled && currentScopeItems.isEmpty,
        submenu: mergedRandomPlaySubmenu,
      ),
    if ((currentSong != null || alwaysShowQuickPlay) &&
        (isCompact || currentSong != null))
      const MenuFlyoutItem.separator(key: 'play-actions-separator'),
    if (isCompact) ...[
      if (onToggleDesktopLyrics != null)
        MenuFlyoutItem(
          key: 'desktop-lyrics',
          text: _desktopLyricsTooltip(i18n, desktopLyricsEnabled),
          iconWidget: const _DesktopLyricsMenuIcon(),
          checked: desktopLyricsEnabled,
          onPressed: onToggleDesktopLyrics,
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
      if (currentSong != null || showFavoriteWhenUnavailable)
        MenuFlyoutItem(
          key: 'player-favorite',
          text:
              currentSong?.favorite == true
                  ? i18n.t('player.unlike')
                  : i18n.t('player.like'),
          iconWidget: SmPlayerFavoriteIcon(
            favorite: currentSong?.favorite == true,
            size: 18,
            animate: false,
          ),
          iconColor:
              currentSong?.favorite == true ? const Color(0xffd13438) : null,
          disabled: currentSong == null,
          onPressed: currentSong == null ? null : onToggleFavorite,
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
    defaultPlaylistName: currentSong.title,
    includeNowPlaying: shouldShowNowPlayingAddToTarget(
      songIds: [currentSong.id],
      nowPlayingSongIds: nowPlayingSongIds,
      isNowPlayingContext: false,
    ),
    includeFavorites: !isCompact && !currentSong.favorite,
    onAddToNowPlaying: onAddToNowPlaying,
    onToggleFavorite: currentSong.favorite ? null : onToggleFavorite,
    onCreatePlaylistWithName: onCreatePlaylist,
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
      icon: FluentIcons.eye_20_regular,
      submenu: [
        if (onSeeArtist != null)
          MenuFlyoutItem(
            key: 'see-artist',
            text: i18n.t('context.seeArtist'),
            icon: FluentIcons.people_20_regular,
            onPressed: onSeeArtist,
          ),
        if (onSeeAlbum != null)
          MenuFlyoutItem(
            key: 'see-album',
            text: i18n.t('context.seeAlbum'),
            useAlbumIcon: true,
            onPressed: onSeeAlbum,
          ),
        if (onSeeMusicInfo != null)
          MenuFlyoutItem(
            key: 'see-music-info',
            text: i18n.t('context.seeMusicInfo'),
            icon: FluentIcons.info_20_regular,
            onPressed: onSeeMusicInfo,
          ),
        if (onSeeLyrics != null)
          MenuFlyoutItem(
            key: 'see-lyrics',
            text: i18n.t('context.seeLyrics'),
            icon: FluentIcons.comment_text_20_regular,
            onPressed: onSeeLyrics,
          ),
        if (onSeeAlbumArt != null)
          MenuFlyoutItem(
            key: 'see-album-art',
            text: i18n.t('context.seeAlbumArt'),
            icon: FluentIcons.image_20_regular,
            onPressed: onSeeAlbumArt,
          ),
        if (onSeeLocal != null)
          MenuFlyoutItem(
            key: 'see-local-file',
            text: i18n.t('context.seeLocalFile'),
            icon: FluentIcons.hard_drive_20_regular,
            pendingText: i18n.t('context.openingLocal'),
            onPressed: onSeeLocal,
          ),
      ],
    ),
    if (onToggleWindowFullScreen != null)
      MenuFlyoutItem(
        key: isWindowFullScreen ? 'exit-full-screen' : 'full-screen',
        text:
            isWindowFullScreen
                ? i18n.t('nowPlaying.exitFullScreenItem')
                : i18n.t('nowPlaying.fullScreen'),
        useFullscreenIcon: !isWindowFullScreen,
        useExitFullscreenIcon: isWindowFullScreen,
        onPressed: onToggleWindowFullScreen,
      ),
    if (onEnterMiniMode != null)
      MenuFlyoutItem(
        key: 'mini-mode',
        text: i18n.t('player.miniMode'),
        icon: FluentIcons.picture_in_picture_20_regular,
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

class _DesktopLyricsMenuIcon extends StatelessWidget {
  const _DesktopLyricsMenuIcon();

  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color ??
        Colors.black;
    return SvgIcon(svg: _desktopLyricsIconSvg, size: 18, color: color);
  }
}

SmPlayerI18n _mediaControlI18n(BuildContext context) {
  return context.maybeSmPlayerI18n ??
      const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
}
