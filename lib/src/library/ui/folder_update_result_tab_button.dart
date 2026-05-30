import 'package:flutter/material.dart';

import 'folder_update_result_tab.dart';
import 'popup_dialog.dart';

class FolderUpdateResultTabButton extends StatelessWidget {
  const FolderUpdateResultTabButton({
    super.key,
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final FolderUpdateResultTabItem item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    final foreground = selected ? colors.accentStrong : colors.text;
    final background =
        selected
            ? colors.accent.withValues(alpha: nightMode ? 0.22 : 0.14)
            : Colors.white.withValues(alpha: nightMode ? 0.06 : 0.68);
    final border =
        selected
            ? colors.accent.withValues(alpha: nightMode ? 0.42 : 0.34)
            : colors.buttonBorder;
    final hover = colors.accent.withValues(alpha: nightMode ? 0.18 : 0.10);
    return SizedBox(
      height: 34,
      child: Material(
        color: background,
        shape: StadiumBorder(side: BorderSide(color: border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          hoverColor: hover,
          focusColor: hover,
          splashColor: hover,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 14, color: foreground),
                const SizedBox(width: 6),
                Text(
                  item.label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  height: 22,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: ShapeDecoration(
                    color:
                        nightMode
                            ? Colors.white.withValues(alpha: 0.10)
                            : const Color(0x247e8b9a),
                    shape: StadiumBorder(),
                  ),
                  child: Text(
                    item.count.toString(),
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
