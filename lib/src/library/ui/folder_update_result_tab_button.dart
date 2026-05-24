import 'package:flutter/material.dart';

import 'folder_update_result_tab.dart';
import 'local_page_quick_jump.dart';

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
    final foreground =
        selected ? LocalPageColors.accentStrong : LocalPageColors.commandText;
    return SizedBox(
      height: 34,
      child: Material(
        color: selected ? const Color(0x240078d7) : const Color(0xadffffff),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? const Color(0x570078d7) : const Color(0x477e8b9a),
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
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
                  decoration: const ShapeDecoration(
                    color: Color(0x247e8b9a),
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
