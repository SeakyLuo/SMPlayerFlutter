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
    required this.selected,
    required this.multiSelect,
    required this.onOpen,
    required this.onPlay,
    required this.onToggleSelection,
    required this.onOpenContextMenu,
  });

  final SearchResult card;
  final SearchResultType type;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final VoidCallback onToggleSelection;
  final ValueChanged<Offset> onOpenContextMenu;

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    final isArtist = widget.type == SearchResultType.artists;
    final artworkFile =
        widget.card.artworkUrl.isEmpty ? null : File(widget.card.artworkUrl);

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
          widget.onOpenContextMenu(details.globalPosition);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          constraints: BoxConstraints(minHeight: isArtist ? 86 : 0),
          padding:
              isArtist
                  ? const EdgeInsets.symmetric(horizontal: 14, vertical: 11)
                  : const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _cardSurface(isArtist),
            border:
                isArtist
                    ? Border.all(
                      color:
                          widget.selected
                              ? colors.accentSelectedBorder
                              : Colors.transparent,
                    )
                    : null,
            borderRadius: BorderRadius.circular(isArtist ? 10 : 14),
            boxShadow: _cardShadow(isArtist),
          ),
          child: Stack(
            children: [
              if (isArtist)
                _SearchCompactCardBody(
                  title: widget.card.title,
                  subtitle: widget.card.subtitle,
                  artwork: _SearchCardArtwork(
                    file: artworkFile,
                    size: 64,
                    radius: 8,
                    elevated: _hovered,
                  ),
                )
              else
                _SearchGridCardBody(
                  title: widget.card.title,
                  subtitle: widget.card.subtitle,
                  artwork: _SearchCardArtwork(
                    file: artworkFile,
                    size: 156,
                    radius: 12,
                  ),
                ),
              if (isArtist && _hovered && !widget.multiSelect)
                Positioned.fill(
                  left: 14,
                  right: null,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 30),
                      child: _SearchCardPlayButton(onPressed: widget.onPlay),
                    ),
                  ),
                ),
              if (!isArtist && _hovered && !widget.multiSelect)
                Positioned(
                  top: 116,
                  right: 8,
                  child: _SearchCardPlayButton(onPressed: widget.onPlay),
                ),
              if (widget.multiSelect || widget.selected)
                Positioned(
                  top: isArtist ? 9 : 8,
                  right: isArtist ? 9 : 8,
                  child: _SearchSelectionMark(selected: widget.selected),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _cardSurface(bool isArtist) {
    final colors = SearchPageThemeColors.of(context);
    if (widget.selected) {
      return colors.cardSelected;
    }
    if (_hovered) {
      return isArtist ? colors.cardHover : colors.panel;
    }
    return Colors.transparent;
  }

  List<BoxShadow>? _cardShadow(bool isArtist) {
    if (isArtist) {
      if (!widget.selected && !_hovered) {
        return null;
      }
      return const [
        BoxShadow(
          color: Color(0x141e2a3a),
          blurRadius: 30,
          offset: Offset(0, 14),
        ),
      ];
    }
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

class _SearchCompactCardBody extends StatelessWidget {
  const _SearchCompactCardBody({
    required this.title,
    required this.subtitle,
    required this.artwork,
  });

  final String title;
  final String subtitle;
  final Widget artwork;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    return Row(
      children: [
        artwork,
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchGridCardBody extends StatelessWidget {
  const _SearchGridCardBody({
    required this.title,
    required this.subtitle,
    required this.artwork,
  });

  final String title;
  final String subtitle;
  final Widget artwork;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPageThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        artwork,
        const SizedBox(height: 12),
        Text(
          title,
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
        Text(
          subtitle,
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
    this.elevated = false,
  });

  final File? file;
  final double size;
  final double radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      transform: elevated ? Matrix4.translationValues(0, -1, 0) : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow:
            elevated
                ? const [
                  BoxShadow(
                    color: Color(0x33322d3f),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ]
                : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox.square(
          dimension: size,
          child: SongArtwork(artworkPath: file?.path),
        ),
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
