import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

enum VoiceAssistantCaptureState { idle, capturing, processing }

class VoiceAssistantPopover extends StatelessWidget {
  const VoiceAssistantPopover({
    super.key,
    required this.text,
    required this.state,
    required this.miniMode,
    required this.narrow,
    required this.helpLabel,
    required this.onClose,
    this.onHelp,
  });

  final String text;
  final VoiceAssistantCaptureState state;
  final bool miniMode;
  final bool narrow;
  final String helpLabel;
  final VoidCallback onClose;
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.progressIndicatorTheme.color!;
    final capturing = state == VoiceAssistantCaptureState.capturing;
    final radius = BorderRadius.circular(miniMode ? 14 : 18);
    final textColor = dark ? const Color(0xfff6f8fb) : const Color(0xff1f252b);
    final fontSize = narrow ? 13.0 : 14.0;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: dark ? const Color(0x57000000) : const Color(0x29465770),
              blurRadius: dark ? 42 : 34,
              offset: Offset(0, dark ? 18 : 16),
            ),
            if (capturing)
              BoxShadow(
                color: accent.withValues(alpha: dark ? .24 : .18),
                blurRadius: dark ? 34 : 30,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: dark ? 48 : 46,
              sigmaY: dark ? 48 : 46,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color:
                      dark ? const Color(0x2edde7f3) : const Color(0xd1ffffff),
                ),
                color: dark ? const Color(0xc210151d) : const Color(0xb8f6faff),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors:
                      dark
                          ? const [Color(0xe027303d), Color(0xe00c1119)]
                          : const [Color(0xf5ffffff), Color(0xd9e5edf8)],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (capturing)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: _VoiceRipples(accent: accent),
                        ),
                      ),
                    ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClose,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: miniMode ? 48 : 52,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: miniMode ? 14 : 18,
                          vertical: miniMode ? 10 : 11,
                        ),
                        child: Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              if (state ==
                                  VoiceAssistantCaptureState.processing)
                                SizedBox.square(
                                  dimension: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color:
                                        dark ? const Color(0xfa82b0ff) : accent,
                                    backgroundColor: accent.withValues(
                                      alpha: .26,
                                    ),
                                  ),
                                ),
                              Text(
                                text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w400,
                                  height: 1.35,
                                ),
                              ),
                              if (onHelp != null)
                                TextButton(
                                  onPressed: onHelp,
                                  style: ButtonStyle(
                                    padding: const WidgetStatePropertyAll(
                                      EdgeInsets.zero,
                                    ),
                                    minimumSize: const WidgetStatePropertyAll(
                                      Size.zero,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    overlayColor: const WidgetStatePropertyAll(
                                      Colors.transparent,
                                    ),
                                    foregroundColor:
                                        WidgetStateProperty.resolveWith(
                                          (states) =>
                                              states.contains(
                                                    WidgetState.hovered,
                                                  )
                                                  ? (dark
                                                      ? Colors.white
                                                      : accent)
                                                  : Color.lerp(
                                                    accent,
                                                    dark
                                                        ? const Color(
                                                          0xfff5fbff,
                                                        )
                                                        : const Color(
                                                          0xff0f172a,
                                                        ),
                                                    dark ? .3 : .24,
                                                  ),
                                        ),
                                    textStyle: WidgetStatePropertyAll(
                                      TextStyle(
                                        fontSize: fontSize,
                                        fontWeight: FontWeight.w500,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                  child: Text(helpLabel),
                                ),
                            ],
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
      ),
    );
  }
}

class _VoiceRipples extends StatefulWidget {
  const _VoiceRipples({required this.accent});
  final Color accent;
  @override
  State<_VoiceRipples> createState() => _VoiceRipplesState();
}

class _VoiceRipplesState extends State<_VoiceRipples>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _RipplePainter(_animation, widget.accent));
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.animation, this.accent) : super(repaint: animation);
  final Animation<double> animation;
  final Color accent;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final glow =
        Paint()
          ..shader = RadialGradient(
            colors: [
              accent.withValues(alpha: .24),
              accent.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: 150));
    canvas.drawRect(Offset.zero & size, glow);
    for (final offset in [0.0, 0.5]) {
      final t = (animation.value + offset) % 1;
      final opacity = t < .18 ? t / .18 : (1 - t) / .82;
      final radius = 48 * (.18 + 6.62 * Curves.easeOut.transform(t));
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = accent.withValues(alpha: opacity * .52),
      );
    }
    final x = -size.width / 2 + size.width * 2 * animation.value;
    canvas.drawRect(
      Rect.fromLTWH(x, 0, size.width / 2, size.height),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            accent.withValues(alpha: .14),
            Colors.transparent,
          ],
          transform: const GradientRotation(math.pi / 18),
        ).createShader(Rect.fromLTWH(x, 0, size.width / 2, size.height)),
    );
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.animation != animation;
}
