import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import 'local_page_quick_jump.dart';

class LocalCompactListPanel extends StatelessWidget {
  const LocalCompactListPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border.all(color: colors.borderSubtle),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: colors.panelShadow.withValues(alpha: 0.08),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: colors.panelShadow.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
            spreadRadius: -18,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: ClipRRect(borderRadius: BorderRadius.circular(9), child: child),
      ),
    );
  }
}

class LocalCompactPanelRow extends StatelessWidget {
  const LocalCompactPanelRow({
    super.key,
    required this.last,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.reserveSeparatorSpace = false,
  });

  final bool last;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool reserveSeparatorSpace;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border:
            last
                ? null
                : Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: Padding(
        padding:
            reserveSeparatorSpace && !last
                ? padding.add(const EdgeInsets.only(bottom: 1))
                : padding,
        child: child,
      ),
    );
  }
}

class LocalCheckMark extends StatelessWidget {
  const LocalCheckMark({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    return Center(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: selected ? colors.accentStrong : colors.selectionMark,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected ? colors.accentStrong : colors.selectionBorder,
          ),
        ),
        child:
            selected
                ? const Icon(
                  FluentIcons.checkmark_16_regular,
                  color: Colors.white,
                  size: 14,
                )
                : null,
      ),
    );
  }
}

void invokeAtButtonBottom(BuildContext context, ValueChanged<Offset> action) {
  final box = context.findRenderObject() as RenderBox;
  action(box.localToGlobal(Offset(0, box.size.height + 6)));
}
