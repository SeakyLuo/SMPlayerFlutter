import 'dart:async';
import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/input_dialog.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/menu_flyout.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart';

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

List<MenuFlyoutItem> buildShuffleMenuFlyoutItems({
  required SmPlayerI18n i18n,
  required List<LibrarySong> songs,
  required List<LibrarySong> librarySongs,
  required List<LibrarySong> recentSongs,
  required List<LibraryPlaylist> playlists,
  required List<LibraryFolder> folders,
  required int randomLimit,
  required ValueChanged<List<int>> onPlaySongs,
  FutureOr<void> Function()? onQuickPlay,
}) {
  void playSongs(List<LibrarySong> sourceSongs) {
    onPlaySongs(_randomLibrary(sourceSongs, randomLimit));
  }

  void playAllSongs(List<LibrarySong> sourceSongs) {
    onPlaySongs(_shuffleSongIds(sourceSongs));
  }

  final playableFolders =
      folders
          .where(
            (folder) => librarySongs.any(
              (song) => _isSongDirectlyInFolder(song, folder.path),
            ),
          )
          .toList();
  final playablePlaylists =
      playlists.where((playlist) => playlist.songIds.isNotEmpty).toList();
  final items = <MenuFlyoutItem>[
    MenuFlyoutItem(
      key: 'quick',
      text: i18n.t('nowPlaying.quickPlay'),
      onPressed: onQuickPlay ?? () => playSongs(librarySongs),
    ),
  ];

  if (songs.isNotEmpty) {
    items.addAll([
      const MenuFlyoutItem.separator(key: 'now-playing-separator'),
      MenuFlyoutItem(
        key: 'now-playing',
        text: i18n.t('common.nowPlaying'),
        onPressed: () => playAllSongs(songs),
      ),
    ]);
  }

  if (librarySongs.isEmpty) {
    return items;
  }

  items.addAll([
    const MenuFlyoutItem.separator(key: 'shuffle-library-separator'),
    MenuFlyoutItem(
      key: 'library',
      text: i18n.t('random.musicLibrary'),
      onPressed: () => playSongs(librarySongs),
    ),
    MenuFlyoutItem(
      key: 'artist',
      text: i18n.t('common.artist'),
      onPressed: () => onPlaySongs(_randomArtist(librarySongs, randomLimit)),
    ),
    MenuFlyoutItem(
      key: 'album',
      text: i18n.t('common.album'),
      onPressed: () => onPlaySongs(_randomAlbum(librarySongs, randomLimit)),
    ),
  ]);

  if (playablePlaylists.isNotEmpty) {
    items.add(
      MenuFlyoutItem(
        key: 'playlist',
        text: i18n.t('common.playlist'),
        onPressed: () {
          onPlaySongs(
            _randomPlaylist(librarySongs, playablePlaylists, randomLimit),
          );
        },
      ),
    );
  }

  if (playableFolders.isNotEmpty) {
    items.add(
      MenuFlyoutItem(
        key: 'folder',
        text: i18n.t('random.localFolder'),
        onPressed: () {
          onPlaySongs(
            _randomFolder(librarySongs, playableFolders, randomLimit),
          );
        },
      ),
    );
  }

  items.add(
    MenuFlyoutItem(
      key: 'recent-added',
      text: i18n.t('common.recentAdded'),
      onPressed:
          () => onPlaySongs(_randomRecentAdded(librarySongs, randomLimit)),
    ),
  );

  if (recentSongs.isNotEmpty) {
    items.add(
      MenuFlyoutItem(
        key: 'recent-played',
        text: i18n.t('random.recentPlayed'),
        onPressed: () => onPlaySongs(_shuffleSongIds(recentSongs)),
      ),
    );
  }

  if (librarySongs.length > randomLimit) {
    items.addAll([
      const MenuFlyoutItem.separator(key: 'shuffle-history-separator'),
      MenuFlyoutItem(
        key: 'most-played',
        text: i18n.t('random.mostPlayed'),
        onPressed:
            () => onPlaySongs(_randomMostPlayed(librarySongs, randomLimit)),
      ),
      MenuFlyoutItem(
        key: 'least-played',
        text: i18n.t('random.leastPlayed'),
        onPressed:
            () => onPlaySongs(_randomLeastPlayed(librarySongs, randomLimit)),
      ),
    ]);
  }

  return items;
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
          onPressed: onUndoPreference,
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
          onPressed: () => onSetPreference(level),
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
  String? defaultPlaylistName,
  String? currentPlaylistName,
  String? excludePlaylistName,
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

  if (includeNowPlaying) {
    submenu.add(
      MenuFlyoutItem(
        key: '$key-now-playing',
        text: i18n.t('common.nowPlaying'),
        icon: FluentIcons.music_note_2_20_regular,
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
        icon: FluentIcons.heart_20_regular,
        disabled: songIds.isEmpty,
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

List<MenuFlyoutItem> buildMusicMenuFlyoutItems({
  required SmPlayerI18n i18n,
  required int songId,
  required bool isFavorite,
  required bool isCurrentTrack,
  required bool isPlaying,
  required List<MultiSelectCommandBarPlaylist> playlists,
  required VoidCallback onPlay,
  required VoidCallback onPause,
  required VoidCallback onPlayNext,
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
  bool showMusicProperties = true,
  bool showSelect = true,
  bool showDelete = true,
  bool showHideFile = false,
  bool showPreference = true,
  bool showMoveToFolder = false,
  bool showAlbumArt = true,
  bool keepViewActionsOpen = true,
}) {
  final items = <MenuFlyoutItem>[
    if (isCurrentTrack && isPlaying)
      MenuFlyoutItem(
        key: 'pause',
        text: i18n.t('context.pause'),
        icon: FluentIcons.pause_20_regular,
        onPressed: onPause,
      )
    else
      MenuFlyoutItem(
        key: 'play',
        text: i18n.t('context.play'),
        icon: FluentIcons.play_20_regular,
        onPressed: onPlay,
      ),
  ];

  if (currentTrackId != null && !isCurrentTrack) {
    items.add(
      MenuFlyoutItem(
        key: 'play-next',
        text: i18n.t('context.playNext'),
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
    includeNowPlaying: currentPlaylistName != i18n.t('common.nowPlaying'),
    includeFavorites:
        currentPlaylistName != i18n.t('common.myFavorites') && !isFavorite,
    defaultPlaylistName: defaultPlaylistName,
    onAddToNowPlaying: onAddToNowPlaying,
    onToggleFavorite: isFavorite ? null : onToggleFavorite,
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

  if (showMoveToFolder && folders.isNotEmpty && onMoveToFolder != null) {
    final moveToFolderItem = _buildMoveToFolderMenuFlyoutItem(
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
        icon: FluentIcons.dismiss_20_regular,
        onPressed: onHide,
      ),
    );
  }

  final viewItems = <MenuFlyoutItem>[];
  if (showMusicProperties) {
    if (showSeeArtistsAndSeeAlbum) {
      viewItems.addAll([
        MenuFlyoutItem(
          key: 'see-artist',
          text: i18n.t('context.seeArtist'),
          icon: FluentIcons.people_20_regular,
          onPressed: onSeeArtist,
        ),
        MenuFlyoutItem(
          key: 'see-album',
          text: i18n.t('context.seeAlbum'),
          useAlbumIcon: true,
          onPressed: onSeeAlbum,
        ),
      ]);
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
      MenuFlyoutItem(
        key: 'see-local',
        text: i18n.t('context.seeLocalFile'),
        icon: FluentIcons.hard_drive_20_regular,
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

List<int> _randomLibrary(List<LibrarySong> songs, int randomLimit) {
  return _randomItems(songs, randomLimit).map((song) => song.id).toList();
}

List<int> _shuffleSongIds(List<LibrarySong> songs) {
  final shuffled = songs.toList()..shuffle(Random());
  return shuffled.map((song) => song.id).toList();
}

List<int> _randomArtist(List<LibrarySong> songs, int randomLimit) {
  final songsByArtist = <String, List<LibrarySong>>{};
  for (final song in songs) {
    final artists = _randomSongArtists(song);
    for (final artist in artists) {
      songsByArtist[artist] = [...(songsByArtist[artist] ?? []), song];
    }
  }
  final group = _randomItem(songsByArtist.values.toList());
  return _randomItems(group, randomLimit).map((song) => song.id).toList();
}

List<int> _randomAlbum(List<LibrarySong> songs, int randomLimit) {
  return _randomItems(
    _randomSongGroup(songs, (song) => song.album),
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomPlaylist(
  List<LibrarySong> songs,
  List<LibraryPlaylist> playlists,
  int randomLimit,
) {
  final songsById = {for (final song in songs) song.id: song};
  final playlist = _randomItem(playlists);
  final playlistSongs =
      playlist.songIds
          .map((songId) => songsById[songId])
          .whereType<LibrarySong>()
          .toList();
  return _randomItems(
    playlistSongs,
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomFolder(
  List<LibrarySong> songs,
  List<LibraryFolder> folders,
  int randomLimit,
) {
  final playableFolders =
      folders
          .map(
            (folder) => (
              folder: folder,
              songs:
                  songs
                      .where(
                        (song) => _isSongDirectlyInFolder(song, folder.path),
                      )
                      .toList(),
            ),
          )
          .where((entry) => entry.songs.isNotEmpty)
          .toList();
  if (playableFolders.isEmpty) {
    return const [];
  }
  return _randomItems(
    _randomItem(playableFolders).songs,
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomRecentAdded(List<LibrarySong> songs, int randomLimit) {
  final sorted =
      songs.toList()
        ..sort((left, right) => right.dateAdded.compareTo(left.dateAdded));
  return _randomItems(
    sorted.take(500).toList(),
    randomLimit,
  ).map((song) => song.id).toList();
}

List<int> _randomMostPlayed(List<LibrarySong> songs, int randomLimit) {
  return _shuffleSongIds(
    _playedSongs(songs, randomLimit, descending: true),
  ).take(randomLimit).toList();
}

List<int> _randomLeastPlayed(List<LibrarySong> songs, int randomLimit) {
  return _shuffleSongIds(
    _playedSongs(songs, randomLimit, descending: false),
  ).take(randomLimit).toList();
}

List<LibrarySong> _playedSongs(
  List<LibrarySong> songs,
  int randomLimit, {
  required bool descending,
}) {
  final songsByPlayCount = <int, List<LibrarySong>>{};
  for (final song in songs) {
    songsByPlayCount[song.playCount] = [
      ...(songsByPlayCount[song.playCount] ?? const <LibrarySong>[]),
      song,
    ];
  }

  final playCounts =
      songsByPlayCount.keys.toList()..sort(
        (left, right) =>
            descending ? right.compareTo(left) : left.compareTo(right),
      );
  final selectedSongs = <LibrarySong>[];
  for (final playCount in playCounts) {
    if (selectedSongs.length > randomLimit) {
      break;
    }
    selectedSongs.addAll(songsByPlayCount[playCount]!);
  }
  return selectedSongs;
}

List<LibrarySong> _randomSongGroup(
  List<LibrarySong> songs,
  String Function(LibrarySong song) getKey,
) {
  final groups = <String, List<LibrarySong>>{};
  for (final song in songs) {
    final key = getKey(song);
    groups[key] = [...(groups[key] ?? []), song];
  }
  return _randomItem(groups.values.toList()).toList()..shuffle(Random());
}

List<T> _randomItems<T>(List<T> items, int count) {
  if (items.length <= count) {
    return items.toList()..shuffle(Random());
  }

  final indices = <int>{};
  final random = Random();
  while (indices.length < count) {
    indices.add(random.nextInt(items.length));
  }
  return [for (final index in indices) items[index]];
}

T _randomItem<T>(List<T> items) {
  return items[Random().nextInt(items.length)];
}

List<String> _randomSongArtists(LibrarySong song) {
  final artists = songArtists(song);
  return artists.isEmpty ? const ['Unknown artist'] : artists;
}

bool _isSongDirectlyInFolder(LibrarySong song, String folderPath) {
  return _getFileParentPath(song.path) == folderPath;
}

String _getFileParentPath(String path) {
  final separatorIndex = max(path.lastIndexOf('\\'), path.lastIndexOf('/'));
  return separatorIndex > -1 ? path.substring(0, separatorIndex) : '';
}

const _preferenceLevels = [
  'do-not-appear',
  'dislike',
  'normal',
  'high',
  'higher',
  'very-high',
];

MenuFlyoutItem? _buildMoveToFolderMenuFlyoutItem({
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
