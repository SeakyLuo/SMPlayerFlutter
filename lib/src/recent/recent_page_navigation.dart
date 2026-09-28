part of 'recent_page.dart';

extension _RecentPageNavigation on _RecentPageState {
  void _syncAppBarPortal({
    required bool showPortal,
    required String routePath,
    required SmPlayerI18n i18n,
    required String title,
    required int addedCount,
    required int playedCount,
    required int browsedCount,
    required int searchesCount,
    required bool showCount,
  }) {
    final signature =
        '$showPortal:$routePath:$title:$_activeTab:$addedCount:$playedCount:$browsedCount:$searchesCount:$showCount';
    if (_appBarPortalSignature == signature) {
      return;
    }
    _appBarPortalSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final notifier = ref.read(workspaceAppBarPortalProvider.notifier);
      if (!showPortal) {
        if (notifier.state?.owner == _appBarPortalOwner) {
          notifier.state = null;
        }
        return;
      }
      notifier.state = WorkspaceAppBarPortalEntry(
        owner: _appBarPortalOwner,
        routePath: routePath,
        title: title,
        replacesTitle: true,
        bottomPadding: 2,
        content: _RecentAppBarTabs(
          controller: _tabController,
          i18n: i18n,
          addedCount: addedCount,
          playedCount: playedCount,
          browsedCount: browsedCount,
          searchesCount: searchesCount,
          showCount: showCount,
          onChanged: _switchTab,
        ),
      );
    });
  }
}
