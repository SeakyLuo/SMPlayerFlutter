part of 'local_compact_table_content.dart';

class _FolderRowSurface extends StatelessWidget {
  const _FolderRowSurface({
    required this.folder,
    required this.treeRow,
    required this.selected,
    required this.multiSelect,
    required this.i18n,
    required this.onToggleTreeFolderExpanded,
    required this.actions,
  });

  final FolderNode folder;
  final LocalCompactTreeRow? treeRow;
  final bool selected;
  final bool multiSelect;
  final SmPlayerI18n i18n;
  final ValueChanged<String> onToggleTreeFolderExpanded;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.fromLTRB(14 + (treeRow?.depth ?? 0) * 22.0, 0, 14, 0),
      decoration: BoxDecoration(
        color: selected ? colors.rowSelected : colors.panel,
        border: Border.all(color: colors.borderSubtle),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: colors.cardShadow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          if (treeRow != null)
            SizedBox(
              width: 24,
              height: 24,
              child:
                  treeRow!.expandable
                      ? IconButton(
                        tooltip: folder.name,
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        color: colors.textMuted,
                        icon: Icon(
                          treeRow!.expanded
                              ? FluentIcons.chevron_down_20_regular
                              : FluentIcons.chevron_right_20_regular,
                        ),
                        onPressed:
                            () =>
                                onToggleTreeFolderExpanded(folder.relativePath),
                      )
                      : null,
            ),
          if (multiSelect) ...[
            _CompactTableCheckMark(selected: selected),
            const SizedBox(width: 10),
          ],
          const _CompactTableTypeImage(assetPath: 'assets/branding/folder.png'),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            i18n.t('playlists.songCount', {
              'count': treeRow == null ? folder.directCount : folder.songCount,
            }),
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Icon(
            FluentIcons.chevron_right_20_regular,
            size: 17,
            color: colors.textMuted,
          ),
          actions,
        ],
      ),
    );
  }
}

class _SongRowSurface extends StatelessWidget {
  const _SongRowSurface({
    required this.song,
    required this.depth,
    required this.selected,
    required this.current,
    required this.multiSelect,
    required this.i18n,
    required this.actions,
  });

  final LibrarySong song;
  final int depth;
  final bool selected;
  final bool current;
  final bool multiSelect;
  final SmPlayerI18n i18n;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: EdgeInsets.fromLTRB(10 + depth * 22.0, 8, 8, 8),
      decoration: BoxDecoration(
        color: selected || current ? colors.rowSelected : Colors.transparent,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 24,
            child: Row(
              children: [
                if (multiSelect) ...[
                  _CompactTableCheckMark(selected: selected),
                  const SizedBox(width: 10),
                ],
                current
                    ? Icon(
                      FluentIcons.play_20_regular,
                      color: colors.accentStrong,
                      size: 18,
                    )
                    : const _CompactTableTypeImage(
                      assetPath: 'assets/branding/colorful_no_bg.png',
                    ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: current ? colors.accentStrong : colors.textStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                actions,
              ],
            ),
          ),
          _SongMetaLine(text: getLocalDisplayArtists(song, i18n)),
          _SongMetaLine(text: displayAlbum(song, i18n)),
        ],
      ),
    );
  }
}

class _SongMetaLine extends StatelessWidget {
  const _SongMetaLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    return SizedBox(
      height: 18,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.textMuted, fontSize: 13),
        ),
      ),
    );
  }
}

class _CompactTableActions extends StatelessWidget {
  const _CompactTableActions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final visible = _CompactHoverState.of(context);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.ease,
        child: SizedBox(
          height: 24,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children:
                children
                    .map(
                      (child) => IconTheme(
                        data: const IconThemeData(size: 14),
                        child: SizedBox.square(dimension: 24, child: child),
                      ),
                    )
                    .toList(),
          ),
        ),
      ),
    );
  }
}

class _CompactHoverRow extends StatefulWidget {
  const _CompactHoverRow({required this.child, this.onOpenContextMenu});

  final Widget child;
  final FutureOr<void> Function(Offset)? onOpenContextMenu;

  @override
  State<_CompactHoverRow> createState() => _CompactHoverRowState();
}

class _CompactHoverRowState extends State<_CompactHoverRow> {
  var _hovered = false;
  var _focused = false;
  var _contextMenuOpen = false;

  Future<void> _openContextMenu(Offset position) async {
    setState(() => _contextMenuOpen = true);
    try {
      await widget.onOpenContextMenu!(position);
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _contextMenuOpen = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onSecondaryTapDown:
            widget.onOpenContextMenu == null
                ? null
                : (details) =>
                    unawaited(_openContextMenu(details.globalPosition)),
        child: Focus(
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: _CompactHoverState(
            visible: _hovered || _focused || _contextMenuOpen,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _CompactHoverState extends InheritedWidget {
  const _CompactHoverState({required this.visible, required super.child});

  final bool visible;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_CompactHoverState>()
            ?.visible ??
        false;
  }

  @override
  bool updateShouldNotify(_CompactHoverState oldWidget) {
    return visible != oldWidget.visible;
  }
}

class _CompactTableTypeImage extends StatelessWidget {
  const _CompactTableTypeImage({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 24,
      child: Image.asset(assetPath, fit: BoxFit.contain),
    );
  }
}

class _CompactTableCheckMark extends StatelessWidget {
  const _CompactTableCheckMark({required this.selected});

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

void _invokeAtButtonBottom(BuildContext context, ValueChanged<Offset> action) {
  final box = context.findRenderObject() as RenderBox;
  action(box.localToGlobal(Offset(0, box.size.height + 6)));
}
