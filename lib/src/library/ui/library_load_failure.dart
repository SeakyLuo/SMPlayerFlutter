import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/app_i18n.dart';
import '../../remote/remote_page_access.dart';
import '../data/library_providers.dart';
import '../../remote/music_source_providers.dart';
import 'popup_dialog.dart';

class LibraryLoadFailure extends ConsumerWidget {
  const LibraryLoadFailure({super.key, this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remote = ref.watch(
      musicShareProvider.select((share) => share.selectedSource != 'local'),
    );
    final i18n = context.smPlayerI18n;
    return Center(
      child: PopupDialogActionButton(
        primary: true,
        label: i18n.t('share.retryDirectory'),
        icon: FluentIcons.arrow_clockwise_24_regular,
        onPressed: () {
          if (ref.read(libraryLoadedDataProvider).hasError) {
            ref.invalidate(libraryLoadedDataProvider);
          }
          final retry =
              onRetry ??
              (remote
                  ? RemotePageAccessScope.of(context).retry
                  : () => invalidateLibraryQueries(ref.invalidate));
          retry();
        },
      ),
    );
  }
}
