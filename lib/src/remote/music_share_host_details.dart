import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/undoable_notification.dart';
import '../i18n/app_i18n.dart';
import '../library/ui/popup_dialog.dart';
import 'music_share_pair_qr.dart';
import 'music_source_providers.dart';

var _connectionInfoOpen = false;

Future<void> showMusicShareConnectionInfo(
  BuildContext context, {
  Rect? Function()? closeTarget,
}) async {
  if (_connectionInfoOpen) return;
  _connectionInfoOpen = true;
  final share = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(musicShareProvider);
  try {
    bool awaitingApproval() => share.server.requests.values.any(
      (request) => request.state == 'pending',
    );
    while (share.server.running && awaitingApproval()) {
      final completed = Completer<void>();
      void changed() {
        if ((!share.server.running || !awaitingApproval()) &&
            !completed.isCompleted) {
          completed.complete();
        }
      }

      share.addListener(changed);
      try {
        await completed.future;
        // Let the approval route finish closing before showing connection info.
        await Future<void>.delayed(popupConfirmDialogDismissDelay);
      } finally {
        share.removeListener(changed);
      }
    }
    if (!context.mounted || !share.server.running) return;
    var closing = false;
    await showScopedPopupDialog<void>(
      context: context,
      builder:
          (dialogContext) => Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(musicShareProvider);
              void close() {
                if (closing) return;
                closing = true;
                final route = ModalRoute.of(dialogContext)!;
                final navigator = Navigator.of(dialogContext);
                if (route.isCurrent) {
                  navigator.pop();
                } else {
                  navigator.removeRoute(route);
                }
              }

              if (!state.server.running) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (dialogContext.mounted) close();
                });
              }
              final title = context.smPlayerI18n.t('share.connectionInfo');
              return PopupDialog(
                navLabel: title,
                navChildren: [Expanded(child: PopupDialogTitle(title))],
                width: 480,
                fitContent: true,
                fullScreenOnNarrow: false,
                onClose: close,
                closeTarget: closeTarget,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: MusicShareHostDetails(),
                ),
              );
            },
          ),
    );
  } finally {
    _connectionInfoOpen = false;
  }
}

class MusicShareHostDetails extends ConsumerStatefulWidget {
  const MusicShareHostDetails({super.key});
  @override
  ConsumerState<MusicShareHostDetails> createState() =>
      _MusicShareHostDetailsState();
}

class _MusicShareHostDetailsState extends ConsumerState<MusicShareHostDetails> {
  List<String> _addresses = [];
  var _loadingAddresses = true;

  @override
  void initState() {
    super.initState();
    final share = ref.read(musicShareProvider);
    unawaited(
      share.ready
          .then((_) async {
            final interfaces = await NetworkInterface.list(
              type: InternetAddressType.IPv4,
            );
            // Prefer physical Wi-Fi/Ethernet interfaces before VPN adapters.
            bool physical(NetworkInterface network) =>
                RegExp(r'^(en|eth|wl)').hasMatch(network.name);
            interfaces.sort(
              (a, b) => (physical(a) ? 0 : 1).compareTo(physical(b) ? 0 : 1),
            );
            if (mounted) {
              setState(() {
                _loadingAddresses = false;
                _addresses = [
                  for (final interface in interfaces)
                    for (final address in interface.addresses) address.address,
                ];
              });
            }
          })
          .catchError((Object error) {
            if (mounted) {
              setState(() => _loadingAddresses = false);
              showAppNotification(
                context: context,
                message: context.smPlayerI18n.t('share.connectionFailed'),
              );
            }
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final share = ref.watch(musicShareProvider);
    if (!share.initialized || _loadingAddresses) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (share.server.running && _addresses.isNotEmpty) ...[
          MusicSharePairQr(
            key: ValueKey(share.port),
            addresses: [
              for (final address in _addresses) '$address:${share.port}',
            ],
            fingerprint: share.identity.fingerprint,
          ),
        ],
      ],
    );
  }
}
