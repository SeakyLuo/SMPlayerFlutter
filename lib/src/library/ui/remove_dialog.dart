import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/popup_dialog.dart';

class RemoveDialog extends StatefulWidget {
  const RemoveDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onCancel,
    required this.onConfirm,
    this.confirmText,
    this.pendingText,
    this.destructive = true,
    this.submitting = false,
  });

  final String title;
  final String message;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String? confirmText;
  final String? pendingText;
  final bool destructive;
  final bool submitting;

  @override
  State<RemoveDialog> createState() => _RemoveDialogState();
}

class _RemoveDialogState extends State<RemoveDialog> {
  final _overlayController = OverlayPortalController(
    debugLabel: 'RemoveDialog',
  );

  @override
  void initState() {
    super.initState();
    _overlayController.show();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: _buildOverlay,
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    final actionLabel =
        widget.submitting
            ? widget.pendingText ??
                widget.confirmText ??
                i18n.t('common.confirm')
            : widget.confirmText ?? i18n.t('common.confirm');

    return Positioned.fill(
      child: FocusScope(
        autofocus: true,
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            label: widget.title,
            namesRoute: true,
            scopesRoute: true,
            explicitChildNodes: true,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(color: colors.overlay),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border),
                            boxShadow: [
                              BoxShadow(
                                color: colors.shadow,
                                blurRadius: 60,
                                offset: const Offset(0, 24),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.textStrong,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  widget.message,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.text,
                                    fontSize: 15,
                                    height: 1.55,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    PopupDialogActionButton(
                                      label: actionLabel,
                                      primary: true,
                                      destructive: widget.destructive,
                                      loading: widget.submitting,
                                      onPressed:
                                          widget.submitting
                                              ? null
                                              : widget.onConfirm,
                                    ),
                                    const SizedBox(width: 18),
                                    PopupDialogActionButton(
                                      label: i18n.t('common.cancel'),
                                      onPressed:
                                          widget.submitting
                                              ? null
                                              : widget.onCancel,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
