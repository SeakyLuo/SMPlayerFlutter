part of 'local_table_content.dart';

class _PinnedContextMenuInkWell extends StatefulWidget {
  const _PinnedContextMenuInkWell({
    required this.onOpenContextMenu,
    required this.onTap,
    required this.child,
  });

  final FutureOr<void> Function(Offset) onOpenContextMenu;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PinnedContextMenuInkWell> createState() =>
      _PinnedContextMenuInkWellState();
}

class _PinnedContextMenuInkWellState extends State<_PinnedContextMenuInkWell> {
  final _statesController = WidgetStatesController();

  Future<void> _openContextMenu(Offset position) async {
    _statesController.update(WidgetState.hovered, true);
    try {
      await widget.onOpenContextMenu(position);
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _statesController.update(WidgetState.hovered, false);
      });
    }
  }

  @override
  void dispose() {
    _statesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown:
          (details) => unawaited(_openContextMenu(details.globalPosition)),
      child: InkWell(
        statesController: _statesController,
        onTap: widget.onTap,
        child: widget.child,
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Text(
        text,
        style: TextStyle(
          color: colors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TableRowHost extends StatefulWidget {
  const _TableRowHost({required this.row});

  final TableRow row;

  @override
  State<_TableRowHost> createState() => _TableRowHostState();
}

class _TableRowHostState extends State<_TableRowHost> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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
      child: _LocalTableRowHover(
        visible: _hovered,
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.5),
            1: FlexColumnWidth(1.25),
            2: FlexColumnWidth(1.25),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [widget.row],
        ),
      ),
    );
  }
}

class _LocalTableRowHover extends InheritedWidget {
  const _LocalTableRowHover({required this.visible, required super.child});

  final bool visible;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_LocalTableRowHover>()
            ?.visible ??
        false;
  }

  @override
  bool updateShouldNotify(_LocalTableRowHover oldWidget) {
    return oldWidget.visible != visible;
  }
}

class _TextLinkCell extends StatelessWidget {
  const _TextLinkCell({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.accentStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _LocalTableActions extends StatelessWidget {
  const _LocalTableActions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final visible = _LocalTableRowHover.of(context);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          height: 36,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children:
                children
                    .map(
                      (child) => IconTheme(
                        data: const IconThemeData(size: 18),
                        child: SizedBox.square(dimension: 34, child: child),
                      ),
                    )
                    .toList(),
          ),
        ),
      ),
    );
  }
}

class _LocalTableTypeIcon extends StatelessWidget {
  const _LocalTableTypeIcon.folder() : assetPath = 'assets/branding/folder.png';

  const _LocalTableTypeIcon.song()
    : assetPath = 'assets/branding/colorful_no_bg.png';

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(assetPath, width: 24, height: 24, fit: BoxFit.contain);
  }
}

class _LocalTableCheckMark extends StatelessWidget {
  const _LocalTableCheckMark({required this.selected});

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
