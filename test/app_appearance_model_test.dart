import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

void main() {
  test('appAccentColor mirrors Electron theme color parsing', () {
    expect(appAccentColor('#112233'), const Color(0xff112233));
  });

  test(
    'buildSmPlayerTheme applies Electron night mode and accent settings',
    () {
      final theme = buildSmPlayerTheme(
        const SettingsSnapshot.defaults().copyWith(
          themeColor: '#112233',
          nightMode: NightMode.onMode,
        ),
      );

      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, isNot(equals(const Color(0xff0078d7))));
      expect(theme.progressIndicatorTheme.color, const Color(0xff112233));
    },
  );
}
