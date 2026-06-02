import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/main_navigation_view.dart';
import 'package:smplayer_flutter/src/app/shell_colors.dart';
import 'package:smplayer_flutter/src/app/shell_layout_state.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/app/shell_widgets.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';

class ShellNavigationHost extends ConsumerWidget {
  const ShellNavigationHost({
    super.key,
    required this.layout,
    required this.colors,
    required this.searchText,
    required this.onPaneToggle,
    required this.onGoBack,
    required this.onSearchTextChanged,
    required this.onSearchCommitted,
    required this.onSearchCleared,
    required this.searchHistoryDismissEpoch,
    required this.onSearchHistoryOpenChanged,
    required this.onItemInvoked,
    required this.onRecentSearchRemove,
    required this.onRecentSearchesClear,
    required this.onCreatePlaylist,
    required this.onDuplicatePlaylist,
    required this.onRenamePlaylist,
    required this.onDeletePlaylist,
    required this.onReorderPlaylists,
    required this.onPlaylistRandomPlay,
    required this.onWindowDragStart,
    required this.onWindowDragEnd,
  });

  final ShellLayoutState layout;
  final ShellThemeColors colors;
  final String searchText;
  final VoidCallback onPaneToggle;
  final VoidCallback onGoBack;
  final ValueChanged<String> onSearchTextChanged;
  final void Function(String value, [SearchHistoryType type]) onSearchCommitted;
  final VoidCallback onSearchCleared;
  final int searchHistoryDismissEpoch;
  final ValueChanged<bool> onSearchHistoryOpenChanged;
  final ValueChanged<String> onItemInvoked;
  final ValueChanged<int> onRecentSearchRemove;
  final VoidCallback onRecentSearchesClear;
  final VoidCallback onCreatePlaylist;
  final ValueChanged<LibraryPlaylist> onDuplicatePlaylist;
  final ValueChanged<LibraryPlaylist> onRenamePlaylist;
  final ValueChanged<LibraryPlaylist> onDeletePlaylist;
  final ValueChanged<List<int>> onReorderPlaylists;
  final ValueChanged<int> onPlaylistRandomPlay;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (layout.isNowPlayingFullRoute ||
        (layout.navigationMode == SmPlayerNavigationMode.minimal &&
            !layout.isNavigationPaneVisible)) {
      return const SizedBox.shrink();
    }
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      left: 0,
      top: layout.navigationSurfaceTop,
      bottom: SmPlayerShellMetrics.playerHeight,
      width: layout.sidebarSurfaceWidth,
      child: ShellNavigationGlassSurface(
        key: SmPlayerShellKeys.sidebar,
        surface:
            layout.isNavigationOverlaySurface
                ? colors.navigationOverlaySurface
                : colors.navigationSurface,
        shadowColor:
            layout.isNavigationOverlaySurface
                ? layout.navigationMode == SmPlayerNavigationMode.minimal
                    ? colors.navigationMinimalShadow
                    : colors.navigationOverlayShadow
                : Colors.transparent,
        shadowBlur:
            layout.navigationMode == SmPlayerNavigationMode.minimal ? 42 : 48,
        child: Padding(
          padding: EdgeInsets.only(top: layout.navigationContentTopInset),
          child: _ShellNavigationContent(
            layout: layout,
            searchText: searchText,
            onPaneToggle: onPaneToggle,
            onGoBack: onGoBack,
            onSearchTextChanged: onSearchTextChanged,
            onSearchCommitted: onSearchCommitted,
            onSearchCleared: onSearchCleared,
            searchHistoryDismissEpoch: searchHistoryDismissEpoch,
            onSearchHistoryOpenChanged: onSearchHistoryOpenChanged,
            onItemInvoked: onItemInvoked,
            onRecentSearchRemove: onRecentSearchRemove,
            onRecentSearchesClear: onRecentSearchesClear,
            onCreatePlaylist: onCreatePlaylist,
            onDuplicatePlaylist: onDuplicatePlaylist,
            onRenamePlaylist: onRenamePlaylist,
            onDeletePlaylist: onDeletePlaylist,
            onReorderPlaylists: onReorderPlaylists,
            onPlaylistRandomPlay: onPlaylistRandomPlay,
            onWindowDragStart: onWindowDragStart,
            onWindowDragEnd: onWindowDragEnd,
          ),
        ),
      ),
    );
  }
}

class _ShellNavigationContent extends ConsumerWidget {
  const _ShellNavigationContent({
    required this.layout,
    required this.searchText,
    required this.onPaneToggle,
    required this.onGoBack,
    required this.onSearchTextChanged,
    required this.onSearchCommitted,
    required this.onSearchCleared,
    required this.searchHistoryDismissEpoch,
    required this.onSearchHistoryOpenChanged,
    required this.onItemInvoked,
    required this.onRecentSearchRemove,
    required this.onRecentSearchesClear,
    required this.onCreatePlaylist,
    required this.onDuplicatePlaylist,
    required this.onRenamePlaylist,
    required this.onDeletePlaylist,
    required this.onReorderPlaylists,
    required this.onPlaylistRandomPlay,
    required this.onWindowDragStart,
    required this.onWindowDragEnd,
  });

  final ShellLayoutState layout;
  final String searchText;
  final VoidCallback onPaneToggle;
  final VoidCallback onGoBack;
  final ValueChanged<String> onSearchTextChanged;
  final void Function(String value, [SearchHistoryType type]) onSearchCommitted;
  final VoidCallback onSearchCleared;
  final int searchHistoryDismissEpoch;
  final ValueChanged<bool> onSearchHistoryOpenChanged;
  final ValueChanged<String> onItemInvoked;
  final ValueChanged<int> onRecentSearchRemove;
  final VoidCallback onRecentSearchesClear;
  final VoidCallback onCreatePlaylist;
  final ValueChanged<LibraryPlaylist> onDuplicatePlaylist;
  final ValueChanged<LibraryPlaylist> onRenamePlaylist;
  final ValueChanged<LibraryPlaylist> onDeletePlaylist;
  final ValueChanged<List<int>> onReorderPlaylists;
  final ValueChanged<int> onPlaylistRandomPlay;
  final VoidCallback? onWindowDragStart;
  final VoidCallback? onWindowDragEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(libraryContentDataProvider).valueOrNull;
    final i18n =
        ref.watch(smPlayerI18nProvider).value ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    final recentSearches =
        snapshot?.recentSearches ?? const <SearchHistoryEntry>[];
    return MainNavigationView(
      isPaneOpen: layout.isNavigationPaneVisible,
      showTitlebar: layout.navigationMode != SmPlayerNavigationMode.minimal,
      currentPath: layout.currentPath,
      searchText: searchText,
      i18n: i18n,
      canGoBack: layout.canGoBack,
      playlists: snapshot?.playlists ?? const [],
      recentSearches: recentSearches,
      onPaneToggle: onPaneToggle,
      onGoBack: onGoBack,
      onSearchTextChanged: onSearchTextChanged,
      onSearchCommitted: onSearchCommitted,
      onSearchCleared: onSearchCleared,
      searchHistoryDismissEpoch: searchHistoryDismissEpoch,
      onSearchHistoryOpenChanged: onSearchHistoryOpenChanged,
      onItemInvoked: onItemInvoked,
      onRecentSearchRemove: onRecentSearchRemove,
      onRecentSearchesClear: onRecentSearchesClear,
      onCreatePlaylist: onCreatePlaylist,
      onDuplicatePlaylist: onDuplicatePlaylist,
      onRenamePlaylist: onRenamePlaylist,
      onDeletePlaylist: onDeletePlaylist,
      onReorderPlaylists: onReorderPlaylists,
      onPlaylistRandomPlay: onPlaylistRandomPlay,
      onWindowDragStart: onWindowDragStart,
      onWindowDragEnd: onWindowDragEnd,
    );
  }
}

class ShellNavigationDismissLayer extends StatelessWidget {
  const ShellNavigationDismissLayer({
    super.key,
    required this.visible,
    required this.onDismiss,
  });

  final bool visible;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: GestureDetector(
        key: SmPlayerShellKeys.navigationDismissLayer,
        behavior: HitTestBehavior.translucent,
        onTap: onDismiss,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class ShellNavigationPlayerBackdrop extends StatelessWidget {
  const ShellNavigationPlayerBackdrop({
    super.key,
    required this.visible,
    required this.layout,
    required this.colors,
  });

  final bool visible;
  final ShellLayoutState layout;
  final ShellThemeColors colors;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 0,
      bottom: 0,
      width: layout.sidebarSurfaceWidth,
      height: SmPlayerShellMetrics.playerHeight,
      child: ShellNavigationGlassSurface(
        surface:
            layout.isNavigationOverlaySurface
                ? colors.navigationOverlaySurface
                : colors.navigationSurface,
        shadowColor: Colors.transparent,
        shadowBlur: 0,
        child: const SizedBox.expand(),
      ),
    );
  }
}
