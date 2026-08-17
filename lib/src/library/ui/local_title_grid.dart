import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'local_folder_model.dart';
import 'local_page_quick_jump.dart';
import 'menu_flyout.dart';

const localFolderChainRadius = 8.0;

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
            SizedBox.square(
              key: const ValueKey('LocalTitleGrid.HiddenFoldersButton'),
              dimension: 42,
              child: IconButton(
                tooltip: i18n.t('local.hiddenFolders'),
                padding: EdgeInsets.zero,
                icon: const Icon(FluentIcons.folder_prohibited_24_regular),
                color: colors.textMuted,
                onPressed: onHiddenFoldersListButtonClick,
              ),
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
    _openedPath = null;
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
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: widget.compact ? 36 : 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(localFolderChainRadius),
          boxShadow: [
            BoxShadow(
              color: colors.panelShadow,
              offset: const Offset(0, 10),
              blurRadius: 24,
            ),
          ],
        ),
        child: GlassContainer(
          key: const ValueKey('FolderChainListView.GlassBackground'),
          useOwnLayer: true,
          quality: GlassQuality.minimal,
          clipBehavior: Clip.hardEdge,
          shape: const LiquidRoundedRectangle(
            borderRadius: localFolderChainRadius,
          ),
          settings: LiquidGlassSettings(
            glassColor:
                nightMode ? const Color(0xf0161c24) : const Color(0xffffffff),
            blur: 46,
            thickness: 20,
            refractiveIndex: 1.06,
            saturation: 1.5,
            chromaticAberration: 0,
            lightIntensity: 0.1,
            ambientStrength: 0.08,
            glowIntensity: 0.04,
            standardOpacityMultiplier: 0.24,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(localFolderChainRadius),
              border: Border.all(color: colors.panelBorder),
            ),
            child: Padding(
              padding:
                  widget.compact
                      ? const EdgeInsets.symmetric(horizontal: 2)
                      : const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                    separatorBuilder: (_, _) => const SizedBox(width: 2),
                    itemBuilder: (context, index) {
                      final item = folderChain[index];
                      return _FolderChainItem(
                        item: item,
                        i18n: widget.i18n,
                        isOpen: _openedPath == item.path,
                        compact: widget.compact,
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
                                  widget.onAcceptDrop!(
                                    targetRelativePath,
                                    payload,
                                  );
                                },
                        onToggleChildren: (buttonContext) {
                          _toggleChildFlyout(item, buttonContext);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
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
    setState(() {
      _openedPath = item.path;
    });
    unawaited(
      showMenuFlyout(
        buttonContext,
        scrollRoot: true,
        items: [
          for (final child in item.children)
            MenuFlyoutItem(
              key: 'FolderChain.Child.${child.path}',
              text: child.name,
              checked: child.isHighlighted,
              tooltip: child.name,
              onPressed: () => widget.onOpenFolder(child.path),
              onSecondaryTapDown:
                  widget.onOpenFolderMenu == null
                      ? null
                      : (position) =>
                          widget.onOpenFolderMenu!(child.path, position),
              onWillAcceptDrop:
                  widget.onWillAcceptDrop == null
                      ? null
                      : (payload) =>
                          payload is LocalItemsDragPayload &&
                          widget.onWillAcceptDrop!(child.path, payload),
              onAcceptDrop:
                  widget.onAcceptDrop == null
                      ? null
                      : (payload) {
                        if (payload is LocalItemsDragPayload) {
                          widget.onAcceptDrop!(child.path, payload);
                        }
                      },
            ),
        ],
      ).whenComplete(() {
        if (mounted && _openedPath == item.path) {
          setState(() {
            _openedPath = null;
          });
        }
      }),
    );
  }

  void _closeChildFlyout({bool updateState = true}) {
    if (_openedPath != null && mounted && updateState) {
      setState(() {
        _openedPath = null;
      });
    } else {
      _openedPath = null;
    }
  }
}

class _FolderChainItem extends StatefulWidget {
  const _FolderChainItem({
    required this.item,
    required this.i18n,
    required this.isOpen,
    required this.compact,
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
  final bool compact;
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
  State<_FolderChainItem> createState() => _FolderChainItemState();
}

class _FolderChainItemState extends State<_FolderChainItem> {
  var _hovered = false;
  final _tooltipLayerLink = LayerLink();
  OverlayEntry? _tooltipOverlayEntry;

  @override
  void didUpdateWidget(_FolderChainItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      _removeTooltipOverlay();
    }
  }

  @override
  void dispose() {
    _removeTooltipOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    final active = _hovered || widget.isOpen;
    final segment = Builder(
      builder: (segmentContext) {
        final pathButton = MouseRegion(
          onEnter: (_) => _showTooltipOverlay(),
          onExit: (_) => _removeTooltipOverlay(),
          child: CompositedTransformTarget(
            link: _tooltipLayerLink,
            child: Semantics(
              tooltip: widget.item.name,
              child: Listener(
                key: ValueKey('FolderChain.Path.${widget.item.path}'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  if (event.buttons == kSecondaryMouseButton) {
                    widget.onOpenFolderMenu?.call(
                      widget.item.path,
                      event.position,
                    );
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap:
                      widget.item.isCurrentItem
                          ? () {
                            if (!widget.shouldIgnoreTap()) {
                              widget.onCurrentFolderClick();
                            }
                          }
                          : () {
                            if (!widget.shouldIgnoreTap()) {
                              widget.onOpenFolder(widget.item.path);
                            }
                          },
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: widget.compact ? 36 : 32,
                    ),
                    child: Padding(
                      padding:
                          widget.compact
                              ? const EdgeInsets.symmetric(horizontal: 6)
                              : const EdgeInsets.fromLTRB(10, 0, 8, 0),
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          widget.item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: widget.compact ? 14 : 13,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final segmentContent = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.item.isCurrentItem || widget.onAcceptDrop == null
                ? pathButton
                : DragTarget<LocalItemsDragPayload>(
                  onWillAcceptWithDetails:
                      widget.onWillAcceptDrop == null
                          ? null
                          : (details) => widget.onWillAcceptDrop!(
                            widget.item.path,
                            details.data,
                          ),
                  onAcceptWithDetails:
                      (details) =>
                          widget.onAcceptDrop!(widget.item.path, details.data),
                  builder: (context, candidateData, rejectedData) => pathButton,
                ),
            if (widget.item.children.isNotEmpty)
              GestureDetector(
                key: ValueKey('FolderChain.Dropdown.${widget.item.path}'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  widget.onToggleChildren(segmentContext);
                },
                child: SizedBox(
                  width: 22,
                  height: widget.compact ? 36 : 32,
                  child: AnimatedRotation(
                    turns: widget.isOpen ? 0.25 : 0,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      FluentIcons.chevron_right_16_regular,
                      size: 14,
                      color: active ? colors.textStrong : colors.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        );

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
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active ? colors.surfaceControlHover : Colors.transparent,
              borderRadius: BorderRadius.circular(localFolderChainRadius),
            ),
            child: segmentContent,
          ),
        );
      },
    );
    return segment;
  }

  void _showTooltipOverlay() {
    if (_tooltipOverlayEntry != null) {
      return;
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder:
          (context) => Positioned.fill(
            child: IgnorePointer(
              child: CompositedTransformFollower(
                link: _tooltipLayerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomCenter,
                followerAnchor: Alignment.topLeft,
                offset: const Offset(-120, 8),
                child: UnconstrainedBox(
                  alignment: Alignment.topLeft,
                  child: _FolderChainTooltipOverlay(message: widget.item.name),
                ),
              ),
            ),
          ),
    );
    _tooltipOverlayEntry = entry;
    overlay.insert(entry);
  }

  void _removeTooltipOverlay() {
    _tooltipOverlayEntry?.remove();
    _tooltipOverlayEntry = null;
  }
}

class _FolderChainTooltipOverlay extends StatelessWidget {
  const _FolderChainTooltipOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = TooltipTheme.of(context);
    return SizedBox(
      width: 240,
      child: Center(
        child: DecoratedBox(
          decoration:
              theme.decoration ??
              BoxDecoration(
                color: const Color(0xe6616161),
                borderRadius: BorderRadius.circular(4),
              ),
          child: Padding(
            padding:
                theme.padding ??
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  theme.textStyle ??
                  const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}
