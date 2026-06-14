part of 'artists_page.dart';

class _ArtistQuickJump extends StatelessWidget {
  const _ArtistQuickJump({
    required this.activeKey,
    required this.keys,
    required this.enabledKeys,
    required this.i18n,
    required this.onJump,
  });

  final String activeKey;
  final List<String> keys;
  final Set<String> enabledKeys;
  final SmPlayerI18n i18n;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      width: 22,
      child: Column(
        children:
            keys.map((key) {
              final enabled = enabledKeys.contains(key);
              final active = activeKey == key;
              return Expanded(
                child: Opacity(
                  key: ValueKey('Artists.QuickJump.Opacity.$key'),
                  opacity: enabled ? 1 : 0.62,
                  child: Tooltip(
                    message: getQuickJumpTooltip(
                      key: key,
                      enabled: enabled,
                      targetName: i18n.t('common.artists'),
                      basisName: i18n.t('common.artist'),
                      i18n: i18n,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 20,
                        height: double.infinity,
                        child: TextButton(
                          key: ValueKey('Artists.QuickJump.$key'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(20, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ).copyWith(
                            foregroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (!enabled ||
                                  states.contains(WidgetState.disabled)) {
                                return _ArtistsColors.quickJumpDisabled(
                                  brightness,
                                );
                              }
                              if (active ||
                                  states.contains(WidgetState.hovered)) {
                                return _ArtistsColors.quickJumpActiveForeground(
                                  brightness,
                                );
                              }
                              return _ArtistsColors.quickJumpForeground(
                                brightness,
                              );
                            }),
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (!enabled ||
                                  states.contains(WidgetState.disabled)) {
                                return Colors.transparent;
                              }
                              if (active ||
                                  states.contains(WidgetState.hovered)) {
                                return _ArtistsColors.quickJumpActiveBackground(
                                  brightness,
                                );
                              }
                              return Colors.transparent;
                            }),
                          ),
                          onPressed:
                              enabled
                                  ? () {
                                    onJump(key);
                                  }
                                  : null,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              key,
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontSize: 10,
                                height: 1,
                                fontWeight: FontWeight.w600,
                                fontVariations: [FontVariation.weight(650)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}
