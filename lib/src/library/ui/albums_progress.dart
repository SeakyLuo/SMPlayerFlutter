part of 'albums_page.dart';

class _AlbumsProgress extends StatefulWidget {
  const _AlbumsProgress({super.key});

  @override
  State<_AlbumsProgress> createState() => _AlbumsProgressState();
}

class _AlbumsProgressState extends State<_AlbumsProgress>
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
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Transform.translate(
        offset: const Offset(0, -6),
        child: Container(
          height: 3,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _AlbumsColors.accentProgressTrackFor(brightness),
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final offset = lerpDouble(-1.2, 3.4, _controller.value)!;
              return FractionalTranslation(
                translation: Offset(offset, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(widthFactor: 0.34, child: child),
                ),
              );
            },
            child: ColoredBox(color: _AlbumsColors.accentFor(brightness)),
          ),
        ),
      ),
    );
  }
}
