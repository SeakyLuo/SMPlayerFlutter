part of 'local_folder_card.dart';

class _OverflowTooltipText extends StatelessWidget {
  const _OverflowTooltipText({
    required this.text,
    required this.style,
    this.query = '',
  });

  final String text;
  final TextStyle style;
  final String query;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final label = SearchMatchText(
          text: text,
          query: query,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
        return painter.didExceedMaxLines
            ? Tooltip(message: text, child: label)
            : label;
      },
    );
  }
}

class _FolderListInfoText extends StatelessWidget {
  const _FolderListInfoText({
    required this.text,
    required this.colors,
    this.color,
  });

  final String text;
  final LocalPageColors colors;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color ?? colors.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        fontVariations: const [FontVariation.weight(520)],
        height: 1.2,
      ),
    );
  }
}

class _LocalRevealedActions extends StatelessWidget {
  const _LocalRevealedActions({
    required this.visible,
    required this.child,
    this.slideFromTrailing = false,
  });

  final bool visible;
  final Widget child;
  final bool slideFromTrailing;

  @override
  Widget build(BuildContext context) {
    final duration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160);
    final hiddenOffset =
        !slideFromTrailing
            ? Offset.zero
            : Directionality.of(context) == TextDirection.ltr
            ? const Offset(0.18, 0)
            : const Offset(-0.18, 0);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : hiddenOffset,
        duration: duration,
        curve: Curves.easeInOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: duration,
          curve: Curves.easeInOutCubic,
          child: child,
        ),
      ),
    );
  }
}

class _FolderArtwork extends ConsumerStatefulWidget {
  const _FolderArtwork({
    required this.dropTarget,
    required this.selected,
    required this.folder,
    required this.nodes,
    required this.songsById,
  });

  final bool dropTarget;
  final bool selected;
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
    final selectedStyle = SelectedCollectionCardStyle.forBrightness(
      Theme.of(context).brightness,
    );
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
            color:
                widget.selected
                    ? selectedStyle.artworkShadow.color
                    : colors.artworkShadow,
            offset:
                widget.selected
                    ? selectedStyle.artworkShadow.offset
                    : Offset(0, 12),
            blurRadius:
                widget.selected ? selectedStyle.artworkShadow.blurRadius : 24,
          ),
          if (widget.dropTarget)
            BoxShadow(color: colors.accentSoft, blurRadius: 0, spreadRadius: 5),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 160,
          child: GridArtworkCover(
            artworkUrls: _thumbnailPaths,
            fallback: const _LocalFolderArtworkFallback(),
          ),
        ),
      ),
    );
  }

  void _refreshArtwork() {
    if (widget.folder.artworkPaths case final paths?) {
      _thumbnailPaths = paths;
      return;
    }

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

class _LocalFolderArtworkFallback extends StatelessWidget {
  const _LocalFolderArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _LocalDefaultArtworkBackground(),
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
  final FutureOr<void> Function(FolderNode folder, Offset position) onAddFolder;

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
       enabled = true,
       active = false;

  const _LocalIconAction.positioned({
    required this.tooltip,
    required this.icon,
    required this.onPressedAtBottom,
    required this.enabled,
    this.active = false,
  }) : onPressed = null;

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final ValueChanged<Offset>? onPressedAtBottom;
  final bool enabled;
  final bool active;

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
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (active) {
              return colors.accentSoft;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.disabled;
            }
            if (active || states.contains(WidgetState.hovered)) {
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
    return const CardCornerBadge(
      key: ValueKey('LocalFolderCard.FolderTypeBadge'),
      child: _FolderTypeBadgeImage(iconSize: 20),
    );
  }
}

class _FolderListIcon extends StatelessWidget {
  const _FolderListIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      key: ValueKey('LocalFolderCard.ListIconSlot'),
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
