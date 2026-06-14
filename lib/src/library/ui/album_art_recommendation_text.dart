part of 'music_dialog.dart';

class _AlbumArtRecommendationText extends StatelessWidget {
  const _AlbumArtRecommendationText({
    required this.recommendation,
    required this.onApply,
    this.showFallbackLabel = true,
  });

  final AlbumArtRecommendation recommendation;
  final ValueChanged<AlbumArtRecommendation> onApply;
  final bool showFallbackLabel;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final colors = PopupDialogColors.resolve(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        key: const ValueKey('MusicDialog.AlbumArtRecommendation'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        children: [
          if (showFallbackLabel)
            Text(
              i18n.t('song.noAlbumArt'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.35,
              ),
            ),
          SizedBox(
            width: 500,
            height: 40,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final prefix = i18n.t('song.albumArtRecommendationPrefix', {
                  'artist': recommendation.artistName,
                });
                final label = i18n.t('song.albumArtRecommendationTitle', {
                  'title': recommendation.song.title,
                });
                final normalStyle = TextStyle(
                  color: colors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                );
                final lineText =
                    '$prefix$label${i18n.t('song.albumArtRecommendationSuffix')}';
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: math.min(220, constraints.maxWidth),
                        height: 40,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            lineText,
                            key: const ValueKey(
                              'MusicDialog.AlbumArtRecommendationLine',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: normalStyle,
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 196.5390625,
                      top: 0,
                      child: SizedBox(
                        width: 281.4921875,
                        height: 40,
                        child: _AlbumArtRecommendationButtonHost(),
                      ),
                    ),
                    Positioned(
                      left: 196.5390625,
                      top: 0,
                      child: _AlbumArtRecommendationButton(
                        recommendation: recommendation,
                        onApply: onApply,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
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
  var _hovered = false;
  var _focused = false;

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() {
      _hovered = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _hovered || _focused;
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      cursor: SystemMouseCursors.click,
      child: Focus(
        onFocusChange: (focused) {
          setState(() {
            _focused = focused;
          });
        },
        child: SizedBox(
          key: const ValueKey('MusicDialog.AlbumArtRecommendationButton'),
          width: 281.4921875,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey(
                    'MusicDialog.AlbumArtRecommendationButtonHitTarget',
                  ),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.onApply(widget.recommendation);
                  },
                ),
              ),
              Positioned(
                left: 192.234375,
                bottom: 0,
                child: _AlbumArtRecommendationPreview(
                  recommendation: widget.recommendation,
                  visible: visible,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumArtRecommendationButtonHost extends StatelessWidget {
  const _AlbumArtRecommendationButtonHost();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      key: ValueKey('MusicDialog.AlbumArtRecommendationButtonChrome'),
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
    final colors = PopupDialogColors.resolve(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: AnimatedOpacity(
        key: const ValueKey('MusicDialog.AlbumArtRecommendationPreview'),
        duration: const Duration(milliseconds: 120),
        opacity: visible ? 1 : 0,
        child: Transform.translate(
          offset: Offset(0, visible ? 0 : 6),
          child: SizedBox.square(
            dimension: 128,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: nightMode ? const Color(0xf51c222b) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: nightMode ? colors.border : const Color(0x337e8b9a),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        nightMode
                            ? const Color(0x5c000000)
                            : const Color(0x38332644),
                    offset: const Offset(0, 18),
                    blurRadius: 44,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _ArtworkImage(
                  url: recommendation.artworkUrl,
                  size: 112,
                  borderRadius: 8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
