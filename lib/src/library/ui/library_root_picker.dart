import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../i18n/app_i18n.dart';
import '../../platform/desktop_feature_service.dart';

Future<String?> pickMusicLibraryRoot(SmPlayerI18n i18n, {String? currentPath}) {
  return Platform.isMacOS || Platform.isWindows
      ? pickDirectoryFromDesktopShell(
        title: i18n.t('local.chooseMusicLibraryFolderDialogTitle'),
        buttonLabel: i18n.t('local.chooseMusicLibraryFolderDialogButton'),
        defaultPath: currentPath == '' ? null : currentPath,
        locale: i18n.locale,
      )
      : FilePicker.getDirectoryPath();
}
