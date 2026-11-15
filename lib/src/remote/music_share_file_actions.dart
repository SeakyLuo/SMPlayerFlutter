import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/input_dialog.dart';
import '../app/undoable_notification.dart';
import '../i18n/app_i18n.dart';
import '../library/ui/menu_flyout.dart';
import 'music_share_access.dart';
import 'remote_directory_provider.dart';
import 'music_share_download.dart';
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
    MenuFlyoutItem(
      key: 'remote-download-song',
      text: i18n.t('share.download'),
      icon: FluentIcons.arrow_download_20_regular,
      onPressedWithContext:
          (context) => runMusicShareAction(
            context,
            () => downloadRemoteMusic(
              context,
              Uri.parse(path).host,
              songs: [int.parse(Uri.parse(path).pathSegments.single)],
            ),
          ),
    ),
    item(
      'remote-rename-file',
      i18n.t('share.renameFile'),
      FluentIcons.rename_20_regular,
      (context) => _rename(context, path),
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
  if (context.mounted) {
    ProviderScope.containerOf(
      context,
      listen: false,
    ).invalidate(remoteDirectoryProvider(Uri.parse(path).host));
  }
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
          if (context.mounted) {
            ProviderScope.containerOf(
              context,
              listen: false,
            ).invalidate(remoteDirectoryProvider(Uri.parse(path).host));
          }
        }),
  );
  if (reason != AppNotificationClosedReason.action) {
    await access.fileRequest(path, 'commit', {'ticket': ticket});
  }
}
