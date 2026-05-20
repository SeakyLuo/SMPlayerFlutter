import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media_control_model.dart';

final mediaControlControllerProvider =
    ChangeNotifierProvider<MediaControlController>((ref) {
      return MediaControlController();
    });
