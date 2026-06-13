import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';

const mainWindowMinimumSize = Size(
  SmPlayerShellMetrics.mainWindowMinimumWidth,
  SmPlayerShellMetrics.mainWindowMinimumHeight,
);
const defaultMainWindowPreferredSize = Size(1460, 940);

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

Rect resolveInitialMainWindowBounds(
  Rect? savedBounds,
  List<Rect> workAreas, {
  Size minimumSize = mainWindowMinimumSize,
  Size preferredSize = defaultMainWindowPreferredSize,
}) {
  final primaryWorkArea = workAreas.isEmpty ? Rect.zero : workAreas.first;
  if (savedBounds == null) {
    final width = min(preferredSize.width, primaryWorkArea.width).toDouble();
    final height = min(preferredSize.height, primaryWorkArea.height).toDouble();
    return Rect.fromLTWH(
      primaryWorkArea.left + (primaryWorkArea.width - width) / 2,
      primaryWorkArea.top + (primaryWorkArea.height - height) / 2,
      width,
      height,
    );
  }

  return clampMainWindowBounds(
    savedBounds,
    workAreas,
    minimumSize: minimumSize,
  );
}

Rect clampMainWindowBounds(
  Rect bounds,
  List<Rect> workAreas, {
  Size minimumSize = mainWindowMinimumSize,
}) {
  final workArea = _matchingWorkArea(bounds, workAreas);
  final width =
      min(max(bounds.width, minimumSize.width), workArea.width).toDouble();
  final height =
      min(max(bounds.height, minimumSize.height), workArea.height).toDouble();
  return Rect.fromLTWH(
    min(max(bounds.left, workArea.left), workArea.right - width).toDouble(),
    min(max(bounds.top, workArea.top), workArea.bottom - height).toDouble(),
    width,
    height,
  );
}

Rect _matchingWorkArea(Rect bounds, List<Rect> workAreas) {
  if (workAreas.isEmpty) {
    return bounds;
  }
  var selected = workAreas.first;
  var selectedOverlap = -1.0;
  for (final workArea in workAreas) {
    final overlap = _rectOverlapArea(bounds, workArea);
    if (overlap > selectedOverlap) {
      selected = workArea;
      selectedOverlap = overlap;
    }
  }
  return selected;
}

double _rectOverlapArea(Rect left, Rect right) {
  final overlapWidth = max(
    0,
    min(left.right, right.right) - max(left.left, right.left),
  );
  final overlapHeight = max(
    0,
    min(left.bottom, right.bottom) - max(left.top, right.top),
  );
  return overlapWidth.toDouble() * overlapHeight.toDouble();
}
