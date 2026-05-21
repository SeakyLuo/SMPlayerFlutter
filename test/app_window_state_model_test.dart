import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/app/app_window_state_model.dart';

void main() {
  test(
    'main window bounds parse and serialize mirror Electron state shape',
    () {
      final bounds = parseMainWindowBounds(
        '{"x":10,"y":20,"width":1200,"height":800}',
      );

      expect(bounds, const Rect.fromLTWH(10, 20, 1200, 800));
      expect(
        serializeMainWindowBounds(const Rect.fromLTWH(10, 20, 1200, 800)),
        '{"x":10.0,"y":20.0,"width":1200.0,"height":800.0}',
      );
    },
  );

  test('initial main window bounds center in the primary work area', () {
    final bounds = resolveInitialMainWindowBounds(null, [
      const Rect.fromLTWH(100, 50, 1600, 1000),
    ]);

    expect(bounds, const Rect.fromLTWH(170, 80, 1460, 940));
  });

  test(
    'saved main window bounds clamp to matching work area like Electron',
    () {
      final bounds = resolveInitialMainWindowBounds(
        const Rect.fromLTWH(2600, -200, 300, 300),
        [
          const Rect.fromLTWH(0, 0, 1920, 1040),
          const Rect.fromLTWH(1920, 0, 1280, 720),
        ],
      );

      expect(bounds, const Rect.fromLTWH(2600, 0, 506, 720));
    },
  );
}
