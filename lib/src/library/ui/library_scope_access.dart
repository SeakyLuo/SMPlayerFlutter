import '../../remote/music_source_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/undoable_notification.dart';
import '../../i18n/app_i18n.dart';
import '../data/library_providers.dart';
import 'library_query_failure.dart';

AsyncValue<List<int>> watchLibraryScopeIds(
  WidgetRef ref,
  LibraryDataQuery query,
) {
  final provider = libraryScopeIdsProvider(query);
  final container = ProviderScope.containerOf(ref.context, listen: false);
  listenLibraryQueryFailure(
    ref,
    provider,
    () => container.invalidate(provider),
  );
  return ref.watch(provider);
}

void listenLibraryPageFailure(WidgetRef ref, LibraryDataQuery query) {
  final source =
      query.kind == LibraryQueryKind.queue
          ? 'local'
          : ref.read(selectedLibraryDataSourceProvider).source.deviceId;
  final bound = query.withPage(source: source);
  final container = ProviderScope.containerOf(ref.context, listen: false);
  listenLibraryQueryFailure(
    ref,
    query.limit == null
        ? libraryPageQueryProvider(bound)
        : libraryPagedQueryProvider(bound),
    () {
      container.invalidate(
        query.limit == null
            ? libraryPageQueryProvider(bound)
            : libraryPagedQueryProvider(bound),
      );
    },
  );
}

void listenLibraryQueryFailure<T>(
  WidgetRef ref,
  ProviderListenable<AsyncValue<T>> provider,
  VoidCallback retry,
) {
  ref.listen(provider, (previous, next) {
    if (next.isLoading ||
        !next.hasError ||
        previous?.isLoading == false &&
            identical(previous?.error, next.error)) {
      return;
    }
    final context = ref.context;
    final container = ProviderScope.containerOf(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final error = next.error;
      showAppNotification(
        context: context,
        message: context.smPlayerI18n.t(
          libraryQueryFailureMessage(error!, next.stackTrace!),
        ),
        actionLabel: context.smPlayerI18n.t('share.retryDirectory'),
        onAction: () {
          if (container.read(libraryLoadedDataProvider).hasError) {
            container.invalidate(libraryLoadedDataProvider);
          }
          retry();
        },
      );
    });
  });
}
