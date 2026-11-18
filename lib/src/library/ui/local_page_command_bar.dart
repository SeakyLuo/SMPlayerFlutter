part of 'local_page.dart';

extension _LocalPageCommandBar on _LocalPageState {
  Widget _buildDirectoryCommandBar(
    BuildContext context,
    SmPlayerI18n i18n,
    FolderNode currentNode,
    LibraryContentData snapshot,
    Map<String, FolderNode> nodes,
    LocalPageColors colors,
    bool isCompactLayout,
    bool contentUnavailable,
    int folderCount,
    int songCount,
    List<int> visibleSongIds,
    bool hasSubfolderSongs,
  ) => CommandBar(
    contentSizing: CommandBarContentSizing.intrinsic,
    overflowReserve: isCompactLayout ? 44 : 0,
    overflowLabel: i18n.t('player.more'),
    overflowItems:
        isCompactLayout
            ? [
              MenuFlyoutItem(
                key: 'hidden-folders',
                text: i18n.t('local.viewHiddenFolders'),
                icon: FluentIcons.folder_prohibited_20_regular,
                onPressed: () => context.push<void>('/hidden-folders'),
              ),
            ]
            : const [],
    content: LocalDirectoryCount(
      loading: contentUnavailable,
      folders: folderCount,
      songs: songCount,
    ),
    children: [
      CommandBarButton(
        iconWidget: const ShuffleIcon(),
        useShuffleIcon: true,
        label: i18n.t('nowPlaying.randomPlay'),
        overflowSubmenu:
            !contentUnavailable &&
                    visibleSongIds.isNotEmpty &&
                    hasSubfolderSongs
                ? _localShuffleMenuItems(currentNode, visibleSongIds, i18n)
                : const [],
        onPressedWithContext:
            contentUnavailable
                ? null
                : (buttonContext) => _playShuffledFromToolbar(
                  buttonContext,
                  currentNode,
                  visibleSongIds,
                  hasSubfolderSongs,
                  i18n,
                ),
      ),
      CommandBarButton(
        icon: FluentIcons.arrow_sync_24_regular,
        label:
            isCompactLayout
                ? i18n.t('local.updateFolderShort')
                : i18n.t('local.updateFolder'),
        loading: _refreshFolderRunning,
        loadingProgress: _refreshButtonProgressNotifier,
        canOverflow: !_refreshFolderRunning,
        onPressed:
            contentUnavailable || !_canWriteDirectory
                ? null
                : () =>
                    _refreshFolderRunning
                        ? _showRefreshFolderTask()
                        : _refreshFolder(currentNode, i18n),
      ),
      CommandBarButton(
        icon: FluentIcons.arrow_sort_24_regular,
        label: i18n.t('common.sort'),
        overflowSubmenu:
            contentUnavailable || !_canWriteDirectory
                ? const []
                : _localSortMenuItems(currentNode, i18n),
        onPressedWithContext:
            contentUnavailable || !_canWriteDirectory
                ? null
                : (context) => _showSortMenu(context, i18n, currentNode),
      ),
      CommandBarButton(
        icon: FluentIcons.add_24_regular,
        label: i18n.t('local.newFolder'),
        onPressed:
            contentUnavailable || !_canWriteDirectory
                ? null
                : () => _createFolder(
                  parent: currentNode,
                  nodes: nodes,
                  rootPath: snapshot.rootPath,
                  i18n: i18n,
                ),
      ),
      CommandBarButton(
        icon: FluentIcons.multiselect_ltr_24_regular,
        label: i18n.t('albums.multiSelect'),
        active: _multiSelect,
        activeMatchesHover: true,
        tooltip: _multiSelect ? i18n.t('common.exitMultiSelectTooltip') : null,
        onPressed: contentUnavailable ? null : _toggleMultiSelect,
      ),
    ],
  );
}
