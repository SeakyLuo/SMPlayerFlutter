import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/undoable_notification.dart';
import '../../i18n/app_i18n.dart';
import '../data/library_providers.dart';
import 'local_folder_model.dart';

class LocalSongLocation {
  const LocalSongLocation(this.songId, this.folderPath);

  final int songId;
  final String folderPath;
}

final localSongLocationProvider = StateProvider<LocalSongLocation?>(
  (ref) => null,
);

bool locateSongInLocal(
  BuildContext context,
  int songId, {
  ValueChanged<String>? onNavigate,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final snapshot = container.read(libraryContentDataProvider).valueOrNull;
  final storedSong =
      snapshot?.songs.where((song) => song.id == songId).firstOrNull;
  if (snapshot == null || storedSong == null || snapshot.rootPath.isEmpty) {
    showAppNotification(
      context: context,
      message: context.smPlayerI18n.t('local.cannotLocateSong'),
    );
    return false;
  }
  final song =
      container.read(librarySongOverridesProvider)[songId] ?? storedSong;
  if (!isLocalPathUnderRoot(song.path, snapshot.rootPath)) {
    showAppNotification(
      context: context,
      message: context.smPlayerI18n.t('local.cannotLocateSong'),
    );
    return false;
  }

  final folderPath = getSongFolderRelativePath(song.path, snapshot.rootPath);
  container.read(localSongLocationProvider.notifier).state = LocalSongLocation(
    songId,
    folderPath,
  );
  final location =
      Uri(path: '/local', queryParameters: {'path': folderPath}).toString();
  if (onNavigate != null) {
    onNavigate(location);
  } else {
    context.go(location);
  }
  return true;
}

class LocalSongLocationHighlight extends StatelessWidget {
  const LocalSongLocationHighlight({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: active ? accent.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(
          color: active ? accent : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
