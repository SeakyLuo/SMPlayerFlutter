import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:screen_retriever/screen_retriever.dart' as screen;
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/app_window_state_model.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page_model.dart'
    as artists_model;
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart';
import 'package:smplayer_flutter/src/platform/external_open_model.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

part 'desktop_shell_utils.dart';
part 'desktop_feature_models.dart';
part 'desktop_feature_service_impl.dart';
part 'desktop_notification_helpers.dart';

const desktopRecentSongLimit = 10;
const windowsAppUserModelId = 'com.seaky.simplemelodyplayer';
const windowsToastActivationUri = 'smplayer://show-window';
const desktopLyricsOffsetMinMs = -10000;
const desktopLyricsOffsetMaxMs = 10000;
const _desktopFeatureChannel = MethodChannel(
  'smplayer_flutter/desktop_features',
);
const _miniModeWindowSize = Size(360, 360);
const _defaultWindowMinimumSize = Size(506, 840);
