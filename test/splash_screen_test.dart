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
