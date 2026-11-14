import '../../remote/music_share_models.dart';
import '../../remote/music_share_file_actions.dart';
import '../../remote/music_source_selector.dart';
import 'dart:async';
import 'dart:math';

export 'local_song_location.dart' show locateSongInLocal;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/input_dialog.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart';

part 'menu_flyout_shuffle.dart';

class MultiSelectCommandBarPlaylist {
  const MultiSelectCommandBarPlaylist({
    required this.id,
    required this.name,
    this.songIds = const [],
  });

  final int id;
  final String name;
  final List<int> songIds;
}

class MenuFlyoutFolder {
  const MenuFlyoutFolder({
    required this.id,
    required this.name,
    required this.path,
    required this.parentId,
  });

  final int id;
  final String name;
  final String path;
  final int parentId;
}

MenuFlyoutItem buildPreferenceMenuFlyoutItem({
  required SmPlayerI18n i18n,
  required String key,
  required String? preferenceLevel,
  FutureOr<void> Function()? onUndoPreference,
  required FutureOr<void> Function(String level) onSetPreference,
}) {
  return MenuFlyoutItem(
    key: key,
    text: i18n.t('settings.preferenceSettings'),
    icon: FluentIcons.star_20_regular,
    submenu: [
      if (preferenceLevel != null && onUndoPreference != null) ...[
        MenuFlyoutItem(
          key: '$key-undo',
          text: i18n.t('preferences.undoPrefer'),
          onPressedWithContext:
              (context) => runMusicShareAction(context, () async {
                await onUndoPreference();
              }),
        ),
        MenuFlyoutItem.separator(key: '$key-undo-separator'),
      ],
      for (final level in _preferenceLevels)
        MenuFlyoutItem(
          key: '$key-$level',
          text: i18n.t('preferences.level.$level'),
          icon:
              preferenceLevel == level
                  ? FluentIcons.checkmark_20_regular
                  : null,
          onPressedWithContext:
              (context) => runMusicShareAction(context, () async {
                await onSetPreference(level);
              }),
        ),
    ],
  );
}

MenuFlyoutItem? buildAddToPlaylistMenuFlyoutItem({
  required SmPlayerI18n i18n,
  required List<int> songIds,
  required List<MultiSelectCommandBarPlaylist> playlists,
  bool includeNowPlaying = false,
  bool includeFavorites = false,
  bool favoritesDisabled = false,
  bool favoritesSelected = false,
  String? defaultPlaylistName,
  String? currentPlaylistName,
  String? excludePlaylistName,
  VoidCallback? onPlayNext,
  VoidCallback? onAddToNowPlaying,
  VoidCallback? onToggleFavorite,
  VoidCallback? onRequestCreatePlaylist,
  VoidCallback? onCreatePlaylist,
  ValueChanged<String>? onCreatePlaylistWithName,
  ValueChanged<int>? onAddToPlaylist,
  String key = 'add-to',
}) {
  final addablePlaylists =
      playlists.where((playlist) {
        if (playlist.name == (excludePlaylistName ?? currentPlaylistName)) {
          return false;
        }
        if (songIds.length != 1) {
          return true;
        }
        return !playlist.songIds.contains(songIds.first);
      }).toList();
  final submenu = <MenuFlyoutItem>[];

  if (songIds.length == 1 && onPlayNext != null) {
    submenu.add(
      MenuFlyoutItem(
        key: '$key-play-next',
        text: i18n.t('context.playNext'),
        iconWidget: const SmPlayerPlayNextIcon(size: 18),
        onPressed: onPlayNext,
      ),
    );
  }

  if (includeNowPlaying) {
    submenu.add(
      MenuFlyoutItem(
        key: '$key-now-playing',
        text: i18n.t('common.nowPlaying'),
        icon: FluentIcons.headphones_20_regular,
        disabled: songIds.isEmpty,
        onPressed: onAddToNowPlaying,
      ),
    );
  }

  if (includeFavorites && onToggleFavorite != null) {
    submenu.add(
      MenuFlyoutItem(
        key: '$key-favorites',
        text: i18n.t('common.myFavorites'),
        iconWidget: SmPlayerFavoriteIcon(
          favorite: favoritesSelected,
          size: 18,
          animate: false,
        ),
        disabled: songIds.isEmpty || favoritesDisabled,
        onPressed: onToggleFavorite,
      ),
    );
  }

  if (submenu.isNotEmpty &&
      (onCreatePlaylist != null ||
          onCreatePlaylistWithName != null ||
          addablePlaylists.isNotEmpty)) {
    submenu.add(MenuFlyoutItem.separator(key: '$key-built-in-separator'));
  }

  if (onCreatePlaylist != null || onCreatePlaylistWithName != null) {
    submenu.add(
      MenuFlyoutItem(
        key: '$key-new-playlist',
        text: i18n.t('playlists.newPlaylist'),
        icon: FluentIcons.add_20_regular,
        disabled: songIds.isEmpty,
        onPressedWithContext: (context) async {
          if (onRequestCreatePlaylist != null) {
            onRequestCreatePlaylist();
            return;
          }
          if (onCreatePlaylistWithName == null) {
            onCreatePlaylist?.call();
            return;
          }
          final name = await showSmPlayerInputDialog(
            context: context,
            i18n: i18n,
            title: i18n.t('playlists.newName'),
            defaultValue: defaultPlaylistName ?? i18n.t('playlists.newName'),
            placeholder: i18n.t('playlists.namePlaceholder'),
            confirmText: i18n.t('common.confirm'),
          );
          if (name != null) {
            onCreatePlaylistWithName(name);
          }
        },
      ),
    );
  }

  submenu.addAll(
    addablePlaylists.map(
      (playlist) => MenuFlyoutItem(
        key: '$key-${playlist.id}',
        text: playlist.name,
        usePlaylistIcon: true,
        disabled: songIds.isEmpty,
        onPressed: () {
          onAddToPlaylist?.call(playlist.id);
        },
      ),
    ),
  );

  if (submenu.isEmpty) {
    return null;
  }

  return MenuFlyoutItem(
    key: key,
    text: i18n.t('context.addToPlaylist'),
    icon: FluentIcons.add_20_regular,
    disabled: songIds.isEmpty,
    submenu: submenu,
  );
}

bool shouldShowNowPlayingAddToTarget({
  required List<int> songIds,
  required List<int> nowPlayingSongIds,
  required bool isNowPlayingContext,
}) {
  if (isNowPlayingContext) {
    return false;
  }
  final nowPlayingSongIdSet = nowPlayingSongIds.toSet();
  return songIds.any((songId) => !nowPlayingSongIdSet.contains(songId));
}

List<MenuFlyoutItem> buildMusicMenuFlyoutItems({
  required SmPlayerI18n i18n,
  required int songId,
  required String songTitle,
  required bool isFavorite,
  required bool isCurrentTrack,
  required bool isPlaying,
  required List<int> nowPlayingSongIds,
  required List<MultiSelectCommandBarPlaylist> playlists,
  required VoidCallback onPlay,
  required VoidCallback onTogglePlayPause,
  VoidCallback? onPlayNext,
  required VoidCallback onAddToNowPlaying,
  required VoidCallback onCreatePlaylist,
  VoidCallback? onRequestCreatePlaylist,
  ValueChanged<String>? onCreatePlaylistWithName,
  required ValueChanged<int> onAddToPlaylist,
  required VoidCallback onRemove,
  required VoidCallback onSelect,
  required VoidCallback onToggleFavorite,
  required ValueChanged<String> onSetPreference,
  required VoidCallback onSeeArtist,
  required VoidCallback onSeeAlbum,
  required VoidCallback onSeeMusicInfo,
  required VoidCallback onSeeLyrics,
  required VoidCallback onSeeAlbumArt,
  required FutureOr<void> Function() onSeeLocal,
  VoidCallback? onLocateLocal,
  String? currentPlaylistName,
  String? excludePlaylistName,
  String? defaultPlaylistName,
  int? currentTrackId,
  String songPath = '',
  String? preferenceLevel,
  VoidCallback? onUndoPreference,
  List<MenuFlyoutFolder> folders = const [],
  ValueChanged<String>? onMoveToFolder,
  VoidCallback? onDelete,
  VoidCallback? onHide,
  bool showRemove = false,
  String? removeLabel,
  bool showSeeArtistsAndSeeAlbum = true,
  bool? showSeeArtist,
  bool? showSeeAlbum,
  bool showMusicProperties = true,
  bool showSelect = true,
  bool showDelete = true,
  bool showHideFile = false,
  bool showPreference = true,
  bool showMoveToFolder = false,
  bool showAlbumArt = true,
  bool keepViewActionsOpen = false,
  bool keepFavoritesInAddTo = false,
}) {
  final remoteFiles = isRemoteMusicPath(songPath) && showDelete;
  if (isRemoteMusicPath(songPath)) {
    showDelete = false;
    showHideFile = false;
    showMoveToFolder = false;
    onLocateLocal = null;
  }
  final items = <MenuFlyoutItem>[
    if (isCurrentTrack && isPlaying)
      MenuFlyoutItem(
        key: 'pause',
        text: i18n.t('context.pause'),
        icon: FluentIcons.pause_20_regular,
        onPressed: onTogglePlayPause,
      )
    else
      MenuFlyoutItem(
        key: 'play',
        text: i18n.t('context.play'),
        tooltip: i18n.t('context.playSongTooltip', {'title': songTitle}),
        icon: FluentIcons.play_20_regular,
        onPressed: isCurrentTrack ? onTogglePlayPause : onPlay,
      ),
  ];

  if (currentTrackId != null && !isCurrentTrack && onPlayNext != null) {
    items.add(
      MenuFlyoutItem(
        key: 'play-next',
        text: i18n.t('context.playNext'),
        tooltip: i18n.t('context.playNextSongTooltip', {'title': songTitle}),
        usePlayNextIcon: true,
        onPressed: onPlayNext,
      ),
    );
  }

  final addToItem = buildAddToPlaylistMenuFlyoutItem(
    i18n: i18n,
    songIds: [songId],
    playlists: playlists,
    currentPlaylistName: currentPlaylistName,
    excludePlaylistName: excludePlaylistName ?? currentPlaylistName,
    includeNowPlaying: shouldShowNowPlayingAddToTarget(
      songIds: [songId],
      nowPlayingSongIds: nowPlayingSongIds,
      isNowPlayingContext: currentPlaylistName == i18n.t('common.nowPlaying'),
    ),
    includeFavorites:
        currentPlaylistName != i18n.t('common.myFavorites') &&
        (!isFavorite || keepFavoritesInAddTo),
    favoritesDisabled: isFavorite,
    favoritesSelected: isFavorite,
    defaultPlaylistName: defaultPlaylistName,
    onAddToNowPlaying: onAddToNowPlaying,
    onToggleFavorite:
        isFavorite && !keepFavoritesInAddTo ? null : onToggleFavorite,
    onRequestCreatePlaylist: onRequestCreatePlaylist,
    onCreatePlaylist: onCreatePlaylist,
    onCreatePlaylistWithName: onCreatePlaylistWithName,
    onAddToPlaylist: onAddToPlaylist,
  );
  if (addToItem != null) {
    items.add(addToItem);
  }

  if (showRemove) {
    items.add(
      MenuFlyoutItem(
        key: 'remove',
        text: removeLabel ?? i18n.t('context.removeFromList'),
        icon: FluentIcons.dismiss_20_regular,
        onPressed: onRemove,
      ),
    );
  }

  if (showSelect) {
    items.add(
      MenuFlyoutItem(
        key: 'select',
        text: i18n.t('context.select'),
        icon: FluentIcons.multiselect_ltr_20_regular,
        onPressed: onSelect,
      ),
    );
  }

  if (showPreference) {
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

  if (remoteFiles) {
    items.addAll(buildRemoteFileMenuItems(i18n, songPath, songTitle));
  }

  if (showMoveToFolder && folders.isNotEmpty && onMoveToFolder != null) {
    final moveToFolderItem = buildMoveToFolderMenuFlyoutItem(
      i18n: i18n,
      folders: folders,
      songPath: songPath,
      onMoveToFolder: onMoveToFolder,
    );
    if (moveToFolderItem != null) {
      items.add(moveToFolderItem);
    }
  }

  if (showDelete && onDelete != null) {
    items.add(
      MenuFlyoutItem(
        key: 'delete',
        text: i18n.t('context.deleteFromDisk'),
        icon: FluentIcons.delete_20_regular,
        onPressed: onDelete,
      ),
    );
  }

  if (showHideFile && onHide != null) {
    items.add(
      MenuFlyoutItem(
        key: 'hide-file',
        text: i18n.t('context.hideFile'),
        icon: FluentIcons.eye_off_20_regular,
        onPressed: onHide,
      ),
    );
  }

  final viewItems = <MenuFlyoutItem>[];
  if (showMusicProperties) {
    if (showSeeArtist ?? showSeeArtistsAndSeeAlbum) {
      viewItems.add(
        MenuFlyoutItem(
          key: 'see-artist',
          text: i18n.t('context.seeArtist'),
          icon: FluentIcons.people_24_regular,
          onPressed: onSeeArtist,
        ),
      );
    }
    if (showSeeAlbum ?? showSeeArtistsAndSeeAlbum) {
      viewItems.add(
        MenuFlyoutItem(
          key: 'see-album',
          text: i18n.t('context.seeAlbum'),
          useAlbumIcon: true,
          onPressed: onSeeAlbum,
        ),
      );
    }
    viewItems.addAll([
      MenuFlyoutItem(
        key: 'see-music-info',
        text: i18n.t('context.seeMusicInfo'),
        icon: FluentIcons.info_20_regular,
        keepOpen: keepViewActionsOpen,
        onPressed: onSeeMusicInfo,
      ),
      MenuFlyoutItem(
        key: 'see-lyrics',
        text: i18n.t('context.seeLyrics'),
        icon: FluentIcons.comment_text_20_regular,
        keepOpen: keepViewActionsOpen,
        onPressed: onSeeLyrics,
      ),
      if (showAlbumArt)
        MenuFlyoutItem(
          key: 'see-album-art',
          text: i18n.t('context.seeAlbumArt'),
          icon: FluentIcons.image_20_regular,
          keepOpen: keepViewActionsOpen,
          onPressed: onSeeAlbumArt,
        ),
      if (onLocateLocal != null)
        MenuFlyoutItem(
          key: 'locate-local',
          text: i18n.t('context.locateInLocal'),
          icon: FluentIcons.hard_drive_24_regular,
          onPressed: onLocateLocal,
        ),
      if (!isRemoteMusicPath(songPath))
        MenuFlyoutItem(
          key: 'see-local',
          text: i18n.t('context.seeLocalFile'),
          icon: FluentIcons.folder_search_20_regular,
          pendingText: i18n.t('context.openingLocal'),
          onPressed: onSeeLocal,
        ),
    ]);
  }
  if (viewItems.isNotEmpty) {
    items.add(
      MenuFlyoutItem(
        key: 'view',
        text: i18n.t('context.view'),
        icon: FluentIcons.eye_20_regular,
        submenu: viewItems,
      ),
    );
  }

  return items;
}

const _preferenceLevels = [
  'do-not-appear',
  'dislike',
  'normal',
  'high',
  'higher',
  'very-high',
];

MenuFlyoutItem? buildMoveToFolderMenuFlyoutItem({
  required SmPlayerI18n i18n,
  required List<MenuFlyoutFolder> folders,
  required String songPath,
  required ValueChanged<String> onMoveToFolder,
}) {
  final currentFolderPath = _getFileParentPath(songPath);
  final childrenByParentId = <int, List<MenuFlyoutFolder>>{};
  for (final folder in folders) {
    childrenByParentId[folder.parentId] = [
      ...(childrenByParentId[folder.parentId] ?? const <MenuFlyoutFolder>[]),
      folder,
    ];
  }

  MenuFlyoutItem toTargetItem(MenuFlyoutFolder folder) {
    return MenuFlyoutItem(
      key: 'move-folder-${folder.id}-target',
      text: folder.name,
      onPressed: () {
        onMoveToFolder(folder.path);
      },
    );
  }

  MenuFlyoutItem? toItem(MenuFlyoutFolder folder) {
    final children =
        (childrenByParentId[folder.id] ?? const <MenuFlyoutFolder>[]).toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    final childItems = [
      for (final child in children)
        if (toItem(child) case final item?) item,
    ];
    final isTargetFolder = currentFolderPath != folder.path;

    if (childItems.isEmpty) {
      return isTargetFolder ? toTargetItem(folder) : null;
    }

    return MenuFlyoutItem(
      key: 'move-folder-${folder.id}',
      text: folder.name,
      submenu:
          isTargetFolder
              ? [
                toTargetItem(folder),
                MenuFlyoutItem.separator(
                  key: 'move-folder-${folder.id}-separator',
                ),
                ...childItems,
              ]
              : childItems,
    );
  }

  final rootItems =
      [
        for (final folder
            in (folders
                .where(
                  (folder) =>
                      folder.parentId == 0 ||
                      !folders.any((item) => item.id == folder.parentId),
                )
                .toList()
              ..sort((left, right) => left.name.compareTo(right.name))))
          if (toItem(folder) case final item?) item,
      ].expand((item) => item.submenu.isEmpty ? [item] : item.submenu).toList();

  if (rootItems.isEmpty) {
    return null;
  }

  return MenuFlyoutItem(
    key: 'move-to-folder',
    text: i18n.t('context.moveToFolder'),
    icon: FluentIcons.folder_20_regular,
    submenu: rootItems,
  );
}
