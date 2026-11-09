import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/undoable_notification.dart';
import '../i18n/app_i18n.dart';
import '../library/ui/menu_flyout.dart';
import 'music_share_dialog.dart';
import 'music_share_models.dart';
import 'music_source_providers.dart';

Future<void> runMusicShareAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (!context.mounted) return;
    showAppNotification(
      context: context,
      message: context.smPlayerI18n.t(
        error is MusicShareException
            ? error.messageKey
            : 'share.connectionFailed',
      ),
    );
  }
}

MenuFlyoutItem buildMusicSourceMenuItem(BuildContext context) {
  final share = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(musicShareProvider);
  final i18n = context.smPlayerI18n;
  final peer =
      share.peers.where((peer) => peer.id == share.selectedSource).firstOrNull;
  final label =
      share.selectedSource == 'all'
          ? i18n.t('share.allSources')
          : peer?.name ?? i18n.t('share.localSource');

  Future<void> selectSource(String source) =>
      runMusicShareAction(context, () async {
        await share.selectSource(source);
        if (context.mounted &&
            GoRouterState.of(context).uri.path == '/local' &&
            source != 'local') {
          context.go('/songs');
        }
      });

  return MenuFlyoutItem(
    key: 'music-source',
    text: '${i18n.t('share.musicSource')}: $label',
    icon: FluentIcons.library_24_regular,
    submenu: [
      for (final source in [
        ('local', i18n.t('share.localSource')),
        ('all', i18n.t('share.allSources')),
      ])
        MenuFlyoutItem(
          key: source.$1,
          text: source.$2,
          checked: share.selectedSource == source.$1,
          onPressed: () => selectSource(source.$1),
        ),
      for (final device in share.peers)
        MenuFlyoutItem(
          key: device.id,
          text:
              '${device.name} · ${i18n.t(device.status == MusicPeerStatus.online
                  ? 'share.online'
                  : device.status == MusicPeerStatus.unauthorized
                  ? 'share.authorizationRequired'
                  : 'share.offline')}',
          checked: share.selectedSource == device.id,
          icon: FluentIcons.desktop_24_regular,
          onPressed: () => selectSource(device.id),
        ),
      const MenuFlyoutItem.separator(key: 'source-actions'),
      MenuFlyoutItem(
        key: 'connect',
        text: i18n.t('share.connectComputer'),
        icon: FluentIcons.plug_connected_24_regular,
        onPressed: () => showMusicShareDialog(context),
      ),
      MenuFlyoutItem(
        key: 'manage',
        text: i18n.t('share.manageSharing'),
        icon: FluentIcons.settings_24_regular,
        onPressed: () => context.go('/settings'),
      ),
    ],
  );
}
