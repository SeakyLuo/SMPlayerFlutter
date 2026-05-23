import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';

const localQuickJumpKeys = [
  '#',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];

class LocalContentSection extends StatelessWidget {
  const LocalContentSection({
    super.key,
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: LocalPageColors.textStrong,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onToggle,
            icon: Icon(
              expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
              size: 18,
            ),
            label: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: LocalPageColors.textStrong,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(text: title),
                  TextSpan(
                    text: '  $count',
                    style: const TextStyle(
                      color: LocalPageColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[const SizedBox(height: 14), child],
        ],
      ),
    );
  }
}

class LocalSongQuickJump extends StatelessWidget {
  const LocalSongQuickJump({
    super.key,
    required this.basisName,
    required this.enabledKeys,
    required this.i18n,
    required this.visible,
    required this.onJump,
  });

  final String basisName;
  final Map<String, int> enabledKeys;
  final SmPlayerI18n i18n;
  final bool visible;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: 30,
      child: Column(
        children: [
          Tooltip(
            message: basisName,
            child: const SizedBox(height: 6, width: 30),
          ),
          for (final key in localQuickJumpKeys)
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 26,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(26, 0),
                      foregroundColor:
                          enabledKeys.containsKey(key)
                              ? LocalPageColors.textMuted
                              : LocalPageColors.disabled,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed:
                        enabledKeys.containsKey(key) ? () => onJump(key) : null,
                    child: Text(
                      key,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LocalPageColors {
  const LocalPageColors._();

  static const panel = Color(0xffffffff);
  static const panelBorder = Color(0x29677486);
  static const panelShadow = Color(0x1f1f2a38);
  static const emptyStateSurface = Color(0x94ffffff);
  static const emptyStateBorder = Color(0x94ffffff);
  static const emptyStateArtworkBorder = Color(0x2e768499);
  static const surfaceControl = Color(0x94ffffff);
  static const surfaceControlHover = Color(0x1a0078d7);
  static const borderSubtle = Color(0x2e768499);
  static const surfaceCard = Color(0x00ffffff);
  static const surfaceCardHover = Color(0xffffffff);
  static const rowBorder = Color(0x21727e8c);
  static const rowHover = Color(0x0e0078d7);
  static const rowSelected = Color(0xf5ffffff);
  static const accentStrong = Color(0xff0063b1);
  static const accentSoft = Color(0x1a0078d7);
  static const commandText = Color(0xff1f252b);
  static const textStrong = Color(0xff111827);
  static const textMuted = Color(0xff5b697a);
  static const disabled = Color(0x3d5b697a);
  static const artwork = Color(0xffe8eef5);
  static const artworkIcon = Color(0xff607085);
  static const artworkShadow = Color(0x211f2a38);
  static const cardShadow = Color(0x1f1e2a3a);
  static const favorite = Color(0xffd13438);
  static const selectionMark = Color(0xdfffffff);
  static const selectionBorder = Color(0x55677486);
}
