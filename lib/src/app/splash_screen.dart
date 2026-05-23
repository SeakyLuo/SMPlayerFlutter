import 'dart:ui';

import 'package:flutter/material.dart';

class SmPlayerSplashScreen extends StatelessWidget {
  const SmPlayerSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) {
          final brightness = PlatformDispatcher.instance.platformBrightness;
          final colors = SmPlayerSplashColors.resolve(brightness);
          final appName = SmPlayerSplashAppName.resolve(
            PlatformDispatcher.instance.locale,
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
                    Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        color: colors.logoPlate,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: colors.logoShadow,
                            blurRadius: 42,
                            offset: const Offset(0, 24),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/branding/app-icon.png',
                          width: 86,
                          height: 86,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
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
        },
      ),
    );
  }
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
    required this.logoPlate,
    required this.logoShadow,
    required this.title,
    required this.accent,
    required this.progressTrack,
  });

  final Color background;
  final Color backgroundAlt;
  final Color logoPlate;
  final Color logoShadow;
  final Color title;
  final Color accent;
  final Color progressTrack;

  static SmPlayerSplashColors resolve(Brightness brightness) {
    return brightness == Brightness.dark ? night : day;
  }

  static const day = SmPlayerSplashColors(
    background: Color(0xfff7f9fc),
    backgroundAlt: Color(0xffdfefff),
    logoPlate: Color(0xffffffff),
    logoShadow: Color(0x300078d7),
    title: Color(0xff18202b),
    accent: Color(0xff0078d7),
    progressTrack: Color(0x240078d7),
  );

  static const night = SmPlayerSplashColors(
    background: Color(0xff0f1319),
    backgroundAlt: Color(0xff151f2b),
    logoPlate: Color(0xff182230),
    logoShadow: Color(0x66000000),
    title: Color(0xfff4f8ff),
    accent: Color(0xff5f9ed1),
    progressTrack: Color(0x335f9ed1),
  );
}
