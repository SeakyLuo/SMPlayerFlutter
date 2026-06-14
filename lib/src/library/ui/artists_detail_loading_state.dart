part of 'artists_page.dart';

class _ArtistsDetailLoadingState extends StatelessWidget {
  const _ArtistsDetailLoadingState();

  @override
  Widget build(BuildContext context) {
    final i18n =
        context.maybeSmPlayerI18n ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    final brightness = Theme.of(context).brightness;
    final label = i18n.t('nowPlaying.loading');
    return ColoredBox(
      key: const ValueKey('Artists.DetailSurface'),
      color: _ArtistsColors.detailBackground(brightness),
      child: Center(
        child: DecoratedBox(
          key: const ValueKey('Artists.DetailLoadingState.Surface'),
          decoration: _ArtistsColors.detailEmptyStateDecoration(brightness),
          child: Padding(
            key: const ValueKey('Artists.DetailLoadingState.Padding'),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Semantics(
              container: true,
              liveRegion: true,
              label: label,
              child: ExcludeSemantics(
                child: Row(
                  key: const ValueKey('Artists.DetailLoadingState'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      key: ValueKey('Artists.DetailLoadingSpinner'),
                      dimension: 18,
                      child: _ArtistsLoadingSpinner(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      key: const ValueKey('Artists.DetailLoadingTitle'),
                      label,
                      style: TextStyle(
                        color: _ArtistsColors.textStrongFor(brightness),
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
