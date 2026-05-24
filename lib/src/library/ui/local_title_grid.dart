import 'package:flutter/gestures.dart';
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
    this.compact = false,
    this.onOpenFolderMenu,
  });

  final List<LibrarySong> songs;
  final List<LibraryFolder> folders;
  final SmPlayerI18n i18n;
  final String rootPath;
  final String currentRelativePath;
  final VoidCallback onHiddenFoldersListButtonClick;
  final ValueChanged<String> onOpenFolder;
  final bool compact;
  final void Function(String targetRelativePath, Offset position)?
  onOpenFolderMenu;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 36 : 42,
      child: Row(
        children: [
          if (!compact) ...[
            Text(
              i18n.t('local.currentPath'),
              style: const TextStyle(
                color: LocalPageColors.textStrong,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FolderChainListView(
              songs: songs,
              folders: folders,
              i18n: i18n,
              rootPath: rootPath,
              currentRelativePath: currentRelativePath,
              onOpenFolder: onOpenFolder,
              compact: compact,
              onOpenFolderMenu: onOpenFolderMenu,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 12),
            IconButton(
              tooltip: i18n.t('local.hiddenFolders'),
              icon: const Icon(FluentIcons.eye_off_24_regular),
              color: LocalPageColors.textMuted,
              onPressed: onHiddenFoldersListButtonClick,
            ),
          ],
        ],
      ),
    );
  }
}

class FolderChainListView extends StatefulWidget {
  const FolderChainListView({
    super.key,
    required this.songs,
    required this.folders,
    required this.i18n,
    required this.rootPath,
    required this.currentRelativePath,
    required this.onOpenFolder,
    this.compact = false,
    this.onOpenFolderMenu,
  });

  final List<LibrarySong> songs;
  final List<LibraryFolder> folders;
  final SmPlayerI18n i18n;
  final String rootPath;
  final String currentRelativePath;
  final ValueChanged<String> onOpenFolder;
  final bool compact;
  final void Function(String targetRelativePath, Offset position)?
  onOpenFolderMenu;

  @override
  State<FolderChainListView> createState() => _FolderChainListViewState();
}

class _FolderChainListViewState extends State<FolderChainListView> {
  OverlayEntry? _childFlyoutOverlay;
  String? _openedPath;

  @override
  void didUpdateWidget(FolderChainListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRelativePath != widget.currentRelativePath ||
        oldWidget.rootPath != widget.rootPath) {
      _closeChildFlyout();
    }
  }

  @override
  void dispose() {
    _closeChildFlyout();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final folderIndex = buildFolderIndex(
      widget.songs,
      widget.folders,
      widget.rootPath,
    );
    final folderChain = buildFolderChain(
      widget.currentRelativePath,
      folderIndex.nodes,
    );

    return Container(
      height: widget.compact ? 36 : 42,
      padding:
          widget.compact
              ? const EdgeInsets.symmetric(horizontal: 2)
              : const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
            i18n: widget.i18n,
            isOpen: _openedPath == item.path,
            onOpenFolder: (path) {
              _closeChildFlyout();
              widget.onOpenFolder(path);
            },
            onOpenFolderMenu: widget.onOpenFolderMenu,
            onToggleChildren: (buttonContext) {
              _toggleChildFlyout(item, buttonContext);
            },
          );
        },
      ),
    );
  }

  void _toggleChildFlyout(FolderChainItem item, BuildContext buttonContext) {
    if (_openedPath == item.path) {
      _closeChildFlyout();
      return;
    }
    _showChildFlyout(item, buttonContext);
  }

  void _showChildFlyout(FolderChainItem item, BuildContext buttonContext) {
    _closeChildFlyout();
    final renderBox = buttonContext.findRenderObject() as RenderBox;
    final origin = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final left = (origin.dx).clamp(8.0, screenWidth - 196.0);
    final top = origin.dy + size.height + 4;
    _openedPath = item.path;
    _childFlyoutOverlay = OverlayEntry(
      builder:
          (overlayContext) => Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _closeChildFlyout,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                child: _FolderChainChildFlyout(
                  item: item,
                  onOpenFolder: (path) {
                    _closeChildFlyout();
                    widget.onOpenFolder(path);
                  },
                  onOpenFolderMenu:
                      widget.onOpenFolderMenu == null
                          ? null
                          : (path, position) {
                            widget.onOpenFolderMenu!(path, position);
                          },
                ),
              ),
            ],
          ),
    );
    Overlay.of(context, rootOverlay: true).insert(_childFlyoutOverlay!);
    setState(() {});
  }

  void _closeChildFlyout() {
    _childFlyoutOverlay?.remove();
    _childFlyoutOverlay = null;
    if (_openedPath != null && mounted) {
      setState(() {
        _openedPath = null;
      });
    } else {
      _openedPath = null;
    }
  }
}

class _FolderChainItem extends StatelessWidget {
  const _FolderChainItem({
    required this.item,
    required this.i18n,
    required this.isOpen,
    required this.onOpenFolder,
    required this.onToggleChildren,
    this.onOpenFolderMenu,
  });

  final FolderChainItem item;
  final SmPlayerI18n i18n;
  final bool isOpen;
  final ValueChanged<String> onOpenFolder;
  final ValueChanged<BuildContext> onToggleChildren;
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
            child: Builder(
              builder:
                  (buttonContext) => IconButton(
                    key: ValueKey('FolderChain.Dropdown.${item.path}'),
                    tooltip: i18n.t('local.path'),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      isOpen
                          ? FluentIcons.chevron_down_16_regular
                          : FluentIcons.chevron_right_16_regular,
                      size: 16,
                      color:
                          isOpen
                              ? LocalPageColors.textStrong
                              : LocalPageColors.textMuted,
                    ),
                    onPressed: () {
                      onToggleChildren(buttonContext);
                    },
                  ),
            ),
          ),
      ],
    );
  }
}

class _FolderChainChildFlyout extends StatelessWidget {
  const _FolderChainChildFlyout({
    required this.item,
    required this.onOpenFolder,
    this.onOpenFolderMenu,
  });

  final FolderChainItem item;
  final ValueChanged<String> onOpenFolder;
  final void Function(String targetRelativePath, Offset position)?
  onOpenFolderMenu;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 180,
          maxWidth: 420,
          maxHeight: 320,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xf7ffffff),
            border: Border.all(color: LocalPageColors.borderSubtle),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2e233144),
                blurRadius: 44,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final child in item.children)
                    Listener(
                      key: ValueKey('FolderChain.Child.${child.path}'),
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        if (event.buttons == kSecondaryMouseButton) {
                          onOpenFolderMenu?.call(child.path, event.position);
                        }
                      },
                      child: _FolderChainChildButton(
                        child: child,
                        onPressed: () {
                          onOpenFolder(child.path);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderChainChildButton extends StatefulWidget {
  const _FolderChainChildButton({required this.child, required this.onPressed});

  final FolderChainChildItem child;
  final VoidCallback onPressed;

  @override
  State<_FolderChainChildButton> createState() =>
      _FolderChainChildButtonState();
}

class _FolderChainChildButtonState extends State<_FolderChainChildButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || widget.child.isHighlighted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          height: 32,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? LocalPageColors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.child.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  active
                      ? LocalPageColors.accentStrong
                      : LocalPageColors.textStrong,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
