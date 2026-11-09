import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_i18n.dart';
import 'music_source_providers.dart';

class MusicSourcePlaylistNotice extends ConsumerWidget {
  const MusicSourcePlaylistNotice({
    super.key,
    required this.visible,
    required this.total,
  });
  final int visible;
  final int total;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (visible == total) return const SizedBox.shrink();
    final i18n = context.smPlayerI18n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Wrap(
        spacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            visible == 0
                ? i18n.t('share.noSourceSongs')
                : i18n.t('share.visibleCount', {
                  'visible': visible,
                  'total': total,
                }),
          ),
          TextButton(
            onPressed: () => ref.read(musicShareProvider).selectSource('all'),
            child: Text(i18n.t('share.showAll')),
          ),
        ],
      ),
    );
  }
}
