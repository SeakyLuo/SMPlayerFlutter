import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final smPlayerWindowDragProvider = Provider<SmPlayerWindowDragCallbacks?>(
  (ref) => null,
);

final smPlayerWindowControlsProvider = Provider<SmPlayerWindowControls?>(
  (ref) => null,
);

class SmPlayerWindowDragCallbacks {
  const SmPlayerWindowDragCallbacks({
    required this.onStart,
    required this.onEnd,
  });

  final VoidCallback onStart;
  final VoidCallback onEnd;
}

class SmPlayerWindowControls {
  const SmPlayerWindowControls({
    required this.isMaximized,
    required this.light,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onClose,
  });

  final bool isMaximized;
  final bool light;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback onClose;
}
