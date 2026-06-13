import 'dart:ui' show ImageFilter;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smplayer_flutter/src/app/main_navigation_view.dart';
import 'package:smplayer_flutter/src/app/navigation_icon_button.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
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

class SmPlayerWorkspace extends ConsumerStatefulWidget {
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
  ConsumerState<SmPlayerWorkspace> createState() => _SmPlayerWorkspaceState();
}

class _SmPlayerWorkspaceState extends ConsumerState<SmPlayerWorkspace> {
  final _workspaceAppBarPortals =
      <_WorkspaceAppBarPortalKey, WorkspaceAppBarPortalEntry>{};

  @override
  Widget build(BuildContext context) {
    final shellColors = ShellThemeColors.of(context);
    final i18n =
        ref.watch(smPlayerI18nProvider).valueOrNull ?? context.smPlayerI18n;
    final snapshot = ref.watch(libraryContentDataProvider).valueOrNull;
    final title = _workspaceTitle(
      path: widget.currentPath,
      snapshot: snapshot,
      i18n: i18n,
    );
    final synchronousPortalTitle = _synchronousWorkspaceAppBarTitle(
      location: widget.currentLocation,
      snapshot: snapshot,
      i18n: i18n,
    );
    final rawHeaderedPlaylistAppBar = ref.watch(
      headeredPlaylistAppBarPortalProvider,
    );
    final headeredPlaylistAppBar =
        rawHeaderedPlaylistAppBar != null &&
                (rawHeaderedPlaylistAppBar.routeLocation == null ||
                    rawHeaderedPlaylistAppBar.routeLocation ==
                        widget.currentLocation)
            ? rawHeaderedPlaylistAppBar
            : null;
    final workspaceAppBarPortal = ref.watch(workspaceAppBarPortalProvider);
    _rememberWorkspaceAppBarPortal(workspaceAppBarPortal);
    final currentUri = Uri.parse(widget.currentLocation);
    final currentRoutePath = currentUri.path;
    final currentWorkspaceAppBarPortal = _workspaceAppBarPortalFor(
      routePath: currentRoutePath,
      routeLocation: widget.currentLocation,
    );
    final localTitleContent =
        currentRoutePath == '/local' &&
                snapshot != null &&
                snapshot.rootPath.isNotEmpty
            ? LocalTitleGrid(
              songs: snapshot.songs,
              folders: snapshot.folders,
              i18n: i18n,
              rootPath: snapshot.rootPath,
              currentRelativePath: currentUri.queryParameters['path'] ?? '',
              compact: widget.showNavigationAppBar,
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
        widget.showNavigationAppBar
            ? shellColors.workspaceSolidSurface
            : shellColors.workspaceSurface;
    final page = _WorkspacePageSurface(
      title: title,
      synchronousPortalTitle: synchronousPortalTitle,
      headerHeight: widget.headerHeight,
      showNavigationAppBar: widget.showNavigationAppBar,
      navigationMenuLabel: widget.navigationMenuLabel,
      onNavigationMenuPressed: widget.onNavigationMenuPressed,
      routeSurface: routeSurface,
      workspaceAppBarPortal: currentWorkspaceAppBarPortal,
      localTitleContent: localTitleContent,
      headeredPlaylistAppBar: headeredPlaylistAppBar,
      navigationAppBarTopInset: widget.navigationAppBarTopInset,
      child: widget.child ?? const SizedBox.shrink(),
    );
    final workspace = DecoratedBox(
      decoration: _workspaceDecoration(shellColors: shellColors),
      child: ClipRect(child: page),
    );
    return RepaintBoundary(child: workspace);
  }

  void _rememberWorkspaceAppBarPortal(WorkspaceAppBarPortalEntry? entry) {
    if (entry == null) {
      return;
    }
    _workspaceAppBarPortals[_WorkspaceAppBarPortalKey(
          routePath: entry.routePath,
          routeLocation: entry.routeLocation,
        )] =
        entry;
  }

  WorkspaceAppBarPortalEntry? _workspaceAppBarPortalFor({
    required String routePath,
    required String routeLocation,
  }) {
    return _workspaceAppBarPortals[_WorkspaceAppBarPortalKey(
          routePath: routePath,
          routeLocation: routeLocation,
        )] ??
        _workspaceAppBarPortals[_WorkspaceAppBarPortalKey(
          routePath: routePath,
          routeLocation: null,
        )];
  }
}

class _WorkspaceAppBarPortalKey {
  const _WorkspaceAppBarPortalKey({
    required this.routePath,
    required this.routeLocation,
  });

  final String routePath;
  final String? routeLocation;

  @override
  bool operator ==(Object other) {
    return other is _WorkspaceAppBarPortalKey &&
        other.routePath == routePath &&
        other.routeLocation == routeLocation;
  }

  @override
  int get hashCode => Object.hash(routePath, routeLocation);
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
    required this.synchronousPortalTitle,
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
  final String? synchronousPortalTitle;
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
            : workspaceAppBarPortal?.title ?? synchronousPortalTitle ?? title);
    final content = WorkspaceNavigationAppBarScope(
      active: showNavigationAppBar || localTitleContent != null,
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
                  topInset: 0,
                )
              else if (!overlayNavigationAppBar && localTitleContent != null)
                _WorkspaceLocalHeader(child: localTitleContent!)
              else if (!overlayNavigationAppBar && pageTitle.isNotEmpty)
                _WorkspaceHeader(title: pageTitle, height: headerHeight),
              Expanded(child: content),
            ],
          ),
          if (overlayNavigationAppBar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: navigationAppBarTopInset + 40,
              child: _WorkspaceNavigationAppBar(
                headeredPlaylistAppBar: headeredPlaylistAppBar,
                title: headeredPlaylistAppBar!.title,
                navigationMenuLabel: navigationMenuLabel,
                onNavigationMenuPressed: onNavigationMenuPressed,
                titleContent: null,
                actions: headeredPlaylistCommandBar,
                bottomContent: null,
                topInset: navigationAppBarTopInset,
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

class _WorkspaceLocalHeader extends StatelessWidget {
  const _WorkspaceLocalHeader({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 18),
        child: child,
      ),
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
    required this.topInset,
  });

  final HeaderedPlaylistAppBarPortalEntry? headeredPlaylistAppBar;
  final String title;
  final String navigationMenuLabel;
  final VoidCallback onNavigationMenuPressed;
  final Widget? titleContent;
  final Widget? actions;
  final Widget? bottomContent;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final shellColors = ShellThemeColors.of(context);
    final navigationColors = MainNavigationViewColors.of(context);
    final isHeaderedPlaylist = headeredPlaylistAppBar != null;
    final titleColor =
        isHeaderedPlaylist
            ? _immersiveAppBarForeground(context)
            : shellColors.headerText;
    final effectiveActions =
        _isEmptyWorkspaceAppBarActions(actions) ? null : actions;
    final topRow = SizedBox(
      height: SmPlayerShellMetrics.navigationButtonSize,
      child: Padding(
        padding: const EdgeInsets.only(
          left: SmPlayerShellMetrics.navigationPaneHorizontalPadding,
          right: 14,
        ),
        child: Row(
          children: [
            SmPlayerNavigationIconButton(
              key: SmPlayerShellWorkspaceKeys.navigationMenuButton,
              icon: FluentIcons.line_horizontal_3_24_regular,
              tooltip: navigationMenuLabel,
              onPressed: onNavigationMenuPressed,
              foreground: navigationColors.textStrong,
              mutedForeground: navigationColors.textMuted,
              hoverForeground: navigationColors.highlightText,
              hoverColor: navigationColors.iconButtonHover,
              collapsedHoverColor: navigationColors.collapsedHover,
            ),
            const SizedBox(width: 10),
            Expanded(
              child:
                  titleContent != null
                      ? titleContent!
                      : effectiveActions == null
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
                                SizedBox(
                                  width: actionWidth,
                                  child: effectiveActions,
                                ),
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
    final appBarContent =
        bottomContent == null
            ? SizedBox(
              height: topInset + 40,
              child: Column(
                children: [
                  if (topInset > 0) SizedBox(height: topInset),
                  topRow,
                ],
              ),
            )
            : DecoratedBox(
              decoration: BoxDecoration(
                color: shellColors.workspaceSolidSurface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha:
                          Theme.of(context).brightness == Brightness.dark
                              ? 0.18
                              : 0.06,
                    ),
                    offset: const Offset(0, 8),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: SizedBox(
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
              ),
            );
    if (!isHeaderedPlaylist) {
      return Material(
        color: shellColors.workspaceSolidSurface,
        child: appBarContent,
      );
    }

    final entry = headeredPlaylistAppBar!;
    final progress = entry.collapseProgress.clamp(0.0, 1.0);
    return ClipRect(
      child: BackdropFilter(
        key: const ValueKey('WorkspaceNavigationAppBar.ImmersiveSurface'),
        filter: ImageFilter.blur(sigmaX: 18 * progress, sigmaY: 18 * progress),
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: _immersiveAppBarDecoration(context, entry),
            child: appBarContent,
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
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.alphaBlend(
          highlight,
          entry.coverColor,
        ).withValues(alpha: 0.24 * progress),
        entry.coverColor.withValues(alpha: 0.14 * progress),
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

bool _isEmptyWorkspaceAppBarActions(Widget? actions) {
  return actions is SizedBox && actions.width == 0 && actions.height == 0;
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

String? _synchronousWorkspaceAppBarTitle({
  required String location,
  required LibraryContentData? snapshot,
  required SmPlayerI18n i18n,
}) {
  final uri = Uri.parse(location);
  final path = uri.path;
  final isAlbumDetailRoute =
      path == '/albums' && uri.queryParameters.containsKey('album');
  if (isAlbumDetailRoute) {
    return null;
  }

  if (snapshot == null) {
    return switch (path) {
      '/songs' => i18n.t('library.allSongs'),
      '/albums' => i18n.t('library.allAlbums'),
      '/playlists' => i18n.t('common.playlists'),
      '/now-playing' => i18n.t('common.nowPlaying'),
      '/search' => _searchWorkspaceTitle(uri, i18n),
      _ => null,
    };
  }

  return switch (path) {
    '/songs' =>
      snapshot.showCount
          ? i18n.t('library.allSongsWithCount', {
            'count': snapshot.songs.length,
          })
          : i18n.t('library.allSongs'),
    '/albums' =>
      snapshot.showCount
          ? i18n.t('library.allAlbumsWithCount', {
            'count': _albumCount(snapshot, i18n),
          })
          : i18n.t('library.allAlbums'),
    '/playlists' =>
      snapshot.showCount
          ? i18n.t('search.playlistsWithCount', {
            'count':
                snapshot.playlists
                    .where((playlist) => !playlist.isBuiltIn)
                    .length,
          })
          : i18n.t('common.playlists'),
    '/now-playing' =>
      snapshot.showCount
          ? i18n.t('nowPlaying.titleWithCount', {
            'count': snapshot.nowPlaying.songIds.length,
          })
          : i18n.t('common.nowPlaying'),
    '/search' => _searchWorkspaceTitle(uri, i18n),
    _ => null,
  };
}

int _albumCount(LibraryContentData snapshot, SmPlayerI18n i18n) {
  return {
    for (final song in snapshot.songs)
      song.album.isEmpty ? i18n.t('common.albumUnknown') : song.album,
  }.length;
}

String _searchWorkspaceTitle(Uri uri, SmPlayerI18n i18n) {
  final query = uri.queryParameters['query']?.trim() ?? '';
  final folder = uri.queryParameters['folder'] ?? '';
  if (query.isNotEmpty && folder.isNotEmpty) {
    return i18n.t('search.directoryResultOf', {
      'query': query,
      'folder': folder.split('/').last,
    });
  }
  return query.isNotEmpty
      ? i18n.t('search.resultOf', {'query': query})
      : i18n.t('search.resultTitle');
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

  if (path.startsWith('/immersive-mode')) {
    return '';
  }

  if (path.startsWith('/now-playing')) {
    return '';
  }

  if (path.startsWith('/hidden-folders')) {
    return i18n.t('local.hiddenFolders');
  }

  if (path.startsWith('/recent')) {
    final hasRecentContent =
        snapshot != null &&
        (snapshot.songs.isNotEmpty ||
            snapshot.recentSongs.isNotEmpty ||
            snapshot.recentPlaylists.isNotEmpty ||
            snapshot.recentAlbums.isNotEmpty ||
            snapshot.recentArtists.isNotEmpty ||
            snapshot.recentSearches.isNotEmpty);
    return hasRecentContent ? '' : i18n.t('common.recent');
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
