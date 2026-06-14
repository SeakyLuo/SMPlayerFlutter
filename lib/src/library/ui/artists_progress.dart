part of 'artists_page.dart';

class _ArtistsProgress extends StatefulWidget {
  const _ArtistsProgress({super.key, required this.label});

  final String label;

  @override
  State<_ArtistsProgress> createState() => _ArtistsProgressState();
}

class _ArtistsProgressState extends State<_ArtistsProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      child: SizedBox(
        height: 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: ColoredBox(
            color: _ArtistsColors.accentProgressTrack,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final offset = lerpDouble(-1.2, 3.4, _controller.value)!;
                return FractionalTranslation(
                  translation: Offset(offset, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.34,
                      child: child,
                    ),
                  ),
                );
              },
              child: const ColoredBox(
                key: ValueKey('Artists.Progress.Thumb'),
                color: _ArtistsColors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
