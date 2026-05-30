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
      child: child,
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
    required this.headeredPlaylistAppBar,
  });

  final String title;
  final bool canGoBack;
  final String backLabel;
  final VoidCallback onGoBack;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;
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

Color _immersiveMinimalTitlebarForeground(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xfff6f9fc)
      : const Color(0xff111827);
}
