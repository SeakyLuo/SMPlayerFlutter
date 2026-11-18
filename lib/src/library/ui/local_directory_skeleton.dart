import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../i18n/app_i18n.dart';
import 'command_bar.dart';
import 'local_directory_count.dart';
import 'local_page_shell.dart';
import 'local_folder_grid_layout.dart';
import '../../app/loading_state.dart';
import '../../app/workspace_app_bar_portal.dart';

class LocalDirectorySkeleton extends StatelessWidget {
  const LocalDirectorySkeleton({super.key, this.includeHeader = false});
  final bool includeHeader;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final content = CustomScrollView(
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            if (compact)
              SliverList.builder(
                itemCount: 12,
                itemBuilder:
                    (context, index) => const SizedBox(
                      height: 46,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 30,
                              child: Center(
                                child: SmPlayerSkeletonBlock(
                                  width: 22,
                                  height: 22,
                                  radius: 4,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            SmPlayerSkeletonBlock(width: 160, height: 14),
                          ],
                        ),
                      ),
                    ),
              )
            else
              SliverToBoxAdapter(
                child: LocalFolderGridLayout(
                  children: [
                    for (
                      var i = 0;
                      i <
                          ((constraints.maxWidth + 30) / 210).floor().clamp(
                                1,
                                8,
                              ) *
                              2;
                      i++
                    )
                      Container(
                        width: 180,
                        height: 232,
                        padding: const EdgeInsets.all(10),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SmPlayerSkeletonBlock(
                              width: 160,
                              height: 160,
                              radius: 8,
                            ),
                            SizedBox(height: 12),
                            SizedBox(
                              height: 20.25,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SmPlayerSkeletonBlock(
                                  width: 112,
                                  height: 14,
                                ),
                              ),
                            ),
                            SizedBox(height: 3),
                            SizedBox(
                              height: 16.2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SmPlayerSkeletonBlock(
                                  width: 80,
                                  height: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
        if (!includeHeader) return content;
        return ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!WorkspaceNavigationAppBarScope.of(context))
                const SizedBox(
                  height: 42,
                  child: SmPlayerSkeletonBlock(height: 36, radius: 8),
                ),
              if (!WorkspaceNavigationAppBarScope.of(context))
                const SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.only(
                  left: compact ? 8 : 12,
                  right: localPageScrollbarGutter(compact),
                ),
                child: CommandBar(
                  contentSizing: CommandBarContentSizing.intrinsic,
                  overflowReserve: compact ? 44 : 0,
                  overflowLabel: context.smPlayerI18n.t('player.more'),
                  content: const LocalDirectoryCount(loading: true),
                  children: [
                    CommandBarButton(
                      useShuffleIcon: true,
                      label: context.smPlayerI18n.t('nowPlaying.randomPlay'),
                    ),
                    CommandBarButton(
                      icon: FluentIcons.arrow_sync_24_regular,
                      label: context.smPlayerI18n.t(
                        compact
                            ? 'local.updateFolderShort'
                            : 'local.updateFolder',
                      ),
                    ),
                    CommandBarButton(
                      icon: FluentIcons.arrow_sort_24_regular,
                      label: context.smPlayerI18n.t('common.sort'),
                    ),
                    CommandBarButton(
                      icon: FluentIcons.add_24_regular,
                      label: context.smPlayerI18n.t('local.newFolder'),
                    ),
                    CommandBarButton(
                      icon: FluentIcons.multiselect_ltr_24_regular,
                      label: context.smPlayerI18n.t('albums.multiSelect'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: compact ? 8 : 16),
              Expanded(child: content),
            ],
          ),
        );
      },
    ),
  );
}
