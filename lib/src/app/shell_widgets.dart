import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_app_bar_portal.dart';

class ShellWindowDragRegion extends StatelessWidget {
  const ShellWindowDragRegion({
    super.key,
    required this.child,
    required this.onWindowDragStart,
    required this.onWindowDragEnd,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (event.buttons == 1) {
            onWindowDragStart?.call();
          }
        },
        onPointerUp: (_) => onWindowDragEnd?.call(),
        onPointerCancel: (_) => onWindowDragEnd?.call(),
        child: child,
      ),
    );
  }
}

class ShellNavigationGlassSurface extends StatelessWidget {
  const ShellNavigationGlassSurface({
    super.key,
    required this.surface,
    required this.shadowColor,
    required this.shadowBlur,
    required this.child,
  });

  final Color surface;
  final Color shadowColor;
  final double shadowBlur;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const edgeBleed = 10.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow:
            shadowColor == Colors.transparent
                ? const []
                : [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: shadowBlur,
                    offset: const Offset(18, 0),
                  ),
                ],
      ),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: -edgeBleed,
                  top: -edgeBleed,
                  right: -edgeBleed,
                  bottom: -edgeBleed,
                  child: GlassContainer(
                    useOwnLayer: true,
                    quality: GlassQuality.standard,
                    shape: const LiquidRoundedRectangle(borderRadius: 0),
                    settings: LiquidGlassSettings(
                      blur: 30,
                      thickness: 18,
                      refractiveIndex: 1.06,
                      saturation: 1.18,
                      chromaticAberration: 0,
                      lightIntensity: 0.18,
                      ambientStrength: 0.12,
                      glowIntensity: 0.12,
                      glassColor: surface,
                      standardOpacityMultiplier: 1,
                    ),
                    clipBehavior: Clip.none,
                    allowElevation: false,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class MinimalTitlebar extends StatelessWidget {
  const MinimalTitlebar({
    super.key,
    required this.title,
    required this.canGoBack,
    required this.backLabel,
    required this.onGoBack,
    required this.onWindowDragStart,
    required this.onWindowDragEnd,
    required this.onTitlebarTap,
    required this.headeredPlaylistAppBar,
  });

  final String title;
  final bool canGoBack;
  final String backLabel;
  final VoidCallback onGoBack;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;
  final VoidCallback? onTitlebarTap;
  final HeaderedPlaylistAppBarPortalEntry? headeredPlaylistAppBar;

  @override
  Widget build(BuildContext context) {
    final shellColors = ShellThemeColors.of(context);
    final leadingInset =
        Platform.isMacOS ? SmPlayerShellMetrics.macOSTitlebarLeadingInset : 0.0;
    final titleColor =
        headeredPlaylistAppBar == null
            ? shellColors.headerText
            : _immersiveMinimalTitlebarForeground(context);
    final content = Row(
      children: [
        if (leadingInset > 0) SizedBox(width: leadingInset),
        if (canGoBack)
          Tooltip(
            message: backLabel,
            waitDuration: const Duration(milliseconds: 450),
            child: InkWell(
              key: const ValueKey('MainNavigationView.BackButton'),
              onTap: onGoBack,
              hoverColor: titleColor.withValues(alpha: 0.08),
              focusColor: titleColor.withValues(alpha: 0.08),
              highlightColor: titleColor.withValues(alpha: 0.08),
              child: SizedBox(
                width: 40,
                height: SmPlayerShellMetrics.minimalTitlebarHeight,
                child: Icon(
                  FluentIcons.arrow_left_24_regular,
                  size: 18,
                  color: titleColor,
                ),
              ),
            ),
          ),
        Expanded(
          child: ShellWindowDragRegion(
            onWindowDragStart: onWindowDragStart,
            onWindowDragEnd: onWindowDragEnd,
            onTap: onTitlebarTap,
            child:
                title.isEmpty
                    ? const SizedBox.expand()
                    : Padding(
                      padding: EdgeInsets.only(
                        left: canGoBack ? 6 : 10,
                        right: 138,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 13,
                            height: 1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
          ),
        ),
      ],
    );
    if (headeredPlaylistAppBar == null) {
      return Material(color: shellColors.workspaceSolidSurface, child: content);
    }

    return Material(color: Colors.transparent, child: content);
  }
}

class WindowsAppTitleBar extends StatelessWidget {
  const WindowsAppTitleBar({
    super.key,
    required this.isMaximized,
    required this.light,
    required this.showDragRegion,
    required this.onWindowDragStart,
    required this.onWindowDragEnd,
    required this.onTitlebarTap,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onClose,
  });

  static const controlsWidth = 138.0;

  final bool isMaximized;
  final bool light;
  final bool showDragRegion;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;
  final VoidCallback? onTitlebarTap;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final foreground = light ? Colors.white : const Color(0xff111111);
    final controls = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _WindowsCaptionButton(
          key: const ValueKey('WindowsAppTitleBar.MinimizeButton'),
          icon: _WindowsCaptionIcon.minimize,
          foreground: foreground,
          onPressed: onMinimize,
        ),
        _WindowsCaptionButton(
          key: const ValueKey('WindowsAppTitleBar.MaximizeButton'),
          icon:
              isMaximized
                  ? _WindowsCaptionIcon.restore
                  : _WindowsCaptionIcon.maximize,
          foreground: foreground,
          onPressed: onToggleMaximize,
        ),
        _WindowsCaptionButton(
          key: const ValueKey('WindowsAppTitleBar.CloseButton'),
          icon: _WindowsCaptionIcon.close,
          foreground: foreground,
          closeButton: true,
          onPressed: onClose,
        ),
      ],
    );

    if (!showDragRegion) {
      return Material(color: Colors.transparent, child: controls);
    }

    return Material(
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: ShellWindowDragRegion(
              key: const ValueKey('WindowsAppTitleBar.DragRegion'),
              onWindowDragStart: onWindowDragStart,
              onWindowDragEnd: onWindowDragEnd,
              onTap: onTitlebarTap,
              child: const SizedBox.expand(),
            ),
          ),
          SizedBox(width: controlsWidth, child: controls),
        ],
      ),
    );
  }
}

enum _WindowsCaptionIcon { minimize, maximize, restore, close }

class _WindowsCaptionButton extends StatefulWidget {
  const _WindowsCaptionButton({
    super.key,
    required this.icon,
    required this.foreground,
    required this.onPressed,
    this.closeButton = false,
  });

  final _WindowsCaptionIcon icon;
  final Color foreground;
  final VoidCallback onPressed;
  final bool closeButton;

  @override
  State<_WindowsCaptionButton> createState() => _WindowsCaptionButtonState();
}

class _WindowsCaptionButtonState extends State<_WindowsCaptionButton> {
  var _hovered = false;
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final background =
        widget.closeButton && (_hovered || _pressed)
            ? const Color(0xffe81123)
            : _pressed
            ? widget.foreground.withValues(alpha: 0.18)
            : _hovered
            ? widget.foreground.withValues(alpha: 0.10)
            : Colors.transparent;
    final foreground =
        widget.closeButton && (_hovered || _pressed)
            ? Colors.white
            : widget.foreground;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:
          (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: ColoredBox(
          color: background,
          child: SizedBox(
            width: 46,
            height: SmPlayerShellMetrics.minimalTitlebarHeight,
            child: CustomPaint(
              painter: _WindowsCaptionIconPainter(
                icon: widget.icon,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowsCaptionIconPainter extends CustomPainter {
  const _WindowsCaptionIconPainter({required this.icon, required this.color});

  final _WindowsCaptionIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

    switch (icon) {
      case _WindowsCaptionIcon.minimize:
        canvas.drawLine(
          Offset(center.dx - 5, center.dy + 4),
          Offset(center.dx + 5, center.dy + 4),
          paint,
        );
      case _WindowsCaptionIcon.maximize:
        canvas.drawRect(
          Rect.fromCenter(center: center, width: 10, height: 10),
          paint,
        );
      case _WindowsCaptionIcon.restore:
        canvas.drawRect(
          Rect.fromLTWH(center.dx - 3, center.dy - 6, 8, 8),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(center.dx - 6, center.dy - 3, 8, 8),
          Paint()
            ..color = color
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
        );
      case _WindowsCaptionIcon.close:
        canvas.drawLine(
          Offset(center.dx - 5, center.dy - 5),
          Offset(center.dx + 5, center.dy + 5),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx + 5, center.dy - 5),
          Offset(center.dx - 5, center.dy + 5),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_WindowsCaptionIconPainter oldDelegate) {
    return oldDelegate.icon != icon || oldDelegate.color != color;
  }
}

Color _immersiveMinimalTitlebarForeground(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xfff6f9fc)
      : const Color(0xff111827);
}
