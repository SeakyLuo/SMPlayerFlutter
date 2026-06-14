part of 'albums_page.dart';

class _AlbumGridDelegate extends SliverGridDelegate {
  const _AlbumGridDelegate({
    required this.crossAxisCount,
    required this.crossAxisExtent,
    required this.mainAxisExtent,
    required this.crossAxisSpacing,
  });

  final int crossAxisCount;
  final double crossAxisExtent;
  final double mainAxisExtent;
  final double crossAxisSpacing;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: mainAxisExtent,
      crossAxisStride: crossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: mainAxisExtent,
      childCrossAxisExtent: crossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(_AlbumGridDelegate oldDelegate) {
    return oldDelegate.crossAxisCount != crossAxisCount ||
        oldDelegate.crossAxisExtent != crossAxisExtent ||
        oldDelegate.mainAxisExtent != mainAxisExtent ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing;
  }
}
