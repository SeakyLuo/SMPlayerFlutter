import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/quick_jump_tooltip.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'quickJump.disabled': 'No {basis} {target} starts with {group}',
      'quickJump.enabled': 'Jump to {basis} {target} starting with {group}',
      'quickJump.letterGroup': '{key}',
      'quickJump.symbolGroup': 'numbers or symbols',
    },
  );

  test('getQuickJumpTooltip mirrors Electron quick jump i18n', () {
    expect(
      getQuickJumpTooltip(
        key: 'A',
        enabled: true,
        targetName: 'songs',
        basisName: 'artist',
        i18n: i18n,
      ),
      'Jump to artist songs starting with A',
    );

    expect(
      getQuickJumpTooltip(
        key: '#',
        enabled: false,
        targetName: 'albums',
        basisName: 'album',
        i18n: i18n,
      ),
      'No album albums starts with numbers or symbols',
    );
  });
}
