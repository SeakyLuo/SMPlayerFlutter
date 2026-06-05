import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';

class SmPlayerShellFrame extends StatelessWidget {
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
            child:
                isMiniMode
                    ? miniModeHost
                    : Stack(fit: StackFit.expand, children: children),
          ),
        ),
      ),
    );
  }
}
