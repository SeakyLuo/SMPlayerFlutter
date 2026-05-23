import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final smPlayerWindowDragProvider = Provider<SmPlayerWindowDragCallbacks?>(
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
