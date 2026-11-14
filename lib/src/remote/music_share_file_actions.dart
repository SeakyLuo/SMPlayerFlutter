import 'dart:async';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../app/input_dialog.dart';
import '../app/undoable_notification.dart';
import '../i18n/app_i18n.dart';
import '../library/ui/menu_flyout.dart';
import '../library/ui/menu_flyout_helpers.dart';
import '../library/ui/popup_dialog.dart';
import 'music_share_access.dart';
import 'music_source_providers.dart';
import 'music_source_selector.dart';

List<MenuFlyoutItem> buildRemoteFileMenuItems(
  SmPlayerI18n i18n,
  String path,
  String title,
) {
  final writable = activeMusicShareAccess!.canWrite(path);
  MenuFlyoutItem item(
    String key,
    String text,
    IconData icon,
    Future<void> Function(BuildContext) action,
  ) => MenuFlyoutItem(
    key: key,
    text: text,
    icon: icon,
    disabled: !writable,
    tooltip: writable ? null : i18n.t('share.readOnlyPermission'),
    onPressedWithContext:
        (context) => runMusicShareAction(context, () => action(context)),
  );
  return [
    item(
      'remote-rename-file',
      i18n.t('share.renameFile'),
      FluentIcons.rename_20_regular,
      (context) => _rename(context, path),
    ),
    item(
      'remote-move-file',
      i18n.t('context.moveToFolder'),
      FluentIcons.folder_20_regular,
      (context) => _move(context, path, title),
    ),
    item(
      'remote-delete-file',
      i18n.t('context.deleteFromDisk'),
      FluentIcons.delete_20_regular,
      (context) => _delete(context, path, title),
    ),
  ];
}

Future<void> _rename(BuildContext context, String path) async {
  final access = activeMusicShareAccess!;
  final info = await access.fileRequest(path, 'info', {});
  if (!context.mounted) return;
  final i18n = context.smPlayerI18n;
  final name = await showSmPlayerInputDialog(
    context: context,
    i18n: i18n,
    title: i18n.t('share.renameFileTitle', {
      'extension': info['extension'] as String,
    }),
    defaultValue: info['name'] as String,
    confirmText: i18n.t('playlists.rename'),
    placeholder: i18n.t('share.fileNameHint'),
  );
  if (name == null || name == info['name']) return;
  final result = await access.fileRequest(path, 'rename', {'name': name});
  if (!context.mounted) {
    await access.fileRequest(path, 'commit', {'ticket': result['ticket']});
    return;
  }
  await _showUndo(
    context,
    access,
    path,
    result['ticket'] as String,
    i18n.t('share.fileRenamed'),
  );
}

Future<void> _move(BuildContext context, String path, String title) async {
  final access = activeMusicShareAccess!;
  final info = await access.fileRequest(path, 'info', {});
  if (!context.mounted) return;
  final i18n = context.smPlayerI18n;
  final paths = (info['folders'] as List).cast<String>();
  final ids = {for (final entry in paths.indexed) entry.$2: entry.$1 + 1};
  final parent = info['parent'] as String;
  final folders = [
    for (final folder in paths)
      MenuFlyoutFolder(
        id: ids[folder]!,
        name:
            folder.isEmpty
                ? i18n.t('local.libraryRoot')
                : p.posix.basename(folder),
        path: folder,
        parentId:
            folder.isEmpty
                ? 0
                : ids[p.posix.dirname(folder) == '.'
                    ? ''
                    : p.posix.dirname(folder)]!,
      ),
  ];
  final menu = buildMoveToFolderMenuFlyoutItem(
    i18n: i18n,
    folders: folders,
    songPath: parent.isEmpty ? 'file' : '$parent/file',
    onMoveToFolder: (folder) {
      unawaited(
        runMusicShareAction(context, () async {
          final result = await access.fileRequest(path, 'move', {
            'folder': folder,
          });
          if (!context.mounted) {
            await access.fileRequest(path, 'commit', {
              'ticket': result['ticket'],
            });
            return;
          }
          await _showUndo(
            context,
            access,
            path,
            result['ticket'] as String,
            i18n.t('notification.movedSong', {'title': title}),
          );
        }),
      );
    },
  );
  if (menu == null) {
    showAppNotification(
      context: context,
      message: i18n.t('share.noMoveFolders'),
    );
    return;
  }
  showMenuFlyout(context, items: menu.submenu);
}

Future<void> _delete(BuildContext context, String path, String title) async {
  final access = activeMusicShareAccess!;
  final peer = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(musicShareProvider).peerFor(path);
  final i18n = context.smPlayerI18n;
  final confirmed = await showPopupConfirmDialog(
    context: context,
    title: i18n.t('context.deleteFromDisk'),
    message: i18n.t('share.remoteFileDeleteConfirm', {
      'device': peer.name,
      'title': title,
    }),
    confirmLabel: i18n.t('playlists.delete'),
  );
  if (!confirmed) return;
  final result = await access.fileRequest(path, 'delete', {});
  if (!context.mounted) {
    await access.fileRequest(path, 'commit', {'ticket': result['ticket']});
    return;
  }
  await _showUndo(
    context,
    access,
    path,
    result['ticket'] as String,
    i18n.t('notification.deletedFromDisk', {'title': title}),
  );
}

Future<void> _showUndo(
  BuildContext context,
  MusicShareAccess access,
  String path,
  String ticket,
  String message,
) async {
  final reason = await showUndoableNotification(
    context: context,
    i18n: context.smPlayerI18n,
    message: message,
    onUndo:
        () => runMusicShareAction(context, () async {
          await access.fileRequest(path, 'undo', {'ticket': ticket});
        }),
  );
  if (reason != AppNotificationClosedReason.action) {
    await access.fileRequest(path, 'commit', {'ticket': ticket});
  }
}
