part of 'artists_page.dart';

class _ArtistsLoadingSpinner extends StatefulWidget {
  const _ArtistsLoadingSpinner();

  @override
  State<_ArtistsLoadingSpinner> createState() => _ArtistsLoadingSpinnerState();
}

class _ArtistsLoadingSpinnerState extends State<_ArtistsLoadingSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      key: const ValueKey('Artists.DetailLoadingSpinner.Rotation'),
      turns: _controller,
      child: CustomPaint(
        key: const ValueKey('Artists.DetailLoadingSpinner.Paint'),
        painter: _ArtistsLoadingSpinnerPainter(
          trackColor: _ArtistsColors.loadingSpinnerTrack,
          topColor: _ArtistsColors.accent,
          strokeWidth: 2,
        ),
      ),
    );
  }
}
