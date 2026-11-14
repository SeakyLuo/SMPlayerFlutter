import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/app_i18n.dart';
import '../../remote/music_share_dialog.dart';
import '../../remote/music_source_providers.dart';
import 'popup_dialog.dart';

class LibraryLoadFailure extends ConsumerWidget {
  const LibraryLoadFailure({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remote = ref.watch(
      musicShareProvider.select((share) => share.selectedSource != 'local'),
    );
    final i18n = context.smPlayerI18n;
    return Center(
      child: PopupDialogActionButton(
        primary: true,
        label: i18n.t(remote ? 'share.connectComputer' : 'common.settings'),
        icon:
            remote
                ? FluentIcons.plug_connected_24_regular
                : FluentIcons.settings_24_regular,
        onPressed:
            () =>
                remote
                    ? showMusicShareDialog(context)
                    : context.go('/settings'),
      ),
    );
  }
}
