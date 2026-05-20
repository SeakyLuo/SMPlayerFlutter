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
}
