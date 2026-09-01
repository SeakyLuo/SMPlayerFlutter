import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';

class SmPlayerShellFrame extends StatefulWidget {
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
  State<SmPlayerShellFrame> createState() => _SmPlayerShellFrameState();
}

class _SmPlayerShellFrameState extends State<SmPlayerShellFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _transition;
  late final Animation<double> _normalScale;
  late final Animation<double> _miniScale;
  late bool _normalModeMounted;
  late bool _miniModeMounted;

  @override
  void initState() {
    super.initState();
    _normalModeMounted = !widget.isMiniMode;
    _miniModeMounted = widget.isMiniMode;
    _controller = AnimationController(
      vsync: this,
      duration: SmPlayerShellFrame._miniModeTransitionDuration,
      value: widget.isMiniMode ? 1 : 0,
    )..addStatusListener(_handleTransitionStatus);
    _transition = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _normalScale = Tween<double>(begin: 1, end: 0.96).animate(_transition);
    _miniScale = Tween<double>(begin: 0.96, end: 1).animate(_transition);
  }

  @override
  void didUpdateWidget(covariant SmPlayerShellFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMiniMode == oldWidget.isMiniMode) {
      return;
    }
    if (widget.isMiniMode) {
      _miniModeMounted = true;
      _controller.forward();
    } else {
      _normalModeMounted = true;
      _controller.reverse();
    }
  }

  void _handleTransitionStatus(AnimationStatus status) {
    if (!mounted) {
      return;
    }
    if (status == AnimationStatus.completed && _normalModeMounted) {
      setState(() {
        _normalModeMounted = false;
      });
    } else if (status == AnimationStatus.dismissed && _miniModeMounted) {
      setState(() {
        _miniModeMounted = false;
      });
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleTransitionStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [widget.colors.bodyTop, widget.colors.bodyBottom],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [widget.colors.bodyHighlight, Colors.transparent],
              stops: const [0, 0.36],
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_normalModeMounted)
                  IgnorePointer(
                    ignoring: widget.isMiniMode,
                    child: ExcludeSemantics(
                      excluding: widget.isMiniMode,
                      child: TickerMode(
                        enabled: !widget.isMiniMode,
                        child: FadeTransition(
                          opacity: ReverseAnimation(_transition),
                          child: ScaleTransition(
                            scale: _normalScale,
                            child: KeyedSubtree(
                              key: const ValueKey(
                                'SmPlayerShellFrame.NormalMode',
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: widget.children,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_miniModeMounted)
                  IgnorePointer(
                    ignoring: !widget.isMiniMode,
                    child: ExcludeSemantics(
                      excluding: !widget.isMiniMode,
                      child: TickerMode(
                        enabled: widget.isMiniMode,
                        child: FadeTransition(
                          opacity: _transition,
                          child: ScaleTransition(
                            scale: _miniScale,
                            child: KeyedSubtree(
                              key: const ValueKey(
                                'SmPlayerShellFrame.MiniMode',
                              ),
                              child: widget.miniModeHost,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
