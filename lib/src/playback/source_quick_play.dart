import '../app/undoable_notification.dart';
import '../i18n/app_i18n.dart';
import '../remote/music_share_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../library/data/library_providers.dart';
import '../remote/music_source_providers.dart';
import 'quick_play_model.dart';

Future<List<int>> sourceQuickPlaySongIds({
  required WidgetRef ref,
  required String unknownAlbumName,
  int randomLimit = quickPlayDefaultLimit,
}) async {
  final container = ProviderScope.containerOf(ref.context, listen: false);
  final context = ref.context;
  try {
    final source = container.read(selectedLibraryDataSourceProvider);
    final songs = await source.selectSongIds(
      LibrarySelectionRequest(
        LibrarySelectionKind.quick,
        limit: randomLimit,
        unknownAlbumName: unknownAlbumName,
      ),
    );
    return songs;
  } catch (error) {
    if (context.mounted) {
      showAppNotification(
        context: context,
        message: context.smPlayerI18n.t(
          error is MusicShareException
              ? error.messageKey
              : 'share.connectionFailed',
        ),
      );
    }
    return [];
  }
}
