import 'dart:async';
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/smplayer_vector_icons.dart';
import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import '../data/library_providers.dart';
import 'artwork_floating_action_button.dart';
import 'local_folder_model.dart';
import 'local_i18n_counts.dart';
import 'local_page_quick_jump.dart';
import 'playlist_artwork.dart';

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
  final void Function(FolderNode folder, Offset position) onAddFolder;
  final ValueChanged<FolderNode> onRefreshFolder;
  final ValueChanged<FolderNode> onSearchFolder;
  final ValueChanged<FolderNode> onRevealFolder;
  final ValueChanged<String> onOpenFolder;
  final void Function(FolderNode folder, Offset position) onOpenFolderMenu;
  final ValueChanged<String> onToggleSelection;
  final bool Function(FolderNode folder, LocalItemsDragPayload payload)?
  onWillAcceptDrop;
  final void Function(FolderNode folder, LocalItemsDragPayload payload)?
  onAcceptDrop;

  @override
  State<LocalFolderCard> createState() => _LocalFolderCardState();
}

class _LocalFolderCardState extends State<LocalFolderCard> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<LocalItemsDragPayload>(
      onWillAcceptWithDetails:
          widget.onWillAcceptDrop == null
              ? null
              : (details) =>
                  widget.onWillAcceptDrop!(widget.folder, details.data),
      onAcceptWithDetails:
          widget.onAcceptDrop == null
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
    final active = widget.selected || _hovered || _focused;
    return GestureDetector(
      onSecondaryTapDown:
          (details) =>
              widget.onOpenFolderMenu(widget.folder, details.globalPosition),
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
            color: active ? colors.surfaceCardHover : colors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow:
                active
                    ? [
                      BoxShadow(
                        color: colors.panelShadow,
                        offset: Offset(0, 16),
                        blurRadius: 34,
                      ),
                    ]
                    : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _FolderArtwork(
                    dropTarget: dropTarget,
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
                  if (!widget.multiSelect && active)
                    Positioned.fill(
                      child: _FolderCardActions(
                        folder: widget.folder,
                        i18n: widget.i18n,
                        onPlayFolder: widget.onPlayFolder,
                        onAddFolder: widget.onAddFolder,
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
              Text(
                widget.folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textStrong,
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
                  color: colors.textMuted,
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
    final active = widget.selected || _hovered || _focused;
    final hasTreeToggle =
        widget.onToggleTreeExpanded != null && widget.treeExpandable;
    return GestureDetector(
      onSecondaryTapDown:
          (details) =>
              widget.onOpenFolderMenu(widget.folder, details.globalPosition),
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
                    ? colors.rowSelected
                    : active
                    ? colors.surfaceCardHover
                    : Colors.transparent,
          ),
          foregroundDecoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: dropTarget ? colors.accentStrong : Colors.transparent,
                width: 2,
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
                    tooltip: widget.folder.name,
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onToggleTreeExpanded,
                    icon: Icon(
                      widget.treeExpanded == true
                          ? FluentIcons.chevron_down_20_regular
                          : FluentIcons.chevron_right_20_regular,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (widget.multiSelect) ...[
                _LocalCheckMark(selected: widget.selected),
                const SizedBox(width: 10),
              ],
              const _FolderListIcon(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontVariations: const [FontVariation.weight(690)],
                  ),
                ),
              ),
              if (widget.multiSelect)
                _FolderListInfoText(text: _folderInfo, colors: colors)
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
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _LocalRevealedActions(
                          visible: active,
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
                                onPressedAtBottom:
                                    (position) => widget.onAddFolder(
                                      widget.folder,
                                      position,
                                    ),
                                enabled:
                                    widget.folder.subtreeSongIds.isNotEmpty,
                              ),
                              const SizedBox(width: 2),
                              _LocalIconAction(
                                tooltip: widget.i18n.t('local.updateFolder'),
                                icon: FluentIcons.arrow_sync_20_regular,
                                onPressed:
                                    () => widget.onRefreshFolder(widget.folder),
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
                              _LocalIconAction(
                                tooltip: widget.i18n.t(
                                  'local.openLocalButtonTooltip',
                                ),
                                icon: FluentIcons.folder_open_20_regular,
                                onPressed:
                                    () => widget.onRevealFolder(widget.folder),
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
}

enum LocalFolderCardVariant { grid, list }

class _FolderListInfoText extends StatelessWidget {
  const _FolderListInfoText({required this.text, required this.colors});

  final String text;
  final LocalPageColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: colors.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        fontVariations: const [FontVariation.weight(520)],
        height: 1.2,
      ),
    );
  }
}

class _LocalRevealedActions extends StatelessWidget {
  const _LocalRevealedActions({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

class _FolderArtwork extends ConsumerStatefulWidget {
  const _FolderArtwork({
    required this.dropTarget,
    required this.folder,
    required this.nodes,
    required this.songsById,
  });

  final bool dropTarget;
  final FolderNode folder;
  final Map<String, FolderNode> nodes;
  final Map<int, LibrarySong> songsById;

  @override
  ConsumerState<_FolderArtwork> createState() => _FolderArtworkState();
}

class _FolderArtworkState extends ConsumerState<_FolderArtwork> {
  var _signature = '';
  List<String> _thumbnailPaths = const [];
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _refreshArtwork();
  }

  @override
  void didUpdateWidget(_FolderArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folder != widget.folder ||
        oldWidget.nodes != widget.nodes ||
        oldWidget.songsById != widget.songsById) {
      _refreshArtwork();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    return AnimatedContainer(
      key: const ValueKey('LocalFolderCard.GridArtworkDropSurface'),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      foregroundDecoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: widget.dropTarget ? colors.accentStrong : Colors.transparent,
            width: 2,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colors.artworkShadow,
            offset: Offset(0, 12),
            blurRadius: 24,
          ),
          if (widget.dropTarget)
            BoxShadow(color: colors.accentSoft, blurRadius: 0, spreadRadius: 5),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 160,
          child:
              _thumbnailPaths.isEmpty
                  ? Stack(
                    fit: StackFit.expand,
                    children: [
                      _LocalDefaultArtworkBackground(),
                      Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.72,
                          heightFactor: 0.72,
                          child: Opacity(
                            opacity: 0.86,
                            child: Image.asset(
                              'assets/branding/colorful_no_bg.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                  : GridView.count(
                    crossAxisCount: _thumbnailPaths.length == 1 ? 1 : 2,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      for (final path in _thumbnailPaths)
                        Image.file(File(path), fit: BoxFit.cover),
                    ],
                  ),
        ),
      ),
    );
  }

  void _refreshArtwork() {
    final candidateGroups = getOriginalFolderThumbnailCandidateGroups(
      widget.folder,
      widget.nodes,
      widget.songsById,
    );
    final signature = getFolderThumbnailSignature(
      widget.folder,
      candidateGroups,
    );
    if (signature == _signature) {
      return;
    }

    _signature = signature;
    final cachedArtworkUrls = getCachedOriginalFolderThumbnailUrls(signature);
    if (cachedArtworkUrls != null) {
      _thumbnailPaths = cachedArtworkUrls;
      return;
    }

    _thumbnailPaths = const [];
    final generation = ++_generation;
    unawaited(
      resolveOriginalFolderThumbnailUrls(
        candidateGroups,
        ref.read(libraryRepositoryProvider),
      ).then((artworkUrls) {
        cacheOriginalFolderThumbnailUrls(signature, artworkUrls);
        if (!mounted || generation != _generation || signature != _signature) {
          return;
        }
        setState(() {
          _thumbnailPaths = artworkUrls;
        });
      }),
    );
  }
}

class _LocalDefaultArtworkBackground extends StatelessWidget {
  const _LocalDefaultArtworkBackground();

  @override
  Widget build(BuildContext context) {
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    final baseGradient =
        nightMode
            ? const [Color(0xf01f2732), Color(0xf50f141b)]
            : const [Color(0xeff7f9fc), Color(0xe6e3eaf2)];
    final diagonalGradient =
        nightMode
            ? const [
              Color(0x3d417c9a),
              Color(0x4234465c),
              Color(0x06ffffff),
              Color(0x00ffffff),
            ]
            : const [
              Color(0x6b9fd8d7),
              Color(0x47cfe0ee),
              Color(0x1affffff),
              Color(0x00ffffff),
            ];
    final radialGradient =
        nightMode
            ? const [Color(0x1affffff), Color(0x00ffffff)]
            : const [Color(0xb8ffffff), Color(0x00ffffff)];
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: baseGradient,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-0.55, -0.8),
              end: const Alignment(0.8, 1),
              colors: diagonalGradient,
              stops: const [0, 0.44, 0.45, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.4, -0.6),
              radius: 0.72,
              colors: radialGradient,
              stops: const [0.24, 0.48],
            ),
          ),
        ),
      ],
    );
  }
}

class _FolderCardActions extends StatelessWidget {
  const _FolderCardActions({
    required this.folder,
    required this.i18n,
    required this.onPlayFolder,
    required this.onAddFolder,
  });

  final FolderNode folder;
  final SmPlayerI18n i18n;
  final ValueChanged<FolderNode> onPlayFolder;
  final void Function(FolderNode folder, Offset position) onAddFolder;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        key: const ValueKey('LocalFolderCard.GridActions'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ArtworkFloatingActionButton(
            tooltip: i18n.t('local.gridFolderPlayInfo', {'name': folder.name}),
            icon: const SmPlayerPlayIcon(size: 20, color: Colors.white),
            onPressed:
                folder.subtreeSongIds.isEmpty
                    ? null
                    : () => onPlayFolder(folder),
          ),
          const SizedBox(width: 10),
          ArtworkFloatingActionButton(
            tooltip: i18n.t('context.addToPlaylist'),
            icon: const Icon(FluentIcons.add_20_regular),
            onPressed:
                folder.subtreeSongIds.isEmpty
                    ? null
                    : () => _invokeAtButtonBottom(
                      context,
                      (position) => onAddFolder(folder, position),
                    ),
          ),
        ],
      ),
    );
  }
}

void _invokeAtButtonBottom(BuildContext context, ValueChanged<Offset> action) {
  final box = context.findRenderObject() as RenderBox;
  action(box.localToGlobal(Offset(0, box.size.height + 6)));
}

class _LocalIconAction extends StatelessWidget {
  const _LocalIconAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  }) : onPressedAtBottom = null,
       enabled = true;

  const _LocalIconAction.positioned({
    required this.tooltip,
    required this.icon,
    required this.onPressedAtBottom,
    required this.enabled,
  }) : onPressed = null;

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final ValueChanged<Offset>? onPressedAtBottom;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    final effectiveOnPressed =
        onPressedAtBottom == null
            ? onPressed
            : enabled
            ? () => _invokeAtButtonBottom(context, onPressedAtBottom!)
            : null;
    return SizedBox.square(
      dimension: 28,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        visualDensity: VisualDensity.compact,
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.disabled;
            }
            if (states.contains(WidgetState.hovered)) {
              return colors.accentStrong;
            }
            return colors.textStrong;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return colors.accentSoft;
            }
            return Colors.transparent;
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          minimumSize: const WidgetStatePropertyAll(Size.square(28)),
          fixedSize: const WidgetStatePropertyAll(Size.square(28)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon:
            icon == FluentIcons.play_20_regular
                ? const SmPlayerPlayIcon(size: 15)
                : Icon(icon, size: 15),
        onPressed: effectiveOnPressed,
      ),
    );
  }
}

class _FolderTypeBadge extends StatelessWidget {
  const _FolderTypeBadge();

  @override
  Widget build(BuildContext context) {
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: nightMode ? const Color(0xe61f2732) : const Color(0xedffffff),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color:
                nightMode ? const Color(0x57000000) : const Color(0x1f1f2a38),
            offset: Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: const _FolderTypeBadgeImage(iconSize: 20),
    );
  }
}

class _FolderListIcon extends StatelessWidget {
  const _FolderListIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 30,
      child: Center(child: _FolderTypeBadgeImage(iconSize: 22)),
    );
  }
}

class _FolderTypeBadgeImage extends StatelessWidget {
  const _FolderTypeBadgeImage({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/folder.png',
      width: iconSize,
      height: iconSize,
      fit: BoxFit.contain,
    );
  }
}

class _LocalCheckMark extends StatelessWidget {
  const _LocalCheckMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: selected ? colors.accentStrong : colors.selectionMark,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: selected ? colors.accentStrong : colors.selectionBorder,
        ),
      ),
      child:
          selected
              ? const Icon(
                FluentIcons.checkmark_16_regular,
                color: Colors.white,
                size: 14,
              )
              : null,
    );
  }
}
