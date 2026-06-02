import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/shell_layout_state.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/app/shell_workspace.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

class ShellWorkspaceHost extends StatelessWidget {
  const ShellWorkspaceHost({
    super.key,
    required this.layout,
    required this.pageStorageBucket,
    required this.navigationMenuLabel,
    required this.onNavigationMenuPressed,
    required this.child,
  });

  final ShellLayoutState layout;
  final PageStorageBucket pageStorageBucket;
  final String navigationMenuLabel;
  final VoidCallback onNavigationMenuPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      left: layout.isNowPlayingFullRoute ? 0 : layout.shellSidebarWidth,
      top: layout.workspaceTop,
      right: 0,
      height:
          layout.isNowPlayingFullRoute
              ? MediaQuery.sizeOf(context).height
              : MediaQuery.sizeOf(context).height -
                  SmPlayerShellMetrics.playerHeight +
                  SmPlayerShellMetrics.playerTopRadius -
                  layout.workspaceTop,
      child: SmPlayerWorkspace(
        key: SmPlayerShellKeys.workspace,
        currentPath: layout.currentPath,
        currentLocation: layout.currentLocation,
        headerHeight: SmPlayerShellMetrics.workspaceHeaderHeight,
        showNavigationAppBar:
            layout.navigationMode == SmPlayerNavigationMode.minimal &&
            !layout.isNowPlayingFullRoute,
        navigationMenuLabel: navigationMenuLabel,
        onNavigationMenuPressed: onNavigationMenuPressed,
        navigationAppBarTopInset:
            layout.immersiveMinimalTitlebar ? layout.minimalTitlebarHeight : 0,
        child: PageStorage(bucket: pageStorageBucket, child: child),
      ),
    );
  }
}

String shellNavigationMenuLabel({
  required BuildContext context,
  required bool navigationVisible,
}) {
  return navigationVisible
      ? context.smPlayerI18n.t('sidebar.collapseNavigation')
      : context.smPlayerI18n.t('sidebar.expandNavigation');
}
