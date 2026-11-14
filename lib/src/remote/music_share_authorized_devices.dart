import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_i18n.dart';
import '../library/ui/popup_dialog.dart';
import 'music_source_providers.dart';
import 'music_share_permission_selector.dart';
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
          LayoutBuilder(
            builder: (context, constraints) {
              final icon = Icon(
                share.mobileGrants.contains(grant.key)
                    ? FluentIcons.phone_24_regular
                    : FluentIcons.desktop_24_regular,
                color: colors.textMuted,
              );
              final title = Text(
                grant.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textStrong, fontSize: 14),
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MusicSharePermissionSelector(
                    canWrite: share.writeGrants.contains(grant.key),
                    enabled: !share.permissionChanges.contains(grant.key),
                    loading: share.permissionChanges.contains(grant.key),
                    onChanged:
                        (canWrite) => runMusicShareAction(
                          context,
                          () => share.setWritePermission(grant.key, canWrite),
                        ),
                  ),
                  const SizedBox(width: 8),
                  PopupDialogActionButton(
                    label: i18n.t('share.revoke'),
                    loading: share.permissionChanges.contains(grant.key),
                    onPressed:
                        share.permissionChanges.contains(grant.key)
                            ? null
                            : () async {
                              await showPopupConfirmDialog(
                                context: context,
                                title: i18n.t('share.revoke'),
                                message: i18n.t('share.revokeConfirm', {
                                  'name': grant.value,
                                }),
                                confirmLabel: i18n.t('share.revoke'),
                                destructive: true,
                                onConfirm:
                                    () => runMusicShareAction(
                                      context,
                                      () => share.revoke(grant.key),
                                    ),
                              );
                            },
                  ),
                ],
              );
              if (constraints.maxWidth < 400) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: icon,
                      title: title,
                    ),
                    Align(alignment: Alignment.centerRight, child: actions),
                    const SizedBox(height: 12),
                  ],
                );
              }
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: icon,
                title: title,
                trailing: actions,
              );
            },
          ),
      ],
    );
  }
}
