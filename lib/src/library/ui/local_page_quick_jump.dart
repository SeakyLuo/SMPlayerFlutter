import 'package:flutter/material.dart';

import '../../app/app_interaction_colors.dart';
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
    this.compact = false,
  });

  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final headerHeight = dark ? 38.0 : 30.0;
    final headerRadius = dark ? 999.0 : 8.0;
    final headerPadding =
        dark
            ? const EdgeInsets.symmetric(horizontal: 16)
            : const EdgeInsets.symmetric(horizontal: 8);
    final headerForeground =
        dark && expanded ? colors.accentStrong : colors.textStrong;
    final headerFontSize = dark || compact ? 15.0 : 16.0;
    final countForeground =
        dark ? headerForeground.withValues(alpha: 0.72) : colors.textMuted;
    final borderRadius = BorderRadius.circular(headerRadius);
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 14 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 0),
            child: Semantics(
              button: true,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onToggle,
                  borderRadius: borderRadius,
                  hoverColor: dark ? const Color(0x09ffffff) : null,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Container(
                    height: headerHeight,
                    padding: headerPadding,
                    decoration: BoxDecoration(
                      color:
                          dark
                              ? expanded
                                  ? const Color(0x3d0078d7)
                                  : const Color(0x09ffffff)
                              : Colors.transparent,
                      border:
                          dark
                              ? Border.all(
                                color:
                                    expanded
                                        ? const Color(0x7a0078d7)
                                        : const Color(0x38d6e0ec),
                              )
                              : null,
                      borderRadius: borderRadius,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (!dark) ...[
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_down
                                : Icons.chevron_right,
                            size: 15,
                            color: headerForeground,
                          ),
                          const SizedBox(width: 7),
                        ],
                        Text(
                          title,
                          textHeightBehavior: const TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                          ),
                          style: TextStyle(
                            color: headerForeground,
                            fontSize: headerFontSize,
                            fontWeight: FontWeight.w700,
                            fontVariations: const [FontVariation.weight(760)],
                            height: 1,
                          ),
                        ),
                        SizedBox(width: dark ? 8 : 7),
                        Text(
                          '$count',
                          textHeightBehavior: const TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                          ),
                          style: TextStyle(
                            color: countForeground,
                            fontSize: headerFontSize,
                            fontWeight:
                                dark ? FontWeight.w600 : FontWeight.w500,
                            fontVariations: [
                              FontVariation.weight(dark ? 650 : 560),
                            ],
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (expanded) ...[SizedBox(height: compact ? 8 : 14), child],
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
    this.axis = Axis.vertical,
    this.compact = false,
  });

  final String basisName;
  final Map<String, int> enabledKeys;
  final SmPlayerI18n i18n;
  final bool visible;
  final ValueChanged<String> onJump;
  final Axis axis;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    final colors = LocalPageColors.of(context);

    if (axis == Axis.horizontal) {
      return SizedBox(
        height: 22,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final key in localQuickJumpKeys)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: _quickJumpButton(context, key, colors),
                ),
              ),
          ],
        ),
      );
    }

    final width = compact ? 22.0 : 30.0;
    final buttonWidth = compact ? 20.0 : 26.0;
    return Tooltip(
      message: basisName,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            children: [
              for (var index = 0; index < localQuickJumpKeys.length; index += 1)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: index == localQuickJumpKeys.length - 1 ? 0 : 1,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: buttonWidth,
                        height: double.infinity,
                        child: _quickJumpButton(
                          context,
                          localQuickJumpKeys[index],
                          colors,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickJumpButton(
    BuildContext context,
    String key,
    LocalPageColors colors,
  ) {
    final enabled = enabledKeys.containsKey(key);
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: axis == Axis.horizontal ? const Size(22, 22) : Size.zero,
        foregroundColor: enabled ? colors.textMuted : colors.disabled,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: enabled ? () => onJump(key) : null,
      child: Text(
        key,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class LocalPageColors extends ThemeExtension<LocalPageColors> {
  const LocalPageColors({
    required this.panel,
    required this.panelBorder,
    required this.panelShadow,
    required this.emptyStateSurface,
    required this.emptyStateBorder,
    required this.emptyStateArtworkBorder,
    required this.surfaceControl,
    required this.surfaceControlHover,
    required this.borderSubtle,
    required this.surfaceCard,
    required this.surfaceCardHover,
    required this.rowBorder,
    required this.rowHover,
    required this.rowSelected,
    required this.accentStrong,
    required this.accentSoft,
    required this.commandText,
    required this.textStrong,
    required this.textMuted,
    required this.disabled,
    required this.artwork,
    required this.artworkIcon,
    required this.artworkShadow,
    required this.cardShadow,
    required this.favorite,
    required this.selectionMark,
    required this.selectionBorder,
  });

  final Color panel;
  final Color panelBorder;
  final Color panelShadow;
  final Color emptyStateSurface;
  final Color emptyStateBorder;
  final Color emptyStateArtworkBorder;
  final Color surfaceControl;
  final Color surfaceControlHover;
  final Color borderSubtle;
  final Color surfaceCard;
  final Color surfaceCardHover;
  final Color rowBorder;
  final Color rowHover;
  final Color rowSelected;
  final Color accentStrong;
  final Color accentSoft;
  final Color commandText;
  final Color textStrong;
  final Color textMuted;
  final Color disabled;
  final Color artwork;
  final Color artworkIcon;
  final Color artworkShadow;
  final Color cardShadow;
  final Color favorite;
  final Color selectionMark;
  final Color selectionBorder;

  static const day = LocalPageColors(
    panel: Color(0xffffffff),
    panelBorder: Color(0x29677486),
    panelShadow: Color(0x1f1f2a38),
    emptyStateSurface: Color(0x94ffffff),
    emptyStateBorder: Color(0x94ffffff),
    emptyStateArtworkBorder: Color(0x2e768499),
    surfaceControl: Color(0x94ffffff),
    surfaceControlHover: Color(0x1a0078d7),
    borderSubtle: Color(0x2e768499),
    surfaceCard: Color(0x00ffffff),
    surfaceCardHover: GlobalUI.hoverBgColorDay,
    rowBorder: Color(0x21727e8c),
    rowHover: Color(0x0e0078d7),
    rowSelected: GlobalUI.selectedBgColorDay,
    accentStrong: Color(0xff0063b1),
    accentSoft: Color(0x1a0078d7),
    commandText: Color(0xff1f252b),
    textStrong: Color(0xff111827),
    textMuted: Color(0xff5b697a),
    disabled: Color(0x3d5b697a),
    artwork: Color(0xffe8eef5),
    artworkIcon: Color(0xff607085),
    artworkShadow: Color(0x211f2a38),
    cardShadow: Color(0x1f1e2a3a),
    favorite: Color(0xffd13438),
    selectionMark: Color(0xdfffffff),
    selectionBorder: Color(0x55677486),
  );

  static const night = LocalPageColors(
    panel: Color(0xf0161c24),
    panelBorder: Color(0x24d6e0ec),
    panelShadow: Color(0x66000000),
    emptyStateSurface: Color(0x141e2835),
    emptyStateBorder: Color(0x24d6e0ec),
    emptyStateArtworkBorder: Color(0x24d6e0ec),
    surfaceControl: Color(0x12ffffff),
    surfaceControlHover: Color(0x2e0078d7),
    borderSubtle: Color(0x38d6e0ec),
    surfaceCard: Color(0x00ffffff),
    surfaceCardHover: GlobalUI.hoverBgColorNight,
    rowBorder: Color(0x24d6e0ec),
    rowHover: Color(0x2e0078d7),
    rowSelected: GlobalUI.selectedBgColorNight,
    accentStrong: Color(0xff7ab7ff),
    accentSoft: Color(0x2e0078d7),
    commandText: Color(0xffe8edf5),
    textStrong: Color(0xffe8edf5),
    textMuted: Color(0xffcbd5e1),
    disabled: Color(0x40dee7f2),
    artwork: Color(0xff1f2732),
    artworkIcon: Color(0xffcbd5e1),
    artworkShadow: Color(0x57000000),
    cardShadow: Color(0x57000000),
    favorite: Color(0xffff7a7e),
    selectionMark: Color(0xe6ffffff),
    selectionBorder: Color(0x47d6e0ec),
  );

  static LocalPageColors of(BuildContext context) {
    return Theme.of(context).extension<LocalPageColors>()!;
  }

  @override
  LocalPageColors copyWith({
    Color? panel,
    Color? panelBorder,
    Color? panelShadow,
    Color? emptyStateSurface,
    Color? emptyStateBorder,
    Color? emptyStateArtworkBorder,
    Color? surfaceControl,
    Color? surfaceControlHover,
    Color? borderSubtle,
    Color? surfaceCard,
    Color? surfaceCardHover,
    Color? rowBorder,
    Color? rowHover,
    Color? rowSelected,
    Color? accentStrong,
    Color? accentSoft,
    Color? commandText,
    Color? textStrong,
    Color? textMuted,
    Color? disabled,
    Color? artwork,
    Color? artworkIcon,
    Color? artworkShadow,
    Color? cardShadow,
    Color? favorite,
    Color? selectionMark,
    Color? selectionBorder,
  }) {
    return LocalPageColors(
      panel: panel ?? this.panel,
      panelBorder: panelBorder ?? this.panelBorder,
      panelShadow: panelShadow ?? this.panelShadow,
      emptyStateSurface: emptyStateSurface ?? this.emptyStateSurface,
      emptyStateBorder: emptyStateBorder ?? this.emptyStateBorder,
      emptyStateArtworkBorder:
          emptyStateArtworkBorder ?? this.emptyStateArtworkBorder,
      surfaceControl: surfaceControl ?? this.surfaceControl,
      surfaceControlHover: surfaceControlHover ?? this.surfaceControlHover,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceCardHover: surfaceCardHover ?? this.surfaceCardHover,
      rowBorder: rowBorder ?? this.rowBorder,
      rowHover: rowHover ?? this.rowHover,
      rowSelected: rowSelected ?? this.rowSelected,
      accentStrong: accentStrong ?? this.accentStrong,
      accentSoft: accentSoft ?? this.accentSoft,
      commandText: commandText ?? this.commandText,
      textStrong: textStrong ?? this.textStrong,
      textMuted: textMuted ?? this.textMuted,
      disabled: disabled ?? this.disabled,
      artwork: artwork ?? this.artwork,
      artworkIcon: artworkIcon ?? this.artworkIcon,
      artworkShadow: artworkShadow ?? this.artworkShadow,
      cardShadow: cardShadow ?? this.cardShadow,
      favorite: favorite ?? this.favorite,
      selectionMark: selectionMark ?? this.selectionMark,
      selectionBorder: selectionBorder ?? this.selectionBorder,
    );
  }

  @override
  LocalPageColors lerp(ThemeExtension<LocalPageColors>? other, double t) {
    if (other is! LocalPageColors) {
      return this;
    }
    return LocalPageColors(
      panel: Color.lerp(panel, other.panel, t)!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      panelShadow: Color.lerp(panelShadow, other.panelShadow, t)!,
      emptyStateSurface:
          Color.lerp(emptyStateSurface, other.emptyStateSurface, t)!,
      emptyStateBorder:
          Color.lerp(emptyStateBorder, other.emptyStateBorder, t)!,
      emptyStateArtworkBorder:
          Color.lerp(
            emptyStateArtworkBorder,
            other.emptyStateArtworkBorder,
            t,
          )!,
      surfaceControl: Color.lerp(surfaceControl, other.surfaceControl, t)!,
      surfaceControlHover:
          Color.lerp(surfaceControlHover, other.surfaceControlHover, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceCardHover:
          Color.lerp(surfaceCardHover, other.surfaceCardHover, t)!,
      rowBorder: Color.lerp(rowBorder, other.rowBorder, t)!,
      rowHover: Color.lerp(rowHover, other.rowHover, t)!,
      rowSelected: Color.lerp(rowSelected, other.rowSelected, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      commandText: Color.lerp(commandText, other.commandText, t)!,
      textStrong: Color.lerp(textStrong, other.textStrong, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      artwork: Color.lerp(artwork, other.artwork, t)!,
      artworkIcon: Color.lerp(artworkIcon, other.artworkIcon, t)!,
      artworkShadow: Color.lerp(artworkShadow, other.artworkShadow, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      favorite: Color.lerp(favorite, other.favorite, t)!,
      selectionMark: Color.lerp(selectionMark, other.selectionMark, t)!,
      selectionBorder: Color.lerp(selectionBorder, other.selectionBorder, t)!,
    );
  }
}
