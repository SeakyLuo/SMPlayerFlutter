part of 'recent_page.dart';

extension _RecentPageFrame on _RecentPageState {
  // Navigation belongs to the page, independently of its data request.
  Widget _buildRecentFrame({
    required SmPlayerI18n i18n,
    required int browsedCount,
    required int searchesCount,
    required bool showCount,
    required Widget child,
  }) {
    return _RecentPagePanel(
      topPadding: 0,
      trailingScrollbar: true,
      child: LayoutBuilder(
        builder: (context, _) {
          final useWorkspaceAppBar = WorkspaceNavigationAppBarScope.of(context);
          _syncAppBarPortal(
            showPortal: useWorkspaceAppBar,
            routePath: '/recent',
            i18n: i18n,
            title: i18n.t('common.recent'),
            browsedCount: browsedCount,
            searchesCount: searchesCount,
            showCount: showCount,
          );
          return Column(
            spacing: 4,
            children: [
              if (!useWorkspaceAppBar)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 26,
                    right: recentScrollbarGutter,
                    bottom: 10,
                  ),
                  child: _RecentAppBarTabs(
                    controller: _tabController,
                    i18n: i18n,
                    browsedCount: browsedCount,
                    searchesCount: searchesCount,
                    showCount: showCount,
                    onChanged: _switchTab,
                  ),
                ),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}
