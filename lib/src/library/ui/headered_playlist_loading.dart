part of 'headered_playlist_control.dart';

/// Uses the same hero and song-list layout as the loaded collection.
class HeaderedPlaylistLoadingState extends StatelessWidget {
  const HeaderedPlaylistLoadingState({super.key, required this.type});

  final HeaderedPlaylistType type;

  @override
  Widget build(BuildContext context) {
    final i18n =
        context.maybeSmPlayerI18n ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    final colors = HeaderedPlaylistThemeColors.of(context);
    final compact = MediaQuery.sizeOf(context).width <= 720;
    return SmPlayerI18nScope(
      i18n: i18n,
      child: Semantics(
        label: i18n.t('nowPlaying.loading'),
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: ColoredBox(
              color: colors.pageSurface,
              child: CustomScrollView(
                physics: const NeverScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _HeaderHero(
                      type: type,
                      title: '',
                      info: '',
                      artworkUrls: const [],
                      coverColor: colors.pageSurface,
                      collapseProgress: 0,
                      windowDragCallbacks: null,
                      loading: true,
                      commandBar: Wrap(
                        alignment:
                            compact
                                ? WrapAlignment.center
                                : WrapAlignment.start,
                        spacing: 10,
                        runSpacing: 8,
                        children: const [
                          SmPlayerSkeletonBlock(
                            width: 108,
                            height: 40,
                            radius: 8,
                          ),
                          SmPlayerSkeletonBlock(
                            width: 88,
                            height: 40,
                            radius: 8,
                          ),
                          SmPlayerSkeletonBlock(
                            width: 40,
                            height: 40,
                            radius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _HeaderedPlaylistListSliver(
                    showAlbum: true,
                    entries: const [],
                    totalCount: 10,
                    entryBuilder: (_) => null,
                    bottomPadding: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
