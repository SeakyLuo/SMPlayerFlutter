part of 'music_dialog.dart';

class _AlbumArtRecommendationText extends StatelessWidget {
  const _AlbumArtRecommendationText({
    required this.recommendation,
    required this.onApply,
  });

  final AlbumArtRecommendation recommendation;
  final ValueChanged<AlbumArtRecommendation> onApply;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(300, MediaQuery.sizeOf(context).width - 124),
      ),
      child: LayoutBuilder(
        builder:
            (context, constraints) => Column(
              key: const ValueKey('MusicDialog.AlbumArtRecommendation'),
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Text(
                  i18n.t('song.noAlbumArt'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: i18n.t('song.albumArtRecommendationPrefix', {
                          'artist': recommendation.artistName,
                        }),
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth,
                          ),
                          child: _AlbumArtRecommendationButton(
                            recommendation: recommendation,
                            onApply: onApply,
                          ),
                        ),
                      ),
                      TextSpan(
                        text: i18n.t('song.albumArtRecommendationSuffix'),
                      ),
                    ],
                  ),
                  key: const ValueKey('MusicDialog.AlbumArtRecommendationLine'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class _AlbumArtRecommendationButton extends StatefulWidget {
  const _AlbumArtRecommendationButton({
    required this.recommendation,
    required this.onApply,
  });
  final AlbumArtRecommendation recommendation;
  final ValueChanged<AlbumArtRecommendation> onApply;

  @override
  State<_AlbumArtRecommendationButton> createState() =>
      _AlbumArtRecommendationButtonState();
}

class _AlbumArtRecommendationButtonState
    extends State<_AlbumArtRecommendationButton> {
  OverlayEntry? _previewEntry;
  var _hovered = false;
  var _focused = false;

  void _updatePreview({bool? hovered, bool? focused}) {
    setState(() {
      if (hovered != null) _hovered = hovered;
      if (focused != null) _focused = focused;
    });
    if (_hovered || _focused) {
      _showPreview();
    } else {
      _hidePreview();
    }
  }

  void _showPreview() {
    if (_previewEntry != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final target = this.context.findRenderObject()! as RenderBox;
            final root = overlay.context.findRenderObject()! as RenderBox;
            final origin = target.localToGlobal(Offset.zero, ancestor: root);
            const previewSize = 128.0;
            const gap = 12.0;
            final left = (origin.dx + (target.size.width - previewSize) / 2)
                .clamp(0.0, constraints.maxWidth - previewSize);
            final above = origin.dy - previewSize - gap;
            final top = (above >= 0
                    ? above
                    : origin.dy + target.size.height + gap)
                .clamp(0.0, constraints.maxHeight - previewSize);
            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: previewSize,
                  height: previewSize,
                  child: _AlbumArtRecommendationPreview(
                    recommendation: widget.recommendation,
                    visible: true,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    _previewEntry = entry;
    overlay.insert(entry);
  }

  void _hidePreview() {
    _previewEntry?.remove();
    _previewEntry?.dispose();
    _previewEntry = null;
  }

  @override
  void dispose() {
    _hidePreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final label = context.smPlayerI18n.t('song.albumArtRecommendationTitle', {
      'title': widget.recommendation.song.title,
    });
    return TextButton(
      key: const ValueKey('MusicDialog.AlbumArtRecommendationButton'),
      onPressed: () => widget.onApply(widget.recommendation),
      onHover: (value) => _updatePreview(hovered: value),
      onFocusChange: (value) => _updatePreview(focused: value),
      style: TextButton.styleFrom(
        foregroundColor: colors.accentStrong,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        overlayColor: Colors.transparent,
        textStyle: TextStyle(
          fontSize: 16,
          height: 1.35,
          fontVariations: const [FontVariation.weight(760)],
          decoration:
              _hovered || _focused
                  ? TextDecoration.underline
                  : TextDecoration.none,
        ),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

class _AlbumArtRecommendationPreview extends StatelessWidget {
  const _AlbumArtRecommendationPreview({
    required this.recommendation,
    required this.visible,
  });

  final AlbumArtRecommendation recommendation;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        key: const ValueKey('MusicDialog.AlbumArtRecommendationPreview'),
        duration: const Duration(milliseconds: 120),
        opacity: visible ? 1 : 0,
        child: Transform.translate(
          offset: Offset(0, visible ? 0 : 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(recommendation.artworkUrl),
              width: 128,
              height: 128,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
