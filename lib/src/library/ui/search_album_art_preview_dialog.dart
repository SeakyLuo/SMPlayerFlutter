part of 'search_page.dart';

class _SearchAlbumArtPreviewDialog extends StatelessWidget {
  const _SearchAlbumArtPreviewDialog({
    required this.card,
    required this.onClose,
  });

  final SearchResult card;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final i18n = context.smPlayerI18n;
    final artworkFile = card.artworkUrl.isEmpty ? null : File(card.artworkUrl);

    return PopupDialog(
      overlayClassName: 'album-art-preview-overlay AlbumArtPreviewOverlay',
      className: 'album-art-preview-dialog AlbumArtPreviewDialog',
      navClassName: 'album-art-preview-nav AlbumArtPreviewNav',
      navLabel: i18n.t('context.seeAlbumArt'),
      ariaLabel: card.title,
      width: 560,
      height: 620,
      onClose: onClose,
      navChildren: [
        Expanded(
          child: Text(
            card.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PopupDialogColors.textStrong,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
      child: Center(
        child:
            artworkFile != null && artworkFile.existsSync()
                ? Container(
                  width: 420,
                  height: 420,
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
                  dimension: 420,
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
                          size: 48,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          i18n.t('song.noAlbumArt'),
                          style: const TextStyle(
                            color: PopupDialogColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}
