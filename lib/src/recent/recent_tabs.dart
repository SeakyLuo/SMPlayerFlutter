part of 'recent_page.dart';

SmPlayerTextIconButtonColors _recentTabButtonColors({
  required Color commandText,
  required Color commandTextHover,
  required Color control,
  required Color controlHover,
  required Color controlBorder,
  required Color controlHoverBorder,
  required Color controlActive,
  required Color accentStrong,
}) {
  return SmPlayerTextIconButtonColors(
    commandText: commandText,
    commandTextHover: commandTextHover,
    control: control,
    controlHover: controlHover,
    controlHoverBorder: controlHoverBorder,
    controlActive: controlActive,
    controlBorder: controlBorder,
    accentStrong: accentStrong,
  );
}

class _RecentTabContent extends StatelessWidget {
  const _RecentTabContent({
    required this.label,
    required this.count,
    required this.showCount,
    required this.labelStyle,
    required this.countStyle,
  });

  final String label;
  final int count;
  final bool showCount;
  final TextStyle labelStyle;
  final TextStyle countStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 7,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        if (showCount)
          Text(
            count.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: countStyle,
          ),
      ],
    );
  }
}
