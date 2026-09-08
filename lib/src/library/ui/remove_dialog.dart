import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';

class RemoveDialog extends StatelessWidget {
  const RemoveDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onCancel,
    required this.onConfirm,
    this.confirmText,
    this.pendingText,
    this.content,
    this.destructive = true,
    this.submitting = false,
  });
  final String title;
  final String message;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String? confirmText;
  final String? pendingText;
  final Widget? content;
  final bool destructive;
  final bool submitting;
  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final actionLabel =
        submitting
            ? pendingText ?? confirmText ?? i18n.t('common.confirm')
            : confirmText ?? i18n.t('common.confirm');
    return PopupDialog(
      navLabel: title,
      navChildren: [Expanded(child: PopupDialogTitle(title))],
      width: 480,
      fitContent: true,
      fullScreenOnNarrow: false,
      canClose: !submitting,
      onClose: onCancel,
      footer: PopupDialogActions(
        children: [
          PopupDialogActionButton(
            label: actionLabel,
            primary: true,
            destructive: destructive,
            loading: submitting,
            onPressed: submitting ? null : onConfirm,
          ),
          PopupDialogActionButton(
            label: i18n.t('common.cancel'),
            onPressed: submitting ? null : onCancel,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
        child:
            content ??
            PopupDialogMessageContent(
              message: message,
              padding: EdgeInsets.zero,
            ),
      ),
    );
  }
}
