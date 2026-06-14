part of 'music_dialog.dart';

class _MusicDialogSaveProgress extends StatefulWidget {
  const _MusicDialogSaveProgress();

  @override
  State<_MusicDialogSaveProgress> createState() =>
      _MusicDialogSaveProgressState();
}

class _MusicDialogSaveProgressState extends State<_MusicDialogSaveProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          key: const ValueKey('MusicDialog.SaveProgress'),
          height: 3,
          width: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          left: (-0.36 + 1.368 * _controller.value) * width,
                          top: 0,
                          bottom: 0,
                          width: width * 0.36,
                          child: child!,
                        ),
                      ],
                    );
                  },
                  child: ColoredBox(color: colors.accent),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
