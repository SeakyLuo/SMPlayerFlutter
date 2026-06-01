part of 'albums_page.dart';

class _AlbumArtPreviewDialog extends StatelessWidget {
  const _AlbumArtPreviewDialog({
    required this.album,
    required this.i18n,
    required this.onClose,
  });

  final AlbumView album;
  final SmPlayerI18n i18n;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final viewport = MediaQuery.sizeOf(context);
    final dialogWidth = min(420.0, viewport.width * 0.86);
    final artworkSize = min(320.0, viewport.width * 0.70);
    return Positioned.fill(
      child: Material(
        color: _AlbumsColors.previewBackdropFor(brightness),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('Albums.ArtPreview.Backdrop'),
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: const SizedBox.expand(),
              ),
            ),
            Center(
              child: GestureDetector(
                key: const ValueKey('Albums.ArtPreview.Dialog'),
                onTap: () {},
                child: Container(
                  width: dialogWidth,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _AlbumsColors.previewDialogSurfaceFor(brightness),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _AlbumsColors.previewDialogBorderFor(brightness),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _AlbumsColors.previewDialogShadowFor(brightness),
                        blurRadius: brightness == Brightness.dark ? 72 : 44,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -12,
                        right: -12,
                        child: IconButton(
                          tooltip: i18n.t('common.close'),
                          style: IconButton.styleFrom(
                            fixedSize: const Size.square(32),
                            minimumSize: const Size.square(32),
                            padding: EdgeInsets.zero,
                            backgroundColor:
                                _AlbumsColors.previewCloseSurfaceFor(
                                  brightness,
                                ),
                            foregroundColor: _AlbumsColors.textMutedFor(
                              brightness,
                            ),
                            hoverColor: _AlbumsColors.surfaceControlHoverFor(
                              brightness,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(FluentIcons.dismiss_20_regular),
                          iconSize: 16,
                          onPressed: onClose,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: AlbumArtControl(
                              album: album,
                              dimension: artworkSize,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            album.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _AlbumsColors.textStrongFor(brightness),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
