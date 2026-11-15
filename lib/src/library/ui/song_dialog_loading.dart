part of 'music_dialog.dart';

class _SongDialogLoading extends StatelessWidget {
  const _SongDialogLoading();

  @override
  Widget build(BuildContext context) {
    return const SmPlayerLoadingState(layout: SmPlayerLoadingLayout.form);
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
