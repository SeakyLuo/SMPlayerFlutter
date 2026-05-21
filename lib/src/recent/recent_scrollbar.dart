import 'package:flutter/material.dart';

class RecentScrollbar extends StatelessWidget {
  const RecentScrollbar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollbarTheme(
      data: ScrollbarTheme.of(context).copyWith(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.hovered)
              ? const Color(0xad435060)
              : const Color(0x805b697a);
        }),
        thickness: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.hovered) ? 7 : 5;
        }),
        radius: const Radius.circular(999),
        crossAxisMargin: 5,
        mainAxisMargin: 0,
      ),
      child: Scrollbar(interactive: true, child: child),
    );
  }
}
