import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

typedef HoldReleaseActionBuilder =
    Widget Function(BuildContext context, double holdProgress);

class HoldReleaseAction extends StatefulWidget {
  const HoldReleaseAction({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.builder,
    this.onHoldRelease,
    this.holdTooltip,
    this.disabled = false,
    this.holdDuration = const Duration(milliseconds: 200),
    this.triggerHoldOnReady = false,
  });

  final String tooltip;
  final String? holdTooltip;
  final bool disabled;
  final Duration holdDuration;
  final bool triggerHoldOnReady;
  final VoidCallback onPressed;
  final VoidCallback? onHoldRelease;
  final HoldReleaseActionBuilder builder;

  @override
  State<HoldReleaseAction> createState() => _HoldReleaseActionState();
}

class _HoldReleaseActionState extends State<HoldReleaseAction>
    with SingleTickerProviderStateMixin {
  var _holdTriggered = false;
  var _holdReady = false;
  var _suppressTap = false;
  Timer? _holdTimer;
  late final AnimationController _holdController;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );
  }

  @override
  void didUpdateWidget(covariant HoldReleaseAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.holdDuration != oldWidget.holdDuration) {
      _holdController.duration = widget.holdDuration;
    }
    if (widget.disabled || widget.onHoldRelease == null) {
      _resetHold();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _holdController.dispose();
    super.dispose();
  }

  void _startHold() {
    if (widget.disabled || widget.onHoldRelease == null) {
      return;
    }
    _holdTriggered = false;
    _holdReady = false;
    _holdController.forward(from: 0);
    _holdTimer?.cancel();
    _holdTimer = Timer(widget.holdDuration, () {
      if (_holdTriggered) {
        return;
      }
      if (widget.triggerHoldOnReady) {
        _holdTriggered = true;
        _suppressTap = true;
        widget.onHoldRelease?.call();
        _resetHold();
        return;
      }
      _holdReady = true;
      if (mounted) {
        setState(() {});
      }
    });
    setState(() {});
  }

  bool _containsGlobalPosition(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(globalPosition);
    final center = Offset(box.size.width / 2, box.size.height / 2);
    return (local - center).distance <= box.size.shortestSide / 2;
  }

  void _releaseHold(Offset globalPosition) {
    if (widget.onHoldRelease == null) {
      return;
    }
    if (_holdReady && !_holdTriggered) {
      _holdTriggered = true;
      _suppressTap = true;
      if (_containsGlobalPosition(globalPosition)) {
        widget.onHoldRelease?.call();
      }
      _resetHold();
      return;
    }
    if (!_holdTriggered) {
      _resetHold();
      return;
    }
    _holdTimer?.cancel();
    _holdTimer = null;
    setState(() {});
  }

  void _resetHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdController.stop();
    _holdController.value = 0;
    _holdTriggered = false;
    _holdReady = false;
    if (mounted) {
      setState(() {});
    }
  }

  void _handleTap() {
    if (_suppressTap) {
      _suppressTap = false;
      return;
    }
    if (_holdTriggered) {
      _resetHold();
      return;
    }
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final holdActive =
        widget.onHoldRelease != null && _holdController.value > 0;
    return Tooltip(
      message:
          holdActive ? widget.holdTooltip ?? widget.tooltip : widget.tooltip,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _startHold(),
        onPointerUp: (event) => _releaseHold(event.position),
        onPointerCancel: (_) => _resetHold(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.disabled ? null : _handleTap,
          child: AnimatedBuilder(
            animation: _holdController,
            builder: (context, _) {
              return widget.builder(context, _holdController.value);
            },
          ),
        ),
      ),
    );
  }
}

class HoldReleaseProgressPainter extends CustomPainter {
  const HoldReleaseProgressPainter({
    required this.progress,
    required this.color,
    this.strokeScale = 0.07,
  });

  final double progress;
  final Color color;
  final double strokeScale;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = max(2.0, size.shortestSide * strokeScale);
    final arcRect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint =
        Paint()
          ..color = color.withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      arcRect,
      -pi / 2,
      progress.clamp(0, 1) * pi * 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant HoldReleaseProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeScale != strokeScale;
  }
}
