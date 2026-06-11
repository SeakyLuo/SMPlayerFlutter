part of 'main_navigation_view.dart';

@immutable
class MainNavigationViewItem {
  const MainNavigationViewItem({
    required this.name,
    required this.target,
    required this.icon,
    this.label = '',
    this.labelKey,
    this.exactActive = false,
  });

  final String name;
  final String target;
  final String label;
  final String? labelKey;
  final IconData icon;
  final bool exactActive;

  String labelFor(SmPlayerI18n i18n) {
    final key = labelKey;
    if (key != null) {
      return i18n.t(key);
    }

    return label;
  }

  bool isActive(String currentPath) {
    if (exactActive) {
      return currentPath == target;
    }

    return currentPath == target || currentPath.startsWith('$target/');
  }
}

class _MainNavigationViewTitle extends StatelessWidget {
  const _MainNavigationViewTitle({
    required this.collapsed,
    required this.hideAppName,
    required this.appName,
    required this.titlebarLeadingInset,
    required this.canGoBack,
    required this.backLabel,
    required this.onGoBack,
    required this.onWindowDragStart,
    required this.onWindowDragEnd,
    required this.onTooltipRequested,
    required this.onTooltipDismissed,
  });

  final bool collapsed;
  final bool hideAppName;
  final String appName;
  final double titlebarLeadingInset;
  final bool canGoBack;
  final String backLabel;
  final VoidCallback? onGoBack;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;
  final _NavigationTooltipRequest? onTooltipRequested;
  final VoidCallback onTooltipDismissed;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => closeOpenMenuFlyouts(),
      child: SizedBox(
        height: 40,
        width: double.infinity,
        child:
            collapsed
                ? Center(
                  child:
                      canGoBack
                          ? _NavigationIconButton(
                            key: const ValueKey(
                              'MainNavigationView.BackButton',
                            ),
                            icon: FluentIcons.arrow_left_24_regular,
                            tooltip: backLabel,
                            onPressed: onGoBack ?? () {},
                            collapsedContext: true,
                            onTooltipRequested: onTooltipRequested,
                            onTooltipDismissed: onTooltipDismissed,
                          )
                          : const SizedBox.shrink(),
                )
                : Row(
                  children: [
                    if (titlebarLeadingInset > 0)
                      SizedBox(width: titlebarLeadingInset),
                    if (canGoBack) ...[
                      _NavigationIconButton(
                        key: const ValueKey('MainNavigationView.BackButton'),
                        icon: FluentIcons.arrow_left_24_regular,
                        tooltip: backLabel,
                        onPressed: onGoBack ?? () {},
                        onTooltipDismissed: onTooltipDismissed,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: _WindowDragRegion(
                        onWindowDragStart: onWindowDragStart,
                        onWindowDragEnd: onWindowDragEnd,
                        child:
                            hideAppName
                                ? const SizedBox.expand()
                                : Text(
                                  appName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textStrong,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

const _desktopTitlebarButtonInset = 78.0;

String _navigationAppName(SmPlayerI18n i18n, Locale locale) {
  final appName = i18n.t('app.shell');
  if (appName != 'app.shell') {
    return appName;
  }
  if (locale.languageCode == 'zh') {
    return locale.scriptCode == 'Hant' ||
            locale.countryCode == 'TW' ||
            locale.countryCode == 'HK' ||
            locale.countryCode == 'MO'
        ? '簡音播放器'
        : '简音播放器';
  }
  return 'Simple Melody Player';
}

class _WindowDragRegion extends StatelessWidget {
  const _WindowDragRegion({
    required this.child,
    required this.onWindowDragStart,
    required this.onWindowDragEnd,
  });

  final Widget child;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (event.buttons == 1) {
          onWindowDragStart?.call();
        }
      },
      onPointerUp: (_) => onWindowDragEnd?.call(),
      onPointerCancel: (_) => onWindowDragEnd?.call(),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}
