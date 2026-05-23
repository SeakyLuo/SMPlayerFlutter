import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/splash_screen.dart';

void main() {
  testWidgets('splash renders the app logo and title', (tester) async {
    await tester.pumpWidget(const SmPlayerSplashScreen());

    expect(
      find.image(const AssetImage('assets/branding/app-icon.png')),
      findsOneWidget,
    );
    expect(find.text('Simple Melody Player'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  test('splash resolves separate day and night palettes', () {
    expect(
      SmPlayerSplashColors.resolve(Brightness.light).background,
      isNot(SmPlayerSplashColors.resolve(Brightness.dark).background),
    );
  });

  testWidgets('splash applies night brightness to loading theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      const SmPlayerSplashScreen(brightness: Brightness.dark),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.brightness, Brightness.dark);
    expect(
      app.theme!.progressIndicatorTheme.color,
      SmPlayerSplashColors.night.accent,
    );
    expect(
      app.theme!.progressIndicatorTheme.linearTrackColor,
      SmPlayerSplashColors.night.progressTrack,
    );
  });

  test('splash app name follows the platform locale family', () {
    expect(SmPlayerSplashAppName.resolve(const Locale('zh', 'CN')), '简音播放器');
    expect(
      SmPlayerSplashAppName.resolve(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      '簡音播放器',
    );
    expect(
      SmPlayerSplashAppName.resolve(const Locale('en', 'US')),
      'Simple Melody Player',
    );
  });
}
