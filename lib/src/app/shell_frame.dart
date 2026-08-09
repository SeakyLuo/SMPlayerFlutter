import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';

class SmPlayerShellFrame extends StatelessWidget {
  static const _miniModeTransitionDuration = Duration(milliseconds: 400);

  const SmPlayerShellFrame({
    super.key,
    required this.colors,
    required this.isMiniMode,
    required this.miniModeHost,
    required this.children,
  });

  final ShellThemeColors colors;
  final bool isMiniMode;
  final Widget miniModeHost;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.bodyTop, colors.bodyBottom],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.bodyHighlight, Colors.transparent],
              stops: const [0, 0.36],
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: AnimatedSwitcher(
              duration: _miniModeTransitionDuration,
              reverseDuration: _miniModeTransitionDuration,
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.96,
                      end: 1,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child:
                  isMiniMode
                      ? KeyedSubtree(
                        key: const ValueKey('SmPlayerShellFrame.MiniMode'),
                        child: miniModeHost,
                      )
                      : KeyedSubtree(
                        key: const ValueKey('SmPlayerShellFrame.NormalMode'),
                        child: Stack(fit: StackFit.expand, children: children),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}
