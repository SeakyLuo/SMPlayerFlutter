part of 'music_dialog.dart';

class _MusicDialogCommandBar extends StatelessWidget {
  const _MusicDialogCommandBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: 12, runSpacing: 8, children: children),
      ),
    );
  }
}

class _MusicDialogCommandButton extends StatelessWidget {
  const _MusicDialogCommandButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.disabled = false,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final bool primary;
  final bool disabled;
  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground =
        disabled
            ? const Color(0xb35e6773)
            : primary
            ? Colors.white
            : PopupDialogColors.text;
    final background =
        disabled
            ? PopupDialogColors.fieldDisabledSurface
            : primary
            ? PopupDialogColors.accent
            : PopupDialogColors.buttonSurface;

    return TextButton.icon(
      style: TextButton.styleFrom(
        minimumSize: Size(0, compact ? 38 : 40),
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18),
        foregroundColor: foreground,
        backgroundColor: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color:
                primary && !disabled
                    ? const Color(0x850078d7)
                    : PopupDialogColors.buttonBorder,
          ),
        ),
      ),
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      onPressed: disabled ? null : onPressed,
    );
  }
}

class _MusicInfoPropertyList extends StatelessWidget {
  const _MusicInfoPropertyList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(children: children);
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Padding(
              padding: const EdgeInsets.only(top: 11),
              child: Text(
                label,
                style: const TextStyle(
                  color: PopupDialogColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({required this.controller, this.readOnly = false});

  final TextEditingController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        isDense: true,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor:
            readOnly
                ? PopupDialogColors.fieldDisabledSurface
                : PopupDialogColors.fieldSurface,
      ),
    );
  }
}

class _ArtistFieldGrid extends StatelessWidget {
  const _ArtistFieldGrid({
    required this.controllers,
    required this.saving,
    required this.onAddArtistCell,
    required this.onRemoveArtistCell,
  });

  final List<TextEditingController> controllers;
  final bool saving;
  final VoidCallback onAddArtistCell;
  final ValueChanged<int> onRemoveArtistCell;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  controllers.length > 1 && constraints.maxWidth >= 420 ? 2 : 1;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in controllers.indexed)
                    SizedBox(
                      width:
                          columns == 2
                              ? (constraints.maxWidth - 8) / 2
                              : constraints.maxWidth,
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          _DialogField(controller: entry.$2),
                          if (controllers.length > 1)
                            IconButton(
                              icon: const Icon(
                                FluentIcons.dismiss_16_regular,
                                size: 14,
                              ),
                              onPressed:
                                  saving
                                      ? null
                                      : () {
                                        onRemoveArtistCell(entry.$1);
                                      },
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        _MusicDialogCommandButton(
          icon: FluentIcons.add_20_regular,
          label: context.smPlayerI18n.t('common.add'),
          compact: true,
          disabled:
              saving || controllers.length >= _MusicDialogState.maxArtistCells,
          onPressed: onAddArtistCell,
        ),
      ],
    );
  }
}

class _LyricsTimestampToggle extends StatelessWidget {
  const _LyricsTimestampToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged:
                onChanged == null
                    ? null
                    : (value) {
                      onChanged!(value ?? false);
                    },
          ),
          Text(
            context.smPlayerI18n.t('song.showLyricsTimestamps'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ArtworkSourceButton extends StatelessWidget {
  const _ArtworkSourceButton({
    required this.disabled,
    required this.onChangeArtwork,
    required this.onChooseArtworkFromLibrary,
  });

  final bool disabled;
  final VoidCallback onChangeArtwork;
  final VoidCallback onChooseArtworkFromLibrary;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return Builder(
      builder:
          (buttonContext) => _MusicDialogCommandButton(
            icon: FluentIcons.edit_20_regular,
            label: i18n.t('song.changeArtwork'),
            disabled: disabled,
            onPressed:
                disabled
                    ? null
                    : () {
                      showMenuFlyout(
                        buttonContext,
                        layer: MenuFlyoutLayer.dialog,
                        items: [
                          MenuFlyoutItem(
                            key: 'local',
                            text: i18n.t('song.chooseArtworkFromLocal'),
                            icon: FluentIcons.image_20_regular,
                            onPressed: onChangeArtwork,
                          ),
                          MenuFlyoutItem(
                            key: 'library',
                            text: i18n.t('song.chooseArtworkFromLibrary'),
                            icon: FluentIcons.music_note_2_20_regular,
                            onPressed: onChooseArtworkFromLibrary,
                          ),
                        ],
                      );
                    },
          ),
    );
  }
}

class _AlbumArtRecommendationText extends StatelessWidget {
  const _AlbumArtRecommendationText({
    required this.recommendation,
    required this.onApply,
  });

  final AlbumArtRecommendation recommendation;
  final ValueChanged<AlbumArtRecommendation> onApply;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 270),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            i18n.t('song.albumArtRecommendationPrefix', {
              'artist': recommendation.artistName,
            }),
            textAlign: TextAlign.center,
            style: const TextStyle(color: PopupDialogColors.textMuted),
          ),
          TextButton(
            onPressed: () {
              onApply(recommendation);
            },
            child: Text(
              i18n.t('song.albumArtRecommendationTitle', {
                'title': recommendation.song.title,
              }),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            i18n.t('song.albumArtRecommendationSuffix'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: PopupDialogColors.textMuted),
          ),
        ],
      ),
    );
  }
}
