import 'dart:io';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/shell_layout_state.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/app/shell_widgets.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';

class ShellTitlebarHost extends StatelessWidget {
  const ShellTitlebarHost({
    super.key,
    required this.layout,
    required this.windowControlsLight,
    required this.isWindowMaximized,
    required this.onGoBack,
    required this.onWindowDragStart,
    required this.onWindowDragEnd,
    required this.onTitlebarTap,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onClose,
  });

  final ShellLayoutState layout;
  final bool? windowControlsLight;
  final bool isWindowMaximized;
  final VoidCallback onGoBack;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;
  final VoidCallback onTitlebarTap;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (layout.minimalTitlebarHeight > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: layout.minimalTitlebarHeight,
            child: MinimalTitlebar(
              title:
                  Platform.isMacOS ? '' : context.smPlayerI18n.t('app.shell'),
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
            !layout.isImmersiveModeRoute &&
            layout.minimalTitlebarHeight == 0)
          Positioned(
            top: 0,
            left: layout.sidebarSurfaceWidth,
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
            !layout.isImmersiveModeRoute &&
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
