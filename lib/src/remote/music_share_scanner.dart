import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app/undoable_notification.dart';
import '../i18n/app_i18n.dart';
import '../library/ui/popup_dialog.dart';
import 'music_share_pair_code.dart';

class MusicShareScanner extends StatefulWidget {
  const MusicShareScanner({
    super.key,
    required this.onScanned,
    required this.onCancel,
  });

  final ValueChanged<MusicSharePairCode> onScanned;
  final VoidCallback onCancel;

  @override
  State<MusicShareScanner> createState() => _MusicShareScannerState();
}

class _MusicShareScannerState extends State<MusicShareScanner> {
  final _seen = <String>{};
  var _finished = false;

  void _detect(BarcodeCapture capture) {
    if (_finished) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || !_seen.add(value)) continue;
      final code = MusicSharePairCode.parse(value);
      if (code == null) {
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t('share.invalidQrCode'),
        );
        continue;
      }
      _finished = true;
      widget.onScanned(code);
      return;
    }
  }

  Widget _cameraError(BuildContext context, MobileScannerException error) {
    if (!_finished) {
      _finished = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showAppNotification(
          context: context,
          message: context.smPlayerI18n.t('share.cameraUnavailable'),
        );
        widget.onCancel();
      });
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(i18n.t('share.scanHint')),
        const SizedBox(height: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(onDetect: _detect, errorBuilder: _cameraError),
          ),
        ),
        const SizedBox(height: 16),
        PopupDialogActionButton(
          onPressed: widget.onCancel,
          label: i18n.t('common.cancel'),
        ),
      ],
    );
  }
}
