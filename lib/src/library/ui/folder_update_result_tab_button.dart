import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/text_icon_button.dart';

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
    return SmPlayerTextIconButtonTheme(
      colors: SmPlayerTextIconButtonColors(
        commandText: foreground,
        commandTextHover: foreground,
        control: background,
        controlHover: hover,
        controlHoverBorder: border,
        controlActive: background,
        controlBorder: border,
        accentStrong: foreground,
      ),
      child: SmPlayerTextIconButton(
        label: item.label,
        active: selected,
        onPressed: onPressed,
        minWidth: 0,
        height: 34,
        horizontalPadding: 14,
        iconSize: 14,
        iconGap: 6,
        borderRadius: 999,
        icon: item.icon,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
                shape: const StadiumBorder(),
              ),
              child: Text(
                item.count.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
