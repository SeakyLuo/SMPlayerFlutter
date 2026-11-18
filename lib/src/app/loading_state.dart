import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import 'shell_colors.dart';

enum SmPlayerLoadingLayout { list, grid, artists, detail, form }

class SmPlayerLoadingState extends StatelessWidget {
  const SmPlayerLoadingState({
    super.key,
    this.compact = false,
    this.layout = SmPlayerLoadingLayout.list,
  });

  final bool compact;
  final SmPlayerLoadingLayout layout;

  @override
  Widget build(BuildContext context) {
    final i18n =
        context.maybeSmPlayerI18n ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    return Semantics(
      container: true,
      liveRegion: true,
      label: i18n.t('nowPlaying.loading'),
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: ClipRect(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height =
                    constraints.hasBoundedHeight
                        ? constraints.maxHeight
                        : (compact ? 280.0 : 520.0);
                final contentWidth = constraints.maxWidth - (compact ? 24 : 40);
                final rows = (height / (compact ? 64 : 82)).ceil().clamp(2, 12);
                final content = switch (layout) {
                  SmPlayerLoadingLayout.form => _form(compact ? 3 : 5),
                  SmPlayerLoadingLayout.grid => _grid(
                    constraints.maxWidth,
                    height,
                  ),
                  SmPlayerLoadingLayout.artists
                      when constraints.maxWidth > 860 =>
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 300, child: _rows(rows)),
                        Expanded(child: _detail(contentWidth - 300, rows)),
                      ],
                    ),
                  SmPlayerLoadingLayout.detail => _detail(contentWidth, rows),
                  _ => _rows(rows),
                };
                return SingleChildScrollView(
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.all(compact ? 12 : 20),
                  child: content,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(int count) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < count; index++) ...[
        const SmPlayerSkeletonBlock(width: 72, height: 12),
        const SizedBox(height: 12),
        const SmPlayerSkeletonBlock(height: 40, radius: 8),
        const SizedBox(height: 24),
      ],
    ],
  );

  Widget _rows(int count) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < count; index++)
        Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
          child: Row(
            children: [
              SmPlayerSkeletonBlock(
                width: compact ? 40 : 48,
                height: compact ? 40 : 48,
                radius: 8,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: index.isEven ? 0.62 : 0.46,
                      child: const SmPlayerSkeletonBlock(height: 14),
                    ),
                    const SizedBox(height: 10),
                    const FractionallySizedBox(
                      widthFactor: 0.34,
                      child: SmPlayerSkeletonBlock(height: 10),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 20),
                const SmPlayerSkeletonBlock(width: 32, height: 10),
              ],
            ],
          ),
        ),
    ],
  );

  Widget _grid(double width, double height) {
    final available = math.max(0.0, width - (compact ? 24 : 40));
    final columns = math.max(1, ((available + 24) / 204).floor());
    final tileWidth = math.min(
      180.0,
      (available - (columns - 1) * 24) / columns,
    );
    final rows = (height / (tileWidth + 68)).ceil().clamp(1, 4);
    return Wrap(
      spacing: 24,
      runSpacing: 28,
      children: [
        for (var index = 0; index < columns * rows; index++)
          SizedBox(
            width: tileWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SmPlayerSkeletonBlock(height: tileWidth, radius: 10),
                const SizedBox(height: 14),
                const FractionallySizedBox(
                  widthFactor: 0.75,
                  child: SmPlayerSkeletonBlock(height: 14),
                ),
                const SizedBox(height: 10),
                const FractionallySizedBox(
                  widthFactor: 0.45,
                  child: SmPlayerSkeletonBlock(height: 10),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _detail(double width, int rows) {
    final artwork = math.min(144.0, width * 0.28);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SmPlayerSkeletonBlock(width: artwork, height: artwork, radius: 10),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    widthFactor: 0.65,
                    child: SmPlayerSkeletonBlock(height: 24),
                  ),
                  SizedBox(height: 16),
                  FractionallySizedBox(
                    widthFactor: 0.4,
                    child: SmPlayerSkeletonBlock(height: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _rows(rows),
      ],
    );
  }
}

class SmPlayerSkeletonBlock extends StatelessWidget {
  const SmPlayerSkeletonBlock({
    super.key,
    this.width,
    required this.height,
    this.radius = 4,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: ShellThemeColors.of(context).headerText.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
