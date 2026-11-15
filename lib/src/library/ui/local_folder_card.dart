import '../../remote/music_share_models.dart';
import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/smplayer_vector_icons.dart';
import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import '../data/library_providers.dart';
import 'artwork_floating_action_button.dart';
import 'card_corner_badge.dart';
import 'grid_artwork_card_content.dart';
import 'local_folder_model.dart';
import 'local_i18n_counts.dart';
import 'local_page_quick_jump.dart';
import 'playlist_artwork.dart';
import 'search_match_text.dart';
import 'selected_collection_card_style.dart';

part 'local_folder_card_parts.dart';

class LocalFolderCard extends StatefulWidget {
  const LocalFolderCard({
    super.key,
    required this.folder,
    required this.selected,
    required this.multiSelect,
    required this.nodes,
    required this.songsById,
    required this.i18n,
    this.variant = LocalFolderCardVariant.grid,
    this.treeExpanded,
    this.treeExpandable = false,
    this.onToggleTreeExpanded,
    required this.onPlayFolder,
    required this.onAddFolder,
    required this.onRefreshFolder,
    required this.onSearchFolder,
    required this.onRevealFolder,
    required this.onOpenFolder,
    required this.onOpenFolderMenu,
    required this.onToggleSelection,
    this.onWillAcceptDrop,
    this.onAcceptDrop,
    this.searchQuery = '',
  });

  final FolderNode folder;
  final bool selected;
  final bool multiSelect;
  final Map<String, FolderNode> nodes;
  final Map<int, LibrarySong> songsById;
  final SmPlayerI18n i18n;
  final LocalFolderCardVariant variant;
  final bool? treeExpanded;
  final bool treeExpandable;
  final VoidCallback? onToggleTreeExpanded;
  final ValueChanged<FolderNode> onPlayFolder;
  final FutureOr<void> Function(FolderNode folder, Offset position) onAddFolder;
  final ValueChanged<FolderNode> onRefreshFolder;
  final ValueChanged<FolderNode> onSearchFolder;
  final ValueChanged<FolderNode> onRevealFolder;
  final ValueChanged<String> onOpenFolder;
  final FutureOr<void> Function(FolderNode folder, Offset position)
  onOpenFolderMenu;
  final ValueChanged<String> onToggleSelection;
  final bool Function(FolderNode folder, LocalItemsDragPayload payload)?
  onWillAcceptDrop;
  final void Function(FolderNode folder, LocalItemsDragPayload payload)?
  onAcceptDrop;
  final String searchQuery;

  @override
  State<LocalFolderCard> createState() => _LocalFolderCardState();
}

class _LocalFolderCardState extends State<LocalFolderCard> {
  var _hovered = false;
  var _focused = false;
  var _addMenuOpen = false;
  var _contextMenuOpen = false;

  Future<void> _openContextMenu(Offset position) async {
    setState(() {
      _contextMenuOpen = true;
    });
    try {
      await widget.onOpenFolderMenu(widget.folder, position);
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _contextMenuOpen = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<LocalItemsDragPayload>(
      onWillAcceptWithDetails:
          isRemoteMusicPath(widget.folder.path) ||
                  widget.onWillAcceptDrop == null
              ? null
              : (details) =>
                  widget.onWillAcceptDrop!(widget.folder, details.data),
      onAcceptWithDetails:
          isRemoteMusicPath(widget.folder.path) || widget.onAcceptDrop == null
              ? null
              : (details) => widget.onAcceptDrop!(widget.folder, details.data),
      builder: (context, candidateData, rejectedData) {
        final card =
            widget.variant == LocalFolderCardVariant.list
                ? _buildListCard(context, dropTarget: candidateData.isNotEmpty)
                : _buildGridCard(context, dropTarget: candidateData.isNotEmpty);
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
          child: Focus(
            onFocusChange: (focused) {
              setState(() {
                _focused = focused;
              });
            },
            child: card,
          ),
        );
      },
    );
  }

  Widget _buildGridCard(BuildContext context, {required bool dropTarget}) {
    final colors = LocalPageColors.of(context);
    final selectedStyle = SelectedCollectionCardStyle.forBrightness(
      Theme.of(context).brightness,
    );
    final hoverStyle = SelectedCollectionCardStyle.hoverForBrightness(
      Theme.of(context).brightness,
    );
    final active =
        widget.selected ||
        _hovered ||
        _focused ||
        _addMenuOpen ||
        _contextMenuOpen;
    final hovered = _hovered || _focused || _addMenuOpen || _contextMenuOpen;
    final hoverActionsOffset =
        Directionality.of(context) == TextDirection.ltr
            ? const Offset(0.18, 0)
            : const Offset(-0.18, 0);
    final hoverActionsDuration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160);
    return GestureDetector(
      onSecondaryTapDown:
          (details) => unawaited(_openContextMenu(details.globalPosition)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            widget.multiSelect
                ? () => widget.onToggleSelection(widget.folder.relativePath)
                : _open,
        child: Container(
          width: 180,
          constraints: const BoxConstraints(minHeight: 232),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                widget.selected
                    ? selectedStyle.background
                    : hovered
                    ? hoverStyle.background
                    : colors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow:
                widget.selected
                    ? [selectedStyle.shadow]
                    : hovered
                    ? [hoverStyle.shadow]
                    : const [],
          ),
          foregroundDecoration:
              active
                  ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          widget.selected
                              ? selectedStyle.border
                              : hoverStyle.border,
                    ),
                  )
                  : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _FolderArtwork(
                    dropTarget: dropTarget,
                    selected: widget.selected || hovered,
                    folder: widget.folder,
                    nodes: widget.nodes,
                    songsById: widget.songsById,
                  ),
                  if (widget.multiSelect)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _LocalCheckMark(selected: widget.selected),
                    ),
                  if (!widget.multiSelect)
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !hovered,
                        child: AnimatedSlide(
                          offset: hovered ? Offset.zero : hoverActionsOffset,
                          duration: hoverActionsDuration,
                          curve: Curves.easeInOutCubic,
                          child: AnimatedOpacity(
                            opacity: hovered ? 1 : 0,
                            duration: hoverActionsDuration,
                            curve: Curves.easeInOutCubic,
                            child: _FolderCardActions(
                              folder: widget.folder,
                              i18n: widget.i18n,
                              onPlayFolder: widget.onPlayFolder,
                              onAddFolder: (_, position) {
                                unawaited(_openAddMenu(position));
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Positioned(
                    right: 7,
                    bottom: 7,
                    child: _FolderTypeBadge(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _OverflowTooltipText(
                text: widget.folder.name,
                query: widget.searchQuery,
                style: TextStyle(
                  color:
                      widget.selected
                          ? selectedStyle.foreground
                          : colors.textStrong,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _folderInfo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      widget.selected ? selectedStyle.muted : colors.textMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context, {required bool dropTarget}) {
    final colors = LocalPageColors.of(context);
    final selectedStyle = SelectedCollectionCardStyle.forBrightness(
      Theme.of(context).brightness,
    );
    final hoverStyle = SelectedCollectionCardStyle.hoverForBrightness(
      Theme.of(context).brightness,
    );
    final active =
        widget.selected ||
        _hovered ||
        _focused ||
        _addMenuOpen ||
        _contextMenuOpen;
    final hasTreeToggle =
        widget.onToggleTreeExpanded != null && widget.treeExpandable;
    return GestureDetector(
      onSecondaryTapDown:
          (details) => unawaited(_openContextMenu(details.globalPosition)),
      child: InkWell(
        onTap:
            widget.multiSelect
                ? () => widget.onToggleSelection(widget.folder.relativePath)
                : _open,
        child: AnimatedContainer(
          key: const ValueKey('LocalFolderCard.ListDropSurface'),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 46),
          padding: EdgeInsets.only(left: hasTreeToggle ? 8 : 14, right: 14),
          decoration: BoxDecoration(
            color:
                widget.selected
                    ? selectedStyle.background
                    : active
                    ? hoverStyle.background
                    : hoverStyle.transparentBackground,
          ),
          foregroundDecoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color:
                    dropTarget
                        ? colors.accentStrong
                        : widget.selected
                        ? selectedStyle.border
                        : active
                        ? hoverStyle.border
                        : Colors.transparent,
                width: dropTarget ? 2 : 1,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
          ),
          child: Row(
            children: [
              if (hasTreeToggle) ...[
                SizedBox.square(
                  dimension: 24,
                  child: IconButton(
                    key: const ValueKey('LocalFolderCard.ListTreeToggle'),
                    tooltip: widget.folder.name,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    style: ButtonStyle(
                      backgroundColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.hovered)) {
                          return colors.accentStrong;
                        }
                        return colors.textMuted;
                      }),
                      overlayColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.hovered)) {
                          return colors.accentSoft;
                        }
                        return Colors.transparent;
                      }),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      minimumSize: const WidgetStatePropertyAll(
                        Size.square(24),
                      ),
                      fixedSize: const WidgetStatePropertyAll(Size.square(24)),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: widget.onToggleTreeExpanded,
                    icon: Icon(
                      widget.treeExpanded == true
                          ? FluentIcons.chevron_down_20_regular
                          : FluentIcons.chevron_right_20_regular,
                    ),
                  ),
                ),
              ],
              if (widget.multiSelect) ...[
                _LocalCheckMark(selected: widget.selected),
                const SizedBox(width: 10),
              ],
              const _FolderListIcon(),
              const SizedBox(width: 10),
              Expanded(
                child: _OverflowTooltipText(
                  text: widget.folder.name,
                  query: widget.searchQuery,
                  style: TextStyle(
                    color:
                        widget.selected
                            ? selectedStyle.foreground
                            : colors.textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontVariations: const [FontVariation.weight(690)],
                  ),
                ),
              ),
              if (widget.multiSelect)
                _FolderListInfoText(
                  text: _folderInfo,
                  colors: colors,
                  color: widget.selected ? selectedStyle.muted : null,
                )
              else
                SizedBox(
                  width: 148,
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: _LocalRevealedActions(
                          visible: !active,
                          child: _FolderListInfoText(
                            text: _folderInfo,
                            colors: colors,
                            color: widget.selected ? selectedStyle.muted : null,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _LocalRevealedActions(
                          visible: active,
                          slideFromTrailing: true,
                          child: Row(
                            key: const ValueKey('LocalFolderCard.ListActions'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LocalIconAction(
                                tooltip: widget.i18n.t(
                                  'local.gridFolderPlayInfo',
                                  {'name': widget.folder.name},
                                ),
                                icon: FluentIcons.play_20_regular,
                                onPressed:
                                    () => widget.onPlayFolder(widget.folder),
                              ),
                              const SizedBox(width: 2),
                              _LocalIconAction.positioned(
                                tooltip: widget.i18n.t('context.addToPlaylist'),
                                icon: FluentIcons.add_20_regular,
                                active: _addMenuOpen,
                                onPressedAtBottom: (position) {
                                  unawaited(_openAddMenu(position));
                                },
                                enabled:
                                    widget.folder.subtreeSongIds.isNotEmpty,
                              ),
                              const SizedBox(width: 2),
                              if (!isRemoteMusicPath(widget.folder.path))
                                _LocalIconAction(
                                  tooltip: widget.i18n.t('local.updateFolder'),
                                  icon: FluentIcons.arrow_sync_20_regular,
                                  onPressed:
                                      () =>
                                          widget.onRefreshFolder(widget.folder),
                                ),
                              const SizedBox(width: 2),
                              _LocalIconAction(
                                tooltip: widget.i18n.t(
                                  'local.searchFolderButtonTooltip',
                                ),
                                icon: FluentIcons.search_20_regular,
                                onPressed:
                                    () => widget.onSearchFolder(widget.folder),
                              ),
                              const SizedBox(width: 2),
                              if (!isRemoteMusicPath(widget.folder.path))
                                _LocalIconAction(
                                  tooltip: widget.i18n.t(
                                    'local.openLocalButtonTooltip',
                                  ),
                                  icon: FluentIcons.folder_open_20_regular,
                                  onPressed:
                                      () =>
                                          widget.onRevealFolder(widget.folder),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String get _folderInfo {
    if (widget.folder.childPaths.isNotEmpty) {
      return formatFolderCardStats(
        widget.i18n,
        widget.folder.childPaths.length,
        widget.folder.directSongIds.length,
      );
    }

    return formatLocalFolderSongCount(
      widget.i18n,
      widget.folder.directSongIds.length,
    );
  }

  void _open() {
    widget.onOpenFolder(widget.folder.relativePath);
  }

  Future<void> _openAddMenu(Offset position) async {
    setState(() {
      _addMenuOpen = true;
    });
    try {
      await widget.onAddFolder(widget.folder, position);
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _addMenuOpen = false;
        });
      });
    }
  }
}

enum LocalFolderCardVariant { grid, list }
