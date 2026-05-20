import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
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
  });

  final List<LibrarySong> songs;
  final List<LibraryFolder> folders;
  final SmPlayerI18n i18n;
  final String rootPath;
  final String currentRelativePath;
  final VoidCallback onHiddenFoldersListButtonClick;
  final ValueChanged<String> onOpenFolder;

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
  });

  final List<LibrarySong> songs;
  final List<LibraryFolder> folders;
  final SmPlayerI18n i18n;
  final String rootPath;
  final String currentRelativePath;
  final ValueChanged<String> onOpenFolder;

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
  });

  final FolderChainItem item;
  final SmPlayerI18n i18n;
  final ValueChanged<String> onOpenFolder;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            foregroundColor: LocalPageColors.textStrong,
            disabledForegroundColor: LocalPageColors.textStrong,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: item.isCurrentItem ? null : () => onOpenFolder(item.path),
          child: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        if (item.children.isNotEmpty)
          SizedBox.square(
            dimension: 30,
            child: PopupMenuButton<String>(
              key: ValueKey('FolderChain.Dropdown.${item.path}'),
              tooltip: i18n.t('local.path'),
              padding: EdgeInsets.zero,
              icon: const Icon(
                FluentIcons.chevron_right_16_regular,
                size: 16,
                color: LocalPageColors.textMuted,
              ),
              itemBuilder:
                  (context) => [
                    for (final child in item.children)
                      PopupMenuItem<String>(
                        key: ValueKey('FolderChain.Child.${child.path}'),
                        value: child.path,
                        child: Text(
                          child.name,
                          style: TextStyle(
                            color:
                                child.isHighlighted
                                    ? LocalPageColors.accentStrong
                                    : LocalPageColors.textStrong,
                            fontWeight:
                                child.isHighlighted
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
              onSelected: onOpenFolder,
            ),
          ),
      ],
    );
  }
}
