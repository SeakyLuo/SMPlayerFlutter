import 'dart:math' as math;

import 'package:flutter/widgets.dart';

const _maxFixedRailKeys = 38;

Iterable<String> visibleQuickJumpKeys(
  List<String> keys,
  Set<String> enabledKeys,
) =>
    keys.length > _maxFixedRailKeys && enabledKeys.isNotEmpty
        ? keys.where(enabledKeys.contains)
        : keys;

class QuickJumpRailColumn extends StatelessWidget {
  const QuickJumpRailColumn({
    super.key,
    required this.keys,
    required this.enabledKeys,
    required this.itemBuilder,
  });

  final List<String> keys;
  final Set<String> enabledKeys;
  final Widget Function(String key) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final children =
        visibleQuickJumpKeys(keys, enabledKeys).map(itemBuilder).toList();
    final column = Column(children: children);
    if (keys.length <= _maxFixedRailKeys) return column;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final contentHeight = math.max(height, children.length * 18.0);
        if (height == contentHeight) return column;
        return SingleChildScrollView(
          primary: false,
          child: SizedBox(height: contentHeight, child: column),
        );
      },
    );
  }
}
