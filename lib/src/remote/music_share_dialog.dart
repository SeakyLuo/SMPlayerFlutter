import 'dart:io';

import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../library/ui/popup_dialog.dart';
import 'music_share_connect.dart';

Future<void> showMusicShareDialog(BuildContext context) {
  var closing = false;
  return showScopedPopupDialog<void>(
    context: context,
    builder: (dialogContext) {
      void close() {
        if (closing) return;
        closing = true;
        Navigator.of(dialogContext).pop();
      }

      final title = context.smPlayerI18n.t('share.connectComputer');
      return PopupDialog(
        navLabel: title,
        navChildren: [Expanded(child: PopupDialogTitle(title))],
        width: 520,
        height: 440,
        fullScreenOnNarrow: Platform.isAndroid || Platform.isIOS,
        onClose: close,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Material(
            type: MaterialType.transparency,
            child: MusicShareConnect(onConnected: close),
          ),
        ),
      );
    },
  );
}
