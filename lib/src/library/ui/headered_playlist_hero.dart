part of 'headered_playlist_control.dart';

class _HeaderHeroSliverDelegate extends SliverPersistentHeaderDelegate {
  const _HeaderHeroSliverDelegate({
    required this.type,
    required this.title,
    required this.info,
    required this.artworkUrls,
    required this.coverColor,
    required this.windowDragCallbacks,
    required this.commandBar,
  });

  final HeaderedPlaylistType type;
  final String title;
  final String info;
  final List<String> artworkUrls;
  final Color coverColor;
  final SmPlayerWindowDragCallbacks? windowDragCallbacks;
  final Widget commandBar;

  @override
  double get minExtent => 126;

  @override
  double get maxExtent => 326;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapseProgress = (shrinkOffset / (maxExtent - minExtent)).clamp(
      0.0,
      1.0,
    );
    return _HeaderHero(
      type: type,
      title: title,
      info: info,
      artworkUrls: artworkUrls,
      coverColor: coverColor,
      collapseProgress: collapseProgress,
      windowDragCallbacks: windowDragCallbacks,
      commandBar: commandBar,
    );
  }

  @override
  bool shouldRebuild(covariant _HeaderHeroSliverDelegate oldDelegate) {
    return type != oldDelegate.type ||
        title != oldDelegate.title ||
        info != oldDelegate.info ||
        artworkUrls != oldDelegate.artworkUrls ||
        coverColor != oldDelegate.coverColor ||
        windowDragCallbacks != oldDelegate.windowDragCallbacks ||
        commandBar != oldDelegate.commandBar;
  }
}

class _HeaderHero extends StatelessWidget {
  const _HeaderHero({
    required this.type,
    required this.title,
    required this.info,
    required this.artworkUrls,
    required this.coverColor,
    required this.collapseProgress,
    required this.windowDragCallbacks,
    required this.commandBar,
  });

  final HeaderedPlaylistType type;
  final String title;
  final String info;
  final List<String> artworkUrls;
  final Color coverColor;
  final double collapseProgress;
  final SmPlayerWindowDragCallbacks? windowDragCallbacks;
  final Widget commandBar;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final colors = HeaderedPlaylistThemeColors.of(context);
    final compactTopInset =
        _compactHeaderTopInset * (1 - collapseProgress).clamp(0.0, 1.0);
    final heroHeight =
        lerpDouble(
          compact ? 320 : 326,
          compact ? 138 : 126,
          collapseProgress,
        )! +
        compactTopInset;
    final coverSize =
        lerpDouble(compact ? 180 : 240, compact ? 68 : 86, collapseProgress)!;
    final titleSize =
        lerpDouble(compact ? 24 : 48, compact ? 20 : 26, collapseProgress)!;
    final commandMargin =
        lerpDouble(compact ? 8 : 30, compact ? 4 : 8, collapseProgress)!;
    final infoMargin = compact ? 8.0 : lerpDouble(24, 8, collapseProgress)!;
    final heroPaddingTop =
        compact ? compactTopInset : lerpDouble(50, 24, collapseProgress)!;
    final horizontalPadding = compact ? 4.0 : 40.0;
    final gap =
        lerpDouble(compact ? 12 : 42, compact ? 12 : 18, collapseProgress)!;
    final backdropOpacity =
        compact ? (1 - collapseProgress).clamp(0.0, 1.0) : 1.0;
    final fixedWidthBackdrop =
        !compact && MediaQuery.sizeOf(context).width <= 900;
    final collapsedDesktop = !compact && collapseProgress >= 1.0;
    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: fixedWidthBackdrop ? -40 : 0,
            right: fixedWidthBackdrop ? -40 : 0,
            bottom: 0,
            child: Opacity(
              opacity: backdropOpacity,
              child: _HeaderedPlaylistBackdrop(
                key: const ValueKey('HeaderedPlaylist.Backdrop'),
                coverColor: coverColor,
                masked: !compact,
              ),
            ),
          ),
          Positioned.fill(
            child: _HeaderHeroSurface(
              coverColor: coverColor,
              surfaceColor: colors.pageSurface,
              collapseProgress: collapseProgress,
            ),
          ),
          Positioned.fill(
            child: _HeaderHeroDragRegion(
              windowDragCallbacks: windowDragCallbacks,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              heroPaddingTop,
              horizontalPadding,
              compact ? 4 : lerpDouble(10, 4, collapseProgress)!,
            ),
            child: Flex(
              direction: compact ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment:
                  compact
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.center,
              children: [
                _HeaderHeroDragRegion(
                  windowDragCallbacks: windowDragCallbacks,
                  child: HeaderedPlaylistCover(
                    artworkUrls: artworkUrls,
                    title: title,
                    type: type,
                    size: coverSize,
                    collapseProgress: collapseProgress,
                  ),
                ),
                SizedBox(width: compact ? 0 : gap, height: compact ? gap : 0),
                Expanded(
                  child: Align(
                    alignment:
                        collapsedDesktop
                            ? Alignment.centerLeft
                            : Alignment.center,
                    child: SizedBox(
                      height: collapsedDesktop ? coverSize : null,
                      child: Column(
                        mainAxisAlignment:
                            compact
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                        crossAxisAlignment:
                            compact
                                ? CrossAxisAlignment.center
                                : CrossAxisAlignment.start,
                        children: [
                          _HeaderHeroDragRegion(
                            windowDragCallbacks: windowDragCallbacks,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: compact ? 420 : 860,
                              ),
                              child: Text(
                                title,
                                maxLines: compact ? 2 : 3,
                                textAlign:
                                    compact
                                        ? TextAlign.center
                                        : TextAlign.start,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textStrong,
                                  fontSize: titleSize,
                                  height: compact ? 1.16 : 1.08,
                                  fontWeight: FontWeight.w600,
                                  fontVariations:
                                      compact
                                          ? const [FontVariation.weight(800)]
                                          : const [FontVariation.weight(650)],
                                ),
                              ),
                            ),
                          ),
                          if (!collapsedDesktop) ...[
                            SizedBox(height: infoMargin),
                            ClipRect(
                              child: Align(
                                alignment:
                                    compact
                                        ? Alignment.center
                                        : Alignment.centerLeft,
                                heightFactor: (1 - collapseProgress).clamp(
                                  0.0,
                                  1.0,
                                ),
                                child: Opacity(
                                  opacity: (1 - collapseProgress).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  child: _HeaderHeroDragRegion(
                                    windowDragCallbacks: windowDragCallbacks,
                                    child: Text(
                                      info,
                                      maxLines: 1,
                                      textAlign:
                                          compact
                                              ? TextAlign.center
                                              : TextAlign.start,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.textMuted,
                                        fontSize:
                                            lerpDouble(
                                              17,
                                              14,
                                              collapseProgress,
                                            )!,
                                        fontWeight: FontWeight.w600,
                                        fontVariations: const [
                                          FontVariation.weight(650),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: commandMargin),
                          ],
                          if (collapsedDesktop)
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: ClipRect(
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: commandBar,
                                  ),
                                ),
                              ),
                            )
                          else
                            Flexible(
                              fit: FlexFit.loose,
                              child: Align(
                                alignment:
                                    compact
                                        ? Alignment.center
                                        : Alignment.centerLeft,
                                child: ClipRect(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: compact ? 520 : double.infinity,
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: commandBar,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderedPlaylistBackdrop extends StatelessWidget {
  const _HeaderedPlaylistBackdrop({
    super.key,
    required this.coverColor,
    required this.masked,
  });

  final Color coverColor;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final base = Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: HeaderedPlaylistThemeColors.of(context).pageSurface,
          ),
        ),
        _HeaderRadial(
          center: const Alignment(-0.6, -0.56),
          radius: 0.86,
          color: coverColor.withValues(
            alpha: HeaderedPlaylistThemeColors.of(context).backdropAlphaA,
          ),
        ),
        _HeaderRadial(
          center: const Alignment(0.78, -0.8),
          radius: 1.0,
          color: coverColor.withValues(
            alpha: HeaderedPlaylistThemeColors.of(context).backdropAlphaB,
          ),
        ),
        Positioned.fill(
          left: -180,
          top: -120,
          right: -180,
          bottom: 120,
          child: Transform.scale(
            scale: 1.04,
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                1.283464,
                -0.257472,
                -0.025992,
                0,
                0,
                -0.076536,
                1.102528,
                -0.025992,
                0,
                0,
                -0.076536,
                -0.257472,
                1.334008,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
              ]),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 54, sigmaY: 54),
                child: Opacity(
                  opacity: 0.96,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _HeaderRadial(
                        center: const Alignment(-0.6, -0.56),
                        radius: 0.76,
                        color: coverColor.withValues(
                          alpha:
                              HeaderedPlaylistThemeColors.of(
                                context,
                              ).backdropBlurAlphaA,
                        ),
                      ),
                      _HeaderRadial(
                        center: const Alignment(0.20, -0.96),
                        radius: 0.88,
                        color: coverColor.withValues(
                          alpha:
                              HeaderedPlaylistThemeColors.of(
                                context,
                              ).backdropBlurAlphaB,
                        ),
                      ),
                      _HeaderRadial(
                        center: const Alignment(0.76, -0.84),
                        radius: 0.76,
                        color: coverColor.withValues(
                          alpha:
                              HeaderedPlaylistThemeColors.of(
                                context,
                              ).backdropBlurAlphaC,
                        ),
                      ),
                      _HeaderRadial(
                        center: const Alignment(-0.44, 0.36),
                        radius: 0.88,
                        color: coverColor.withValues(
                          alpha:
                              HeaderedPlaylistThemeColors.of(
                                context,
                              ).backdropBlurAlphaD,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (!masked) {
      return base;
    }

    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.black, Colors.black, Colors.transparent],
          stops: [0, ((rect.height - 112) / rect.height).clamp(0.0, 1.0), 1],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: base,
    );
  }
}

class _HeaderHeroSurface extends StatelessWidget {
  const _HeaderHeroSurface({
    required this.coverColor,
    required this.surfaceColor,
    required this.collapseProgress,
  });

  final Color coverColor;
  final Color surfaceColor;
  final double collapseProgress;

  @override
  Widget build(BuildContext context) {
    final progress = collapseProgress.clamp(0.0, 1.0);
    final blur = 18 * progress;
    return ClipRect(
      key: const ValueKey('HeaderedPlaylist.HeroBackdropClip'),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _HeaderRadial(
              center: const Alignment(-0.56, -0.76),
              radius: 0.96,
              color: coverColor.withValues(alpha: 0.22 * progress),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: 0.9 * progress),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderRadial extends StatelessWidget {
  const _HeaderRadial({
    required this.center,
    required this.radius,
    required this.color,
  });

  final Alignment center;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: radius,
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _HeaderHeroDragRegion extends StatelessWidget {
  const _HeaderHeroDragRegion({required this.windowDragCallbacks, this.child});

  final SmPlayerWindowDragCallbacks? windowDragCallbacks;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        windowDragCallbacks?.onStart();
      },
      onPointerUp: (_) {
        windowDragCallbacks?.onEnd();
      },
      onPointerCancel: (_) {
        windowDragCallbacks?.onEnd();
      },
      child: child,
    );
  }
}
