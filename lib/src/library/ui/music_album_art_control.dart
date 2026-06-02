part of 'music_dialog.dart';

class MusicAlbumArtControl extends StatelessWidget {
  const MusicAlbumArtControl({
    super.key,
    required this.song,
    required this.loading,
    required this.saving,
    required this.artworkUrl,
    required this.artworkDirty,
    required this.recommendation,
    required this.showDeleteConfirm,
    required this.onApplyRecommendation,
    required this.onChangeArtwork,
    required this.onChooseArtworkFromLibrary,
    required this.onSaveArtwork,
    required this.onResetArtwork,
    required this.onRequestDelete,
    required this.onConfirmDelete,
    required this.onCancelDelete,
  });

  final LibrarySong song;
  final bool loading;
  final bool saving;
  final String artworkUrl;
  final bool artworkDirty;
  final AlbumArtRecommendation? recommendation;
  final bool showDeleteConfirm;
  final ValueChanged<AlbumArtRecommendation> onApplyRecommendation;
  final VoidCallback onChangeArtwork;
  final VoidCallback onChooseArtworkFromLibrary;
  final VoidCallback onSaveArtwork;
  final VoidCallback onResetArtwork;
  final VoidCallback onRequestDelete;
  final VoidCallback onConfirmDelete;
  final VoidCallback onCancelDelete;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final artworkFile = artworkUrl.isEmpty ? null : File(artworkUrl);

    return Column(
      children: [
        _MusicDialogCommandBar(
          children: [
            _ArtworkSourceButton(
              disabled: loading || saving,
              onChangeArtwork: onChangeArtwork,
              onChooseArtworkFromLibrary: onChooseArtworkFromLibrary,
            ),
            _MusicDialogCommandButton(
              icon: FluentIcons.save_20_regular,
              label: i18n.t('settings.save'),
              primary: true,
              disabled: loading || saving,
              onPressed: onSaveArtwork,
            ),
            if (artworkDirty)
              _MusicDialogCommandButton(
                icon: FluentIcons.arrow_reset_20_regular,
                label: i18n.t('common.reset'),
                disabled: loading || saving,
                onPressed: onResetArtwork,
              ),
            _MusicDialogCommandButton(
              icon: FluentIcons.delete_20_regular,
              label: i18n.t('playlists.delete'),
              disabled: loading || saving,
              onPressed: onRequestDelete,
            ),
          ],
        ),
        Expanded(
          child:
              loading
                  ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        artworkFile != null && artworkFile.existsSync()
                            ? Container(
                              width: 340,
                              height: 340,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x2932423a),
                                    blurRadius: 42,
                                    offset: Offset(0, 18),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.file(artworkFile, fit: BoxFit.cover),
                            )
                            : SizedBox.square(
                              dimension: 340,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xffe8eef5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      FluentIcons.image_24_regular,
                                      color: PopupDialogColors.textMuted,
                                      size: 46,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      i18n.t('song.noAlbumArt'),
                                      style: const TextStyle(
                                        color: PopupDialogColors.textMuted,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (recommendation != null) ...[
                                      const SizedBox(height: 12),
                                      _AlbumArtRecommendationText(
                                        recommendation: recommendation!,
                                        onApply: onApplyRecommendation,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        if (showDeleteConfirm) ...[
                          const SizedBox(height: 18),
                          _ArtworkDeleteConfirm(
                            message: i18n.t('song.removeAlbumArt', {
                              'title': song.title,
                            }),
                            onConfirm: onConfirmDelete,
                            onCancel: onCancelDelete,
                          ),
                        ],
                      ],
                    ),
                  ),
        ),
      ],
    );
  }
}
