import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../library/ui/popup_dialog.dart';
import 'music_share_connect.dart';

Future<void> showMusicShareDialog(BuildContext context) =>
    showScopedPopupDialog<void>(
      context: context,
      builder: (_) => const _MusicShareDialog(),
    );

class _MusicShareDialog extends StatefulWidget {
  const _MusicShareDialog();

  @override
  State<_MusicShareDialog> createState() => _MusicShareDialogState();
}

class _MusicShareDialogState extends State<_MusicShareDialog> {
  var _closing = false;

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = context.smPlayerI18n.t('share.connectComputer');
    return PopupDialog(
      navLabel: title,
      navChildren: [Expanded(child: PopupDialogTitle(title))],
      width: 600,
      height: 640,
      onClose: _close,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Material(
          type: MaterialType.transparency,
          child: MusicShareConnect(onConnected: _close),
        ),
      ),
    );
  }
}
