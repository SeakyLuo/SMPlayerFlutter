import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const touchContextMenuDelay = Duration(milliseconds: 650);
const touchContextMenuMoveTolerance = 10.0;

var _pendingTouchContextMenuInvocation = false;
var _dispatchingSyntheticContextMenu = false;
var _lastPointerDeviceKind = PointerDeviceKind.mouse;

bool get usesTouchMenuDensity =>
    _lastPointerDeviceKind == PointerDeviceKind.touch;

bool takeTouchContextMenuInvocation() {
  final pending = _pendingTouchContextMenuInvocation;
  _pendingTouchContextMenuInvocation = false;
  return pending;
}

class TouchContextMenuAdapter extends StatefulWidget {
  const TouchContextMenuAdapter({super.key, required this.child});

  final Widget child;

  @override
  State<TouchContextMenuAdapter> createState() =>
      _TouchContextMenuAdapterState();
}

class _TouchContextMenuAdapterState extends State<TouchContextMenuAdapter> {
  _PendingTouchContextMenu? _pendingMenu;
  var _syntheticPointer = 0x5a000000;

  @override
  void dispose() {
    _clearPendingMenu();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_dispatchingSyntheticContextMenu) {
      _lastPointerDeviceKind = event.kind;
      _pendingTouchContextMenuInvocation = false;
    }
    if (event.kind != PointerDeviceKind.touch ||
        event.buttons != kPrimaryButton) {
      return;
    }

    _clearPendingMenu();
    late final Timer timer;
    timer = Timer(touchContextMenuDelay, () {
      _openContextMenu(event.pointer);
    });
    _pendingMenu = _PendingTouchContextMenu(
      pointer: event.pointer,
      position: event.position,
      timer: timer,
    );
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final pendingMenu = _pendingMenu;
    if (pendingMenu == null || event.pointer != pendingMenu.pointer) {
      return;
    }

    if ((event.position - pendingMenu.position).distance >
        touchContextMenuMoveTolerance) {
      _clearPendingMenu();
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    final pendingMenu = _pendingMenu;
    if (pendingMenu != null && event.pointer == pendingMenu.pointer) {
      _clearPendingMenu();
    }
  }

  void _openContextMenu(int touchPointer) {
    final pendingMenu = _pendingMenu;
    if (pendingMenu == null || pendingMenu.pointer != touchPointer) {
      return;
    }

    _pendingMenu = null;
    final binding = GestureBinding.instance;
    binding.handlePointerEvent(
      PointerCancelEvent(
        pointer: pendingMenu.pointer,
        position: pendingMenu.position,
        kind: PointerDeviceKind.touch,
      ),
    );

    _pendingTouchContextMenuInvocation = true;
    _dispatchingSyntheticContextMenu = true;
    try {
      final pointer = _syntheticPointer++;
      binding.handlePointerEvent(
        PointerDownEvent(
          pointer: pointer,
          position: pendingMenu.position,
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        ),
      );
      binding.handlePointerEvent(
        PointerUpEvent(
          pointer: pointer,
          position: pendingMenu.position,
          kind: PointerDeviceKind.mouse,
          buttons: 0,
        ),
      );
    } finally {
      _dispatchingSyntheticContextMenu = false;
    }
  }

  void _clearPendingMenu() {
    _pendingMenu?.timer.cancel();
    _pendingMenu = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: widget.child,
    );
  }
}

class _PendingTouchContextMenu {
  const _PendingTouchContextMenu({
    required this.pointer,
    required this.position,
    required this.timer,
  });

  final int pointer;
  final Offset position;
  final Timer timer;
}
