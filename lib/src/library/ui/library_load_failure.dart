import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_providers.dart';
import '../../remote/music_source_providers.dart';
import 'popup_dialog.dart';

class LibraryLoadFailure extends ConsumerWidget {
  const LibraryLoadFailure({super.key, required this.onRetry});
  final VoidCallback onRetry;

  factory LibraryLoadFailure.forQuery(WidgetRef ref, LibraryDataQuery query) {
    final source =
        query.kind == LibraryQueryKind.queue
            ? 'local'
            : ref.read(selectedLibraryDataSourceProvider).source.deviceId;
    final scoped = query.withPage(source: source);
    return LibraryLoadFailure(
      onRetry: () {
        if (scoped.limit == null) {
          ref.invalidate(libraryPageQueryProvider(scoped));
        } else {
          ref.invalidate(libraryPagedQueryProvider(scoped));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = context.smPlayerI18n;
    return Center(
      child: PopupDialogActionButton(
        primary: true,
        label: i18n.t('share.retryDirectory'),
        icon: FluentIcons.arrow_clockwise_24_regular,
        onPressed: () {
          final container = ProviderScope.containerOf(context, listen: false);
          if (container.exists(libraryLoadedDataProvider) &&
              ref.read(libraryLoadedDataProvider).hasError) {
            ref.invalidate(libraryLoadedDataProvider);
          }
          onRetry();
        },
      ),
    );
  }
}
