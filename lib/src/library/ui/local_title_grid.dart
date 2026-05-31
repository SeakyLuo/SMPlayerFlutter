import 'dart:math' as math;

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
    this.onCurrentFolderClick,
    this.onOpenFolderMenu,
    this.onWillAcceptDrop,
    this.onAcceptDrop,
  });

  final List<LibrarySong> songs;
  final List<LibraryFolder> folders;
  final SmPlayerI18n i18n;
  final String rootPath;
  final String currentRelativePath;
  final VoidCallback onHiddenFoldersListButtonClick;
  final ValueChanged<String> onOpenFolder;
  final bool compact;
  final VoidCallback? onCurrentFolderClick;
  final void Function(String targetRelativePath, Offset position)?
  onOpenFolderMenu;
  final bool Function(String targetRelativePath, LocalItemsDragPayload payload)?
  onWillAcceptDrop;
  final void Function(String targetRelativePath, LocalItemsDragPayload payload)?
  onAcceptDrop;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    return SizedBox(
      height: compact ? 36 : 42,
      child: Row(
        children: [
          if (!compact) ...[
            Text(
              i18n.t('local.currentPath'),
              style: TextStyle(
                color: colors.textStrong,
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
              onCurrentFolderClick: onCurrentFolderClick,
              onOpenFolderMenu: onOpenFolderMenu,
              onWillAcceptDrop: onWillAcceptDrop,
              onAcceptDrop: onAcceptDrop,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 12),
            IconButton(
              tooltip: i18n.t('local.hiddenFolders'),
              icon: const Icon(FluentIcons.eye_off_24_regular),
              color: colors.textMuted,
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
    this.onCurrentFolderClick,
    this.onOpenFolderMenu,
    this.onWillAcceptDrop,
    this.onAcceptDrop,
  });

  final List<LibrarySong> songs;
  final List<LibraryFolder> folders;
  final SmPlayerI18n i18n;
  final String rootPath;
  final String currentRelativePath;
  final ValueChanged<String> onOpenFolder;
  final bool compact;
  final VoidCallback? onCurrentFolderClick;
  final void Function(String targetRelativePath, Offset position)?
  onOpenFolderMenu;
  final bool Function(String targetRelativePath, LocalItemsDragPayload payload)?
  onWillAcceptDrop;
  final void Function(String targetRelativePath, LocalItemsDragPayload payload)?
  onAcceptDrop;

  @override
  State<FolderChainListView> createState() => _FolderChainListViewState();
}

class _FolderChainListViewState extends State<FolderChainListView> {
  OverlayEntry? _childFlyoutOverlay;
  String? _openedPath;
  final _scrollController = ScrollController();
  var _draggingChain = false;
  var _chainDragged = false;
  var _dragStartX = 0.0;
  var _dragStartOffset = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToEnd();
    });
  }

  @override
  void didUpdateWidget(FolderChainListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRelativePath != widget.currentRelativePath ||
        oldWidget.rootPath != widget.rootPath) {
      _closeChildFlyout();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToEnd();
      });
    }
  }

  @override
  void dispose() {
    _closeChildFlyout(updateState: false);
    _scrollController.dispose();
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

    final colors = LocalPageColors.of(context);
    return Container(
      height: widget.compact ? 36 : 42,
      padding:
          widget.compact
              ? const EdgeInsets.symmetric(horizontal: 2)
              : const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.panelBorder),
        boxShadow: [
          BoxShadow(
            color: colors.panelShadow,
            offset: Offset(0, 10),
            blurRadius: 24,
          ),
        ],
      ),
      child: Listener(
        onPointerSignal: _scrollFolderChainFromWheel,
        onPointerDown: _startFolderChainDrag,
        onPointerMove: _updateFolderChainDrag,
        onPointerUp: _stopFolderChainDrag,
        onPointerCancel: _stopFolderChainDrag,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (_chainDragged) {
              _chainDragged = false;
            }
          },
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: folderChain.length,
            separatorBuilder:
                (_, _) => Icon(
                  FluentIcons.chevron_right_16_regular,
                  size: 14,
                  color: colors.textMuted,
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
                onCurrentFolderClick: () {
                  _closeChildFlyout();
                  widget.onCurrentFolderClick?.call();
                },
                shouldIgnoreTap: _consumeFolderChainDragTap,
                onOpenFolderMenu: widget.onOpenFolderMenu,
                onWillAcceptDrop: widget.onWillAcceptDrop,
                onAcceptDrop:
                    widget.onAcceptDrop == null
                        ? null
                        : (targetRelativePath, payload) {
                          _closeChildFlyout();
                          widget.onAcceptDrop!(targetRelativePath, payload);
                        },
                onToggleChildren: (buttonContext) {
                  _toggleChildFlyout(item, buttonContext);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _scrollFolderChainFromWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scrollController.hasClients) {
      return;
    }
    final rawDelta =
        event.scrollDelta.dx != 0 ? event.scrollDelta.dx : event.scrollDelta.dy;
    if (rawDelta == 0) {
      return;
    }
    final nextOffset = (_scrollController.offset + rawDelta).clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(nextOffset);
  }

  void _startFolderChainDrag(PointerDownEvent event) {
    if (event.buttons != kPrimaryMouseButton || !_scrollController.hasClients) {
      return;
    }
    _draggingChain = true;
    _chainDragged = false;
    _dragStartX = event.position.dx;
    _dragStartOffset = _scrollController.offset;
  }

  void _updateFolderChainDrag(PointerMoveEvent event) {
    if (!_draggingChain || !_scrollController.hasClients) {
      return;
    }
    final deltaX = event.position.dx - _dragStartX;
    if (deltaX.abs() > 3) {
      _chainDragged = true;
    }
    final nextOffset = (_dragStartOffset - deltaX).clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(nextOffset);
  }

  void _stopFolderChainDrag(PointerEvent event) {
    _draggingChain = false;
  }

  bool _consumeFolderChainDragTap() {
    if (!_chainDragged) {
      return false;
    }
    _chainDragged = false;
    return true;
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
    final maxFlyoutWidth = math.max(0.0, math.min(420.0, screenWidth - 48.0));
    final left =
        (origin.dx)
            .clamp(8.0, math.max(8.0, screenWidth - maxFlyoutWidth - 8.0))
            .toDouble();
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
                  onWillAcceptDrop: widget.onWillAcceptDrop,
                  onAcceptDrop:
                      widget.onAcceptDrop == null
                          ? null
                          : (targetRelativePath, payload) {
                            _closeChildFlyout();
                            widget.onAcceptDrop!(targetRelativePath, payload);
                          },
                  onOpenFolderMenu:
                      widget.onOpenFolderMenu == null
                          ? null
                          : (path, position) {
                            widget.onOpenFolderMenu!(path, position);
                          },
                  maxWidth: maxFlyoutWidth,
                ),
              ),
            ],
          ),
    );
    Overlay.of(context, rootOverlay: true).insert(_childFlyoutOverlay!);
    setState(() {});
  }

  void _closeChildFlyout({bool updateState = true}) {
    _childFlyoutOverlay?.remove();
    _childFlyoutOverlay = null;
    if (_openedPath != null && mounted && updateState) {
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
    required this.onCurrentFolderClick,
    required this.shouldIgnoreTap,
    required this.onToggleChildren,
    this.onOpenFolderMenu,
    this.onWillAcceptDrop,
    this.onAcceptDrop,
  });

  final FolderChainItem item;
  final SmPlayerI18n i18n;
  final bool isOpen;
  final ValueChanged<String> onOpenFolder;
  final VoidCallback onCurrentFolderClick;
  final bool Function() shouldIgnoreTap;
  final ValueChanged<BuildContext> onToggleChildren;
  final void Function(String targetRelativePath, Offset position)?
  onOpenFolderMenu;
  final bool Function(String targetRelativePath, LocalItemsDragPayload payload)?
  onWillAcceptDrop;
  final void Function(String targetRelativePath, LocalItemsDragPayload payload)?
  onAcceptDrop;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    final pathButton = Listener(
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
          onTap:
              item.isCurrentItem
                  ? () {
                    if (!shouldIgnoreTap()) {
                      onCurrentFolderClick();
                    }
                  }
                  : () {
                    if (!shouldIgnoreTap()) {
                      onOpenFolder(item.path);
                    }
                  },
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
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        item.isCurrentItem || onAcceptDrop == null
            ? pathButton
            : DragTarget<LocalItemsDragPayload>(
              onWillAcceptWithDetails:
                  onWillAcceptDrop == null
                      ? null
                      : (details) => onWillAcceptDrop!(item.path, details.data),
              onAcceptWithDetails:
                  (details) => onAcceptDrop!(item.path, details.data),
              builder: (context, candidateData, rejectedData) => pathButton,
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
                      color: isOpen ? colors.textStrong : colors.textMuted,
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
    this.onWillAcceptDrop,
    this.onAcceptDrop,
    this.onOpenFolderMenu,
    required this.maxWidth,
  });

  final FolderChainItem item;
  final ValueChanged<String> onOpenFolder;
  final bool Function(String targetRelativePath, LocalItemsDragPayload payload)?
  onWillAcceptDrop;
  final void Function(String targetRelativePath, LocalItemsDragPayload payload)?
  onAcceptDrop;
  final void Function(String targetRelativePath, Offset position)?
  onOpenFolderMenu;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: math.min(180, maxWidth),
          maxWidth: maxWidth,
          maxHeight: 320,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                nightMode ? const Color(0xf0161c24) : const Color(0xf7ffffff),
            border: Border.all(color: colors.borderSubtle),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color:
                    nightMode
                        ? const Color(0x57000000)
                        : const Color(0x2e233144),
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
                    _FolderChainDropTarget(
                      targetRelativePath: child.path,
                      onWillAcceptDrop: onWillAcceptDrop,
                      onAcceptDrop: onAcceptDrop,
                      key: ValueKey('FolderChain.Child.${child.path}'),
                      child: _FolderChainChildButton(
                        child: child,
                        onOpenFolderMenu: onOpenFolderMenu,
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
  const _FolderChainChildButton({
    required this.child,
    required this.onPressed,
    this.onOpenFolderMenu,
  });

  final FolderChainChildItem child;
  final VoidCallback onPressed;
  final void Function(String targetRelativePath, Offset position)?
  onOpenFolderMenu;

  @override
  State<_FolderChainChildButton> createState() =>
      _FolderChainChildButtonState();
}

class _FolderChainChildButtonState extends State<_FolderChainChildButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || widget.child.isHighlighted;
    final colors = LocalPageColors.of(context);
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
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (event.buttons == kSecondaryMouseButton) {
            widget.onOpenFolderMenu?.call(widget.child.path, event.position);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            height: 32,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active ? colors.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.child.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? colors.accentStrong : colors.textStrong,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderChainDropTarget extends StatelessWidget {
  const _FolderChainDropTarget({
    super.key,
    required this.targetRelativePath,
    required this.child,
    this.onWillAcceptDrop,
    this.onAcceptDrop,
  });

  final String targetRelativePath;
  final Widget child;
  final bool Function(String targetRelativePath, LocalItemsDragPayload payload)?
  onWillAcceptDrop;
  final void Function(String targetRelativePath, LocalItemsDragPayload payload)?
  onAcceptDrop;

  @override
  Widget build(BuildContext context) {
    if (onAcceptDrop == null) {
      return child;
    }
    return DragTarget<LocalItemsDragPayload>(
      onWillAcceptWithDetails:
          onWillAcceptDrop == null
              ? null
              : (details) =>
                  onWillAcceptDrop!(targetRelativePath, details.data),
      onAcceptWithDetails:
          (details) => onAcceptDrop!(targetRelativePath, details.data),
      builder: (context, candidateData, rejectedData) => child,
    );
  }
}
