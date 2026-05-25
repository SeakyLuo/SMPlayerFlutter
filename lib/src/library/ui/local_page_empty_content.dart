import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/widgets.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'local_page_shell.dart';

Widget buildLocalPageEmptyContent({
  required SmPlayerI18n i18n,
  required LibraryContentData snapshot,
  required String searchQuery,
  required VoidCallback onOpenSettings,
}) {
  if (snapshot.songs.isEmpty) {
    return LocalPageEmptyState(
      title: i18n.t('local.noSongsScanned'),
      message: i18n.t('local.scanPopulate'),
      action: LocalCommandButton(
        onPressed: onOpenSettings,
        icon: FluentIcons.settings_20_regular,
        label: i18n.t('local.goToSettings'),
      ),
    );
  }

  if (searchQuery.trim().isNotEmpty) {
    return LocalPageEmptyState(
      title: i18n.t('local.noSongsBranch', {'query': searchQuery}),
      message: i18n.t('local.searchHelp'),
    );
  }

  return const SizedBox.expand();
}
