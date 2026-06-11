import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_app_bar_portal.dart';

class ShellLayoutState {
  const ShellLayoutState({
    required this.currentPath,
    required this.currentLocation,
    required this.isImmersiveModeRoute,
    required this.navigationMode,
    required this.isNavigationPaneVisible,
    required this.canGoBack,
    required this.shellSidebarWidth,
    required this.sidebarSurfaceWidth,
    required this.isNavigationOverlaySurface,
    required this.minimalTitlebarHeight,
    required this.immersiveMinimalTitlebar,
    required this.workspaceTop,
    required this.navigationSurfaceTop,
    required this.navigationContentTopInset,
    required this.headeredPlaylistAppBar,
  });

  final String currentPath;
  final String currentLocation;
  final bool isImmersiveModeRoute;
  final SmPlayerNavigationMode navigationMode;
  final bool isNavigationPaneVisible;
  final bool canGoBack;
  final double shellSidebarWidth;
  final double sidebarSurfaceWidth;
  final bool isNavigationOverlaySurface;
  final double minimalTitlebarHeight;
  final bool immersiveMinimalTitlebar;
  final double workspaceTop;
  final double navigationSurfaceTop;
  final double navigationContentTopInset;
  final HeaderedPlaylistAppBarPortalEntry? headeredPlaylistAppBar;

  static ShellLayoutState resolve({
    required String currentPath,
    required String currentLocation,
    required double windowWidth,
    required bool navigationPaneOpen,
    required bool minimalNavigationOpen,
    required bool canGoBack,
    required HeaderedPlaylistAppBarPortalEntry? rawHeaderedPlaylistAppBar,
  }) {
    final isImmersiveModeRoute = currentPath == '/immersive-mode';
    final navigationMode = SmPlayerShellMetrics.navigationModeForWidth(
      windowWidth,
    );
    final isNavigationPaneVisible =
        isImmersiveModeRoute
            ? false
            : navigationMode == SmPlayerNavigationMode.minimal
            ? minimalNavigationOpen
            : navigationPaneOpen;
    final shellSidebarWidth =
        navigationMode == SmPlayerNavigationMode.minimal
            ? 0.0
            : navigationMode != SmPlayerNavigationMode.wide
            ? SmPlayerShellMetrics.collapsedSidebarWidth
            : isNavigationPaneVisible
            ? SmPlayerShellMetrics.sidebarWidth
            : SmPlayerShellMetrics.collapsedSidebarWidth;
    final sidebarSurfaceWidth =
        navigationMode == SmPlayerNavigationMode.minimal
            ? isNavigationPaneVisible
                ? SmPlayerShellMetrics.sidebarWidth
                : 0.0
            : isNavigationPaneVisible &&
                navigationMode != SmPlayerNavigationMode.wide
            ? SmPlayerShellMetrics.sidebarWidth
            : shellSidebarWidth;
    final isNavigationOverlaySurface =
        isNavigationPaneVisible &&
        navigationMode != SmPlayerNavigationMode.wide;
    final headeredPlaylistAppBar =
        rawHeaderedPlaylistAppBar != null &&
                (rawHeaderedPlaylistAppBar.routeLocation == null ||
                    rawHeaderedPlaylistAppBar.routeLocation == currentLocation)
            ? rawHeaderedPlaylistAppBar
            : null;
    final minimalTitlebarHeight =
        !isImmersiveModeRoute &&
                navigationMode == SmPlayerNavigationMode.minimal
            ? SmPlayerShellMetrics.minimalTitlebarHeight
            : 0.0;
    final immersiveMinimalTitlebar =
        minimalTitlebarHeight > 0 && headeredPlaylistAppBar != null;
    final workspaceTop = immersiveMinimalTitlebar ? 0.0 : minimalTitlebarHeight;
    final navigationSurfaceTop =
        headeredPlaylistAppBar != null &&
                navigationMode == SmPlayerNavigationMode.minimal
            ? 0.0
            : minimalTitlebarHeight;
    return ShellLayoutState(
      currentPath: currentPath,
      currentLocation: currentLocation,
      isImmersiveModeRoute: isImmersiveModeRoute,
      navigationMode: navigationMode,
      isNavigationPaneVisible: isNavigationPaneVisible,
      canGoBack: canGoBack,
      shellSidebarWidth: shellSidebarWidth,
      sidebarSurfaceWidth: sidebarSurfaceWidth,
      isNavigationOverlaySurface: isNavigationOverlaySurface,
      minimalTitlebarHeight: minimalTitlebarHeight,
      immersiveMinimalTitlebar: immersiveMinimalTitlebar,
      workspaceTop: workspaceTop,
      navigationSurfaceTop: navigationSurfaceTop,
      navigationContentTopInset: minimalTitlebarHeight - navigationSurfaceTop,
      headeredPlaylistAppBar: headeredPlaylistAppBar,
    );
  }
}
