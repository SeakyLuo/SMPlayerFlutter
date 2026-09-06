import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/main_navigation_view.dart';
import 'package:smplayer_flutter/src/app/navigation_icon_button.dart';
import 'package:smplayer_flutter/src/app/shell_layout_state.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/app/shell_widgets.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

class ShellTitlebarHost extends StatelessWidget {
  const ShellTitlebarHost({
    super.key,
    required this.layout,
    required this.immersiveOverlayVisible,
    required this.windowControlsLight,
    required this.isWindowMaximized,
    required this.onPaneToggle,
    required this.onGoBack,
    required this.onWindowDragStart,
    required this.onWindowDragEnd,
    required this.onTitlebarTap,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onClose,
  });

  final ShellLayoutState layout;
  final bool immersiveOverlayVisible;
  final bool? windowControlsLight;
  final bool isWindowMaximized;
  final VoidCallback onPaneToggle;
  final VoidCallback onGoBack;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;
  final VoidCallback onTitlebarTap;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final immersiveModeVisible = immersiveOverlayVisible;
    return Stack(
      children: [
        if (Platform.isMacOS &&
            !immersiveModeVisible &&
            layout.navigationMode != SmPlayerNavigationMode.minimal)
          _MacOSSidebarTitlebarActions(
            layout: layout,
            onPaneToggle: onPaneToggle,
            onGoBack: onGoBack,
            onWindowDragStart: onWindowDragStart,
            onWindowDragEnd: onWindowDragEnd,
            onTitlebarTap: onTitlebarTap,
          ),
        if (!immersiveModeVisible && layout.minimalTitlebarHeight > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: layout.minimalTitlebarHeight,
            child: MinimalTitlebar(
              title: context.smPlayerI18n.t('app.shell'),
              canGoBack: layout.canGoBack,
              backLabel: context.smPlayerI18n.t('sidebar.back'),
              onGoBack: onGoBack,
              onWindowDragStart: onWindowDragStart,
              onWindowDragEnd: onWindowDragEnd,
              onTitlebarTap: onTitlebarTap,
              headeredPlaylistAppBar: layout.headeredPlaylistAppBar,
            ),
          ),
        if (Platform.isWindows &&
            (immersiveModeVisible || layout.minimalTitlebarHeight == 0))
          Positioned(
            top: 0,
            left: immersiveModeVisible ? 0 : layout.sidebarSurfaceWidth,
            right: 0,
            height: SmPlayerShellMetrics.minimalTitlebarHeight,
            child: WindowsAppTitleBar(
              isMaximized: isWindowMaximized,
              light:
                  windowControlsLight ??
                  (Theme.of(context).brightness == Brightness.dark),
              showDragRegion: true,
              onWindowDragStart: onWindowDragStart,
              onWindowDragEnd: onWindowDragEnd,
              onTitlebarTap: onTitlebarTap,
              onMinimize: onMinimize,
              onToggleMaximize: onToggleMaximize,
              onClose: onClose,
            ),
          ),
        if (Platform.isWindows &&
            !immersiveModeVisible &&
            layout.minimalTitlebarHeight > 0)
          Positioned(
            top: 0,
            right: 0,
            width: WindowsAppTitleBar.controlsWidth,
            height: SmPlayerShellMetrics.minimalTitlebarHeight,
            child: WindowsAppTitleBar(
              isMaximized: isWindowMaximized,
              light:
                  windowControlsLight ??
                  (Theme.of(context).brightness == Brightness.dark),
              showDragRegion: false,
              onWindowDragStart: onWindowDragStart,
              onWindowDragEnd: onWindowDragEnd,
              onTitlebarTap: onTitlebarTap,
              onMinimize: onMinimize,
              onToggleMaximize: onToggleMaximize,
              onClose: onClose,
            ),
          ),
      ],
    );
  }
}

class _MacOSSidebarTitlebarActions extends StatelessWidget {
  const _MacOSSidebarTitlebarActions({
    required this.layout,
    required this.onPaneToggle,
    required this.onGoBack,
    required this.onWindowDragStart,
    required this.onWindowDragEnd,
    required this.onTitlebarTap,
  });

  static const _buttonSize = 32.0;
  static const _iconSize = 18.0;
  static const _buttonGap = 4.0;

  final ShellLayoutState layout;
  final VoidCallback onPaneToggle;
  final VoidCallback onGoBack;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;
  final VoidCallback onTitlebarTap;

  @override
  Widget build(BuildContext context) {
    final colors = MainNavigationViewColors.of(context);
    final toggleLeft = SmPlayerShellMetrics.macOSTitlebarLeadingInset;
    final backLeft = toggleLeft + _buttonSize + _buttonGap;
    final dragLeft =
        layout.canGoBack ? backLeft + _buttonSize + _buttonGap : backLeft;
    final showSidebarDragRegion =
        layout.isNavigationPaneVisible && layout.sidebarSurfaceWidth > dragLeft;

    Widget navigationButton({
      required Key key,
      required IconData icon,
      required String tooltip,
      required VoidCallback onPressed,
    }) {
      return SmPlayerNavigationIconButton(
        key: key,
        icon: icon,
        tooltip: tooltip,
        onPressed: onPressed,
        foreground: colors.textStrong,
        mutedForeground: colors.textMuted,
        hoverForeground: colors.highlightText,
        hoverColor: colors.iconButtonHover,
        collapsedHoverColor: colors.collapsedHover,
        size: _buttonSize,
        iconSize: _iconSize,
        borderRadius: 8,
      );
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: _buttonSize,
      child: Stack(
        children: [
          Positioned(
            left: toggleLeft,
            child: navigationButton(
              key: const ValueKey('MainNavigationView.TogglePaneButton'),
              icon: FluentIcons.panel_left_24_regular,
              tooltip:
                  layout.isNavigationPaneVisible
                      ? context.smPlayerI18n.t('sidebar.collapseNavigation')
                      : context.smPlayerI18n.t('sidebar.expandNavigation'),
              onPressed: onPaneToggle,
            ),
          ),
          if (layout.canGoBack)
            Positioned(
              left: backLeft,
              child: navigationButton(
                key: const ValueKey('MainNavigationView.BackButton'),
                icon: FluentIcons.arrow_left_24_regular,
                tooltip: context.smPlayerI18n.t('sidebar.back'),
                onPressed: onGoBack,
              ),
            ),
          if (showSidebarDragRegion)
            Positioned(
              left: dragLeft,
              width: layout.sidebarSurfaceWidth - dragLeft,
              top: 0,
              bottom: 0,
              child: ShellWindowDragRegion(
                onWindowDragStart: onWindowDragStart,
                onWindowDragEnd: onWindowDragEnd,
                onTap: onTitlebarTap,
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }
}
