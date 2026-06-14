part of 'music_dialog.dart';

class _LyricsTimestampToggle extends StatelessWidget {
  const _LyricsTimestampToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return SizedBox(
      key: const ValueKey('MusicDialog.LyricsTimestampToggle'),
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              key: const ValueKey('MusicDialog.LyricsTimestampCheckboxBox'),
              dimension: 18,
              child: Checkbox(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
                value: value,
                onChanged:
                    onChanged == null
                        ? null
                        : (value) {
                          onChanged!(value ?? false);
                        },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.smPlayerI18n.t('song.showLyricsTimestamps'),
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation.weight(650)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
