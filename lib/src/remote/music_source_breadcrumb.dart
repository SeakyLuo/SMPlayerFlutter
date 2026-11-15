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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(
          builder:
              (anchor) => ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: BreadcrumbSegmentSurface(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final menu =
                          buildMusicSourceMenuItem(
                            context,
                            onSelectSource: (source) async {
                              if (source == share.selectedSource) return;
                              await share.selectSource(source);
                              if (context.mounted) context.go('/local');
                            },
                          )!;
                      showMenuFlyout(anchor, items: menu.submenu);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: BreadcrumbLabel(
                            label: label,
                            compact: compact,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          FluentIcons.chevron_down_16_regular,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ),
        const Icon(FluentIcons.chevron_right_16_regular, size: 16),
        const SizedBox(width: 4),
      ],
    );
  }
}
