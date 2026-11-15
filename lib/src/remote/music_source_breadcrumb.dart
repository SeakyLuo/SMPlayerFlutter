import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../i18n/app_i18n.dart';
import '../library/ui/menu_flyout.dart';
import '../library/ui/breadcrumb_segment.dart';
import 'music_source_providers.dart';
import 'music_source_selector.dart';

class MusicSourceBreadcrumb extends ConsumerWidget {
  const MusicSourceBreadcrumb({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final share = ref.watch(musicShareProvider);
    if (share.peers.isEmpty) return const SizedBox.shrink();
    final label =
        share.selectedSource == 'local'
            ? context.smPlayerI18n.t('share.localSource')
            : share.peers
                .firstWhere((peer) => peer.id == share.selectedSource)
                .name;
    return Builder(
      builder:
          (anchor) => BreadcrumbSegmentSurface(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final sources = {
                  'local',
                  ...share.peers.map((peer) => peer.id),
                };
                final menu =
                    buildMusicSourceMenuItem(
                      context,
                      onSelectSource: (source) async {
                        if (source == share.selectedSource) return;
                        final router = GoRouter.of(context);
                        await share.selectSource(source);
                        router.go('/local');
                      },
                    )!;
                showMenuFlyout(
                  anchor,
                  items:
                      menu.submenu
                          .where((item) => sources.contains(item.key))
                          .toList(),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BreadcrumbLabel(label: label, compact: compact),
                  SizedBox(
                    width: 22,
                    height: compact ? 36 : 32,
                    child: const Icon(
                      FluentIcons.chevron_right_16_regular,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
