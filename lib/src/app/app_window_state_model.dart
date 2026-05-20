import 'dart:convert';

import 'package:flutter/widgets.dart';

Rect? parseMainWindowBounds(String rawBounds) {
  if (rawBounds.isEmpty) {
    return null;
  }
  final value = jsonDecode(rawBounds) as Map<String, dynamic>;
  return Rect.fromLTWH(
    (value['x'] as num).toDouble(),
    (value['y'] as num).toDouble(),
    (value['width'] as num).toDouble(),
    (value['height'] as num).toDouble(),
  );
}

String serializeMainWindowBounds(Rect bounds) {
  return jsonEncode({
    'x': bounds.left,
    'y': bounds.top,
    'width': bounds.width,
    'height': bounds.height,
  });
}
