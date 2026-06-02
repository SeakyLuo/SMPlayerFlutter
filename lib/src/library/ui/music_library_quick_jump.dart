part of 'music_library_page.dart';

class _QuickJumpRail extends StatelessWidget {
  const _QuickJumpRail({
    required this.activeKey,
    required this.keys,
    required this.enabledKeys,
    required this.targetName,
    required this.basisName,
    required this.i18n,
    required this.onJump,
  });

  final String activeKey;
  final List<String> keys;
  final Set<String> enabledKeys;
  final String targetName;
  final String basisName;
  final SmPlayerI18n i18n;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryPalette.of(context);
    return Container(
      width: 58,
      padding: const EdgeInsets.fromLTRB(10, 42, 16, 16),
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border(right: BorderSide(color: colors.quickJumpBorder)),
      ),
      child: Column(
        children:
            keys.map((key) {
              final enabled = enabledKeys.contains(key);
              final active = activeKey == key;
              return Expanded(
                child: Center(
                  child: SizedBox(
                    width: 22,
                    child: Tooltip(
                      message: getQuickJumpTooltip(
                        key: key,
                        enabled: enabled,
                        targetName: targetName,
                        basisName: basisName,
                        i18n: i18n,
                      ),
                      child: TextButton(
                        key: ValueKey('MusicLibrary.QuickJumpRail.$key'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(22, 0),
                          foregroundColor:
                              enabled
                                  ? active
                                      ? colors.accentStrong
                                      : colors.textMuted
                                  : colors.disabled,
                          backgroundColor:
                              active ? colors.accentSoft : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed:
                            enabled
                                ? () {
                                  onJump(key);
                                }
                                : null,
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
              );
            }).toList(),
      ),
    );
  }
}

class _QuickJumpPanel extends StatelessWidget {
  const _QuickJumpPanel({
    required this.activeKey,
    required this.keys,
    required this.enabledKeys,
    required this.targetName,
    required this.basisName,
    required this.i18n,
    required this.underWorkspaceAppBar,
    required this.onJump,
  });

  final String activeKey;
  final List<String> keys;
  final Set<String> enabledKeys;
  final String targetName;
  final String basisName;
  final SmPlayerI18n i18n;
  final bool underWorkspaceAppBar;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    final topPadding = underWorkspaceAppBar ? 10.0 : 50.0;
    final colors = _LibraryQuickJumpPanelColors.of(context);
    return Positioned(
      key: const ValueKey('MusicLibrary.QuickJumpPanel'),
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.panel,
                boxShadow: [
                  BoxShadow(
                    color: colors.panelShadow,
                    offset: Offset(0, 18),
                    blurRadius: 36,
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, topPadding, 18, 18),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 50,
                            mainAxisExtent: 40,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      children:
                          keys.map((key) {
                            final enabled = enabledKeys.contains(key);
                            final active = activeKey == key;
                            return Tooltip(
                              message: getQuickJumpTooltip(
                                key: key,
                                enabled: enabled,
                                targetName: targetName,
                                basisName: basisName,
                                i18n: i18n,
                              ),
                              child: TextButton(
                                key: ValueKey(
                                  'MusicLibrary.QuickJumpPanel.$key',
                                ),
                                style: ButtonStyle(
                                  padding: const WidgetStatePropertyAll(
                                    EdgeInsets.zero,
                                  ),
                                  minimumSize: const WidgetStatePropertyAll(
                                    Size(42, 40),
                                  ),
                                  foregroundColor:
                                      WidgetStateProperty.resolveWith((states) {
                                        if (!enabled) {
                                          return colors.disabledText;
                                        }
                                        if (active ||
                                            states.contains(
                                              WidgetState.hovered,
                                            ) ||
                                            states.contains(
                                              WidgetState.focused,
                                            )) {
                                          return colors.activeText;
                                        }
                                        return colors.text;
                                      }),
                                  backgroundColor:
                                      WidgetStateProperty.resolveWith((states) {
                                        if (!enabled) {
                                          return colors.disabledBackground;
                                        }
                                        if (active ||
                                            states.contains(
                                              WidgetState.hovered,
                                            ) ||
                                            states.contains(
                                              WidgetState.focused,
                                            )) {
                                          return colors.activeBackground;
                                        }
                                        return colors.buttonBackground;
                                      }),
                                  overlayColor: const WidgetStatePropertyAll(
                                    Colors.transparent,
                                  ),
                                  side: WidgetStateProperty.resolveWith((
                                    states,
                                  ) {
                                    if (active ||
                                        states.contains(WidgetState.hovered) ||
                                        states.contains(WidgetState.focused)) {
                                      return BorderSide(
                                        color: colors.activeBorder,
                                      );
                                    }
                                    return BorderSide(
                                      color: colors.buttonBorder,
                                    );
                                  }),
                                  shape: WidgetStatePropertyAll(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  textStyle: const WidgetStatePropertyAll(
                                    TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                onPressed:
                                    enabled
                                        ? () {
                                          onJump(key);
                                        }
                                        : null,
                                child: Text(key),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactQuickJumpButton extends StatelessWidget {
  const _CompactQuickJumpButton({
    required this.active,
    required this.onPressed,
  });

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryQuickJumpPanelColors.of(context);
    return Tooltip(
      message: '#-Z',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('MusicLibrary.QuickJumpToggle'),
          borderRadius: BorderRadius.circular(10),
          hoverColor: colors.toggleHover,
          focusColor: colors.toggleHover,
          highlightColor: colors.toggleHover,
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active ? colors.toggleHover : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Text(
                  '#-Z',
                  style: TextStyle(
                    color: colors.headerText,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<String> _quickJumpKeysForDirection(MusicLibrarySortDirection direction) {
  return direction == MusicLibrarySortDirection.descending
      ? _quickJumpKeys.reversed.toList()
      : _quickJumpKeys;
}

String _libraryQuickJumpBasisName(
  MusicLibrarySortCriterion criterion,
  SmPlayerI18n i18n,
) {
  switch (criterion) {
    case MusicLibrarySortCriterion.artist:
      return i18n.t('common.artist');
    case MusicLibrarySortCriterion.album:
      return i18n.t('common.album');
    case MusicLibrarySortCriterion.duration:
      return i18n.t('common.duration');
    case MusicLibrarySortCriterion.playCount:
      return i18n.t('common.playCount');
    case MusicLibrarySortCriterion.dateAdded:
      return i18n.t('common.dateAdded');
    case MusicLibrarySortCriterion.title:
      return i18n.t('musicLibrary.titleHeader');
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = _LibraryPalette.of(context);
    return DecoratedBox(
      key: const ValueKey('MusicLibrary.EmptyState'),
      decoration: BoxDecoration(
        color: colors.emptyStateSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.emptyStateBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  message,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 14,
                    height: 1.65,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
