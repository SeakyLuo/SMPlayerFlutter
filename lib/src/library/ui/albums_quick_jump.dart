part of 'albums_page.dart';

class _AlbumsQuickJump extends StatelessWidget {
  const _AlbumsQuickJump({
    required this.activeKey,
    this.reverse = false,
    required this.enabledKeys,
    required this.i18n,
    required this.onJump,
  });

  final String activeKey;
  final bool reverse;
  final Set<String> enabledKeys;
  final SmPlayerI18n i18n;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final libraryIndex = i18n.libraryIndex;
    final standardOrder = libraryQuickJumpKeys(index: libraryIndex);
    final keys =
        libraryIndex != LibraryIndex.standard && reverse
            ? standardOrder.reversed.toList()
            : standardOrder;
    return Container(
      width: _albumQuickJumpWidth,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 18),
      child: QuickJumpRailColumn(
        keys: keys,
        enabledKeys: enabledKeys,
        itemBuilder: (key) {
          final enabled = enabledKeys.contains(key);
          final active = activeKey == key;
          return Expanded(
            child: Tooltip(
              message: getQuickJumpTooltip(
                key: key,
                enabled: enabled,
                i18n: i18n,
              ),
              child: TextButton(
                key: ValueKey('Albums.QuickJump.$key'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(_albumQuickJumpWidth, 0),
                  foregroundColor:
                      enabled
                          ? active
                              ? _AlbumsColors.quickJumpActiveForeground(
                                brightness,
                              )
                              : _AlbumsColors.quickJumpForeground(brightness)
                          : _AlbumsColors.quickJumpDisabled(brightness),
                  backgroundColor:
                      active
                          ? _AlbumsColors.quickJumpActiveBackground(brightness)
                          : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
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
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
