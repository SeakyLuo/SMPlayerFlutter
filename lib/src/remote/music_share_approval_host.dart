import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_i18n.dart';
import '../app/undoable_notification.dart';
import '../library/ui/popup_dialog.dart';
import 'music_share_models.dart';
import 'music_share_permission_selector.dart';
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
  Object? _shownHostFailure;

  @override
  Widget build(BuildContext context) {
    ref.listen(musicShareProvider.select((share) => share.incomingConnection), (
      _,
      event,
    ) {
      if (event == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t('share.deviceConnected', {
            'name': event.name,
          }),
        );
      });
    });
    final share = ref.watch(musicShareProvider);
    final failure = share.hostFailure;
    if (failure != null && !identical(_shownHostFailure, failure)) {
      _shownHostFailure = failure;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t(
            share.backgroundSharing
                ? 'share.backgroundOperationFailed'
                : 'share.sharingStartFailed',
          ),
        );
      });
    }
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
              Row(
                children: [
                  Icon(
                    widget.request.isMobile
                        ? FluentIcons.phone_24_regular
                        : FluentIcons.desktop_24_regular,
                    size: 32,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.request.name,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          i18n.t('share.requestAccessLibrary'),
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      i18n.t('share.accessPermission'),
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  MusicSharePermissionSelector(
                    canWrite: _canWrite,
                    enabled: !_submitting,
                    onChanged: (value) => setState(() => _canWrite = value),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  i18n.t(
                    _canWrite ? 'share.readWriteHint' : 'share.readOnlyHint',
                  ),
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
