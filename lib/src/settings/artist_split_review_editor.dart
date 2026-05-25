part of 'artist_split_review_panel.dart';

class _ArtistSplitEditor extends StatelessWidget {
  const _ArtistSplitEditor({
    required this.artists,
    required this.canAdd,
    required this.onAddArtist,
    required this.onSaveEdit,
    required this.onRemoveArtist,
    required this.onUpdateArtist,
  });

  final List<String> artists;
  final bool canAdd;
  final VoidCallback onAddArtist;
  final VoidCallback onSaveEdit;
  final ValueChanged<int> onRemoveArtist;
  final void Function(int index, String value) onUpdateArtist;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _ArtistSplitSmallIconButton(
              icon: FluentIcons.add_20_regular,
              tooltip: i18n.t('common.add'),
              onPressed: canAdd ? onAddArtist : null,
            ),
            const SizedBox(width: 5),
            _ArtistSplitSmallIconButton(
              icon: FluentIcons.checkmark_20_regular,
              tooltip: i18n.t('settings.save'),
              onPressed: onSaveEdit,
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (var index = 0; index < artists.length; index += 1) ...[
          _ArtistSplitEditorCell(
            value: artists[index],
            onChanged: (value) => onUpdateArtist(index, value),
            onRemove: () => onRemoveArtist(index),
          ),
          if (index != artists.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _ArtistSplitEditorCell extends StatefulWidget {
  const _ArtistSplitEditorCell({
    required this.value,
    required this.onChanged,
    required this.onRemove,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;

  @override
  State<_ArtistSplitEditorCell> createState() => _ArtistSplitEditorCellState();
}

class _ArtistSplitEditorCellState extends State<_ArtistSplitEditorCell> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_ArtistSplitEditorCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return SizedBox(
      height: 36,
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: TextStyle(
          color: colors.textStrong,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.fromLTRB(9, 0, 38, 0),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.72),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0x3d7e8b9a)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: BorderSide(color: colors.accent.withValues(alpha: 0.5)),
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _ArtistSplitEditorRemoveButton(onPressed: widget.onRemove),
          ),
          suffixIconConstraints: const BoxConstraints.tightFor(
            width: 32,
            height: 28,
          ),
        ),
      ),
    );
  }
}

class _ArtistSplitEditorRemoveButton extends StatelessWidget {
  const _ArtistSplitEditorRemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      style: IconButton.styleFrom(
        fixedSize: const Size.square(28),
        padding: EdgeInsets.zero,
        foregroundColor: PopupDialogColors.resolve(context).textStrong,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: const Icon(FluentIcons.dismiss_20_regular, size: 15),
      onPressed: onPressed,
    );
  }
}

class _ArtistSplitChip extends StatelessWidget {
  const _ArtistSplitChip({required this.label, required this.merge});

  final String label;
  final bool merge;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    final color = merge ? const Color(0xffdc2626) : colors.accentStrong;
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: merge ? 0.14 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.normal,
        ),
      ),
    );
  }
}

class _ArtistSplitIconButton extends StatelessWidget {
  const _ArtistSplitIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        style: IconButton.styleFrom(
          fixedSize: const Size.square(34),
          padding: EdgeInsets.zero,
          foregroundColor: colors.textStrong,
          backgroundColor: Colors.white.withValues(alpha: 0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0x387e8b9a)),
          ),
        ),
        icon: Icon(icon, size: 15),
        onPressed: onPressed,
      ),
    );
  }
}

class _ArtistSplitSmallIconButton extends StatelessWidget {
  const _ArtistSplitSmallIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = PopupDialogColors.resolve(context);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        style: IconButton.styleFrom(
          fixedSize: const Size.square(28),
          padding: EdgeInsets.zero,
          foregroundColor: colors.textStrong,
          disabledForegroundColor: colors.textMuted.withValues(alpha: 0.44),
          backgroundColor: Colors.white.withValues(alpha: 0.72),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0x387e8b9a)),
          ),
        ),
        icon: Icon(icon, size: 15),
        onPressed: onPressed,
      ),
    );
  }
}

List<String> _getEditedArtists(List<String> artists) {
  return [
    for (final artist in artists)
      if (artist.trim().isNotEmpty) artist.trim(),
  ];
}

bool _sameArtists(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
