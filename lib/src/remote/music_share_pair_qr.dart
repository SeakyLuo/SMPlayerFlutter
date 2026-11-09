import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../i18n/app_i18n.dart';
import 'music_share_pair_code.dart';

class MusicSharePairQr extends StatefulWidget {
  const MusicSharePairQr({
    super.key,
    required this.addresses,
    required this.fingerprint,
  });

  final List<String> addresses;
  final String fingerprint;

  @override
  State<MusicSharePairQr> createState() => _MusicSharePairQrState();
}

class _MusicSharePairQrState extends State<MusicSharePairQr> {
  late String _address = widget.addresses.first;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: QrImageView(
            data:
                MusicSharePairCode(
                  'https://$_address',
                  widget.fingerprint,
                ).encode(),
            size: 184,
            padding: const EdgeInsets.all(12),
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(i18n.t('share.qrConnectHint'), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        if (widget.addresses.length > 1)
          DropdownButtonFormField<String>(
            initialValue: _address,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: i18n.t('share.networkAddress'),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final address in widget.addresses)
                DropdownMenuItem(value: address, child: Text(address)),
            ],
            onChanged: (address) => setState(() => _address = address!),
          )
        else
          SelectableText(_address),
      ],
    );
  }
}
