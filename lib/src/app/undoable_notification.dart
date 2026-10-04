import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ViewFocusEvent, ViewFocusState;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';
import 'package:smplayer_flutter/src/app/notification_diagnostics.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/command_bar_colors.dart';

const undoableNotificationDuration = Duration(seconds: 5);
const appNotificationDuration = Duration(seconds: 2);
const _extendedNotificationDuration = Duration(seconds: 10);
const _appNotificationRadius = 8.0;
const _appNotificationExitDuration = Duration(milliseconds: 180);

_AppNotificationController? _currentNotification;
bool _notificationWindowActive = false;
int _notificationDetailsDepth = 0;
final _notificationPresentation = ValueNotifier<_AppNotificationPresentation?>(
  null,
);

enum AppNotificationClosedReason { hide, action, timeout }

class AppNotificationAction {
  const AppNotificationAction({
    required this.label,
    required this.onPressed,
    this.closeOnPressed = true,
  });

  final String label;
  final FutureOr<void> Function() onPressed;
  final bool closeOnPressed;
}

class AppNotificationDetailsSession {
  AppNotificationDetailsSession() {
    _notificationDetailsDepth += 1;
    _currentNotification?.setPaused(_NotificationPause.details, true);
  }

  void close() {
    _notificationDetailsDepth -= 1;
    if (_notificationDetailsDepth == 0) {
      _currentNotification?.restartTimer();
      _currentNotification?.setPaused(_NotificationPause.details, false);
    }
  }
}

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

Future<AppNotificationClosedReason> showUndoableNotification({
  required BuildContext context,
  required SmPlayerI18n i18n,
  required String message,
  required FutureOr<void> Function() onUndo,
}) {
  return showUndoableAppNotification(
    i18n: i18n,
    message: message,
    onUndo: onUndo,
  );
}

Future<AppNotificationClosedReason> showUndoableAppNotification({
  required SmPlayerI18n i18n,
  required String message,
  required FutureOr<void> Function() onUndo,
}) {
  return _showAppOverlayNotification(
    message: message,
    duration: undoableNotificationDuration,
    actionLabel: i18n.t('common.undo'),
    onAction: onUndo,
  );
}

Future<AppNotificationClosedReason> showAppNotification({
  required BuildContext context,
  required String message,
  Duration duration = appNotificationDuration,
  bool autoDismiss = true,
  String? actionLabel,
  FutureOr<void> Function()? onAction,
  List<AppNotificationAction>? actions,
  bool closeOnAction = true,
}) {
  return _showAppOverlayNotification(
    message: message,
    duration: duration,
    autoDismiss: autoDismiss,
    actionLabel: actionLabel,
    onAction: onAction,
    actions: actions,
    closeOnAction: closeOnAction,
  );
}

void hideAppNotification() {
  _currentNotification?.close(AppNotificationClosedReason.hide);
}

Future<AppNotificationClosedReason> _showAppOverlayNotification({
  required String message,
  required Duration duration,
  bool autoDismiss = true,
  String? actionLabel,
  FutureOr<void> Function()? onAction,
  List<AppNotificationAction>? actions,
  bool closeOnAction = true,
}) {
  _currentNotification?.close(AppNotificationClosedReason.hide);

  _notificationPresentation.value?.controller.removePresentation();

  final controller = _AppNotificationController();
  final resolvedActions =
      actions ??
      (actionLabel == null || onAction == null
          ? const <AppNotificationAction>[]
          : [
            AppNotificationAction(
              label: actionLabel,
              onPressed: onAction,
              closeOnPressed: closeOnAction,
            ),
          ]);
  _notificationPresentation.value = _AppNotificationPresentation(
    controller: controller,
    message: message,
    actions: resolvedActions,
  );

  _currentNotification = controller;
  controller.startTimer(autoDismiss ? duration : _extendedNotificationDuration);
  return controller.closed;
}

class AppNotificationHost extends StatefulWidget {
  const AppNotificationHost({super.key});

  @override
  State<AppNotificationHost> createState() => _AppNotificationHostState();
}

class _AppNotificationHostState extends State<AppNotificationHost>
    with WidgetsBindingObserver {
  final _overlayController = OverlayPortalController(
    debugLabel: 'AppNotificationHost',
  );
  var _showing = false;

  @override
  void initState() {
    super.initState();
    NotificationDiagnostics.attach();
    WidgetsBinding.instance.addObserver(this);
    _setWindowActive(
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
    _notificationPresentation.addListener(_handlePresentationChanged);
  }

  @override
  void dispose() {
    NotificationDiagnostics.detach();
    _notificationPresentation.removeListener(_handlePresentationChanged);
    WidgetsBinding.instance.removeObserver(this);
    _setWindowActive(false);
    super.dispose();
  }

  void _setWindowActive(bool active) {
    NotificationDiagnostics.record('window.active', {'active': active});
    _notificationWindowActive = active;
    _currentNotification?.setPaused(_NotificationPause.window, !active);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _setWindowActive(state == AppLifecycleState.resumed);
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    if (event.viewId != View.of(context).viewId) return;
    _setWindowActive(
      event.state == ViewFocusState.focused &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
  }

  void _handlePresentationChanged() {
    if (_notificationPresentation.value == null) {
      _overlayController.hide();
      _showing = false;
      return;
    }
    if (!_showing) {
      _overlayController.show();
      _showing = true;
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: (context) {
        final presentation = _notificationPresentation.value!;
        final controller = presentation.controller;
        controller.recordFirstFrame();
        return _AppNotificationOverlay(
          key: ObjectKey(controller),
          closing: controller.isClosed,
          onDismissed: controller.removePresentation,
          message: presentation.message,
          actions: presentation.actions,
          bottomAligned: presentation.actions.isNotEmpty,
          runningActionIndex: controller.runningActionIndex,
          onHoverChanged: (hovered) {
            controller.setPaused(_NotificationPause.hover, hovered);
          },
          onDismiss: () {
            controller.close(AppNotificationClosedReason.hide);
          },
          onAction: (actionIndex) async {
            final action = presentation.actions[actionIndex];
            controller.setRunning(actionIndex);
            try {
              await SchedulerBinding.instance.endOfFrame;
              await Future<void>.sync(action.onPressed);
            } finally {
              if (action.closeOnPressed) {
                controller.close(AppNotificationClosedReason.action);
              } else {
                controller.finishAction();
              }
            }
          },
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}

class _AppNotificationPresentation {
  const _AppNotificationPresentation({
    required this.controller,
    required this.message,
    required this.actions,
  });

  final _AppNotificationController controller;
  final String message;
  final List<AppNotificationAction> actions;
}

enum _NotificationPause { window, hover, details, action }

class _AppNotificationController {
  static int _nextDiagnosticId = 0;
  final _diagnosticId = ++_nextDiagnosticId;
  final _diagnosticAge = Stopwatch()..start();
  bool _firstFrameScheduled = false;
  bool _firstFrameSubmitted = false;

  void _diagnose(String event, [Map<String, Object?> data = const {}]) {
    NotificationDiagnostics.record(event, {
      'toast': _diagnosticId,
      'ageMs': _diagnosticAge.elapsedMilliseconds,
      ...data,
    });
  }

  void recordFirstFrame() {
    if (_firstFrameScheduled) return;
    _firstFrameScheduled = true;
    _diagnose('toast.build');
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _diagnose('toast.firstFrameSubmitted', {'closed': isClosed});
      _firstFrameSubmitted = true;
      _startRemainingTimer();
    });
  }

  final closedCompleter = Completer<AppNotificationClosedReason>();
  final runningActionIndex = ValueNotifier<int?>(null);
  Timer? timer;
  Duration _remainingDuration = Duration.zero;
  DateTime? _timeoutAt;
  bool isClosed = false;
  late Duration _duration;
  final _pausedReasons = <_NotificationPause>{
    if (!_notificationWindowActive) _NotificationPause.window,
    if (_notificationDetailsDepth > 0) _NotificationPause.details,
  };

  Future<AppNotificationClosedReason> get closed => closedCompleter.future;

  void startTimer(Duration duration) {
    _diagnose('toast.created', {'durationMs': duration.inMilliseconds});
    _duration = duration;
    _remainingDuration = duration;
  }

  void _startRemainingTimer() {
    timer?.cancel();
    if (isClosed || !_firstFrameSubmitted || _pausedReasons.isNotEmpty) return;
    if (_remainingDuration <= Duration.zero) {
      close(AppNotificationClosedReason.timeout);
      return;
    }
    _timeoutAt = DateTime.now().add(_remainingDuration);
    _diagnose('timer.start', {
      'remainingMs': _remainingDuration.inMilliseconds,
    });
    timer = Timer(
      _remainingDuration,
      () => close(AppNotificationClosedReason.timeout),
    );
  }

  void setPaused(_NotificationPause reason, bool paused) {
    _diagnose('timer.pauseChange', {'reason': reason.name, 'paused': paused});
    if (isClosed) return;
    if (!paused) {
      if (_pausedReasons.remove(reason) && _pausedReasons.isEmpty) {
        _startRemainingTimer();
      }
      return;
    }
    if (!_pausedReasons.add(reason) || _pausedReasons.length != 1) return;
    final timeoutAt = _timeoutAt;
    if (timeoutAt == null) {
      return;
    }
    final remaining = timeoutAt.difference(DateTime.now());
    _remainingDuration = remaining > Duration.zero ? remaining : Duration.zero;
    timer?.cancel();
    timer = null;
    _timeoutAt = null;
  }

  void restartTimer() {
    _diagnose('timer.restart');
    if (isClosed) return;
    _remainingDuration = _duration;
    _timeoutAt = null;
    _startRemainingTimer();
  }

  void setRunning(int actionIndex) {
    setPaused(_NotificationPause.action, true);
    runningActionIndex.value = actionIndex;
  }

  void finishAction() {
    if (isClosed) return;
    runningActionIndex.value = null;
    setPaused(_NotificationPause.action, false);
  }

  void close(AppNotificationClosedReason reason) {
    if (isClosed) {
      return;
    }
    isClosed = true;
    _diagnose('toast.closed', {
      'reason': reason.name,
      'built': _firstFrameScheduled,
      'overdueMs':
          _timeoutAt == null
              ? null
              : DateTime.now().difference(_timeoutAt!).inMilliseconds,
    });
    timer?.cancel();
    _timeoutAt = null;
    if (_notificationPresentation.value?.controller == this) {
      if (_firstFrameSubmitted) {
        final presentation = _notificationPresentation.value!;
        _notificationPresentation.value = _AppNotificationPresentation(
          controller: this,
          message: presentation.message,
          actions: presentation.actions,
        );
      } else {
        removePresentation();
      }
    }
    if (_currentNotification == this) {
      _currentNotification = null;
    }
    if (!closedCompleter.isCompleted) {
      closedCompleter.complete(reason);
    }
  }

  void removePresentation() {
    if (_notificationPresentation.value?.controller == this) {
      _notificationPresentation.value = null;
    }
    runningActionIndex.dispose();
  }
}

class _AppNotificationOverlay extends StatelessWidget {
  const _AppNotificationOverlay({
    super.key,
    required this.closing,
    required this.onDismissed,
    required this.message,
    required this.bottomAligned,
    required this.runningActionIndex,
    required this.actions,
    required this.onHoverChanged,
    required this.onDismiss,
    required this.onAction,
  });

  final String message;
  final bool closing;
  final VoidCallback onDismissed;
  final List<AppNotificationAction> actions;
  final bool bottomAligned;
  final ValueListenable<int?> runningActionIndex;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onDismiss;
  final ValueChanged<int> onAction;

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
        quality: GlassQuality.minimal,
        clipBehavior: Clip.hardEdge,
        shape: const LiquidRoundedRectangle(
          borderRadius: _appNotificationRadius,
        ),
        settings: LiquidGlassSettings(
          thickness: 20,
          blur: 46,
          refractiveIndex: 1.06,
          saturation: 1.65,
          chromaticAberration: 0,
          lightIntensity: 0.1,
          ambientStrength: 0.08,
          glowIntensity: 0.04,
          glassColor: colors.glass,
          standardOpacityMultiplier: 0.24,
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
            padding: EdgeInsets.fromLTRB(22, 15, actions.isEmpty ? 22 : 12, 15),
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
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (index, action) in actions.indexed)
                        _NotificationActionButton(
                          label: action.label,
                          actionIndex: index,
                          runningActionIndex: runningActionIndex,
                          onPressed: () {
                            onAction(index);
                          },
                        ),
                    ],
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
        child: AnimatedOpacity(
          opacity: closing ? 0 : 1,
          duration:
              mediaQuery.disableAnimations
                  ? Duration.zero
                  : _appNotificationExitDuration,
          curve: Curves.easeInCubic,
          onEnd: () {
            if (closing) onDismissed();
          },
          child: IgnorePointer(
            ignoring: closing,
            child: MouseRegion(
              onEnter: (_) {
                onHoverChanged(true);
              },
              onExit: (_) {
                onHoverChanged(false);
              },
              child: GestureDetector(onTap: onDismiss, child: notification),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationActionButton extends StatelessWidget {
  const _NotificationActionButton({
    required this.label,
    required this.actionIndex,
    required this.runningActionIndex,
    required this.onPressed,
  });

  final String label;
  final int actionIndex;
  final ValueListenable<int?> runningActionIndex;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = SmPlayerTextIconButtonColors.of(context).copyWith(
      commandText:
          dark ? CommandBarColors.textNight : CommandBarColors.textStrong,
      commandTextHover:
          dark
              ? CommandBarColors.accentStrongNight
              : CommandBarColors.accentStrong,
      control:
          dark
              ? CommandBarColors.actionNightSurface
              : CommandBarColors.actionSurface,
      controlHover:
          dark
              ? CommandBarColors.actionNightHoverSurface
              : CommandBarColors.actionHoverSurface,
      controlHoverBorder:
          dark
              ? CommandBarColors.actionNightHoverBorder
              : CommandBarColors.actionHoverBorder,
      controlActive: CommandBarColors.accentSoft,
      controlBorder:
          dark
              ? CommandBarColors.actionNightBorder
              : CommandBarColors.actionBorder,
      accentStrong: CommandBarColors.accentStrong,
    );
    return ValueListenableBuilder<int?>(
      valueListenable: runningActionIndex,
      builder: (context, runningIndex, child) {
        final hasRunningAction = runningIndex != null;
        final isRunning = runningIndex == actionIndex;
        return SmPlayerTextIconButtonTheme(
          colors: colors,
          child: SmPlayerTextIconButton(
            label: label,
            loading: isRunning,
            disabled: hasRunningAction && !isRunning,
            minWidth: 64,
            height: 36,
            horizontalPadding: 16,
            borderRadius: 10,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation.weight(720)],
            opacityWhenDisabled: isRunning ? 1 : 0.45,
            onPressed: onPressed,
          ),
        );
      },
    );
  }
}
