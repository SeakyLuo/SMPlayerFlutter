import 'dart:ui' show ImageFilter;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/app/workspace_app_bar_portal.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/headered_playlist_app_bar_portal.dart';
import 'package:smplayer_flutter/src/library/ui/local_title_grid.dart';

class SmPlayerShellWorkspaceKeys {
  const SmPlayerShellWorkspaceKeys._();

  static const navigationMenuButton = ValueKey(
    'SmPlayerShell.MinimalMenuButton',
  );
}

class SmPlayerWorkspace extends ConsumerWidget {
  const SmPlayerWorkspace({
    super.key,
    required this.currentPath,
    required this.currentLocation,
    required this.headerHeight,
    required this.showNavigationAppBar,
    required this.navigationMenuLabel,
    required this.onNavigationMenuPressed,
    required this.navigationAppBarTopInset,
    this.child,
  });

  final String currentPath;
  final String currentLocation;
  final double headerHeight;
  final bool showNavigationAppBar;
  final String navigationMenuLabel;
  final VoidCallback onNavigationMenuPressed;
  final double navigationAppBarTopInset;
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shellColors = ShellThemeColors.of(context);
    final i18n =
        ref.watch(smPlayerI18nProvider).valueOrNull ?? context.smPlayerI18n;
    final snapshot = ref.watch(libraryContentDataProvider).valueOrNull;
    final title = _workspaceTitle(
      path: currentPath,
      snapshot: snapshot,
      i18n: i18n,
    );
    final rawHeaderedPlaylistAppBar = ref.watch(
      headeredPlaylistAppBarPortalProvider,
    );
    final headeredPlaylistAppBar =
        rawHeaderedPlaylistAppBar != null &&
                (rawHeaderedPlaylistAppBar.routeLocation == null ||
                    rawHeaderedPlaylistAppBar.routeLocation == currentLocation)
            ? rawHeaderedPlaylistAppBar
            : null;
    final workspaceAppBarPortal = ref.watch(workspaceAppBarPortalProvider);
    final currentUri = Uri.parse(currentLocation);
    final currentRoutePath = currentUri.path;
    final currentWorkspaceAppBarPortal =
        workspaceAppBarPortal != null &&
                workspaceAppBarPortal.routePath == currentRoutePath &&
                (workspaceAppBarPortal.routeLocation == null ||
                    workspaceAppBarPortal.routeLocation == currentLocation)
            ? workspaceAppBarPortal
            : null;
    final localTitleContent =
        showNavigationAppBar &&
                currentRoutePath == '/local' &&
                snapshot != null &&
                snapshot.rootPath.isNotEmpty
            ? LocalTitleGrid(
              songs: snapshot.songs,
              folders: snapshot.folders,
              i18n: i18n,
              rootPath: snapshot.rootPath,
              currentRelativePath: currentUri.queryParameters['path'] ?? '',
              compact: true,
              onHiddenFoldersListButtonClick: () {
                context.go('/hidden-folders');
              },
              onOpenFolder: (targetRelativePath) {
                final query = <String, String>{};
                if (targetRelativePath.isNotEmpty) {
                  query['path'] = targetRelativePath;
                }
                final searchQuery = currentUri.queryParameters['query'];
                if (searchQuery != null && searchQuery.trim().isNotEmpty) {
                  query['query'] = searchQuery.trim();
                }
                context.go(
                  Uri(path: '/local', queryParameters: query).toString(),
                );
              },
            )
            : null;
    final routeSurface =
        showNavigationAppBar
            ? shellColors.workspaceSolidSurface
            : shellColors.workspaceSurface;
    final page = _WorkspacePageSurface(
      title: title,
      headerHeight: headerHeight,
      showNavigationAppBar: showNavigationAppBar,
      navigationMenuLabel: navigationMenuLabel,
      onNavigationMenuPressed: onNavigationMenuPressed,
      routeSurface: routeSurface,
      workspaceAppBarPortal: currentWorkspaceAppBarPortal,
      localTitleContent: localTitleContent,
      headeredPlaylistAppBar: headeredPlaylistAppBar,
      navigationAppBarTopInset: navigationAppBarTopInset,
      child: child ?? const SizedBox.shrink(),
    );
    final workspace = DecoratedBox(
      decoration: _workspaceDecoration(shellColors: shellColors),
      child: ClipRect(child: page),
    );
    return RepaintBoundary(child: workspace);
  }
}

BoxDecoration _workspaceDecoration({required ShellThemeColors shellColors}) {
  return BoxDecoration(
    boxShadow: [
      BoxShadow(
        color: shellColors.workspaceShadow,
        offset: const Offset(0, 22),
        blurRadius: 56,
      ),
    ],
  );
}

class _WorkspacePageSurface extends StatelessWidget {
  const _WorkspacePageSurface({
    required this.title,
    required this.headerHeight,
    required this.showNavigationAppBar,
    required this.navigationMenuLabel,
    required this.onNavigationMenuPressed,
    required this.routeSurface,
    required this.workspaceAppBarPortal,
    required this.localTitleContent,
    required this.headeredPlaylistAppBar,
    required this.navigationAppBarTopInset,
    required this.child,
  });

  final String title;
  final double headerHeight;
  final bool showNavigationAppBar;
  final String navigationMenuLabel;
  final VoidCallback onNavigationMenuPressed;
  final Color routeSurface;
  final WorkspaceAppBarPortalEntry? workspaceAppBarPortal;
  final Widget? localTitleContent;
  final HeaderedPlaylistAppBarPortalEntry? headeredPlaylistAppBar;
  final double navigationAppBarTopInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final overlayNavigationAppBar =
        showNavigationAppBar && headeredPlaylistAppBar != null;
    final headeredPlaylistCommandBar = headeredPlaylistAppBar?.commandBarBuilder
        ?.call(context);
    final pageTitle =
        headeredPlaylistAppBar?.title ??
        (workspaceAppBarPortal?.replacesTitle == true
            ? ''
            : workspaceAppBarPortal?.title ?? title);
    final content = WorkspaceNavigationAppBarScope(
      active: showNavigationAppBar,
      child: _WorkspaceContentMediaQuery(child: child),
    );
    return ColoredBox(
      color: routeSurface,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showNavigationAppBar && !overlayNavigationAppBar)
                _WorkspaceNavigationAppBar(
                  headeredPlaylistAppBar: headeredPlaylistAppBar,
                  title:
                      localTitleContent != null ||
                              pageTitle.isEmpty &&
                                  workspaceAppBarPortal?.replacesTitle == true
                          ? ''
                          : pageTitle,
                  navigationMenuLabel: navigationMenuLabel,
                  onNavigationMenuPressed: onNavigationMenuPressed,
                  titleContent:
                      localTitleContent ??
                      (workspaceAppBarPortal?.replacesTitle == true
                          ? workspaceAppBarPortal?.content
                          : null),
                  actions:
                      headeredPlaylistCommandBar ??
                      (workspaceAppBarPortal?.replacesTitle == true
                          ? null
                          : workspaceAppBarPortal?.content),
                  bottomContent: workspaceAppBarPortal?.bottomContent,
                )
              else if (pageTitle.isNotEmpty)
                _WorkspaceHeader(title: pageTitle, height: headerHeight),
              Expanded(child: content),
            ],
          ),
          if (overlayNavigationAppBar)
            Positioned(
              top: navigationAppBarTopInset,
              left: 0,
              right: 0,
              height: 40,
              child: _WorkspaceNavigationAppBar(
                headeredPlaylistAppBar: headeredPlaylistAppBar,
                title: headeredPlaylistAppBar!.title,
                navigationMenuLabel: navigationMenuLabel,
                onNavigationMenuPressed: onNavigationMenuPressed,
                titleContent: null,
                actions: headeredPlaylistCommandBar,
                bottomContent: null,
              ),
            ),
          if (!showNavigationAppBar && headeredPlaylistAppBar != null)
            _HeaderedPlaylistAppBarPortal(entry: headeredPlaylistAppBar!),
        ],
      ),
    );
  }
}

class _WorkspaceContentMediaQuery extends StatelessWidget {
  const _WorkspaceContentMediaQuery({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return MediaQuery(
          data: mediaQuery.copyWith(size: constraints.biggest),
          child: SizedBox.expand(child: child),
        );
      },
    );
  }
}

class _HeaderedPlaylistAppBarPortal extends StatelessWidget {
  const _HeaderedPlaylistAppBarPortal({required this.entry});

  final HeaderedPlaylistAppBarPortalEntry entry;

  @override
  Widget build(BuildContext context) {
    final shellColors = ShellThemeColors.of(context);
    return Positioned(
      key: const ValueKey('HeaderedPlaylist.AppBarPortal'),
      top: 8,
      left: 16,
      right: 8,
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: shellColors.headerText,
                fontSize: 18,
                height: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: entry.commandBarBuilder?.call(context),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceNavigationAppBar extends StatelessWidget {
  const _WorkspaceNavigationAppBar({
    required this.headeredPlaylistAppBar,
    required this.title,
    required this.navigationMenuLabel,
    required this.onNavigationMenuPressed,
    required this.titleContent,
    required this.actions,
    required this.bottomContent,
  });

  final HeaderedPlaylistAppBarPortalEntry? headeredPlaylistAppBar;
  final String title;
  final String navigationMenuLabel;
  final VoidCallback onNavigationMenuPressed;
  final Widget? titleContent;
  final Widget? actions;
  final Widget? bottomContent;

  @override
  Widget build(BuildContext context) {
    final shellColors = ShellThemeColors.of(context);
    final isHeaderedPlaylist = headeredPlaylistAppBar != null;
    final titleColor =
        isHeaderedPlaylist
            ? _immersiveAppBarForeground(context)
            : shellColors.headerText;
    final topRow = SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 14),
        child: Row(
          children: [
            Tooltip(
              message: navigationMenuLabel,
              waitDuration: const Duration(milliseconds: 450),
              child: InkWell(
                key: SmPlayerShellWorkspaceKeys.navigationMenuButton,
                borderRadius: BorderRadius.circular(10),
                hoverColor:
                    isHeaderedPlaylist
                        ? _immersiveAppBarHover(context)
                        : shellColors.headerText.withValues(alpha: 0.07),
                focusColor:
                    isHeaderedPlaylist
                        ? _immersiveAppBarHover(context)
                        : shellColors.headerText.withValues(alpha: 0.07),
                highlightColor:
                    isHeaderedPlaylist
                        ? _immersiveAppBarHover(context)
                        : shellColors.headerText.withValues(alpha: 0.07),
                onTap: onNavigationMenuPressed,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    FluentIcons.line_horizontal_3_24_regular,
                    size: 19,
                    color: titleColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child:
                  titleContent != null
                      ? titleContent!
                      : actions == null
                      ? _WorkspaceNavigationAppBarTitle(
                        title: title,
                        color: titleColor,
                      )
                      : LayoutBuilder(
                        builder: (context, constraints) {
                          const titleActionGap = 12.0;
                          const titleReserveWidth = 148.0;
                          final actionWidth =
                              (constraints.maxWidth -
                                      titleReserveWidth -
                                      titleActionGap)
                                  .clamp(0.0, 360.0)
                                  .toDouble();
                          return Row(
                            children: [
                              Expanded(
                                child: _WorkspaceNavigationAppBarTitle(
                                  title: title,
                                  color: titleColor,
                                ),
                              ),
                              if (actionWidth > 0) ...[
                                const SizedBox(width: titleActionGap),
                                SizedBox(width: actionWidth, child: actions!),
                              ],
                            ],
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
    final content =
        bottomContent == null
            ? topRow
            : SizedBox(
              height: 80,
              child: Column(
                children: [
                  topRow,
                  SizedBox(
                    key: const ValueKey('WorkspaceNavigationAppBar.Bottom'),
                    height: 40,
                    child: Material(
                      color: shellColors.workspaceSolidSurface,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: bottomContent!,
                      ),
                    ),
                  ),
                ],
              ),
            );
    if (!isHeaderedPlaylist) {
      return Material(color: shellColors.workspaceSolidSurface, child: content);
    }

    final entry = headeredPlaylistAppBar!;
    final progress = entry.collapseProgress.clamp(0.0, 1.0);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18 * progress, sigmaY: 18 * progress),
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: _immersiveAppBarDecoration(context, entry),
            child: content,
          ),
        ),
      ),
    );
  }
}

BoxDecoration _immersiveAppBarDecoration(
  BuildContext context,
  HeaderedPlaylistAppBarPortalEntry entry,
) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final progress = entry.collapseProgress.clamp(0.0, 1.0);
  final surface = dark ? const Color(0xff101419) : const Color(0xfff6f9fc);
  final shadowColor =
      dark
          ? Colors.white.withValues(alpha: 0.05 * progress)
          : const Color(0xff111827).withValues(alpha: 0.05 * progress);
  final highlight = Colors.white.withValues(alpha: 0.08 * progress);
  return BoxDecoration(
    color: surface.withValues(alpha: 0.20 * progress),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(
          highlight,
          entry.coverColor.withValues(alpha: 0.24 * progress),
        ),
        Color.alphaBlend(
          Colors.white.withValues(alpha: 0),
          entry.coverColor.withValues(alpha: 0.14 * progress),
        ),
      ],
    ),
    boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(0, 1))],
  );
}

Color _immersiveAppBarForeground(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xfff6f9fc)
      : const Color(0xff111827);
}

Color _immersiveAppBarHover(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return const Color(0xff0078d7).withValues(alpha: dark ? 0.18 : 0.12);
}

class _WorkspaceNavigationAppBarTitle extends StatelessWidget {
  const _WorkspaceNavigationAppBarTitle({
    required this.title,
    required this.color,
  });

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty) {
      return const SizedBox.expand();
    }
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 16,
        height: 1.1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.title, required this.height});

  final String title;
  final double height;

  @override
  Widget build(BuildContext context) {
    final shellColors = ShellThemeColors.of(context);
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 142, 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: shellColors.headerText,
              fontSize: 40,
              height: 1.1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

String _workspaceTitle({
  required String path,
  required LibraryContentData? snapshot,
  required SmPlayerI18n i18n,
}) {
  if (path.startsWith('/artists')) {
    return '';
  }

  if (path.startsWith('/albums')) {
    return '';
  }

  if (path.startsWith('/now-playing/full')) {
    return '';
  }

  if (path.startsWith('/now-playing')) {
    return '';
  }

  if (path.startsWith('/hidden-folders')) {
    return i18n.t('local.hiddenFolders');
  }

  if (path.startsWith('/recent')) {
    return '';
  }

  if (path.startsWith('/local')) {
    return snapshot != null && snapshot.rootPath.isEmpty
        ? i18n.t('common.local')
        : '';
  }

  if (path.startsWith('/playlists')) {
    return '';
  }

  if (path.startsWith('/favorites')) {
    return '';
  }

  if (path.startsWith('/search')) {
    return '';
  }

  if (path.startsWith('/settings')) {
    return i18n.t('common.settings');
  }

  return '';
}
