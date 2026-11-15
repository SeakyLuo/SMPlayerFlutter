import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/undoable_notification.dart';
import '../i18n/app_i18n.dart';
import '../library/data/library_providers.dart';
import '../library/ui/menu_flyout.dart';
import '../remote/music_share_models.dart';
import '../remote/music_source_providers.dart';

Future<List<MenuFlyoutItem>> loadSourceShuffleMenu(
  BuildContext context,
  SmPlayerI18n i18n,
  ValueChanged<List<int>> onPlaySongs,
  int limit,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final source = container.read(selectedLibraryDataSourceProvider);
  final notificationContext =
      Navigator.of(context, rootNavigator: true).context;
  final modes = (await source.selectionModes(limit)).toSet();
  const labels = {
    LibrarySelectionKind.library: 'random.musicLibrary',
    LibrarySelectionKind.artist: 'common.artist',
    LibrarySelectionKind.album: 'common.album',
    LibrarySelectionKind.folder: 'random.localFolder',
    LibrarySelectionKind.recentAdded: 'common.recentAdded',
    LibrarySelectionKind.recentPlayed: 'random.recentPlayed',
    LibrarySelectionKind.mostPlayed: 'random.mostPlayed',
    LibrarySelectionKind.leastPlayed: 'random.leastPlayed',
    LibrarySelectionKind.favorites: 'common.myFavorites',
    LibrarySelectionKind.playlist: 'common.playlist',
  };
  if (modes.isEmpty && notificationContext.mounted) {
    showAppNotification(
      context: notificationContext,
      message: i18n.t('app.libraryEmpty'),
    );
  }
  return [
    for (final entry in labels.entries)
      if (modes.contains(entry.key))
        MenuFlyoutItem(
          key: entry.key.name,
          text: i18n.t(entry.value),
          icon: switch (entry.key) {
            LibrarySelectionKind.library => FluentIcons.library_24_regular,
            LibrarySelectionKind.artist => FluentIcons.people_24_regular,
            LibrarySelectionKind.folder => FluentIcons.hard_drive_24_regular,
            LibrarySelectionKind.favorites => FluentIcons.heart_24_regular,
            LibrarySelectionKind.album || LibrarySelectionKind.playlist => null,
            _ => FluentIcons.clock_24_regular,
          },
          useAlbumIcon: entry.key == LibrarySelectionKind.album,
          usePlaylistIcon: entry.key == LibrarySelectionKind.playlist,
          onPressed: () async {
            try {
              final songs = await source.selectSongIds(
                LibrarySelectionRequest(entry.key, limit: limit),
              );
              final ids = songs;
              if (ids.isNotEmpty) onPlaySongs(ids);
            } catch (error) {
              if (notificationContext.mounted) {
                showAppNotification(
                  context: notificationContext,
                  message: i18n.t(
                    error is MusicShareException
                        ? error.messageKey
                        : 'share.connectionFailed',
                  ),
                );
              }
            }
          },
        ),
  ];
}
