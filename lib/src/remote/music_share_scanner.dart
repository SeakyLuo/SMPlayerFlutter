import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app/undoable_notification.dart';
import '../i18n/app_i18n.dart';
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

class _MusicShareScannerState extends State<MusicShareScanner>
    with SingleTickerProviderStateMixin {
  late final _scanLine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
    value: 0.5,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _scanLine.stop();
      _scanLine.value = 0.5;
    } else if (!_scanLine.isAnimating) {
      _scanLine.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _scanLine.dispose();
    super.dispose();
  }

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: BackButton(color: Colors.white, onPressed: widget.onCancel),
          title: Text(
            context.smPlayerI18n.t('share.scanToConnect'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final side = math.min(248.0, size.shortestSide * 0.74);
            final scanWindow = Rect.fromCenter(
              center: Offset(size.width / 2, size.height / 2),
              width: side,
              height: side,
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  scanWindow: scanWindow,
                  onDetect: _detect,
                  errorBuilder: _cameraError,
                  placeholderBuilder:
                      (_) => const ColoredBox(color: Colors.black),
                ),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _ScanFramePainter(scanWindow, _scanLine),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  _ScanFramePainter(this.scanWindow, this.animation)
    : super(repaint: animation);
  final Rect scanWindow;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(
      scanWindow,
      const Radius.circular(24),
    );
    final mask =
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size)
          ..addRRect(frame);
    canvas.drawPath(mask, Paint()..color = const Color(0x99000000));
    canvas.drawRRect(
      frame,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final y = scanWindow.top + 12 + (scanWindow.height - 24) * animation.value;
    final start = Offset(scanWindow.left + 12, y);
    final end = Offset(scanWindow.right - 12, y);
    canvas.save();
    canvas.clipRRect(frame);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = const Color(0x9900DDF4)
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = const Color(0xff00ddf4)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) =>
      scanWindow != oldDelegate.scanWindow ||
      animation != oldDelegate.animation;
}
