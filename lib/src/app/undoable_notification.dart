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

class AppNotificationThemeColors
    extends ThemeExtension<AppNotificationThemeColors> {
  const AppNotificationThemeColors({
    required this.primaryShadow,
    required this.secondaryShadow,
    required this.glass,
    required this.border,
    required this.top,
    required this.bottom,
    required this.text,
    required this.actionForeground,
    required this.actionBackground,
    required this.actionHoverBackground,
    required this.actionBorder,
  });

  final Color primaryShadow;
  final Color secondaryShadow;
  final Color glass;
  final Color border;
  final Color top;
  final Color bottom;
  final Color text;
  final Color actionForeground;
  final Color actionBackground;
  final Color actionHoverBackground;
  final Color actionBorder;

  static final light = AppNotificationThemeColors(
    primaryShadow: Colors.black.withValues(alpha: 0.18),
    secondaryShadow: Colors.black.withValues(alpha: 0.10),
    glass: const Color(0x9cf7fbff),
    border: const Color(0x2e56657a),
    top: const Color(0xe8ffffff),
    bottom: const Color(0xcaf6faff),
    text: const Color(0xff3b4654),
    actionForeground: const Color(0xff2d3644),
    actionBackground: Colors.white.withValues(alpha: 0.82),
    actionHoverBackground: Colors.white.withValues(alpha: 0.96),
    actionBorder: const Color(0x3d788291),
  );

  static final dark = AppNotificationThemeColors(
    primaryShadow: Colors.black.withValues(alpha: 0.42),
    secondaryShadow: Colors.black.withValues(alpha: 0.28),
    glass: const Color(0x54262f3c),
    border: Colors.white.withValues(alpha: 0.14),
    top: const Color(0xb8262f3c),
    bottom: const Color(0x9c141b24),
    text: const Color(0xffeaf2fb),
    actionForeground: Colors.white.withValues(alpha: 0.86),
    actionBackground: Colors.white.withValues(alpha: 0.08),
    actionHoverBackground: const Color(0x2e0078d7),
    actionBorder: Colors.white.withValues(alpha: 0.13),
  );

  static AppNotificationThemeColors of(BuildContext context) {
    return Theme.of(context).extension<AppNotificationThemeColors>()!;
  }

  @override
  AppNotificationThemeColors copyWith() {
    return this;
  }

  @override
  AppNotificationThemeColors lerp(
    ThemeExtension<AppNotificationThemeColors>? other,
    double t,
  ) {
    return t < 0.5 || other is! AppNotificationThemeColors ? this : other;
  }
}

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
  String? actionLabel,
  FutureOr<void> Function()? onAction,
}) {
  return _showAppOverlayNotification(
    context: context,
    message: message,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
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
    final colors = AppNotificationThemeColors.of(context);
    final notification = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_appNotificationRadius),
        boxShadow: [
          BoxShadow(
            color: colors.primaryShadow,
            blurRadius: 58,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: colors.secondaryShadow,
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
          glassColor: colors.glass,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(_appNotificationRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.top, colors.bottom],
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
                      color: colors.text,
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
    final colors = AppNotificationThemeColors.of(context);
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
              return colors.actionForeground;
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)) {
                return colors.actionHoverBackground;
              }
              return colors.actionBackground;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              final color =
                  states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? accent.withValues(alpha: 0.24)
                      : colors.actionBorder;
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
