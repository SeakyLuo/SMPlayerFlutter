part of 'playlists_page.dart';

int _playlistGridColumns(double width) =>
    ((width + _playlistGridCrossAxisSpacing) /
            (_playlistCardWidth + _playlistGridCrossAxisSpacing))
        .floor()
        .clamp(1, 8);

EdgeInsets _playlistGridPadding(bool workspaceAppBar) =>
    EdgeInsets.fromLTRB(38, workspaceAppBar ? 20 : 8, 14, 116);

SliverGridDelegate _playlistGridDelegate(int columns) =>
    SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisExtent: gridViewHolderHeight,
      crossAxisSpacing: _playlistGridCrossAxisSpacing,
      mainAxisSpacing: 26,
    );

class _PlaylistGridLoadingState extends StatelessWidget {
  const _PlaylistGridLoadingState({required this.useWorkspaceAppBar});
  final bool useWorkspaceAppBar;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.smPlayerI18n.t('nowPlaying.loading'),
    child: ExcludeSemantics(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = _playlistGridColumns(constraints.maxWidth);
            final rows =
                (constraints.maxHeight / (gridViewHolderHeight + 26)).ceil();
            return Padding(
              padding: const EdgeInsets.only(right: 18),
              child: GridView.builder(
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                padding: _playlistGridPadding(useWorkspaceAppBar),
                gridDelegate: _playlistGridDelegate(columns),
                itemCount: columns * rows,
                itemBuilder:
                    (_, _) => const Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: gridViewHolderWidth,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SmPlayerSkeletonBlock(
                                width: 160,
                                height: 160,
                                radius: 8,
                              ),
                              SizedBox(height: 12),
                              SizedBox(
                                height: 20.25,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SmPlayerSkeletonBlock(
                                    width: 120,
                                    height: 14,
                                  ),
                                ),
                              ),
                              SizedBox(height: 3),
                              SizedBox(
                                height: 16.2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SmPlayerSkeletonBlock(
                                    width: 80,
                                    height: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
