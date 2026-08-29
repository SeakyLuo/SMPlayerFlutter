import 'dart:ui';

import 'package:flutter/material.dart';

class SmPlayerSplashScreen extends StatelessWidget {
  const SmPlayerSplashScreen({super.key, this.brightness, this.locale});

  final Brightness? brightness;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    final resolvedBrightness =
        brightness ?? PlatformDispatcher.instance.platformBrightness;
    final colors = SmPlayerSplashColors.resolve(resolvedBrightness);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: resolvedBrightness,
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: colors.accent,
          linearTrackColor: colors.progressTrack,
          circularTrackColor: colors.progressTrack,
        ),
      ),
      home: SmPlayerSplashView(brightness: resolvedBrightness, locale: locale),
    );
  }
}

class SmPlayerSplashView extends StatelessWidget {
  const SmPlayerSplashView({super.key, this.brightness, this.locale});

  final Brightness? brightness;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    final resolvedBrightness =
        brightness ?? PlatformDispatcher.instance.platformBrightness;
    final colors = SmPlayerSplashColors.resolve(resolvedBrightness);
    final appName = SmPlayerSplashAppName.resolve(
      locale ?? PlatformDispatcher.instance.locale,
    );
    return Scaffold(
      backgroundColor: colors.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.background, colors.backgroundAlt],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SmPlayerSplashLogo(size: 132),
              const SizedBox(height: 26),
              Text(
                appName,
                style: TextStyle(
                  color: colors.title,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 144,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: colors.progressTrack,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmPlayerSplashLogo extends StatelessWidget {
  const _SmPlayerSplashLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _SmPlayerSplashLogoPainter(),
    );
  }
}

class _SmPlayerSplashLogoPainter extends CustomPainter {
  const _SmPlayerSplashLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final logoRect = Offset.zero & size;
    final paint =
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff86c7e5), Color(0xff2750bd)],
          ).createShader(logoRect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.095
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final path =
        Path()
          ..moveTo(size.width * 0.23, size.height * 0.68)
          ..lineTo(size.width * 0.23, size.height * 0.27)
          ..lineTo(size.width * 0.5, size.height * 0.45)
          ..lineTo(size.width * 0.77, size.height * 0.25)
          ..lineTo(size.width * 0.77, size.height * 0.64);
    canvas.drawPath(path, paint);

    paint.style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.19, size.height * 0.72),
        width: size.width * 0.24,
        height: size.height * 0.17,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.73, size.height * 0.68),
        width: size.width * 0.24,
        height: size.height * 0.17,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SmPlayerSplashLogoPainter oldDelegate) => false;
}

class SmPlayerSplashAppName {
  const SmPlayerSplashAppName._();

  static String resolve(Locale locale) {
    if (locale.languageCode == 'zh') {
      return locale.scriptCode == 'Hant' ||
              locale.countryCode == 'TW' ||
              locale.countryCode == 'HK' ||
              locale.countryCode == 'MO'
          ? '簡音播放器'
          : '简音播放器';
    }
    return 'Simple Melody Player';
  }
}

class SmPlayerSplashColors {
  const SmPlayerSplashColors({
    required this.background,
    required this.backgroundAlt,
    required this.title,
    required this.accent,
    required this.progressTrack,
  });

  final Color background;
  final Color backgroundAlt;
  final Color title;
  final Color accent;
  final Color progressTrack;

  static SmPlayerSplashColors resolve(Brightness brightness) {
    return brightness == Brightness.dark ? night : day;
  }

  static const day = SmPlayerSplashColors(
    background: Color(0xfff7f9fc),
    backgroundAlt: Color(0xffdfefff),
    title: Color(0xff18202b),
    accent: Color(0xff0078d7),
    progressTrack: Color(0x240078d7),
  );

  static const night = SmPlayerSplashColors(
    background: Color(0xff0f1319),
    backgroundAlt: Color(0xff151f2b),
    title: Color(0xfff4f8ff),
    accent: Color(0xff5f9ed1),
    progressTrack: Color(0x335f9ed1),
  );
}
