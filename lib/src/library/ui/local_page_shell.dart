import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../../app/workspace_app_bar_portal.dart';
import '../../app/text_icon_button.dart';
import 'default_album_artwork.dart';
import 'missing_library_root_content.dart';

const _localPageCompactBreakpoint = 720.0;
const localPageCompactScrollbarGutter = 12.0;
const localPageWideScrollbarGutter = 18.0;

double localPageScrollbarGutter(bool compact) =>
    compact ? localPageCompactScrollbarGutter : localPageWideScrollbarGutter;

class LocalPageScaffold extends StatelessWidget {
  const LocalPageScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < _localPageCompactBreakpoint;
    final underWorkspaceHeader = WorkspaceNavigationAppBarScope.of(context);
    return Padding(
      padding:
          compact
              ? const EdgeInsets.fromLTRB(4, 6, 0, 0)
              : underWorkspaceHeader
              ? const EdgeInsets.fromLTRB(6, 0, 6, 0)
              : const EdgeInsets.fromLTRB(6, 18, 6, 0),
      child: SizedBox.expand(child: child),
    );
  }
}

class LocalPageContentPanel extends StatelessWidget {
  const LocalPageContentPanel({
    super.key,
    required this.scrollController,
    required this.scrollable,
    required this.compact,
    required this.bottomPadding,
    required this.child,
  });

  final ScrollController scrollController;
  final bool scrollable;
  final bool compact;
  final double bottomPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      if (!scrollable) {
        return child;
      }
      return _LocalScrollableContent(
        controller: scrollController,
        scrollbarGutter: localPageCompactScrollbarGutter,
        padding: EdgeInsets.fromLTRB(
          8,
          4,
          localPageCompactScrollbarGutter,
          bottomPadding,
        ),
        child: child,
      );
    }

    if (!scrollable) {
      return child;
    }
    return _LocalScrollableContent(
      controller: scrollController,
      scrollbarGutter: localPageWideScrollbarGutter,
      padding: EdgeInsets.fromLTRB(12, 4, 24, bottomPadding),
      child: child,
    );
  }
}

class _LocalScrollableContent extends StatelessWidget {
  const _LocalScrollableContent({
    required this.controller,
    required this.scrollbarGutter,
    required this.padding,
    required this.child,
  });

  final ScrollController controller;
  final double scrollbarGutter;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = constraints.maxWidth - padding.horizontal;
        return Stack(
          children: [
            Positioned.fill(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  controller: controller,
                  child: Padding(
                    padding: padding,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: minWidth > 0 ? minWidth : 0,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: scrollbarGutter,
              child: _LocalPageScrollbar(controller: controller),
            ),
          ],
        );
      },
    );
  }
}

class _LocalPageScrollbar extends StatefulWidget {
  const _LocalPageScrollbar({required this.controller});

  final ScrollController controller;

  @override
  State<_LocalPageScrollbar> createState() => _LocalPageScrollbarState();
}

class _LocalPageScrollbarState extends State<_LocalPageScrollbar> {
  var _hovered = false;
  var _lastMaxScrollExtent = -1.0;

  ScrollPosition? get _activePosition {
    ScrollPosition? active;
    for (final position in widget.controller.positions) {
      if (position.hasContentDimensions && position.maxScrollExtent > 1) {
        active = position;
      }
    }
    return active;
  }

  void _scheduleMetricsSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final nextMaxScrollExtent = _activePosition?.maxScrollExtent ?? 0;
      if (_lastMaxScrollExtent == nextMaxScrollExtent) {
        return;
      }
      setState(() {
        _lastMaxScrollExtent = nextMaxScrollExtent;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMetricsSync();
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final position = _activePosition;
            if (position == null) {
              return const SizedBox.shrink();
            }

            final trackHeight = constraints.maxHeight;
            final maxScrollTop = position.maxScrollExtent;
            final scrollHeight = trackHeight + maxScrollTop;
            final thumbHeight = max(
              38.0,
              (trackHeight / scrollHeight) * trackHeight,
            );
            final trackRange = max(1.0, trackHeight - thumbHeight);
            final thumbTop = (position.pixels / maxScrollTop) * trackRange;
            final thumbWidth = _hovered ? 7.0 : 5.0;

            return MouseRegion(
              onEnter:
                  (_) => setState(() {
                    _hovered = true;
                  }),
              onExit:
                  (_) => setState(() {
                    _hovered = false;
                  }),
              child: Stack(
                children: [
                  Positioned(
                    top: thumbTop.clamp(0.0, trackRange),
                    left: (constraints.maxWidth - thumbWidth) / 2,
                    width: thumbWidth,
                    height: thumbHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        final scrollDelta =
                            details.delta.dy * (maxScrollTop / trackRange);
                        position.jumpTo(
                          (position.pixels + scrollDelta).clamp(
                            0.0,
                            maxScrollTop,
                          ),
                        );
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color:
                              _hovered
                                  ? const Color(0xad435060)
                                  : const Color(0x805b697a),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class LocalPageEmptyState extends StatelessWidget {
  const LocalPageEmptyState({
    super.key,
    required this.title,
    this.message = '',
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = MissingLibraryRootThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: LocalPageEmptyArtwork(),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation.weight(650)],
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  message,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 14,
                    height: 1.65,
                  ),
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class LocalPageEmptyArtwork extends StatelessWidget {
  const LocalPageEmptyArtwork({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = MissingLibraryRootThemeColors.of(context);
    return SizedBox.square(
      dimension: 104,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colors.artworkShadow,
              offset: const Offset(0, 8),
              blurRadius: 18,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.artworkBorder),
            ),
            child: DefaultAlbumArtwork(
              logoScale: 0.72,
              logoOpacity: colors.artworkLogoOpacity,
            ),
          ),
        ),
      ),
    );
  }
}

class LocalCommandButton extends StatelessWidget {
  const LocalCommandButton({
    super.key,
    this.icon,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final IconData? icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SmPlayerTextIconButton(
      icon: icon,
      label: label,
      loading: loading,
      onPressed: onPressed,
    );
  }
}
