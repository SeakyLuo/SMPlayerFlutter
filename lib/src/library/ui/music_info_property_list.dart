part of 'music_dialog.dart';

class _MusicInfoPropertyList extends StatelessWidget {
  const _MusicInfoPropertyList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    return Column(
      key: const ValueKey('MusicDialog.PropertyList'),
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) SizedBox(height: mobile ? 6 : 10),
          child,
        ],
      ],
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= popupDialogMobileBreakpoint;
    final labelWidget = Padding(
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: mobile ? double.infinity : 110,
        height: mobile ? null : 42,
        child: Align(
          alignment: mobile ? Alignment.topLeft : Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
    if (mobile) {
      return Column(
        key: ValueKey('MusicDialog.PropertyRow.$label'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [labelWidget, const SizedBox(height: 6), child],
      );
    }
    return Row(
      key: ValueKey('MusicDialog.PropertyRow.$label'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labelWidget,
        const SizedBox(width: 18),
        Expanded(child: child),
      ],
    );
  }
}
