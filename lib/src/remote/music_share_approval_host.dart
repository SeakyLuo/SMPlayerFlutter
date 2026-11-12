import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_i18n.dart';
import '../library/ui/popup_dialog.dart';
import 'music_share_models.dart';
import 'music_source_providers.dart';
import 'music_source_selector.dart';

class MusicShareApprovalHost extends ConsumerStatefulWidget {
  const MusicShareApprovalHost({super.key});

  @override
  ConsumerState<MusicShareApprovalHost> createState() =>
      _MusicShareApprovalHostState();
}

class _MusicShareApprovalHostState
    extends ConsumerState<MusicShareApprovalHost> {
  var _showing = false;

  @override
  Widget build(BuildContext context) {
    final share = ref.watch(musicShareProvider);
    if (!_showing && share.initialized) {
      final pending =
          share.server.requests.entries
              .where((entry) => entry.value.state == 'pending')
              .firstOrNull;
      if (pending != null) {
        _showing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_ask(pending.key, pending.value));
        });
      }
    }
    return const SizedBox.shrink();
  }

  Future<void> _ask(String requestKey, MusicPairRequest request) async {
    try {
      await showScopedPopupDialog<void>(
        context: context,
        builder:
            (_) => _MusicShareApprovalDialog(
              requestKey: requestKey,
              request: request,
            ),
      );
    } finally {
      if (mounted) setState(() => _showing = false);
    }
  }
}

class _MusicShareApprovalDialog extends ConsumerStatefulWidget {
  const _MusicShareApprovalDialog({
    required this.requestKey,
    required this.request,
  });

  final String requestKey;
  final MusicPairRequest request;

  @override
  ConsumerState<_MusicShareApprovalDialog> createState() =>
      _MusicShareApprovalDialogState();
}

class _MusicShareApprovalDialogState
    extends ConsumerState<_MusicShareApprovalDialog> {
  var _submitting = false;
  var _canWrite = false;
  var _closing = false;

  void _close() {
    if (_closing) return;
    _closing = true;
    final route = ModalRoute.of(context)!;
    final navigator = Navigator.of(context);
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  Future<void> _answer(bool allow) async {
    if (_submitting || _closing) return;
    final share = ref.read(musicShareProvider);
    final request = share.server.requests[widget.requestKey];
    if (request == null ||
        request.state != 'pending' ||
        DateTime.now().isAfter(request.expires)) {
      _close();
      return;
    }
    setState(() => _submitting = true);
    await runMusicShareAction(context, () async {
      await share.approve(widget.requestKey, allow, canWrite: _canWrite);
      if (mounted) _close();
    });
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final share = ref.watch(musicShareProvider);
    final request = share.server.requests[widget.requestKey];
    if (!_submitting && (request == null || request.state != 'pending')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
    }
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    final title = i18n.t('share.connectionRequest');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_submitting && !_closing) unawaited(_answer(false));
      },
      child: PopupDialog(
        navLabel: title,
        navChildren: [Expanded(child: PopupDialogTitle(title))],
        fitContent: true,
        fullScreenOnNarrow: false,
        width: 480,
        canClose: !_submitting,
        onClose: () => unawaited(_answer(false)),
        footer: PopupDialogActions(
          children: [
            PopupDialogActionButton(
              label: i18n.t('share.allow'),
              primary: true,
              loading: _submitting,
              onPressed: _submitting ? null : () => unawaited(_answer(true)),
            ),
            PopupDialogActionButton(
              label: i18n.t('share.reject'),
              onPressed: _submitting ? null : () => unawaited(_answer(false)),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupDialogMessageContent(
                message: i18n.t('share.requestFrom', {
                  'name': widget.request.name,
                }),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              SelectableText(
                widget.request.code,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _canWrite,
                title: Text(
                  i18n.t('share.allowEditing'),
                  style: TextStyle(color: colors.textStrong, fontSize: 14),
                ),
                onChanged:
                    _submitting
                        ? null
                        : (value) => setState(() => _canWrite = value!),
              ),
              PopupDialogMessageContent(
                message: i18n.t('share.approvalHint'),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
