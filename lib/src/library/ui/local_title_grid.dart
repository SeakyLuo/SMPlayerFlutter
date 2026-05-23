import 'package:flutter/gestures.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'command_bar.dart';
import 'local_folder_model.dart';
import 'local_page_quick_jump.dart';

class LocalTitleGrid extends StatelessWidget {
  const LocalTitleGrid({
    super.key,
    required this.songs,
    required this.folders,
    required this.i18n,
    required this.rootPath,
    required this.currentRelativePath,
    required this.onHiddenFoldersListButtonClick,
    required this.onOpenFolder,
    this.onOpenFolderMenu,
  });

  final List<LibrarySong> songs;
  final List<LibraryFolder> folders;
  final SmPlayerI18n i18n;
  final String rootPath;
  final String currentRelativePath;
  final VoidCallback onHiddenFoldersListButtonClick;
  final ValueChanged<String> onOpenFolder;
  final void Function(String targetRelativePath, Offset position)?
  onOpenFolderMenu;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Text(
            i18n.t('local.currentPath'),
            style: const TextStyle(
              color: LocalPageColors.textStrong,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FolderChainListView(
              songs: songs,
              folders: folders,
              i18n: i18n,
              rootPath: rootPath,
              currentRelativePath: currentRelativePath,
              onOpenFolder: onOpenFolder,
              onOpenFolderMenu: onOpenFolderMenu,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: i18n.t('local.hiddenFolders'),
            icon: const Icon(FluentIcons.eye_off_24_regular),
            color: LocalPageColors.textMuted,
            onPressed: onHiddenFoldersListButtonClick,
          ),
        ],
      ),
    );
  }
}

class FolderChainListView extends StatelessWidget {
  const FolderChainListView({
    super.key,
    required this.songs,
    required this.folders,
    required this.i18n,
    required this.rootPath,
    required this.currentRelativePath,
    required this.onOpenFolder,
    this.onOpenFolderMenu,
  });

  final List<LibrarySong> songs;
  final List<LibraryFolder> folders;
  final SmPlayerI18n i18n;
  final String rootPath;
  final String currentRelativePath;
  final ValueChanged<String> onOpenFolder;
  final void Function(String targetRelativePath, Offset position)?
  onOpenFolderMenu;

  @override
  Widget build(BuildContext context) {
    final folderIndex = buildFolderIndex(songs, folders, rootPath);
    final folderChain = buildFolderChain(
      currentRelativePath,
      folderIndex.nodes,
    );

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: LocalPageColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: LocalPageColors.panelBorder),
        boxShadow: const [
          BoxShadow(
            color: LocalPageColors.panelShadow,
            offset: Offset(0, 10),
            blurRadius: 24,
          ),
        ],
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: folderChain.length,
        separatorBuilder:
            (_, _) => const Icon(
              FluentIcons.chevron_right_16_regular,
              size: 14,
              color: LocalPageColors.textMuted,
            ),
        itemBuilder: (context, index) {
          final item = folderChain[index];
          return _FolderChainItem(
            item: item,
            i18n: i18n,
            onOpenFolder: onOpenFolder,
            onOpenFolderMenu: onOpenFolderMenu,
          );
        },
      ),
    );
  }
}

class _FolderChainItem extends StatelessWidget {
  const _FolderChainItem({
    required this.item,
    required this.i18n,
    required this.onOpenFolder,
    this.onOpenFolderMenu,
  });

  final FolderChainItem item;
  final SmPlayerI18n i18n;
  final ValueChanged<String> onOpenFolder;
  final void Function(String targetRelativePath, Offset position)?
  onOpenFolderMenu;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Listener(
          key: ValueKey('FolderChain.Path.${item.path}'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (event.buttons == kSecondaryMouseButton) {
              onOpenFolderMenu?.call(item.path, event.position);
            }
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: item.isCurrentItem ? () {} : () => onOpenFolder(item.path),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LocalPageColors.textStrong,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (item.children.isNotEmpty)
          SizedBox.square(
            dimension: 30,
            child: IconButton(
              key: ValueKey('FolderChain.Dropdown.${item.path}'),
              tooltip: i18n.t('local.path'),
              padding: EdgeInsets.zero,
              icon: const Icon(
                FluentIcons.chevron_right_16_regular,
                size: 16,
                color: LocalPageColors.textMuted,
              ),
              onPressed: () {
                showMenuFlyout(
                  context,
                  items: [
                    for (final child in item.children)
                      MenuFlyoutItem(
                        key: 'folder-chain-child-${child.path}',
                        text: child.name,
                        icon:
                            child.isHighlighted
                                ? FluentIcons.checkmark_20_regular
                                : null,
                        onPressed: () => onOpenFolder(child.path),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
