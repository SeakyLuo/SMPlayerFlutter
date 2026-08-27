part of 'music_dialog.dart';

class _ArtworkSourceButton extends StatelessWidget {
  const _ArtworkSourceButton({
    this.loading = false,
    required this.disabled,
    required this.onChangeArtwork,
    required this.onChooseArtworkFromLibrary,
  });

  final bool loading;
  final bool disabled;
  final VoidCallback onChangeArtwork;
  final VoidCallback? onChooseArtworkFromLibrary;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;

    return Builder(
      builder:
          (buttonContext) => _MusicDialogCommandButton(
            iconWidget: const _ElectronIcon(_ElectronIconName.edit, size: 20),
            label: i18n.t('song.changeArtwork'),
            commandBar: true,
            loading: loading,
            disabled: disabled,
            onPressed:
                disabled
                    ? null
                    : () {
                      final button =
                          buttonContext.findRenderObject()! as RenderBox;
                      showMenuFlyout(
                        buttonContext,
                        layer: MenuFlyoutLayer.dialog,
                        position: button.localToGlobal(
                          Offset(0, button.size.height + 6),
                        ),
                        items: [
                          MenuFlyoutItem(
                            key: 'local',
                            text: i18n.t('song.chooseArtworkFromLocal'),
                            iconWidget: const _ElectronIcon(
                              _ElectronIconName.pictures,
                              size: 18,
                            ),
                            onPressed: onChangeArtwork,
                          ),
                          MenuFlyoutItem(
                            key: 'library',
                            text: i18n.t('song.chooseArtworkFromLibrary'),
                            iconWidget: const _ElectronIcon(
                              _ElectronIconName.musicLibrary,
                              size: 18,
                            ),
                            disabled: onChooseArtworkFromLibrary == null,
                            onPressed: onChooseArtworkFromLibrary,
                          ),
                        ],
                      );
                    },
          ),
    );
  }
}
