part of 'search_page.dart';

class _SearchResultCardGrid extends StatelessWidget {
  const _SearchResultCardGrid({required this.type, required this.children});

  final SearchResultType type;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isArtist = type == SearchResultType.artists;
    final spacing = isArtist ? 12.0 : 30.0;
    final runSpacing = isArtist ? 2.0 : 26.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final itemWidth =
            isArtist && maxWidth.isFinite
                ? _stretchedGridWidth(maxWidth, 260, spacing)
                : 180.0;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

double _stretchedGridWidth(double maxWidth, double minWidth, double spacing) {
  final rawColumns = ((maxWidth + spacing) / (minWidth + spacing)).floor();
  final columns = rawColumns < 1 ? 1 : rawColumns;
  return (maxWidth - spacing * (columns - 1)) / columns;
}

class _SearchSelectionMark extends StatelessWidget {
  const _SearchSelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? _SearchColors.accent : colors.selectionMarkSurface,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.transparent : colors.selectionMarkBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1f485870),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: 23,
        child:
            selected
                ? const Icon(
                  FluentIcons.checkmark_16_regular,
                  color: Colors.white,
                  size: 16,
                )
                : null,
      ),
    );
  }
}

class _SearchResultCard extends StatefulWidget {
  const _SearchResultCard({
    required this.card,
    required this.type,
    required this.query,
    required this.selected,
    required this.multiSelect,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSelection,
    required this.onOpenContextMenu,
  });

  final SearchResult card;
  final SearchResultType type;
  final String query;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final VoidCallback onToggleSelection;
  final FutureOr<void> Function(Offset) onOpenContextMenu;

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  var _hovered = false;
  var _contextMenuOpen = false;

  Future<void> _openContextMenu(Offset position) async {
    setState(() {
      _contextMenuOpen = true;
    });
    try {
      await widget.onOpenContextMenu(position);
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
    final isArtist = widget.type == SearchResultType.artists;
    if (isArtist) {
      return SearchArtistCard(
        title: widget.card.title,
        subtitle: widget.card.subtitle,
        searchQuery: widget.query,
        artworkPath: widget.card.artworkUrl,
        selected: widget.selected,
        multiSelect: widget.multiSelect,
        playTooltip: context.smPlayerI18n.t('context.play'),
        onOpen: widget.onOpen,
        onPlay: widget.onPlay,
        onToggleSelection: widget.onToggleSelection,
        onOpenContextMenu: widget.onOpenContextMenu,
      );
    }
    final artworkFile =
        widget.card.artworkUrl.isEmpty ? null : File(widget.card.artworkUrl);
    final hoverActive = _hovered || _contextMenuOpen;

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
        onTap: widget.multiSelect ? widget.onToggleSelection : widget.onOpen,
        onSecondaryTapDown: (details) {
          unawaited(_openContextMenu(details.globalPosition));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _cardSurface(),
            borderRadius: BorderRadius.circular(14),
            boxShadow: _cardShadow(),
          ),
          child: Stack(
            children: [
              _SearchGridCardBody(
                title: widget.card.title,
                subtitle: widget.card.subtitle,
                query: widget.query,
                artwork: _SearchCardArtwork(
                  file: artworkFile,
                  size: 156,
                  radius: 12,
                ),
              ),
              if (hoverActive && !widget.multiSelect)
                Positioned(
                  top: 116,
                  right: 8,
                  child: _SearchCardPlayButton(onPressed: widget.onPlay),
                ),
              if (widget.multiSelect || widget.selected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _SearchSelectionMark(selected: widget.selected),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _cardSurface() {
    final colors = SearchPageThemeColors.of(context);
    if (widget.selected) {
      return colors.cardSelected;
    }
    if (_hovered || _contextMenuOpen) {
      return colors.panel;
    }
    return Colors.transparent;
  }

  List<BoxShadow>? _cardShadow() {
    if (!widget.selected) {
      return null;
    }
    return const [
      BoxShadow(
        color: Color(0x1f1f2a38),
        blurRadius: 18,
        offset: Offset(0, 10),
      ),
    ];
  }
}

class _SearchGridCardBody extends StatelessWidget {
  const _SearchGridCardBody({
    required this.title,
    required this.subtitle,
    required this.query,
    required this.artwork,
  });

  final String title;
  final String subtitle;
  final String query;
  final Widget artwork;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        artwork,
        const SizedBox(height: 12),
        SearchMatchText(
          text: title,
          query: query,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        SearchMatchText(
          text: subtitle,
          query: query,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _SearchCardArtwork extends StatelessWidget {
  const _SearchCardArtwork({
    required this.file,
    required this.size,
    required this.radius,
  });

  final File? file;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: SongArtwork(artworkPath: file?.path),
      ),
    );
  }
}

class _SearchCardPlayButton extends StatelessWidget {
  const _SearchCardPlayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ArtworkFloatingActionButton(
      tooltip: context.smPlayerI18n.t('context.play'),
      size: 34,
      iconSize: 17,
      icon: const SmPlayerPlayIcon(size: 17, color: Colors.white),
      onPressed: onPressed,
    );
  }
}
