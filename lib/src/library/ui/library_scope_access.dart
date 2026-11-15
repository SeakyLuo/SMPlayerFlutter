import '../../remote/music_source_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/undoable_notification.dart';
import '../../i18n/app_i18n.dart';
import '../../remote/music_share_models.dart';
import '../data/library_providers.dart';

AsyncValue<List<int>> watchLibraryScopeIds(
  WidgetRef ref,
  LibraryDataQuery query,
) {
  final provider = libraryScopeIdsProvider(query);
  ref.listen(provider, (previous, next) {
    if (!next.hasError || identical(previous?.error, next.error)) return;
    final context = ref.context;
    final container = ProviderScope.containerOf(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final error = next.error;
      showAppNotification(
        context: context,
        message: context.smPlayerI18n.t(
          error is MusicShareException
              ? error.messageKey
              : 'share.connectionFailed',
        ),
        actionLabel: context.smPlayerI18n.t('share.retryDirectory'),
        onAction: () => container.invalidate(provider),
      );
    });
  });
  return ref.watch(provider);
}

void listenLibraryPageFailure(WidgetRef ref, LibraryDataQuery query) {
  ref.listen(browsingLibraryPageProvider(query), (previous, next) {
    if (!next.hasError || identical(previous?.error, next.error)) return;
    final context = ref.context;
    final container = ProviderScope.containerOf(context, listen: false);
    final source =
        query.kind == LibraryQueryKind.queue
            ? 'local'
            : ref.read(selectedLibraryDataSourceProvider).source.deviceId;
    final bound = query.withPage(source: source);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final error = next.error;
      showAppNotification(
        context: context,
        message: context.smPlayerI18n.t(
          error is MusicShareException
              ? error.messageKey
              : 'share.connectionFailed',
        ),
        actionLabel: context.smPlayerI18n.t('share.retryDirectory'),
        onAction:
            () => container.invalidate(
              query.limit == null
                  ? libraryPageQueryProvider(bound)
                  : libraryPagedQueryProvider(bound),
            ),
      );
    });
  });
}
