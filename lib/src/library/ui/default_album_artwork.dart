import 'dart:ui';

import 'package:flutter/material.dart';

class DefaultAlbumArtwork extends StatelessWidget {
  const DefaultAlbumArtwork({
    super.key,
    this.logoScale = 0.68,
    this.lightShadowOffset = 8,
    this.darkShadowOffset = 10,
    this.lightShadowBlur = 8,
    this.darkShadowBlur = 10,
    this.logoOpacity = 1,
  });

  final double logoScale;
  final double lightShadowOffset;
  final double darkShadowOffset;
  final double lightShadowBlur;
  final double darkShadowBlur;
  final double logoOpacity;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              night
                  ? const [Color(0xf01f2732), Color(0xf50f141b)]
                  : const [Color(0xf0f7f9fc), Color(0xe6e3eaf2)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-0.47, -1),
                end: const Alignment(0.47, 1),
                colors:
                    night
                        ? const [
                          Color(0x3d417c9a),
                          Color(0x4234465c),
                          Color(0x06ffffff),
                        ]
                        : const [
                          Color(0x4f9fd8d7),
                          Color(0x33cfe0ee),
                          Color(0x12ffffff),
                        ],
                stops: const [0.0, 0.44, 0.62],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.6),
                radius: 0.72,
                colors:
                    night
                        ? const [
                          Color(0x10ffffff),
                          Color(0x08ffffff),
                          Color(0x00ffffff),
                        ]
                        : const [
                          Color(0x45ffffff),
                          Color(0x24ffffff),
                          Color(0x00ffffff),
                        ],
                stops: const [0.0, 0.26, 0.72],
              ),
            ),
          ),
          Center(
            child: FractionallySizedBox(
              widthFactor: logoScale,
              heightFactor: logoScale,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Transform.translate(
                    offset: Offset(
                      0,
                      night ? darkShadowOffset : lightShadowOffset,
                    ),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: night ? darkShadowBlur : lightShadowBlur,
                        sigmaY: night ? darkShadowBlur : lightShadowBlur,
                      ),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          night
                              ? const Color(0x42000000)
                              : const Color(0x18263952),
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          'assets/branding/app-icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: logoOpacity,
                    child: Image.asset(
                      'assets/branding/app-icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
