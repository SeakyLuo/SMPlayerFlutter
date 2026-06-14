import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/shell_actions.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout_helpers.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';
import 'package:smplayer_flutter/src/playback/immersive_mode_model.dart';

Future<void> showImmersiveModeMoreMenu({
  required BuildContext context,
  required WidgetRef ref,
  required BuildContext buttonContext,
  required LibrarySong? currentSong,
  required LibraryContentData snapshot,
  required List<int> queueSongIds,
  required List<MultiSelectCommandBarPlaylist> customPlaylists,
  required List<LibrarySong> recentSongs,
  required SmPlayerShellActions? shellActions,
  required bool isCompact,
  required VoidCallback onQuickPlay,
  required ValueChanged<List<int>> onPlaySongs,
  required VoidCallback onToggleShuffle,
  required Future<void> Function(String name, List<int> songIds)
  onCreatePlaylist,
  required Future<void> Function(int playlistId, List<int> songIds)
  onAddSongsToPlaylist,
  required void Function(LibrarySong song) onAddSongToNowPlaying,
  required Future<void> Function(List<int> songIds, bool favorite)
  onToggleSongsFavorite,
  required Future<void> Function(int songId, String title, String level)
  onSetSongPreference,
  required void Function(SongDialogMode mode) onOpenMusicDialog,
  required void Function(LibrarySong song, List<LibrarySong> songs)
  onPlayArtist,
  required void Function(LibrarySong song, List<LibrarySong> songs) onPlayAlbum,
  required ValueChanged<bool> onMenuOpenChanged,
  required VoidCallback onSchedulePlayerBarHide,
  required bool Function() hasDialogOpen,
  required bool Function() isMounted,
}) async {
  final i18n = context.smPlayerI18n;
  final mediaController = ref.read(mediaControlControllerProvider);
  onMenuOpenChanged(true);
  if (!buttonContext.mounted) {
    onMenuOpenChanged(false);
    if (!hasDialogOpen()) {
      onSchedulePlayerBarHide();
    }
    return;
  }
  final songsById = {for (final song in snapshot.songs) song.id: song};
  final queueSongs =
      queueSongIds
          .map((songId) => songsById[songId])
          .whereType<LibrarySong>()
          .toList();
  final activeSong =
      mediaController.state.disabled || mediaController.state.track.id == null
          ? null
          : currentSong;
  final addToItem =
      activeSong == null
          ? null
          : buildAddToPlaylistMenuFlyoutItem(
            i18n: i18n,
            songIds: [activeSong.id],
            playlists: customPlaylists,
            includeNowPlaying: shouldShowNowPlayingAddToTarget(
              songIds: [activeSong.id],
              nowPlayingSongIds: queueSongIds,
              isNowPlayingContext: false,
            ),
            includeFavorites: !isCompact && !activeSong.favorite,
            defaultPlaylistName: activeSong.title,
            onAddToNowPlaying: () {
              onAddSongToNowPlaying(activeSong);
            },
            onToggleFavorite: () {
              onToggleSongsFavorite([activeSong.id], true);
            },
            onCreatePlaylistWithName: (name) {
              onCreatePlaylist(name, [activeSong.id]);
            },
            onAddToPlaylist: (playlistId) {
              onAddSongsToPlaylist(playlistId, [activeSong.id]);
            },
          );
  List<MenuFlyoutItem> buildItems(String? preferenceLevel) {
    return [
      MenuFlyoutItem(
        key: 'quick-play',
        text: i18n.t('nowPlaying.quickPlay'),
        icon: FluentIcons.play_20_regular,
        onPressed: onQuickPlay,
      ),
      MenuFlyoutItem(
        key: 'random-play',
        text: i18n.t('nowPlaying.randomPlay'),
        useShuffleIcon: true,
        disabled: queueSongIds.isEmpty && snapshot.songs.isEmpty,
        submenu: buildShuffleMenuFlyoutItems(
          i18n: i18n,
          songs: queueSongs,
          librarySongs: snapshot.songs,
          recentSongs: recentSongs,
          playlists: snapshot.playlists,
          folders: snapshot.folders,
          randomLimit: nowPlayingQuickPlayLimit,
          onPlaySongs: onPlaySongs,
          onQuickPlay: onQuickPlay,
        ),
      ),
      if (isCompact) ...[
        MenuFlyoutItem(
          key: 'playback-mode',
          text:
              '${i18n.t('player.playbackMode')}: ${_playbackModeName(i18n, mediaController.state.mode)}',
          icon:
              mediaController.state.mode == PlaybackMode.shuffle
                  ? null
                  : _nonShufflePlaybackModeMenuIcon(mediaController.state.mode),
          usePlaylistIcon: mediaController.state.mode == PlaybackMode.once,
          useShuffleIcon: mediaController.state.mode == PlaybackMode.shuffle,
          submenu: buildPlaybackModeMenuFlyoutItems(
            i18n: i18n,
            mode: mediaController.state.mode,
            onToggleShuffle: onToggleShuffle,
            onToggleRepeat: mediaController.onToggleRepeat,
            onToggleRepeatOne: mediaController.onToggleRepeatOne,
          ),
        ),
        MenuFlyoutItem(
          key: 'player-volume',
          text: i18n.t('player.volume'),
          icon: playerVolumeIcon(
            mediaController.state.volume,
            mediaController.state.isMuted,
          ),
          keepOpen: true,
          contentHeight: 42,
          content: PlayerVolumeMenuItem(
            label: i18n.t('player.volume'),
            muted: mediaController.state.isMuted,
            volumeValue: mediaController.state.volume,
            disabled: false,
            onToggleMute: mediaController.onToggleMute,
            onVolumeChange: mediaController.onVolumeChange,
          ),
        ),
        MenuFlyoutItem(
          key: 'player-favorite',
          text:
              activeSong?.favorite == true
                  ? i18n.t('player.unlike')
                  : i18n.t('player.like'),
          icon:
              activeSong?.favorite == true
                  ? FluentIcons.heart_20_filled
                  : FluentIcons.heart_20_regular,
          iconColor:
              activeSong?.favorite == true ? const Color(0xffd13438) : null,
          disabled: activeSong == null,
          onPressed:
              activeSong == null
                  ? null
                  : () {
                    onToggleSongsFavorite([
                      activeSong.id,
                    ], !activeSong.favorite);
                  },
        ),
      ],
      if (activeSong != null) ...[
        if (addToItem != null) ...[
          const MenuFlyoutItem.separator(key: 'current-song-separator'),
          addToItem,
        ],
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
                        .removePreferenceItem('song', '${activeSong.id}');
                  },
          onSetPreference: (level) {
            onSetSongPreference(activeSong.id, activeSong.title, level);
          },
        ),
        MenuFlyoutItem(
          key: 'play-artist',
          text: i18n.t('detail.playArtist'),
          icon: FluentIcons.people_24_regular,
          onPressed: () {
            onPlayArtist(activeSong, snapshot.songs);
          },
        ),
        MenuFlyoutItem(
          key: 'play-album',
          text: i18n.t('detail.playAlbum'),
          useAlbumIcon: true,
          onPressed: () {
            onPlayAlbum(activeSong, snapshot.songs);
          },
        ),
        MenuFlyoutItem(
          key: 'view',
          text: i18n.t('context.view'),
          icon: FluentIcons.eye_20_regular,
          submenu: [
            MenuFlyoutItem(
              key: 'see-music-info',
              text: i18n.t('context.seeMusicInfo'),
              icon: FluentIcons.info_20_regular,
              onPressed: () {
                onOpenMusicDialog(SongDialogMode.properties);
              },
            ),
            MenuFlyoutItem(
              key: 'see-lyrics',
              text: i18n.t('context.seeLyrics'),
              icon: FluentIcons.comment_text_20_regular,
              onPressed: () {
                onOpenMusicDialog(SongDialogMode.lyrics);
              },
            ),
            MenuFlyoutItem(
              key: 'see-album-art',
              text: i18n.t('context.seeAlbumArt'),
              icon: FluentIcons.image_20_regular,
              onPressed: () {
                onOpenMusicDialog(SongDialogMode.albumArt);
              },
            ),
          ],
        ),
      ],
    ];
  }

  final itemsNotifier = ValueNotifier<List<MenuFlyoutItem>>(buildItems(null));
  var menuClosed = false;
  if (activeSong != null) {
    unawaited(
      ref
          .read(libraryRepositoryProvider)
          .getPreferenceLevel('song', '${activeSong.id}')
          .then((preferenceLevel) {
            if (!menuClosed) {
              itemsNotifier.value = buildItems(preferenceLevel);
            }
          }),
    );
  }
  await showMenuFlyout(
    buttonContext,
    position: _menuFlyoutPositionAboveAnchor(buttonContext),
    avoidPlayerBar: false,
    items: itemsNotifier.value,
    itemsListenable: itemsNotifier,
  );
  menuClosed = true;
  itemsNotifier.dispose();
  if (!isMounted()) {
    return;
  }
  onMenuOpenChanged(false);
  if (!hasDialogOpen()) {
    onSchedulePlayerBarHide();
  }
}

String _playbackModeName(SmPlayerI18n i18n, PlaybackMode mode) {
  return switch (mode) {
    PlaybackMode.shuffle => i18n.t('player.playbackModeShuffle'),
    PlaybackMode.repeat => i18n.t('player.playbackModeRepeat'),
    PlaybackMode.repeatOne => i18n.t('player.playbackModeRepeatOne'),
    PlaybackMode.once => i18n.t('player.playbackModeList'),
  };
}

IconData _nonShufflePlaybackModeMenuIcon(PlaybackMode mode) {
  return switch (mode) {
    PlaybackMode.repeat => FluentIcons.arrow_repeat_all_20_regular,
    PlaybackMode.repeatOne => FluentIcons.arrow_repeat_1_20_regular,
    PlaybackMode.once => FluentIcons.music_note_2_20_regular,
    PlaybackMode.shuffle =>
      throw StateError('shuffle uses SmPlayerShuffleIcon'),
  };
}

Offset _menuFlyoutPositionAboveAnchor(BuildContext context) {
  final box = context.findRenderObject() as RenderBox;
  return box.localToGlobal(const Offset(0, -8));
}
