import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/undoable_notification.dart';
import '../i18n/app_i18n.dart';
import 'music_share_pair_qr.dart';
import 'music_source_providers.dart';

class MusicShareHostDetails extends ConsumerStatefulWidget {
  const MusicShareHostDetails({super.key});
  @override
  ConsumerState<MusicShareHostDetails> createState() =>
      _MusicShareHostDetailsState();
}

class _MusicShareHostDetailsState extends ConsumerState<MusicShareHostDetails> {
  List<String> _addresses = [];

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
              setState(
                () =>
                    _addresses = [
                      for (final interface in interfaces)
                        for (final address in interface.addresses)
                          address.address,
                    ],
              );
            }
          })
          .catchError((Object error) {
            if (mounted) {
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
    if (!share.initialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (share.server.running && _addresses.isNotEmpty) ...[
          const SizedBox(height: 16),
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
