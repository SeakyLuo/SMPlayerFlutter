import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_i18n.dart';
import '../library/ui/popup_dialog.dart';
import 'music_source_providers.dart';
import 'music_source_selector.dart';

Future<void> showMusicShareAuthorizedDevices(BuildContext context) {
  var closing = false;
  return showScopedPopupDialog<void>(
    context: context,
    builder: (context) {
      void close() {
        if (closing) return;
        closing = true;
        Navigator.of(context).pop();
      }

      return PopupDialog(
        navLabel: context.smPlayerI18n.t('share.authorizedDevices'),
        navChildren: [
          Expanded(
            child: PopupDialogTitle(
              context.smPlayerI18n.t('share.authorizedDevices'),
            ),
          ),
        ],
        width: 520,
        height: 300,
        fullScreenOnNarrow: Platform.isAndroid || Platform.isIOS,
        onClose: close,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Material(
            type: MaterialType.transparency,
            child: _AuthorizedDevices(),
          ),
        ),
      );
    },
  );
}

class _AuthorizedDevices extends ConsumerWidget {
  const _AuthorizedDevices();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final share = ref.watch(musicShareProvider);
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    if (share.grants.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.desktop_24_regular,
              size: 32,
              color: colors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              i18n.t('share.noAuthorizedDevices'),
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              i18n.t('share.authorizedDevicesHint'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return ListView(
      children: [
        for (final grant in share.grants.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              FluentIcons.desktop_24_regular,
              color: colors.textMuted,
            ),
            title: Text(
              grant.value,
              style: TextStyle(color: colors.textStrong, fontSize: 14),
            ),
            trailing: PopupDialogActionButton(
              label: i18n.t('share.revoke'),
              onPressed: () async {
                final confirmed = await showPopupConfirmDialog(
                  context: context,
                  title: i18n.t('share.revoke'),
                  message: i18n.t('share.revokeConfirm', {'name': grant.value}),
                  confirmLabel: i18n.t('share.revoke'),
                );
                if (confirmed && context.mounted) {
                  await runMusicShareAction(
                    context,
                    () => share.revoke(grant.key),
                  );
                }
              },
            ),
          ),
        const SizedBox(height: 12),
        Text(
          i18n.t('share.revokeHint'),
          style: TextStyle(color: colors.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}
