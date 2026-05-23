import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

const undoableNotificationDuration = Duration(seconds: 5);
const appNotificationDuration = Duration(seconds: 2);
const _appNotificationRadius = 8.0;

_AppNotificationController? _currentNotification;

Future<SnackBarClosedReason> showUndoableSnackBar({
  required BuildContext context,
  required SmPlayerI18n i18n,
  required String message,
  required FutureOr<void> Function() onUndo,
}) {
  return _showAppOverlayNotification(
    context: context,
    message: message,
    duration: undoableNotificationDuration,
    actionLabel: i18n.t('common.undo'),
    onAction: onUndo,
  );
}

Future<SnackBarClosedReason> showAppNotification({
  required BuildContext context,
  required String message,
  Duration duration = appNotificationDuration,
}) {
  return _showAppOverlayNotification(
    context: context,
    message: message,
    duration: duration,
  );
}

Future<SnackBarClosedReason> _showAppOverlayNotification({
  required BuildContext context,
  required String message,
  required Duration duration,
  String? actionLabel,
  FutureOr<void> Function()? onAction,
}) {
  _currentNotification?.close(SnackBarClosedReason.hide);

  final controller = _AppNotificationController();
  final overlay = Overlay.of(context, rootOverlay: true);
  final hasAction = actionLabel != null;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder:
        (context) => _AppNotificationOverlay(
          message: message,
          actionLabel: actionLabel,
          bottomAligned: hasAction,
          running: controller.running,
          onAction:
              hasAction
                  ? () async {
                    controller.setRunning();
                    await Future<void>.sync(onAction!);
                    controller.close(SnackBarClosedReason.action);
                  }
                  : null,
        ),
  );

  controller.attach(entry);
  _currentNotification = controller;
  overlay.insert(entry);
  controller.startTimer(duration);
  return controller.closed;
}

class _AppNotificationController {
  final closedCompleter = Completer<SnackBarClosedReason>();
  final running = ValueNotifier<bool>(false);
  OverlayEntry? entry;
  Timer? timer;

  Future<SnackBarClosedReason> get closed => closedCompleter.future;

  void attach(OverlayEntry overlayEntry) {
    entry = overlayEntry;
  }

  void startTimer(Duration duration) {
    timer = Timer(duration, () => close(SnackBarClosedReason.timeout));
  }

  void setRunning() {
    timer?.cancel();
    running.value = true;
  }

  void close(SnackBarClosedReason reason) {
    timer?.cancel();
    entry?.remove();
    running.dispose();
    if (_currentNotification == this) {
      _currentNotification = null;
    }
    if (!closedCompleter.isCompleted) {
      closedCompleter.complete(reason);
    }
  }
}

class _AppNotificationOverlay extends StatelessWidget {
  const _AppNotificationOverlay({
    required this.message,
    required this.bottomAligned,
    required this.running,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final bool bottomAligned;
  final ValueListenable<bool> running;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = math.min(680.0, mediaQuery.size.width - 40.0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final notification = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_appNotificationRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.18),
            blurRadius: 58,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.10),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: GlassContainer(
        useOwnLayer: true,
        quality: GlassQuality.standard,
        shape: const LiquidRoundedRectangle(
          borderRadius: _appNotificationRadius,
        ),
        settings: LiquidGlassSettings(
          thickness: 26,
          blur: 32,
          refractiveIndex: 1.1,
          saturation: 1.35,
          chromaticAberration: 0.012,
          lightIntensity: 0.46,
          ambientStrength: 0.18,
          glowIntensity: 0.42,
          glassColor:
              isDark ? const Color(0x54262f3c) : const Color(0x9cf7fbff),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : const Color(0x2e56657a),
            ),
            borderRadius: BorderRadius.circular(_appNotificationRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  isDark
                      ? const [Color(0xb8262f3c), Color(0x9c141b24)]
                      : const [Color(0xe8ffffff), Color(0xcaf6faff)],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              15,
              actionLabel == null ? 22 : 16,
              15,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    message,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          isDark
                              ? const Color(0xffeaf2fb)
                              : const Color(0xff3b4654),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(width: 14),
                  _NotificationActionButton(
                    label: actionLabel!,
                    running: running,
                    onPressed: onAction!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Positioned(
      left: (mediaQuery.size.width - width) / 2,
      top: bottomAligned ? null : 48,
      bottom: bottomAligned ? 138 : null,
      width: width,
      child: SafeArea(
        top: !bottomAligned,
        bottom: bottomAligned,
        child: notification,
      ),
    );
  }
}

class _NotificationActionButton extends StatelessWidget {
  const _NotificationActionButton({
    required this.label,
    required this.running,
    required this.onPressed,
  });

  final String label;
  final ValueListenable<bool> running;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    return ValueListenableBuilder<bool>(
      valueListenable: running,
      builder: (context, isRunning, child) {
        return TextButton(
          onPressed: isRunning ? null : onPressed,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(64, 36)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16),
            ),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)) {
                return accent;
              }
              return isDark
                  ? accent.withValues(alpha: 0.86)
                  : const Color(0xff2d3644);
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)) {
                return isDark
                    ? accent.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.96);
              }
              return isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.82);
            }),
            side: WidgetStateProperty.resolveWith((states) {
              final color =
                  states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? accent.withValues(alpha: 0.24)
                      : isDark
                      ? Colors.white.withValues(alpha: 0.13)
                      : const Color(0x3d788291);
              return BorderSide(color: color);
            }),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          child:
              isRunning
                  ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text(label),
        );
      },
    );
  }
}
