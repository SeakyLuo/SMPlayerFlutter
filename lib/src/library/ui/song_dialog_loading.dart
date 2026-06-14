part of 'music_dialog.dart';

class _SongDialogLoading extends StatelessWidget {
  const _SongDialogLoading();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = MediaQuery.sizeOf(context).height;
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: math.min(180, viewportHeight * 0.28)),
            child: const _SongDialogLoadingIndicator(),
          ),
        );
      },
    );
  }
}

class _SongDialogLoadingIndicator extends StatelessWidget {
  const _SongDialogLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return SizedBox.square(
      key: const ValueKey('MusicDialog.LoadingSpinner'),
      dimension: 38,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        color: colors.accent,
        backgroundColor: colors.accent.withValues(alpha: 0.16),
      ),
    );
  }
}
